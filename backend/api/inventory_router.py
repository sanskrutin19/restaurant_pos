from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional, Dict
from pydantic import BaseModel
from backend.database.core import get_db
from backend.models.inventory import Ingredient, Recipe, RecipeIngredient, StockTransaction, MenuItemAvailability
from backend.models.system import AuditLog
from backend.services.inventory import deduct_stock_for_bill, process_purchase, process_wastage

router = APIRouter(prefix="/admin/inventory", tags=["Inventory"])

def log_audit(db: Session, action: str, entity: str, entity_id: int, description: str, user_id: Optional[int] = None, details: dict = None):
    # Default to user_id=1 (admin) if not provided, but allow null if it's a guest
    audit = AuditLog(
        action=action,
        entity=entity,
        entity_id=entity_id,
        description=description,
        user_id=user_id if user_id is not None else None,
        details=details
    )
    db.add(audit)
    db.commit()


# --- Schemas ---
class IngredientCreate(BaseModel):
    name: str
    unit: str = "kg"
    current_stock: float = 0.0
    min_stock: float = 5.0
    cost_per_unit: float = 0.0

class IngredientResponse(BaseModel):
    id: int
    name: str
    unit: str
    current_stock: float
    min_stock: float
    cost_per_unit: float
    is_low_stock: bool = False

    class Config:
        from_attributes = True

class IngredientUpdate(BaseModel):
    name: Optional[str] = None
    unit: Optional[str] = None
    current_stock: Optional[float] = None
    min_stock: Optional[float] = None
    cost_per_unit: Optional[float] = None

class RecipeIngredientIn(BaseModel):
    ingredient_id: Optional[int] = None
    sub_recipe_id: Optional[int] = None
    quantity: float
    unit: str
    stage: str = "cook"
    yield_factor: float = 1.0

class RecipeIn(BaseModel):
    menu_item_id: int
    name: str
    yield_qty: float = 1.0
    yield_unit: str = "serving"
    recipe_type: str = "main"
    ingredients: List[RecipeIngredientIn]

class PurchaseIn(BaseModel):
    ingredient_id: int
    quantity: float
    rate: float
    invoice_number: Optional[str] = None

class WastageIn(BaseModel):
    ingredient_id: int
    quantity: float
    reason: str
    notes: Optional[str] = None

# --- Endpoints ---

@router.get("/ingredients", response_model=List[IngredientResponse])
def list_ingredients(db: Session = Depends(get_db)):
    ingredients = db.query(Ingredient).all()
    results = []
    for ing in ingredients:
        resp = IngredientResponse(
            id=ing.id,
            name=ing.name,
            unit=ing.unit,
            current_stock=ing.current_stock,
            min_stock=ing.min_stock,
            cost_per_unit=ing.cost_per_unit,
            is_low_stock=ing.current_stock <= ing.min_stock,
        )
        results.append(resp)
    return results

@router.post("/ingredients", response_model=IngredientResponse)
def create_ingredient(data: IngredientCreate, db: Session = Depends(get_db)):
    ing = Ingredient(**data.model_dump())
    db.add(ing)
    db.commit()
    db.refresh(ing)
    log_audit(db, "CREATE", "inventory", ing.id, f"Added new ingredient: {ing.name}")
    return IngredientResponse(
        id=ing.id, name=ing.name, unit=ing.unit,
        current_stock=ing.current_stock, min_stock=ing.min_stock,
        cost_per_unit=ing.cost_per_unit,
        is_low_stock=ing.current_stock <= ing.min_stock,
    )

@router.put("/ingredients/{ingredient_id}", response_model=IngredientResponse)
def update_ingredient(ingredient_id: int, data: IngredientUpdate, db: Session = Depends(get_db)):
    ing = db.query(Ingredient).filter(Ingredient.id == ingredient_id).first()
    if not ing:
        raise HTTPException(status_code=404, detail="Ingredient not found")
    
    update_data = data.model_dump(exclude_none=True)
    for key, value in update_data.items():
        setattr(ing, key, value)
    
    db.commit()
    db.refresh(ing)
    
    # NEW: Better audit log message if only stock was updated
    if len(update_data) == 1 and "current_stock" in update_data:
        log_audit(db, "ADJUST", "inventory", ing.id, f"Stock adjusted for {ing.name} to {ing.current_stock}")
    else:
        log_audit(db, "UPDATE", "inventory", ing.id, f"Updated details for: {ing.name}")
        
    return IngredientResponse(
        id=ing.id, name=ing.name, unit=ing.unit,
        current_stock=ing.current_stock, min_stock=ing.min_stock,
        cost_per_unit=ing.cost_per_unit,
        is_low_stock=ing.current_stock <= ing.min_stock,
    )

