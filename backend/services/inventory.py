from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List, Dict, Any, Optional
from datetime import datetime

from backend.models.inventory import Ingredient, Recipe, RecipeIngredient, StockTransaction, MenuItemAvailability
from backend.models.catalog import MenuItem
from backend.models.billing import Bill

async def deduct_stock_for_bill(db: Session, bill: Any) -> List[Dict[str, Any]]:
    """
    Recursively resolves recipes for all items in a bill and deducts stock.
    Supports sub-recipes, yield factors, and variant multipliers.
    Returns list of deduction results with warnings for low stock.
    """
    aggregated_deductions: Dict[int, float] = {}  # ingredient_id -> total_quantity
    results = []

    # 1. Aggregate all ingredients across the bill
    for item in bill.items:
        # Fetch root recipe for this menu item
        recipe = db.query(Recipe).filter(Recipe.menu_item_id == item.menu_item_id, Recipe.recipe_type == "main").first()
        if not recipe:
            continue
        
        # Resolve recursively (item.quantity is the number of portions sold)
        # Note: Variant multiplier should be applied here if item model supports it
        # For now we use item.quantity
        _resolve_recipe_recursive(db, recipe.id, item.quantity, aggregated_deductions)

    # 2. Deduct from ingredients table
    for ing_id, qty in aggregated_deductions.items():
        ing = db.query(Ingredient).filter(Ingredient.id == ing_id).first()
        if not ing:
            continue
        
        prev_stock = ing.current_stock
        ing.current_stock -= qty
        new_stock = ing.current_stock
        
        # 3. Save stock transaction
        txn = StockTransaction(
            ingredient_id=ing_id,
            quantity=-qty,
            previous_stock=prev_stock,
            new_stock=new_stock,
            reference_type="order",
            reference_id=str(bill.id),
            reason="bill-deduction",
            notes=f"Order #{bill.id} deduction"
        )
        db.add(txn)
        
        results.append({
            "ingredient_name": ing.name,
            "deducted_qty": qty,
            "previous_stock": prev_stock,
            "new_stock": new_stock,
            "warning": new_stock <= ing.min_stock
        })
        
        # 4. Auto menu disable logic: check all recipes using this ingredient
        await update_menu_availability_for_ingredient(db, ing_id)

    db.commit()
    return results

def _resolve_recipe_recursive(db: Session, recipe_id: int, multiplier: float, aggregated: Dict[int, float]):
    """Helper to walk the recipe tree."""
    ingredients = db.query(RecipeIngredient).filter(RecipeIngredient.recipe_id == recipe_id).all()
    
    for ri in ingredients:
        total_needed = ri.quantity * multiplier * ri.yield_factor
        
        if ri.ingredient_id:
            # Raw material
            aggregated[ri.ingredient_id] = aggregated.get(ri.ingredient_id, 0.0) + total_needed
        elif ri.sub_recipe_id:
            # Sub-recipe
            _resolve_recipe_recursive(db, ri.sub_recipe_id, total_needed, aggregated)

async def update_menu_availability_for_ingredient(db: Session, ingredient_id: int):
    """Checks all recipes containing this ingredient and updates availability."""
    # Find all root recipes that (recursively) use this ingredient
    # For performance in a real app, a reverse-map or pre-calc would be better.
    # Here we do a straightforward check.
    
    # Simple logic: If any ingredient is <= 0, related menu items might be disabled.
    ing = db.query(Ingredient).filter(Ingredient.id == ingredient_id).first()
    if not ing:
        return

    # Find recipes using this ingredient
    ris = db.query(RecipeIngredient).filter(RecipeIngredient.ingredient_id == ingredient_id).all()
    for ri in ris:
        # Find root recipe(s)
        root_recipes = _find_root_recipes(db, ri.recipe_id)
        for rr in root_recipes:
            # Check if this menu item MUST be disabled
            # We can re-check the full recipe availability here
            is_avail, reason = check_recipe_availability(db, rr.id)
            
            # Update MenuItemAvailability table
            avail = db.query(MenuItemAvailability).filter(MenuItemAvailability.menu_item_id == rr.menu_item_id).first()
            if not avail:
                avail = MenuItemAvailability(menu_item_id=rr.menu_item_id)
                db.add(avail)
            
            avail.is_available = is_avail
            avail.disabled_reason = reason if not is_avail else None
            
            # Also sync with MenuItem.is_available
            mi = db.query(MenuItem).filter(MenuItem.id == rr.menu_item_id).first()
            if mi:
                mi.is_available = is_avail

