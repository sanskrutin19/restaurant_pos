from pydantic import BaseModel
from typing import Optional

class SystemSettingSchema(BaseModel):
    key: str
    value: str

    class Config:
        from_attributes = True

class TaxSettingsUpdate(BaseModel):
    tax_rate: float

class SystemSettingsUpdate(BaseModel):
    settings: dict # Key-Value pairs 
