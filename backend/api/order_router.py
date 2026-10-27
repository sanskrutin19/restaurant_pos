from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import HTMLResponse
from sqlalchemy.orm import Session, joinedload
from backend.security.auth import get_current_user, get_current_user_optional
from sqlalchemy import func, text
from typing import List, Optional, cast as t_cast
from datetime import datetime, timedelta
from pydantic import BaseModel, Field

class UpdateOrderRequest(BaseModel):
    customer_name: Optional[str] = None
    customer_phone: Optional[str] = None
    order_type: Optional[str] = None
    discount_amount: Optional[float] = None
    tax_rate: Optional[float] = None
    user_id: Optional[int] = None
    device_id: Optional[int] = None

class UpdateOrderStatusRequest(BaseModel):
    status: str

from backend.database.core import get_db
from backend.schemas.orders import CreateOrderRequest, AddItemRequest, OrderResponse, OrderItemResponse
from backend.schemas.commands import CreateOrderCommand, AddItemToOrderCommand
from backend.services import order as order_service
from backend.services import billing as billing_service
from backend.services.billing import generate_bill
from backend.models.system import Table, PrinterJob
from backend.models.order import Order as OrderModel, OrderItem, OrderItem as OrderItemModel
from backend.models.billing import Payment, Bill
from backend.models.catalog import MenuItem
from backend.models.customer import Customer
from backend.events.core import event_bus
from backend.schemas.events import TableUpdatedEvent
from backend.api.inventory_router import log_audit
from backend.models.user import User
from backend.models.kot import KOTLog
from backend.schemas.kot import KOTLogResponse, CancelKOTRequest
from backend.utils.frozen_logger import log_msg

router = APIRouter(prefix="/orders", tags=["Orders"])

@router.post("", response_model=OrderResponse)
async def create_order(request: CreateOrderRequest, db: Session = Depends(get_db)):
    # Map payment method int to string
    payment_str = {1: 'cash', 2: 'card', 3: 'upi'}.get(request.payment_method) if request.payment_method else None

    cmd = CreateOrderCommand(
        table_id=request.table_id,
        user_id=request.user_id,
        device_id=request.device_id,
        payment_method=payment_str,
        order_type=request.order_type,
        customer_name=request.customer_name,
        customer_phone=request.customer_phone,
        discount_amount=request.discount_amount,
        tax_rate=request.tax_rate,
        counter_id=request.counter_id,
        items=request.items
    )
    order = await order_service.create_new_order(db, cmd)
    log_audit(db, "CREATE", "order", order.id, f"New order created for Table {order.table_id or 'Takeaway'}", user_id=order.user_id)
    return order

@router.post("/{order_id}/items")
async def add_items_to_order(order_id: int, items: list, db: Session = Depends(get_db)):
    # Verify order exists
    order = order_service.get_order_by_id(db, order_id)
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    if order.status.lower() in ("paid", "cancelled"):
        raise HTTPException(status_code=400, detail=f"Cannot add items to a {order.status} order.")

    try:
        for item_data in items:
            item_id = item_data.get('menu_item_id') or item_data.get('item_id')
            if not item_id:
                log_msg(f"ERROR: Item data missing ID: {item_data}")
                raise HTTPException(status_code=400, detail="Each item must have a menu_item_id")
                
            cmd = AddItemToOrderCommand(
                order_id=order_id,
                item_id=item_id,
                quantity=item_data.get('quantity', 1),
                notes=item_data.get('notes')
            )
            await order_service.add_item_to_order(db, cmd)
        
        return {"status": "success"}
    except Exception as e:
        import traceback
        log_msg(f"ERROR adding items to order {order_id}:\n{traceback.format_exc()}")
        raise HTTPException(status_code=400, detail=str(e))

@router.get("", response_model=List[OrderResponse])
def read_orders(skip: int = 0, limit: int = 100, date: str = Query(None), db: Session = Depends(get_db)):
    """Get all orders with their items (including item names and prices)"""
    orders = order_service.get_orders(db, skip=skip, limit=limit, date_filter=date)
    return orders

