from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import HTMLResponse
from backend.security.auth import get_current_user
from sqlalchemy.orm import Session, joinedload
from backend.database.core import get_db
from pydantic import BaseModel
from typing import List
from datetime import datetime

from backend.commands.core import command_bus
from backend.schemas.commands import SendOrderToKitchenCommand, MarkOrderReadyCommand
from backend.models.order import Order, OrderItem
from backend.models.catalog import MenuItem as MenuItemModel

router = APIRouter(prefix="/kitchen", tags=["Kitchen Display System"])

class KitchenTicketResponse(BaseModel):
    order_id: int
    table_id: int
    status: str
    order_type: str = "dine_in"
    items: List[dict]
    created_at: datetime
    
    class Config:
        from_attributes = True

@router.get("/tickets/active", response_model=List[KitchenTicketResponse])
def get_active_tickets(db: Session = Depends(get_db)):
    """Fetch all orders currently in Created or Preparing state."""
    orders = db.query(Order).options(
        joinedload(Order.items).joinedload(OrderItem.menu_item),
        joinedload(Order.items).joinedload(OrderItem.modifiers)
    ).filter(Order.status.in_(["Pending", "Preparing"])).all()
    
    results = []
    for order in orders:
        items = []
        for i in order.items:
            items.append({
                "item_id": i.item_id,
                "name": i.menu_item.name if i.menu_item else f"Item #{i.item_id}",
                "quantity": i.quantity,
                "notes": i.notes,
                "status": i.status,
            })
        results.append({
            "order_id": order.id,
            "table_id": order.table_id,
            "status": order.status,
            "order_type": order.order_type or "dine_in",
            "items": items,
            "created_at": order.created_at
        })
    return results

@router.post("/tickets/{order_id}/start")
async def start_preparing_ticket(order_id: int, db: Session = Depends(get_db), current_user = Depends(get_current_user)):
    """Cashier or Kitchen marks ticket as 'Preparing'."""
    cmd = SendOrderToKitchenCommand(order_id=order_id)
    try:
        await command_bus.dispatch(cmd, db)
        return {"message": "Order is now preparing"}
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/{order_id}/items/{item_index}/ready")
async def mark_item_ready(order_id: int, item_index: int, db: Session = Depends(get_db)):
    """Mark a specific item in an order as ready."""
    try:
        cmd = MarkOrderReadyCommand(order_id=order_id) # Using MarkOrderReady for simplicity or we could have a specific item command
        await command_bus.dispatch(cmd, db)
        return {"status": "success", "message": f"Item {item_index} in Order #{order_id} marked as ready"}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/{order_id}/ready")
async def mark_order_ready(order_id: int, db: Session = Depends(get_db)):
    """Mark the entire order as ready."""
    try:
        cmd = MarkOrderReadyCommand(order_id=order_id)
        await command_bus.dispatch(cmd, db)
        return {"status": "success", "message": f"Order #{order_id} marked as ready"}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/tickets/{order_id}/kot", response_class=HTMLResponse)
def print_kot(order_id: int, db: Session = Depends(get_db)):
    """Generate a printable HTML KOT (Kitchen Order Ticket)."""
    order = db.query(Order).options(
        joinedload(Order.items).joinedload(OrderItem.menu_item)
    ).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    order_type_label = {"dine_in": "DINE-IN", "takeaway": "TAKEAWAY", "delivery": "DELIVERY"}.get(
        order.order_type or "dine_in", "DINE-IN"
    )

    items_html = ""
    for item in order.items:
        name = item.menu_item.name if item.menu_item else f"Item #{item.item_id}"
        notes_line = f'<div style="font-size:11px;color:#666;padding-left:12px;">→ {item.notes}</div>' if item.notes else ""
        items_html += f'<div style="display:flex;justify-content:space-between;margin:4px 0;font-size:14px;"><span>{item.quantity}× {name}</span></div>{notes_line}'

    html = f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>KOT #{order.id}</title>
    <style>
        body {{ font-family: 'Courier New', monospace; max-width: 80mm; margin: 0 auto; padding: 8px; }}
        .header {{ text-align: center; border-bottom: 2px dashed #000; padding-bottom: 8px; margin-bottom: 8px; }}
        .header h2 {{ margin: 0; font-size: 18px; }}
        .info {{ font-size: 12px; margin: 6px 0; }}
        .items {{ border-top: 1px dashed #000; border-bottom: 1px dashed #000; padding: 8px 0; margin: 8px 0; }}
        .footer {{ text-align: center; font-size: 10px; margin-top: 8px; }}
        @media print {{ .no-print {{ display: none; }} }}
    </style>
</head>
<body>
    <div class="header">
        <h2>🍳 KOT</h2>
        <div style="font-weight:bold;font-size:14px;">{order_type_label}</div>
    </div>
    <div class="info">
        <div><strong>Order #:</strong> {order.id}</div>
        <div><strong>Table:</strong> {order.table_id}</div>
        {f'<div><strong>Counter:</strong> {order.counter_id}</div>' if getattr(order, 'counter_id', None) else ''}
        <div><strong>Time:</strong> {order.created_at.strftime('%I:%M %p')}</div>
    </div>
    <div class="items">{items_html}</div>
    <div class="footer">--- KOT END ---</div>
    <div class="no-print" style="text-align:center;margin-top:16px;">
        <button onclick="window.print()" style="padding:8px 16px;font-size:14px;cursor:pointer;background:#ff6b35;color:white;border:none;border-radius:4px;">🖨️ Print KOT</button>
    </div>
</body>
</html>"""
    return HTMLResponse(content=html)




