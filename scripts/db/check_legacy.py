import sqlite3

def check_legacy_dbs():
    dbs = [
        'pos.db',
        'restaurant.db',
        'backend/restaurant_pos.db',
        'backend/database/pos.db'
    ]
    
    with open('tmp/legacy_audit.txt', 'w') as f:
        for db in dbs:
            f.write(f"--- Checking {db} ---\n")
            try:
                conn = sqlite3.connect(db)
                cursor = conn.cursor()
                cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
                tables = [t[0] for t in cursor.fetchall()]
                f.write(f"Tables: {tables}\n")
                
                for table in tables:
                    if any(kw in table.lower() for kw in ['ingredient', 'raw', 'stock', 'item']):
                        cursor.execute(f"SELECT COUNT(*) FROM {table}")
                        count = cursor.fetchone()[0]
                        f.write(f"  Table {table}: {count} rows\n")
                        if count > 0 and 'item' not in table.lower(): # Focus on ingredients
                             cursor.execute(f"SELECT * FROM {table} LIMIT 3")
                             f.write(f"    Sample: {cursor.fetchall()}\n")
                conn.close()
            except Exception as e:
                f.write(f"  Error: {e}\n")
            f.write("\n")

if __name__ == "__main__":
    check_legacy_dbs()
