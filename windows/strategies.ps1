# ZAPRET Windows Strategy Selector (Flowseal Presets)
$SCRIPT_DIR = $PSScriptRoot
$ZAPRET_DIR = Join-Path $SCRIPT_DIR "zapret"
$CONFIG_FILE = Join-Path $ZAPRET_DIR "zapret-winws.ini"
$WINWS_EXE = Join-Path $ZAPRET_DIR "bin\winws.exe"

$curBat = "не выбран"
if (Test-Path $CONFIG_FILE) {
    foreach ($line in Get-Content $CONFIG_FILE) {
        if ($line -match "^WINWS_BAT=(.+)$") { $curBat = $matches[1] }
    }
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "      FLOWSEAL ZAPRET - ВЫБОР ПРЕСЕТА DPI        " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "   Текущий активный пресет: $curBat" -ForegroundColor Yellow
Write-Host ""

Write-Host "    1) Flowseal (ALT) (general (ALT).bat)" -ForegroundColor Green
Write-Host "    2) Flowseal (ALT10) (general (ALT10).bat)" -ForegroundColor Green
Write-Host "    3) Flowseal (ALT11) (general (ALT11).bat)" -ForegroundColor Green
Write-Host "    4) Flowseal (ALT12) (general (ALT12).bat)" -ForegroundColor Green
Write-Host "    5) Flowseal (ALT2) (general (ALT2).bat)" -ForegroundColor Green
Write-Host "    6) Flowseal (ALT3) (general (ALT3).bat)" -ForegroundColor Green
Write-Host "    7) Flowseal (ALT4) (general (ALT4).bat)" -ForegroundColor Green
Write-Host "    8) Flowseal (ALT5) (general (ALT5).bat)" -ForegroundColor Green
Write-Host "    9) Flowseal (ALT6) (general (ALT6).bat)" -ForegroundColor Green
Write-Host "   10) Flowseal (ALT7) (general (ALT7).bat)" -ForegroundColor Green
Write-Host "   11) Flowseal (ALT8) (general (ALT8).bat)" -ForegroundColor Green
Write-Host "   12) Flowseal (ALT9) (general (ALT9).bat)" -ForegroundColor Green
Write-Host "   13) Flowseal (FAKE TLS AUTO ALT) (general (FAKE TLS AUTO ALT).bat)" -ForegroundColor Green
Write-Host "   14) Flowseal (FAKE TLS AUTO ALT2) (general (FAKE TLS AUTO ALT2).bat)" -ForegroundColor Green
Write-Host "   15) Flowseal (FAKE TLS AUTO ALT3) (general (FAKE TLS AUTO ALT3).bat)" -ForegroundColor Green
Write-Host "   16) Flowseal (FAKE TLS AUTO) (general (FAKE TLS AUTO).bat)" -ForegroundColor Green
Write-Host "   17) Flowseal (SIMPLE FAKE ALT) (general (SIMPLE FAKE ALT).bat)" -ForegroundColor Green
Write-Host "   18) Flowseal (SIMPLE FAKE ALT2) (general (SIMPLE FAKE ALT2).bat)" -ForegroundColor Green
Write-Host "   19) Flowseal (SIMPLE FAKE) (general (SIMPLE FAKE).bat)" -ForegroundColor Green
Write-Host "   20) Flowseal General Default (general.bat)" -ForegroundColor Green
Write-Host "    0) Выход"
Write-Host ""

$choice = Read-Host "   Выберите номер пресета [0-20]"

$selFileName = ""
$selTitle = ""
$selArgs = ""

switch ($choice) {
    "1" { $selFileName = "general (ALT).bat"; $selTitle = "Flowseal (ALT)"; $selArgs = "--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 ^" }
    "2" { $selFileName = "general (ALT10).bat"; $selTitle = "Flowseal (ALT10)"; $selArgs = "--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 ^" }
    "3" { $selFileName = "general (ALT11).bat"; $selTitle = "Flowseal (ALT11)"; $selArgs = "--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 ^" }
    "4" { $selFileName = "general (ALT12).bat"; $selTitle = "Flowseal (ALT12)"; $selArgs = "--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 ^" }
    "5" { $selFileName = "general (ALT2).bat"; $selTitle = "Flowseal (ALT2)"; $selArgs = "--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 ^" }
    "6" { $selFileName = "general (ALT3).bat"; $selTitle = "Flowseal (ALT3)"; $selArgs = "--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 ^" }
    "7" { $selFileName = "general (ALT4).bat"; $selTitle = "Flowseal (ALT4)"; $selArgs = "--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 ^" }
    "8" { $selFileName = "general (ALT5).bat"; $selTitle = "Flowseal (ALT5)"; $selArgs = "--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 ^" }
    "9" { $selFileName = "general (ALT6).bat"; $selTitle = "Flowseal (ALT6)"; $selArgs = "--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 ^" }
    "10" { $selFileName = "general (ALT7).bat"; $selTitle = "Flowseal (ALT7)"; $selArgs = "--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 ^" }
    "11" { $selFileName = "general (ALT8).bat"; $selTitle = "Flowseal (ALT8)"; $selArgs = "--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 ^" }
    "12" { $selFileName = "general (ALT9).bat"; $selTitle = "Flowseal (ALT9)"; $selArgs = "--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 ^" }
    "13" { $selFileName = "general (FAKE TLS AUTO ALT).bat"; $selTitle = "Flowseal (FAKE TLS AUTO ALT)"; $selArgs = "--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 ^" }
    "14" { $selFileName = "general (FAKE TLS AUTO ALT2).bat"; $selTitle = "Flowseal (FAKE TLS AUTO ALT2)"; $selArgs = "--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 ^" }
    "15" { $selFileName = "general (FAKE TLS AUTO ALT3).bat"; $selTitle = "Flowseal (FAKE TLS AUTO ALT3)"; $selArgs = "--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 ^" }
    "16" { $selFileName = "general (FAKE TLS AUTO).bat"; $selTitle = "Flowseal (FAKE TLS AUTO)"; $selArgs = "--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 ^" }
    "17" { $selFileName = "general (SIMPLE FAKE ALT).bat"; $selTitle = "Flowseal (SIMPLE FAKE ALT)"; $selArgs = "--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 ^" }
    "18" { $selFileName = "general (SIMPLE FAKE ALT2).bat"; $selTitle = "Flowseal (SIMPLE FAKE ALT2)"; $selArgs = "--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 ^" }
    "19" { $selFileName = "general (SIMPLE FAKE).bat"; $selTitle = "Flowseal (SIMPLE FAKE)"; $selArgs = "--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 ^" }
    "20" { $selFileName = "general.bat"; $selTitle = "Flowseal General Default"; $selArgs = "--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 ^" }
    "0" { exit 0 }
    default { Write-Host "   [!] Неверный выбор" -ForegroundColor Red; exit 0 }
}

Get-Process -Name "winws" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500

$configContent = "WINWS_BAT=" + $selFileName + "`r`nARGS=" + $selArgs
Set-Content -Path $CONFIG_FILE -Value $configContent -Encoding UTF8

Start-Process -FilePath $WINWS_EXE -ArgumentList $selArgs -WindowStyle Hidden
Start-Sleep -Seconds 2

Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "        [OK] ПРЕСЕТ УСПЕШНО АКТИВИРОВАН          " -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host ""
Write-Host "   * Выбран пресет:  $selTitle ($selFileName)" -ForegroundColor Cyan
Write-Host "   * Статус службы:  [OK] ЗАПУЩЕН И РАБОТАЕТ" -ForegroundColor Green
Write-Host ""
Write-Host "[Экспресс-тест доступа]" -ForegroundColor Yellow

& curl.exe -4 -sL -I --connect-timeout 3 -m 4 "https://discord.com" 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "   * Discord:  [OK] ДОСТУПЕН" -ForegroundColor Green
} else {
    Write-Host "   * Discord:  [X] БЛОКИРУЕТСЯ" -ForegroundColor Red
}

& curl.exe -4 -sL -I --connect-timeout 3 -m 4 "https://www.youtube.com" 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "   * YouTube:  [OK] ДОСТУПЕН" -ForegroundColor Green
} else {
    Write-Host "   * YouTube:  [X] БЛОКИРУЕТСЯ" -ForegroundColor Red
}

Write-Host ""
