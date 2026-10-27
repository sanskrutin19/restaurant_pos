from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from backend.database.core import get_db
from backend.schemas.commands import ClockInCommand, ClockOutCommand
from backend.schemas.user import UserCreate, UserUpdate, UserResponse
from backend.commands.core import command_bus
from backend.models.attendance import Attendance
from backend.models.user import User
from backend.security.auth import RoleChecker, get_current_user, get_password_hash

router = APIRouter(prefix="/staff", tags=["Staff Management"])

@router.post("/clock-in/{user_id}")
async def clock_in(user_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    # Optional: Ensure user is clocking in themselves OR is an admin
    cmd = ClockInCommand(user_id=user_id)
    return await command_bus.dispatch(cmd, db)

@router.post("/clock-out/{user_id}")
async def clock_out(user_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    cmd = ClockOutCommand(user_id=user_id)
    return await command_bus.dispatch(cmd, db)

@router.get("/attendance", dependencies=[Depends(RoleChecker(["admin", "cashier"]))])
def get_attendance_logs(db: Session = Depends(get_db)):
    return db.query(Attendance).all()

@router.get("/users")
def get_staff_users(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    # All staff can see users, but non-admins only see basic info to prevent leakage
    is_admin = current_user.role == "admin"
    users = db.query(User).all()
    result = []
    for user in users:
        # Get active clock in
        active_session = db.query(Attendance).filter(
            Attendance.user_id == user.id,
            Attendance.clock_out == None
        ).first()
        
        result.append({
            "id": user.id,
            "username": user.username,
            "role": user.role,
            "hourly_rate": user.hourly_rate,
            "is_clocked_in": active_session is not None,
            "active_session_start": active_session.clock_in if active_session else None
        })
    return result

@router.post("/", response_model=UserResponse, dependencies=[Depends(RoleChecker(["admin"]))])
def create_staff(user_in: UserCreate, db: Session = Depends(get_db)):
    """Create a new staff member."""
    existing = db.query(User).filter(User.username == user_in.username).first()
    if existing:
        raise HTTPException(status_code=400, detail="Username already exists")
    
    new_user = User(
        username=user_in.username,
        password_hash=get_password_hash(user_in.password),
        role=user_in.role,
        hourly_rate=user_in.hourly_rate
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return new_user

@router.put("/{user_id}", response_model=UserResponse, dependencies=[Depends(RoleChecker(["admin"]))])
def update_staff(user_id: int, user_in: UserUpdate, db: Session = Depends(get_db)):
    """Update staff details."""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Staff not found")
    
    if user_in.username: user.username = user_in.username
    if user_in.role: user.role = user_in.role
    if user_in.hourly_rate is not None: user.hourly_rate = user_in.hourly_rate
    if user_in.password:
        user.password_hash = get_password_hash(user_in.password)
    
    db.commit()
    db.refresh(user)
    return user

@router.delete("/{user_id}", dependencies=[Depends(RoleChecker(["admin"]))])
def delete_staff(user_id: int, db: Session = Depends(get_db)):
    """Remove a staff member."""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Staff not found")
    
    db.delete(user)
    db.commit()
    return {"status": "success"}