# IMPORTANT: Specific routes BEFORE generic /{order_id} route
@router.get("/summary")
def get_order_summary(db: Session = Depends(get_db)):
    """Get all orders with statistics for Dashboard"""
    try:
        # Total orders (all time or current session, but usually all time in this context)
        total_orders = db.query(func.count(OrderModel.id)).scalar() or 0
        
        # Revenue only from confirmed/completed orders, excluding cancelled items
        # Revenue ONLY from PAID orders
        confirmed_statuses = ['paid', 'Paid']
        
        total_revenue = db.query(
            func.sum(OrderItemModel.price * OrderItemModel.quantity)
        ).join(OrderModel).filter(
            OrderModel.status.in_(confirmed_statuses),
            OrderItemModel.status.notin_(['cancelled', 'Cancelled'])
        ).scalar() or 0.0
        
        # Orders by status via GROUP BY
        status_rows = db.query(
            OrderModel.status, func.count(OrderModel.id)
        ).group_by(OrderModel.status).all()
        orders_by_status = {row[0]: row[1] for row in status_rows}
        
        # Revenue Trend for last 7 days
        start_trend = datetime.now() - timedelta(days=7)
        revenue_trend = db.query(
            func.date(OrderModel.created_at).label('day'),
            func.sum(OrderModel.total_amount).label('revenue')
        ).filter(
            OrderModel.status.in_(confirmed_statuses),
            OrderModel.created_at >= start_trend
        ).group_by(func.date(OrderModel.created_at)).all()

        return {
            "total_orders": total_orders,
            "total_revenue": float(total_revenue),
            "orders_by_status": orders_by_status,
            "revenue_trend": [
                {"day": row.day, "revenue": row.revenue}
                for row in revenue_trend
            ]
        }
    except Exception as e:
        return {
            "total_orders": 0,
            "total_revenue": 0.0,
            "orders_by_status": {}
        }

# ── Hold / Resume Endpoints ────────────────────────────────────────────

@router.get("/held")
def get_held_orders(db: Session = Depends(get_db)):
    """Get all held orders"""
    orders = db.query(OrderModel).options(
        joinedload(OrderModel.items).joinedload(OrderItemModel.menu_item)
    ).filter(OrderModel.status == "held").order_by(OrderModel.held_at.desc()).all()
    
    # Enrich items with menu item names
    for order_any in orders:
        order: OrderModel = t_cast(OrderModel, order_any)
        order_items: List[OrderItemModel] = t_cast(List[OrderItemModel], order.items)
        for item in order_items:
            if item.menu_item and not item.name:
                item.name = item.menu_item.name
    
    return orders

