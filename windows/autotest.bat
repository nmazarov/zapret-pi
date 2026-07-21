@echo off
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion

:: ─── Проверка прав администратора ───────────────────────────────────────────
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo   [ОШИБКА] Этот скрипт нужно запускать от Администратора!
    echo.
    pause
    exit /b 1
)

set "SCRIPT_DIR=%~dp0"
set "ZAPRET_DIR=%~dp0zapret"
set "CONFIG_FILE=%ZAPRET_DIR%\zapret-winws.ini"
set "WINWS_EXE="
if exist "%ZAPRET_DIR%\binaries\win64\winws.exe" set "WINWS_EXE=%ZAPRET_DIR%\binaries\win64\winws.exe"
if exist "%ZAPRET_DIR%\binaries\win32\winws.exe" set "WINWS_EXE=%ZAPRET_DIR%\binaries\win32\winws.exe"

cls
echo.
echo   ╔══════════════════════════════════════════════════════════╗
echo   ║          АВТОМАТИЧЕСКИЙ ПОДБОР СТРАТЕГИЙ DPI             ║
echo   ╚══════════════════════════════════════════════════════════╝
echo.
echo   [i] Скрипт по очереди проверит все доступные стратегии.
echo   [i] Тестируемые сайты: Discord, YouTube, X (Twitter), Gemini, SoundCloud
echo.

:: Загружаем стратегии
call "%SCRIPT_DIR%strategies.bat" load_strategies

:: Останавливаем фоновую службу перед тестами
call "%SCRIPT_DIR%service.bat" stop >nul 2>&1
taskkill /IM winws.exe /F >nul 2>&1
echo   [OK] Фоновую службу временно остановили для тестов.
echo.

:: Список тестовых URL (важно: https:// обязательно, так как DPI блокирует именно ClientHello)
set "TEST_URLS=https://discord.com https://x.com https://rr1---sn-axq7sn7l.googlevideo.com https://gemini.google.com https://soundcloud.com"
set "TOTAL_STRATS=6"
set "SUCCESS_STRATEGY="

for /L %%I in (1,1,%TOTAL_STRATS%) do (
    set "STRAT_NAME=!S%%I_NAME!"
    set "STRAT_TITLE=!S%%I_TITLE!"
    set "STRAT_ARGS=!S%%I_ARGS!"
    
    echo   ━━━ Тестирование стратегии %%I: !STRAT_TITLE! ━━━
    
    :: Запускаем winws.exe в фоне (скрыто, с перенаправлением вывода)
    start "" /B "%WINWS_EXE%" !STRAT_ARGS! >nul 2>&1
    
    :: Ждем 2 секунды для установки перехвата пакетов WinDivert
    timeout /t 2 /nobreak >nul
    
    set "ALL_PASS=1"
    
    :: Проверяем все сайты
    for %%U in (%TEST_URLS%) do (
        echo   [?] Проверка: %%U
        curl -s -I --connect-timeout 4 -m 4 "%%U" >nul
        if !errorlevel! neq 0 (
            echo   [X] Заблокировано: %%U
            set "ALL_PASS=0"
        ) else (
            echo   [OK] Доступен: %%U
        )
    )
    
    :: Убиваем тестовый процесс
    taskkill /IM winws.exe /F >nul 2>&1
    
    if "!ALL_PASS!"=="1" (
        echo.
        echo   [УСПЕХ] Стратегия %%I идеально работает для всех сайтов!
        set "SUCCESS_STRATEGY=%%I"
        goto :found_strategy
    ) else (
        echo   [!] Стратегия %%I не прошла тест. Идем дальше...
        echo.
    )
)

:found_strategy
if "!SUCCESS_STRATEGY!"=="" (
    echo.
    echo   [ОШИБКА] Ни одна из встроенных стратегий не смогла разблокировать все сайты.
    echo   [i] Возможно, вам потребуется ручная настройка или кастомные аргументы.
    echo.
    pause
    exit /b 1
)

:: Применяем найденную стратегию
echo.
echo   [i] Применение рабочей стратегии: !S%SUCCESS_STRATEGY%_TITLE!
echo winws_args="!S%SUCCESS_STRATEGY%_ARGS!"> "%CONFIG_FILE%"

:: Установка и запуск службы
echo   [i] Перезапуск службы...
call "%SCRIPT_DIR%service.bat" install >nul 2>&1
call "%SCRIPT_DIR%service.bat" start >nul 2>&1

echo.
echo   ╔══════════════════════════════════════════════════════════╗
echo   ║       ✅ АВТОМАТИЧЕСКАЯ НАСТРОЙКА ЗАВЕРШЕНА              ║
echo   ╚══════════════════════════════════════════════════════════╝
echo   Стратегия успешно применена. Служба свернута в фон.
echo.
pause
exit /b 0
