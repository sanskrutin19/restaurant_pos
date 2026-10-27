import sqlite3
import os

db_path = 'restaurant_pos.db'
if not os.path.exists(db_path):
    print(f"Database {db_path} not found.")
    exit(1)

conn = sqlite3.connect(db_path)
cursor = conn.cursor()

def add_column(table, column, type, default=None):
    try:
        if default is not None:
            cursor.execute(f"ALTER TABLE {table} ADD COLUMN {column} {type} DEFAULT {default}")
        else:
            cursor.execute(f"ALTER TABLE {table} ADD COLUMN {column} {type}")
        print(f"Added {column} to {table}")
    except Exception as e:
        print(f"Could not add {column} to {table}: {e}")

# Fix order_items
add_column('order_items', 'status', 'VARCHAR', "'Pending'")

# Fix orders
add_column('orders', 'order_type', 'VARCHAR', "'dine_in'")

# Also check for customer_name/phone in orders (added in Phase 1/2)
add_column('orders', 'customer_name', 'VARCHAR')
add_column('orders', 'customer_phone', 'VARCHAR')

conn.commit()
conn.close()
print("Migration completed successfully.")
