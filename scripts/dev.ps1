<#
.SYNOPSIS
  Launches bybit-adapter (port 3000) and Astras dev server (port 4200) with one command.

.DESCRIPTION
  Frees ports 3000 and 4200 first (kills any stale ng serve / npm run dev that
  did not shut down cleanly), then spawns each process in its own PowerShell
  window so the logs are readable.

  Run from PowerShell:
      .\scripts\dev.ps1

  If PowerShell blocks script execution, run once:
      Set-ExecutionPolicy -Scope CurrentUser RemoteSigned

  To stop: close the two spawned windows (or Ctrl+C in each). Re-running this
  script also kills the old processes before starting new ones.
#>

$ErrorActionPreference = 'Continue'
$root = Split-Path $PSScriptRoot -Parent

function Stop-Port {
    param([int]$Port, [string]$Label)
    $conns = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
    if (-not $conns) {
        Write-Host "[port $Port] free ($Label)" -ForegroundColor DarkGray
        return
    }
    $pids = $conns | Select-Object -ExpandProperty OwningProcess -Unique
    foreach ($processId in $pids) {
        try {
            $proc = Get-Process -Id $processId -ErrorAction Stop
            Write-Host "[port $Port] killing PID $processId ($($proc.ProcessName))" -ForegroundColor Yellow
            Stop-Process -Id $processId -Force -ErrorAction Stop
        } catch {
            Write-Host "[port $Port] could not kill PID ${processId}: $_" -ForegroundColor Red
        }
    }
    Start-Sleep -Milliseconds 600
}

Write-Host '=== mm-bot dev launcher ===' -ForegroundColor Cyan
Stop-Port -Port 3000 -Label 'bybit-adapter'
Stop-Port -Port 4200 -Label 'astras dev server'

$adapterPath = Join-Path $root 'bybit-adapter'
$astrasPath  = Join-Path $root 'astras-bybit-ui'

if (-not (Test-Path $adapterPath)) {
    Write-Host "FATAL: $adapterPath not found. Clone bybit-adapter first." -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $astrasPath)) {
    Write-Host "FATAL: $astrasPath not found. Clone astras-bybit-ui first." -ForegroundColor Red
    exit 1
}

# Spawn adapter in a dedicated window
$adapterCmd = "`$Host.UI.RawUI.WindowTitle='bybit-adapter (port 3000)'; Set-Location '$adapterPath'; npm run dev"
Start-Process powershell -ArgumentList '-NoExit', '-Command', $adapterCmd | Out-Null
Write-Host '[spawn] bybit-adapter window opened (port 3000)' -ForegroundColor Green

# Wait for adapter /health so Astras does not race it
Write-Host '[wait] adapter health check...' -ForegroundColor DarkGray
$ready = $false
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Milliseconds 500
    try {
        $r = Invoke-WebRequest -Uri 'http://127.0.0.1:3000/health' -UseBasicParsing -TimeoutSec 1 -ErrorAction Stop
        if ($r.StatusCode -eq 200) { $ready = $true; break }
    } catch { }
}
if ($ready) {
    Write-Host '[wait] adapter healthy.' -ForegroundColor Green
} else {
    Write-Host '[wait] adapter did not respond within 15s — continuing anyway, check the adapter window for errors.' -ForegroundColor Yellow
}

# Spawn Astras in a dedicated window
$astrasCmd = "`$Host.UI.RawUI.WindowTitle='astras-bybit-ui (port 4200)'; Set-Location '$astrasPath'; pnpm start"
Start-Process powershell -ArgumentList '-NoExit', '-Command', $astrasCmd | Out-Null
Write-Host '[spawn] astras dev server window opened (port 4200)' -ForegroundColor Green

Write-Host ''
Write-Host '=== Ready ===' -ForegroundColor Cyan
Write-Host '  adapter: http://127.0.0.1:3000  (REST + WS /ws, /cws)'
Write-Host '  astras:  http://localhost:4200  (open in Chrome after ng builds, ~35s)'
Write-Host ''
Write-Host 'To stop: close the two new windows, or re-run this script.' -ForegroundColor DarkGray
