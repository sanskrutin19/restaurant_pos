import sqlite3

def migrate():
    conn = sqlite3.connect('restaurant_pos.db')
    c = conn.cursor()
    
    # Check if columns exist first
    c.execute("PRAGMA table_info(kitchen_counters)")
    columns = [col[1] for col in c.fetchall()]
    
    if 'printer_type' not in columns:
        c.execute("ALTER TABLE kitchen_counters ADD COLUMN printer_type TEXT DEFAULT 'network'")
    if 'printer_address' not in columns:
        c.execute("ALTER TABLE kitchen_counters ADD COLUMN printer_address TEXT")
    if 'printer_port' not in columns:
        c.execute("ALTER TABLE kitchen_counters ADD COLUMN printer_port INTEGER DEFAULT 9100")
        
    conn.commit()
    conn.close()
    print("Success: Printer configuration support added to Kitchen Counters.")

if __name__ == "__main__":
    migrate()
