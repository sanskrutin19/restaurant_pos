from sqlalchemy.orm import Session
from backend.models.catalog import MenuCategory, MenuItem, MenuItemModifier, ComboItem
from backend.schemas.menu import MenuCategoryCreate, MenuItemCreate, MenuItemUpdate, MenuItemModifierCreate, ComboItemCreate

def create_category(db: Session, category: MenuCategoryCreate) -> MenuCategory:
    db_category = MenuCategory(**category.model_dump())
    db.add(db_category)
    db.commit()
    db.refresh(db_category)
    return db_category

def get_categories(db: Session, skip: int = 0, limit: int = 100, parent_id: int = None):
    query = db.query(MenuCategory)
    if parent_id is not None:
        query = query.filter(MenuCategory.parent_id == parent_id)
    else:
        # Default to root categories if no parent_id specified? 
        # Actually, standard POS often shows all or just roots.
        # Let's keep it flexible.
        pass
    return query.offset(skip).limit(limit).all()

def create_item(db: Session, item: MenuItemCreate) -> MenuItem:

    db_item = MenuItem(**item.model_dump())
    db.add(db_item)
    db.commit()
    db.refresh(db_item)
    

        
    return db_item

def get_items(db: Session, skip: int = 0, limit: int = 100, category_id: int = None):
    query = db.query(MenuItem)
    if category_id:
        query = query.filter(MenuItem.category_id == category_id)
    return query.offset(skip).limit(limit).all()

def update_item(db: Session, item_id: int, item: MenuItemUpdate):
    db_item = db.query(MenuItem).filter(MenuItem.id == item_id).first()
    if not db_item:
        return None
    
    update_data = item.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(db_item, key, value)
        
    db.commit()
    db.refresh(db_item)
    return db_item
def get_item(db: Session, item_id: int):
    return db.query(MenuItem).filter(MenuItem.id == item_id).first()

def update_category(db: Session, category_id: int, category: MenuCategoryCreate):
    db_cat = db.query(MenuCategory).filter(MenuCategory.id == category_id).first()
    if not db_cat:
        return None
    
    update_data = category.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(db_cat, key, value)
        
    db.commit()
    db.refresh(db_cat)
    return db_cat

def add_modifier(db: Session, modifier: MenuItemModifierCreate):
    db_mod = MenuItemModifier(**modifier.model_dump())
    db.add(db_mod)
    db.commit()
    db.refresh(db_mod)
    return db_mod

def delete_modifier(db: Session, modifier_id: int):
    db_mod = db.query(MenuItemModifier).filter(MenuItemModifier.id == modifier_id).first()
    if db_mod:
        db.delete(db_mod)
        db.commit()
        return True
    return False

def add_combo_item(db: Session, combo_id: int, component_id: int, quantity: int = 1):
    db_combo = ComboItem(combo_menu_item_id=combo_id, component_item_id=component_id, quantity=quantity)
    db.add(db_combo)
    db.commit()
    db.refresh(db_combo)
    return db_combo

def delete_combo_item(db: Session, combo_id: int, component_id: int):
    db_combo = db.query(ComboItem).filter(
        ComboItem.combo_menu_item_id == combo_id, 
        ComboItem.component_item_id == component_id
    ).first()
    if db_combo:
        db.delete(db_combo)
        db.commit()
        return True
    return False
