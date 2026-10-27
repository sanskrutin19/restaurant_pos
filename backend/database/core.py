import os
import sys
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

# PRO-MODE: Use APPDATA for persistence. 
# This ensures it works even if installed in C:\Program Files
if getattr(sys, 'frozen', False):
    base_dir = os.path.join(os.environ.get('APPDATA', os.getcwd()), "Servezy")
else:
    # Development mode
    base_dir = os.path.dirname(os.path.abspath(__file__))
    if "database" in base_dir:
        base_dir = os.path.dirname(os.path.dirname(base_dir))

if not os.path.exists(base_dir):
    os.makedirs(base_dir)

db_path = os.path.join(base_dir, "restaurant_pos.db")
DATABASE_URL = f"sqlite:///{db_path}"

engine = create_engine(
    DATABASE_URL, connect_args={"check_same_thread": False}
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Standard practice for production-grade SQLite (Enables concurrency)
from sqlalchemy import event
@event.listens_for(engine, "connect")
def set_sqlite_pragma(dbapi_connection, connection_record):
    cursor = dbapi_connection.cursor()
    cursor.execute("PRAGMA journal_mode=WAL")
    cursor.execute("PRAGMA synchronous=NORMAL")
    cursor.execute("PRAGMA busy_timeout=5000") # 5s timeout for locks
    cursor.close()

Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
