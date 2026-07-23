# ZAPRET Windows Service Manager
param([string]$action)

$SCRIPT_DIR = $PSScriptRoot
$ZAPRET_DIR = Join-Path $SCRIPT_DIR "zapret"
$CONFIG_FILE = Join-Path $ZAPRET_DIR "zapret-winws.ini"
$WINWS_EXE = Join-Path $ZAPRET_DIR "bin\winws.exe"

$winArgs = ""
if (Test-Path $CONFIG_FILE) {
    foreach ($line in Get-Content $CONFIG_FILE) {
        if ($line -match "^ARGS=(.+)$") { $winArgs = $matches[1] }
    }
}

if (-not $action) {
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "          ZAPRET - УПРАВЛЕНИЕ СЛУЖБОЙ             " -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   1) Запустить"
    Write-Host "   2) Остановить"
    Write-Host "   3) Перезапустить"
    Write-Host "   4) Проверить статус"
    Write-Host "   0) Выход"
    Write-Host ""
    $choice = Read-Host "   Выберите действие [0-4]"
    switch ($choice) {
        "1" { $action = "start" }
        "2" { $action = "stop" }
        "3" { $action = "restart" }
        "4" { $action = "status" }
        default { exit 0 }
    }
}

if ($action -eq "stop" -or $action -eq "restart") {
    Write-Host "   [*] Остановка процесса winws.exe..." -ForegroundColor Yellow
    Get-Process -Name "winws" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    if ($action -eq "stop") {
        Write-Host "   [OK] Служба остановлена." -ForegroundColor Green
        exit 0
    }
}

if ($action -eq "start" -or $action -eq "restart") {
    Write-Host "   [*] Запуск процесса winws.exe..." -ForegroundColor Yellow
    $proc = Get-Process -Name "winws" -ErrorAction SilentlyContinue
    if (-not $proc) {
        Start-Process -FilePath $WINWS_EXE -ArgumentList $winArgs -WindowStyle Hidden
        Start-Sleep -Seconds 2
    }
    Write-Host "   [OK] Служба запущена!" -ForegroundColor Green
}

if ($action -eq "status") {
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "               СТАТУС СЛУЖБЫ ZAPRET               " -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host ""
    
    $proc = Get-Process -Name "winws" -ErrorAction SilentlyContinue
    if ($proc) {
        Write-Host "   * Процесс winws.exe: [OK] ЗАПУЩЕН И РАБОТАЕТ (PID: $($proc.Id))" -ForegroundColor Green
    } else {
        Write-Host "   * Процесс winws.exe: [X] ОСТАНОВЛЕН" -ForegroundColor Red
    }

    $curStrat = "не выбрана"
    if (Test-Path $CONFIG_FILE) {
        foreach ($line in Get-Content $CONFIG_FILE) {
            if ($line -match "^STRATEGY=(.+)$") { $curStrat = $matches[1] }
        }
    }
    Write-Host "   * Активный профиль:  $curStrat" -ForegroundColor Cyan
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
}
