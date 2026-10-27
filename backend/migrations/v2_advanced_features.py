"""
Database migration v2: Advanced POS Features
Adds new columns to existing tables for:
- Non-discount categories/items (#1)
- Per-item tax (#2)
- Customer enhancements (#3)
- Room support (#4)
- KOT versioning (#5, #6)
- Role permissions (#10)
- Bill number sequencing (#13)

Also creates new tables: kot_logs, rooms, roles, bill_sequences
"""
import sqlite3
import os


def get_db_path():
    """Find the database file."""
    candidates = [
        os.path.join(os.getcwd(), "restaurant_pos.db"),
        os.path.join(os.path.dirname(__file__), "..", "restaurant_pos.db"),
    ]
    for p in candidates:
        if os.path.exists(p):
            return p
    return candidates[0]


def column_exists(cursor, table, column):
    cursor.execute(f"PRAGMA table_info({table})")
    columns = [row[1] for row in cursor.fetchall()]
    return column in columns


def table_exists(cursor, table):
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name=?", (table,))
    return cursor.fetchone() is not None


def migrate():
    db_path = get_db_path()
    print(f"Migrating database: {db_path}")
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # --- menu_categories ---
    if not column_exists(cursor, "menu_categories", "allow_discount"):
        cursor.execute("ALTER TABLE menu_categories ADD COLUMN allow_discount BOOLEAN DEFAULT 1")
        print("  + menu_categories.allow_discount")

    # --- menu_items ---
    for col, typ, default in [
        ("allow_discount", "BOOLEAN", "1"),
        ("tax_enabled", "BOOLEAN", "1"),
        ("tax_percentage", "REAL", "5.0"),
    ]:
        if not column_exists(cursor, "menu_items", col):
            cursor.execute(f"ALTER TABLE menu_items ADD COLUMN {col} {typ} DEFAULT {default}")
            print(f"  + menu_items.{col}")

    # --- orders ---
    for col, typ, default in [
        ("room_number", "TEXT", "NULL"),
        ("guest_name", "TEXT", "NULL"),
        ("room_service_charge", "REAL", "0.0"),
        ("pax_count", "INTEGER", "1"),
        ("customer_mobile", "TEXT", "NULL"),
        ("bill_number", "TEXT", "NULL"),
    ]:
        if not column_exists(cursor, "orders", col):
            cursor.execute(f"ALTER TABLE orders ADD COLUMN {col} {typ} DEFAULT {default}")
            print(f"  + orders.{col}")

    # --- order_items ---
    for col, typ, default in [
        ("allow_discount", "BOOLEAN", "1"),
        ("tax_enabled", "BOOLEAN", "1"),
        ("tax_percentage", "REAL", "5.0"),
        ("kot_version", "INTEGER", "1"),
        ("kot_status", "TEXT", "'active'"),
    ]:
        if not column_exists(cursor, "order_items", col):
            cursor.execute(f"ALTER TABLE order_items ADD COLUMN {col} {typ} DEFAULT {default}")
            print(f"  + order_items.{col}")

    # --- customers ---
    for col, typ, default in [
        ("total_spend", "REAL", "0.0"),
        ("last_visit", "TEXT", "NULL"),
    ]:
        if not column_exists(cursor, "customers", col):
            cursor.execute(f"ALTER TABLE customers ADD COLUMN {col} {typ} DEFAULT {default}")
            print(f"  + customers.{col}")

    # --- bills ---
    for col, typ, default in [
        ("bill_number", "TEXT", "NULL"),
        ("taxable_subtotal", "REAL", "0.0"),
        ("non_taxable_subtotal", "REAL", "0.0"),
        ("discountable_subtotal", "REAL", "0.0"),
        ("non_discountable_subtotal", "REAL", "0.0"),
        ("discount_note", "TEXT", "NULL"),
        ("is_reprint", "INTEGER", "0"),
    ]:
        if not column_exists(cursor, "bills", col):
            cursor.execute(f"ALTER TABLE bills ADD COLUMN {col} {typ} DEFAULT {default}")
            print(f"  + bills.{col}")

    # --- users ---
    if not column_exists(cursor, "users", "permissions"):
        cursor.execute("ALTER TABLE users ADD COLUMN permissions TEXT DEFAULT NULL")
        print("  + users.permissions")

    # --- NEW TABLES ---

    if not table_exists(cursor, "kot_logs"):
        cursor.execute("""
            CREATE TABLE kot_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                order_id INTEGER NOT NULL REFERENCES orders(id),
                version INTEGER NOT NULL DEFAULT 1,
                action TEXT NOT NULL DEFAULT 'created',
                items_snapshot TEXT,
                added_items TEXT,
                removed_items TEXT,
                modified_items TEXT,
                cancelled_by INTEGER REFERENCES users(id),
                cancel_reason TEXT,
                captain_name TEXT,
                table_number TEXT,
                room_number TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        cursor.execute("CREATE INDEX idx_kot_logs_order ON kot_logs(order_id)")
        print("  + TABLE kot_logs")

    if not table_exists(cursor, "bill_sequences"):
        cursor.execute("""
            CREATE TABLE bill_sequences (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                prefix TEXT DEFAULT 'BILL',
                date TEXT NOT NULL,
                last_number INTEGER DEFAULT 0
            )
        """)
        print("  + TABLE bill_sequences")

    if not table_exists(cursor, "rooms"):
        cursor.execute("""
            CREATE TABLE rooms (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                room_number TEXT UNIQUE NOT NULL,
                floor TEXT,
                guest_name TEXT,
                status TEXT DEFAULT 'available',
                service_charge REAL DEFAULT 0.0,
                is_active BOOLEAN DEFAULT 1,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP
            )
        """)
        # Seed default rooms
        for floor, range_start, range_end in [("1st Floor", 101, 111), ("2nd Floor", 201, 211)]:
            for rn in range(range_start, range_end):
                cursor.execute("INSERT OR IGNORE INTO rooms (room_number, floor, status, service_charge) VALUES (?, ?, ?, ?)",
                               (str(rn), floor, 'available', 0.0))
        print("  + TABLE rooms (seeded with 20 default rooms)")

    if not table_exists(cursor, "roles"):
        cursor.execute("""
            CREATE TABLE roles (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT UNIQUE NOT NULL,
                permissions TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP
            )
        """)
        # Seed default roles
        import json
        default_roles = [
            ("admin", {
                "can_create_order": True, "can_edit_order": True, "can_delete_order": True,
                "can_print_kot": True, "can_cancel_kot": True,
                "can_apply_discount": True, "can_apply_large_discount": True,
                "can_change_tax": True, "can_settle_bill": True,
                "can_view_reports": True, "can_manage_tables": True,
                "can_manage_users": True, "can_manage_menu": True,
                "can_view_management": True,
            }),
            ("manager", {
                "can_create_order": True, "can_edit_order": True, "can_delete_order": True,
                "can_print_kot": True, "can_cancel_kot": True,
                "can_apply_discount": True, "can_apply_large_discount": True,
                "can_change_tax": True, "can_settle_bill": True,
                "can_view_reports": True, "can_manage_tables": True,
                "can_manage_users": False, "can_manage_menu": True,
                "can_view_management": True,
            }),
            ("cashier", {
                "can_create_order": True, "can_edit_order": True, "can_delete_order": False,
                "can_print_kot": True, "can_cancel_kot": False,
                "can_apply_discount": True, "can_apply_large_discount": False,
                "can_change_tax": False, "can_settle_bill": True,
                "can_view_reports": False, "can_manage_tables": True,
                "can_manage_users": False, "can_manage_menu": False,
                "can_view_management": False,
            }),
            ("captain", {
                "can_create_order": True, "can_edit_order": True, "can_delete_order": False,
                "can_print_kot": True, "can_cancel_kot": False,
                "can_apply_discount": False, "can_apply_large_discount": False,
                "can_change_tax": False, "can_settle_bill": False,
                "can_view_reports": False, "can_manage_tables": True,
                "can_manage_users": False, "can_manage_menu": False,
                "can_view_management": False,
            }),
            ("kitchen", {
                "can_create_order": False, "can_edit_order": False, "can_delete_order": False,
                "can_print_kot": True, "can_cancel_kot": False,
                "can_apply_discount": False, "can_apply_large_discount": False,
                "can_change_tax": False, "can_settle_bill": False,
                "can_view_reports": False, "can_manage_tables": False,
                "can_manage_users": False, "can_manage_menu": False,
                "can_view_management": False,
            }),
        ]
        for name, perms in default_roles:
            cursor.execute("INSERT INTO roles (name, permissions) VALUES (?, ?)",
                           (name, json.dumps(perms)))
        print("  + TABLE roles (seeded with defaults)")

    # Add indexes for performance (#12)
    try:
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_menu_items_category ON menu_items(category_id)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_menu_items_name ON menu_items(name)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_orders_table ON orders(table_id)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_orders_created ON orders(created_at)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone)")
        print("  + Performance indexes")
    except Exception as e:
        print(f"  ! Index creation note: {e}")

    conn.commit()
    conn.close()
    print("Migration complete!")


if __name__ == "__main__":
    migrate()
