import sqlite3
import json
from backend.security.auth import get_password_hash

def seed_manager_captain():
    conn = sqlite3.connect('restaurant_pos.db')
    cursor = conn.cursor()
    
    # 1. Ensure Roles exist
    # Sample matrix: {} which is everything by default for these roles unless specified.
    # Actually, permissions are just JSON in the 'permissions' column.
    
    roles = [
        ("MANAGER", json.dumps({"all": True})),
        ("CAPTAIN", json.dumps({"orders": True, "kot": True}))
    ]
    
    for name, perms in roles:
        try:
            cursor.execute("INSERT INTO roles (name, permissions) VALUES (?, ?)", (name, perms))
        except: pass
    
    # 2. Add Users
    users = [
        ("manager", "manager123", "MANAGER"),
        ("captain", "captain123", "CAPTAIN")
    ]
    
    for username, password, role in users:
        hashed = get_password_hash(password)
        try:
            cursor.execute("INSERT INTO users (username, password_hash, role) VALUES (?, ?, ?)", (username, hashed, role))
            print(f"Created user: {username} ({role})")
        except: pass
    
    conn.commit()
    conn.close()

if __name__ == "__main__":
    seed_manager_captain()
