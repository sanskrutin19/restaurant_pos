from sqlalchemy import Column, Integer, String, Float, ForeignKey, DateTime
from sqlalchemy.sql import func
from backend.database.core import Base

class Bill(Base):
    __tablename__ = "bills"

    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("orders.id"), unique=True)
    bill_number = Column(String, nullable=True)
    subtotal = Column(Float, nullable=False, default=0.0)
    taxable_subtotal = Column(Float, default=0.0)
    non_taxable_subtotal = Column(Float, default=0.0)
    discountable_subtotal = Column(Float, default=0.0)
    non_discountable_subtotal = Column(Float, default=0.0)
    total_amount = Column(Float, nullable=False)
    tax = Column(Float, default=0.0)
    cgst = Column(Float, default=0.0)
    sgst = Column(Float, default=0.0)
    discount = Column(Float, default=0.0)
    discount_type = Column(String, default="flat")  # flat, percentage
    discount_value = Column(Float, default=0.0)  # original input value
    discount_note = Column(String, nullable=True)  # e.g., "Discount not applicable on 2 items"
    round_off = Column(Float, default=0.0)
    payment_details = Column(String, nullable=True) # e.g., "Cash: 500.0, UPI: 200.0"
    counter_id = Column(String, nullable=True)
    is_reprint = Column(Integer, default=0)  # Track reprint count
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class Payment(Base):
    __tablename__ = "payments"

    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("orders.id"), index=True)  # Multiple payments per order for split billing
    amount = Column(Float, nullable=False)
    payment_method = Column(String, nullable=False) # cash, UPI, card
    status = Column(String, default="Completed")
    counter_id = Column(String, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
