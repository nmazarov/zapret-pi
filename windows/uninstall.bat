@echo off
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion

:: ═══════════════════════════════════════════════════════════════════════════════
::  ZAPRET для WINDOWS — Деинсталлятор
::  Полностью удаляет все компоненты zapret
:: ═══════════════════════════════════════════════════════════════════════════════

set "ZAPRET_DIR=%~dp0zapret"
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

cls
echo.
echo   ╔══════════════════════════════════════════════════════════╗
echo   ║                                                        ║
echo   ║          🗑️  УДАЛЕНИЕ ZAPRET (WINDOWS)                 ║
echo   ║                                                        ║
echo   ╚══════════════════════════════════════════════════════════╝
echo.
echo   Будут удалены:
echo     • Процесс winws.exe
echo     • Задача автозапуска: %TASK_NAME%
echo     • Папка: %ZAPRET_DIR%
echo.

set /p "confirm=  Продолжить удаление? [y/N]: "
if /i not "%confirm%"=="y" (
    echo.
    echo   Отменено.
    echo.
    pause
    exit /b 0
)

echo.

:: ─── 1. Остановка winws.exe ────────────────────────────────────────────────
echo   [i] Остановка winws.exe...
taskkill /F /IM winws.exe >nul 2>&1
if %errorlevel% equ 0 (
    echo   [OK] winws.exe остановлен
) else (
    echo   [i] winws.exe не был запущен
)

:: ─── 2. Удаление задачи автозапуска ─────────────────────────────────────────
echo   [i] Удаление задачи автозапуска...
schtasks /Query /TN "%TASK_NAME%" >nul 2>&1
if %errorlevel% equ 0 (
    schtasks /Delete /TN "%TASK_NAME%" /F >nul 2>&1
    echo   [OK] Задача автозапуска удалена
) else (
    echo   [i] Задача автозапуска не найдена
)

:: ─── 3. Удаление файлов ────────────────────────────────────────────────────
echo.
if exist "%ZAPRET_DIR%" (
    set /p "del_files=  Удалить папку %ZAPRET_DIR%? [y/N]: "
    if /i "!del_files!"=="y" (
        :: Снимаем атрибут "только для чтения" со всех файлов
        attrib -r -h "%ZAPRET_DIR%\*.*" /s /d >nul 2>&1
        rmdir /s /q "%ZAPRET_DIR%" 2>nul
        if exist "%ZAPRET_DIR%" (
            echo   [!] Не удалось удалить некоторые файлы.
            echo       Попробуйте перезагрузить компьютер и удалить вручную:
            echo       %ZAPRET_DIR%
        ) else (
            echo   [OK] Папка %ZAPRET_DIR% удалена
        )
    ) else (
        echo   [i] Папка %ZAPRET_DIR% оставлена
    )
) else (
    echo   [i] Папка %ZAPRET_DIR% не найдена
)

:: ─── Итог ───────────────────────────────────────────────────────────────────
echo.
echo   ╔══════════════════════════════════════════════════════════╗
echo   ║                                                        ║
echo   ║        ✅  ZAPRET ПОЛНОСТЬЮ УДАЛЁН                     ║
echo   ║                                                        ║
echo   ╚══════════════════════════════════════════════════════════╝
echo.
echo   Обход DPI отключён. Интернет работает напрямую.
echo.

pause
exit /b 0
