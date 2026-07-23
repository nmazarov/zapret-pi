# ZAPRET Windows Diagnostic Script
Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "         ZAPRET - ДИАГНОСТИКА ДОСТУПНОСТИ         " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

$proc = Get-Process -Name "winws" -ErrorAction SilentlyContinue
if ($proc) {
    Write-Host "   * Служба WinWS:      [OK] ЗАПУЩЕНА (PID: $($proc.Id))" -ForegroundColor Green
} else {
    Write-Host "   * Служба WinWS:      [X] НЕ ЗАПУЩЕНА" -ForegroundColor Red
}

$targets = @(
    @{ Name = "Discord App"; Url = "https://discord.com" },
    @{ Name = "Discord Media"; Url = "https://cdn.discordapp.com" },
    @{ Name = "YouTube Main"; Url = "https://www.youtube.com" },
    @{ Name = "YouTube Video"; Url = "https://googlevideo.com" },
    @{ Name = "Notion"; Url = "https://www.notion.so" }
)

Write-Host ""
Write-Host "[Тестирование сайтов]" -ForegroundColor Yellow

foreach ($t in $targets) {
    Write-Host "   * $($t.Name)..." -ForegroundColor Yellow -NoNewline
    & curl.exe -4 -sL -I --connect-timeout 3 -m 4 $t.Url 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host " -> [OK] ДОСТУПЕН" -ForegroundColor Green
    } else {
        Write-Host " -> [X] БЛОКИРУЕТСЯ" -ForegroundColor Red
    }
}
Write-Host ""
