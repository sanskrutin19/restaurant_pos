from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime

class BillResponse(BaseModel):
    id: int
    order_id: int
    bill_number: Optional[str] = None
    subtotal: float = 0.0
    taxable_subtotal: float = 0.0
    non_taxable_subtotal: float = 0.0
    discountable_subtotal: float = 0.0
    non_discountable_subtotal: float = 0.0
    total_amount: float
    tax: float
    cgst: float = 0.0
    sgst: float = 0.0
    discount: float
    discount_type: str = "flat"
    discount_value: float = 0.0
    discount_note: Optional[str] = None
    round_off: float = 0.0
    is_reprint: int = 0
    created_at: datetime

    class Config:
        from_attributes = True

class PrintJobRequest(BaseModel):
    order_id: int
    printer_name: str
    document_type: str = "receipt"

class PrintJobResponse(BaseModel):
    id: int
    printer_name: str
    document_type: str
    status: str
    reference_id: Optional[str] = None
    created_at: datetime
    
    class Config:
        from_attributes = True
