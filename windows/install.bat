@echo off
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion

:: ═══════════════════════════════════════════════════════════════════════════════
::  ZAPRET для WINDOWS — Автоматический установщик
::  Обход DPI-блокировок на Windows (локально)
::  github.com/nmazarov/zapret-pi
:: ═══════════════════════════════════════════════════════════════════════════════

set "ZAPRET_DIR=%~dp0zapret"
set "ZAPRET_REPO=https://github.com/Flowseal/zapret-discord-youtube.git"
set "WINWS_EXE=%ZAPRET_DIR%\bin\winws.exe"
set "CONFIG_FILE=%ZAPRET_DIR%\zapret-winws.ini"
set "TASK_NAME=ZapretWinWS"
set "VERSION=1.0"

:: ─── Проверка прав администратора ───────────────────────────────────────────
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo   [ОШИБКА] Этот скрипт нужно запускать от Администратора!
    echo.
    echo   Нажмите правой кнопкой мыши на файл и выберите
    echo   "Запуск от имени администратора"
    echo.
    pause
    exit /b 1
)

:: ─── Баннер ─────────────────────────────────────────────────────────────────
cls
echo.
echo   ╔══════════════════════════════════════════════════════════╗
echo   ║          🛡️ ZAPRET-PI WINDOWS EDITION v%VERSION%            ║
echo   ║          Автоматический обход DPI для Windows            ║
echo   ╚══════════════════════════════════════════════════════════╝
echo.
echo   github.com/nmazarov/zapret-pi
echo.

:: ═══════════════════════════════════════════════════════════════════════════════
::  ШАГ 1: ПРОВЕРКА ЗАВИСИМОСТЕЙ
:: ═══════════════════════════════════════════════════════════════════════════════

echo   ━━━ Шаг 1/5 — Проверка системы ━━━
echo.

:: Проверка архитектуры
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    echo   [OK] Архитектура: x64
    set "ARCH=win64"
) else if "%PROCESSOR_ARCHITECTURE%"=="x86" (
    echo   [OK] Архитектура: x86
    set "ARCH=win32"
) else (
    echo   [ОШИБКА] Неподдерживаемая архитектура: %PROCESSOR_ARCHITECTURE%
    pause
    exit /b 1
)

:: Git и curl больше не требуются, так как Zapret поставляется вместе с проектом

echo.

:: ═══════════════════════════════════════════════════════════════════════════════
::  ШАГ 2: СКАЧИВАНИЕ ZAPRET
:: ═══════════════════════════════════════════════════════════════════════════════

echo   ━━━ Шаг 2/5 — Загрузка Zapret ━━━
echo.

if not exist "%ZAPRET_DIR%\bin\winws.exe" (
    echo   [ОШИБКА] Файлы Zapret не найдены в папке %ZAPRET_DIR%
    echo   Убедитесь, что вы скачали архив целиком вместе с папкой zapret.
    pause
    exit /b 1
)

echo   [OK] Встроенный Zapret найден локально

echo.

:: ═══════════════════════════════════════════════════════════════════════════════
::  ШАГ 2.5: СКАЧИВАНИЕ СПИСКОВ FLOWSEAL
:: ═══════════════════════════════════════════════════════════════════════════════
echo   ━━━ Шаг 2.5 — Подготовка списков Flowseal ━━━
echo.
set "LISTS_DIR=%ZAPRET_DIR%\lists"
if not exist "%LISTS_DIR%" mkdir "%LISTS_DIR%"

:: Копирование payload-файлов туда, где их ждет strategies.bat
set "BIN_DIR=%ZAPRET_DIR%\files\fake"
if not exist "%BIN_DIR%" mkdir "%BIN_DIR%"
if exist "%ZAPRET_DIR%\bin\*.bin" xcopy "%ZAPRET_DIR%\bin\*.bin" "%BIN_DIR%\" /y /q >nul

:: Создаем пустые user-листы, чтобы winws не ругался
echo. > "%LISTS_DIR%\list-general-user.txt"
echo. > "%LISTS_DIR%\list-exclude-user.txt"
echo. > "%LISTS_DIR%\ipset-exclude-user.txt"

echo   [OK] Списки Flowseal успешно скачаны

echo.

:: ═══════════════════════════════════════════════════════════════════════════════
::  ШАГ 3: ПРОВЕРКА winws.exe
:: ═══════════════════════════════════════════════════════════════════════════════

echo   ━━━ Шаг 3/5 — Проверка winws.exe ━━━
echo.

if exist "%ZAPRET_DIR%\bin\winws.exe" (
    echo   [OK] winws.exe найден: !WINWS_EXE!
) else (
    echo   [ОШИБКА] winws.exe не найден!
    echo   Проверьте что zapret скачался корректно.
    echo   Путь: %ZAPRET_DIR%\bin\
    dir "%ZAPRET_DIR%\bin\" /s 2>nul | findstr "winws"
    pause
    exit /b 1
)

:: Проверка WinDivert
if exist "%ZAPRET_DIR%\bin\WinDivert.dll" (
    echo   [OK] WinDivert.dll найден
) else (
    echo   [ВНИМАНИЕ] WinDivert.dll не найден — winws может не работать
)

echo.

:: ═══════════════════════════════════════════════════════════════════════════════
::  ШАГ 4: КОНФИГУРАЦИЯ
:: ═══════════════════════════════════════════════════════════════════════════════

