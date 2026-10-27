from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from backend.database.core import get_db
from backend.security.auth import RoleChecker
import shutil
import os
import csv
import io
from datetime import datetime
from fastapi.responses import FileResponse, StreamingResponse
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
import pandas as pd
import json
try:
    import win32print
except ImportError:
    win32print = None

from backend.models.system import KitchenCounter
from pydantic import BaseModel
from typing import List, Optional, Any, Dict, Tuple, cast as t_cast
import socket
from sqlalchemy import func, cast, Date, text
from sqlalchemy.orm import joinedload
from backend.models.order import Order, OrderItem
from backend.models.billing import Payment, Bill
from backend.models.catalog import MenuItem as MenuItemModel, MenuCategory
from backend.models.system import KitchenCounter, SystemSettings
from backend.schemas.system import SystemSettingSchema, TaxSettingsUpdate, SystemSettingsUpdate

class KitchenCounterSchema(BaseModel):
    id: Optional[int] = None
    name: str
    is_active: bool = True
    icon: Optional[str] = "store"
    color: Optional[str] = "#000000"
    printer_type: Optional[str] = "network"
    printer_address: Optional[str] = None
    printer_port: Optional[int] = 9100
    class Config:
        from_attributes = True

router = APIRouter(
    prefix="/admin", 
    tags=["Admin"]
)

# Auth dependency for protected routes
protected = [Depends(RoleChecker(["admin", "manager", "cashier", "waiter", "owner"]))]

DB_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), "restaurant_pos.db")
BACKUP_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "backups")


