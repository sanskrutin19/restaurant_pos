from pydantic import BaseModel
from typing import Optional

class UserBase(BaseModel):
    username: str
    role: str
    hourly_rate: Optional[float] = 0.0

class UserCreate(UserBase):
    password: str

class UserUpdate(BaseModel):
    username: Optional[str] = None
    role: Optional[str] = None
    hourly_rate: Optional[float] = None
    password: Optional[str] = None

class UserResponse(UserBase):
    id: int

    class Config:
        from_attributes = True
