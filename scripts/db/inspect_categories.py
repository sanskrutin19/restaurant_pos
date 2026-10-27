import sys
import os

# Setup path
sys.path.append(os.getcwd())

from backend.database.core import SessionLocal
# Import all models directly
from backend.models.order import Order, OrderItem
from backend.models.catalog import MenuItem, MenuCategory
from backend.models.system import Table
from backend.models.user import User, Device
from backend.models.customer import Customer
from backend.models.billing import Bill, Payment

db = SessionLocal()

try:
    print("--- CATEGORY DEBUG ---")
    cats = db.query(MenuCategory).all()
    for c in cats:
        print(f"Category: ID={c.id}, Name={c.name}")
    
    # Check paid orders items
    from datetime import datetime, timedelta
    start = datetime.now() - timedelta(days=30)
    
    # Use outer joins to see what's disconnected
    query = db.query(OrderItem, Order.id, MenuItem.name, MenuCategory.name)\
        .join(Order, OrderItem.order_id == Order.id)\
        .outerjoin(MenuItem, OrderItem.item_id == MenuItem.id)\
        .outerjoin(MenuCategory, MenuItem.category_id == MenuCategory.id)\
        .filter(Order.status == 'Paid')\
        .filter(Order.created_at >= start)
    
    results = query.all()
        
    print(f"\nFound {len(results)} items in paid orders recently.")
    uncategorized = 0
    main_course_count = 0
    for oi, order_id, mi_name, mc_name in results:
        if mc_name == "Main Course":
            main_course_count += 1
        if mc_name is None:
            uncategorized = uncategorized + 1
            if uncategorized < 20: # Limit output
                print(f"Uncategorized Item: Order {order_id}, ItemID {oi.item_id}, Name {oi.name}")

    print(f"\nSummary:")
    print(f"Main Course Items Found: {main_course_count}")
    print(f"Uncategorized Items Found: {uncategorized}")

finally:
    db.close()
