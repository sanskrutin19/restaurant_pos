import sqlite3

def check_db():
    conn = sqlite3.connect('restaurant_pos.db')
    cursor = conn.cursor()
    
    # 1. List all tables
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
    tables = cursor.fetchall()
    print(f"Tables found: {[t[0] for t in tables]}")
    
    # 2. Check each table for keywords like 'ingredient', 'raw', 'stock'
    for table in [t[0] for t in tables]:
        if any(keyword in table.lower() for keyword in ['ingredient', 'raw', 'stock']):
            cursor.execute(f"SELECT COUNT(*) FROM {table}")
            count = cursor.fetchone()[0]
            print(f"Table '{table}' has {count} records")
            if count > 0:
                print(f"Sample data for {table}:")
                cursor.execute(f"SELECT * FROM {table} LIMIT 5")
                print(cursor.fetchall())
    
    conn.close()

if __name__ == "__main__":
    check_db()
