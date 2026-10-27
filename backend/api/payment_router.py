from fastapi import APIRouter, Depends, HTTPException
from backend.security.auth import get_current_user
from sqlalchemy.orm import Session
from typing import List
from backend.database.core import get_db
from backend.schemas.payments import PaymentRequest, PaymentResponse
from backend.schemas.commands import RecordPaymentCommand
from backend.commands.core import command_bus
from backend.models.billing import Payment, Bill
from backend.models.order import Order
import backend.services.payment # load handlers
from backend.utils.frozen_logger import log_msg

router = APIRouter(prefix="/payments", tags=["Payments"])

@router.post("", response_model=PaymentResponse)
async def record_payment(cmd: RecordPaymentCommand, db: Session = Depends(get_db)):
    """Record a payment for an order."""
    try:
        payment = await command_bus.dispatch(cmd, db)
        return payment
    except ValueError as e: 
        log_msg(f"PAYMENT ERROR (Value): {str(e)}")
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        import traceback
        log_msg(f"PAYMENT CRITICAL ERROR for Order {cmd.order_id}:\n{traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@router.get("/order/{order_id}", response_model=List[PaymentResponse])
def get_order_payments(order_id: int, db: Session = Depends(get_db)):
    """List all payments for an order (supports split payment view)."""
    payments = db.query(Payment).filter(Payment.order_id == order_id).all()
    return payments

@router.get("/order/{order_id}/balance")
def get_payment_balance(order_id: int, db: Session = Depends(get_db)):
    """Get remaining balance for an order (for split payments)."""
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    
    bill = db.query(Bill).filter(Bill.order_id == order_id).first()
    required_total = bill.total_amount if bill else order.total_amount

    paid = sum(
        p.amount for p in
        db.query(Payment).filter(Payment.order_id == order_id, Payment.status == "Completed").all()
    )

    return {
        "order_id": order_id,
        "total_required": required_total,
        "total_paid": paid,
        "balance_remaining": max(required_total - paid, 0),
        "is_fully_paid": paid >= required_total,
    }

