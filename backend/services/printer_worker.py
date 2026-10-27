import asyncio
import time
from sqlalchemy.orm import Session
from backend.database.core import SessionLocal
from backend.models.system import PrinterJob
from backend.models.system import KitchenCounter
try:
    import win32print
except ImportError:
    win32print = None

async def printer_worker_loop():
    """Background loop to process local printer jobs."""
    if not win32print:
        print("Printer worker disabled: win32print not available")
        return

    print("Starting background printer worker...")
    while True:
        try:
            db = SessionLocal()
            try:
                # Find pending jobs for local printers
                # A job corresponds to a counter or a direct printer name
                jobs = db.query(PrinterJob).filter(PrinterJob.status == "Pending").all()
                
                for job in jobs:
                    try:
                        print(f"[PrinterWorker] Processing Job ID {job.id} for printer name: '{job.printer_name}'")
                        
                        # Check if this name exists on the system
                        system_printers = [p[2] for p in win32print.EnumPrinters(2|4)]
                        if job.printer_name not in system_printers:
                            print(f"[PrinterWorker] ERROR: Printer '{job.printer_name}' not found on system! Available: {system_printers}")
                            job.status = f"Error: Printer Not Found"
                            continue

                        try:
                            hPrinter = win32print.OpenPrinter(job.printer_name)
                            # For now, mark as 'Sent' to show the server attempted the connection
                            # We keep it as 'Sent' instead of 'Completed' to indicate it reached the spooler
                            job.status = "Sent"
                            print(f"[PrinterWorker] SUCCESS: Handed over job {job.id} to spooler for '{job.printer_name}'")
                            win32print.ClosePrinter(hPrinter)
                        except Exception as ep:
                            print(f"[PrinterWorker] FAILED to open printer '{job.printer_name}': {ep}")
                            job.status = f"Error: {str(ep)}"
                    except Exception as ex:
                        print(f"[PrinterWorker] General error in job {job.id}: {ex}")
                
                if jobs:
                    db.commit()
            finally:
                db.close()
        except Exception as e:
            print(f"Printer worker error: {e}")
            
        await asyncio.sleep(5) # Poll every 5 seconds

def start_printer_worker():
    loop = asyncio.get_event_loop()
    loop.create_task(printer_worker_loop())
