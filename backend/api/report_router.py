from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy.orm import Session
from datetime import datetime, date
from backend.database.core import get_db
from backend.services.report_service import ReportService
from backend.utils.csv_generator import CSVGenerator
from backend.utils.pdf_generator import PDFGenerator
from backend.utils.excel_generator import ExcelGenerator

router = APIRouter(prefix="/reports", tags=["Reports"])

@router.get("/summary")
async def get_report_summary(
    start_date: date = Query(...),
    end_date: date = Query(...),
    db: Session = Depends(get_db)
):
    start_dt = datetime.combine(start_date, datetime.min.time())
    end_dt = datetime.combine(end_date, datetime.max.time())
    return ReportService.get_report_data(db, start_dt, end_dt)

@router.get("/export/csv")
async def export_csv(
    start_date: date = Query(...),
    end_date: date = Query(...),
    db: Session = Depends(get_db)
):
    start_dt = datetime.combine(start_date, datetime.min.time())
    end_dt = datetime.combine(end_date, datetime.max.time())
    data = ReportService.get_report_data(db, start_dt, end_dt)
    csv_content = CSVGenerator.generate_sales_csv(data)
    
    filename = f"sales_report_{start_date.strftime('%Y%m%d')}_{end_date.strftime('%Y%m%d')}.csv"
    return Response(
        content=csv_content,
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename={filename}"}
    )

@router.get("/export/pdf")
async def export_pdf(
    start_date: date = Query(...),
    end_date: date = Query(...),
    restaurant_name: str = Query("POS System"),
    orientation: str = Query("portrait"),
    db: Session = Depends(get_db)
):
    start_dt = datetime.combine(start_date, datetime.min.time())
    end_dt = datetime.combine(end_date, datetime.max.time())
    data = ReportService.get_report_data(db, start_dt, end_dt)
    pdf_content = PDFGenerator.generate_sales_pdf(data, start_dt, end_dt, restaurant_name, orientation=orientation)
    
    filename = f"sales_report_{start_date.strftime('%Y%m%d')}_{end_date.strftime('%Y%m%d')}.pdf"
    return Response(
        content=pdf_content,
        media_type="application/pdf",
        headers={"Content-Disposition": f"attachment; filename={filename}"}
    )

@router.get("/export/excel")
async def export_excel(
    start_date: date = Query(...),
    end_date: date = Query(...),
    restaurant_name: str = Query("POS System"),
    db: Session = Depends(get_db)
):
    start_dt = datetime.combine(start_date, datetime.min.time())
    end_dt = datetime.combine(end_date, datetime.max.time())
    data = ReportService.get_report_data(db, start_dt, end_dt)
    excel_content = ExcelGenerator.generate_sales_excel(data, start_dt, end_dt, restaurant_name)
    
    filename = f"sales_report_{start_date.strftime('%Y%m%d')}_{end_date.strftime('%Y%m%d')}.xlsx"
    return Response(
        content=excel_content,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f"attachment; filename={filename}"}
    )
