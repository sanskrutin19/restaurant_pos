from backend.database.core import SessionLocal
from backend.models.user import User
from backend.security.auth import get_password_hash

def setup_test_users():
    db = SessionLocal()
    try:
        # 1. Setup Manager
        manager = db.query(User).filter(User.username == "manager").first()
        if not manager:
            manager = User(
                username="manager",
                role="ADMIN", # Manager uses ADMIN role features
                pin="1122",
                password_hash=get_password_hash("manager123")
            )
            db.add(manager)
        else:
            manager.pin = "1122"
            manager.role = "ADMIN"

        # 2. Setup Kitchen
        kitchen = db.query(User).filter(User.username == "kitchen").first()
        if not kitchen:
            kitchen = User(
                username="kitchen",
                role="KITCHEN",
                pin="3344",
                password_hash=get_password_hash("kitchen123")
            )
            db.add(kitchen)
        else:
            kitchen.pin = "3344"
            kitchen.role = "KITCHEN"

        db.commit()
        print("Manager and Kitchen users configured successfully.")
    finally:
        db.close()

if __name__ == "__main__":
    setup_test_users()
