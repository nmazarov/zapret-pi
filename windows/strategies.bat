@echo off
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion

:: ═══════════════════════════════════════════════════════════════════════════════
::  ZAPRET для WINDOWS — Выбор стратегии DPI Bypass
::  Позволяет переключить стратегию обхода DPI
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

if "%1"=="load_strategies" goto load_strategies

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

:: ─── Стратегии ──────────────────────────────────────────────────────────────
:load_strategies

:: Стратегия 1: Универсальная (md5sig)
set "S1_NAME=universal_md5sig"
set "S1_TITLE=Универсальная (MD5Sig)"
set "S1_DESC=Fake + FakedSplit + MD5Sig. Работает с большинством провайдеров."
set "S1_ARGS=--wf-tcp=80,443 --wf-udp=443 --dpi-desync=fake,fakedsplit --dpi-desync-fooling=md5sig --dpi-desync-split-pos=1,midsld --dpi-desync-split-seqovl=2 --dpi-desync-fake-tls-mod=rnd,rndsni,dupsid --dpi-desync-any-protocol --new --filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=6"

:: Стратегия 2: TTL-based
set "S2_NAME=ttl_based"
set "S2_TITLE=TTL-based"
set "S2_DESC=Fake + MultiDisorder + TTL. Если md5sig не помогает."
set "S2_ARGS=--wf-tcp=80,443 --wf-udp=443 --dpi-desync=fake,multidisorder --dpi-desync-ttl=2 --dpi-desync-autottl=2:64:3 --dpi-desync-split-pos=1,midsld --dpi-desync-any-protocol --new --filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=6"

:: Стратегия 3: FakedDisorder
set "S3_NAME=fakeddisorder"
set "S3_TITLE=FakedDisorder"
set "S3_DESC=Перемешивание фейков. Для сложных DPI (ТСПУ v2)."
set "S3_ARGS=--wf-tcp=80,443 --wf-udp=443 --dpi-desync=fake,disorder2 --dpi-desync-ttl=3 --dpi-desync-fooling=md5sig --dpi-desync-split-pos=1,midsld --dpi-desync-any-protocol --new --filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=6"

:: Стратегия 4: HostFakeSplit (минимальная)
set "S4_NAME=hostfakesplit"
set "S4_TITLE=HostFakeSplit (минимальная)"
set "S4_DESC=Минимальная модификация. Лучший пинг для игр."
set "S4_ARGS=--wf-tcp=80,443 --wf-udp=443 --dpi-desync=fake,split2 --dpi-desync-ttl=4 --dpi-desync-fooling=md5sig --dpi-desync-split-http-req=host --dpi-desync-split-pos=1 --new --filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=6"

:: Стратегия 5: MultiSplit + SeqOvl (максимальная)
set "S5_NAME=multisplit_seqovl"
set "S5_TITLE=MultiSplit + SeqOvl (максимальная)"
set "S5_DESC=Множественная нарезка. Для самых жёстких DPI."
set "S5_ARGS=--wf-tcp=80,443 --wf-udp=443 --dpi-desync=multisplit --dpi-desync-split-seqovl=2 --dpi-desync-ttl=3 --dpi-desync-fooling=md5sig --dpi-desync-split-pos=1,host+2 --dpi-desync-any-protocol --new --filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=6"

