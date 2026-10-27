import sqlite3
import os

db_path = "restaurant_pos.db"
if os.path.exists(db_path):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute("PRAGMA table_info(kot_logs)")
    columns = cursor.fetchall()
    print("Columns in kot_logs:")
    for col in columns:
        print(f"Col {col[0]}: {col[1]} ({col[2]}) - {'NOT NULL' if col[3] else 'NULLABLE'} - Default: {col[4]}")
    conn.close()
else:
    print(f"{db_path} not found")
