from backend.database.core import SessionLocal
from backend.models.inventory import Ingredient
from backend.models.order import Order, OrderItem
from backend.models.catalog import MenuCategory, MenuItem
from backend.models.billing import Payment, Bill
from backend.models.system import Table, KitchenCounter
from backend.models.customer import Customer
from backend.models.user import User

def seed_inventory():
    db = SessionLocal()
    try:
        # Check if already seeded
        if db.query(Ingredient).count() > 0:
            print("Inventory already has items. Skipping seeding.")
            return

        ingredients = [
            Ingredient(name="Flour", unit="kg", current_stock=50.0, min_stock=10.0, cost_per_unit=45.0),
            Ingredient(name="Sugar", unit="kg", current_stock=20.0, min_stock=5.0, cost_per_unit=50.0),
            Ingredient(name="Rice", unit="kg", current_stock=100.0, min_stock=20.0, cost_per_unit=60.0),
            Ingredient(name="Chicken", unit="kg", current_stock=15.0, min_stock=5.0, cost_per_unit=220.0),
            Ingredient(name="Tomato", unit="kg", current_stock=10.0, min_stock=3.0, cost_per_unit=40.0),
            Ingredient(name="Potato", unit="kg", current_stock=30.0, min_stock=5.0, cost_per_unit=25.0),
            Ingredient(name="Onion", unit="kg", current_stock=25.0, min_stock=5.0, cost_per_unit=35.0),
            Ingredient(name="Garlic", unit="kg", current_stock=5.0, min_stock=1.0, cost_per_unit=120.0),
            Ingredient(name="Cooking Oil", unit="l", current_stock=40.0, min_stock=10.0, cost_per_unit=150.0),
            Ingredient(name="Milk", unit="l", current_stock=10.0, min_stock=2.0, cost_per_unit=60.0),
        ]

        db.add_all(ingredients)
        db.commit()
        print(f"Successfully seeded {len(ingredients)} ingredients.")
    except Exception as e:
        print(f"Error seeding inventory: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    seed_inventory()
