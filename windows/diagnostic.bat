@echo off
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion

:: Проверка прав администратора
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ОШИБКА] Запустите от имени Администратора
    pause
    exit /b 1
)

set "ZAPRET_DIR=%~dp0zapret"
set "WINWS_EXE=%ZAPRET_DIR%\bin\winws.exe"
set "CONFIG_FILE=%ZAPRET_DIR%\zapret-winws.ini"

echo.
echo === ДИАГНОСТИКА ZAPRET ===
echo.

:: 1. Проверяем наличие файлов
echo [1] Проверка файлов...
if exist "%WINWS_EXE%" (
    echo   [OK] winws.exe найден
) else (
    echo   [ОШИБКА] winws.exe НЕ НАЙДЕН
    goto :end
)

if exist "%ZAPRET_DIR%\bin\WinDivert.dll" (
    echo   [OK] WinDivert.dll найден
) else (
    echo   [ОШИБКА] WinDivert.dll НЕ НАЙДЕН
)

if exist "%ZAPRET_DIR%\bin\WinDivert64.sys" (
    echo   [OK] WinDivert64.sys найден
) else (
    echo   [ОШИБКА] WinDivert64.sys НЕ НАЙДЕН
)
echo.

:: 2. Проверяем конфиг
echo [2] Конфигурация:
type "%CONFIG_FILE%" 2>nul
echo.

:: 3. Читаем ARGS
set "WINWS_ARGS="
for /f "tokens=1,* delims==" %%a in ('type "%CONFIG_FILE%" 2^>nul ^| findstr "^ARGS="') do (
    set "WINWS_ARGS=%%b"
)

if "!WINWS_ARGS!"=="" (
    echo [ВНИМАНИЕ] ARGS пустые, используем стратегию по умолчанию
    set "WINWS_ARGS=--wf-tcp=80,443 --wf-udp=443 --dpi-desync=fake,fakedsplit --dpi-desync-fooling=md5sig --dpi-desync-split-pos=1,midsld --dpi-desync-split-seqovl=2 --dpi-desync-fake-tls-mod=rnd,rndsni,dupsid --dpi-desync-any-protocol --new --filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=6"
)

echo [3] Аргументы winws:
setlocal DisableDelayedExpansion
echo   %WINWS_ARGS%
endlocal

:: 4. Убиваем старый процесс
echo [4] Остановка старого winws.exe...
taskkill /F /IM winws.exe >nul 2>&1
timeout /t 1 /nobreak >nul
echo   [OK] Остановлен
echo.

:: 5. Запускаем с правильными аргументами
echo [5] Запуск winws.exe с аргументами...
start "" /B "%WINWS_EXE%" !WINWS_ARGS!
timeout /t 3 /nobreak >nul

:: 6. Проверяем процесс
tasklist /FI "IMAGENAME eq winws.exe" 2>nul | findstr /I "winws.exe" >nul
if %errorlevel% equ 0 (
    echo   [OK] winws.exe ЗАПУЩЕН
) else (
    echo   [ОШИБКА] winws.exe НЕ ЗАПУСТИЛСЯ
    goto :end
)
echo.

:: 7. Тестируем Discord
echo [6] Тестирование Discord...
curl -s -I --connect-timeout 5 -m 5 "https://discord.com" >nul 2>&1
if %errorlevel% equ 0 (
    echo   [OK] Discord ДОСТУПЕН
) else (
    echo   [X] Discord ЗАБЛОКИРОВАН - стратегия не подходит для Discord
)

:: 8. Тестируем YouTube
echo [7] Тестирование YouTube...
curl -s -I --connect-timeout 5 -m 5 "https://www.youtube.com" >nul 2>&1
if %errorlevel% equ 0 (
    echo   [OK] YouTube ДОСТУПЕН
) else (
    echo   [X] YouTube ЗАБЛОКИРОВАН - стратегия не подходит для YouTube
)

echo.
echo === ДИАГНОСТИКА ЗАВЕРШЕНА ===

:end
echo.
