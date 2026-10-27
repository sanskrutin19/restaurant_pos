from sqlalchemy.orm import Session
from backend.commands.core import command_bus
from backend.schemas.commands import RedeemPointsCommand, CreateCustomerCommand
from backend.services.loyalty import redeem_points, create_customer

def handle_redeem_points(command: RedeemPointsCommand, db: Session):
    return redeem_points(db, command.phone, command.points)

def handle_create_customer(command: CreateCustomerCommand, db: Session):
    return create_customer(db, command)

# Register handlers
command_bus.register(RedeemPointsCommand, handle_redeem_points)
command_bus.register(CreateCustomerCommand, handle_create_customer)
