import os
import sys
from datetime import datetime

def get_log_path():
    app_data_dir = os.path.join(os.environ.get('APPDATA', os.getcwd()), "Servezy")
    os.makedirs(app_data_dir, exist_ok=True)
    return os.path.join(app_data_dir, "server_debug_log.txt")

def log_msg(msg: str):
    try:
        log_path = get_log_path()
        with open(log_path, "a", encoding="utf-8") as f:
            f.write(f"[{datetime.now().isoformat()}] {msg}\n")
    except Exception:
        pass