:: Стратегия 6: Flowseal ALT (Discord + YouTube)
set "S6_NAME=flowseal_alt"
set "S6_TITLE=Flowseal ALT (Discord + YouTube)"
set "S6_DESC=Проверенная стратегия с подменой TLS/QUIC пакетов."
set "S6_ARGS=--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 --filter-udp=443 --hostlist="!ZAPRET_DIR!\lists\list-general.txt" --hostlist="!ZAPRET_DIR!\lists\list-general-user.txt" --hostlist-exclude="!ZAPRET_DIR!\lists\list-exclude.txt" --hostlist-exclude="!ZAPRET_DIR!\lists\list-exclude-user.txt" --ipset-exclude="!ZAPRET_DIR!\lists\ipset-exclude.txt" --ipset-exclude="!ZAPRET_DIR!\lists\ipset-exclude-user.txt" --dpi-desync=fake --dpi-desync-repeats=6 --dpi-desync-fake-quic="!ZAPRET_DIR!\bin\quic_initial_www_google_com.bin" --new --filter-udp=19294-19344,50000-50100 --filter-l7=discord,stun --dpi-desync=fake --dpi-desync-fake-discord="!ZAPRET_DIR!\bin\quic_initial_dbankcloud_ru.bin" --dpi-desync-fake-stun="!ZAPRET_DIR!\bin\quic_initial_dbankcloud_ru.bin" --dpi-desync-repeats=6 --new --filter-tcp=2053,2083,2087,2096,8443 --hostlist-domains=discord.media --dpi-desync=fake,fakedsplit --dpi-desync-repeats=6 --dpi-desync-fooling=ts --dpi-desync-fakedsplit-pattern=0x00 --dpi-desync-fake-tls="!ZAPRET_DIR!\bin\tls_clienthello_www_google_com.bin" --new --filter-tcp=443 --hostlist="!ZAPRET_DIR!\lists\list-google.txt" --ip-id=zero --dpi-desync=fake,fakedsplit --dpi-desync-repeats=6 --dpi-desync-fooling=ts --dpi-desync-fakedsplit-pattern=0x00 --dpi-desync-fake-tls="!ZAPRET_DIR!\bin\tls_clienthello_www_google_com.bin" --new --filter-tcp=80,443 --hostlist="!ZAPRET_DIR!\lists\list-general.txt" --hostlist="!ZAPRET_DIR!\lists\list-general-user.txt" --hostlist-exclude="!ZAPRET_DIR!\lists\list-exclude.txt" --hostlist-exclude="!ZAPRET_DIR!\lists\list-exclude-user.txt" --ipset-exclude="!ZAPRET_DIR!\lists\ipset-exclude.txt" --ipset-exclude="!ZAPRET_DIR!\lists\ipset-exclude-user.txt" --dpi-desync=fake,fakedsplit --dpi-desync-repeats=6 --dpi-desync-fooling=ts --dpi-desync-fakedsplit-pattern=0x00 --dpi-desync-fake-tls="!ZAPRET_DIR!\bin\stun.bin" --dpi-desync-fake-tls="!ZAPRET_DIR!\bin\tls_clienthello_www_google_com.bin" --dpi-desync-fake-http="!ZAPRET_DIR!\bin\tls_clienthello_max_ru.bin" --new --filter-udp=443 --ipset="!ZAPRET_DIR!\bin\ipset-all.txt" --hostlist-exclude="!ZAPRET_DIR!\lists\list-exclude.txt" --hostlist-exclude="!ZAPRET_DIR!\lists\list-exclude-user.txt" --ipset-exclude="!ZAPRET_DIR!\lists\ipset-exclude.txt" --ipset-exclude="!ZAPRET_DIR!\lists\ipset-exclude-user.txt" --dpi-desync=fake --dpi-desync-repeats=6 --dpi-desync-fake-quic="!ZAPRET_DIR!\bin\quic_initial_www_google_com.bin" --new --filter-tcp=80,443,8443 --ipset="!ZAPRET_DIR!\lists\ipset-all.txt" --hostlist-exclude="!ZAPRET_DIR!\lists\list-exclude.txt" --hostlist-exclude="!ZAPRET_DIR!\lists\list-exclude-user.txt" --ipset-exclude="!ZAPRET_DIR!\lists\ipset-exclude.txt" --ipset-exclude="!ZAPRET_DIR!\lists\ipset-exclude-user.txt" --dpi-desync=fake,fakedsplit --dpi-desync-repeats=6 --dpi-desync-fooling=ts --dpi-desync-fakedsplit-pattern=0x00 --dpi-desync-fake-tls="!ZAPRET_DIR!\bin\stun.bin" --dpi-desync-fake-tls="!ZAPRET_DIR!\bin\tls_clienthello_www_google_com.bin" --dpi-desync-fake-http="!ZAPRET_DIR!\bin\tls_clienthello_max_ru.bin""


if "%1"=="load_strategies" exit /b 0

:show_menu


:: ─── Текущая стратегия ──────────────────────────────────────────────────────
set "CURRENT_STRATEGY="
for /f "tokens=1,* delims==" %%a in ('type "%CONFIG_FILE%" 2^>nul ^| findstr "^STRATEGY="') do (
    set "CURRENT_STRATEGY=%%b"
)

