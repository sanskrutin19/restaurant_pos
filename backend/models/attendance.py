from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
from sqlalchemy.sql import func
from backend.database.core import Base

class Attendance(Base):
    __tablename__ = "attendance"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    clock_in = Column(DateTime(timezone=True), server_default=func.now())
    clock_out = Column(DateTime(timezone=True), nullable=True)
    total_hours = Column(Integer, default=0)
