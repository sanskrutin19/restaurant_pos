import sys
import os
from datetime import datetime

# Add project root to path
sys.path.append(os.getcwd())

from backend.utils.excel_generator import ExcelGenerator

# Mock data
data = {
    "summary": {
        "total_revenue": 5000.0,
        "total_orders": 45,
        "cgst": 125.0,
        "sgst": 125.0,
        "total_tax": 250.0,
        "discount": 50.0
    },
    "orders": [
        {
            "date": "26/03/2026",
            "id": "ORD-0001",
            "customer": "Test Customer",
            "items": 2,
            "amount": 250.0,
            "payment_mode": "UPI",
            "status": "Paid"
        }
    ],
    "item_wise": [
        {"item_name": "Paneer Butter Masala", "quantity_sold": 10, "total_revenue": 2500.0}
    ],
    "category_wise": [
        {"category": "Main Course", "quantity_sold": 20, "total_revenue": 4000.0}
    ],
    "payment_breakdown": [
        {"mode": "Cash", "count": 10, "total_amount": 2000.0},
        {"mode": "UPI", "count": 35, "total_amount": 3000.0}
    ],
    "revenue_trend": [
        {"day": "2026-03-24", "revenue": 3000.0},
        {"day": "2026-03-25", "revenue": 2500.0},
        {"day": "2026-03-26", "revenue": 5000.0}
    ]
}

try:
    print("Generating Optimized Excel...")
    excel_bytes = ExcelGenerator.generate_sales_excel(
        data, 
        datetime(2026, 3, 19), 
        datetime(2026, 3, 26), 
        "Test Restaurant"
    )
    print(f"Success! Generated {len(excel_bytes)} bytes.")
except Exception as e:
    print(f"Error: {e}")
    import traceback
    traceback.print_exc()
