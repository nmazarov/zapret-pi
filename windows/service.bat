@echo off
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion

:: ═══════════════════════════════════════════════════════════════════════════════
::  ZAPRET для WINDOWS — Управление службой
::  Использование: service.bat [start|stop|restart|status]
:: ═══════════════════════════════════════════════════════════════════════════════

set "ZAPRET_DIR=%~dp0zapret"
set "CONFIG_FILE=%ZAPRET_DIR%\zapret-winws.ini"
set "TASK_NAME=ZapretWinWS"

:: ─── Проверка прав администратора ───────────────────────────────────────────
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo   [ОШИБКА] Этот скрипт нужно запускать от Администратора!
    echo.
    pause
    exit /b 1
)

:: ─── Определяем winws.exe ──────────────────────────────────────────────────
set "WINWS_EXE="
if exist "%ZAPRET_DIR%\bin\winws.exe" (
    set "WINWS_EXE=%ZAPRET_DIR%\bin\winws.exe"
)

if "%WINWS_EXE%"=="" (
    echo   [ОШИБКА] winws.exe не найден! Запустите install.bat
    pause
    exit /b 1
)

:: ─── Читаем ARGS из конфига ────────────────────────────────────────────────
set "WINWS_ARGS="
for /f "tokens=1,* delims==" %%a in ('type "%CONFIG_FILE%" 2^>nul ^| findstr "^ARGS="') do (
    set "WINWS_ARGS=%%b"
)

if "%WINWS_ARGS%"=="" (
    set "WINWS_ARGS=--wf-tcp=80,443 --wf-udp=443 --dpi-desync=fake,fakedsplit --dpi-desync-fooling=md5sig --dpi-desync-split-pos=1,midsld --dpi-desync-split-seqovl=2 --dpi-desync-fake-tls-mod=rnd,rndsni,dupsid --dpi-desync-any-protocol --new --filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=6"
)

:: ─── Разбор команды ─────────────────────────────────────────────────────────
if "%~1"=="" goto :show_menu
if /i "%~1"=="start" goto :do_start
if /i "%~1"=="stop" goto :do_stop
if /i "%~1"=="restart" goto :do_restart
if /i "%~1"=="status" goto :do_status
goto :show_menu

:: ─── Меню ───────────────────────────────────────────────────────────────────
:show_menu
cls
echo.
echo   ╔══════════════════════════════════════════════════════════╗
echo   ║          ZAPRET — УПРАВЛЕНИЕ СЛУЖБОЙ                   ║
echo   ╚══════════════════════════════════════════════════════════╝
echo.
echo   1) ▶️  Запустить (start)
echo   2) ⏹️  Остановить (stop)
echo   3) 🔄 Перезапустить (restart)
echo   4) 📊 Проверить статус (status)
echo   0) ❌ Выход
echo.
set /p "choice=  Выберите действие [0-4]: "

if "%choice%"=="1" goto :do_start
if "%choice%"=="2" goto :do_stop
if "%choice%"=="3" goto :do_restart
if "%choice%"=="4" goto :do_status
if "%choice%"=="0" exit /b 0

echo   [!] Неверный выбор
timeout /t 2 /nobreak >nul
goto :show_menu

:: ─── START ──────────────────────────────────────────────────────────────────
:do_start
echo.
echo   [i] Запуск winws.exe...

:: Проверяем что уже не запущен
tasklist /FI "IMAGENAME eq winws.exe" 2>nul | findstr /I "winws.exe" >nul
if %errorlevel% equ 0 (
    echo   [!] winws.exe уже запущен
    goto :end_action
)

:: Пробуем через планировщик
schtasks /Run /TN "%TASK_NAME%" >nul 2>&1
if %errorlevel% equ 0 (
    echo   [OK] winws.exe запущен через планировщик
) else (
    :: Запускаем напрямую
    start "" /B "%WINWS_EXE%" %WINWS_ARGS%
    echo   [OK] winws.exe запущен
)

timeout /t 2 /nobreak >nul
goto :do_status

:: ─── STOP ───────────────────────────────────────────────────────────────────
:do_stop
echo.
echo   [i] Остановка winws.exe...
taskkill /F /IM winws.exe >nul 2>&1
if %errorlevel% equ 0 (
    echo   [OK] winws.exe остановлен
) else (
    echo   [i] winws.exe не был запущен
)
goto :end_action

:: ─── RESTART ────────────────────────────────────────────────────────────────
:do_restart
echo.
echo   [i] Перезапуск winws.exe...
taskkill /F /IM winws.exe >nul 2>&1
timeout /t 1 /nobreak >nul
start "" /B "%WINWS_EXE%" %WINWS_ARGS%
echo   [OK] winws.exe перезапущен
timeout /t 2 /nobreak >nul
goto :do_status

:: ─── STATUS ─────────────────────────────────────────────────────────────────
:do_status
echo.
echo   ════════════════════════════════════════════════════
echo   СТАТУС ZAPRET (WINDOWS)
echo   ════════════════════════════════════════════════════
echo.

:: Проверка процесса
tasklist /FI "IMAGENAME eq winws.exe" 2>nul | findstr /I "winws.exe" >nul
if %errorlevel% equ 0 (
    echo   [OK] winws.exe: ЗАПУЩЕН
    for /f "tokens=2" %%p in ('tasklist /FI "IMAGENAME eq winws.exe" /NH 2^>nul ^| findstr /I "winws.exe"') do (
        echo   [i]  PID: %%p
    )
) else (
    echo   [!!] winws.exe: НЕ ЗАПУЩЕН
)

:: Проверка автозапуска
schtasks /Query /TN "%TASK_NAME%" >nul 2>&1
if %errorlevel% equ 0 (
    echo   [OK] Автозапуск: НАСТРОЕН
) else (
    echo   [!]  Автозапуск: НЕ НАСТРОЕН
)

:: Текущая стратегия
echo.
echo   Текущая стратегия:
for /f "tokens=1,* delims==" %%a in ('type "%CONFIG_FILE%" 2^>nul ^| findstr "^STRATEGY="') do (
    echo     %%b
)
echo.
echo   Аргументы winws:
echo     %WINWS_ARGS%
echo.
goto :end_action

:: ─── Конец действия ─────────────────────────────────────────────────────────
:end_action
echo.
if "%~1"=="" (
    pause
    goto :show_menu
)
exit /b 0
