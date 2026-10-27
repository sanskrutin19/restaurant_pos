import sqlite3

conn = sqlite3.connect("restaurant_pos.db")
try:
    conn.execute('ALTER TABLE orders ADD COLUMN order_type TEXT DEFAULT "dine_in"')
    conn.commit()
    print("Column order_type added successfully")
except Exception as e:
    print(f"Note: {e}")
conn.close()
