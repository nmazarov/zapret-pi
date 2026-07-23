@echo off
chcp 65001 >nul
title Zapret Control Panel - Windows
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo [ОШИБКА] Скрипт должен быть запущен от имени АДМИНИСТРАТОРА!
    echo Щелкните правой кнопкой мыши по menu.bat и выберите "Запуск от имени администратора".
    echo.
    pause
    exit /b 1
)

:MENU
cls
echo.
echo ==================================================
echo         ZAPRET DPI BYPASS - ПАНЕЛЬ УПРАВЛЕНИЯ     
echo ==================================================
echo.
echo   1) Автоматический подбор лучшей стратегии (Рекомендуется)
echo   2) Ручной выбор стратегии DPI
echo   3) Диагностика доступности (Discord/YouTube)
echo   4) Управление службой (Статус / Перезапуск)
echo   0) Выход
echo.
set /p choice="   Выберите действие [0-4]: "

if "%choice%"=="1" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0autotest.ps1"
    pause
    goto MENU
)
if "%choice%"=="2" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0strategies.ps1"
    pause
    goto MENU
)
if "%choice%"=="3" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0diagnostic.ps1"
    pause
    goto MENU
)
if "%choice%"=="4" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0service.ps1"
    pause
    goto MENU
)
if "%choice%"=="0" exit /b 0

goto MENU
