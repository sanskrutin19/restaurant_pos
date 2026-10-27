import json
import sqlite3
import os

# 1. Load the full set of items (280+) from the dump
with open('data/menu_dump.json', 'r') as f:
    full_dump = json.load(f)

# 2. Map existing descriptions from the current DB
db = sqlite3.connect('restaurant_pos.db')
cursor = db.cursor()
existing_data = cursor.execute("SELECT name, description FROM menu_items").fetchall()
desc_map = {name: desc for name, desc in existing_data if desc}
db.close()

# 3. Handle name fixes
NAME_FIXES = {
    ("Pizza", "Barbeque Chicken"): "Barbeque Chicken Pizza",
    ("Bruschettas", "Barbeque Chicken"): "Barbeque Chicken Bruschetta",
    ("Risotto", "Grilled Chicken"): "Grilled Chicken Risotto",
    ("Sandwiches", "Grilled Chicken"): "Grilled Chicken Sandwich",
    ("Dessert's", "Sizzling Brwnie"): "Sizzling Brownie",
    ("Dessert's", "Sizzling Brownie"): "Sizzling Brownie"
}

recovered_menu = {}
for cat_name, items in full_dump.items():
    recovered_menu[cat_name] = []
    for item in items:
        name = item[0]
        price = item[1]
        tax_enabled = item[2]
        tax_percentage = item[3]
        
        fixed_name = NAME_FIXES.get((cat_name, name), name)
        desc = desc_map.get(fixed_name) or desc_map.get(name) or ""
        
        recovered_menu[cat_name].append([
            fixed_name,
            price,
            tax_enabled,
            tax_percentage,
            desc
        ])

# 4. Update seeder.py (Safer)
dict_str = json.dumps(recovered_menu, indent=8)
dict_str = dict_str.replace('true,', 'True,').replace('false,', 'False,')

with open('backend/services/seeder.py', 'r') as f:
    lines = f.readlines()

start_idx = -1
end_idx = -1
for i, line in enumerate(lines):
    if "full_menu_data =" in line:
        start_idx = i
    if start_idx != -1 and line.strip() == "}":
        end_idx = i
        break

if start_idx != -1 and end_idx != -1:
    new_lines = lines[:start_idx] + ["    full_menu_data = " + dict_str + "\n"] + lines[end_idx+1:]
    with open('backend/services/seeder.py', 'w') as f:
        f.writelines(new_lines)
    print("seeder.py RECOVERED.")

# 5. Re-seed DB
from backend.database.core import SessionLocal
from backend.services.seeder import seed_initial_data

db = sqlite3.connect('restaurant_pos.db')
db.execute("DELETE FROM menu_items")
db.execute("DELETE FROM menu_categories")
db.execute("DELETE FROM kitchen_counters")
db.commit()
db.close()

session = SessionLocal()
seed_initial_data(session)
session.close()
print("Database FULLY RECOVERED.")
