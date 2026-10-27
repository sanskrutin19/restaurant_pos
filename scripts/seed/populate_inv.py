from backend.database.core import SessionLocal
from backend.models.inventory import Ingredient

def populate_missing():
    db = SessionLocal()
    items = [
        ("Flour", "kg", 50.0, 10.0, 45.0),
        ("Sugar", "kg", 20.0, 5.0, 50.0),
        ("Chicken", "kg", 15.0, 5.0, 220.0),
        ("Tomato", "kg", 10.0, 3.0, 40.0),
        ("Potato", "kg", 30.0, 5.0, 25.0),
        ("Onion", "kg", 25.0, 5.0, 35.0),
        ("Garlic", "kg", 5.0, 1.0, 120.0),
        ("Cooking Oil", "l", 40.0, 10.0, 150.0),
        ("Milk", "l", 10.0, 2.0, 60.0),
    ]
    
    for name, unit, stock, min_s, cost in items:
        # Avoid duplicate "Rice" or any already existing manually
        if not db.query(Ingredient).filter(Ingredient.name == name).first():
            db.add(Ingredient(name=name, unit=unit, current_stock=stock, min_stock=min_s, cost_per_unit=cost))
            print(f"Added {name}")
    
    db.commit()
    db.close()
    print("Done.")

if __name__ == "__main__":
    populate_missing()