@router.post("/backup", dependencies=protected)
def create_backup():
    """Create a timestamped backup of the SQLite database."""
    os.makedirs(BACKUP_DIR, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_path = os.path.join(BACKUP_DIR, f"pos_backup_{timestamp}.db")
    shutil.copy2(DB_PATH, backup_path)
    return {
        "message": "Backup created successfully",
        "backup_file": backup_path,
        "timestamp": timestamp,
    }


@router.get("/backup/download", dependencies=protected)
def download_backup():
    """Download the latest backup file."""
    os.makedirs(BACKUP_DIR, exist_ok=True)
    backups = sorted(
        [f for f in os.listdir(BACKUP_DIR) if f.endswith(".db")],
        reverse=True,
    )
    if not backups:
        # Create one on-the-fly
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_path = os.path.join(BACKUP_DIR, f"pos_backup_{timestamp}.db")
        shutil.copy2(DB_PATH, backup_path)
        return FileResponse(backup_path, filename=f"pos_backup_{timestamp}.db")

    latest = os.path.join(BACKUP_DIR, backups[0])
    return FileResponse(latest, filename=backups[0])


@router.get("/backup/list", dependencies=protected)
def list_backups():
    """List all available backups."""
    os.makedirs(BACKUP_DIR, exist_ok=True)
    backups = sorted(
        [f for f in os.listdir(BACKUP_DIR) if f.endswith(".db")],
        reverse=True,
    )
    results = []
    for b in backups:
        path = os.path.join(BACKUP_DIR, b)
        size_mb: float = float(os.path.getsize(path)) / (1024.0 * 1024.0)
        results.append({
            "filename": b,
            "size_mb": round(cast(Any, size_mb), 2),
            "created": os.path.getmtime(path),
        })
    return results


@router.get("/reports/daily", dependencies=protected)
async def daily_report(date: Optional[str] = None, db: Session = Depends(get_db)):
    """Get detailed daily report with date support. Format: YYYY-MM-DD"""

    if date:
        try:
            target_date = datetime.strptime(date, "%Y-%m-%d").date()
        except ValueError:
            target_date = datetime.now().date()
    else:
        target_date = datetime.now().date()

    # Orders for the target date - using joinedload for items
    orders: List[Order] = db.query(Order).options(joinedload(Order.items)).filter(
        func.date(Order.created_at) == target_date
    ).all()

    total_orders = len(orders)

    # Statuses that count as "Sales Revenue" (anything beyond pending/held)
    confirmed_statuses = ["Preparing", "preparing", "Ready", "ready", "Served", "served", "Paid", "paid", "Completed", "completed"]
    
    # Revenue from finalized Bills for the target date - ONLY PAID ORDERS
    total_revenue = db.query(func.sum(Bill.total_amount)).join(Order).filter(
        func.date(Bill.created_at) == target_date,
        Order.status.in_(["Paid", "paid"])
    ).scalar() or 0.0
    
    completed_orders = [o for o in orders if o.status.lower() in ("ready", "served", "paid", "completed")]
    cancelled_orders = [o for o in orders if o.status.lower() == "cancelled"]

    # Payment breakdown
    payments = db.query(Payment).filter(
        func.date(Payment.created_at) == target_date
    ).all()

    payment_breakdown = {}
    for p in payments:
        method = p.payment_method or "unknown"
        payment_breakdown[method] = payment_breakdown.get(method, 0) + p.amount

    # Item sales with naming
    item_sales: Dict[Tuple[int, str], float] = {} # (item_id, name) -> quantity
    # Enrich items with menu item names
    for order in t_cast(List[Order], orders):
        o_status: str = str(order.status or "")
        if o_status.lower() == "cancelled":
            continue
        for item in t_cast(List[OrderItem], order.items):
            if item.menu_item and not item.name:
                item.name = item.menu_item.name
            
            name = item.name # Ensure 'name' is defined for the key creation
            key: Tuple[int, str] = (int(item.item_id), str(name or f"Item #{item.item_id}"))
            current_qty: float = float(item_sales.get(key, 0.0))
            item_sales[key] = current_qty + float(item.quantity)

    # Convert to list for slicing
    sales_list = list(item_sales.items())
    sales_list.sort(key=lambda x: x[1], reverse=True)
    
    # Use a loop to get top items if slicing is causing lint issues
    top_items = []
    for i in range(min(10, len(sales_list))):
        top_items.append(sales_list[i])

    # Order type breakdown
    type_breakdown = {}
    for o in orders:
        otype = getattr(o, 'order_type', 'dine_in') or 'dine_in'
        type_breakdown[otype] = type_breakdown.get(otype, 0) + 1

    return {
        "date": str(target_date),
        "total_orders": total_orders,
        "total_revenue": total_revenue,
        "completed_orders": len(completed_orders),
        "cancelled_orders": len(cancelled_orders),
        "average_order_value": float(total_revenue) / float(total_orders) if total_orders > 0 else 0.0,
        "payment_breakdown": payment_breakdown,
        "order_type_breakdown": type_breakdown,
        "top_selling_items": [{"item_id": k[0], "name": k[1], "quantity": v} for k, v in top_items],
    }

@router.get("/reports/category-sales", dependencies=protected)
def category_sales_report(date: Optional[str] = None, db: Session = Depends(get_db)):
    """Get sales breakdown by category."""
    target_date = datetime.strptime(date, "%Y-%m-%d").date() if date else datetime.now().date()

    results = db.query(
        MenuCategory.name,
        func.sum(OrderItem.price * OrderItem.quantity).label("total_sales"),
        func.sum(OrderItem.quantity).label("total_quantity")
    ).join(MenuItemModel, MenuItemModel.category_id == MenuCategory.id)\
     .join(OrderItem, OrderItem.item_id == MenuItemModel.id)\
     .join(Order, Order.id == OrderItem.order_id)\
     .filter(func.date(Order.created_at) == target_date)\
     .filter(Order.status.in_(["Paid", "paid"]))\
     .group_by(MenuCategory.name).all()

    return [{"category": r[0], "sales": r[1], "quantity": r[2]} for r in results]

@router.get("/reports/tax-summary", dependencies=protected)
def tax_summary_report(date: Optional[str] = None, db: Session = Depends(get_db)):
    """Get tax breakdown (GST) for a specific date."""
    target_date = datetime.strptime(date, "%Y-%m-%d").date() if date else datetime.now().date()

    # Assuming Bill model has cgst, sgst fields
    results = db.query(
        func.sum(Bill.subtotal).label("total_subtotal"),
        func.sum(Bill.cgst).label("total_cgst"),
        func.sum(Bill.sgst).label("total_sgst"),
        func.sum(Bill.total_amount).label("total_grand_total")
    ).join(Order).filter(
        func.date(Bill.created_at) == target_date,
        Order.status.in_(["Paid", "paid"])
    ).first()

    return {
        "date": str(target_date),
        "subtotal": results[0] or 0.0,
        "cgst": results[1] or 0.0,
        "sgst": results[2] or 0.0,
        "grand_total": results[3] or 0.0
    }

@router.get("/reports/payment-methods", dependencies=protected)
def payment_methods_report(date: Optional[str] = None, db: Session = Depends(get_db)):
    """Get detailed payment method breakdown."""
    target_date = datetime.strptime(date, "%Y-%m-%d").date() if date else datetime.now().date()

    results = db.query(
        Payment.payment_method,
        func.count(Payment.id).label("transaction_count"),
        func.sum(Payment.amount).label("total_amount")
    ).filter(
        func.date(Payment.created_at) == target_date,
        Payment.status == "Completed"
    )\
     .group_by(Payment.payment_method).all()

    return [{"method": r[0] or "unknown", "count": r[1], "amount": r[2]} for r in results]


@router.get("/reports/dashboard-unified", dependencies=protected)
async def dashboard_unified(date: Optional[str] = None, db: Session = Depends(get_db)):
    """Unified dashboard data for the frontend."""
    # Reuse existing logic via internal calls
    daily = await daily_report(date, db)
    return daily

@router.get("/reports/insights-unified", dependencies=protected)
async def insights_unified(date: Optional[str] = None, db: Session = Depends(get_db)):
    """Unified insights data for the frontend."""
    target_date = date or datetime.now().strftime("%Y-%m-%d")
    daily = await daily_report(target_date, db)
    categories = category_sales_report(target_date, db)
    taxes = tax_summary_report(target_date, db)
    payments = payment_methods_report(target_date, db)
    
    return {
        "summary": daily,
        "categories": categories,
        "taxes": taxes,
        "payments": payments
    }

@router.get("/reports/export", dependencies=protected)
async def export_report(date: Optional[str] = None, type: str = "csv", db: Session = Depends(get_db)):
    """Export detailed report for a specific date (CSV or PDF)."""
    target_date_obj = datetime.strptime(date, "%Y-%m-%d").date() if date else datetime.now().date()
    target_date_str = target_date_obj.strftime("%Y-%m-%d")

    # Reuse unified insights for data consistency
    insights = await insights_unified(target_date_str, db)
    summary = insights["summary"]
    taxes = insights["taxes"]
    categories = insights["categories"]
    
    # Fetch detailed paid orders
    orders = db.query(Order).options(joinedload(Order.items)).filter(
        func.date(Order.created_at) == target_date_obj,
        Order.status.in_(["Paid", "paid"])
    ).all()

    if type.lower() == "csv":
        output = io.StringIO()
        writer = csv.writer(output)
        
        # Section 1: Summary
        writer.writerow(["SECTION 1: BUSINESS SUMMARY"])
        writer.writerow(["Metric", "Value"])
        writer.writerow(["Total Revenue", f"{summary['total_revenue']:.2f}"])
        writer.writerow(["Total Orders", summary['total_orders']])
        writer.writerow(["CGST", f"{taxes['cgst']:.2f}"])
        writer.writerow(["SGST", f"{taxes['sgst']:.2f}"])
        writer.writerow(["Grand Total", f"{taxes['grand_total']:.2f}"])
        writer.writerow([])
        
        # Section 2: Detailed Orders
        writer.writerow(["SECTION 2: DETAILED ORDERS"])
        writer.writerow(["Date", "Order ID", "Items", "Qty", "Amount", "Tax", "Payment Mode"])
        
        for o in orders:
            bill = db.query(Bill).filter(Bill.order_id == o.id).first()
            payment = db.query(Payment).filter(Payment.order_id == o.id).first()
            items_str = "; ".join([f"{i.name} x{i.quantity}" for i in o.items])
            qty = sum([i.quantity for i in o.items])
            amount = bill.total_amount if bill else 0.0
            tax = (bill.cgst + bill.sgst) if bill else 0.0
            pmode = payment.payment_method if payment else "N/A"
            
            writer.writerow([
                o.created_at.strftime("%H:%M:%S"),
                o.id,
                items_str,
                qty,
                f"{amount:.2f}",
                f"{tax:.2f}",
                pmode
            ])

        output.seek(0)
        return StreamingResponse(
            iter([output.getvalue()]),
            media_type="text/csv",
            headers={"Content-Disposition": f"attachment; filename=report_{target_date_str}.csv"}
        )

    elif type.lower() == "pdf":
        buf = io.BytesIO()
        with PdfPages(buf) as pdf:
            # Page 1: Summary & Category Sales
            fig, ax = plt.subplots(figsize=(8.5, 11))
            ax.axis('off')
            
            # Header
            plt.text(0.5, 0.95, "SALES REPORT", ha='center', fontsize=20, weight='bold')
            plt.text(0.5, 0.92, f"Date: {target_date_str}", ha='center', fontsize=12)
            plt.axhline(y=0.9, xmin=0.05, xmax=0.95, color='black', linewidth=1)
            
            # Summary Table
            plt.text(0.05, 0.85, "Financial Summary", weight='bold', fontsize=14)
            summary_data = [
                ["Total Revenue", f"INR {summary['total_revenue']:.2f}"],
                ["Total Orders", str(summary['total_orders'])],
                ["Total CGST", f"INR {taxes['cgst']:.2f}"],
                ["Total SGST", f"INR {taxes['sgst']:.2f}"],
                ["Grand Total", f"INR {taxes['grand_total']:.2f}"]
            ]
            table = plt.table(cellText=summary_data, colWidths=[0.3, 0.3], loc='center', bbox=[0.05, 0.65, 0.6, 0.15])
            table.auto_set_font_size(False)
            table.set_fontsize(10)
            
            # Category Breakdown
            plt.text(0.05, 0.6, "Category Breakdown", weight='bold', fontsize=14)
            cat_data = [[c['category'], f"{c['sales']:.2f}", str(c['quantity'])] for c in categories]
            if cat_data:
                cat_table = plt.table(cellText=cat_data, colLabels=["Category", "Sales", "Qty"], loc='center', bbox=[0.05, 0.35, 0.9, 0.2])
                cat_table.auto_set_font_size(False)
                cat_table.set_fontsize(9)
            else:
                plt.text(0.05, 0.55, "No category sales recorded.")

            pdf.savefig()
            plt.close()

            # Page 2+: Detailed Orders
            if orders:
                # Group orders for multiple pages if needed (approx 30 per page)
                batch_size = 30
                for i in range(0, len(orders), batch_size):
                    batch = orders[i:i+batch_size]
                    fig, ax = plt.subplots(figsize=(8.5, 11))
                    ax.axis('off')
                    plt.text(0.5, 0.95, f"Detailed Transactions (Part {i//batch_size + 1})", ha='center', fontsize=16, weight='bold')
                    
                    order_rows = []
                    for o in batch:
                        bill = db.query(Bill).filter(Bill.order_id == o.id).first()
                        order_rows.append([
                            o.created_at.strftime("%H:%M"),
                            f"#{o.id}",
                            f"{bill.total_amount:.2f}" if bill else "0.00",
                            (db.query(Payment).filter(Payment.order_id == o.id).first().payment_method if db.query(Payment).filter(Payment.order_id == o.id).first() else "N/A")
                        ])
                    
                    order_table = plt.table(cellText=order_rows, colLabels=["Time", "Order ID", "Amount", "Mode"], loc='center', bbox=[0.05, 0.1, 0.9, 0.8])
                    order_table.auto_set_font_size(False)
                    order_table.set_fontsize(8)
                    pdf.savefig()
                    plt.close()

        buf.seek(0)
        return StreamingResponse(
            buf,
            media_type="application/pdf",
            headers={"Content-Disposition": f"attachment; filename=report_{target_date_str}.pdf"}
        )

    return {"error": "Unsupported export type"}

# --- System Settings CRUD ---

@router.get("/settings", response_model=List[SystemSettingSchema], dependencies=protected)
def get_settings(db: Session = Depends(get_db)):
    return db.query(SystemSettings).all()

@router.post("/settings/tax", dependencies=protected)
def update_tax_settings(data: TaxSettingsUpdate, db: Session = Depends(get_db)):
    setting = db.query(SystemSettings).filter(SystemSettings.key == "tax_rate").first()
    if not setting:
        setting = SystemSettings(key="tax_rate", value=str(data.tax_rate))
        db.add(setting)
    else:
        setting.value = str(data.tax_rate)
    db.commit()
    return {"status": "success", "tax_rate": data.tax_rate}

@router.post("/settings/bulk", dependencies=protected)
def update_settings_bulk(data: SystemSettingsUpdate, db: Session = Depends(get_db)):
    for key, value in data.settings.items():
        setting = db.query(SystemSettings).filter(SystemSettings.key == key).first()
        if not setting:
            setting = SystemSettings(key=key, value=str(value))
            db.add(setting)
        else:
            setting.value = str(value)
    db.commit()
    return {"status": "success"}

@router.get("/kitchen-counters", response_model=List[KitchenCounterSchema])
def list_counters(db: Session = Depends(get_db)):
    """List available counters (public for POS grid/printing)."""
    return db.query(KitchenCounter).all()

@router.post("/kitchen-counters", response_model=KitchenCounterSchema, dependencies=protected)
def create_counter(counter: KitchenCounterSchema, db: Session = Depends(get_db)):
    db_counter = KitchenCounter(
        name=counter.name, 
        icon=counter.icon, 
        color=counter.color,
        printer_type=counter.printer_type,
        printer_address=counter.printer_address,
        printer_port=counter.printer_port
    )
    db.add(db_counter)
    db.commit()
    db.refresh(db_counter)
    return db_counter

@router.put("/kitchen-counters/{counter_id}", response_model=KitchenCounterSchema, dependencies=protected)
def update_counter(counter_id: int, counter: KitchenCounterSchema, db: Session = Depends(get_db)):
    """Update an existing kitchen counter/printer configuration."""
    print(f"Updating counter {counter_id}: {counter.model_dump()}")
    db_counter = db.query(KitchenCounter).filter(KitchenCounter.id == counter_id).first()
    if not db_counter:
        raise HTTPException(status_code=404, detail=f"Counter {counter_id} not found")
        
    try:
        db_counter.name = counter.name
        db_counter.icon = counter.icon
        db_counter.color = counter.color
        db_counter.printer_type = counter.printer_type
        db_counter.printer_address = counter.printer_address
        db_counter.printer_port = counter.printer_port
        db_counter.is_active = counter.is_active
        
        db.commit()
        db.refresh(db_counter)
        print(f"Counter {counter_id} updated successfully: {db_counter.printer_address}")
        return db_counter
    except Exception as e:
        db.rollback()
        print(f"Error updating counter: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/kitchen-counters/{counter_id}", dependencies=protected)
def delete_counter(counter_id: int, db: Session = Depends(get_db)):
    counter = db.query(KitchenCounter).filter(KitchenCounter.id == counter_id).first()
    if counter:
        db.delete(counter)
        db.commit()
    return {"status": "success"}

@router.post("/reset-orders", dependencies=[Depends(RoleChecker(["admin", "owner"]))])
def reset_orders(db: Session = Depends(get_db)):
    """
    DANGEROUS: Clears all transactional data (Orders, Items, Payments, etc.)
    Resets auto-increment counters.
    """
    try:
        # Delete related transactional tables
        db.execute(text("DELETE FROM order_item_modifiers"))
        db.execute(text("DELETE FROM order_items"))
        db.execute(text("DELETE FROM payments"))
        db.execute(text("DELETE FROM bills"))
        db.execute(text("DELETE FROM kitchen_tickets"))
        db.execute(text("DELETE FROM order_events"))
        db.execute(text("DELETE FROM orders"))
        
        # Reset auto-increment counters in SQLite
        tables_to_reset = [
            'orders', 'order_items', 'payments', 'bills', 
            'kitchen_tickets', 'order_events', 'order_item_modifiers'
        ]
        for table in tables_to_reset:
            try:
                db.execute(text(f"DELETE FROM sqlite_sequence WHERE name='{table}'"))
            except Exception:
                # sqlite_sequence might not exist if NO autoincrement has happened yet
                pass
            
        db.commit()
        print(f"[{datetime.now()}] ADMIN RESET: Transactional data cleared.")
        return {"status": "success", "message": "All orders and transactional data have been reset."}
    except Exception as e:
        db.rollback()
        from fastapi import HTTPException
        raise HTTPException(status_code=500, detail=f"Reset failed: {str(e)}")

@router.get("/system/info")
def get_system_info():
    """Returns server's local IP and status."""
    hostname = socket.gethostname()
    try:
        # This gets the primary LAN IP
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
    except Exception:
        local_ip = socket.gethostbyname(hostname)

    return {
        "hostname": hostname,
        "local_ip": local_ip,
        "port": 8000,
        "api_url": f"http://{local_ip}:8000",
        "ws_url": f"ws://{local_ip}:8000/ws",
        "status": "online",
        "version": "1.0.0"
    }


# --- Role & Permissions Management ---

from backend.models.user import Role, User
from backend.schemas.roles import RoleCreate, RoleUpdate, RoleResponse, VerifyPinRequest

@router.get("/roles", response_model=List[RoleResponse], dependencies=protected)
def list_roles(db: Session = Depends(get_db)):
    return db.query(Role).all()

@router.post("/roles", response_model=RoleResponse, dependencies=protected)
def create_role(role: RoleCreate, db: Session = Depends(get_db)):
    db_role = Role(name=role.name, permissions=role.permissions)
    db.add(db_role)
    db.commit()
    db.refresh(db_role)
    return db_role

@router.put("/roles/{role_id}", response_model=RoleResponse, dependencies=protected)
def update_role(role_id: int, role: RoleUpdate, db: Session = Depends(get_db)):
    db_role = db.query(Role).filter(Role.id == role_id).first()
    if not db_role:
        raise HTTPException(status_code=404, detail="Role not found")
    if role.name:
         db_role.name = role.name
    if role.permissions is not None:
         db_role.permissions = role.permissions
    db.commit()
    db.refresh(db_role)
    return db_role

@router.delete("/roles/{role_id}", dependencies=protected)
def delete_role(role_id: int, db: Session = Depends(get_db)):
    db_role = db.query(Role).filter(Role.id == role_id).first()
    if not db_role:
        raise HTTPException(status_code=404, detail="Role not found")
    db.delete(db_role)
    db.commit()
    return {"status": "success"}

@router.get("/permissions/matrix", dependencies=protected)
def get_permissions_matrix():
    return {
         "can_create_order": "Create New Order",
         "can_edit_order": "Edit Existing Orders",
         "can_delete_order": "Void/Delete Orders",
         "can_print_kot": "Print KOT to Kitchen",
         "can_cancel_kot": "Cancel KOT Items",
         "can_apply_discount": "Apply Basic Discounts",
         "can_apply_large_discount": "Apply Large Discounts (>10%)",
         "can_change_tax": "Modify Tax Rates",
         "can_settle_bill": "Settle & Print Bills",
         "can_view_reports": "View Basic Sales Reports",
         "can_view_insights": "View Advanced Analytics",
         "can_manage_tables": "Edit Table Layout",
         "can_manage_rooms": "Manage Rooms & Bookings",
         "can_manage_users": "Staff & Attendance Management",
         "can_manage_roles": "Edit Roles & Permissions",
         "can_manage_menu": "Update Menu & Pricing",
         "can_manage_crm": "Access Customer Data",
         "can_view_management": "Access Management Dashboard",
         "can_system_settings": "Edit System & Printer Settings",
    }

@router.post("/verify-pin")
def verify_admin_pin(req: VerifyPinRequest, db: Session = Depends(get_db)):
    from fastapi import HTTPException
    admin_user = db.query(User).filter(User.pin == req.pin, User.role.in_(["admin", "manager"])).first()
    if not admin_user:
         user = db.query(User).filter(User.pin == req.pin).first()
         if user and user.permissions and user.permissions.get("can_cancel_kot"):
             return {"status": "success", "user_id": user.id, "name": user.username}
         raise HTTPException(status_code=403, detail="Invalid PIN or insufficient permissions")
    return {"status": "success", "user_id": admin_user.id, "name": admin_user.username}


@router.get("/printers/scan", dependencies=protected)
def scan_printers():
    """Scan and list available system printers (Windows) and potential network printers."""
    printers = []
    
    # 1. System Printers (Windows)
    if win32print:
        try:
            printer_default = win32print.GetDefaultPrinter()
        except:
            printer_default = None
            
        try:
            # Flag 2 = PRINTER_ENUM_LOCAL, 4 = PRINTER_ENUM_CONNECTIONS
            system_printers = win32print.EnumPrinters(2|4)
            for p in system_printers:
                # p is (flags, description, name, comment)
                name = p[2]
                details = p[1]
                
                # Try to determine if it's likely a thermal printer by name/details
                # or if it's a network printer (has \\ in name)
                is_network = name.startswith("\\\\") or "network" in details.lower()
                
                printers.append({
                    "name": name,
                    "type": "network" if is_network else "local",
                    "details": details,
                    "is_default": printer_default == name,
                    "port": 9100 # Default port for network discovery
                })
        except Exception as e:
            print(f"Error enumerating local printers: {e}")
    
    return {
        "status": "success",
        "printers": printers,
        "count": len(printers),
        "platform": "windows" if win32print else "generic"
    }

class RawPrintRequest(BaseModel):
    printer_name: str
    base64_bytes: str

@router.post("/printers/raw-print", dependencies=protected)
async def raw_print(request: RawPrintRequest):
    """Print raw bytes (base64 encoded) to a Windows printer."""
    import base64
    if not win32print:
        raise HTTPException(status_code=500, detail="Printing not supported on this platform")
        
    try:
        raw_data = base64.b64decode(request.base64_bytes)
        hPrinter = win32print.OpenPrinter(request.printer_name)
        try:
            hJob = win32print.StartDocPrinter(hPrinter, 1, ("Servezy Print Job", None, "RAW"))
            try:
                win32print.StartPagePrinter(hPrinter)
                win32print.WritePrinter(hPrinter, raw_data)
                win32print.EndPagePrinter(hPrinter)
            finally:
                win32print.EndDocPrinter(hPrinter)
        finally:
            win32print.ClosePrinter(hPrinter)
            
        return {"status": "success", "message": f"Raw bytes sent to {request.printer_name}"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Print failed: {str(e)}")



@router.post("/printers/test-print", dependencies=protected)
async def test_print(request: Dict[str, str], db: Session = Depends(get_db)):
    """Try to print a test page to a specific printer."""
    printer_name = request.get("printer_name")
    if not printer_name:
        raise HTTPException(status_code=400, detail="printer_name is required")
    
    if not win32print:
        raise HTTPException(status_code=500, detail="Printing not supported on this platform (win32print missing)")
        
    try:
        hPrinter = win32print.OpenPrinter(printer_name)
        try:
            hJob = win32print.StartDocPrinter(hPrinter, 1, ("Servezy Test Print", None, "RAW"))
            try:
                win32print.StartPagePrinter(hPrinter)
                test_text = f"\nSERVEZY POS - TEST PRINT\n"
                test_text += f"--------------------------\n"
                test_text += f"Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n"
                test_text += f"Printer: {printer_name}\n"
                test_text += f"Status: SUCCESS\n"
                test_text += f"--------------------------\n\n\n\n\n"
                win32print.WritePrinter(hPrinter, test_text.encode('utf-8'))
                win32print.EndPagePrinter(hPrinter)
            finally:
                win32print.EndDocPrinter(hPrinter)
        finally:
            win32print.ClosePrinter(hPrinter)
            
        return {"status": "success", "message": f"Test print sent to {printer_name}"}
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Print failed: {str(e)}")
