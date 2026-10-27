import sqlite3
from backend.database.core import engine, Base
from backend.models.kot import KOTLog
import time

def recreate():
    conn = sqlite3.connect('restaurant_pos.db')
    cursor = conn.cursor()
    cursor.execute("DROP TABLE IF EXISTS kot_logs")
    conn.commit()
    conn.close()
    
    print("Table kot_logs dropped. Recreating from models...")
    Base.metadata.create_all(bind=engine)
    print("Table recreated.")

if __name__ == "__main__":
    recreate()
