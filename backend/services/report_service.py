from sqlalchemy.orm import Session
from sqlalchemy import func, and_
from datetime import datetime
from backend.models.order import Order, OrderItem
from backend.models.catalog import MenuItem, MenuCategory
from backend.models.billing import Bill, Payment

class ReportService:
    @staticmethod
    def get_report_data(db: Session, start_date: datetime, end_date: datetime):
        # Ensure end_date includes the entire day
        if end_date.hour == 0 and end_date.minute == 0:
            from datetime import time
            end_date = datetime.combine(end_date.date(), time(23, 59, 59))

        # 1. Summary Metrics (Paid orders only)
        orders_query = db.query(Order).filter(
            and_(
                Order.status == 'Paid',
                Order.created_at >= start_date,
                Order.created_at <= end_date
            )
        )
        
        paid_orders = orders_query.all()
        total_revenue = sum(o.total_amount for o in paid_orders)
        total_orders_count = len(paid_orders)
        
        # Tax and Discount from Bills
        bills = db.query(Bill).join(Order).filter(
            and_(
                Order.status == 'Paid',
                Order.created_at >= start_date,
                Order.created_at <= end_date
            )
        ).all()
        
        total_cgst = sum(b.cgst for b in bills)
        total_sgst = sum(b.sgst for b in bills)
        total_tax = total_cgst + total_sgst
        total_discount = sum(b.discount for b in bills)

        # 2. Item-wise Sales
        item_sales = db.query(
            OrderItem.name,
            func.sum(OrderItem.quantity).label('quantity_sold'),
            func.sum(OrderItem.quantity * OrderItem.price).label('total_revenue')
        ).join(Order).filter(
            and_(
                Order.status == 'Paid',
                Order.created_at >= start_date,
                Order.created_at <= end_date
            )
        ).group_by(OrderItem.name).all()

        # 3. Category-wise Sales
        # Using outer join for MenuCategory to handle items that might not have a category assigned
        category_sales = db.query(
            func.coalesce(MenuCategory.name, "Uncategorized").label('category_name'),
            func.sum(OrderItem.quantity).label('quantity_sold'),
            func.sum(OrderItem.quantity * OrderItem.price).label('total_revenue')
        ).select_from(OrderItem)\
         .join(Order, OrderItem.order_id == Order.id)\
         .outerjoin(MenuItem, OrderItem.item_id == MenuItem.id)\
         .outerjoin(MenuCategory, MenuItem.category_id == MenuCategory.id)\
         .filter(
            and_(
                Order.status == 'Paid',
                Order.created_at >= start_date,
                Order.created_at <= end_date
            )
        ).group_by(func.coalesce(MenuCategory.name, "Uncategorized")).all()

        # 4. Payment Breakdown
        payment_breakdown = db.query(
            Payment.payment_method,
            func.count(Payment.id).label('count'),
            func.sum(Payment.amount).label('total_amount')
        ).join(Order).filter(
            and_(
                Order.status == 'Paid',
                Order.created_at >= start_date,
                Order.created_at <= end_date
            )
        ).group_by(Payment.payment_method).all()

        # 5. Daily Revenue Trend (for Line Chart)
        revenue_trend = db.query(
            func.date(Order.created_at).label('day'),
            func.sum(Order.total_amount).label('revenue')
        ).filter(
            and_(
                Order.status == 'Paid',
                Order.created_at >= start_date,
                Order.created_at <= end_date
            )
        ).group_by(func.date(Order.created_at)).order_by('day').all()

        return {
            "summary": {
                "total_revenue": total_revenue,
                "total_orders": total_orders_count,
                "cgst": total_cgst,
                "sgst": total_sgst,
                "total_tax": total_tax,
                "discount": total_discount
            },
            "orders": [
                {
                    "date": o.created_at.strftime("%d/%m/%Y"),
                    "id": f"ORD-{o.id:04d}",
                    "customer": (o.customer.name if hasattr(o, 'customer') and o.customer else "Walk-in") if hasattr(o, 'customer') else "Walk-in",
                    "items": len(o.items) if hasattr(o, 'items') else 0,
                    "amount": o.total_amount,
                    "payment_mode": o.payment_method or "Cash",
                    "status": "Paid"
                } for o in paid_orders
            ],
            "item_wise": [
                {"item_name": row[0], "quantity_sold": row[1], "total_revenue": row[2]}
                for row in item_sales
            ],
            "category_wise": [
                {"category": row[0], "quantity_sold": row[1], "total_revenue": row[2]}
                for row in category_sales
            ],
            "payment_breakdown": [
                {"mode": row[0], "count": row[1], "total_amount": row[2]}
                for row in payment_breakdown
            ],
            "revenue_trend": [
                {"day": row.day, "revenue": row.revenue}
                for row in revenue_trend
            ]
        }
