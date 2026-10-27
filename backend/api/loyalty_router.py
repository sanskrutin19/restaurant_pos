from typing import List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from backend.database.core import get_db
from backend.schemas.customer import CustomerResponse, CustomerCreate
from backend.schemas.orders import OrderResponse
from backend.schemas.commands import CreateCustomerCommand, RedeemPointsCommand
from backend.commands.core import command_bus
from backend.services import loyalty as loyalty_service

router = APIRouter(prefix="/loyalty", tags=["Loyalty"])

@router.get("/customer/{phone}", response_model=CustomerResponse)
def get_customer(phone: str, db: Session = Depends(get_db)):
    customer = loyalty_service.get_customer_by_phone(db, phone)
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")
    return customer

@router.post("/customer", response_model=CustomerResponse)
async def create_customer(cmd: CreateCustomerCommand, db: Session = Depends(get_db)):
    return await command_bus.dispatch(cmd, db)

@router.post("/customer/redeem")
async def redeem_points(cmd: RedeemPointsCommand, db: Session = Depends(get_db)):
    try:
        success = await command_bus.dispatch(cmd, db)
        if not success:
            raise HTTPException(status_code=400, detail="Insufficient points or customer not found")
        return {"status": "success", "message": f"{cmd.points} points redeemed"}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/customers/search", response_model=List[CustomerResponse])
def search_customers(query: str, db: Session = Depends(get_db)):
    """Search customers by name or phone."""
    return loyalty_service.search_customers(db, query)

@router.get("/customer/{phone}/history", response_model=List[OrderResponse])
def get_customer_history(phone: str, db: Session = Depends(get_db)):
    """Get historical orders for a customer."""
    customer = loyalty_service.get_customer_by_phone(db, phone)
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")
    return loyalty_service.get_customer_history(db, customer.id)
