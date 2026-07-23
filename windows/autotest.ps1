# ZAPRET Windows Auto-Tester (Flowseal Presets)
$SCRIPT_DIR = $PSScriptRoot
$ZAPRET_DIR = Join-Path $SCRIPT_DIR "zapret"
$CONFIG_FILE = Join-Path $ZAPRET_DIR "zapret-winws.ini"
$WINWS_EXE = Join-Path $ZAPRET_DIR "bin\winws.exe"

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "     FLOWSEAL ZAPRET - АВТОМАТИЧЕСКИЙ ПОДБОР      " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "[i] Сканирование 20 встроенных пресетов Flowseal..." -ForegroundColor Yellow
Write-Host ""

function Test-Flowseal-Profile([string]$tTitle, [string]$tFileName, [string]$tArgs) {
    Write-Host "   * Проверка $tTitle ($tFileName)..." -ForegroundColor Yellow -NoNewline
    Get-Process -Name "winws" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 300
    
    $proc = Start-Process -FilePath $WINWS_EXE -ArgumentList $tArgs -WindowStyle Hidden -PassThru
    Start-Sleep -Seconds 2
    
    & curl.exe -4 -sL -I --connect-timeout 3 -m 4 "https://discord.com" 2>&1 | Out-Null
    $ok1 = ($LASTEXITCODE -eq 0)
    
    & curl.exe -4 -sL -I --connect-timeout 3 -m 4 "https://www.youtube.com" 2>&1 | Out-Null
    $ok2 = ($LASTEXITCODE -eq 0)
    
    if ($ok1 -and $ok2) {
        Write-Host " -> [OK] ИДЕАЛЬНО РАЗБЛОКИРУЕТ!" -ForegroundColor Green
        return $true
    }
    
    Get-Process -Name "winws" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Host " -> [X] Заблокировано" -ForegroundColor Red
    return $false
}

$winnerName = ""
$winnerTitle = ""
$winnerFileName = ""
$winnerArgs = ""

