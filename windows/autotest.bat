@echo off
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion

:: Generate ESC character for colors
for /F %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"

:: Colors
set "GREEN=%ESC%[32m"
set "RED=%ESC%[31m"
set "YELLOW=%ESC%[33m"
set "CYAN=%ESC%[36m"
set "RESET=%ESC%[0m"

:: ─── Проверка прав администратора ───────────────────────────────────────────
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo   !RED![ОШИБКА] Этот скрипт нужно запускать от Администратора!!RESET!
    echo.
    pause
    exit /b 1
)

set "SCRIPT_DIR=%~dp0"
set "ZAPRET_DIR=%~dp0zapret"
set "CONFIG_FILE=%ZAPRET_DIR%\zapret-winws.ini"
set "WINWS_EXE="
if exist "%ZAPRET_DIR%\bin\winws.exe" set "WINWS_EXE=%ZAPRET_DIR%\bin\winws.exe"

cls
echo.
echo   !CYAN!╔══════════════════════════════════════════════════════════╗!RESET!
echo   !CYAN!║          АВТОМАТИЧЕСКИЙ ПОДБОР СТРАТЕГИЙ DPI             ║!RESET!
echo   !CYAN!╚══════════════════════════════════════════════════════════╝!RESET!
echo.
echo   !YELLOW![i] Скрипт по очереди проверит все доступные стратегии.!RESET!
echo   !YELLOW![i] Тестируемые сайты: Discord, YouTube!RESET!
echo.

:: Загружаем стратегии
call "%SCRIPT_DIR%strategies.bat" load_strategies

:: Останавливаем фоновую службу перед тестами
call "%SCRIPT_DIR%service.bat" stop >nul 2>&1
taskkill /IM winws.exe /F >nul 2>&1
echo   !GREEN![OK] Фоновую службу временно остановили для тестов.!RESET!
echo.

:: Список тестовых URL (проверяем только целевые сервисы)
set "TEST_URLS=https://discord.com https://rr1---sn-axq7sn7l.googlevideo.com"
set "TOTAL_STRATS=6"
set "SUCCESS_STRATEGY="

for /L %%I in (1,1,%TOTAL_STRATS%) do (
    set "STRAT_NAME=!S%%I_NAME!"
    set "STRAT_TITLE=!S%%I_TITLE!"
    set "STRAT_ARGS=!S%%I_ARGS!"
    
    echo   !CYAN!━━━ Тестирование стратегии %%I: !STRAT_TITLE! ━━━!RESET!
    
    :: Запускаем winws.exe в фоне
    start "" /B "%WINWS_EXE%" !STRAT_ARGS! >nul 2>&1
    
    :: Ждем 2 секунды для установки перехвата
    timeout /t 2 /nobreak >nul
    
    set "ALL_PASS=1"
    
    :: Проверяем все сайты
    for %%U in (!TEST_URLS!) do (
        curl -s -I --connect-timeout 4 -m 4 "%%U" >nul
        if !errorlevel! neq 0 (
            echo   !RED![X] Заблокировано: %%U!RESET!
            set "ALL_PASS=0"
        ) else (
            echo   !GREEN![OK] Доступен: %%U!RESET!
        )
    )
    
    :: Убиваем тестовый процесс
    taskkill /IM winws.exe /F >nul 2>&1
    
    if "!ALL_PASS!"=="1" (
        echo.
        echo   !GREEN![УСПЕХ] Стратегия %%I идеально работает для всех сайтов!!RESET!
        set "SUCCESS_STRATEGY=%%I"
        goto :found_strategy
    ) else (
        echo   !YELLOW![!] Стратегия %%I не прошла тест. Идем дальше...!RESET!
        echo.
    )
)

:found_strategy
if "!SUCCESS_STRATEGY!"=="" (
    echo.
    echo   !RED![ОШИБКА] Ни одна из встроенных стратегий не смогла разблокировать все сайты.!RESET!
    echo   !YELLOW![i] Возможно, вам потребуется ручная настройка или кастомные аргументы.!RESET!
    echo.
    pause
    exit /b 1
)

:: Применяем найденную стратегию
echo.
echo   !YELLOW![i] Применение рабочей стратегии: !S%SUCCESS_STRATEGY%_TITLE!!RESET!
(
    echo # Конфигурация Zapret для Windows
    echo # Обновлено автотестом: %date% %time%
    echo #
    echo STRATEGY=!S%SUCCESS_STRATEGY%_NAME!
    echo ARGS=!S%SUCCESS_STRATEGY%_ARGS!
) > "%CONFIG_FILE%"

:: Установка и запуск службы
echo   !YELLOW![i] Перезапуск службы...!RESET!
call "%SCRIPT_DIR%service.bat" install >nul 2>&1
call "%SCRIPT_DIR%service.bat" start >nul 2>&1

echo.
echo   !GREEN!╔══════════════════════════════════════════════════════════╗!RESET!
echo   !GREEN!║       [OK] АВТОМАТИЧЕСКАЯ НАСТРОЙКА ЗАВЕРШЕНА            ║!RESET!
echo   !GREEN!╚══════════════════════════════════════════════════════════╝!RESET!
echo   !GREEN!Стратегия успешно применена. Служба свернута в фон.!RESET!
echo.
pause
exit /b 0
