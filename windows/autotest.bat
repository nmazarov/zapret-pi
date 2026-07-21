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

:: в”Ђв”Ђв”Ђ РџСЂРѕРІРµСЂРєР° РїСЂР°РІ Р°РґРјРёРЅРёСЃС‚СЂР°С‚РѕСЂР° в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo   !RED![РћРЁРР‘РљРђ] Р­С‚РѕС‚ СЃРєСЂРёРїС‚ РЅСѓР¶РЅРѕ Р·Р°РїСѓСЃРєР°С‚СЊ РѕС‚ РђРґРјРёРЅРёСЃС‚СЂР°С‚РѕСЂР°!!RESET!
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
echo   !CYAN!в•”в•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•—!RESET!
echo   !CYAN!в•‘          РђР’РўРћРњРђРўРР§Р•РЎРљРР™ РџРћР”Р‘РћР  РЎРўР РђРўР•Р“РР™ DPI             в•‘!RESET!
echo   !CYAN!в•љв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ќ!RESET!
echo.
echo   !YELLOW![i] РЎРєСЂРёРїС‚ РїРѕ РѕС‡РµСЂРµРґРё РїСЂРѕРІРµСЂРёС‚ РІСЃРµ РґРѕСЃС‚СѓРїРЅС‹Рµ СЃС‚СЂР°С‚РµРіРёРё.!RESET!
echo   !YELLOW![i] РўРµСЃС‚РёСЂСѓРµРјС‹Рµ СЃР°Р№С‚С‹: Discord, YouTube, X (Twitter), Gemini, SoundCloud!RESET!
echo.

:: Р—Р°РіСЂСѓР¶Р°РµРј СЃС‚СЂР°С‚РµРіРёРё
call "%SCRIPT_DIR%strategies.bat" load_strategies

:: РћСЃС‚Р°РЅР°РІР»РёРІР°РµРј С„РѕРЅРѕРІСѓСЋ СЃР»СѓР¶Р±Сѓ РїРµСЂРµРґ С‚РµСЃС‚Р°РјРё
call "%SCRIPT_DIR%service.bat" stop >nul 2>&1
taskkill /IM winws.exe /F >nul 2>&1
echo   !GREEN![OK] Р¤РѕРЅРѕРІСѓСЋ СЃР»СѓР¶Р±Сѓ РІСЂРµРјРµРЅРЅРѕ РѕСЃС‚Р°РЅРѕРІРёР»Рё РґР»СЏ С‚РµСЃС‚РѕРІ.!RESET!
echo.

:: РЎРїРёСЃРѕРє С‚РµСЃС‚РѕРІС‹С… URL
set "TEST_URLS=https://discord.com https://x.com https://rr1---sn-axq7sn7l.googlevideo.com https://gemini.google.com https://soundcloud.com"
set "TOTAL_STRATS=6"
set "SUCCESS_STRATEGY="

