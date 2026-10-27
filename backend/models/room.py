from sqlalchemy import Column, Integer, String, Float, DateTime, Boolean
from sqlalchemy.sql import func
from backend.database.core import Base


class Room(Base):
    """Hotel/restaurant room for room service orders."""
    __tablename__ = "rooms"

    id = Column(Integer, primary_key=True, index=True)
    room_number = Column(String, unique=True, nullable=False)
    floor = Column(String, nullable=True)
    guest_name = Column(String, nullable=True)
    status = Column(String, default="available")  # available, occupied, checkout, maintenance
    service_charge = Column(Float, default=0.0)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
