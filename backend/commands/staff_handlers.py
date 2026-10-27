from sqlalchemy.orm import Session
from datetime import datetime
from fastapi import HTTPException
from backend.commands.core import command_bus
from backend.schemas.commands import ClockInCommand, ClockOutCommand
from backend.models.attendance import Attendance

def handle_clock_in(command: ClockInCommand, db: Session):
    active = db.query(Attendance).filter(
        Attendance.user_id == command.user_id, 
        Attendance.clock_out == None
    ).first()
    
    if active:
        raise HTTPException(status_code=400, detail="User already clocked in")
    
    entry = Attendance(user_id=command.user_id)
    db.add(entry)
    db.commit()
    db.refresh(entry)
    return entry

def handle_clock_out(command: ClockOutCommand, db: Session):
    active = db.query(Attendance).filter(
        Attendance.user_id == command.user_id, 
        Attendance.clock_out == None
    ).first()
    
    if not active:
        raise HTTPException(status_code=400, detail="User not clocked in")
    
    active.clock_out = datetime.now()
    diff = active.clock_out - active.clock_in
    active.total_hours = diff.seconds // 3600
    
    db.commit()
    db.refresh(active)
    return active

# Register handlers
command_bus.register(ClockInCommand, handle_clock_in)
command_bus.register(ClockOutCommand, handle_clock_out)