def _find_root_recipes(db: Session, current_recipe_id: int) -> List[Recipe]:
    """Climbs the recipe tree to find parent 'main' recipes."""
    recipe = db.query(Recipe).filter(Recipe.id == current_recipe_id).first()
    if not recipe:
        return []
        
    if recipe.recipe_type == "main":
        return [recipe]
    
    # It's a sub-recipe, find its parents
    parents = db.query(RecipeIngredient).filter(RecipeIngredient.sub_recipe_id == current_recipe_id).all()
    roots = []
    for p in parents:
        roots.extend(_find_root_recipes(db, p.recipe_id))
    return roots

def check_recipe_availability(db: Session, recipe_id: int) -> (bool, str):
    """Recursively checks if all ingredients for a recipe are in stock."""
    ingredients = db.query(RecipeIngredient).filter(RecipeIngredient.recipe_id == recipe_id).all()
    for ri in ingredients:
        if ri.ingredient_id:
            ing = db.query(Ingredient).filter(Ingredient.id == ri.ingredient_id).first()
            if not ing or ing.current_stock <= 0:
                return False, f"Out of Stock: {ing.name if ing else 'Unknown'}"
        elif ri.sub_recipe_id:
            avail, reason = check_recipe_availability(db, ri.sub_recipe_id)
            if not avail:
                return False, reason
    return True, None

async def process_purchase(db: Session, ingredient_id: int, quantity: float, rate: float, invoice_number: str = None):
    """Updates stock and running average cost."""
    ing = db.query(Ingredient).filter(Ingredient.id == ingredient_id).first()
    if not ing:
        return None
        
    old_stock = max(0, ing.current_stock)
    old_cost = ing.cost_per_unit
    
    # Running average cost formula
    # new_avg_cost = ((old_stock * old_cost) + (purchase_qty * purchase_rate)) / (old_stock + purchase_qty)
    total_qty = old_stock + quantity
    if total_qty > 0:
        new_cost = ((old_stock * old_cost) + (quantity * rate)) / total_qty
        ing.cost_per_unit = new_cost
    
    prev_stock = ing.current_stock
    ing.current_stock += quantity
    new_stock = ing.current_stock
    
    txn = StockTransaction(
        ingredient_id=ingredient_id,
        quantity=quantity,
        previous_stock=prev_stock,
        new_stock=new_stock,
        reference_type="purchase",
        reference_id=invoice_number,
        reason="stock-purchase",
        notes=f"Purchase entry. Invoice: {invoice_number}"
    )
    db.add(txn)
    
    # Check if this replenishes any menu items
    await update_menu_availability_for_ingredient(db, ingredient_id)
    
    db.commit()
    return ing

async def process_wastage(db: Session, ingredient_id: int, quantity: float, reason: str, notes: str = None):
    """Deducts stock due to wastage."""
    ing = db.query(Ingredient).filter(Ingredient.id == ingredient_id).first()
    if not ing:
        return None
        
    prev_stock = ing.current_stock
    ing.current_stock -= quantity
    new_stock = ing.current_stock
    
    txn = StockTransaction(
        ingredient_id=ingredient_id,
        quantity=-quantity,
        previous_stock=prev_stock,
        new_stock=new_stock,
        reference_type="wastage",
        reference_id=reason,
        reason=reason,
        notes=notes
    )
    db.add(txn)
    
    # Check if this disables any menu items
    await update_menu_availability_for_ingredient(db, ingredient_id)
    
    db.commit()
    return ing
