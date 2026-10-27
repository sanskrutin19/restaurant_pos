from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
from pydantic import BaseModel
from datetime import datetime
from backend.database.core import get_db
from backend.models.offers import Offer

router = APIRouter(prefix="/offers", tags=["Offers"])


# --- Schemas ---
class OfferCreate(BaseModel):
    name: str
    code: Optional[str] = None
    offer_type: str = "percentage"  # percentage, flat, bogo
    value: float = 0.0
    min_order_amount: float = 0.0
    max_discount: float = 0.0
    start_time: Optional[str] = None
    end_time: Optional[str] = None
    days_active: str = "0,1,2,3,4,5,6"
    usage_limit: int = 0


class OfferResponse(BaseModel):
    id: int
    name: str
    code: Optional[str]
    offer_type: str
    value: float
    min_order_amount: float
    max_discount: float
    is_active: bool
    start_time: Optional[str]
    end_time: Optional[str]
    days_active: str
    usage_limit: int
    used_count: int

    class Config:
        from_attributes = True


class ApplyCouponRequest(BaseModel):
    code: str
    order_total: float


class ApplyCouponResponse(BaseModel):
    valid: bool
    discount_amount: float = 0.0
    message: str = ""
    offer_name: str = ""


# --- Endpoints ---
@router.get("/", response_model=List[OfferResponse])
def list_offers(db: Session = Depends(get_db)):
    return db.query(Offer).all()


@router.post("/", response_model=OfferResponse)
def create_offer(data: OfferCreate, db: Session = Depends(get_db)):
    offer = Offer(**data.model_dump())
    db.add(offer)
    db.commit()
    db.refresh(offer)
    return offer


@router.put("/{offer_id}", response_model=OfferResponse)
def update_offer(offer_id: int, data: OfferCreate, db: Session = Depends(get_db)):
    offer = db.query(Offer).filter(Offer.id == offer_id).first()
    if not offer:
        raise HTTPException(status_code=404, detail="Offer not found")
    for key, value in data.model_dump().items():
        setattr(offer, key, value)
    db.commit()
    db.refresh(offer)
    return offer


@router.delete("/{offer_id}")
def delete_offer(offer_id: int, db: Session = Depends(get_db)):
    offer = db.query(Offer).filter(Offer.id == offer_id).first()
    if not offer:
        raise HTTPException(status_code=404, detail="Offer not found")
    db.delete(offer)
    db.commit()
    return {"message": "Offer deleted"}


@router.patch("/{offer_id}/toggle")
def toggle_offer(offer_id: int, db: Session = Depends(get_db)):
    offer = db.query(Offer).filter(Offer.id == offer_id).first()
    if not offer:
        raise HTTPException(status_code=404, detail="Offer not found")
    offer.is_active = not offer.is_active
    db.commit()
    return {"is_active": offer.is_active}


@router.post("/apply", response_model=ApplyCouponResponse)
def apply_coupon(request: ApplyCouponRequest, db: Session = Depends(get_db)):
    offer = db.query(Offer).filter(
        Offer.code == request.code,
        Offer.is_active == True
    ).first()

    if not offer:
        return ApplyCouponResponse(valid=False, message="Invalid coupon code")

    # Check usage limit
    if offer.usage_limit > 0 and offer.used_count >= offer.usage_limit:
        return ApplyCouponResponse(valid=False, message="Coupon usage limit reached")

    # Check minimum order
    if request.order_total < offer.min_order_amount:
        return ApplyCouponResponse(
            valid=False,
            message=f"Minimum order amount: ₹{offer.min_order_amount}"
        )

    # Check happy hours
    now = datetime.now()
    current_weekday = str(now.weekday())
    if current_weekday not in offer.days_active.split(","):
        return ApplyCouponResponse(valid=False, message="Offer not valid today")

    if offer.start_time and offer.end_time:
        current_time = now.strftime("%H:%M")
        if not (offer.start_time <= current_time <= offer.end_time):
            return ApplyCouponResponse(
                valid=False,
                message=f"Valid only between {offer.start_time} - {offer.end_time}"
            )

    # Calculate discount
    if offer.offer_type == "percentage":
        discount = request.order_total * (offer.value / 100)
        if offer.max_discount > 0:
            discount = min(discount, offer.max_discount)
    elif offer.offer_type == "flat":
        discount = offer.value
    else:
        discount = 0.0

    discount = min(discount, request.order_total)

    # Increment usage
    offer.used_count += 1
    db.commit()

    return ApplyCouponResponse(
        valid=True,
        discount_amount=discount,
        message=f"Coupon applied: ₹{discount:.2f} off",
        offer_name=offer.name,
    )
