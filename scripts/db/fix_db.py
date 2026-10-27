import sqlite3
import os

db_path = "restaurant_pos.db"

def fix_db():
    if not os.path.exists(db_path):
        print(f"Database {db_path} not found.")
        return

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    try:
        print("Adding columns to customers...")
        cursor.execute("ALTER TABLE customers ADD COLUMN points INTEGER DEFAULT 0")
    except sqlite3.OperationalError: pass
    try:
        cursor.execute("ALTER TABLE customers ADD COLUMN visits_count INTEGER DEFAULT 0")
    except sqlite3.OperationalError: pass
    try:
        cursor.execute("ALTER TABLE customers ADD COLUMN created_at DATETIME DEFAULT CURRENT_TIMESTAMP")
    except sqlite3.OperationalError: pass

    try:
        cursor.execute("ALTER TABLE orders ADD COLUMN counter_id TEXT")
    except sqlite3.OperationalError: pass

    try:
        print("Adding columns to bills and payments...")
        cursor.execute("ALTER TABLE bills ADD COLUMN counter_id TEXT")
    except sqlite3.OperationalError: pass
    try:
        cursor.execute("ALTER TABLE payments ADD COLUMN counter_id TEXT")
    except sqlite3.OperationalError: pass

    conn.commit()
    conn.close()
    print("Database schema migration completed.")

if __name__ == "__main__":
    fix_db()
