from fastapi import FastAPI, Request, Depends
from sqlalchemy.orm import Session
from backend.database.core import get_db
from fastapi.staticfiles import StaticFiles
import os
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware

from backend.utils.frozen_logger import log_msg
log_msg("backend.main: Imports starting...")

from backend.database.core import engine, Base
log_msg("backend.main: Database engine loaded.")

# Import all models to ensure they are registered with Base
from backend.models import order, catalog, billing, user, customer, attendance, system, inventory
from backend.models import offers
from backend.models import kot, room  # New models for KOT tracking and rooms
log_msg("backend.main: Models imported.")

from backend.api import websockets
import backend.commands.order_handlers
import backend.commands.loyalty_handlers
import backend.commands.staff_handlers
log_msg("backend.main: API and Handlers imported.")

# Create all tables
log_msg("backend.main: Creating tables...")
Base.metadata.create_all(bind=engine)
log_msg("backend.main: Tables created.")

# Seed initial data if DB is empty
from backend.services.seeder import seed_initial_data
from backend.database.core import SessionLocal
log_msg("backend.main: Seeding data if needed...")
db = SessionLocal()
try:
    seed_initial_data(db)
finally:
    db.close()
log_msg("backend.main: Seeding finished.")

app = FastAPI(
    title="Servezy POS Offline API",
    description="Professional local-first offline Restaurant Operating System",
    version="1.0.0"
)

@app.on_event("startup")
async def startup_event():
    from backend.services.discovery import discovery_manager
    discovery_manager.start()
    
    from backend.services.printer_worker import start_printer_worker
    start_printer_worker()

@app.on_event("shutdown")
def shutdown_event():
    from backend.services.discovery import discovery_manager
    discovery_manager.stop()

# ─── ERROR LOGGING MIDDLEWARE ───────────────────────────────────────────────
@app.middleware("http")
async def error_logging_middleware(request: Request, call_next):
    import time
    start_time = time.time()
    try:
        response = await call_next(request)
        if response.status_code >= 400:
            # We don't have the response body easily here, but we know it failed
            log_msg(f"API ERROR {response.status_code}: {request.method} {request.url.path}")
        return response
    except Exception as e:
        import traceback
        error_trace = traceback.format_exc()
        log_msg(f"CRITICAL API EXCEPTION: {request.method} {request.url.path}\n{error_trace}")
        return JSONResponse(
            status_code=500,
            content={"message": "Internal Server Error", "detail": str(e)}
        )

# ─── LICENSE SYSTEM ENFORCEMENT ─────────────────────────────────────────────
from backend.services.license import license_manager
from backend.models.system import SystemSettings

@app.middleware("http")
async def license_check_middleware(request: Request, call_next):
    # Allow license and static/root routes always
    allowed_paths = ["/admin/license", "/docs", "/openapi.json", "/"]
    if any(request.url.path.startswith(p) for p in allowed_paths):
        return await call_next(request)

    # Check activation status in DB
    db = SessionLocal()
    try:
        active_key = db.query(SystemSettings).filter(SystemSettings.key == "license_key").first()
        machine_id = license_manager.get_machine_id()
        
        is_valid = False
        if active_key and active_key.value:
            is_valid = license_manager.verify_key(machine_id, active_key.value)
        
        if not is_valid:
            return JSONResponse(
                status_code=402, # Payment Required
                content={"status": "error", "code": "LICENSE_REQUIRED", "machine_id": machine_id}
            )
    finally:
        db.close()
        
    return await call_next(request)

# License Endpoints
@app.get("/admin/license/status")
def get_license_status(db: Session = Depends(get_db)):
    machine_id = license_manager.get_machine_id()
    active_key = db.query(SystemSettings).filter(SystemSettings.key == "license_key").first()
    
    is_active = False
    if active_key and active_key.value:
        is_active = license_manager.verify_key(machine_id, active_key.value)
        
    return {
        "machine_id": machine_id,
        "is_active": is_active,
        "key_preview": f"{active_key.value[:4]}****" if active_key and active_key.value else None
    }

@app.post("/admin/license/activate")
async def activate_license(data: dict, db: Session = Depends(get_db)):
    key = data.get("key", "").strip()
    machine_id = license_manager.get_machine_id()
    
    if license_manager.verify_key(machine_id, key):
        # Save to DB
        setting = db.query(SystemSettings).filter(SystemSettings.key == "license_key").first()
        if not setting:
            setting = SystemSettings(key="license_key", value=key)
            db.add(setting)
        else:
            setting.value = key
        db.commit()
        return {"status": "success", "message": "License activated successfully!"}
    else:
        return JSONResponse(status_code=400, content={"status": "error", "message": "Invalid license key for this machine."})

