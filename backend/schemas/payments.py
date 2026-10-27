from pydantic import BaseModel
from datetime import datetime

class PaymentRequest(BaseModel):
    order_id: int
    amount: float
    payment_method: str # cash, card, upi

class PaymentResponse(BaseModel):
    id: int
    order_id: int
    amount: float
    payment_method: str
    status: str
    created_at: datetime

    class Config:
        from_attributes = True
