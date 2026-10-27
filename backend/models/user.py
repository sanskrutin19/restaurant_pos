from sqlalchemy import Column, Integer, String, Boolean, DateTime, Float, JSON
from sqlalchemy.sql import func
from backend.database.core import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True, nullable=False)
    full_name = Column(String, nullable=True) # Added
    password_hash = Column(String, nullable=False)
    role = Column(String, nullable=False) # 'admin', 'manager', 'waiter', etc.
    hourly_rate = Column(Float, default=100.0)
    tips_earned = Column(Float, default=0.0)
    reset_code = Column(String, nullable=True)
    pin = Column(String(4), nullable=True)
    is_active = Column(Boolean, default=True) # Added
    permissions = Column(JSON, nullable=True)  # Per-user permission overrides
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

class Role(Base):
    """Role templates with permission matrices."""
    __tablename__ = "roles"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, nullable=False)  # admin, manager, cashier, captain, kitchen
    permissions = Column(JSON, nullable=True)  # {"can_create_order": true, ...}
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

class Device(Base):
    __tablename__ = "devices"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    device_type = Column(String, nullable=False)
    mac_address = Column(String, unique=True, index=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
