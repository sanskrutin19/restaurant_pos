import sqlite3
conn = sqlite3.connect('restaurant_pos.db')
cursor = conn.cursor()

# Get existing columns
cursor.execute("PRAGMA table_info(kot_logs)")
columns = [row[1] for row in cursor.fetchall()]

# ALL columns from KOTLog model
required_columns = {
    'id': 'INTEGER PRIMARY KEY',
    'order_id': 'INTEGER',
    'version': 'INTEGER DEFAULT 1',
    'action': 'TEXT DEFAULT "created"',
    'items_snapshot': 'JSON',
    'added_items': 'JSON',
    'removed_items': 'JSON',
    'modified_items': 'JSON',
    'cancelled_by': 'INTEGER',
    'cancel_reason': 'TEXT',
    'captain_name': 'TEXT',
    'table_number': 'TEXT',
    'room_number': 'TEXT',
    'created_at': 'DATETIME'
}

for col, dtype in required_columns.items():
    if col not in columns:
        print(f"Adding column {col} to kot_logs...")
        cursor.execute(f"ALTER TABLE kot_logs ADD COLUMN {col} {dtype}")

conn.commit()
print("KOTLog table synchronization COMPLETE.")
conn.close()
