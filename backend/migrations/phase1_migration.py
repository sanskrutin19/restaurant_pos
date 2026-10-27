"""
Database migration script: Phase 1 — Core POS Improvements
Run this script once to add new columns to existing SQLite tables.
Usage: python -m backend.migrations.phase1_migration
"""
import sqlite3
import os

DB_PATH = os.path.join(os.path.dirname(__file__), '..', 'restaurant_pos.db')


def run_migration():
    db_path = os.path.abspath(DB_PATH)
    print(f"[Migration] Connecting to: {db_path}")
    
    if not os.path.exists(db_path):
        print("[Migration] Database file not found. It will be created on first server start.")
        return

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    migrations = [
        # Order model: add held_at
        ("orders", "held_at", "DATETIME"),
        # Bill model: add new columns
        ("bills", "subtotal", "FLOAT DEFAULT 0.0"),
        ("bills", "cgst", "FLOAT DEFAULT 0.0"),
        ("bills", "sgst", "FLOAT DEFAULT 0.0"),
        ("bills", "discount_type", "TEXT DEFAULT 'flat'"),
        ("bills", "discount_value", "FLOAT DEFAULT 0.0"),
        ("bills", "round_off", "FLOAT DEFAULT 0.0"),
    ]

    for table, column, col_type in migrations:
        try:
            cursor.execute(f"ALTER TABLE {table} ADD COLUMN {column} {col_type}")
            print(f"  ✅ Added {table}.{column}")
        except sqlite3.OperationalError as e:
            if "duplicate column" in str(e).lower():
                print(f"  ⏭️  {table}.{column} already exists, skipping")
            else:
                print(f"  ❌ Error adding {table}.{column}: {e}")

    conn.commit()
    conn.close()
    print("[Migration] Phase 1 complete!")


if __name__ == "__main__":
    run_migration()
