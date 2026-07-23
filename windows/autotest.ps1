# ZAPRET Windows Auto-Tester
$SCRIPT_DIR = $PSScriptRoot
$ZAPRET_DIR = Join-Path $SCRIPT_DIR "zapret"
$CONFIG_FILE = Join-Path $ZAPRET_DIR "zapret-winws.ini"
$WINWS_EXE = Join-Path $ZAPRET_DIR "bin\winws.exe"

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "       АВТОМАТИЧЕСКИЙ ПОДБОР СТРАТЕГИЙ DPI        " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "[i] Поочередная проверка 6 встроенных профилей..." -ForegroundColor Yellow
Write-Host ""

$s1_args = '--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 --filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=6 --new --filter-udp=19294-19344,50000-50100 --filter-l7=discord,stun --dpi-desync=fake --dpi-desync-repeats=6 --new --filter-tcp=2053,2083,2087,2096,8443 --hostlist-domains=discord.media --dpi-desync=fake,fakedsplit --dpi-desync-repeats=6 --dpi-desync-fooling=ts --dpi-desync-fakedsplit-pattern=0x00 --new --filter-tcp=443 --ip-id=zero --dpi-desync=fake,fakedsplit --dpi-desync-repeats=6 --dpi-desync-fooling=ts --dpi-desync-fakedsplit-pattern=0x00 --new --filter-tcp=80,443 --dpi-desync=fake,fakedsplit --dpi-desync-repeats=6 --dpi-desync-fooling=ts --dpi-desync-fakedsplit-pattern=0x00 --new --filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=6 --new --filter-tcp=80,443,8443 --dpi-desync=fake,fakedsplit --dpi-desync-repeats=6 --dpi-desync-fooling=ts --dpi-desync-fakedsplit-pattern=0x00'
$s2_args = '--wf-tcp=80,443 --wf-udp=443 --dpi-desync=fake,fakedsplit --dpi-desync-fooling=md5sig --dpi-desync-split-pos=1,midsld --dpi-desync-split-seqovl=2 --dpi-desync-fake-tls-mod=rnd,rndsni,dupsid --dpi-desync-any-protocol --new --filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=6'
$s3_args = '--wf-tcp=80,443 --wf-udp=443 --dpi-desync=multisplit --dpi-desync-split-seqovl=2 --dpi-desync-ttl=3 --dpi-desync-fooling=md5sig --dpi-desync-split-pos=1,host+2 --dpi-desync-any-protocol --new --filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=6'
$s4_args = '--wf-tcp=80,443 --wf-udp=443 --dpi-desync=fake,disorder2 --dpi-desync-ttl=3 --dpi-desync-fooling=md5sig --dpi-desync-split-pos=1,midsld --dpi-desync-any-protocol --new --filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=6'
$s5_args = '--wf-tcp=80,443 --wf-udp=443 --dpi-desync=fake,multidisorder --dpi-desync-ttl=2 --dpi-desync-autottl=2:64:3 --dpi-desync-split-pos=1,midsld --dpi-desync-any-protocol --new --filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=6'
$s6_args = '--wf-tcp=80,443 --wf-udp=443 --dpi-desync=fake,split2 --dpi-desync-ttl=4 --dpi-desync-fooling=md5sig --dpi-desync-split-http-req=host --dpi-desync-split-pos=1 --new --filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=6'

function Test-Single-Strategy([string]$tTitle, [string]$tArgs) {
    Write-Host "   * Проверка: $tTitle..." -ForegroundColor Yellow -NoNewline
    Get-Process -Name "winws" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    
    $proc = Start-Process -FilePath $WINWS_EXE -ArgumentList $tArgs -WindowStyle Hidden -PassThru
    Start-Sleep -Seconds 2
    
    & curl.exe -4 -sL -I --connect-timeout 3 -m 4 "https://discord.com" 2>&1 | Out-Null
    $ok1 = ($LASTEXITCODE -eq 0)
    
    & curl.exe -4 -sL -I --connect-timeout 3 -m 4 "https://www.youtube.com" 2>&1 | Out-Null
    $ok2 = ($LASTEXITCODE -eq 0)
    
    Get-Process -Name "winws" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    
    if ($ok1 -and $ok2) {
        Write-Host " -> [OK] Идеально подходит!" -ForegroundColor Green
        return $true
    }
    
    Write-Host " -> [X] Заблокировано" -ForegroundColor Red
    return $false
}

$winnerName = ""
$winnerTitle = ""
$winnerArgs = ""

if (Test-Single-Strategy "Flowseal ALT" $s1_args) {
    $winnerName = "flowseal_alt"
    $winnerTitle = "Flowseal ALT"
    $winnerArgs = $s1_args
}
if ($winnerName -eq "" -and (Test-Single-Strategy "Universal MD5Sig" $s2_args)) {
    $winnerName = "universal_md5sig"
    $winnerTitle = "Universal MD5Sig"
    $winnerArgs = $s2_args
}
if ($winnerName -eq "" -and (Test-Single-Strategy "MultiSplit SeqOvl" $s3_args)) {
    $winnerName = "multisplit_seqovl"
    $winnerTitle = "MultiSplit SeqOvl"
    $winnerArgs = $s3_args
}
if ($winnerName -eq "" -and (Test-Single-Strategy "FakedDisorder" $s4_args)) {
    $winnerName = "fakeddisorder"
    $winnerTitle = "FakedDisorder"
    $winnerArgs = $s4_args
}
if ($winnerName -eq "" -and (Test-Single-Strategy "TTL-based" $s5_args)) {
    $winnerName = "ttl_based"
    $winnerTitle = "TTL-based"
    $winnerArgs = $s5_args
}
if ($winnerName -eq "" -and (Test-Single-Strategy "HostFakeSplit" $s6_args)) {
    $winnerName = "hostfakesplit"
    $winnerTitle = "HostFakeSplit"
    $winnerArgs = $s6_args
}

if ($winnerName -eq "") {
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Red
    Write-Host " [!] НИ ОДНА ИЗ ВСТРОЕННЫХ СТРАТЕГИЙ НЕ ПОДОШЛА   " -ForegroundColor Red
    Write-Host "==================================================" -ForegroundColor Red
    Write-Host "Рекомендуется использовать SmartDNS VLESS на Raspberry Pi." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

$configContent = "STRATEGY=" + $winnerName + "`r`nARGS=" + $winnerArgs
Set-Content -Path $CONFIG_FILE -Value $configContent -Encoding UTF8

Start-Process -FilePath $WINWS_EXE -ArgumentList $winnerArgs -WindowStyle Hidden

Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "   [OK] АВТОМАТИЧЕСКИЙ ПОДБОР УСПЕШНО ЗАВЕРШЕН    " -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host ""
Write-Host "   * Подошла стратегия: $winnerTitle" -ForegroundColor Cyan
Write-Host "   * Статус службы:     [OK] АКТИВИРОВАНА И РАБОТАЕТ" -ForegroundColor Green
Write-Host ""
Write-Host "[Результат доступа]" -ForegroundColor Yellow
Write-Host "   * Discord:  [OK] ДОСТУПЕН" -ForegroundColor Green
Write-Host "   * YouTube:  [OK] ДОСТУПЕН" -ForegroundColor Green
Write-Host ""
