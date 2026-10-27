import sqlite3
from backend.database.core import SessionLocal
from backend.models.catalog import MenuItem
from backend.models.inventory import Ingredient, Recipe, RecipeIngredient

def seed_recipes():
    db = SessionLocal()
    try:
        # Helper to get ingredient id by name
        def get_ing_id(name):
            ing = db.query(Ingredient).filter(Ingredient.name == name).first()
            return ing.id if ing else None

        # Data for recipes
        recipe_data = {
            "Masala Papad": [("Flour", 0.05, "kg"), ("Onion", 0.02, "kg"), ("Tomato", 0.02, "kg")],
            "Roasted Papad": [("Flour", 0.05, "kg")],
            "Paneer Butter Masala": [("Milk", 0.2, "l"), ("Tomato", 0.1, "kg"), ("Onion", 0.05, "kg"), ("Garlic", 0.01, "kg")],
            "Peri Peri Fries(M)": [("Potato", 0.2, "kg"), ("Cooking Oil", 0.05, "l")],
            "Tandoori Roti": [("Flour", 0.1, "kg")],
            "Butter Roti": [("Flour", 0.1, "kg"), ("Milk", 0.02, "l")],
            "Garlic Naan": [("Flour", 0.15, "kg"), ("Garlic", 0.02, "kg")],
            "Paneer Tikka Masala": [("Milk", 0.15, "l"), ("Tomato", 0.1, "kg"), ("Onion", 0.05, "kg"), ("Garlic", 0.01, "kg")],
            "Belgium Chocolate IceCream": [("Milk", 0.1, "l"), ("Sugar", 0.02, "kg")],
            "Masala Dosa": [("Rice", 0.15, "kg"), ("Cooking Oil", 0.05, "l"), ("Potato", 0.1, "kg"), ("Onion", 0.03, "kg"), ("Garlic", 0.01, "kg")]
        }

        for item_name, ingredients in recipe_data.items():
            menu_item = db.query(MenuItem).filter(MenuItem.name == item_name).first()
            if not menu_item:
                print(f"Skipping {item_name} (not in menu)")
                continue
            
            # Check if recipe already exists
            existing = db.query(Recipe).filter(Recipe.menu_item_id == menu_item.id).first()
            if existing:
                print(f"Recipe for {item_name} already exists.")
                continue

            # Create Recipe
            recipe = Recipe(
                menu_item_id=menu_item.id,
                name=f"{item_name} Recipe",
                yield_qty=1.0,
                yield_unit="serving",
                recipe_type="main"
            )
            db.add(recipe)
            db.flush()

            # Add recipe ingredients
            for ing_name, qty, unit in ingredients:
                ing_id = get_ing_id(ing_name)
                if ing_id:
                    ri = RecipeIngredient(
                        recipe_id=recipe.id,
                        ingredient_id=ing_id,
                        quantity=qty,
                        unit=unit
                    )
                    db.add(ri)
            
            print(f"Created recipe for {item_name}")

        db.commit()
        print("Initial recipes seeded.")
    except Exception as e:
        print(f"Error seeding recipes: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    seed_recipes()
