from sqlalchemy.orm import Session
from backend.models.catalog import MenuCategory, MenuItem
from backend.models.system import SystemSettings, Table, KitchenCounter
from backend.models.user import User
from backend.security.auth import get_password_hash
import json
import os

def seed_initial_data(db: Session):
    """Seed the database with the FULL menu, roles, and settings if empty."""
    
    # 1. Check if we already have data
    if db.query(MenuCategory).count() > 0:
        return

    print("Seeding COMPLETE product data...")

    # 2. Add Default Admin/Manager if no users exist
    if db.query(User).count() == 0:
        admin = User(
            username="admin",
            full_name="Administrator",
            password_hash=get_password_hash("admin123"),
            role="admin",
            pin="1122"
        )
        db.add(admin)
        
        kitchen = User(
            username="kitchen",
            full_name="Kitchen Display",
            password_hash=get_password_hash("kitchen123"),
            role="kitchen",
            pin="3344"
        )
        db.add(kitchen)

    # 3. Default Roles with Permission Templates
    from backend.models.user import Role
    if db.query(Role).count() == 0:
        print("Seeding default roles (Admin, Manager, Kitchen)...")
        all_perms = {
            "can_create_order": True, "can_edit_order": True, "can_delete_order": True,
            "can_print_kot": True, "can_cancel_kot": True, "can_apply_discount": True,
            "can_apply_large_discount": True, "can_change_tax": True, "can_settle_bill": True,
            "can_view_reports": True, "can_view_insights": True, "can_manage_tables": True,
            "can_manage_rooms": True, "can_manage_users": True, "can_manage_roles": True,
            "can_manage_menu": True, "can_manage_crm": True, "can_view_management": True,
            "can_system_settings": True,
        }
        manager_perms = all_perms.copy()
        manager_perms["can_manage_users"] = False
        manager_perms["can_manage_roles"] = False
        manager_perms["can_system_settings"] = False
        
        kitchen_perms = {
            "can_print_kot": True, 
            "can_view_management": True,
            "can_edit_order": True, # For marking as ready
        }
        
        db.add(Role(name="admin", permissions=all_perms))
        db.add(Role(name="manager", permissions=manager_perms))
        db.add(Role(name="kitchen", permissions=kitchen_perms))
        db.commit()

    # 4. Standard System Settings
    default_settings = [
        ("restaurant_name", "Servezy Restaurant"),
        ("tax_rate", "5.0"),
        ("tax_label", "GST"),
        ("currency_symbol", "₹"),
        ("bill_footer", "Thank you for visiting!"),
        ("total_tables", "20")
    ]
    for key, val in default_settings:
        if not db.query(SystemSettings).filter(SystemSettings.key == key).first():
            db.add(SystemSettings(key=key, value=val))

    # 4. Default Kitchen Counters
    if db.query(KitchenCounter).count() == 0:
        db.add(KitchenCounter(id=1, name="Main Kitchen", icon="restaurant", color="#E64A19"))
        db.add(KitchenCounter(id=2, name="Bar / Drinks", icon="local_bar", color="#1976D2"))
        db.commit()

    # 5. Default Tables
    if db.query(Table).count() == 0:
        for i in range(1, 21):
            db.add(Table(id=i, name=f"Table {i}", status="Available", capacity=4))

    # 6. THE FULL MENU (Loaded from the dump)
    # Using a local variable for the data to keep it all in one file for the final build
    full_menu_data = {
        "Organic Tea's": [
                [
                        "Darjeeling Black Supreme (Single)",
                        60.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Darjeeling Black Supreme (Pot For Three)",
                        140.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Assam Black Supreme (Single)",
                        50.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Assam Black Supreme (Pot For Three)",
                        120.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Peach Black (Single)",
                        60.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Peach Black (Pot For Three)",
                        140.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Darjeeling Green Classic (Single)",
                        60.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Darjeeling Green Classic (Pot For Three)",
                        140.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Mango Green (Single)",
                        70.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Mango Green (Pot For Three)",
                        160.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Darjeeling Oolong (Single)",
                        70.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Darjeeling Oolong (Pot For Three)",
                        180.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Himalayan Chamomile (Single)",
                        50.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Himalayan Chamomile (Pot For Three)",
                        120.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Himalayan Lemongrass (Single)",
                        50.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Himalayan Lemongrass (Pot For Three)",
                        120.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Tulsi Rhododendron (Single)",
                        60.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Tulsi Rhododendron (Pot For Three)",
                        140.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Orange & Mint (Single)",
                        70.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Orange & Mint (Pot For Three)",
                        180.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Black Currant (Single)",
                        60.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Black Currant (Pot For Three)",
                        120.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Strawberry (Single)",
                        60.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Strawberry (Pot For Three)",
                        120.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Hibiscus Green Tea (Single)",
                        70.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Hibiscus Green Tea (Pot For Three)",
                        140.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Mix Fruit Tea (Single)",
                        80.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Mix Fruit Tea (Pot For Three)",
                        180.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Jasmine Tea (Single)",
                        60.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Jasmine Tea (Pot For Three)",
                        140.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Rose Tea (Single)",
                        50.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Rose Tea (Pot For Three)",
                        120.0,
                        True,
                        5.0,
                        ""
                ]
        ],
        "Shakes": [
                [
                        "Vanilla Milkshake",
                        180.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Chocolate Milkshake",
                        180.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Strawberry Milkshake",
                        180.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Oreo Milkshake",
                        240.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "KitKat Milkshake",
                        240.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Nutella Peanut Butter Milkshake",
                        260.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Cold Coffee",
                        160.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Cold Coffee With Ice Cream",
                        180.0,
                        True,
                        5.0,
                        ""
                ]
        ],
        "Refreshers": [
                [
                        "Lemonade",
                        140.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Virgin Mojito",
                        170.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Strawberry Mojito",
                        190.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Ginger Ale",
                        180.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Tonic Water",
                        180.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Red Bull",
                        200.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Canned Juice",
                        120.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Coke Can",
                        79.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Hot Tea",
                        60.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Hot Coffee",
                        90.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Hot Chocolate",
                        120.0,
                        True,
                        5.0,
                        ""
                ]
        ],
        "Freshly Brewed Ice Tea's": [
                [
                        "Lemon",
                        160.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Peach",
                        180.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Mango",
                        180.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Hibiscus",
                        180.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Black Currant",
                        180.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Orange And Mint",
                        180.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Tulsi Rhododendron",
                        180.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Strawberry",
                        180.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Mixed Fruit",
                        180.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Refreshing",
                        180.0,
                        True,
                        5.0,
                        ""
                ]
        ],
        "Soup's": [
                [
                        "Cream Of Tomato",
                        180.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Cream Of Mushroom",
                        180.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Cream Of Vegetable",
                        180.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Cream Of Broccoli",
                        180.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Cream Of Chicken",
                        220.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Tomato Basil",
                        180.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Roasted Chicken & Garlic",
                        220.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Manchow (Veg)",
                        190.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Manchow (Chicken)",
                        220.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Hot N Sour (Veg)",
                        190.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Hot N Sour (Chicken)",
                        220.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Sweet Corn Soup (Veg)",
                        190.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Sweet Corn Soup (Chicken)",
                        220.0,
                        True,
                        5.0,
                        ""
                ]
        ],
        "Salads": [
                [
                        "Caesar Salad (Veg)",
                        320.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Caesar Salad (Chicken)",
                        340.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Cobb Salad (Veg)",
                        320.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Cobb Salad (Chicken)",
                        340.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Cobb Salad (Bacon)",
                        360.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Greek Salad With Feta Cheese",
                        320.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Pesto Grilled Chicken Salad",
                        360.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Chicken Tossed Salad",
                        280.0,
                        True,
                        5.0,
                        ""
                ]
        ],
        "Appetizers": [
                [
                        "French Fries",
                        260.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Cheese French Fries",
                        360.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Potato Wedges",
                        280.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Stuffed Potato Wedges",
                        360.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Nachos With Two Dips",
                        320.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Loaded Cheese Nachos",
                        460.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Cheese Corn Roll",
                        420.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Cheese Balls",
                        420.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Crispy Mushroom With Cheese",
                        460.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Mushroom Duplex",
                        460.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Cheese And Vegetable Croquette",
                        420.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Crispy Corn",
                        420.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Cilantro Chicken",
                        480.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Chicken Skewers",
                        480.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Barbeque Chicken Wings",
                        480.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Crispy Fried Chicken",
                        480.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Barbeque Chicken",
                        480.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Chicken Nuggets",
                        420.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Chicken Volcano Buns",
                        460.0,
                        True,
                        5.0,
                        "(buns filled with chicken, cheese and bell peppers and baked together)"
                ],
                [
                        "Minced Mutton Keema Pav",
                        520.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Fish Fingers With Tartar Sauce",
                        520.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Herbed Fish Skewers",
                        520.0,
                        True,
                        5.0,
                        ""
                ]
        ],
        "Chinese": [
                [
                        "Honey Chilli Potato",
                        380.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Spring Rolls (Veg)",
                        360.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Spring Rolls (Chicken)",
                        420.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Chilli Paneer",
                        420.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Chilly Chicken",
                        460.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Paneer Sixty Five",
                        420.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Chicken Sixty Five",
                        460.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Fried Rice (Veg)",
                        280.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Fried Rice (Egg)",
                        320.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Fried Rice (Chicken)",
                        380.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Vegetable Noodles (Veg)",
                        320.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Vegetable Noodles (Egg)",
                        340.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Vegetable Noodles (Chicken)",
                        380.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Drums Of Heaven",
                        460.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "American Chopsuey (Veg)",
                        380.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "American Chopsuey (Chicken)",
                        420.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Veg Lolipop",
                        340.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Singapore Style Noodle (Veg)",
                        320.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Singapore Style Noodle (Chicken)",
                        360.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Veg Hakka Noodles (Veg)",
                        320.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Veg Hakka Noodles (Chicken)",
                        360.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Manchurian (Veg)",
                        320.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Manchurian (Chicken)",
                        360.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Chilli Garlic Noodles (Veg)",
                        320.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Chilli Garlic Noodles (Chicken)",
                        360.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Green Thai Curry (Veg)",
                        520.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Green Thai Curry (Chicken)",
                        520.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Red Thai Curry (Veg)",
                        520.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Red Thai Curry (Chicken)",
                        520.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Thukpa (Veg)",
                        220.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Thukpa (Chicken)",
                        280.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Vegetable In Hot Garlic Sauce",
                        0.0,
                        True,
                        5.0,
                        ""
                ]
        ],
        "Tandoori Starters": [
                [
                        "Paneer Tikka",
                        460.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Soya Chaap Tikka",
                        380.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Stuffed Mushroom Tikka",
                        480.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Veg Seekh Kebab",
                        360.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Hara Bhara Kebab (Deep Fried)",
                        380.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Tandoori Chicken (Half)",
                        520.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Tandoori Chicken (Full)",
                        880.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Chicken Tikka",
                        480.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Chicken Malai Tikka",
                        490.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Achari Paneer Tikka",
                        460.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Achari Chicken Tikka",
                        480.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Chicken Seekh Kebab",
                        380.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Fish Tikka",
                        520.0,
                        True,
                        5.0,
                        ""
                ]
        ],
        "Sandwiches": [
                [
                        "Grilled Tomato Cheese",
                        320.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Grilled Vegetable & Cheese",
                        360.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Grilled Chicken Sandwich",
                        420.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Bacon Club",
                        520.0,
                        True,
                        5.0,
                        ""
                ]
        ],
        "Burgers": [
                [
                        "Vegetarian Delight Burger",
                        360.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Guy At The Grill Chicken Burger",
                        420.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Lamb Steak Burger",
                        480.0,
                        True,
                        5.0,
                        ""
                ]
        ],
        "Garlic Breads": [
                [
                        "Plain",
                        240.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Cheese",
                        320.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Cheese Chilli Toast",
                        280.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Cheese Mushroom Toast",
                        320.0,
                        True,
                        5.0,
                        ""
                ]
        ],
        "Bruschettas": [
                [
                        "Onion, Tomato, Jalapeno, Pepper & Cheese",
                        420.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Olives, Capers & Basil Pesto",
                        420.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Barbeque Chicken Bruschetta",
                        480.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Avocado With Flax Seeds",
                        520.0,
                        True,
                        5.0,
                        ""
                ]
        ],
        "Pizza ( 12' Thin Crust Pizza)": [
                [
                        "Classic Margherita",
                        480.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Pizza Primavera",
                        580.0,
                        True,
                        5.0,
                        "(bell pepper, zucchini, mushroom, onion, corn, olives, plum, tomato sauce,mozzarella cheese)"
                ],
                [
                        "Pizza Corn Fungi",
                        520.0,
                        True,
                        5.0,
                        "(plum tomato spread, American corns and mozzarella cheese)"
                ],
                [
                        "Pesto Polo Chicken",
                        580.0,
                        True,
                        5.0,
                        "(pesto marinated grilled chicken with pesto & tomato sauce along with mozzarella and parmesan cheese)"
                ],
                [
                        "Italian Hot Chicken",
                        580.0,
                        True,
                        5.0,
                        "(plum tomato spread, chicken sausage, chicken salami, chicken ham, grilled chicken with mozzarella cheese)"
                ],
                [
                        "Barbeque Chicken",
                        580.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Paneer Tikka Pizza",
                        580.0,
                        True,
                        5.0,
                        "A delightful fusion of Indian and Italian cuisine, features spicy marinated paneer, vibrant vegetables, and a tangy yogurt sauce atop a crispy pizza curst"
                ],
                [
                        "Chicken Tikka Pizza",
                        580.0,
                        True,
                        5.0,
                        "A delightful fusion of Indian and Italian cuisine, features spicy marinated chicken, vibrant vegetables, and a tangy yogurt sauce atop a crispy pizza curst"
                ]
        ],
        "Pasta's": [
                [
                        "Penne Arrabiata (Veg)",
                        460.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Penne Arrabiata (Chicken)",
                        480.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Penne Alfredo (Mushroom)",
                        460.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Penne Alfredo (Chicken)",
                        480.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Penne Pomodoro (Veg)",
                        460.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Penne Pomodoro (Chicken)",
                        480.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Penne Pesto Veg",
                        460.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Cajun Chicken",
                        480.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Spaghetti Carbonara",
                        580.0,
                        True,
                        5.0,
                        "(spaghetti tossed with bacon, egg yolk cream and parmesan cheese)"
                ],
                [
                        "Spaghetti Bolognaise",
                        580.0,
                        True,
                        5.0,
                        "(spaghetti tossed with lamb, tomato sauce, rosemary, parmesan cheese and olives)"
                ],
                [
                        "Spaghetti Aglieolio (Veg)",
                        480.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Spaghetti Aglieolio (Chicken)",
                        520.0,
                        True,
                        5.0,
                        ""
                ]
        ],
        "Risotto": [
                [
                        "Wild Mushroom",
                        520.0,
                        True,
                        5.0,
                        "(button mushroom, shiitake mushroom, arborio (Italian) rice with cream and parmesan cheese)"
                ],
                [
                        "Grilled Chicken Risotto",
                        560.0,
                        True,
                        5.0,
                        "(grilled chicken, arborio rice, parmesan cheese, olives and sun-dried tomato)"
                ],
                [
                        "SeaFood",
                        580.0,
                        True,
                        5.0,
                        "(mix of seafood, arborio rice, parmesan cheese and olives)"
                ]
        ],
        "Lasagne": [
                [
                        "Vegetable",
                        480.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Chicken",
                        520.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Mutton",
                        580.0,
                        True,
                        5.0,
                        ""
                ]
        ],
        "Sizzlers": [
                [
                        "Vegetable Steak Sizzler",
                        480.0,
                        True,
                        5.0,
                        "(grilled vegetable patty served with potato wedges, saut\u00e9 vegetable and creamy mushroom sauce)"
                ],
                [
                        "Chicken Minced Steak Sizzler",
                        560.0,
                        True,
                        5.0,
                        "(grilled chicken patty served with saut\u00e9 vegetable, potato wedges and mushroom sauce)"
                ],
                [
                        "Chicken Fillet Steak With Cheese Sizzler",
                        580.0,
                        True,
                        5.0,
                        "(grilled chicken steak and cheese served with smashed potato, saut\u00e9 vegetabe and pepper sauce)"
                ],
                [
                        "Minced Lamb Steak Sizzler",
                        580.0,
                        True,
                        5.0,
                        "(grilled lamb steak served with potato wedges, saut\u00e9 vegetable and mushroom sauce)"
                ]
        ],
        "Western Main's": [
                [
                        "Vegetable AU Gratin",
                        460.0,
                        True,
                        5.0,
                        "(vegetables drowned in white sauce with lots of cheese, its creamy with a crusty top served with toasted bread)"
                ],
                [
                        "Quesadilla (Veg)",
                        480.0,
                        True,
                        5.0,
                        "(tortilla filled with bell pepper, beans, american corn cheese)"
                ],
                [
                        "Quesadilla (Chicken)",
                        520.0,
                        True,
                        5.0,
                        "(tortilla filled with bell pepper, beans, american corn cheese)"
                ],
                [
                        "Burrito (Veg)",
                        420.0,
                        True,
                        5.0,
                        "(tortilla wrap filled with cottage cheese, bell pepper, red beans tossed with tangy tomato sauce)"
                ],
                [
                        "Burrito (Chicken)",
                        480.0,
                        True,
                        5.0,
                        "(tortilla wrap filled with cottage cheese, bell pepper, red beans tossed with tangy tomato sauce)"
                ],
                [
                        "Shawarma Wrap",
                        420.0,
                        True,
                        5.0,
                        "(Lebanese pita bread, grilled chicken, pickled vegetable served with tahini sauce)"
                ],
                [
                        "Chicken Fajitas",
                        480.0,
                        True,
                        5.0,
                        "(A tex-mex dish served with barbeque sauce)"
                ],
                [
                        "Peri Peri Grilled Chicken",
                        560.0,
                        True,
                        5.0,
                        "(served with herb rice, grilled pineapple and peri peri sauce)"
                ],
                [
                        "Thyme & Garlic Grilled Chicken",
                        560.0,
                        True,
                        5.0,
                        "(served with brown garlic, mashed potato, glazed vegetables and green pepper sauce)"
                ],
                [
                        "Grilled Chicken Supreme",
                        580.0,
                        True,
                        5.0,
                        "(chicken breast filled with minced chicken served with herb rice tossed vegetable and mushroom sauce)"
                ],
                [
                        "Cajun Spicy Grilled Chicken",
                        560.0,
                        True,
                        5.0,
                        "(served with mashed potato, saute vegetable and cajun sauce)"
                ],
                [
                        "Grilled Fish With Lemon Butter Sauce",
                        580.0,
                        True,
                        5.0,
                        "(served with mashed potato and butter tossed vegetables)"
                ],
                [
                        "Herb Crusted Basa Fish",
                        520.0,
                        True,
                        5.0,
                        "(served with mashed potato, vegetables and lemon butter sauce)"
                ],
                [
                        "Fish & Chips",
                        520.0,
                        True,
                        5.0,
                        "(served with mashed potato and tartar)"
                ],
                [
                        "Chilli Garlic Prawns",
                        580.0,
                        True,
                        5.0,
                        "(Seared prawns smothered in a spicy Asian sauce)"
                ]
        ],
        "Indian Main's Veg": [
                [
                        "Dal Tadka",
                        360.0,
                        True,
                        5.0,
                        "(cooked lentils tempered with oil, fried spices & herbs)"
                ],
                [
                        "Dal Makhani",
                        460.0,
                        True,
                        5.0,
                        "(whole black lentils cooked with butter and cream and simmered on low heat for that unique flavour)"
                ],
                [
                        "Veg Korma",
                        420.0,
                        True,
                        5.0,
                        "(seasonal vegetables in rich aromatic Indian gravy)"
                ],
                [
                        "Paneer Butter Masala",
                        480.0,
                        True,
                        5.0,
                        "(rich & creamy curry made with cottage cheese, spices, onions, tomatoes, cashews and butter)"
                ],
                [
                        "Paneer Lababdar",
                        480.0,
                        True,
                        5.0,
                        "(cottage cheese in a creamy mildly tangy and faintly sweet gravy)"
                ],
                [
                        "Kadhai Paneer",
                        480.0,
                        True,
                        5.0,
                        "(cottage cheese and bell peppers are cooked in a spicy masala)"
                ],
                [
                        "Paneer Do Pyaza",
                        480.0,
                        True,
                        5.0,
                        "(cottage cheese with delicious, aromatic gravy that has mild hints of sweet and slightly tangy taste) "
                ],
                [
                        "Paneer Korma",
                        480.0,
                        True,
                        5.0,
                        "(cottage cheese cubes are cooked in a rich onion based gravy)"
                ],
                [
                        "Shahi Paneer",
                        480.0,
                        True,
                        5.0,
                        "(the recipe is mild or less spicy, cottage cheese cubes based curry as the name suggests, shahi which means royal)"
                ],
                [
                        "Paneer Tikka Masala",
                        480.0,
                        True,
                        5.0,
                        "(translates to grilled chunks of cottage cheese in a spicy gravy)"
                ],
                [
                        "Palak Paneer",
                        440.0,
                        True,
                        5.0,
                        "(cottage cheese cubes in a mild, spiced smooth spinach gravy)"
                ],
                [
                        "Mutter Paneer",
                        420.0,
                        True,
                        5.0,
                        "(Peas and Cottage Cheese Curry)"
                ],
                [
                        "Malai Kofta",
                        460.0,
                        True,
                        5.0,
                        "(vegetrian dish where balls made of potato and cottage cheese are deep  fried and served with a creamy tomato based curry)"
                ],
                [
                        "Mutter Mushroom",
                        460.0,
                        True,
                        5.0,
                        "(creamy and spicy north indian gravy prepared mainly with green peas and mushrooms)"
                ],
                [
                        "Kashmiri Dum Aloo",
                        420.0,
                        True,
                        5.0,
                        "(baby potatoes simmered (dum cooked) in a spicy curd (yogurt) based gravy or sauce)"
                ],
                [
                        "Stuffed Dum Aloo",
                        420.0,
                        True,
                        5.0,
                        "(potatoes are deep-fried and stuffed with a rich filling of cottage cheese cashew nuts, raisins and green chillies)"
                ],
                [
                        "Mix Veg",
                        420.0,
                        True,
                        5.0,
                        "(This recipe is loaded with veggies, paneer, cooked together in a tangy tomato sauce)"
                ],
                [
                        "Soya Chaap Rara",
                        420.0,
                        True,
                        5.0,
                        "(It is made using soya pieces and soya mince in a gravy)"
                ],
                [
                        "Jeera Aloo",
                        280.0,
                        True,
                        5.0,
                        "(potatoes saut\u00e9ed with cumin)"
                ]
        ],
        "Indian Main's Non Veg": [
                [
                        "Chicken Curry",
                        480.0,
                        True,
                        5.0,
                        "(onion and tomato based sauce, flavoured with ginger, garlic, tomato pur\u00e9e, chilli peppers and a mix of spices)"
                ],
                [
                        "Kadhai Chicken (Half)",
                        580.0,
                        True,
                        5.0,
                        "(chicken, onions, tomatoes, ginger, garlic & fresh ground spices)"
                ],
                [
                        "Kadhai Chicken (Full)",
                        880.0,
                        True,
                        5.0,
                        "(chicken, onions, tomatoes, ginger, garlic & fresh ground spices)"
                ],
                [
                        "Butter Chicken (Half)",
                        580.0,
                        True,
                        5.0,
                        "(Tandoori chicken cooked in butter and thick tomato gravy)"
                ],
                [
                        "Butter Chicken (Full)",
                        880.0,
                        True,
                        5.0,
                        "(Tandoori chicken cooked in butter and thick tomato gravy)"
                ],
                [
                        "Chicken Korma",
                        560.0,
                        True,
                        5.0,
                        "(chicken in a gravy usually made with onions, spices, nuts & yogurt)"
                ],
                [
                        "Chicken Do Pyaza",
                        520.0,
                        True,
                        5.0,
                        "(Diced onions first fried with spices, and then larger pieces of onions are added towards the end)"
                ],
                [
                        "Chicken Saagwala",
                        560.0,
                        True,
                        5.0,
                        "(sauce made flavourful with turmeric, cinnamon, garam masala and fresh spinach with lightly browned pan-fried chicken)"
                ],
                [
                        "Chicken Tikka Masala",
                        560.0,
                        True,
                        5.0,
                        "(translates to grilled chunks of chicken in a spicy gravy)"
                ],
                [
                        "Afghani Chicken",
                        580.0,
                        True,
                        5.0,
                        "(made of chicken marinated in a rich creamy marinade made with cashew nut paste, cream, lemon juice, cheese and ginger-garlic paste)"
                ],
                [
                        "Mutton Curry",
                        580.0,
                        True,
                        5.0,
                        "(flavourful & tender lamb in onion and tomato based gravy)"
                ],
                [
                        "Mutton Saagwala",
                        620.0,
                        True,
                        5.0,
                        "(sauce made flavourful with turmeric, cinnamon, garam masala, and fresh spinach with lightly browned pan-fried lamb)"
                ],
                [
                        "Mutton Korma",
                        620.0,
                        True,
                        5.0,
                        "(lamb in a gravy made with onions, spices, nuts & yogurt)"
                ],
                [
                        "Mutton Tawa Masala",
                        620.0,
                        True,
                        5.0,
                        "(Boneless chunks of marinated lamb with onions, tomatoes and fresh green chillies) "
                ],
                [
                        "Egg Curry",
                        360.0,
                        True,
                        5.0,
                        "(boiled eggs cooked in onion tomato based gravy)"
                ],
                [
                        "Chana Masala",
                        360.0,
                        True,
                        5.0,
                        "(Chickenpea curry in indian spices)"
                ]
        ],
        "Rice": [
                [
                        "Steam Rice",
                        240.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Jeera Rice",
                        280.0,
                        True,
                        5.0,
                        "(rice tossed with cumins)"
                ],
                [
                        "Peas Pulao",
                        280.0,
                        True,
                        5.0,
                        "(rice tossed with peas & spices)"
                ],
                [
                        "Vegetable Pulao",
                        320.0,
                        True,
                        5.0,
                        "(rice tossed with seasonal vegetables and spices)"
                ],
                [
                        "Kashmiri Pulao",
                        380.0,
                        True,
                        5.0,
                        "(rice tossed with seasonal vegetables, cashews and raisins)"
                ],
                [
                        "Veg Biryani",
                        380.0,
                        True,
                        5.0,
                        "(aromatic rice dish made by cooking basmati rice with mix veggies, herbs & spices)"
                ],
                [
                        "Chicken Biryani",
                        480.0,
                        True,
                        5.0,
                        "(aromatic rice dish made by cooking chicken, basmati rice herbs & spices)"
                ],
                [
                        "Mutton Biryani",
                        560.0,
                        True,
                        5.0,
                        "(aromatic rice dish made by cooking lamb, basmati rice herbs & spices)"
                ]
        ],
        "Indian Breads": [
                [
                        "Plain Roti",
                        45.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Butter Roti",
                        60.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Plain Naan",
                        60.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Butter Naan",
                        75.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Garlic Naan",
                        85.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Cheese Naan",
                        160.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Missi Roti",
                        90.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Lachha Paratha",
                        90.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Stuffed Naan",
                        160.0,
                        True,
                        5.0,
                        ""
                ]
        ],
        "Sides": [
                [
                        "Aloo Chat",
                        280.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Egg Bhurji",
                        260.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Masala Peanut",
                        280.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Chana Chaat",
                        240.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Masala Papad",
                        80.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Roasted Papad",
                        40.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Paneer Pakoda",
                        320.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Omelette",
                        160.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Masala Omelette",
                        180.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Cheese Omelette",
                        260.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Boiled Eggs (2 PCS)",
                        80.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Fresh Green Salad",
                        180.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Raita",
                        160.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Curd",
                        120.0,
                        True,
                        5.0,
                        ""
                ]
        ],
        "Desserts": [
                [
                        "Vanilla Ice Cream",
                        120.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Chocolate Ice Cream",
                        120.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Strawberry Ice Cream",
                        120.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Sizzling Brwnie",
                        280.0,
                        True,
                        5.0,
                        ""
                ],
                [
                        "Death By Chocolate",
                        320.0,
                        True,
                        5.0,
                        ""
                ]
        ]
}

    sort_order = 1
    for cat_name, items in full_menu_data.items():
        # Map certain categories to specific counters
        # Default to counter 1 (Main Kitchen)
        target_counter_id = 1 
        
        # Beverage related categories mapping to counter 2 (Bar / Drinks)
        bar_categories = [
            "Shakes", "Refreshers", "Freshly Brewed Ice Tea's", 
            "Organic Tea's", "Smoothies", "Mocktails", "Coffee", "Tea"
        ]
        
        if any(bc.lower() in cat_name.lower() for bc in bar_categories):
            target_counter_id = 2
            
        cat = MenuCategory(name=cat_name, kitchen_counter_id=target_counter_id)
        db.add(cat)
        db.flush() # Get ID
        
        for i_data in items:
            item = MenuItem(
                name=i_data[0],
                price=i_data[1],
                category_id=cat.id,
                description=i_data[4] if len(i_data) > 4 else "",
                is_available=True,
                tax_enabled=i_data[2],
                tax_percentage=i_data[3]
            )
            db.add(item)
        
        sort_order += 1

    db.commit()
    print("Seeding complete.")
