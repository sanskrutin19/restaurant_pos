import sqlite3
import os

db_path = "restaurant_pos.db"
if os.path.exists(db_path):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    rooms = [
        ('101', 'First Floor', 50.0),
        ('102', 'First Floor', 50.0),
        ('201', 'Second Floor', 100.0),
        ('202', 'Second Floor', 100.0),
    ]
    
    for r in rooms:
        try:
            cursor.execute(
                "INSERT INTO rooms (room_number, floor, service_charge, status, is_active) VALUES (?, ?, ?, 'available', 1)",
                r
            )
            print(f"Added room {r[0]}")
        except sqlite3.IntegrityError:
            print(f"Room {r[0]} already exists")
            
    conn.commit()
    conn.close()
else:
    print("Database not found")