@router.delete("/ingredients/{ingredient_id}")
def delete_ingredient(ingredient_id: int, db: Session = Depends(get_db)):
    ing = db.query(Ingredient).filter(Ingredient.id == ingredient_id).first()
    if not ing:
        raise HTTPException(status_code=404, detail="Ingredient not found")
    
    name = ing.name
    db.delete(ing)
    db.commit()
    log_audit(db, "DELETE", "inventory", ingredient_id, f"Permanently deleted ingredient: {name}")
    return {"message": "Ingredient deleted"}

@router.post("/recipes", response_model=Dict[str, str])
def create_recipe(data: RecipeIn, db: Session = Depends(get_db)):
    # 1. Create root Recipe
    recipe = Recipe(
        menu_item_id=data.menu_item_id,
        name=data.name,
        yield_qty=data.yield_qty,
        yield_unit=data.yield_unit,
        recipe_type=data.recipe_type
    )
    db.add(recipe)
    db.flush() # Get recipe ID

    # 2. Add ingredients
    for item in data.ingredients:
        ri = RecipeIngredient(
            recipe_id=recipe.id,
            ingredient_id=item.ingredient_id,
            sub_recipe_id=item.sub_recipe_id,
            quantity=item.quantity,
            unit=item.unit,
            stage=item.stage,
            yield_factor=item.yield_factor
        )
        db.add(ri)
    
    db.commit()
    return {"message": "Recipe created successfully"}

@router.get("/recipes/{menu_item_id}")
def get_recipe(menu_item_id: int, db: Session = Depends(get_db)):
    recipe = db.query(Recipe).filter(Recipe.menu_item_id == menu_item_id, Recipe.recipe_type == "main").first()
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")
    
    ingredients = db.query(RecipeIngredient).filter(RecipeIngredient.recipe_id == recipe.id).all()
    # Expand ingredients/sub-recipes details if needed
    return {
        "recipe": recipe,
        "ingredients": ingredients
    }

@router.post("/deduct-stock-for-bill")
async def deduct_stock(bill_id: int, db: Session = Depends(get_db)):
    from backend.models.billing import Bill
    bill = db.query(Bill).filter(Bill.id == bill_id).first()
    if not bill:
        raise HTTPException(status_code=404, detail="Bill not found")
    
    results = await deduct_stock_for_bill(db, bill)
    return {"message": "Stock deducted", "results": results}

@router.post("/purchase")
async def add_purchase(data: PurchaseIn, db: Session = Depends(get_db)):
    ing = await process_purchase(db, data.ingredient_id, data.quantity, data.rate, data.invoice_number)
    if not ing:
        raise HTTPException(status_code=404, detail="Ingredient not found")
    return {"message": "Purchase entry saved", "new_stock": ing.current_stock}

@router.post("/wastage")
async def add_wastage(data: WastageIn, db: Session = Depends(get_db)):
    ing = await process_wastage(db, data.ingredient_id, data.quantity, data.reason, data.notes)
    if not ing:
        raise HTTPException(status_code=404, detail="Ingredient not found")
    return {"message": "Wastage entry saved", "new_stock": ing.current_stock}

@router.get("/low-stock")
def get_low_stock(db: Session = Depends(get_db)):
    items = db.query(Ingredient).filter(Ingredient.current_stock <= Ingredient.min_stock).all()
    return items

@router.get("/menu-availability")
def get_menu_availability(db: Session = Depends(get_db)):
    avails = db.query(MenuItemAvailability).all()
    return avails

@router.post("/reset")
def reset_inventory(db: Session = Depends(get_db)):
    db.query(StockTransaction).delete()
    db.query(RecipeIngredient).delete()
    db.query(Recipe).delete()
    db.query(MenuItemAvailability).delete()
    db.query(Ingredient).delete()
    db.commit()
    log_audit(db, "DELETE", "inventory", 0, "Inventory system reset")
    return {"message": "Inventory reset successfully"}
