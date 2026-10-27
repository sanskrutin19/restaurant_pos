import asyncio
from sqlalchemy.orm import Session
from fastapi import HTTPException
from backend.schemas.commands import (
    CreateOrderCommand,
    AddItemToOrderCommand,
    RemoveItemFromOrderCommand
)
from backend.models.order import Order, OrderItem
from backend.models.customer import Customer
from backend.models.catalog import MenuItem
from backend.models.system import Table
from backend.commands.core import command_bus
from backend.events.core import event_bus
from backend.schemas.events import TableUpdatedEvent, LowStockEvent, OrderCreatedEvent
from backend.schemas.orders import OrderResponse

from backend.models.inventory import Ingredient, Recipe, RecipeIngredient, StockTransaction

async def _deduct_stock(item: MenuItem, quantity: int, db: Session, order_id: int = None):
    """Recursively deducts stock for an item, its combo components, AND its ingredients (recipes)."""
    # 1. Deduct from MenuItem stock_level (legacy/basic if still used)
    if item.stock_level < quantity:
        # We don't necessarily want to block order creation if ingredient stock is enough 
        # but let's keep consistency for now
        pass
    
    item.stock_level -= quantity
    
    # 2. Process Ingredients (Recipe-based deduction)
    # Find the main recipe for this menu item
    recipe = db.query(Recipe).filter(Recipe.menu_item_id == item.id, Recipe.recipe_type == "main").first()
    if recipe:
        _resolve_recipe_recursive_deduct(db, recipe.id, float(quantity), order_id)

    # 3. Check for Low Stock Alert (on the MenuItem)
    if item.stock_level <= item.low_stock_threshold:
        event = LowStockEvent(
            item_id=item.id,
            item_name=item.name,
            current_stock=item.stock_level,
            threshold=item.low_stock_threshold
        )
        await event_bus.publish(event)
    
    # 4. Process combo components recursively
    for combo_link in item.combo_items:
        component = db.query(MenuItem).filter(MenuItem.id == combo_link.component_item_id).first()
        if component:
            await _deduct_stock(component, combo_link.quantity * quantity, db, order_id)

def _resolve_recipe_recursive_deduct(db: Session, recipe_id: int, multiplier: float, order_id: int = None):
    """Recursive helper for order handler to deduct stock."""
    ingredients = db.query(RecipeIngredient).filter(RecipeIngredient.recipe_id == recipe_id).all()
    for ri in ingredients:
        total_needed = ri.quantity * multiplier * ri.yield_factor
        if ri.ingredient_id:
            ingredient = db.query(Ingredient).filter(Ingredient.id == ri.ingredient_id).first()
            if ingredient:
                prev_stock = ingredient.current_stock
                ingredient.current_stock -= total_needed
                new_stock = ingredient.current_stock
                
                # Record Audit Trail
                transaction = StockTransaction(
                    ingredient_id=ingredient.id,
                    quantity=-total_needed,
                    previous_stock=prev_stock,
                    new_stock=new_stock,
                    reference_type="order",
                    reference_id=str(order_id) if order_id else None,
                    reason="order-deduction",
                    notes=f"Order {order_id} deduction (Live Order)"
                )
                db.add(transaction)
        elif ri.sub_recipe_id:
            _resolve_recipe_recursive_deduct(db, ri.sub_recipe_id, total_needed, order_id)

async def _restore_stock(item: MenuItem, quantity: int, db: Session, order_id: int = None):
    """Recursively restores stock for an item, its combo components, and its ingredients."""
    # 1. Restore MenuItem stock_level
    item.stock_level += quantity
    
    # 2. Restore Ingredients (Recipe-based)
    recipe = db.query(Recipe).filter(Recipe.menu_item_id == item.id, Recipe.recipe_type == "main").first()
    if recipe:
        _resolve_recipe_recursive_restore(db, recipe.id, float(quantity), order_id)

    # 3. Process combo components recursively
    for combo_link in item.combo_items:
        component = db.query(MenuItem).filter(MenuItem.id == combo_link.component_item_id).first()
        if component:
            await _restore_stock(component, combo_link.quantity * quantity, db, order_id)

