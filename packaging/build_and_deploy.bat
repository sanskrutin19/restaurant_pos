@echo off
setlocal enabledelayedexpansion

:: Always run from the repo root (this script lives in packaging\)
cd /d "%~dp0.."

echo 🚀 STARTING FULL PRODUCTION BUILD AND DEPLOYMENT...

cd frontend\app

:: 1. BUILD WINDOWS TERMINAL
echo [1/3] Building Flutter Windows (Terminal)...
call flutter build windows --release
if %ERRORLEVEL% neq 0 (
    echo ❌ Flutter Windows build failed!
    exit /b %ERRORLEVEL%
)

:: 2. BUILD WEB GUEST MENU
echo [2/3] Building Flutter Web (Guest Menu)...
call flutter build web --release
if %ERRORLEVEL% neq 0 (
    echo ❌ Flutter Web build failed!
    exit /b %ERRORLEVEL%
)

cd ..\..

:: 3. BUILD BACKEND EXE
echo [3/3] Building Python Backend (pos_server.exe)...
call .venv\Scripts\activate
pip install -r requirements.txt
pyinstaller packaging\pos_server.spec --clean -y
if %ERRORLEVEL% neq 0 (
    echo ❌ PyInstaller build failed!
    exit /b %ERRORLEVEL%
)

:: 4. DEPLOYMENT SYNC
echo 📂 SYNCING FILES TO DEPLOY DIRECTORY...

:: Clear old files
rmdir /s /q DEPLOY\POS_Terminal 2>nul
mkdir DEPLOY\POS_Terminal
rmdir /s /q DEPLOY\Server_Backend\frontend 2>nul
mkdir DEPLOY\Server_Backend\frontend

:: Copy Windows Build (Terminal)
echo - Copying Terminal...
xcopy /E /I /Y frontend\app\build\windows\x64\runner\Release\* DEPLOY\POS_Terminal\
if not exist "DEPLOY\POS_Terminal\app.exe" (
    echo ⚠️ app.exe not found in DEPLOY\POS_Terminal. Checking for other executables...
    dir /b DEPLOY\POS_Terminal\*.exe
)

:: Copy Web Build (Guest Menu)
echo - Copying Guest Menu...
xcopy /E /I /Y frontend\app\build\web\* DEPLOY\Server_Backend\frontend\

:: Copy Server EXE
echo - Copying Server EXE...
copy /Y dist\pos_server.exe DEPLOY\Server_Backend\

echo ✅ BUILD AND DEPLOY SYNC COMPLETE.
echo Now open 'packaging\servezy_installer.iss' in Inno Setup and press F9 to compile the final installer.
