import sqlite3

def check_db():
    conn = sqlite3.connect('restaurant_pos.db')
    cursor = conn.cursor()
    
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
    tables = [t[0] for t in cursor.fetchall()]
    print(f"All tables found: {tables}")
    
    for table in tables:
        cursor.execute(f"SELECT COUNT(*) FROM {table}")
        count = cursor.fetchone()[0]
        print(f"Table {table}: {count} rows")
    
    conn.close()

if __name__ == "__main__":
    check_db()
