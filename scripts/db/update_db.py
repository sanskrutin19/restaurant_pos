import sqlite3
conn = sqlite3.connect('restaurant_pos.db')
cursor = conn.cursor()

# Get existing columns
cursor.execute("PRAGMA table_info(kot_logs)")
columns = [row[1] for row in cursor.fetchall()]

missing_columns = {
    'cancel_reason': 'TEXT',
    'cancelled_by': 'INTEGER',
    'captain_name': 'TEXT',
    'table_number': 'TEXT',
    'room_number': 'TEXT',
    'items_snapshot': 'JSON',
    'added_items': 'JSON',
    'removed_items': 'JSON',
    'modified_items': 'JSON'
}

for col, dtype in missing_columns.items():
    if col not in columns:
        print(f"Adding column {col} to kot_logs...")
        cursor.execute(f"ALTER TABLE kot_logs ADD COLUMN {col} {dtype}")

conn.commit()
print("KOTLog table columns synchronized successfully.")
conn.close()
