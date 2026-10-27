from pydantic import BaseModel
from typing import Optional, Dict, Any
from datetime import datetime

class RoleBase(BaseModel):
    name: str
    permissions: Optional[Dict[str, Any]] = None

class RoleCreate(RoleBase):
    pass

class RoleUpdate(RoleBase):
    name: Optional[str] = None

class RoleResponse(RoleBase):
    id: int
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True

class VerifyPinRequest(BaseModel):
    pin: str