@app.exception_handler(ValueError)
async def value_error_exception_handler(request: Request, exc: ValueError):
    return JSONResponse(
        status_code=400,
        content={"status": "error", "detail": str(exc)},
    )

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    print(f"\nVALIDATION ERROR on {request.method} {request.url.path}:")
    print(exc.errors())
    return JSONResponse(
        status_code=400,
        content={"status": "error", "detail": exc.errors()},
    )

@app.exception_handler(Exception)
async def generic_exception_handler(request: Request, exc: Exception):
    import traceback
    print(f"\n{'='*60}")
    print(f"UNHANDLED ERROR on {request.method} {request.url.path}")
    traceback.print_exc()
    print(f"{'='*60}\n")
    return JSONResponse(
        status_code=500,
        content={"status": "error", "detail": str(exc)},
    )

# Crucial for local network access — must be before routers
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
from backend.api.menu_router import router as menu_router
from backend.api.order_router import router as order_router
from backend.api.kitchen_router import router as kitchen_router
from backend.api.billing_router import router as billing_router
from backend.api.payment_router import router as payment_router
from backend.api.auth_router import router as auth_router
from backend.api.loyalty_router import router as loyalty_router
from backend.api.qr_router import router as qr_router
from backend.api.staff_router import router as staff_router
# from backend.api.inventory_router import router as inventory_router  # Disabled (#7)
from backend.api.room_router import router as room_router
from backend.api.offers_router import router as offers_router
from backend.api.admin_router import router as admin_router
from backend.api.report_router import router as report_router


app.include_router(menu_router)
app.include_router(order_router)
app.include_router(kitchen_router)
app.include_router(billing_router)
app.include_router(payment_router)
app.include_router(auth_router)
app.include_router(loyalty_router)
app.include_router(qr_router)
app.include_router(staff_router)
# app.include_router(inventory_router)  # Disabled (#7)
app.include_router(room_router)
app.include_router(offers_router)
app.include_router(admin_router)
app.include_router(report_router)




from sqlalchemy.orm import Session
from backend.models.system import AuditLog
from backend.database.core import get_db
from fastapi import Depends

@app.get("/admin/audit-logs")
def get_audit_logs(entity: str = None, limit: int = 200, db: Session = Depends(get_db)):
    query = db.query(AuditLog)
    if entity:
        query = query.filter(AuditLog.entity == entity.lower())
    return query.order_by(AuditLog.created_at.desc()).limit(limit).all()

# Register WebSockets
@app.websocket("/ws")
async def websocket_endpoint(websocket: websockets.WebSocket):
    await websockets.manager.connect(websocket)
    try:
        while True:
            data = await websocket.receive_text()
    except Exception as e:
        websockets.manager.disconnect(websocket)

# Serve Flutter Web build for Guest Menu
import sys
if getattr(sys, 'frozen', False):
    # 1. Look in the temp bundle directory (sys._MEIPASS)
    # 2. Look relative to the EXE (sys.executable) for external assets
    bundle_root = sys._MEIPASS
    install_root = os.path.dirname(sys.executable)
else:
    # Running from source
    current_file_dir = os.path.dirname(os.path.abspath(__file__))
    bundle_root = os.path.dirname(current_file_dir)
    install_root = bundle_root

possible_web_dirs = [
    os.path.join(bundle_root, "frontend"), # Bundled
    os.path.join(install_root, "frontend"), # External (installed via Inno)
    os.path.join(install_root, "web"),      # Alternative external
    os.path.join(bundle_root, "frontend", "app", "build", "web"), # Dev path
]
web_dir = next((d for d in possible_web_dirs if os.path.exists(d)), None)

if web_dir:
    # Mount web app BEFORE the catch-all but AFTER other API routes
    app.mount("/", StaticFiles(directory=web_dir, html=True), name="web")
else:
    # If no web build, provide a simple status at root
    @app.get("/")
    def read_root():
        return {"status": "online", "system": "Restaurant POS", "info": "Guest Menu web build not found. Run 'flutter build web' in frontend/app"}

if __name__ == "__main__":
    import uvicorn
    # Use 0.0.0.0 to allow access from local network
    # log_config=None is CRITICAL for frozen (PyInstaller) mode
    uvicorn.run(app, host="0.0.0.0", port=8000, log_config=None, log_level="warning")