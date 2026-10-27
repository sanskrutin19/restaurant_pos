from sqlalchemy.orm import Session, joinedload
from backend.models.order import Order, OrderItem
from backend.models.catalog import MenuItem
from backend.schemas.commands import CreateOrderCommand, AddItemToOrderCommand, SendOrderToKitchenCommand, PrintKOTCommand
from backend.commands.core import command_bus
from backend.events.core import event_bus
from backend.schemas.events import OrderCreatedEvent, ItemAddedEvent, OrderSentToKitchenEvent
from backend.models.system import PrinterJob, KitchenCounter

async def create_new_order(db: Session, req_data: CreateOrderCommand):
    """
    Service to execute the CreateOrder command and emit the corresponding event.
    """
    # 1. Dispatch Command
    order = await command_bus.dispatch(req_data, db)
    
    # 2. Publish Event
    event = OrderCreatedEvent(
        order_id=order.id,
        table_id=order.table_id,
        device_id=order.device_id
    )
    await event_bus.publish(event, db)
    
    return order

async def add_item_to_order(db: Session, req_data: AddItemToOrderCommand):
    """
    Service to execute AddItem command and emit the corresponding event.
    """
    # 1. Dispatch Command
    order_item = await command_bus.dispatch(req_data, db)
    
    # 2. Publish Event
    event = ItemAddedEvent(
        order_id=order_item.order_id,
        order_item_id=order_item.id,
        item_id=order_item.item_id,
        quantity=order_item.quantity
    )
    await event_bus.publish(event, db)
    
    return order_item

def get_orders(db: Session, skip: int = 0, limit: int = 100, date_filter: str = None):
    """Query side (CQRS) - Read operations"""
    from sqlalchemy import func
    query = db.query(Order).options(
        joinedload(Order.items).joinedload(OrderItem.menu_item),
        joinedload(Order.items).joinedload(OrderItem.modifiers),
        joinedload(Order.customer)
    )
    
    if date_filter:
        query = query.filter(func.date(Order.created_at) == date_filter)
        
    return query.order_by(Order.id.desc()).offset(skip).limit(limit).all()

def get_order_by_id(db: Session, order_id: int):
    return db.query(Order).options(
        joinedload(Order.items).joinedload(OrderItem.menu_item).joinedload(MenuItem.category),
        joinedload(Order.items).joinedload(OrderItem.modifiers),
        joinedload(Order.customer)
    ).filter(Order.id == order_id).first()


async def handle_print_kot(cmd: PrintKOTCommand, db: Session):
    """Handler to push KOT print jobs to the correct kitchen station queues."""
    order = get_order_by_id(db, cmd.order_id)
    if not order:
        raise ValueError("Order not found")
        
    # Group items by their kitchen counter
    counter_jobs = {} # counter_id -> list of items
    for item in order.items:
        # 1. Check item-level override
        # 2. Check category-level mapping
        counter_id = getattr(item.menu_item, 'kitchen_counter_id', None)
        if not counter_id and item.menu_item and item.menu_item.category:
            counter_id = item.menu_item.category.kitchen_counter_id
            
        if counter_id:
            if counter_id not in counter_jobs:
                counter_jobs[counter_id] = []
            counter_jobs[counter_id].append(item)
    
    # If no counters mapped, we might want a default, but for now we only print if mapped
    if not counter_jobs:
        print(f"[PrintKOT] WARNING: No kitchen counters mapped for items in Order #{cmd.order_id}")
        return []
    
    jobs = []
    for counter_id, items in counter_jobs.items():
        counter = db.query(KitchenCounter).filter(KitchenCounter.id == counter_id).first()
        if not counter:
            continue
            
        printer_name = counter.printer_address
        if not printer_name:
            print(f"[PrintKOT] SKIP: Counter '{counter.name}' has no printer address configured.")
            continue
            
        # Create the job for this specific counter's printer
        job = PrinterJob(
            printer_name=printer_name,
            document_type="kitchen_ticket",
            reference_id=str(cmd.order_id),
            status="Pending"
        )
        db.add(job)
        jobs.append(job)
        print(f"[PrintKOT] Created job for Order #{cmd.order_id} on printer '{printer_name}' (Station: {counter.name})")

    db.commit()
    return jobs

command_bus.register(PrintKOTCommand, handle_print_kot)
