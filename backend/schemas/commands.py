from pydantic import BaseModel
from typing import Optional

class Command(BaseModel):
    """Base Command class"""
    pass

class CreateOrderCommand(Command):
    table_id: Optional[int] = None
    user_id: int
    device_id: int
    payment_method: Optional[str] = None
    order_type: str = "dine_in"
    customer_name: Optional[str] = None
    customer_phone: Optional[str] = None
    customer_mobile: Optional[str] = None
    room_number: Optional[str] = None
    discount_amount: float = 0.0
    tax_rate: float = 5.0
    counter_id: Optional[str] = None
    items: Optional[list] = None

class AddItemToOrderCommand(Command):
    order_id: int
    item_id: int
    quantity: int = 1
    notes: Optional[str] = None

class RemoveItemFromOrderCommand(Command):
    order_id: int
    order_item_id: int

class SendOrderToKitchenCommand(Command):
    order_id: int

class MarkOrderReadyCommand(Command):
    order_id: int

class RecordPaymentCommand(Command):
    order_id: int
    amount: float
    payment_method: str
    counter_id: Optional[str] = None

class PrintBillCommand(Command):
    order_id: int
    printer_name: str

class PrintKOTCommand(Command):
    order_id: int
    mode: str = "all" # all, separate, specific
    counter_id: Optional[int] = None

# --- Loyalty Commands ---
class CreateCustomerCommand(Command):
    name: Optional[str] = None
    phone: str
    email: Optional[str] = None

class RedeemPointsCommand(Command):
    phone: str
    points: int

# --- Staff Commands ---
class ClockInCommand(Command):
    user_id: int

class ClockOutCommand(Command):
    user_id: int