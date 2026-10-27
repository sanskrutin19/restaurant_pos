from fastapi import APIRouter, Depends, HTTPException, Query
from backend.security.auth import get_current_user, get_current_user_optional
from sqlalchemy.orm import Session
from backend.database.core import get_db
from backend.models.system import PrinterJob
from backend.schemas.billing import BillResponse, PrintJobRequest, PrintJobResponse
from backend.services import billing as billing_service
from backend.commands.core import command_bus
from backend.schemas.commands import PrintBillCommand

router = APIRouter(prefix="/billing", tags=["Billing"])


@router.post("/{order_id}/generate", response_model=BillResponse)
def generate_bill(
    order_id: int,
    tax_rate: float = Query(5.0, description="Combined GST rate %"),
    discount: float = Query(0.0, description="Discount amount (already calculated)"),
    discount_type: str = Query("flat", description="flat or percentage"),
    discount_value: float = Query(0.0, description="Original discount input value"),
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user_optional),
):
    try:
        bill = billing_service.generate_bill(
            db,
            order_id,
            tax_rate=tax_rate,
            discount=discount,
            discount_type=discount_type,
            discount_value=discount_value,
        )
        return bill
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.post("/{order_id}/print", response_model=PrintJobResponse)
async def print_bill(order_id: int, db: Session = Depends(get_db)):
    """Send bill to printer."""
    cmd = PrintBillCommand(order_id=order_id, printer_name="Default")
    try:
        job = await command_bus.dispatch(cmd, db)
        return job
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/printer-jobs", response_model=list[PrintJobResponse])
def get_pending_printer_jobs(db: Session = Depends(get_db)):
    """Fetch pending printer jobs for the 'downloader' agent."""
    jobs = db.query(PrinterJob).filter(PrinterJob.status == "Pending").all()
    return jobs


@router.post("/printer-jobs/{job_id}/complete")
def complete_printer_job(job_id: int, db: Session = Depends(get_db)):
    """Mark a printer job as completed."""
    job = db.query(PrinterJob).filter(PrinterJob.id == job_id).first()
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    
    job.status = "Completed"
    db.commit()
    return {"status": "success"}
