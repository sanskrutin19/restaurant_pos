from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
from backend.security.auth import get_current_user, get_current_user_optional
from pydantic import BaseModel

from backend.database.core import get_db
from backend.schemas.menu import (
    MenuCategoryCreate, MenuCategoryResponse, 
    MenuItemCreate, MenuItemUpdate, MenuItemResponse,
    MenuItemModifierCreate, MenuItemModifierResponse,
    ComboItemCreate, ComboItemResponse
)
from backend.services import menu as menu_service
from backend.models.catalog import MenuItemModifier, MenuItem as MenuItemModel, MenuCategory as MenuCategoryModel

router = APIRouter(prefix="/menu", tags=["Menu"])

@router.post("/categories", response_model=MenuCategoryResponse)
def create_category(category: MenuCategoryCreate, db: Session = Depends(get_db), current_user = Depends(get_current_user_optional)):
    return menu_service.create_category(db=db, category=category)

@router.get("/categories", response_model=List[MenuCategoryResponse])
def read_categories(skip: int = 0, limit: int = 1000, parent_id: Optional[int] = None, db: Session = Depends(get_db)):
    return menu_service.get_categories(db, skip=skip, limit=limit, parent_id=parent_id)

@router.put("/categories/{category_id}", response_model=MenuCategoryResponse)
def update_category(category_id: int, category: MenuCategoryCreate, db: Session = Depends(get_db), current_user = Depends(get_current_user_optional)):
    db_cat = menu_service.update_category(db, category_id, category)
    if not db_cat:
        raise HTTPException(status_code=404, detail="Category not found")
    return db_cat

@router.delete("/categories/{category_id}")
def delete_category(category_id: int, db: Session = Depends(get_db), current_user = Depends(get_current_user_optional)):
    db_cat = db.query(MenuCategoryModel).filter(MenuCategoryModel.id == category_id).first()
    if not db_cat:
        raise HTTPException(status_code=404, detail="Category not found")
    db.delete(db_cat)
    db.commit()
    return {"message": f"Category {category_id} deleted"}

@router.post("/items", response_model=MenuItemResponse)
def create_item(item: MenuItemCreate, db: Session = Depends(get_db), current_user = Depends(get_current_user_optional)):
    return menu_service.create_item(db=db, item=item)

@router.get("/items", response_model=List[MenuItemResponse])
def read_items(skip: int = 0, limit: int = 2000, category_id: int = None, db: Session = Depends(get_db)):
    return menu_service.get_items(db, skip=skip, limit=limit, category_id=category_id)

@router.put("/items/{item_id}", response_model=MenuItemResponse)
def update_item(item_id: int, item: MenuItemUpdate, db: Session = Depends(get_db), current_user = Depends(get_current_user_optional)):
    db_item = menu_service.update_item(db, item_id, item)
    if db_item is None:
        raise HTTPException(status_code=404, detail="Item not found")
    return db_item

@router.get("/items/{item_id}", response_model=MenuItemResponse)
def read_item(item_id: int, db: Session = Depends(get_db)):
    db_item = menu_service.get_item(db, item_id)
    if not db_item:
        raise HTTPException(status_code=404, detail="Item not found")
    return db_item

@router.delete("/items/{item_id}")
def delete_item(item_id: int, db: Session = Depends(get_db), current_user = Depends(get_current_user_optional)):
    db_item = db.query(MenuItemModel).filter(MenuItemModel.id == item_id).first()
    if not db_item:
        raise HTTPException(status_code=404, detail="Item not found")
    db.delete(db_item)
    db.commit()
    return {"message": f"Item {item_id} deleted"}

# ── Modifier CRUD ────────────────────────────────────────────────────────

@router.get("/items/{item_id}/modifiers", response_model=List[MenuItemModifierResponse])
def get_item_modifiers(item_id: int, db: Session = Depends(get_db)):
    """Get all modifiers for a menu item."""
    return db.query(MenuItemModifier).filter(MenuItemModifier.menu_item_id == item_id).all()

