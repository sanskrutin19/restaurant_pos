from pydantic import BaseModel
from typing import Any, Dict, Optional
from datetime import datetime

class Event(BaseModel):
    """Base Event class"""
    event_type: str
    timestamp: datetime = datetime.now()

class OrderCreatedEvent(Event):
    event_type: str = "order_created"
    order_id: int
    table_id: Optional[int] = None
    device_id: int
    data: Optional[Dict[str, Any]] = None # Full OrderResponse

class OrderStatusUpdatedEvent(Event):
    event_type: str = "order_status_updated"
    order_id: int
    status: str
    data: Optional[Dict[str, Any]] = None # {'order_id': int, 'status': str}

class ItemAddedEvent(Event):
    event_type: str = "ItemAdded"
    order_id: int
    order_item_id: int
    item_id: int
    quantity: int

class OrderSentToKitchenEvent(Event):
    event_type: str = "OrderSentToKitchen"
    order_id: int

class OrderReadyEvent(Event):
    event_type: str = "OrderReady"
    order_id: int

class BillPrintedEvent(Event):
    event_type: str = "BillPrinted"
    order_id: int
    bill_id: int

class PaymentCompletedEvent(Event):
    event_type: str = "PaymentCompleted"
    order_id: int
    amount: float
    payment_method: str

class TableUpdatedEvent(Event):
    event_type: str = "TableUpdated"
    table_id: int
    status: str
    is_reserved: bool = False
    reserved_for: Optional[str] = None

class LowStockEvent(Event):
    event_type: str = "LowStock"
    item_id: int
    item_name: str
    current_stock: int
    threshold: int
