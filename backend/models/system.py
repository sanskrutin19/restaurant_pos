from sqlalchemy import Column, Integer, String, ForeignKey, DateTime, JSON, Boolean, Float
from sqlalchemy.sql import func
from backend.database.core import Base

class Table(Base):
    __tablename__ = "tables"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, nullable=False)
    status = Column(String, default="Available") # Available, Occupied, Billing, Reserved
    capacity = Column(Integer, default=4)
    section = Column(String, default="Main")
    is_reserved = Column(Boolean, default=False)
    reserved_for = Column(String, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class PrinterJob(Base):
    __tablename__ = "printer_jobs"

    id = Column(Integer, primary_key=True, index=True)
    printer_name = Column(String, nullable=False)
    document_type = Column(String, nullable=False) # e.g. receipt, kitchen_ticket
    reference_id = Column(String) # e.g. order_id string
    status = Column(String, default="Pending")
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

class AuditLog(Base):
    __tablename__ = "audit_logs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    action = Column(String, nullable=False)
    entity = Column(String, nullable=False)
    entity_id = Column(Integer)
    description = Column(String)
    details = Column(JSON)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class KitchenCounter(Base):
    __tablename__ = "kitchen_counters"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, nullable=False) # e.g. "Grill", "Tandoor", "Bar"
    is_active = Column(Boolean, default=True)
    icon = Column(String, default="store")
    color = Column(String, default="#000000")
    printer_type = Column(String, default="network") # network, usb, bluetooth
    printer_address = Column(String, nullable=True) # IP address, or device name
    printer_port = Column(Integer, default=9100)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class SystemSettings(Base):
    __tablename__ = "system_settings"

    id = Column(Integer, primary_key=True, index=True)
    key = Column(String, unique=True, nullable=False)
    value = Column(String, nullable=False) # e.g. "tax_rate", "5.0"
    updated_at = Column(DateTime(timezone=True), onupdate=func.now(), server_default=func.now())

class Shift(Base):
    __tablename__ = "shifts"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    start_time = Column(DateTime(timezone=True), server_default=func.now())
    end_time = Column(DateTime(timezone=True), nullable=True)
    initial_cash = Column(Float, default=0.0)
    closed_cash = Column(Float, nullable=True)
    actual_cash = Column(Float, nullable=True)
    status = Column(String, default="Open") # Open, Closed, Reconciled
    cash_payments = Column(Float, default=0.0)
    card_payments = Column(Float, default=0.0)
    upi_payments = Column(Float, default=0.0)
    total_sales = Column(Float, default=0.0)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class ShiftAudit(Base):
    """Logs cash in/out events within a shift (e.g. payout to vendor)."""
    __tablename__ = "shift_audits"

    id = Column(Integer, primary_key=True, index=True)
    shift_id = Column(Integer, ForeignKey("shifts.id"))
    user_id = Column(Integer, ForeignKey("users.id"))
    amount = Column(Float, nullable=False)
    action = Column(String, nullable=False) # Cash-In, Cash-Out
    reason = Column(String)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