echo   ━━━ Шаг 4/5 — Настройка конфигурации ━━━
echo.

:: Создаём файл конфигурации с дефолтной стратегией
if not exist "%CONFIG_FILE%" (
    (
        echo # Конфигурация Zapret для Windows
        echo # Создано: %date% %time%
        echo #
        echo # Стратегия DPI bypass (аргументы для winws.exe^)
        echo # Смените стратегию через strategies.bat или отредактируйте вручную
        echo #
        echo STRATEGY=universal_md5sig
        echo ARGS=--wf-tcp=80,443 --wf-udp=443 --dpi-desync=fake,fakedsplit --dpi-desync-fooling=md5sig --dpi-desync-split-pos=1,midsld --dpi-desync-split-seqovl=2 --dpi-desync-fake-tls-mod=rnd,rndsni,dupsid --dpi-desync-any-protocol --new --filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=6
    ) > "%CONFIG_FILE%"
    echo   [OK] Конфигурация создана: %CONFIG_FILE%
) else (
    echo   [OK] Конфигурация уже существует
)

echo.

:: ═══════════════════════════════════════════════════════════════════════════════
::  ШАГ 5: АВТОЗАПУСК (TASK SCHEDULER)
:: ═══════════════════════════════════════════════════════════════════════════════

echo   ━━━ Шаг 5/5 — Настройка автозапуска ━━━
echo.

:: Удаляем старую задачу если есть
schtasks /Query /TN "%TASK_NAME%" >nul 2>&1
if %errorlevel% equ 0 (
    echo   [i] Удаление старой задачи автозапуска...
    schtasks /Delete /TN "%TASK_NAME%" /F >nul 2>&1
)

:: Читаем ARGS из конфига
set "WINWS_ARGS="
for /f "tokens=1,* delims==" %%a in ('type "%CONFIG_FILE%" 2^>nul ^| findstr "^ARGS="') do (
    set "WINWS_ARGS=%%b"
)

if "!WINWS_ARGS!"=="" (
    set "WINWS_ARGS=--wf-tcp=80,443 --wf-udp=443 --dpi-desync=fake,fakedsplit --dpi-desync-fooling=md5sig --dpi-desync-split-pos=1,midsld --dpi-desync-split-seqovl=2 --dpi-desync-fake-tls-mod=rnd,rndsni,dupsid --dpi-desync-any-protocol --new --filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=6"
)

:: Создаём задачу в планировщике (запуск при входе, от SYSTEM)
schtasks /Create /TN "%TASK_NAME%" /TR "\"!WINWS_EXE!\" !WINWS_ARGS!" /SC ONLOGON /RL HIGHEST /RU SYSTEM /F >nul 2>&1
if %errorlevel% equ 0 (
    echo   [OK] Задача автозапуска создана: %TASK_NAME%
) else (
    echo   [!] Не удалось создать задачу автозапуска
    echo       Вы можете запускать winws вручную через service.bat
)

:: Запускаем winws прямо сейчас
echo.
echo   [i] Запуск winws.exe...

:: Убиваем старый процесс если есть
taskkill /F /IM winws.exe >nul 2>&1

:: Запускаем задачу
schtasks /Run /TN "%TASK_NAME%" >nul 2>&1
if %errorlevel% equ 0 (
    echo   [OK] winws.exe запущен
) else (
    echo   [!] Не удалось запустить через планировщик, запускаем напрямую...
    start "" /B "!WINWS_EXE!" !WINWS_ARGS!
    echo   [OK] winws.exe запущен
)

:: Проверяем что процесс работает
timeout /t 2 /nobreak >nul
tasklist /FI "IMAGENAME eq winws.exe" 2>nul | findstr /I "winws.exe" >nul
if %errorlevel% equ 0 (
    echo   [OK] winws.exe процесс активен
) else (
    echo   [!] winws.exe не обнаружен. Проверьте логи.
)

echo.

:: ═══════════════════════════════════════════════════════════════════════════════
::  ФИНАЛЬНАЯ СВОДКА
:: ═══════════════════════════════════════════════════════════════════════════════

echo.
echo   ╔══════════════════════════════════════════════════════════╗
echo   ║                                                        ║
echo   ║       ✅  УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО!                 ║
echo   ║                                                        ║
echo   ╚══════════════════════════════════════════════════════════╝
echo.
echo   ┌──────────────────────────────────────────────────────┐
echo   │                                                      │
echo   │  Zapret (winws.exe) работает на этом компьютере      │
echo   │  Обход DPI активен для всех подключений              │
echo   │                                                      │
echo   │  winws.exe будет запускаться автоматически            │
echo   │  при каждом входе в Windows                          │
echo   │                                                      │
echo   └──────────────────────────────────────────────────────┘
echo.
echo   Полезные команды:
echo     menu.bat               — интерактивное меню управления (РЕКОМЕНДУЕТСЯ)
echo     service.bat start      — запустить winws
echo     service.bat stop       — остановить winws
echo     service.bat status     — проверить статус
echo     strategies.bat         — сменить стратегию DPI bypass
echo     uninstall.bat          — полное удаление
echo.
echo   Папка установки: %ZAPRET_DIR%
echo   Конфигурация:    %CONFIG_FILE%
echo.

pause
exit /b 0
