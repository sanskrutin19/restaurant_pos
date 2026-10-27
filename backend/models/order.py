from sqlalchemy import Column, Integer, String, Float, ForeignKey, DateTime, JSON, Boolean
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from backend.database.core import Base

class Order(Base):
    __tablename__ = "orders"

    id = Column(Integer, primary_key=True, index=True)
    table_id = Column(Integer, ForeignKey("tables.id"))
    customer_id = Column(Integer, ForeignKey("customers.id"), nullable=True)
    device_id = Column(Integer, ForeignKey("devices.id"))
    user_id = Column(Integer, ForeignKey("users.id"))
    status = Column(String, default="Pending")  # Pending, Held, Preparing, Ready, Served, Paid, Cancelled
    total_amount = Column(Float, default=0.0)
    discount_amount = Column(Float, default=0.0)
    tax_rate = Column(Float, default=5.0)  # Store the rate used for this order
    payment_method = Column(String(20), nullable=True, default=None)
    order_type = Column(String, default="dine_in")  # dine_in, takeaway, delivery, room_service
    counter_id = Column(String, nullable=True) # ID of the POS counter/terminal
    shift_id = Column(Integer, ForeignKey("shifts.id"), nullable=True)
    held_at = Column(DateTime(timezone=True), nullable=True)  # When order was put on hold
    room_number = Column(String, nullable=True)  # Room order support
    guest_name = Column(String, nullable=True)
    room_service_charge = Column(Float, default=0.0)
    pax_count = Column(Integer, default=1)
    customer_mobile = Column(String, nullable=True)
    bill_number = Column(String, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    items = relationship("OrderItem", back_populates="order")
    events = relationship("OrderEvent", back_populates="order", order_by="OrderEvent.id")
    customer = relationship("Customer")

class OrderItem(Base):
    __tablename__ = "order_items"

    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("orders.id"))
    item_id = Column(Integer, ForeignKey("menu_items.id"))
    quantity = Column(Integer, nullable=False, default=1)
    price = Column(Float, nullable=False)
    name = Column(String, nullable=True)  # Store item name for historical accuracy
    notes = Column(String)
    status = Column(String, default="Pending")
    is_sent_to_kitchen = Column(Boolean, default=False)
    allow_discount = Column(Boolean, default=True)
    tax_enabled = Column(Boolean, default=True)
    tax_percentage = Column(Float, default=5.0)
    kot_version = Column(Integer, default=1)
    kot_status = Column(String, default="active")  # active, cancelled
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    order = relationship("Order", back_populates="items")
    menu_item = relationship("MenuItem")
    modifiers = relationship("OrderItemModifier", cascade="all, delete-orphan")


class OrderItemModifier(Base):
    """Tracks selected modifiers for each order item."""
    __tablename__ = "order_item_modifiers"

    id = Column(Integer, primary_key=True, index=True)
    order_item_id = Column(Integer, ForeignKey("order_items.id"), nullable=False)
    modifier_name = Column(String, nullable=False)
    price_delta = Column(Float, default=0.0)


class OrderEvent(Base):
    __tablename__ = "order_events"

    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("orders.id"), index=True, nullable=True)
    event_type = Column(String, nullable=False)
    event_data = Column(JSON, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    order = relationship("Order", back_populates="events")

class KitchenTicket(Base):
    __tablename__ = "kitchen_tickets"

    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("orders.id"), unique=True)
    status = Column(String, default="Received")
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())