def _resolve_recipe_recursive_restore(db: Session, recipe_id: int, multiplier: float, order_id: int = None):
    """Recursive helper for order handler to restore stock."""
    ingredients = db.query(RecipeIngredient).filter(RecipeIngredient.recipe_id == recipe_id).all()
    for ri in ingredients:
        total_restored = ri.quantity * multiplier * ri.yield_factor
        if ri.ingredient_id:
            ingredient = db.query(Ingredient).filter(Ingredient.id == ri.ingredient_id).first()
            if ingredient:
                prev_stock = ingredient.current_stock
                ingredient.current_stock += total_restored
                new_stock = ingredient.current_stock
                
                # Record Audit Trail
                transaction = StockTransaction(
                    ingredient_id=ingredient.id,
                    quantity=total_restored,
                    previous_stock=prev_stock,
                    new_stock=new_stock,
                    reference_type="order_cancel",
                    reference_id=str(order_id) if order_id else None,
                    reason="order-restoration",
                    notes=f"Order {order_id} restoration"
                )
                db.add(transaction)
        elif ri.sub_recipe_id:
            _resolve_recipe_recursive_restore(db, ri.sub_recipe_id, total_restored, order_id)

async def handle_create_order(cmd: CreateOrderCommand, db: Session) -> Order:
    """Handles the creation of a new order."""
    print(f"\n[CREATE ORDER] Starting for Table {cmd.table_id}...")
    order_data = {
        "table_id": cmd.table_id,
        "user_id": cmd.user_id,
        "device_id": cmd.device_id,
        "status": "Pending",
        "order_type": cmd.order_type,
        "room_number": getattr(cmd, 'room_number', None),
        "customer_mobile": getattr(cmd, 'customer_mobile', None),
        "total_amount": 0.0,
        "discount_amount": cmd.discount_amount,
        "tax_rate": cmd.tax_rate,
        "counter_id": cmd.counter_id
    }
    
    if hasattr(cmd, 'payment_method') and cmd.payment_method is not None:
        order_data["payment_method"] = cmd.payment_method
    
    new_order = Order(**order_data)
    print(f"[CREATE ORDER] Order object created...")
    
    if hasattr(cmd, 'customer_phone') and cmd.customer_phone:
        customer = db.query(Customer).filter(Customer.phone == cmd.customer_phone).first()
        if not customer:
            customer = Customer(
                phone=cmd.customer_phone,
                name=getattr(cmd, 'customer_name', None)
            )
            db.add(customer)
            db.flush()
        elif getattr(cmd, 'customer_name', None):
            customer.name = cmd.customer_name
            db.add(customer)
            
        new_order.customer_id = customer.id

    db.add(new_order)
    db.flush() # Get order ID for items
    print(f"[CREATE ORDER] Table entries flushed. ID: {new_order.id}")
    
    # Process initial items if provided
    total_amount = 0.0
    if hasattr(cmd, 'items') and cmd.items:
        print(f"[CREATE ORDER] Processing {len(cmd.items)} items...")
        for item_data in cmd.items:
            item_id = item_data.get('menu_item_id') or item_data.get('item_id')
            qty = item_data.get('quantity', 1)
            notes = item_data.get('notes')
            
            menu_item = db.query(MenuItem).filter(MenuItem.id == item_id).first()
            if menu_item:
                await _deduct_stock(menu_item, qty, db, new_order.id)
                
                order_item = OrderItem(
                    order_id=new_order.id,
                    item_id=item_id,
                    quantity=qty,
                    price=menu_item.price,
                    name=menu_item.name,
                    notes=notes,
                    status="Pending"
                )
                db.add(order_item)
                total_amount += (menu_item.price * qty)

    new_order.total_amount = total_amount
    print(f"[CREATE ORDER] Items added. Total: {total_amount}")
    
    # Update table status only if table_id is provided and non-zero
    if cmd.table_id and cmd.table_id > 0:
        table = db.query(Table).filter(Table.id == cmd.table_id).first()
        if table:
            table.status = "Occupied"
            # Notify about table status change
            table_event = TableUpdatedEvent(
                table_id=table.id,
                status="Occupied",
                is_reserved=False
            )
            await event_bus.publish(table_event)
            print(f"[CREATE ORDER] Table {cmd.table_id} status updated to Occupied")
    
    print(f"[CREATE ORDER] Pre-commit...")
    db.commit()
    db.refresh(new_order)
    print(f"[CREATE ORDER] Committed to DB!")

    # Fire WebSocket event for KDS (Kitchen Display System)
    try:
        print(f"[CREATE ORDER] Broadcasting to WebSockets...")
        kds_event = OrderCreatedEvent(
            order_id=new_order.id,
            table_id=new_order.table_id if new_order.table_id and new_order.table_id > 0 else None,
            device_id=new_order.device_id,
            data=OrderResponse.model_validate(new_order).model_dump()
        )
        await event_bus.publish(kds_event)
        print(f"[CREATE ORDER] Broadcast complete! Done.")
    except Exception as e:
         print(f"[CREATE ORDER] WebSocket Broadcast Error (Ignored): {e}")

    # We do this after commit/refresh so all data is available
    return new_order

