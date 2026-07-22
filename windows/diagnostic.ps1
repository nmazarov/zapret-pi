# Zapret Diagnostic Script
# Run this from an Admin PowerShell

$zapretDir = Join-Path $PSScriptRoot "zapret"
$winws = Join-Path $zapretDir "bin\winws.exe"
$config = Join-Path $zapretDir "zapret-winws.ini"

Write-Host ""
Write-Host "=== ZAPRET DIAGNOSTIC ===" -ForegroundColor Cyan
Write-Host ""

# 1. Check files
Write-Host "[1] Checking files..." -ForegroundColor Yellow
foreach ($f in @("bin\winws.exe", "bin\WinDivert.dll", "bin\WinDivert64.sys")) {
    $p = Join-Path $zapretDir $f
    if (Test-Path $p) {
        Write-Host "  [OK] $f" -ForegroundColor Green
    } else {
        Write-Host "  [X] $f NOT FOUND" -ForegroundColor Red
    }
}
Write-Host ""

# 2. Show config
Write-Host "[2] Config file:" -ForegroundColor Yellow
if (Test-Path $config) {
    Get-Content $config | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host "  [X] Config not found" -ForegroundColor Red
}
Write-Host ""

# 3. Read ARGS
$winwsArgs = ""
if (Test-Path $config) {
    foreach ($line in Get-Content $config) {
        if ($line -match "^ARGS=(.+)$") {
            $winwsArgs = $matches[1]
        }
    }
}
if ([string]::IsNullOrWhiteSpace($winwsArgs)) {
    Write-Host "[!] ARGS empty, using default strategy" -ForegroundColor Yellow
    $winwsArgs = "--wf-tcp=80,443 --wf-udp=443 --dpi-desync=fake,fakedsplit --dpi-desync-fooling=md5sig --dpi-desync-split-pos=1,midsld --dpi-desync-split-seqovl=2 --dpi-desync-fake-tls-mod=rnd,rndsni,dupsid --dpi-desync-any-protocol --new --filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=6"
}
Write-Host "[3] Args: $winwsArgs" -ForegroundColor Yellow
Write-Host ""

# 4. Check process
Write-Host "[4] Checking winws.exe process..." -ForegroundColor Yellow
$proc = Get-Process -Name "winws" -ErrorAction SilentlyContinue
if (-not $proc) {
    Write-Host "  Starting winws.exe..." -ForegroundColor Yellow
    $proc = Start-Process -FilePath $winws -ArgumentList $winwsArgs -WindowStyle Hidden -PassThru
    Start-Sleep -Seconds 2
}

if ($proc) {
    Write-Host "  [OK] winws.exe RUNNING (PID: $($proc.Id))" -ForegroundColor Green
} else {
    Write-Host "  [X] winws.exe FAILED TO START" -ForegroundColor Red
}
Write-Host ""

# 5. Test Discord
Write-Host "[5] Testing Discord..." -ForegroundColor Yellow
$rDiscord = curl.exe -s -I --connect-timeout 5 -m 5 "https://discord.com"
if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] Discord ACCESSIBLE" -ForegroundColor Green
} else {
    Write-Host "  [X] Discord BLOCKED" -ForegroundColor Red
}

# 6. Test YouTube
Write-Host "[6] Testing YouTube..." -ForegroundColor Yellow
$rYT = curl.exe -s -I --connect-timeout 5 -m 5 "https://www.youtube.com"
if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] YouTube ACCESSIBLE" -ForegroundColor Green
} else {
    Write-Host "  [X] YouTube BLOCKED" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== DIAGNOSTIC COMPLETE ===" -ForegroundColor Cyan
Write-Host ""
