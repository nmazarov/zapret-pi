@echo off
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ОШИБКА] Запустите от имени Администратора!
    pause
    exit /b 1
)

echo [i] Остановка и удаление процесса winws...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0service.ps1" stop
pause
