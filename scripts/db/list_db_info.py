import sqlite3
import os

for db in ["restaurant_pos.db", "../restaurant_pos.db"]:
    print(f"\nChecking {db}...")
    if not os.path.exists(db):
        print("Not found")
        continue
    conn = sqlite3.connect(db)
    cursor = conn.cursor()
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
    tables = [t[0] for t in cursor.fetchall()]
    print(f"Tables: {tables}")
    if "kot_logs" in tables:
        cursor.execute("PRAGMA table_info(kot_logs)")
        print(f"kot_logs columns: {[c[1] for c in cursor.fetchall()]}")
    conn.close()
