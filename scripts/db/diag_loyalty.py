
import sys
import os

# Add project root to path
sys.path.append(os.getcwd())

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from backend.services import loyalty as loyalty_service
from backend.schemas.orders import OrderResponse
from typing import List
from pydantic import TypeAdapter

# Database setup
SQLALCHEMY_DATABASE_URL = "sqlite:///./restaurant_pos.db"
engine = create_engine(SQLALCHEMY_DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def diag():
    db = SessionLocal()
    phone = "9172748544"
    print(f"Checking history for phone: {phone}")
    
    customer = loyalty_service.get_customer_by_phone(db, phone)
    if not customer:
        print("Customer not found")
        return
        
    print(f"Customer ID: {customer.id}")
    orders = loyalty_service.get_customer_history(db, customer.id)
    print(f"Found {len(orders)} orders")
    
    adapter = TypeAdapter(List[OrderResponse])
    try:
        # Attempt serialization
        serialized = adapter.validate_python(orders)
        print("Serialization SUCCESSful")
    except Exception as e:
        print("\n!!! SERIALIZATION ERROR !!!")
        print(e)

if __name__ == "__main__":
    diag()
