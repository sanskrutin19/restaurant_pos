# -*- mode: python ; coding: utf-8 -*-
# Servezy POS Server — PyInstaller Spec (Production)
# Entry point: main.py (the frozen launcher with safe stdio + log_config=None)
# Run from the repo root:  pyinstaller packaging/pos_server.spec --clean -y
import os

ROOT = os.path.abspath(os.path.join(SPECPATH, '..'))

a = Analysis(
    [os.path.join(ROOT, 'main.py')],
    pathex=[ROOT],
    binaries=[],
    datas=[(os.path.join(ROOT, 'backend'), 'backend')],
    hiddenimports=[
        # Passlib / auth
        'passlib.handlers.bcrypt',
        'passlib.handlers.des_crypt',
        'passlib.handlers.pbkdf2',
        'passlib.handlers.sha2_crypt',
        'passlib.handlers.misc',
        # JOSE (JWT)
        'jose',
        'jose.jwt',
        'jose.jws',
        'jose.backends',
        'jose.backends.cryptography_backend',
        # Uvicorn internals
        'uvicorn.logging',
        'uvicorn.protocols.http.auto',
        'uvicorn.protocols.http.h11_impl',
        'uvicorn.protocols.websockets.auto',
        'uvicorn.protocols.websockets.wsproto_impl',
        'uvicorn.lifespan.on',
        'uvicorn.lifespan.off',
        # Multipart form parsing
        'multipart',
        'python_multipart',
        # Zeroconf (network discovery)
        'zeroconf',
        'zeroconf._utils',
        # Win32 printing
        'win32print',
        'win32api',
        'pywintypes',
        # Multiprocessing
        'multiprocessing',
        # ESC/POS printing
        'escpos',
        'escpos.printer',
        # SQLAlchemy dialects
        'sqlalchemy.dialects.sqlite',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=['torch', 'tensorflow', 'tensorboard', 'cv2', 'openvino', 'numpy.f2py'],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='pos_server',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=[os.path.join(SPECPATH, 'app_icon.ico')],
)