@router.put("/{order_id}/hold")
async def hold_order(order_id: int, db: Session = Depends(get_db), current_user = Depends(get_current_user_optional)):
    """Put an order on hold"""

    order = db.query(OrderModel).filter(OrderModel.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    
    # Allow holding Pending, Created, OR Preparing orders
    valid_statuses = ("pending", "created", "preparing", "sending to kitchen")
    
    if order.status.lower() == "held":
        return order # Already held, do nothing
        
    if order.status.lower() not in valid_statuses:
        msg = f"Cannot hold order #{order_id} in '{order.status}' status. Valid: {valid_statuses}"
        log_msg(f"HOLD ERROR: {msg}")
        raise HTTPException(status_code=400, detail=msg)
    
    old_status = order.status
    order.status = "Held"
    order.held_at = datetime.utcnow()
    
    # Update table status
    table = db.query(Table).filter(Table.id == order.table_id).first()
    if table:
        table.status = "Held"
        
    db.commit()
    db.refresh(order)
    log_audit(db, "UPDATE", "order", order.id, f"Order status: Held", user_id=current_user.id if current_user else 1)
    
    # Fire WebSocket event
    if table:
        event = TableUpdatedEvent(
            table_id=table.id,
            status=table.status,
            is_reserved=table.is_reserved,
            reserved_for=table.reserved_for
        )
        await event_bus.publish(event)
    
    return {"message": f"Order #{order.id} is now on hold", "order_id": order.id}

@router.patch("/{order_id}")
async def update_order(order_id: int, request: dict, db: Session = Depends(get_db), current_user = Depends(get_current_user_optional)):
    """Update order details (like customer info)"""
    order = db.query(OrderModel).filter(OrderModel.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    
    # Extract customer fields that need special handling
    cust_name = request.pop('customer_name', None)
    cust_phone = request.pop('customer_phone', None)
    
    # Process standard Order model fields
    for key, value in request.items():
        if hasattr(order, key) and value is not None:
            setattr(order, key, value)
    
    # Handle customer linking: create/update Customer record
    phone_to_use = cust_phone or request.get('customer_mobile')
    if phone_to_use:
        customer = db.query(Customer).filter(Customer.phone == phone_to_use).first()
        if not customer:
            customer = Customer(phone=phone_to_use, name=cust_name)
            db.add(customer)
            db.flush()
        elif cust_name:
            customer.name = cust_name
            db.add(customer)
        order.customer_id = customer.id
    elif cust_name and order.customer_id:
        # Update name on existing linked customer
        customer = db.query(Customer).filter(Customer.id == order.customer_id).first()
        if customer:
            customer.name = cust_name
            db.add(customer)
    
    db.commit()
    db.refresh(order)
    return order


@router.patch("/{order_id}/status")
async def update_order_status(order_id: int, request: UpdateOrderStatusRequest, db: Session = Depends(get_db), current_user = Depends(get_current_user_optional)):
    """Update order status (Send to Kitchen, Ready etc)"""
    new_status = request.status.title()
    if not new_status:
        raise HTTPException(status_code=400, detail="Status is required")
        
    from backend.schemas.commands import SendOrderToKitchenCommand, MarkOrderReadyCommand
    from backend.commands.core import command_bus
    
    if new_status.lower() in ["preparing", "send to kitchen"]:
        cmd = SendOrderToKitchenCommand(order_id=order_id)
    elif new_status.lower() == "ready":
        cmd = MarkOrderReadyCommand(order_id=order_id)
    elif new_status.lower() == "served":
        # We can handle Served via generic status update for now, or add a command if needed
        order = db.query(OrderModel).filter(OrderModel.id == order_id).first()
        if not order:
            raise HTTPException(status_code=404, detail="Order not found")
        order.status = "Served"
        
        # AUTO-RELEASE TABLE
        if order.table_id:
            table = db.query(Table).filter(Table.id == order.table_id).first()
            if table:
                table.status = "Available"
                event = TableUpdatedEvent(
                    table_id=table.id,
                    status="Available",
                    is_reserved=table.is_reserved,
                    reserved_for=table.reserved_for
                )
                await event_bus.publish(event)
        
        db.commit()
        db.refresh(order)
        log_audit(db, "UPDATE", "order", order.id, "Order marked as Served", user_id=current_user.id if current_user else 1)
        return order
    elif new_status.lower() == "paid":
        order = db.query(OrderModel).filter(OrderModel.id == order_id).first()
        if not order:
            raise HTTPException(status_code=404, detail="Order not found")
        
        # 1. Generate Bill (handles taxes CGST/SGST)
        # Use stored tax_rate and discount_amount from the order
        bill = generate_bill(
            db, 
            order_id, 
            tax_rate=order.tax_rate, 
            discount=order.discount_amount,
            counter_id=order.counter_id
        )
        
        # 2. Record Payment if none exists
        existing_payment = db.query(Payment).filter(Payment.order_id == order_id).first()
        if not existing_payment:
            payment = Payment(
                order_id=order_id,
                amount=bill.total_amount,
                payment_method="Cash",
                status="Completed"
            )
            db.add(payment)
            
        order.status = "Paid"
        
        # Release Table
        if order.table_id:
            table = db.query(Table).filter(Table.id == order.table_id).first()
            if table:
                table.status = "Available"
                # Notify POS
                table_event = TableUpdatedEvent(table_id=table.id, status="Available")
                await event_bus.publish(table_event)

        db.commit()
        db.refresh(order)
        log_audit(db, "UPDATE", "order", order.id, "Order marked as Paid", user_id=current_user.id if current_user else 1)
        return order
    else:
        # Generic status update for other cases (e.g., Cancelled)
        order = db.query(OrderModel).filter(OrderModel.id == order_id).first()
        if not order:
            raise HTTPException(status_code=404, detail="Order not found")
        
        old_status = order.status
        order.status = new_status # already titled
        
        # ── NEW: Handle Stock Restoration on Cancellation ──
        if new_status.lower() == "cancelled":
            for item in order.items:
                if item.status.lower() != "cancelled": 
                    item.status = "Cancelled"
            
            # If cancelled, release table
            if order.table_id:
                table = db.query(Table).filter(Table.id == order.table_id).first()
                if table:
                    table.status = "Available"
                    await event_bus.publish(TableUpdatedEvent(table_id=table.id, status="Available"))

        db.commit()
        db.refresh(order)
        log_audit(db, "STATUS", "order", order.id, f"Order status changed to {new_status}", user_id=current_user.id if current_user else 1)
        return order
        
    try:
        from backend.services.state_machine import InvalidStateTransitionError
        updated_order = await command_bus.dispatch(cmd, db)
        return updated_order
    except (ValueError, InvalidStateTransitionError) as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        import traceback
        log_msg(f"CRITICAL ERROR updating status for Order {order_id}:\n{traceback.format_exc()}")
        raise HTTPException(status_code=400, detail=str(e))

# Redundant update_order route already merged/removed

@router.put("/{order_id}/resume")
async def resume_order(order_id: int, db: Session = Depends(get_db), current_user = Depends(get_current_user)):
    """Resume a held order"""

    order = db.query(OrderModel).filter(OrderModel.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    
    if order.status != "held":
        raise HTTPException(status_code=400, detail="Only held orders can be resumed")
    
    order.status = "pending"
    order.held_at = None
    
    # Update table status
    table = db.query(Table).filter(Table.id == order.table_id).first()
    if table:
        table.status = "Occupied"
        
    db.commit()
    db.refresh(order)
    
    # Fire WebSocket event
    if table:
        event = TableUpdatedEvent(
            table_id=table.id,
            status=table.status,
            is_reserved=table.is_reserved,
            reserved_for=table.reserved_for
        )
        await event_bus.publish(event)
    
    return {"message": f"Order #{order.id} resumed", "order_id": order.id}


@router.get("/{order_id}/bill", response_class=HTMLResponse)
async def print_bill(
    order_id: int, 
    restaurant_name: str = "THE RESTAURANT POS", 
    address: str = "",
    phone: str = "",
    gstin: str = "",
    fssai: str = "",
    footer: str = "Thank you for dining with us!",
    tax_label: str = "GST",
    tax_rate: Optional[float] = None,
    discount: float = 0.0,
    counter_id: Optional[str] = None,
    db: Session = Depends(get_db)
):
    """Generate printable HTML bill specialized for 80mm thermal printers"""
    from backend.models.system import SystemSettings
    
    # FETCH SETTINGS FROM DB AS FALLBACK
    db_settings = {s.key: s.value for s in db.query(SystemSettings).all()}
    
    # Apply fallbacks
    r_name = restaurant_name if restaurant_name != "THE RESTAURANT POS" else db_settings.get('restaurant_name', restaurant_name)
    r_addr = address if address != "" else db_settings.get('restaurant_address', "")
    r_phone = phone if phone != "" else db_settings.get('restaurant_phone', "")
    r_gstin = gstin if gstin != "" else db_settings.get('gstin', "")
    r_fssai = fssai if fssai != "" else db_settings.get('fssai_license', "")
    r_footer = footer if footer != "Thank you for dining with us!" else db_settings.get('bill_footer', footer)
    r_tax_label = tax_label if tax_label != "GST" else db_settings.get('tax_label', tax_label)
    r_currency = db_settings.get('currency_symbol', "Rs.")

    order: OrderModel = order_service.get_order_by_id(db, order_id)
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
        
    if tax_rate is None:
        tax_rate = billing_service.get_tax_rate(db)
        
    bill = billing_service.generate_bill(db, order_id, tax_rate=tax_rate, discount=discount)
    
    currency_symbol = "Rs."
    
    customer = None
    if order.customer_id:
        customer = db.query(Customer).filter(Customer.id == order.customer_id).first()

    # Pre-calculate to avoid linter issues
    half_tax = (tax_rate or 0.0) / 2.0
    
    # Use a list for building HTML to avoid += linter issues
    html_parts = []
    
    html_parts.append(f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {{ font-family: 'Courier New', Courier, monospace; width: 80mm; margin: 0; padding: 2mm; color: #000; font-size: 10pt; line-height: 1.2; }}
        .center {{ text-align: center; }}
        .bold {{ font-weight: bold; }}
        .header {{ margin-bottom: 4mm; }}
        .header h1 {{ margin: 0; font-size: 16pt; }}
        .dashed-line {{ border-top: 1px dashed #000; margin: 2mm 0; }}
        .info-row {{ display: flex; justify-content: space-between; margin-bottom: 1mm; }}
        .item-table {{ width: 100%; margin: 2mm 0; border-collapse: collapse; }}
        .item-table th {{ border-bottom: 1px dashed #000; text-align: left; padding: 1mm 0; }}
        .item-table td {{ padding: 1mm 0; vertical-align: top; }}
        .totals-section {{ width: 100%; margin-top: 2mm; }}
        .total-row {{ display: flex; justify-content: space-between; margin-bottom: 1mm; }}
        .grand-total {{ font-size: 12pt; border-top: 1px solid #000; padding-top: 1mm; margin-top: 1mm; }}
        .footer {{ margin-top: 6mm; font-size: 9pt; }}
        @media print {{ .no-print {{ display: none; }} }}
    </style>
</head>
<body onload="window.print()">
  <div class="center header">
        <h1 class="bold">{r_name}</h1>
        {f'<div>{r_addr}</div>' if r_addr else ''}
        {f'<div>Ph: {r_phone}</div>' if r_phone else ''}
        {f'<div style="font-size: 8pt;">GSTIN: {r_gstin}</div>' if r_gstin else ''}
        {f'<div style="font-size: 8pt;">FSSAI: {r_fssai}</div>' if r_fssai else ''}
        <div class="bold" style="margin-top: 2mm;">TAX INVOICE</div>
    </div>
    
    <div class="dashed-line"></div>
    
    <div class="info-row">
        <span>BILL: {bill.id}</span>
        <span>ORD: #{order.id}</span>
    </div>
    <div class="info-row">
        <span class="bold">TABLE: {order.table_id or 'TAKEAWAY'}</span>
        <span>{(order.order_type or "").upper()}</span>
        {f' | Counter: {counter_id}' if counter_id else ''}
    </div>
    <div class="info-row">
        <span>DATE: {order.created_at.strftime('%d/%m/%y %H:%M') if order.created_at else ''}</span>
    </div>
    {f'<div class="info-row"><span>CUST: {customer.name} ({customer.phone})</span></div>' if customer else ''}
    
    <div class="dashed-line"></div>
    
    <table class="item-table">
        <thead>
            <tr>
                <th style="width: 55%;">ITEM</th>
                <th style="width: 15%; text-align: center;">QTY</th>
                <th style="width: 30%; text-align: right;">AMT</th>
            </tr>
        </thead>
        <tbody>
""")

    for item in order.items: # type: OrderItemModel
        if item.status.lower() != 'cancelled':
            html_parts.append(f"""
            <tr>
                <td>{item.name or (item.menu_item.name if item.menu_item else 'Item')}</td>
                <td style="text-align: center;">{item.quantity}</td>
                <td style="text-align: right;">{(item.price * item.quantity):.2f}</td>
            </tr>""")
            
    html_parts.append(f"""
        </tbody>
    </table>
    
    <div class="dashed-line"></div>
    
    <div class="totals-section">
        <div class="total-row"><span>Subtotal:</span> <span>{bill.subtotal:.2f}</span></div>
        {f'<div class="total-row"><span>Discount:</span> <span>-{bill.discount:.2f}</span></div>' if bill.discount > 0 else ''}
        <div class="total-row"><span>C{r_tax_label} ({half_tax}%):</span> <span>{bill.cgst:.2f}</span></div>
        <div class="total-row"><span>S{r_tax_label} ({half_tax}%):</span> <span>{bill.sgst:.2f}</span></div>
        {f'<div class="total-row"><span>Round Off:</span> <span>{bill.round_off:.2f}</span></div>' if bill.round_off != 0 else ''}
        <div class="total-row bold grand-total">
            <span>GRAND TOTAL:</span> 
            <span>{r_currency} {bill.total_amount:.2f}</span>
        </div>
    </div>
    
    {f'<div class="center" style="margin-top: 2mm; font-size: 9pt; font-style: italic;">PAID VIA: {bill.payment_details}</div>' if bill.payment_details else ''}
    
    <div class="footer center">
        <div class="dashed-line"></div>
        <div>{r_footer}</div>
        <div style="font-size: 8pt; margin-top: 2mm;">{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</div>
    </div>
    
    <div class="center no-print" style="margin-top: 10mm;">
        <button onclick="window.print()" style="padding: 10mm 20mm; font-size: 14pt; cursor: pointer;">PRINT RECEIPT</button>
    </div>
</body>
</html>""")

    return HTMLResponse(content="".join(html_parts))

@router.get("/{order_id}/kot")
async def print_kot(order_id: int, mode: str = "all", target_counter_id: Optional[int] = None, counter_id: Optional[str] = None, db: Session = Depends(get_db)):
    """Generate printable HTML KOT for the kitchen"""
    
    order: OrderModel = order_service.get_order_by_id(db, order_id)
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    from backend.models.system import KitchenCounter
    counters = {c.id: c.name for c in db.query(KitchenCounter).all()}
    
    # helper
    def build_kot_html(items, c_name):
        html_parts = []
        html_parts.append(f'''
    <div class="kot-page">
        <div class="center header">
            <h1>KOT #{order.id}</h1>
            <div style="font-size: 16pt; font-weight: bold; margin-top: 1mm;">TABLE: {order.table_id or 'TAKEAWAY'}</div>
            <div>{(order.order_type or "").upper()} | {datetime.now().strftime('%H:%M')}</div>
            <div style="font-size: 14pt; font-weight: bold; margin-top: 2mm;">Counter: {c_name}</div>
        </div>
        <div class="items-list">''')
        for item in items:
            html_parts.append(f'''
            <div class="item-row">
                <span class="qty center">{item.quantity}</span>
                <span>{item.name or (item.menu_item.name if getattr(item, "menu_item", None) else 'Item')}</span>
            </div>''')
            if item.notes:
                html_parts.append(f'<div class="notes">** {item.notes}</div>')
        html_parts.append(f'''
        </div>
        <div class="dashed-line"></div>
        <div class="center" style="font-size: 10pt;">
            ORDERED AT: {order.created_at.strftime('%I:%M %p') if order.created_at else ''}
        </div>
    </div>''')
        return "".join(html_parts)

    kots = []
    
    if mode == "all":
        items = [i for i in order.items if i.status.lower() != 'cancelled']
        if items:
            kots.append(build_kot_html(items, "ALL COUNTERS"))
            
    elif mode == "specific":
        if not target_counter_id:
            raise HTTPException(status_code=400, detail="target_counter_id required for specific mode")
        counter_name = counters.get(target_counter_id, f"Counter #{target_counter_id}")
        
        counter_items = []
        for i in order.items:
            if i.status.lower() != 'cancelled':
                # RESOLVE COUNTER ID (Item -> Category fallback)
                effective_c_id = i.menu_item.kitchen_counter_id if i.menu_item else None
                if effective_c_id is None and i.menu_item and i.menu_item.category:
                    effective_c_id = i.menu_item.category.kitchen_counter_id
                
                if effective_c_id == target_counter_id:
                    counter_items.append(i)
        
        if counter_items:
             kots.append(build_kot_html(counter_items, counter_name))
             
    elif mode == "separate":
        counter_map = {}
        for i in order.items:
            if i.status.lower() != 'cancelled':
                # RESOLVE COUNTER ID (Item -> Category fallback)
                effective_c_id = i.menu_item.kitchen_counter_id if i.menu_item else None
                if effective_c_id is None and i.menu_item and i.menu_item.category:
                    effective_c_id = i.menu_item.category.kitchen_counter_id
                
                if effective_c_id not in counter_map:
                    counter_map[effective_c_id] = []
                counter_map[effective_c_id].append(i)
                
        for cid, group_items in counter_map.items():
            if cid is None:
                c_name = "Main Kitchen"
            else:
                c_name = counters.get(cid, f"Counter #{cid}")
            kots.append(build_kot_html(group_items, c_name))

    full_html = f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {{ font-family: 'Courier New', monospace; width: 80mm; margin: 0; padding: 2mm; line-height: 1.2; }}
        .center {{ text-align: center; }}
        .bold {{ font-weight: bold; }}
        .header {{ border-bottom: 1px dashed #000; padding-bottom: 2mm; margin-bottom: 3mm; }}
        .header h1 {{ margin: 0; font-size: 20pt; }}
        .item-row {{ display: flex; margin: 2mm 0; font-size: 14pt; font-weight: bold; }}
        .qty {{ width: 12mm; border-right: 1px solid #000; margin-right: 3mm; font-size: 18pt; }}
        .notes {{ font-size: 11pt; font-style: italic; margin-left: 15mm; margin-bottom: 2mm; }}
        .dashed-line {{ border-top: 1px dashed #000; margin: 3mm 0; }}
        .kot-page {{ page-break-after: always; margin-bottom: 10mm; }}
        @media print {{ .no-print {{ display: none; }} .kot-page {{ border-bottom: none; }} }}
    </style>
</head>
<body onload="window.print()">
    {"".join(kots)}
    <div class="center no-print" style="margin-top: 10mm;">
        <button onclick="window.print()" style="padding: 10mm 20mm; font-size: 14pt;">PRINT KOT</button>
    </div>
</body>
</html>"""

    return HTMLResponse(content=full_html)

class PrintKotMode(BaseModel):
    mode: str = "all" # all, separate, specific
    counter_id: Optional[int] = None

@router.post("/{order_id}/print-kot")
async def generate_kots(order_id: int, request: PrintKotMode, db: Session = Depends(get_db)):
    """Generate printable HTML KOTs depending on the mode"""
    order: OrderModel = order_service.get_order_by_id(db, order_id)
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    from backend.models.system import KitchenCounter
    counters = {c.id: c.name for c in db.query(KitchenCounter).all()}
    
    # helper
    def build_kot_html(items, c_name):
        html_parts = []
        html_parts.append(f'''<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {{ font-family: 'Courier New', monospace; width: 80mm; margin: 0; padding: 2mm; line-height: 1.2; }}
        .center {{ text-align: center; }}
        .bold {{ font-weight: bold; }}
        .header {{ border-bottom: 1px dashed #000; padding-bottom: 2mm; margin-bottom: 3mm; }}
        .header h1 {{ margin: 0; font-size: 20pt; }}
        .item-row {{ display: flex; margin: 2mm 0; font-size: 14pt; font-weight: bold; }}
        .qty {{ width: 12mm; border-right: 1px solid #000; margin-right: 3mm; font-size: 18pt; }}
        .notes {{ font-size: 11pt; font-style: italic; margin-left: 15mm; margin-bottom: 2mm; }}
        .dashed-line {{ border-top: 1px dashed #000; margin: 3mm 0; }}
        @media print {{ .no-print {{ display: none; }} }}
    </style>
</head>
<body onload="window.print()">
    <div class="center header">
        <h1>KOT #{order.id}</h1>
        <div style="font-size: 16pt; font-weight: bold; margin-top: 1mm;">TABLE: {order.table_id or 'TAKEAWAY'}</div>
        <div>{(order.order_type or "").upper()} | {datetime.now().strftime('%H:%M')}</div>
        <div style="font-size: 14pt; font-weight: bold; margin-top: 2mm;">Counter: {c_name}</div>
    </div>
    <div class="items-list">''')
        for item in items:
            html_parts.append(f'''
            <div class="item-row">
                <span class="qty center">{item.quantity}</span>
                <span>{item.name or (item.menu_item.name if getattr(item, "menu_item", None) else 'Item')}</span>
            </div>''')
            if item.notes:
                html_parts.append(f'<div class="notes">** {item.notes}</div>')
        html_parts.append(f'''
    </div>
    <div class="dashed-line"></div>
    <div class="center" style="font-size: 10pt;">
        ORDERED AT: {order.created_at.strftime('%I:%M %p') if order.created_at else ''}
    </div>
</body>
</html>''')
        return "".join(html_parts)

    kots = []
    
    if request.mode == "all":
        # Check all items, map them to counters
        # If order items have no counter, group as Main Kitchen
        items = [i for i in order.items if i.status.lower() != 'cancelled']
        if items:
            kots.append({
                "counter": "ALL",
                "html": build_kot_html(items, "ALL COUNTERS")
            })
            
    elif request.mode == "specific":
        if not request.counter_id:
            raise HTTPException(status_code=400, detail="counter_id required for specific mode")
        counter_name = counters.get(request.counter_id, f"Counter #{request.counter_id}")
        
        counter_items = []
        for i in order.items:
            if i.status.lower() != 'cancelled':
                mi_c_id = i.menu_item.kitchen_counter_id if i.menu_item else None
                if mi_c_id == request.counter_id:
                    counter_items.append(i)
        
        if counter_items:
             kots.append({
                "counter": counter_name,
                "html": build_kot_html(counter_items, counter_name)
             })
             
    elif request.mode == "separate":
        counter_map = {}
        for i in order.items:
            if i.status.lower() != 'cancelled':
                mi_c_id = i.menu_item.kitchen_counter_id if i.menu_item else None
                if mi_c_id not in counter_map:
                    counter_map[mi_c_id] = []
                counter_map[mi_c_id].append(i)
                
        for cid, group_items in counter_map.items():
            if cid is None:
                c_name = "Main Kitchen"
            else:
                c_name = counters.get(cid, f"Counter #{cid}")
            kots.append({
                "counter": c_name,
                "html": build_kot_html(group_items, c_name)
            })

    # NEW: Also create PrinterJobs for downloaders
    for k in kots:
        job = PrinterJob(
            printer_name=k.get("counter", "Kitchen"),
            document_type="kitchen_ticket",
            reference_id=str(order.id),
            status="Pending"
        )
        db.add(job)
    db.commit()

    return {"kots": kots}


@router.post("/{order_id}/kot/version")
def create_kot_version(order_id: int, request: dict, db: Session = Depends(get_db)):
    """Create a new KOT version (incremental diff)."""
    order = order_service.get_order_by_id(db, order_id)
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
        
    last_version = db.query(func.max(KOTLog.version)).filter(KOTLog.order_id == order_id).scalar() or 0
    new_version = last_version + 1
    
    # Update order items kot_version
    for item in order.items:
        if item.status.lower() != 'cancelled':
             item.kot_version = new_version
             
    log = KOTLog(
        order_id=order_id,
        version=new_version,
        action="updated" if last_version > 0 else "created",
        added_items=request.get("added_items", []),
        removed_items=request.get("removed_items", []),
        modified_items=request.get("modified_items", []),
        captain_name=request.get("captain_name"),
        table_number=str(order.table_id) if order.table_id else None,
        room_number=order.room_number
    )
    db.add(log)
    db.commit()
    return {"status": "success", "version": new_version}


@router.get("/{order_id}/kot/history", response_model=List[KOTLogResponse])
def get_kot_history(order_id: int, db: Session = Depends(get_db)):
    return db.query(KOTLog).filter(KOTLog.order_id == order_id).order_by(KOTLog.version.desc()).all()

@router.post("/{order_id}/kot/cancel")
async def cancel_kot(order_id: int, request: CancelKOTRequest, db: Session = Depends(get_db)):
    try:
        order = order_service.get_order_by_id(db, order_id)
        if not order:
            raise HTTPException(status_code=404, detail="Order not found")
        admin_user = db.query(User).filter(User.pin == request.pin).first()
        if not admin_user:
             raise HTTPException(status_code=403, detail="Invalid PIN")
        if (admin_user.role or "").lower() not in ["admin", "manager", "owner"]:
             perms = admin_user.permissions or {}
             if not perms.get("can_cancel_kot", False):
                  raise HTTPException(status_code=403, detail="Insufficient permissions")
        last_version = db.query(func.max(KOTLog.version)).filter(KOTLog.order_id == order_id).scalar() or 0
        log = KOTLog(order_id=order_id, version=last_version + 1, action="cancelled", cancelled_by=admin_user.id, cancel_reason=request.reason, table_number=str(order.table_id) if order.table_id else None)
        db.add(log)
        for item in order.items:
            item.status = "Cancelled"
            item.kot_status = "cancelled"
        if order.table_id:
            table = db.query(Table).filter(Table.id == order.table_id).first()
            if table:
                 table.status = "Available"
                 try: await event_bus.publish(TableUpdatedEvent(table_id=table.id, status="Available"))
                 except: pass
        order.status = "Cancelled"
        db.commit()
        return {"message": "KOT cancelled successfully"}
    except HTTPException: raise
    except Exception as e:
        import traceback
        with open('error_log.txt', 'a') as ef:
            ef.write(f"\n[{datetime.now()}] ERROR in cancel_kot: {str(e)}\n")
            traceback.print_exc(file=ef)
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/{order_id}", response_model=OrderResponse)
def read_order(order_id: int, db: Session = Depends(get_db)):
    order = order_service.get_order_by_id(db, order_id)
    if not order: raise HTTPException(status_code=404, detail="Order not found")
    return order


class MergeRequest(BaseModel):
    source_order_id: int

@router.post("/{order_id}/merge")
async def merge_orders(order_id: int, request: MergeRequest, db: Session = Depends(get_db), current_user = Depends(get_current_user)):
    """Merge source order items into target order, then mark source as 'merged'"""
    target: OrderModel = db.query(OrderModel).filter(OrderModel.id == order_id).first()
    source: OrderModel = db.query(OrderModel).filter(OrderModel.id == request.source_order_id).first()

    if not target:
        raise HTTPException(status_code=404, detail="Target order not found")
    if not source:
        raise HTTPException(status_code=404, detail="Source order not found")

    # Move all items from source to target
    source_items = db.query(OrderItemModel).filter(OrderItemModel.order_id == source.id).all()
    for item in source_items:
        item.order_id = target.id

    # Update target total
    target.total_amount = sum(i.price * i.quantity for i in target.items) + sum(i.price * i.quantity for i in source_items)
    source.status = "merged"
    source.total_amount = 0.0

    # Release source table
    source_table = db.query(Table).filter(Table.id == source.table_id).first()
    if source_table:
        source_table.status = "Available"

    db.commit()
    db.refresh(target)
    
    if source_table:
        event = TableUpdatedEvent(
            table_id=source_table.id,
            status=source_table.status,
            is_reserved=source_table.is_reserved,
            reserved_for=source_table.reserved_for
        )
        await event_bus.publish(event)

    return {"message": f"Order #{source.id} merged into #{target.id}", "target_order_id": target.id}


class TransferRequest(BaseModel):
    new_table_id: int

@router.post("/{order_id}/transfer")
async def transfer_order(order_id: int, request: TransferRequest, db: Session = Depends(get_db), current_user = Depends(get_current_user)):
    """Transfer an order to a different table"""
    try:
        order = db.query(OrderModel).filter(OrderModel.id == order_id).first()
        if not order:
            raise HTTPException(status_code=404, detail="Order not found")

        old_table_id = order.table_id
        new_table_id = request.new_table_id

        if old_table_id == new_table_id:
             return {"message": "Order already at this table"}

        # 1. Validation: Is NEW table valid and available?
        new_table = db.query(Table).filter(Table.id == new_table_id).first()
        if not new_table:
            raise HTTPException(status_code=404, detail=f"Target table {new_table_id} not found")
        
        if new_table.status.lower() == "occupied" and new_table.id != old_table_id:
            # We don't block it completely as some POS allow multiple orders, 
            # but usually it's an error in standard restaurant flow.
            # For now, let's just log it or we could raise an error.
            print(f"Warning: Transferring to an OCCUPIED table {new_table_id}")

        # 2. Update Order
        order.table_id = new_table_id
        if order.order_type == "takeaway":
             order.order_type = "dine_in" # Auto-convert to dine-in if moved to a table

        # 3. Update Table Statuses
        old_table = None
        if old_table_id:
            old_table = db.query(Table).filter(Table.id == old_table_id).first()
            if old_table:
                # Check if there are other ACTIVE orders on the old table
                other_orders = db.query(OrderModel).filter(
                    OrderModel.table_id == old_table_id, 
                    OrderModel.id != order.id,
                    OrderModel.status.notin_(["Paid", "Cancelled", "merged"])
                ).first()
                if not other_orders:
                    old_table.status = "Available"
        
        new_table.status = "Occupied"
        
        db.commit()
        db.refresh(order)

        # 4. Notify POS via WebSockets
        for t in [old_table, new_table]:
            if t:
                event = TableUpdatedEvent(
                    table_id=t.id,
                    status=t.status,
                    is_reserved=t.is_reserved,
                    reserved_for=t.reserved_for
                )
                await event_bus.publish(event)

        log_audit(db, "TRANSFER", "order", order.id, f"Transferred from table {old_table_id} to {new_table_id}", user_id=current_user.id)

        return {"message": f"Order #{order.id} transferred from table {old_table_id} to table {new_table_id}"}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Transfer failed: {str(e)}")
