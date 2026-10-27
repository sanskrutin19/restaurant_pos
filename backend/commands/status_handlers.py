import asyncio
from sqlalchemy.orm import Session
from backend.models.order import Order
from backend.services.state_machine import OrderStateMachine, InvalidStateTransitionError
from backend.schemas.commands import MarkOrderReadyCommand, SendOrderToKitchenCommand
from backend.commands.core import command_bus
from backend.events.core import event_bus
from backend.schemas.events import OrderStatusUpdatedEvent

async def handle_send_to_kitchen(cmd: SendOrderToKitchenCommand, db: Session) -> Order:
    from backend.models.system import Table
    from backend.schemas.events import TableUpdatedEvent
    
    order = db.query(Order).filter(Order.id == cmd.order_id).first()
    if not order:
        raise ValueError("Order not found")
        
    OrderStateMachine.validate_transition(order.status, "Preparing")
    order.status = "Preparing"
    
    # Mark items as sent to kitchen
    from backend.models.order import OrderItem
    db.query(OrderItem).filter(OrderItem.order_id == order.id).update({"is_sent_to_kitchen": True})
    
    # Update table status if applicable
    if order.table_id:
        table = db.query(Table).filter(Table.id == order.table_id).first()
        if table:
            table.status = "Preparing"
            # Notify POS
            table_event = TableUpdatedEvent(
                table_id=table.id,
                status="Preparing",
                is_reserved=table.is_reserved
            )
            await event_bus.publish(table_event)

    db.commit()
    db.refresh(order)
    
    # Notify KDS/POS
    event = OrderStatusUpdatedEvent(
        order_id=order.id,
        status=order.status.lower(),
        data={'order_id': order.id, 'status': order.status.lower()}
    )
    await event_bus.publish(event)
    
    # NEW: Automatically trigger Printer Jobs for KOT
    from backend.schemas.commands import PrintKOTCommand
    kot_cmd = PrintKOTCommand(order_id=order.id, mode="all")
    await command_bus.dispatch(kot_cmd, db)
    
    return order

async def handle_mark_ready(cmd: MarkOrderReadyCommand, db: Session) -> Order:
    from backend.models.system import Table
    from backend.schemas.events import TableUpdatedEvent
    
    order = db.query(Order).filter(Order.id == cmd.order_id).first()
    if not order:
        raise ValueError("Order not found")
        
    OrderStateMachine.validate_transition(order.status, "Ready")
    order.status = "Ready"
    
    # Update table status if applicable
    if order.table_id:
        table = db.query(Table).filter(Table.id == order.table_id).first()
        if table:
            table.status = "Ready"
            # Notify POS
            table_event = TableUpdatedEvent(
                table_id=table.id,
                status="Ready",
                is_reserved=table.is_reserved
            )
            await event_bus.publish(table_event)

    db.commit()
    db.refresh(order)

    # Notify KDS/POS
    event = OrderStatusUpdatedEvent(
        order_id=order.id,
        status=order.status.lower(),
        data={'order_id': order.id, 'status': order.status.lower()}
    )
    await event_bus.publish(event)

    return order

command_bus.register(SendOrderToKitchenCommand, handle_send_to_kitchen)
command_bus.register(MarkOrderReadyCommand, handle_mark_ready)