async def handle_add_item_to_order(cmd: AddItemToOrderCommand, db: Session) -> OrderItem:
    """Handles adding an item to an existing order with stock management."""
    item = db.query(MenuItem).filter(MenuItem.id == cmd.item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Menu item not found")

    # Decrement stock recursively
    await _deduct_stock(item, cmd.quantity, db, cmd.order_id)

    # Check for existing item with same ID and notes to prevent duplicates
    existing_item = db.query(OrderItem).filter(
        OrderItem.order_id == cmd.order_id,
        OrderItem.item_id == cmd.item_id,
        OrderItem.notes == cmd.notes,
        OrderItem.status == "Pending"
    ).first()

    if existing_item:
        print(f"UPDATING quantity for existing item {cmd.item_id} in order {cmd.order_id}: {existing_item.quantity} -> {existing_item.quantity + cmd.quantity}")
        existing_item.quantity += cmd.quantity
        order_item = existing_item
    else:
        print(f"INSERTING new item {cmd.item_id} into order {cmd.order_id}")
        order_item = OrderItem(
            order_id=cmd.order_id,
            item_id=cmd.item_id,
            quantity=cmd.quantity,
            price=item.price,
            name=item.name,
            notes=cmd.notes,
            status="Pending"
        )
        db.add(order_item)
    
    # Update order total
    order = db.query(Order).filter(Order.id == cmd.order_id).first()
    if order:
        order.total_amount += (item.price * cmd.quantity)
        
    db.commit()
    db.refresh(order_item)
    return order_item

async def handle_remove_item_from_order(cmd: RemoveItemFromOrderCommand, db: Session):
    """Handles removing an item and restoring stock."""
    order_item = db.query(OrderItem).filter(OrderItem.id == cmd.order_item_id, OrderItem.order_id == cmd.order_id).first()
    if not order_item:
        raise HTTPException(status_code=404, detail="Order item not found")

    # Restore stock recursively
    item = db.query(MenuItem).filter(MenuItem.id == order_item.item_id).first()
    if item:
        await _restore_stock(item, order_item.quantity, db, cmd.order_id)

    # Update order total
    order = db.query(Order).filter(Order.id == cmd.order_id).first()
    if order:
        order.total_amount -= (order_item.price * order_item.quantity)

    db.delete(order_item)
    db.commit()
    return {"status": "success"}

# Register handlers
command_bus.register(CreateOrderCommand, handle_create_order)
command_bus.register(AddItemToOrderCommand, handle_add_item_to_order)
command_bus.register(RemoveItemFromOrderCommand, handle_remove_item_from_order)

import backend.commands.status_handlers