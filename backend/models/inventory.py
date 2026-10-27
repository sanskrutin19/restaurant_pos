from sqlalchemy import Column, Integer, String, Float, ForeignKey, DateTime, Boolean
from sqlalchemy.sql import func
from backend.database.core import Base


class Ingredient(Base):
    __tablename__ = "ingredients"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, nullable=False)
    unit = Column(String, nullable=False, default="kg")  # kg, g, l, ml, pcs
    current_stock = Column(Float, default=0.0)
    min_stock = Column(Float, default=5.0)
    cost_per_unit = Column(Float, default=0.0)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())


class Recipe(Base):
    """Container for a Menu Item's recipe composed of ingredients and sub-recipes."""
    __tablename__ = "recipes"

    id = Column(Integer, primary_key=True, index=True)
    menu_item_id = Column(Integer, ForeignKey("menu_items.id"), nullable=False)
    name = Column(String, nullable=False)
    yield_qty = Column(Float, default=1.0)
    yield_unit = Column(String, default="serving")
    recipe_type = Column(String, default="main")  # "main", "sub_recipe"


class RecipeIngredient(Base):
    """Maps ingredients and sub-recipes to a Recipe."""
    __tablename__ = "recipe_ingredients"

    id = Column(Integer, primary_key=True, index=True)
    recipe_id = Column(Integer, ForeignKey("recipes.id"), nullable=False)
    ingredient_id = Column(Integer, ForeignKey("ingredients.id"), nullable=True)  # Null if it's a sub-recipe
    sub_recipe_id = Column(Integer, ForeignKey("recipes.id"), nullable=True)     # Null if it's a raw material
    quantity = Column(Float, nullable=False)
    unit = Column(String, nullable=False)
    stage = Column(String, default="cook")  # "prep", "cook", "garnish"
    yield_factor = Column(Float, default=1.0) # For items like chicken (raw to cooked)


class MenuItemAvailability(Base):
    """Tracks automated menu disabling reasons based on stock."""
    __tablename__ = "menu_item_availability"

    id = Column(Integer, primary_key=True, index=True)
    menu_item_id = Column(Integer, ForeignKey("menu_items.id"), nullable=False, unique=True)
    is_available = Column(Boolean, default=True)
    disabled_reason = Column(String)  # "Low Stock: Cheese", "Out of Stock: Bun"
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())


class StockTransaction(Base):
    """Tracks stock movements with historical state."""
    __tablename__ = "stock_transactions"

    id = Column(Integer, primary_key=True, index=True)
    ingredient_id = Column(Integer, ForeignKey("ingredients.id"), nullable=False)
    quantity = Column(Float, nullable=False)  # Change (+/-)
    previous_stock = Column(Float, default=0.0)
    new_stock = Column(Float, default=0.0)
    reference_type = Column(String)  # "order", "purchase", "wastage", "adjustment"
    reference_id = Column(String)    # order_id or purchase_id
    reason = Column(String, nullable=True) # Added to fix IntegrityError
    notes = Column(String)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
