import sqlite3

def run_sql_seed():
    conn = sqlite3.connect('restaurant_pos.db')
    cursor = conn.cursor()
    
    # Map of menu_item name -> [(ingredient_name, qty, unit)]
    recipes = {
        "Masala Papad": [("Flour", 0.05, "kg"), ("Onion", 0.02, "kg"), ("Tomato", 0.02, "kg")],
        "Roasted Papad": [("Flour", 0.05, "kg")],
        "Paneer Butter Masala": [("Milk", 0.2, "l"), ("Tomato", 0.1, "kg"), ("Onion", 0.05, "kg"), ("Garlic", 0.01, "kg")],
        "Peri Peri Fries(M)": [("Potato", 0.2, "kg"), ("Cooking Oil", 0.05, "l")],
        "Tandoori Roti": [("Flour", 0.1, "kg")],
        "Butter Roti": [("Flour", 0.1, "kg"), ("Milk", 0.02, "l")],
        "Garlic Naan": [("Flour", 0.15, "kg"), ("Garlic", 0.02, "kg")],
        "Paneer Tikka Masala": [("Milk", 0.15, "l"), ("Tomato", 0.1, "kg"), ("Onion", 0.05, "kg"), ("Garlic", 0.01, "kg")],
        "Belgium Chocolate IceCream": [("Milk", 0.1, "l"), ("Sugar", 0.02, "kg")],
        "Masala Dosa": [("Rice", 0.15, "kg"), ("Cooking Oil", 0.05, "l"), ("Potato", 0.1, "kg"), ("Onion", 0.03, "kg"), ("Garlic", 0.01, "kg")],
        "Gobi Manchurian": [("Cauliflower", 0.2, "kg"), ("Cabbage", 0.05, "kg"), ("Flour", 0.05, "kg"), ("Cooking Oil", 0.03, "l")],
        "Hara bhara Kabab": [("Spinach", 0.1, "kg"), ("Green Peas", 0.05, "kg"), ("Potato", 0.05, "kg")]
    }
    
    successful = 0
    for item_name, ings in recipes.items():
        # Get Item ID
        cursor.execute("SELECT id FROM menu_items WHERE name=?", (item_name,))
        item_row = cursor.fetchone()
        if not item_row:
            continue
        item_id = item_row[0]
        
        # Check if already has a recipe
        cursor.execute("SELECT id FROM recipes WHERE menu_item_id=?", (item_id,))
        if cursor.fetchone():
            continue
            
        # Create Recipe
        cursor.execute("""
            INSERT INTO recipes (menu_item_id, name, yield_qty, yield_unit, recipe_type)
            VALUES (?, ?, ?, ?, ?)
        """, (item_id, f"{item_name} Recipe", 1.0, "serving", "main"))
        recipe_id = cursor.lastrowid
        
        # Add Ingredients
        for ing_name, qty, unit in ings:
            cursor.execute("SELECT id FROM ingredients WHERE name=?", (ing_name,))
            ing_row = cursor.fetchone()
            if ing_row:
                ing_id = ing_row[0]
                cursor.execute("""
                    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, quantity, unit)
                    VALUES (?, ?, ?, ?)
                """, (recipe_id, ing_id, qty, unit))
        
        successful += 1
        print(f"Created recipe for {item_name}")
        
    conn.commit()
    conn.close()
    print(f"Successfully seeded {successful} recipes.")

if __name__ == "__main__":
    run_sql_seed()
