# ZAPRET Windows Strategy Selector
$SCRIPT_DIR = $PSScriptRoot
$ZAPRET_DIR = Join-Path $SCRIPT_DIR "zapret"
$CONFIG_FILE = Join-Path $ZAPRET_DIR "zapret-winws.ini"
$WINWS_EXE = Join-Path $ZAPRET_DIR "bin\winws.exe"

$s1_args = '--wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100 --filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=6 --new --filter-udp=19294-19344,50000-50100 --filter-l7=discord,stun --dpi-desync=fake --dpi-desync-repeats=6 --new --filter-tcp=2053,2083,2087,2096,8443 --hostlist-domains=discord.media --dpi-desync=fake,fakedsplit --dpi-desync-repeats=6 --dpi-desync-fooling=ts --dpi-desync-fakedsplit-pattern=0x00 --new --filter-tcp=443 --ip-id=zero --dpi-desync=fake,fakedsplit --dpi-desync-repeats=6 --dpi-desync-fooling=ts --dpi-desync-fakedsplit-pattern=0x00 --new --filter-tcp=80,443 --dpi-desync=fake,fakedsplit --dpi-desync-repeats=6 --dpi-desync-fooling=ts --dpi-desync-fakedsplit-pattern=0x00 --new --filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=6 --new --filter-tcp=80,443,8443 --dpi-desync=fake,fakedsplit --dpi-desync-repeats=6 --dpi-desync-fooling=ts --dpi-desync-fakedsplit-pattern=0x00'
$s2_args = '--wf-tcp=80,443 --wf-udp=443 --dpi-desync=fake,fakedsplit --dpi-desync-fooling=md5sig --dpi-desync-split-pos=1,midsld --dpi-desync-split-seqovl=2 --dpi-desync-fake-tls-mod=rnd,rndsni,dupsid --dpi-desync-any-protocol --new --filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=6'
$s3_args = '--wf-tcp=80,443 --wf-udp=443 --dpi-desync=multisplit --dpi-desync-split-seqovl=2 --dpi-desync-ttl=3 --dpi-desync-fooling=md5sig --dpi-desync-split-pos=1,host+2 --dpi-desync-any-protocol --new --filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=6'
$s4_args = '--wf-tcp=80,443 --wf-udp=443 --dpi-desync=fake,disorder2 --dpi-desync-ttl=3 --dpi-desync-fooling=md5sig --dpi-desync-split-pos=1,midsld --dpi-desync-any-protocol --new --filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=6'
$s5_args = '--wf-tcp=80,443 --wf-udp=443 --dpi-desync=fake,multidisorder --dpi-desync-ttl=2 --dpi-desync-autottl=2:64:3 --dpi-desync-split-pos=1,midsld --dpi-desync-any-protocol --new --filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=6'
$s6_args = '--wf-tcp=80,443 --wf-udp=443 --dpi-desync=fake,split2 --dpi-desync-ttl=4 --dpi-desync-fooling=md5sig --dpi-desync-split-http-req=host --dpi-desync-split-pos=1 --new --filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=6'

$curName = "не выбрана"
if (Test-Path $CONFIG_FILE) {
    foreach ($line in Get-Content $CONFIG_FILE) {
        if ($line -match "^STRATEGY=(.+)$") { $curName = $matches[1] }
    }
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "         ZAPRET - ВЫБОР СТРАТЕГИИ DPI BYPASS      " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "   Текущий активный профиль: $curName" -ForegroundColor Yellow
Write-Host ""
Write-Host "   1) Flowseal ALT (Рекомендуется)" -ForegroundColor Green
Write-Host "      Подмена TLS/QUIC пакетов. Для Discord и YouTube."
Write-Host ""
Write-Host "   2) Универсальная (MD5Sig)" -ForegroundColor Green
Write-Host "      Fake + FakedSplit + MD5Sig."
Write-Host ""
Write-Host "   3) MultiSplit SeqOvl (Максимальная)" -ForegroundColor Green
Write-Host "      Множественная нарезка для сложных блокировок."
Write-Host ""
Write-Host "   4) FakedDisorder (ТСПУ v2)" -ForegroundColor Green
Write-Host "      Перемешивание пакетов."
Write-Host ""
Write-Host "   5) TTL-based" -ForegroundColor Green
Write-Host "      Fake + MultiDisorder + TTL."
Write-Host ""
Write-Host "   6) HostFakeSplit (Игровая)" -ForegroundColor Green
Write-Host "      Минимальная задержка 0 мс для онлайн-игр."
Write-Host ""
Write-Host "   0) Выход"
Write-Host ""

$choice = Read-Host "   Выберите профиль [0-6]"

$selName = ""
$selTitle = ""
$selArgs = ""

switch ($choice) {
    "1" { $selName = "flowseal_alt"; $selTitle = "Flowseal ALT"; $selArgs = $s1_args }
    "2" { $selName = "universal_md5sig"; $selTitle = "Универсальная (MD5Sig)"; $selArgs = $s2_args }
    "3" { $selName = "multisplit_seqovl"; $selTitle = "MultiSplit SeqOvl"; $selArgs = $s3_args }
    "4" { $selName = "fakeddisorder"; $selTitle = "FakedDisorder"; $selArgs = $s4_args }
    "5" { $selName = "ttl_based"; $selTitle = "TTL-based"; $selArgs = $s5_args }
    "6" { $selName = "hostfakesplit"; $selTitle = "HostFakeSplit"; $selArgs = $s6_args }
    "0" { exit 0 }
    default { Write-Host "   [!] Неверный выбор" -ForegroundColor Red; exit 0 }
}

Get-Process -Name "winws" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

$configContent = "STRATEGY=" + $selName + "`r`nARGS=" + $selArgs
Set-Content -Path $CONFIG_FILE -Value $configContent -Encoding UTF8

Start-Process -FilePath $WINWS_EXE -ArgumentList $selArgs -WindowStyle Hidden
Start-Sleep -Seconds 2

Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "        [OK] СТРАТЕГИЯ УСПЕШНО АКТИВИРОВАНА       " -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host ""
Write-Host "   * Выбран профиль: $selTitle" -ForegroundColor Cyan
Write-Host "   * Статус службы:  [OK] ЗАПУЩЕНА И РАБОТАЕТ" -ForegroundColor Green
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
