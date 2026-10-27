import sqlite3
import json
from backend.security.auth import get_password_hash

def reset_admin_credentials():
    conn = sqlite3.connect('restaurant_pos.db')
    cursor = conn.cursor()
    
    # Define roles for super admin and admin
    roles = [
        ("super_admin", json.dumps({"all": True})),
        ("admin", json.dumps({"all": True}))
    ]
    
    for name, perms in roles:
        try:
            cursor.execute("INSERT INTO roles (name, permissions) VALUES (?, ?)", (name, perms))
        except: 
            cursor.execute("UPDATE roles SET permissions = ? WHERE name = ?", (perms, name))
    
    # Define users
    users = [
        ("superadmin", "superadmin123", "super_admin"),
        ("admin", "admin123", "admin")
    ]
    
    for username, password, role in users:
        hashed = get_password_hash(password)
        # Check if user exists
        cursor.execute("SELECT id FROM users WHERE username = ?", (username,))
        row = cursor.fetchone()
        
        if row:
            cursor.execute("UPDATE users SET password_hash = ?, role = ? WHERE username = ?", (hashed, role, username))
            print(f"Updated user: {username} ({role}) with password: {password}")
        else:
            cursor.execute("INSERT INTO users (username, password_hash, role) VALUES (?, ?, ?)", (username, hashed, role))
            print(f"Created user: {username} ({role}) with password: {password}")
    
    conn.commit()
    conn.close()

if __name__ == "__main__":
    reset_admin_credentials()
