from pydantic import BaseModel
from typing import Optional, List, Any
from datetime import datetime

# --- Menu Category Schemas ---
class MenuCategoryBase(BaseModel):
    name: str
    description: Optional[str] = None
    parent_id: Optional[int] = None
    kitchen_counter_id: Optional[int] = None
    allow_discount: bool = True

class MenuCategoryCreate(MenuCategoryBase):
    pass

class MenuCategoryResponse(MenuCategoryBase):
    id: int
    created_at: datetime
    
    class Config:
        from_attributes = True

# --- Menu Item Schemas ---
class MenuItemBase(BaseModel):
    name: str
    description: Optional[str] = None
    price: float
    is_available: bool = True
    kitchen_counter_id: Optional[int] = None
    category_id: int
    allow_discount: bool = True
    tax_enabled: bool = True
    tax_percentage: float = 5.0

class MenuItemCreate(MenuItemBase):
    pass

class MenuItemUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    price: Optional[float] = None
    is_available: Optional[bool] = None
    kitchen_counter_id: Optional[int] = None
    category_id: Optional[int] = None
    allow_discount: Optional[bool] = None
    tax_enabled: Optional[bool] = None
    tax_percentage: Optional[float] = None

# --- Modifier Schemas ---
class MenuItemModifierBase(BaseModel):
    name: str
    price_delta: float
    modifier_group: str = "default"
    is_default: bool = False

class MenuItemModifierCreate(MenuItemModifierBase):
    pass

class MenuItemModifierResponse(MenuItemModifierBase):
    id: int
    class Config:
        from_attributes = True

# --- Combo Schemas ---
class ComboItemBase(BaseModel):
    component_item_id: int
    quantity: int = 1

class ComboItemCreate(ComboItemBase):
    pass

class ComboItemResponse(ComboItemBase):
    id: int
    name: Optional[str] = None
    price: Optional[float] = None
    class Config:
        from_attributes = True

class MenuItemResponse(MenuItemBase):
    id: int
    created_at: datetime
    modifiers: List[MenuItemModifierResponse] = []
    combo_items: List[ComboItemResponse] = []

    class Config:
        from_attributes = True
