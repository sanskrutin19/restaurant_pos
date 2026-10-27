from sqlalchemy.orm import Session
from backend.models.inventory import Ingredient, Recipe, RecipeIngredient
from backend.models.catalog import MenuItem

def suggest_and_create_recipe(db: Session, menu_item_id: int, item_name: str):
    """
    Automatically suggests and creates a recipe for a new menu item based on its name.
    Uses keyword matching to avoid 'fake' or 'dummy' data.
    """
    name = item_name.lower()
    ingredients_to_add = []

    # 1. Map keywords to ingredients and typical quantities
    # Format: (keyword, ingredient_name, qty, unit)
    knowledge_base = [
        # --- Indian ---
        ("paneer", "Paneer", 0.15, "kg"), ("paneer", "Milk", 0.05, "l"), ("paneer", "Tomato", 0.05, "kg"),
        ("chicken", "Chicken", 0.2, "kg"), ("chicken", "Cooking Oil", 0.03, "l"), ("chicken", "Garlic", 0.01, "kg"),
        ("mutton", "Mutton", 0.2, "kg"), ("mutton", "Onion", 0.05, "kg"), ("mutton", "Cooking Oil", 0.04, "l"),
        ("dal", "Onion", 0.02, "kg"), ("dal", "Garlic", 0.01, "kg"),
        ("biryani", "Rice", 0.2, "kg"), ("biryani", "Yogurt", 0.05, "kg"), ("biryani", "Onion", 0.03, "kg"),
        ("dosa", "Rice", 0.1, "kg"), ("dosa", "Potato", 0.05, "kg"),
        ("roti", "Flour", 0.1, "kg"), ("naan", "Flour", 0.15, "kg"), ("naan", "Garlic", 0.01, "kg"),
        ("papad", "Flour", 0.05, "kg"),
        # --- Chinese ---
        ("manchurian", "Cabbage", 0.1, "kg"), ("manchurian", "Flour", 0.05, "kg"), ("manchurian", "Cooking Oil", 0.03, "l"),
        ("gobi", "Cauliflower", 0.2, "kg"), ("noodles", "Noodles", 0.15, "kg"), ("noodles", "Cabbage", 0.02, "kg"),
        ("fried rice", "Rice", 0.15, "kg"), ("fried rice", "Cooking Oil", 0.03, "l"),
        ("prawn", "Prawn", 0.15, "kg"), ("prawn", "Garlic", 0.01, "kg"),
        # --- Continental/Italian ---
        ("pasta", "Pasta", 0.15, "kg"), ("pasta", "Cheese", 0.03, "kg"), ("pasta", "Cream", 0.05, "l"),
        ("pizza", "Flour", 0.2, "kg"), ("pizza", "Cheese", 0.05, "kg"), ("pizza", "Tomato", 0.05, "kg"),
        ("burger", "Potato", 0.1, "kg"), ("burger", "Cheese", 0.02, "kg"), ("burger", "Bread", 1.0, "pcs"),
        ("sandwich", "Bread", 2.0, "pcs"), ("sandwich", "Cheese", 0.02, "kg"),
        ("fries", "Potato", 0.2, "kg"), ("fries", "Cooking Oil", 0.05, "l"),
        ("fish", "Fish", 0.2, "kg"), ("fish", "Lemon", 0.5, "pcs"),
        # --- Beverages/Desserts ---
        ("icecre", "Milk", 0.1, "l"), ("icecre", "Sugar", 0.02, "kg"),
        ("tea", "Milk", 0.1, "l"), ("tea", "Sugar", 0.01, "kg"),
        ("coffee", "Milk", 0.15, "l"), ("coffee", "Sugar", 0.01, "kg"),
        ("juice", "Sugar", 0.02, "kg"), ("shake", "Milk", 0.2, "l"), ("shake", "Sugar", 0.02, "kg"),
        # --- Others ---
        ("salad", "Tomato", 0.05, "kg"), ("salad", "Cucumber", 0.05, "kg"), ("salad", "Lemon", 0.5, "pcs"),
    ]

    # 1.1 Match keywords
    matched_ingredients = []
    for kw, ing_name, qty, unit in knowledge_base:
        if kw in name:
            matched_ingredients.append((ing_name, qty, unit))

    if not matched_ingredients:
        return None  # No confident suggestion

    # 2. Create the Recipe
    recipe = Recipe(
        menu_item_id=menu_item_id,
        name=f"Auto-generated Recipe for {item_name}",
        yield_qty=1.0,
        yield_unit="serving",
        recipe_type="main"
    )
    db.add(recipe)
    db.flush()

    # 3. Link ingredients (CREATE THEM if they don't exist)
    for ing_name, qty, unit in matched_ingredients:
        ing = db.query(Ingredient).filter(Ingredient.name == ing_name).first()
        
        if not ing:
            # Create the missing ingredient automatically
            ing = Ingredient(
                name=ing_name,
                unit=unit,
                current_stock=0.0,
                min_stock=5.0,
                cost_per_unit=0.0
            )
            db.add(ing)
            db.flush() # Get the new ID

        ri = RecipeIngredient(
            recipe_id=recipe.id,
            ingredient_id=ing.id,
            quantity=qty,
            unit=unit
        )
        db.add(ri)
    
    db.commit()
    return recipe
