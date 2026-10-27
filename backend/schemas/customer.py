from datetime import datetime
from pydantic import BaseModel
from typing import Optional, List

class CustomerBase(BaseModel):
    name: Optional[str] = None
    phone: str
    email: Optional[str] = None

class CustomerCreate(CustomerBase):
    pass

class CustomerResponse(CustomerBase):
    id: int
    points: int
    visits_count: int
    total_spend: float = 0.0
    last_visit: Optional[datetime] = None
    created_at: datetime

    class Config:
        from_attributes = True

class CustomerUpdate(BaseModel):
    name: Optional[str] = None
    email: Optional[str] = None
    points: Optional[int] = None
