from sqlalchemy.orm import Session
from backend.models.customer import Customer
from backend.schemas.customer import CustomerCreate

def get_customer_by_phone(db: Session, phone: str):
    return db.query(Customer).filter(Customer.phone == phone).first()

def create_customer(db: Session, customer: CustomerCreate):
    db_customer = Customer(**customer.model_dump())
    db.add(db_customer)
    db.commit()
    db.refresh(db_customer)
    return db_customer

def add_points(db: Session, customer_id: int, amount: float):
    customer = db.query(Customer).filter(Customer.id == customer_id).first()
    if customer:
        # 1 point for every 100 spent
        points_to_add = int(amount / 100)
        customer.points += points_to_add
        customer.visits_count += 1
        db.commit()
    return customer

def redeem_points(db: Session, customer_id: int, points: int):
    customer = db.query(Customer).filter(Customer.id == customer_id).first()
    if customer and customer.points >= points:
        customer.points -= points
        db.commit()
        return True
    return False

def search_customers(db: Session, query: str):
    """Search customers by name or phone."""
    return db.query(Customer).filter(
        (Customer.name.ilike(f"%{query}%")) | 
        (Customer.phone.contains(query))
    ).limit(20).all()

def get_customer_history(db: Session, customer_id: int):
    """Get all past orders for a customer."""
    from backend.models.order import Order, OrderItem
    from sqlalchemy.orm import joinedload
    return db.query(Order).options(
        joinedload(Order.items).joinedload(OrderItem.menu_item),
        joinedload(Order.items).joinedload(OrderItem.modifiers)
    ).filter(Order.customer_id == customer_id).order_by(Order.created_at.desc()).all()
