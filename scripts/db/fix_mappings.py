import sqlite3

def fix_all_mappings():
    conn = sqlite3.connect('restaurant_pos.db')
    c = conn.cursor()

    # Create Drinks Counter
    c.execute("INSERT OR IGNORE INTO kitchen_counters (id, name, is_active) VALUES (4, 'Drinks Counter', 1)")

    # HARD RE-INSERT (to clear any corrupt or hidden metadata on Starters and Desserts)
    c.execute("DELETE FROM menu_categories WHERE id IN (1, 3)")
    c.execute("INSERT INTO menu_categories (id, name, kitchen_counter_id) VALUES (1, 'Starters', 3)")
    c.execute("INSERT INTO menu_categories (id, name, kitchen_counter_id) VALUES (3, 'Desserts', 2)")
    print("Hard recreated Starters and Desserts!")

    # Corrected swapping for the specific IDs found in DB:
    # 1: Drinks Counter
    # 4: Main Course
    
    mapping = {
        2: 4, # Main Course Category -> Main Course Counter (ID 4)
        4: 1  # Drinks Category -> Drinks Counter (ID 1)
    }
    
    for cat_id, counter_id in mapping.items():
        c.execute("UPDATE menu_categories SET kitchen_counter_id = ? WHERE id = ?", (counter_id, cat_id))
    print("Success: Corrected cross-wired mappings (Main Course <> Drinks)!")
    
    # Ensure all items in those categories are points back to the re-inserted ones
    # (Since we deleted and re-inserted with same IDs, this should be fine but let's re-verify)
    c.execute("UPDATE menu_items SET category_id = 1 WHERE category_id IS NULL AND name LIKE '%Starter%'")
    c.execute("UPDATE menu_items SET category_id = 3 WHERE category_id IS NULL AND name LIKE '%Dessert%'")
    
    # Clear item-level overrides so they inherit from category
    c.execute("UPDATE menu_items SET kitchen_counter_id = NULL")
    print("Success: Mappings and inheritance fixed.")

    conn.commit()
    conn.close()

if __name__ == '__main__':
    fix_all_mappings()
