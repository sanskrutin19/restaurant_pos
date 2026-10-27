import sqlite3
import os

db_path = 'restaurant_pos.db'
if os.path.exists(db_path):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Target date: Today
    target_date = '2026-03-24'
    
    # Fetch all bills for today
    cursor.execute("SELECT id, subtotal, discount, total_amount FROM bills WHERE date(created_at) = ?", (target_date,))
    bills = cursor.fetchall()
    
    print(f"Updating {len(bills)} bills to 12% GST...")
    
    for bill_id, subtotal, discount, old_total in bills:
        taxable = max(0, subtotal - discount)
        cgst = round(taxable * 0.06, 2)
        sgst = round(taxable * 0.06, 2)
        new_total = round(taxable + cgst + sgst, 2)
        
        cursor.execute(
            "UPDATE bills SET cgst = ?, sgst = ?, total_amount = ? WHERE id = ?",
            (cgst, sgst, new_total, bill_id)
        )
        print(f"Bill #{bill_id}: New CGST/SGST = ₹{cgst}, Total = ₹{new_total}")
    
    conn.commit()
    conn.close()
    print("Bills updated successfully.")
else:
    print(f"{db_path} not found.")
