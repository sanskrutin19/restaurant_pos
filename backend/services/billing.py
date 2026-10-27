from typing import Optional
from sqlalchemy.orm import Session
from backend.models.billing import Bill
from backend.models.system import PrinterJob, SystemSettings
from backend.models.order import Order
from backend.models.kot import BillSequence
from backend.schemas.commands import PrintBillCommand
from backend.commands.core import command_bus
from datetime import date
import math


def get_tax_rate(db: Session) -> float:
    """Fetch current GST rate from settings."""
    rate = db.query(SystemSettings).filter(SystemSettings.key == "tax_rate").first()
    if not rate:
        return 5.0
    try:
        return float(rate.value)
    except (ValueError, TypeError):
        return 5.0


def get_next_bill_number(db: Session, prefix: str = "BILL") -> str:
    """Generate sequential bill number for today."""
    today = date.today().isoformat()
    seq = db.query(BillSequence).filter(
        BillSequence.prefix == prefix,
        BillSequence.date == today
    ).first()

    if seq:
        seq.last_number += 1
    else:
        seq = BillSequence(prefix=prefix, date=today, last_number=1)
        db.add(seq)

    db.flush()
    year = date.today().year
    return f"{prefix}-{year}-{seq.last_number:05d}"


def generate_bill(
    db: Session,
    order_id: int,
    tax_rate: Optional[float] = None,
    discount: float = 0.0,
    discount_type: str = "flat",
    discount_value: float = 0.0,
    counter_id: Optional[str] = None,
) -> Bill:
    """
    Calculates total and generates a bill for an order.
    
    Supports:
    - Split discount: only applies to discountable items (#1)
    - Split tax: per-item tax rates (#2)  
    - Bill numbering (#13)
    """
    if tax_rate is None:
        tax_rate = get_tax_rate(db)
        
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise ValueError("Order not found")

    # Use order-specific defaults if not provided in request
    if tax_rate is None:
        tax_rate = getattr(order, 'tax_rate', None) or get_tax_rate(db)
    
    if discount == 0.0:
        discount = getattr(order, 'discount_amount', 0.0) or 0.0

    # ── Split items into categories ──────────────────────────────────
    active_items = [item for item in order.items if getattr(item, 'status', 'Pending').lower() != 'cancelled'
                    and getattr(item, 'kot_status', 'active') != 'cancelled']

    discountable_subtotal = 0.0
    non_discountable_subtotal = 0.0
    taxable_subtotal = 0.0
    non_taxable_subtotal = 0.0
    total_tax = 0.0
    total_cgst = 0.0
    total_sgst = 0.0
    non_discountable_names = []

    for item in active_items:
        item_total = item.price * item.quantity

        # Discount split (#1)
        allow_disc = getattr(item, 'allow_discount', True)
        if allow_disc is None:
            allow_disc = True
        if allow_disc:
            discountable_subtotal += item_total
        else:
            non_discountable_subtotal += item_total
            non_discountable_names.append(getattr(item, 'name', 'Item'))

        # Tax split (#2)
        tax_en = getattr(item, 'tax_enabled', True)
        if tax_en is None:
            tax_en = True
        if tax_en:
            taxable_subtotal += item_total
            item_tax_rate = getattr(item, 'tax_percentage', tax_rate) or tax_rate
            item_cgst = round(item_total * (item_tax_rate / 2.0 / 100.0), 2)
            item_sgst = round(item_total * (item_tax_rate / 2.0 / 100.0), 2)
            total_cgst += item_cgst
            total_sgst += item_sgst
            total_tax += item_cgst + item_sgst
        else:
            non_taxable_subtotal += item_total

    subtotal = discountable_subtotal + non_discountable_subtotal

    # ── Apply discount only to discountable portion ──────────────────
    effective_discount = min(discount, discountable_subtotal)

    # Recalculate tax on discounted amount for taxable+discountable items
    # We need to reduce tax proportionally for the discount applied
    if discount > 0 and discountable_subtotal > 0:
        discount_ratio = effective_discount / discountable_subtotal
        # Reduce tax for discountable+taxable items
        taxable_discountable = 0.0
        for item in active_items:
            allow_disc = getattr(item, 'allow_discount', True)
            tax_en = getattr(item, 'tax_enabled', True)
            if (allow_disc is None or allow_disc) and (tax_en is None or tax_en):
                taxable_discountable += item.price * item.quantity
        
        if taxable_discountable > 0:
            tax_reduction_ratio = min(effective_discount, taxable_discountable) / taxable_discountable
            # Recompute tax excluding discount portion
            new_cgst = 0.0
            new_sgst = 0.0
            new_tax = 0.0
            for item in active_items:
                tax_en = getattr(item, 'tax_enabled', True)
                if tax_en is None or not tax_en:
                    continue
                item_total = item.price * item.quantity
                allow_disc = getattr(item, 'allow_discount', True)
                if allow_disc is None:
                    allow_disc = True
                if allow_disc:
                    # This item gets a proportional discount
                    item_after_discount = item_total * (1 - discount_ratio)
                else:
                    item_after_discount = item_total
                item_tax_rate = getattr(item, 'tax_percentage', tax_rate) or tax_rate
                c = round(item_after_discount * (item_tax_rate / 2.0 / 100.0), 2)
                s = round(item_after_discount * (item_tax_rate / 2.0 / 100.0), 2)
                new_cgst += c
                new_sgst += s
                new_tax += c + s
            total_cgst = new_cgst
            total_sgst = new_sgst
            total_tax = new_tax

    # Build discount note
    discount_note = None
    if non_discountable_names and discount > 0:
        discount_note = f"Discount not applicable on: {', '.join(non_discountable_names)}"

    # Room service charge
    room_charge = getattr(order, 'room_service_charge', 0.0) or 0.0

    raw_total = (subtotal - effective_discount) + total_tax + room_charge
    rounded_total = round(raw_total, 2)
    round_off = 0.0

    # Aggregate payment details for split-billing
    from backend.models.billing import Payment
    payments = db.query(Payment).filter(Payment.order_id == order_id, Payment.status == "Completed").all()
    pay_map = {}
    for p in payments:
        method = p.payment_method.upper()
        pay_map[method] = pay_map.get(method, 0.0) + p.amount
    pay_details = ", ".join([f"{m}: ₹{amt:.2f}" for m, amt in pay_map.items()])

    # Check for existing bill
    existing_bill = db.query(Bill).filter(Bill.order_id == order_id).first()
    
    if existing_bill:
        existing_bill.subtotal = subtotal
        existing_bill.taxable_subtotal = taxable_subtotal
        existing_bill.non_taxable_subtotal = non_taxable_subtotal
        existing_bill.discountable_subtotal = discountable_subtotal
        existing_bill.non_discountable_subtotal = non_discountable_subtotal
        existing_bill.total_amount = rounded_total
        existing_bill.tax = total_tax
        existing_bill.cgst = total_cgst
        existing_bill.sgst = total_sgst
        existing_bill.discount = effective_discount
        existing_bill.discount_note = discount_note
        existing_bill.round_off = round_off
        existing_bill.payment_details = pay_details
        db.commit()
        db.refresh(existing_bill)
        return existing_bill
    
    # Generate bill number
    bill_number = get_next_bill_number(db)

    bill = Bill(
        order_id=order_id,
        bill_number=bill_number,
        subtotal=subtotal,
        taxable_subtotal=taxable_subtotal,
        non_taxable_subtotal=non_taxable_subtotal,
        discountable_subtotal=discountable_subtotal,
        non_discountable_subtotal=non_discountable_subtotal,
        total_amount=rounded_total,
        tax=total_tax,
        cgst=total_cgst,
        sgst=total_sgst,
        discount=effective_discount,
        discount_type=discount_type,
        discount_value=discount_value,
        discount_note=discount_note,
        round_off=round_off,
        payment_details=pay_details,
        counter_id=counter_id,
    )
    db.add(bill)
    
    # Also set bill_number on the order
    order.bill_number = bill_number
    
    db.commit()
    db.refresh(bill)
    return bill


def handle_print_bill(cmd: PrintBillCommand, db: Session) -> PrinterJob:
    """Handler to push a print job to the queue."""
    generate_bill(db, cmd.order_id)
    
    job = PrinterJob(
        printer_name=cmd.printer_name,
        document_type="receipt",
        reference_id=str(cmd.order_id),
        status="Pending"
    )
    db.add(job)
    db.commit()
    db.refresh(job)
    return job

command_bus.register(PrintBillCommand, handle_print_bill)
