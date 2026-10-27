import asyncio
from sqlalchemy.orm import Session
from backend.models.billing import Payment, Bill
from backend.models.order import Order
from backend.schemas.commands import RecordPaymentCommand
from backend.commands.core import command_bus
from backend.services.state_machine import OrderStateMachine
from backend.models.system import Table
from backend.events.core import event_bus
from backend.schemas.events import TableUpdatedEvent


async def handle_record_payment(cmd: RecordPaymentCommand, db: Session) -> Payment:
    order = db.query(Order).filter(Order.id == cmd.order_id).first()
    if not order:
        raise ValueError("Order not found")

    # Calculate total paid so far (for split payment support)
    existing_payments = db.query(Payment).filter(
        Payment.order_id == cmd.order_id,
        Payment.status == "Completed"
    ).all()
    total_paid = sum(p.amount for p in existing_payments) + cmd.amount

    # Record this payment
    payment = Payment(
        order_id=cmd.order_id,
        amount=cmd.amount,
        payment_method=cmd.payment_method,
        status="Completed"
    )
    db.add(payment)

    # Check if fully paid — compare against bill total or calculated order total
    bill = db.query(Bill).filter(Bill.order_id == cmd.order_id).first()
    
    if bill:
        required_total = bill.total_amount
    else:
        # Calculate expected total using order-specific tax/discount
        subtotal = sum(item.price * item.quantity for item in order.items if item.status.lower() != 'cancelled')
        discount = getattr(order, 'discount_amount', 0.0)
        tax_rate = getattr(order, 'tax_rate', 5.0)
        
        taxable_amount = max(0, subtotal - discount)
        tax = taxable_amount * (tax_rate / 100)
        required_total = round(taxable_amount + tax, 2)

    if total_paid >= required_total:
        # Fully paid - update order status
        order.status = "Paid"
            
        # Reset table status for new guests
        if order.table_id and order.table_id > 0:
            table = db.query(Table).filter(Table.id == order.table_id).first()
            if table:
                table.status = "Available"
                # Fire WebSocket event for table status update
                event = TableUpdatedEvent(
                    table_id=table.id,
                    status="Available",
                    is_reserved=table.is_reserved,
                    reserved_for=table.reserved_for
                )
                # Ensure the event is published correctly
                try:
                    await event_bus.publish(event)
                except Exception as e:
                    print(f"Error publishing table update: {e}")
    
    db.commit()
    db.refresh(payment)
    db.refresh(order)
    
    # Award Loyalty Points if customer is linked and fully paid
    if order.customer_id and total_paid >= required_total:
        from backend.services.loyalty import add_points
        add_points(db, order.customer_id, required_total)

    return payment

command_bus.register(RecordPaymentCommand, handle_record_payment)
