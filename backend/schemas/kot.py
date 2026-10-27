from pydantic import BaseModel
from typing import Optional, List, Dict, Any
from datetime import datetime

class KOTLogBase(BaseModel):
    order_id: int
    version: int
    action: str = "created"
    items_snapshot: Optional[List[Dict[str, Any]]] = None
    added_items: Optional[List[Dict[str, Any]]] = None
    removed_items: Optional[List[Dict[str, Any]]] = None
    modified_items: Optional[List[Dict[str, Any]]] = None
    cancelled_by: Optional[int] = None
    cancel_reason: Optional[str] = None
    captain_name: Optional[str] = None
    table_number: Optional[str] = None
    room_number: Optional[str] = None

class KOTLogCreate(KOTLogBase):
    pass

class KOTLogResponse(KOTLogBase):
    id: int
    created_at: datetime

    class Config:
        from_attributes = True

class CancelKOTRequest(BaseModel):
    pin: str
    reason: str
