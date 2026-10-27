from sqlalchemy import Column, Integer, String, Float, Boolean, ForeignKey, DateTime
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from backend.database.core import Base

class MenuCategory(Base):
    __tablename__ = "menu_categories"

    id = Column(Integer, primary_key=True, index=True)
    parent_id = Column(Integer, ForeignKey("menu_categories.id"), nullable=True)
    name = Column(String, unique=True, nullable=False)
    description = Column(String)
    kitchen_counter_id = Column(Integer, ForeignKey("kitchen_counters.id"), nullable=True)
    allow_discount = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    items = relationship("MenuItem", back_populates="category")
    subcategories = relationship("MenuCategory", back_populates="parent", foreign_keys="[MenuCategory.parent_id]")
    parent = relationship("MenuCategory", back_populates="subcategories", remote_side="MenuCategory.id", foreign_keys="[MenuCategory.parent_id]")

class MenuItem(Base):
    __tablename__ = "menu_items"

    id = Column(Integer, primary_key=True, index=True)
    category_id = Column(Integer, ForeignKey("menu_categories.id"))
    kitchen_counter_id = Column(Integer, ForeignKey("kitchen_counters.id"), nullable=True)
    name = Column(String, nullable=False)
    description = Column(String)
    price = Column(Float, nullable=False)
    is_available = Column(Boolean, default=True)
    stock_level = Column(Integer, default=100)
    low_stock_threshold = Column(Integer, default=5)
    allow_discount = Column(Boolean, default=True)
    tax_enabled = Column(Boolean, default=True)
    tax_percentage = Column(Float, default=5.0)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    category = relationship("MenuCategory", back_populates="items")
    kitchen_counter = relationship("KitchenCounter")
    modifiers = relationship("MenuItemModifier", back_populates="menu_item")
    
    # Relationships for combos
    # As a combo parent:
    combo_items = relationship("ComboItem", foreign_keys="[ComboItem.combo_menu_item_id]", backref="combo_parent")
    # As a component in other combos:
    used_in_combos = relationship("ComboItem", foreign_keys="[ComboItem.component_item_id]", backref="component_item")


class MenuItemModifier(Base):
    """Modifiers for menu items (e.g., size variants, add-ons like extra cheese)."""
    __tablename__ = "menu_item_modifiers"

    id = Column(Integer, primary_key=True, index=True)
    menu_item_id = Column(Integer, ForeignKey("menu_items.id"), nullable=False)
    name = Column(String, nullable=False)           # e.g., "Large", "Extra Cheese"
    price_delta = Column(Float, default=0.0)         # Price adjustment (+/-)
    modifier_group = Column(String, default="default")  # Group: "size", "addon", "spice"
    is_default = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    menu_item = relationship("MenuItem", back_populates="modifiers")


class ComboItem(Base):
    """Defines combo meal compositions."""
    __tablename__ = "combo_items"

    id = Column(Integer, primary_key=True, index=True)
    combo_menu_item_id = Column(Integer, ForeignKey("menu_items.id"), nullable=False)  # The combo itself
    component_item_id = Column(Integer, ForeignKey("menu_items.id"), nullable=False)   # Items in the combo
    quantity = Column(Integer, default=1)