:: ─── Меню ───────────────────────────────────────────────────────────────────
:show_menu
cls
echo.
echo   ╔══════════════════════════════════════════════════════════╗
echo   ║         ZAPRET — ВЫБОР СТРАТЕГИИ DPI BYPASS            ║
echo   ╚══════════════════════════════════════════════════════════╝
echo.
echo   Текущая стратегия: %CURRENT_STRATEGY%
echo.
echo   ┌──────────────────────────────────────────────────────────┐
echo   │                                                          │
echo   │  1) %S1_TITLE%
echo   │     %S1_DESC%
echo   │                                                          │
echo   │  2) %S2_TITLE%
echo   │     %S2_DESC%
echo   │                                                          │
echo   │  3) %S3_TITLE%
echo   │     %S3_DESC%
echo   │                                                          │
echo   │  4) %S4_TITLE%
echo   │     %S4_DESC%
echo   │                                                          │
echo   │  5) %S5_TITLE%
echo   │     %S5_DESC%
echo   │                                                          │
echo   │  6) %S6_TITLE%
echo   │     %S6_DESC%
echo   │                                                          │
echo   └──────────────────────────────────────────────────────────┘
echo.
echo   0) Выход
echo.
set /p "choice=  Выберите стратегию [0-6]: "

if "%choice%"=="1" (
    set "SEL_NAME=!S1_NAME!"
    set "SEL_TITLE=!S1_TITLE!"
    set "SEL_ARGS=!S1_ARGS!"
    goto :apply
)
if "%choice%"=="2" (
    set "SEL_NAME=!S2_NAME!"
    set "SEL_TITLE=!S2_TITLE!"
    set "SEL_ARGS=!S2_ARGS!"
    goto :apply
)
if "%choice%"=="3" (
    set "SEL_NAME=!S3_NAME!"
    set "SEL_TITLE=!S3_TITLE!"
    set "SEL_ARGS=!S3_ARGS!"
    goto :apply
)
if "%choice%"=="4" (
    set "SEL_NAME=!S4_NAME!"
    set "SEL_TITLE=!S4_TITLE!"
    set "SEL_ARGS=!S4_ARGS!"
    goto :apply
)
if "%choice%"=="5" (
    set "SEL_NAME=!S5_NAME!"
    set "SEL_TITLE=!S5_TITLE!"
    set "SEL_ARGS=!S5_ARGS!"
    goto :apply
)
if "%choice%"=="6" (
    set "SEL_NAME=!S6_NAME!"
    set "SEL_TITLE=!S6_TITLE!"
    set "SEL_ARGS=!S6_ARGS!"
    goto :apply
)
if "%choice%"=="0" exit /b 0

echo   [!] Неверный выбор
timeout /t 2 /nobreak >nul
goto :show_menu

:: ─── Применение стратегии ───────────────────────────────────────────────────
:apply
echo.
echo   [i] Применение стратегии: !SEL_TITLE!
echo.

:: Обновляем конфиг
(
    echo # Конфигурация Zapret для Windows
    echo # Обновлено: %date% %time%
    echo #
    echo # Стратегия DPI bypass (аргументы для winws.exe^)
    echo #
    echo STRATEGY=!SEL_NAME!
    echo ARGS=!SEL_ARGS!
) > "%CONFIG_FILE%"

echo   [OK] Конфигурация обновлена

:: Перезапускаем winws
echo   [i] Перезапуск winws.exe...
taskkill /F /IM winws.exe >nul 2>&1
timeout /t 1 /nobreak >nul

:: Обновляем задачу планировщика
schtasks /Delete /TN "%TASK_NAME%" /F >nul 2>&1
schtasks /Create /TN "%TASK_NAME%" /TR "\"!WINWS_EXE!\" !SEL_ARGS!" /SC ONLOGON /RL HIGHEST /RU SYSTEM /F >nul 2>&1

:: Запускаем
schtasks /Run /TN "%TASK_NAME%" >nul 2>&1
if %errorlevel% neq 0 (
    start "" /B "!WINWS_EXE!" !SEL_ARGS!
)

timeout /t 2 /nobreak >nul

:: Проверяем
tasklist /FI "IMAGENAME eq winws.exe" 2>nul | findstr /I "winws.exe" >nul
if %errorlevel% equ 0 (
    echo   [OK] winws.exe запущен с новой стратегией
) else (
    echo   [!] winws.exe не обнаружен. Попробуйте запустить вручную через service.bat
)

set "CURRENT_STRATEGY=!SEL_NAME!"

echo.
pause
goto :show_menu
