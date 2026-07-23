@echo off
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ОШИБКА] Запустите от имени Администратора!
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0strategies.ps1"
pause
