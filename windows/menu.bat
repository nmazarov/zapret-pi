@echo off
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion

:: Проверка прав администратора
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo   [ОШИБКА] Этот скрипт нужно запускать от Администратора!
    echo.
    pause
    exit /b 1
)

set "SCRIPT_DIR=%~dp0"

:show_menu
cls
echo.
echo   ╔══════════════════════════════════════════════════════════╗
echo   ║                ZAPRET-PI WINDOWS МЕНЮ                    ║
echo   ╚══════════════════════════════════════════════════════════╝
echo.
echo   1) 🟢 Показать статус службы (zapret)
echo   2) ▶️  Запустить службу
echo   3) ⏹️  Остановить службу
echo   4) 🔄 Перезапустить службу
echo   5) ⚙️  Сменить стратегию DPI Bypass
echo   6) 🗑️  Полное удаление проекта
echo   0) ❌ Выход
echo.
set /p "choice=  Выберите действие [0-6]: "

echo.

if "%choice%"=="1" (
    call "%SCRIPT_DIR%service.bat" status
    pause
    goto :show_menu
)
if "%choice%"=="2" (
    call "%SCRIPT_DIR%service.bat" start
    pause
    goto :show_menu
)
if "%choice%"=="3" (
    call "%SCRIPT_DIR%service.bat" stop
    pause
    goto :show_menu
)
if "%choice%"=="4" (
    call "%SCRIPT_DIR%service.bat" restart
    pause
    goto :show_menu
)
if "%choice%"=="5" (
    call "%SCRIPT_DIR%strategies.bat"
    goto :show_menu
)
if "%choice%"=="6" (
    echo   [!] Внимание: будет произведено полное удаление проекта.
    set /p "del_confirm=  Вы уверены? (y/N): "
    if /I "!del_confirm!"=="y" (
        call "%SCRIPT_DIR%uninstall.bat"
        pause
        exit /b 0
    ) else (
        goto :show_menu
    )
)
if "%choice%"=="0" (
    exit /b 0
)

echo   [!] Неверный выбор
timeout /t 2 /nobreak >nul
goto :show_menu
