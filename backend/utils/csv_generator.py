import csv
import io

class CSVGenerator:
    @staticmethod
    def generate_sales_csv(data: dict):
        output = io.StringIO()
        writer = csv.writer(output)

        # 1. Summary
        writer.writerow(["SALES REPORT - EXECUTIVE SUMMARY"])
        writer.writerow(["Metric", "Value"])
        s = data['summary']
        writer.writerow(["Total Revenue", s['total_revenue']])
        writer.writerow(["Total Orders", s['total_orders']])
        writer.writerow(["Total Tax", s['total_tax']])
        writer.writerow(["CGST", s['cgst']])
        writer.writerow(["SGST", s['sgst']])
        writer.writerow(["Total Discount", s['discount']])
        writer.writerow([])

        # 2. Daily Trends
        writer.writerow(["DAILY REVENUE TREND"])
        writer.writerow(["Date", "Revenue"])
        for row in data['revenue_trend']:
            writer.writerow([row['day'], row['revenue']])
        writer.writerow([])

        # 3. Category Sales
        writer.writerow(["CATEGORY-WISE SALES"])
        writer.writerow(["Category", "Qty Sold", "Total Revenue"])
        for row in data['category_wise']:
            writer.writerow([row['category'], row['quantity_sold'], row['total_revenue']])
        writer.writerow([])

        # 4. Item-wise Sales
        writer.writerow(["ITEM-WISE SALES"])
        writer.writerow(["Item Name", "Qty Sold", "Total Revenue"])
        for row in data['item_wise']:
            writer.writerow([row['item_name'], row['quantity_sold'], row['total_revenue']])
        writer.writerow([])

        # 5. Orders History
        writer.writerow(["ORDERS HISTORY"])
        writer.writerow(["Date", "Order ID", "Customer", "Items", "Amount", "Payment", "Status"])
        for o in data['orders']:
            writer.writerow([o['date'], o['id'], o['customer'], o['items'], o['amount'], o['payment_mode'], o['status']])

        return output.getvalue().encode('utf-8')
