import sqlite3

def check_db():
    conn = sqlite3.connect('restaurant_pos.db')
    cursor = conn.cursor()
    
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
    tables = [t[0] for t in cursor.fetchall()]
    
    with open('tmp/db_audit.txt', 'w') as f:
        f.write(f"All tables found: {tables}\n\n")
        for table in tables:
            cursor.execute(f"SELECT COUNT(*) FROM {table}")
            count = cursor.fetchone()[0]
            f.write(f"Table {table}: {count} rows\n")
    
    conn.close()

if __name__ == "__main__":
    check_db()
