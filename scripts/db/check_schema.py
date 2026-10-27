import sqlite3
conn = sqlite3.connect('restaurant_pos.db')
cursor = conn.cursor()
for table in ['orders', 'order_items']:
    print(f"\nTable: {table}")
    cursor.execute(f"PRAGMA table_info({table})")
    for col in cursor.fetchall():
        print(f"  {col[0]}: {col[1]} ({col[2]})")
conn.close()
