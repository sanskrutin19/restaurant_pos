import sqlite3
from backend.security.auth import get_password_hash

def seed_users():
    try:
        conn = sqlite3.connect('restaurant_pos.db')
        cursor = conn.cursor()
        
        users = [
            ("admin", "admin123", "admin"),
            ("kitchen", "kitchen123", "chef"),
            ("cashier", "cashier123", "cashier")
        ]
        
        for username, password, role in users:
            hashed = get_password_hash(password)
            try:
                cursor.execute(
                    "INSERT INTO users (username, password_hash, role) VALUES (?, ?, ?)",
                    (username, hashed, role)
                )
                print(f"User '{username}' created successfully with password '{password}' and role '{role}'")
            except sqlite3.IntegrityError:
                print(f"User '{username}' already exists, skipping...")
        
        conn.commit()
        conn.close()
    except Exception as e:
        print(f"Error seeding users: {e}")

if __name__ == "__main__":
    seed_users()
