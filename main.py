"""
Servezy POS Server — Production Launcher
==========================================
This is the single entry-point for the PyInstaller-bundled EXE.
It must handle the "windowless" (console=False) scenario gracefully.
"""
import sys
import os
import traceback
import multiprocessing

# ─── FREEZE SUPPORT ────────────────────────────────────────────────────────────
# Required on Windows when bundled via PyInstaller with multiprocessing
multiprocessing.freeze_support()

# ─── SAFE STDIO ────────────────────────────────────────────────────────────────
# When running as a frozen windowless EXE (console=False), sys.stdout / stderr
# are set to None. Any library that calls .write() or .isatty() on them will
# crash with "NoneType has no attribute ...". We replace them with devnull.
if getattr(sys, 'frozen', False):
    if sys.stdout is None:
        sys.stdout = open(os.devnull, 'w')
    if sys.stderr is None:
        sys.stderr = open(os.devnull, 'w')

# ─── LOGGING ──────────────────────────────────────────────────────────────
from backend.utils.frozen_logger import log_msg

# ─── MAIN BOOT ─────────────────────────────────────────────────────────────────
try:
    log_msg("=== Servezy Server Starting ===")
    log_msg(f"frozen={getattr(sys, 'frozen', False)}  exe={sys.executable}")
    log_msg(f"cwd={os.getcwd()}")

    log_msg("Importing uvicorn...")
    import uvicorn
    log_msg("Importing backend.main...")
    from backend.main import app
    log_msg("Importing backend.main SUCCESS.")

    log_msg("Modules imported OK. Launching uvicorn on 0.0.0.0:8000 ...")

    if __name__ == "__main__":
        # CRITICAL: log_config=None prevents the isatty() crash in frozen mode
        uvicorn.run(
            app,
            host="0.0.0.0",
            port=8000,
            log_config=None,        # ← disables default logging that crashes
            log_level="warning",    # still get important messages via Python logging
        )

except Exception as e:
    error_info = traceback.format_exc()
    log_msg("CRITICAL ERROR DURING STARTUP:")
    log_msg(error_info)
    # Try to show a message-box so the user knows something went wrong
    try:
        from backend.utils.frozen_logger import get_log_path
        import ctypes
        log_path = get_log_path()
        ctypes.windll.user32.MessageBoxW(
            0,
            f"Servezy Server failed to start.\n\n{e}\n\nFull log location:\n{log_path}",
            "Servezy Server Error",
            0x10,  # MB_ICONERROR
        )
    except Exception:
        pass
    sys.exit(1)
