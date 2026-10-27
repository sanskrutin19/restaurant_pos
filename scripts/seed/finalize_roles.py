import sqlite3
import json
from backend.security.auth import get_password_hash

def finalize_roles_and_users():
    conn = sqlite3.connect('restaurant_pos.db')
    cursor = conn.cursor()
    
    # 1. Clear existing roles and users to start fresh as requested
    cursor.execute("DELETE FROM roles")
    cursor.execute("DELETE FROM users")
    
    # 2. Define the exact FIVE roles requested
    # Permissions matrix based on the new management screen requirements
    full_perms = {
        "can_create_order": True, "can_edit_order": True, "can_delete_order": True,
        "can_print_kot": True, "can_cancel_kot": True, "can_apply_discount": True,
        "can_apply_large_discount": True, "can_change_tax": True, "can_settle_bill": True,
        "can_view_reports": True, "can_manage_tables": True, "can_manage_users": True,
        "can_manage_menu": True, "can_view_management": True
    }
    
    manager_perms = full_perms.copy()
    manager_perms.pop("can_manage_users", None) # Managers can't delete admins etc.
    
    cashier_perms = {
        "can_create_order": True, "can_edit_order": True, "can_print_kot": True,
        "can_apply_discount": True, "can_settle_bill": True, "can_view_reports": True
    }
    
    captain_perms = {
        "can_create_order": True, "can_edit_order": True, "can_print_kot": True,
        "can_manage_tables": True
    }
    
    kitchen_perms = {
        "can_print_kot": True, "can_view_management": False # KDS has its own view
    }

    roles_data = [
        ("ADMIN", json.dumps(full_perms)),
        ("MANAGER", json.dumps(manager_perms)),
        ("CASHIER", json.dumps(cashier_perms)),
        ("CAPTAIN", json.dumps(captain_perms)),
        ("KITCHEN", json.dumps(kitchen_perms))
    ]
    
    for name, perms in roles_data:
        cursor.execute("INSERT INTO roles (name, permissions) VALUES (?, ?)", (name, perms))
        
    # 3. Define the credentials for these five roles
    # We use lowercase roles for backend compatibility but preserve the Display Name
    users_data = [
        ("admin", "admin123", "ADMIN"),
        ("manager", "manager123", "MANAGER"),
        ("cashier", "cashier123", "CASHIER"),
        ("captain", "captain123", "CAPTAIN"),
        ("kitchen", "kitchen123", "KITCHEN")
    ]
    
    for username, password, role in users_data:
        hashed = get_password_hash(password)
        cursor.execute("INSERT INTO users (username, password_hash, role) VALUES (?, ?, ?)", (username, hashed, role))
        print(f"Finalized user: {username} with role {role}")
    
    conn.commit()
    conn.close()

if __name__ == "__main__":
    finalize_roles_and_users()
