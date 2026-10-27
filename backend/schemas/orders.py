from pydantic import BaseModel, field_validator
from typing import Optional, List, Dict, Any, Union
from datetime import datetime
from backend.schemas.customer import CustomerResponse
from backend.schemas.menu import MenuItemResponse

# --- Order Item Schemas ---
class OrderItemModifierResponse(BaseModel):
    id: int
    modifier_name: str
    price_delta: float

    class Config:
        from_attributes = True

class OrderItemResponse(BaseModel):
    id: int
    item_id: int
    name: Optional[str] = None
    quantity: int
    price: float = 0.0
    notes: Optional[str] = None
    status: str = "Pending"
    modifiers: List[OrderItemModifierResponse] = []
    menu_item: Optional[MenuItemResponse] = None
    allow_discount: bool = True
    tax_enabled: bool = True
    tax_percentage: float = 5.0
    kot_version: int = 1
    kot_status: str = "active"

    @field_validator('name', mode='before')
    @classmethod
    def get_item_name(cls, v, info):
        if v: return v
        # info.data for V2, values for V1-style or attribute access
        return "Unknown Item"

    class Config:
        from_attributes = True

# --- Order Schemas ---
class OrderResponse(BaseModel):
    id: int
    table_id: Optional[int] = None
    device_id: Optional[int] = None
    user_id: Optional[int] = None
    status: str = "Pending"
    total_amount: float = 0.0
    discount_amount: Optional[float] = 0.0
    tax_rate: Optional[float] = 5.0
    payment_method: Optional[str] = None
    order_type: str = "dine_in"
    customer_id: Optional[int] = None
    customer_name: Optional[str] = None
    customer_phone: Optional[str] = None
    counter_id: Optional[str] = None
    customer: Optional[CustomerResponse] = None
    room_number: Optional[str] = None
    guest_name: Optional[str] = None
    room_service_charge: float = 0.0
    pax_count: int = 1
    customer_mobile: Optional[str] = None
    bill_number: Optional[str] = None
    created_at: datetime
    items: List[OrderItemResponse] = []

    @field_validator('discount_amount', 'tax_rate', 'total_amount', mode='before')
    @classmethod
    def validate_nullable_fields(cls, v):
        if v is None:
            return 0.0
        return v

    @field_validator('payment_method', mode='before')
    @classmethod
    def validate_payment_method(cls, v):
        if isinstance(v, int):
            return {1: 'cash', 2: 'card', 3: 'upi'}.get(v, str(v))
        return v

    @field_validator('customer_name', mode='before')
    @classmethod
    def get_customer_name(cls, v, info):
        if v: return v
        # Fall back to Customer relationship
        try:
            customer = info.data.get('customer')
            if customer and hasattr(customer, 'name'):
                return customer.name
        except Exception:
            pass
        return None

    @field_validator('customer_phone', mode='before')
    @classmethod
    def get_customer_phone(cls, v, info):
        if v: return v
        # Fall back to customer_mobile on the order itself
        try:
            mobile = info.data.get('customer_mobile')
            if mobile: return mobile
        except Exception:
            pass
        # Fall back to Customer relationship
        try:
            customer = info.data.get('customer')
            if customer and hasattr(customer, 'phone'):
                return customer.phone
        except Exception:
            pass
        return None

    class Config:
        from_attributes = True


# --- API Request Schemas ---
class CreateOrderRequest(BaseModel):
    table_id: Optional[int] = None
    user_id: int
    device_id: int
    payment_method: Optional[int] = None
    order_type: str = "dine_in"
    customer_phone: Optional[str] = None
    customer_name: Optional[str] = None
    customer_mobile: Optional[str] = None
    discount_amount: float = 0.0
    tax_rate: float = 5.0
    counter_id: Optional[str] = None
    room_number: Optional[str] = None
    guest_name: Optional[str] = None
    room_service_charge: float = 0.0
    pax_count: int = 1
    items: Optional[List[Dict[str, Any]]] = None

class AddItemRequest(BaseModel):
    item_id: int
    quantity: int = 1
    notes: Optional[str] = None
    user_id: int # Who took the order