@router.post("/items/{item_id}/modifiers", response_model=MenuItemModifierResponse)
def create_modifier(item_id: int, mod: MenuItemModifierCreate, db: Session = Depends(get_db), current_user = Depends(get_current_user)):
    """Add a modifier (size/addon) to a menu item."""
    # Ensure item exists
    db_item = db.query(MenuItemModel).filter(MenuItemModel.id == item_id).first()
    if not db_item:
        raise HTTPException(status_code=404, detail="Menu item not found")
    
    # We ignore mod.menu_item_id if provided and use path parameter
    return menu_service.add_modifier(db, mod)

@router.delete("/modifiers/{modifier_id}")
def delete_modifier(modifier_id: int, db: Session = Depends(get_db), current_user = Depends(get_current_user)):
    """Delete a modifier."""
    if not menu_service.delete_modifier(db, modifier_id):
        raise HTTPException(status_code=404, detail="Modifier not found")
    return {"message": f"Modifier {modifier_id} deleted"}

# ── Combo CRUD ───────────────────────────────────────────────────────────

@router.post("/items/{item_id}/combo", response_model=ComboItemResponse)
def add_combo_component(item_id: int, component_id: int, quantity: int = 1, db: Session = Depends(get_db), current_user = Depends(get_current_user)):
    """Add a component item to a combo meal."""
    # item_id is the combo, component_id is the item in the combo
    return menu_service.add_combo_item(db, item_id, component_id, quantity)

@router.delete("/items/{item_id}/combo/{component_id}")
def remove_combo_component(item_id: int, component_id: int, db: Session = Depends(get_db), current_user = Depends(get_current_user)):
    """Remove a component from a combo meal."""
    if not menu_service.delete_combo_item(db, item_id, component_id):
        raise HTTPException(status_code=404, detail="Combo component not found")
    return {"status": "success"}


class TableResponse(BaseModel):
    id: int
    name: str = ""
    status: str = "Available"
    capacity: int = 4
    section: str = "Main"
    is_reserved: bool = False
    reserved_for: Optional[str] = None
    class Config:
        from_attributes = True

@router.get("/tables", response_model=List[TableResponse])
def get_tables(db: Session = Depends(get_db)):
    """List all tables for the POS grid."""
    from backend.models.system import Table
    return db.query(Table).all()

class ReserveTableRequest(BaseModel):
    is_reserved: bool
    reserved_for: Optional[str] = None

@router.post("/tables/{table_id}/reserve")
def reserve_table(table_id: int, request: ReserveTableRequest, db: Session = Depends(get_db)):
    """Reserve or unreserve a table."""
    from backend.models.system import Table
    from backend.events.core import event_bus
    from backend.schemas.events import TableUpdatedEvent

    table = db.query(Table).filter(Table.id == table_id).first()
    if not table:
        raise HTTPException(status_code=404, detail="Table not found")
    
    table.is_reserved = request.is_reserved
    table.reserved_for = request.reserved_for if request.is_reserved else None
    
    # Only change status if it's currently Available or Reserved
    if table.status in ("Available", "Reserved"):
        table.status = "Reserved" if request.is_reserved else "Available"
    
    db.commit()
    db.refresh(table)
    
    # Fire WebSocket event
    event = TableUpdatedEvent(
        table_id=table.id,
        status=table.status,
        is_reserved=table.is_reserved,
        reserved_for=table.reserved_for
    )
    import asyncio
    try:
        loop = asyncio.get_event_loop()
        if loop.is_running():
            loop.create_task(event_bus.publish(event))
        else:
            loop.run_until_complete(event_bus.publish(event))
    except RuntimeError:
        asyncio.run(event_bus.publish(event))
    
    return table

@router.get("/settings")
def get_public_settings(db: Session = Depends(get_db)):
    """Get public restaurant info for Guest Menu."""
    from backend.models.system import SystemSettings
    settings = db.query(SystemSettings).all()
    return {s.key: s.value for s in settings}