for /L %%I in (1,1,%TOTAL_STRATS%) do (
    set "STRAT_NAME=!S%%I_NAME!"
    set "STRAT_TITLE=!S%%I_TITLE!"
    set "STRAT_ARGS=!S%%I_ARGS!"
    
    echo   !CYAN!в”Ѓв”Ѓв”Ѓ РўРµСЃС‚РёСЂРѕРІР°РЅРёРµ СЃС‚СЂР°С‚РµРіРёРё %%I: !STRAT_TITLE! в”Ѓв”Ѓв”Ѓ!RESET!
    
    :: Р—Р°РїСѓСЃРєР°РµРј winws.exe РІ С„РѕРЅРµ
    start "" /B "%WINWS_EXE%" !STRAT_ARGS! >nul 2>&1
    
    :: Р–РґРµРј 2 СЃРµРєСѓРЅРґС‹ РґР»СЏ СѓСЃС‚Р°РЅРѕРІРєРё РїРµСЂРµС…РІР°С‚Р°
    timeout /t 2 /nobreak >nul
    
    set "ALL_PASS=1"
    
    :: РџСЂРѕРІРµСЂСЏРµРј РІСЃРµ СЃР°Р№С‚С‹
    for %%U in (!TEST_URLS!) do (
        curl -s -I --connect-timeout 4 -m 4 "%%U" >nul
        if !errorlevel! neq 0 (
            echo   !RED![X] Р—Р°Р±Р»РѕРєРёСЂРѕРІР°РЅРѕ: %%U!RESET!
            set "ALL_PASS=0"
        ) else (
            echo   !GREEN![OK] Р”РѕСЃС‚СѓРїРµРЅ: %%U!RESET!
        )
    )
    
    :: РЈР±РёРІР°РµРј С‚РµСЃС‚РѕРІС‹Р№ РїСЂРѕС†РµСЃСЃ
    taskkill /IM winws.exe /F >nul 2>&1
    
    if "!ALL_PASS!"=="1" (
        echo.
        echo   !GREEN![РЈРЎРџР•РҐ] РЎС‚СЂР°С‚РµРіРёСЏ %%I РёРґРµР°Р»СЊРЅРѕ СЂР°Р±РѕС‚Р°РµС‚ РґР»СЏ РІСЃРµС… СЃР°Р№С‚РѕРІ!!RESET!
        set "SUCCESS_STRATEGY=%%I"
        goto :found_strategy
    ) else (
        echo   !YELLOW![!] РЎС‚СЂР°С‚РµРіРёСЏ %%I РЅРµ РїСЂРѕС€Р»Р° С‚РµСЃС‚. РРґРµРј РґР°Р»СЊС€Рµ...!RESET!
        echo.
    )
)

:found_strategy
if "!SUCCESS_STRATEGY!"=="" (
    echo.
    echo   !RED![РћРЁРР‘РљРђ] РќРё РѕРґРЅР° РёР· РІСЃС‚СЂРѕРµРЅРЅС‹С… СЃС‚СЂР°С‚РµРіРёР№ РЅРµ СЃРјРѕРіР»Р° СЂР°Р·Р±Р»РѕРєРёСЂРѕРІР°С‚СЊ РІСЃРµ СЃР°Р№С‚С‹.!RESET!
    echo   !YELLOW![i] Р’РѕР·РјРѕР¶РЅРѕ, РІР°Рј РїРѕС‚СЂРµР±СѓРµС‚СЃСЏ СЂСѓС‡РЅР°СЏ РЅР°СЃС‚СЂРѕР№РєР° РёР»Рё РєР°СЃС‚РѕРјРЅС‹Рµ Р°СЂРіСѓРјРµРЅС‚С‹.!RESET!
    echo.
    pause
    exit /b 1
)

:: РџСЂРёРјРµРЅСЏРµРј РЅР°Р№РґРµРЅРЅСѓСЋ СЃС‚СЂР°С‚РµРіРёСЋ
echo.
echo   !YELLOW![i] РџСЂРёРјРµРЅРµРЅРёРµ СЂР°Р±РѕС‡РµР№ СЃС‚СЂР°С‚РµРіРёРё: !S%SUCCESS_STRATEGY%_TITLE!!RESET!
echo winws_args="!S%SUCCESS_STRATEGY%_ARGS!"> "%CONFIG_FILE%"

:: РЈСЃС‚Р°РЅРѕРІРєР° Рё Р·Р°РїСѓСЃРє СЃР»СѓР¶Р±С‹
echo   !YELLOW![i] РџРµСЂРµР·Р°РїСѓСЃРє СЃР»СѓР¶Р±С‹...!RESET!
call "%SCRIPT_DIR%service.bat" install >nul 2>&1
call "%SCRIPT_DIR%service.bat" start >nul 2>&1

echo.
echo   !GREEN!в•”в•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•—!RESET!
echo   !GREEN!в•‘       вњ… РђР’РўРћРњРђРўРР§Р•РЎРљРђРЇ РќРђРЎРўР РћР™РљРђ Р—РђР’Р•Р РЁР•РќРђ              в•‘!RESET!
echo   !GREEN!в•љв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ђв•ќ!RESET!
echo   !GREEN!РЎС‚СЂР°С‚РµРіРёСЏ СѓСЃРїРµС€РЅРѕ РїСЂРёРјРµРЅРµРЅР°. РЎР»СѓР¶Р±Р° СЃРІРµСЂРЅСѓС‚Р° РІ С„РѕРЅ.!RESET!
echo.
pause
exit /b 0
