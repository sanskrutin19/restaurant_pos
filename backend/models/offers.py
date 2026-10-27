from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime
from sqlalchemy.sql import func
from backend.database.core import Base


class Offer(Base):
    __tablename__ = "offers"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    code = Column(String, unique=True, index=True, nullable=True)  # Coupon code
    offer_type = Column(String, nullable=False)  # percentage, flat, bogo, combo
    value = Column(Float, default=0.0)  # 10 for 10% or ₹10
    min_order_amount = Column(Float, default=0.0)
    max_discount = Column(Float, default=0.0)  # Cap for percentage discounts
    is_active = Column(Boolean, default=True)
    start_time = Column(String, nullable=True)  # HH:MM for happy hours
    end_time = Column(String, nullable=True)    # HH:MM for happy hours
    days_active = Column(String, default="0,1,2,3,4,5,6")  # Comma-separated weekday indices
    usage_limit = Column(Integer, default=0)  # 0 = unlimited
    used_count = Column(Integer, default=0)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
