
from backend.database.core import SessionLocal
from backend.models.user import User
from backend.security.auth import get_password_hash

db = SessionLocal()
user = db.query(User).filter(User.username == "admin").first()
if user:
    user.password_hash = get_password_hash("admin123")
    db.commit()
    print("User 'admin' password reset to 'admin123' successfully.")
else:
    print("User 'admin' not found.")
db.close()
