import sqlite3
import os

db_path = 'restaurant_pos.db'
if not os.path.exists(db_path):
    print("Database not found!")
    exit(1)

conn = sqlite3.connect(db_path)
cursor = conn.cursor()

# Set PINs
cursor.execute("UPDATE users SET pin = '1234' WHERE username = 'admin'")
cursor.execute("UPDATE users SET pin = '4321' WHERE username = 'manager'")
conn.commit()

# Verify
cursor.execute("SELECT username, pin FROM users WHERE username IN ('admin', 'manager')")
for row in cursor.fetchall():
    print(f"User: {row[0]}, PIN: {row[1]}")

conn.close()
