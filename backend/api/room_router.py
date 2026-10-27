"""Room management API router."""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import Optional
from pydantic import BaseModel

from backend.database.core import get_db
from backend.models.room import Room

router = APIRouter(prefix="/rooms", tags=["rooms"])


# --- Schemas ---
class RoomCreate(BaseModel):
    room_number: str
    floor: Optional[str] = None
    guest_name: Optional[str] = None
    service_charge: float = 0.0


class RoomUpdate(BaseModel):
    room_number: Optional[str] = None
    floor: Optional[str] = None
    guest_name: Optional[str] = None
    status: Optional[str] = None
    service_charge: Optional[float] = None
    is_active: Optional[bool] = None


class RoomResponse(BaseModel):
    id: int
    room_number: str
    floor: Optional[str] = None
    guest_name: Optional[str] = None
    status: Optional[str] = "available"
    service_charge: float = 0.0
    is_active: Optional[bool] = True

    class Config:
        from_attributes = True


# --- Endpoints ---
@router.get("", response_model=list[RoomResponse])
def list_rooms(db: Session = Depends(get_db)):
    return db.query(Room).filter(Room.is_active == True).order_by(Room.room_number).all()


@router.post("", response_model=RoomResponse)
def create_room(data: RoomCreate, db: Session = Depends(get_db)):
    existing = db.query(Room).filter(Room.room_number == data.room_number).first()
    if existing:
        raise HTTPException(status_code=400, detail=f"Room {data.room_number} already exists")
    room = Room(
        room_number=data.room_number,
        floor=data.floor,
        guest_name=data.guest_name,
        service_charge=data.service_charge,
    )
    db.add(room)
    db.commit()
    db.refresh(room)
    return room


@router.put("/{room_id}", response_model=RoomResponse)
def update_room(room_id: int, data: RoomUpdate, db: Session = Depends(get_db)):
    room = db.query(Room).filter(Room.id == room_id).first()
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(room, field, value)
    db.commit()
    db.refresh(room)
    return room


@router.delete("/{room_id}")
def delete_room(room_id: int, db: Session = Depends(get_db)):
    room = db.query(Room).filter(Room.id == room_id).first()
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    room.is_active = False  # Soft delete
    db.commit()
    return {"status": "ok", "detail": f"Room {room.room_number} deactivated"}


@router.post("/{room_id}/checkin", response_model=RoomResponse)
def checkin_room(room_id: int, guest_name: str = None, db: Session = Depends(get_db)):
    room = db.query(Room).filter(Room.id == room_id).first()
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    room.status = "occupied"
    if guest_name:
        room.guest_name = guest_name
    db.commit()
    db.refresh(room)
    return room


@router.post("/{room_id}/checkout", response_model=RoomResponse)
def checkout_room(room_id: int, db: Session = Depends(get_db)):
    room = db.query(Room).filter(Room.id == room_id).first()
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    room.status = "available"
    room.guest_name = None
    db.commit()
    db.refresh(room)
    return room