if ($winnerFileName -eq "") {
    $args_0 = "--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 ^"
    if (Test-Flowseal-Profile "Flowseal (ALT)" "general (ALT).bat" $args_0) {
        $winnerTitle = "Flowseal (ALT)"
        $winnerFileName = "general (ALT).bat"
        $winnerArgs = $args_0
    }
}
if ($winnerFileName -eq "") {
    $args_1 = "--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 ^"
    if (Test-Flowseal-Profile "Flowseal (ALT10)" "general (ALT10).bat" $args_1) {
        $winnerTitle = "Flowseal (ALT10)"
        $winnerFileName = "general (ALT10).bat"
        $winnerArgs = $args_1
    }
}
if ($winnerFileName -eq "") {
    $args_2 = "--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 ^"
    if (Test-Flowseal-Profile "Flowseal (ALT11)" "general (ALT11).bat" $args_2) {
        $winnerTitle = "Flowseal (ALT11)"
        $winnerFileName = "general (ALT11).bat"
        $winnerArgs = $args_2
    }
}
if ($winnerFileName -eq "") {
    $args_3 = "--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 ^"
    if (Test-Flowseal-Profile "Flowseal (ALT12)" "general (ALT12).bat" $args_3) {
        $winnerTitle = "Flowseal (ALT12)"
        $winnerFileName = "general (ALT12).bat"
        $winnerArgs = $args_3
    }
}
if ($winnerFileName -eq "") {
    $args_4 = "--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 ^"
    if (Test-Flowseal-Profile "Flowseal (ALT2)" "general (ALT2).bat" $args_4) {
        $winnerTitle = "Flowseal (ALT2)"
        $winnerFileName = "general (ALT2).bat"
        $winnerArgs = $args_4
    }
}
if ($winnerFileName -eq "") {
    $args_5 = "--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 ^"
    if (Test-Flowseal-Profile "Flowseal (ALT3)" "general (ALT3).bat" $args_5) {
        $winnerTitle = "Flowseal (ALT3)"
        $winnerFileName = "general (ALT3).bat"
        $winnerArgs = $args_5
    }
}
if ($winnerFileName -eq "") {
    $args_6 = "--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 ^"
    if (Test-Flowseal-Profile "Flowseal (ALT4)" "general (ALT4).bat" $args_6) {
        $winnerTitle = "Flowseal (ALT4)"
        $winnerFileName = "general (ALT4).bat"
        $winnerArgs = $args_6
    }
}
if ($winnerFileName -eq "") {
    $args_7 = "--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 ^"
    if (Test-Flowseal-Profile "Flowseal (ALT5)" "general (ALT5).bat" $args_7) {
        $winnerTitle = "Flowseal (ALT5)"
        $winnerFileName = "general (ALT5).bat"
        $winnerArgs = $args_7
    }
}
if ($winnerFileName -eq "") {
    $args_8 = "--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 ^"
    if (Test-Flowseal-Profile "Flowseal (ALT6)" "general (ALT6).bat" $args_8) {
        $winnerTitle = "Flowseal (ALT6)"
        $winnerFileName = "general (ALT6).bat"
        $winnerArgs = $args_8
    }
}
if ($winnerFileName -eq "") {
    $args_9 = "--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 ^"
    if (Test-Flowseal-Profile "Flowseal (ALT7)" "general (ALT7).bat" $args_9) {
        $winnerTitle = "Flowseal (ALT7)"
        $winnerFileName = "general (ALT7).bat"
        $winnerArgs = $args_9
    }
}
if ($winnerFileName -eq "") {
    $args_10 = "--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 ^"
    if (Test-Flowseal-Profile "Flowseal (ALT8)" "general (ALT8).bat" $args_10) {
        $winnerTitle = "Flowseal (ALT8)"
        $winnerFileName = "general (ALT8).bat"
        $winnerArgs = $args_10
    }
}
if ($winnerFileName -eq "") {
    $args_11 = "--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 ^"
    if (Test-Flowseal-Profile "Flowseal (ALT9)" "general (ALT9).bat" $args_11) {
        $winnerTitle = "Flowseal (ALT9)"
        $winnerFileName = "general (ALT9).bat"
        $winnerArgs = $args_11
    }
}
if ($winnerFileName -eq "") {
    $args_12 = "--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 ^"
    if (Test-Flowseal-Profile "Flowseal (FAKE TLS AUTO ALT)" "general (FAKE TLS AUTO ALT).bat" $args_12) {
        $winnerTitle = "Flowseal (FAKE TLS AUTO ALT)"
        $winnerFileName = "general (FAKE TLS AUTO ALT).bat"
        $winnerArgs = $args_12
    }
}
if ($winnerFileName -eq "") {
    $args_13 = "--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 ^"
    if (Test-Flowseal-Profile "Flowseal (FAKE TLS AUTO ALT2)" "general (FAKE TLS AUTO ALT2).bat" $args_13) {
        $winnerTitle = "Flowseal (FAKE TLS AUTO ALT2)"
        $winnerFileName = "general (FAKE TLS AUTO ALT2).bat"
        $winnerArgs = $args_13
    }
}
if ($winnerFileName -eq "") {
    $args_14 = "--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 ^"
    if (Test-Flowseal-Profile "Flowseal (FAKE TLS AUTO ALT3)" "general (FAKE TLS AUTO ALT3).bat" $args_14) {
        $winnerTitle = "Flowseal (FAKE TLS AUTO ALT3)"
        $winnerFileName = "general (FAKE TLS AUTO ALT3).bat"
        $winnerArgs = $args_14
    }
}
if ($winnerFileName -eq "") {
    $args_15 = "--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 ^"
    if (Test-Flowseal-Profile "Flowseal (FAKE TLS AUTO)" "general (FAKE TLS AUTO).bat" $args_15) {
        $winnerTitle = "Flowseal (FAKE TLS AUTO)"
        $winnerFileName = "general (FAKE TLS AUTO).bat"
        $winnerArgs = $args_15
    }
}
if ($winnerFileName -eq "") {
    $args_16 = "--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 ^"
    if (Test-Flowseal-Profile "Flowseal (SIMPLE FAKE ALT)" "general (SIMPLE FAKE ALT).bat" $args_16) {
        $winnerTitle = "Flowseal (SIMPLE FAKE ALT)"
        $winnerFileName = "general (SIMPLE FAKE ALT).bat"
        $winnerArgs = $args_16
    }
}
if ($winnerFileName -eq "") {
    $args_17 = "--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 ^"
    if (Test-Flowseal-Profile "Flowseal (SIMPLE FAKE ALT2)" "general (SIMPLE FAKE ALT2).bat" $args_17) {
        $winnerTitle = "Flowseal (SIMPLE FAKE ALT2)"
        $winnerFileName = "general (SIMPLE FAKE ALT2).bat"
        $winnerArgs = $args_17
    }
}
if ($winnerFileName -eq "") {
    $args_18 = "--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 ^"
    if (Test-Flowseal-Profile "Flowseal (SIMPLE FAKE)" "general (SIMPLE FAKE).bat" $args_18) {
        $winnerTitle = "Flowseal (SIMPLE FAKE)"
        $winnerFileName = "general (SIMPLE FAKE).bat"
        $winnerArgs = $args_18
    }
}
if ($winnerFileName -eq "") {
    $args_19 = "--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 ^"
    if (Test-Flowseal-Profile "Flowseal General Default" "general.bat" $args_19) {
        $winnerTitle = "Flowseal General Default"
        $winnerFileName = "general.bat"
        $winnerArgs = $args_19
    }
}

if ($winnerFileName -eq "") {
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Red
    Write-Host " [!] НИ ОДИН ИЗ ПРЕСЕТОВ FLOWSEAL НЕ ПОДОШЕЛ     " -ForegroundColor Red
    Write-Host "==================================================" -ForegroundColor Red
    Write-Host "Рекомендуется использовать SmartDNS VLESS на Raspberry Pi." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

$configContent = "WINWS_BAT=" + $winnerFileName + "`r`nARGS=" + $winnerArgs
Set-Content -Path $CONFIG_FILE -Value $configContent -Encoding UTF8

Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "   [OK] АВТОМАТИЧЕСКИЙ ПОДБОР УСПЕШНО ЗАВЕРШЕН    " -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host ""
Write-Host "   * Подошел пресет: $winnerTitle ($winnerFileName)" -ForegroundColor Cyan
Write-Host "   * Статус службы:  [OK] АКТИВИРОВАН И РАБОТАЕТ" -ForegroundColor Green
Write-Host ""
Write-Host "[Результат доступа]" -ForegroundColor Yellow
Write-Host "   * Discord:  [OK] ДОСТУПЕН" -ForegroundColor Green
Write-Host "   * YouTube:  [OK] ДОСТУПЕН" -ForegroundColor Green
Write-Host ""
