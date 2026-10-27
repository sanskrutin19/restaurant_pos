import json
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from backend.models.catalog import MenuCategory, MenuItem

# Database setup
DB_URL = "sqlite:///./restaurant_pos.db"
engine = create_engine(DB_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
db = SessionLocal()

def extract():
    data = {}
    categories = db.query(MenuCategory).order_by(MenuCategory.id).all()
    
    for cat in categories:
        items = db.query(MenuItem).filter(MenuItem.category_id == cat.id).all()
        # Storing as list of (name, price, tax_enabled, tax_percentage)
        data[cat.name] = [(i.name, i.price, i.tax_enabled, i.tax_percentage) for i in items]
    
    # Save to a temporary python file format that I can copy-paste into seeder.py
    with open("data/menu_dump.json", "w", encoding="utf-8") as f:
        json.dump(data, f, indent=4)
        
    print(f"Extracted {len(data)} categories.")

if __name__ == "__main__":
    extract()
    db.close()
