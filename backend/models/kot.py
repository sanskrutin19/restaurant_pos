from sqlalchemy import Column, Integer, String, Float, ForeignKey, DateTime, JSON
from sqlalchemy.sql import func
from backend.database.core import Base


class KOTLog(Base):
    """Tracks KOT versions and cancellations for audit trail."""
    __tablename__ = "kot_logs"

    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("orders.id"), index=True, nullable=False)
    version = Column(Integer, nullable=False, default=1)
    action = Column(String, nullable=False, default="created")  # created, updated, cancelled
    items_snapshot = Column(JSON, nullable=True)   # Full items state at this version
    added_items = Column(JSON, nullable=True)      # Items added in this version
    removed_items = Column(JSON, nullable=True)    # Items removed in this version
    modified_items = Column(JSON, nullable=True)   # Qty/modifier changes
    cancelled_by = Column(Integer, ForeignKey("users.id"), nullable=True)
    cancel_reason = Column(String, nullable=True)
    captain_name = Column(String, nullable=True)
    table_number = Column(String, nullable=True)   # Snapshot of table/room at time of KOT
    room_number = Column(String, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class BillSequence(Base):
    """Tracks sequential bill numbering per date."""
    __tablename__ = "bill_sequences"

    id = Column(Integer, primary_key=True, index=True)
    prefix = Column(String, default="BILL")
    date = Column(String, nullable=False)  # e.g., '2026-04-06'
    last_number = Column(Integer, default=0)
