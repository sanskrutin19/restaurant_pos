import sys
import os
import sqlite3

# Ensure we can import from backend
sys.path.append(os.getcwd())

from backend.database.core import engine, Base
from backend.models import catalog, order, billing, inventory, system

db_files = ['restaurant_pos.db', 'backend/restaurant_pos.db']

def repair_database(db_path):
    if not os.path.exists(db_path):
        print(f"Skipping {db_path} (does not exist)")
        return
    
    print(f"\nRepairing database: {db_path}")
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    def add_col(table, col, dtype, default=None):
        try:
            if default is not None:
                 cursor.execute(f"ALTER TABLE {table} ADD COLUMN {col} {dtype} DEFAULT {default}")
            else:
                 cursor.execute(f"ALTER TABLE {table} ADD COLUMN {col} {dtype}")
            print(f"  [+] Added {col} to {table}")
        except Exception as e:
            if "duplicate column name" in str(e):
                print(f"  [ ] Column {col} already exists in {table}")
            elif "no such table" in str(e):
                print(f"  [!] Table {table} missing - will be created by create_all")
            else:
                print(f"  [!] Error adding {col} to {table}: {e}")

    # Ensure critical columns exist
    add_col('menu_items', 'kitchen_counter_id', 'INTEGER')
    add_col('menu_items', 'low_stock_threshold', 'INTEGER', 5)
    add_col('menu_items', 'stock_level', 'INTEGER', 100)
    add_col('order_items', 'status', 'VARCHAR', "'Pending'")
    add_col('order_items', 'is_sent_to_kitchen', 'BOOLEAN', 0)
    add_col('orders', 'order_type', 'VARCHAR', "'dine_in'")
    add_col('orders', 'customer_name', 'VARCHAR')
    add_col('orders', 'customer_phone', 'VARCHAR')
    add_col('orders', 'counter_id', 'VARCHAR')
    add_col('orders', 'shift_id', 'INTEGER')
    add_col('orders', 'held_at', 'DATETIME')
    add_col('users', 'pin', 'VARCHAR')
    add_col('users', 'hourly_rate', 'FLOAT', 100.0)
    add_col('users', 'tips_earned', 'FLOAT', 0.0)
    add_col('users', 'reset_code', 'VARCHAR')
    
    # KOT Logs repair
    add_col('kot_logs', 'version', 'INTEGER', 1)
    add_col('kot_logs', 'items_snapshot', 'JSON')
    add_col('kot_logs', 'added_items', 'JSON')
    add_col('kot_logs', 'removed_items', 'JSON')
    add_col('kot_logs', 'modified_items', 'JSON')
    add_col('kot_logs', 'captain_name', 'VARCHAR')
    add_col('kot_logs', 'table_number', 'VARCHAR')
    add_col('kot_logs', 'room_number', 'VARCHAR')

    conn.commit()
    conn.close()

# 1. First ensure all tables exist in all potential databases via SQLAlchemy
# We run it twice, once for each candidate folder if relevant
for db_f in db_files:
    repair_database(db_f)

print("\nRunning Base.metadata.create_all for current engine...")
Base.metadata.create_all(bind=engine)

print("\nDatabase repair complete.")
