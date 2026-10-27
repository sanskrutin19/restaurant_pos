import socket
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from backend.database.core import get_db
from backend.models.catalog import MenuItem

router = APIRouter(prefix="/qr", tags=["QR Ordering"])

def get_local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        # doesn't even have to be reachable
        s.connect(('10.255.255.255', 1))
        IP = s.getsockname()[0]
    except Exception:
        IP = '127.0.0.1'
    finally:
        s.close()
    return IP

@router.get("/menu")
def get_guest_menu(db: Session = Depends(get_db)):
    """Lightweight menu for guests"""
    items = db.query(MenuItem).filter(MenuItem.is_available == True).all()
    return items

@router.get("/table/{table_id}/url")
def get_table_url(table_id: int):
    """Generate the QR URL for a specific table"""
    local_ip = get_local_ip()
    # Path should point to the root where the web Guest Menu is mounted
    # Flutter web usually uses hash routing: http://IP:8000/#/guest-order
    base_url = f"http://{local_ip}:8000"
    return {"url": f"{base_url}/#/guest-order?table={table_id}"}
