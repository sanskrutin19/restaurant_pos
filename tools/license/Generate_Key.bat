@echo off
:: Run from the repo root so the backend package is importable
cd /d "%~dp0..\.."
python -m tools.license.key_generator
pause
