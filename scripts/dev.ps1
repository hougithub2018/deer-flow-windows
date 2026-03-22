#!/usr/bin/env pwsh
#
# dev.ps1 - Start all DeerFlow development services on Windows
#
# Must be run from the repo root directory.

param(
    [switch]$Prod
)

$ErrorActionPreference = "Continue"
$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $RepoRoot

# ── Stop existing services ────────────────────────────────────────────────────

Write-Host "Stopping existing services if any..." -ForegroundColor Yellow

# Kill by port (most reliable method on Windows)
$portsToFree = @(2024, 8001, 3000)
foreach ($port in $portsToFree) {
    $pids = cmd /c "netstat -ano | findstr :$port" 2>$null |
        Where-Object { $_ -match "LISTENING\s+(\d+)" } |
        ForEach-Object { $matches[1] } | Select-Object -Unique
    foreach ($procId in $pids) {
        cmd /c "taskkill /F /PID $procId /T" 2>$null | Out-Null
    }
}

# Also kill by process name as a fallback
$processesToKill = @("langgraph", "uvicorn", "next", "node")
foreach ($proc in $processesToKill) {
    Get-Process -Name $proc -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

Start-Sleep -Seconds 2

# Verify ports are free
$stalePorts = $false
foreach ($port in $portsToFree) {
    $check = cmd /c "netstat -ano | findstr :$port" 2>$null
    if ($check -match "LISTENING") {
        Write-Host "  WARNING: Port $port is still in use. You may need to close the application manually." -ForegroundColor Yellow
        $stalePorts = $true
    }
}

# Kill nginx
Get-Process -Name "nginx" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

# ── Banner ────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Starting DeerFlow Development Server" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

if ($Prod) {
    Write-Host "  Mode: PROD (hot-reload disabled)" -ForegroundColor Yellow
    Write-Host "  Tip:  run .\scripts\dev.ps1 to start in development mode" -ForegroundColor Gray
} else {
    Write-Host "  Mode: DEV  (hot-reload enabled)" -ForegroundColor Green
    Write-Host "  Tip:  run .\scripts\dev.ps1 -Prod to start in production mode" -ForegroundColor Gray
}
Write-Host ""
Write-Host "Services starting up..."
Write-Host "  -> Backend: LangGraph + Gateway"
Write-Host "  -> Frontend: Next.js"
Write-Host "  -> (nginx optional: install from https://nginx.org/en/download.html)"
Write-Host ""

# ── Config check ─────────────────────────────────────────────────────────────

$hasConfig = $false
if ($env:DEER_FLOW_CONFIG_PATH -and (Test-Path $env:DEER_FLOW_CONFIG_PATH)) {
    $hasConfig = $true
} elseif (Test-Path "backend\config.yaml") {
    $hasConfig = $true
} elseif (Test-Path "config.yaml") {
    $hasConfig = $true
}

if (-not $hasConfig) {
    Write-Host "No DeerFlow config file found." -ForegroundColor Red
    Write-Host ""
    Write-Host "  Run 'python scripts\configure.py' from the repo root to generate .\config.yaml"
    Write-Host "  Then set required model API keys in .env or your config file."
    exit 1
}

# ── Auto-upgrade config ──────────────────────────────────────────────────────

python scripts\config_upgrade.py

# ── Set environment variables ─────────────────────────────────────────────────

if (-not $env:DEER_FLOW_CONFIG_PATH) {
    if (Test-Path "config.yaml") {
        $env:DEER_FLOW_CONFIG_PATH = (Resolve-Path "config.yaml").Path
    } elseif (Test-Path "backend\config.yaml") {
        $env:DEER_FLOW_CONFIG_PATH = (Resolve-Path "backend\config.yaml").Path
    }
}

# ── Start services ────────────────────────────────────────────────────────────

New-Item -ItemType Directory -Force -Path "logs" | Out-Null

if ($Prod) {
    $langgraphExtraFlags = @("--no-reload")
    $gatewayExtraFlags = @()
} else {
    $langgraphExtraFlags = @()
    $gatewayExtraFlags = @("--reload", "--reload-include=*.yaml", "--reload-include=.env")
}

# 1. LangGraph Server
Write-Host "Starting LangGraph server..." -ForegroundColor White
$langgraphFlags = ($langgraphExtraFlags -join " ")
$langgraphJob = Start-Job -ScriptBlock {
    param($repoRoot, $configPath, $flags, $logPath)
    Set-Location "$repoRoot\backend"
    $env:NO_COLOR = "1"
    $env:DEER_FLOW_CONFIG_PATH = $configPath
    if (-not $env:DEER_FLOW_CONFIG_PATH) { $env:DEER_FLOW_CONFIG_PATH = "$repoRoot\config.yaml" }
    cmd /c "uv run langgraph dev --no-browser --allow-blocking $flags 2>&1" | Tee-Object -FilePath $logPath
} -ArgumentList $RepoRoot, $env:DEER_FLOW_CONFIG_PATH, $langgraphFlags, "$RepoRoot\logs\langgraph.log"

# Wait for LangGraph to start (poll port 2024 via netstat)
$started = $false
for ($i = 0; $i -lt 60; $i++) {
    Start-Sleep -Seconds 1
    $check = cmd /c "netstat -ano | findstr :2024 | findstr LISTENING" 2>$null
    if ($check) { $started = $true; break }
    # Check if the job failed
    if ($langgraphJob.State -eq "Failed") {
        Write-Host "LangGraph server failed to start:" -ForegroundColor Red
        Receive-Job $langgraphJob 2>&1 | Select-Object -Last 20 | ForEach-Object { Write-Host "  $_" }
        Stop-Job $langgraphJob -ErrorAction SilentlyContinue
        exit 1
    }
}
if (-not $started) {
    Write-Host "LangGraph server failed to start within 60s." -ForegroundColor Red
    Write-Host "  See logs\langgraph.log for details"
    Stop-Job $langgraphJob -ErrorAction SilentlyContinue
    exit 1
}
Write-Host "  LangGraph server started on localhost:2024" -ForegroundColor Green

# 2. Gateway API
Write-Host "Starting Gateway API..." -ForegroundColor White
$gatewayFlags = ($gatewayExtraFlags -join " ")
$gatewayJob = Start-Job -ScriptBlock {
    param($repoRoot, $configPath, $flags, $logPath)
    Set-Location "$repoRoot\backend"
    $env:PYTHONPATH = "."
    $env:DEER_FLOW_CONFIG_PATH = $configPath
    cmd /c "uv run uvicorn app.gateway.app:app --host 0.0.0.0 --port 8001 $flags 2>&1" | Tee-Object -FilePath $logPath
} -ArgumentList $RepoRoot, $env:DEER_FLOW_CONFIG_PATH, $gatewayFlags, "$RepoRoot\logs\gateway.log"

# Wait for Gateway (poll port 8001 via netstat)
$started = $false
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 1
    $check = cmd /c "netstat -ano | findstr :8001 | findstr LISTENING" 2>$null
    if ($check) { $started = $true; break }
    if ($gatewayJob.State -eq "Failed") {
        Write-Host "Gateway API failed to start:" -ForegroundColor Red
        Receive-Job $gatewayJob 2>&1 | Select-Object -Last 20 | ForEach-Object { Write-Host "  $_" }
        Stop-Job $gatewayJob -ErrorAction SilentlyContinue
        exit 1
    }
}
if (-not $started) {
    Write-Host "Gateway API failed to start within 30s." -ForegroundColor Red
    Write-Host "  See logs\gateway.log for details"
    Stop-Job $langgraphJob -ErrorAction SilentlyContinue
    Stop-Job $gatewayJob -ErrorAction SilentlyContinue
    exit 1
}
Write-Host "  Gateway API started on localhost:8001" -ForegroundColor Green

# 3. Frontend
Write-Host "Starting Frontend..." -ForegroundColor White
$frontendJob = Start-Job -ScriptBlock {
    param($repoRoot, $prod, $logPath)
    Set-Location "$repoRoot\frontend"
    if ($prod) {
        pnpm run preview 2>&1 | Tee-Object -FilePath $logPath
    } else {
        pnpm run dev 2>&1 | Tee-Object -FilePath $logPath
    }
} -ArgumentList $RepoRoot, $Prod.IsPresent, "$RepoRoot\logs\frontend.log"

# Wait for Frontend (poll port 3000 via netstat)
$started = $false
for ($i = 0; $i -lt 120; $i++) {
    Start-Sleep -Seconds 1
    $check = cmd /c "netstat -ano | findstr :3000 | findstr LISTENING" 2>$null
    if ($check) { $started = $true; break }
    if ($frontendJob.State -eq "Failed") {
        Write-Host "Frontend failed to start:" -ForegroundColor Red
        Receive-Job $frontendJob 2>&1 | Select-Object -Last 20 | ForEach-Object { Write-Host "  $_" }
        Stop-Job $frontendJob -ErrorAction SilentlyContinue
        exit 1
    }
}
if (-not $started) {
    Write-Host "Frontend failed to start within 120s." -ForegroundColor Red
    Write-Host "  See logs\frontend.log for details"
    Stop-Job $langgraphJob -ErrorAction SilentlyContinue
    Stop-Job $gatewayJob -ErrorAction SilentlyContinue
    Stop-Job $frontendJob -ErrorAction SilentlyContinue
    exit 1
}
Write-Host "  Frontend started on localhost:3000" -ForegroundColor Green

# ── Ready ─────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
if ($Prod) {
    Write-Host "  DeerFlow production server is running!" -ForegroundColor Cyan
} else {
    Write-Host "  DeerFlow development server is running!" -ForegroundColor Cyan
}
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Application:   http://localhost:3000" -ForegroundColor White
Write-Host "  API Gateway:   http://localhost:8001" -ForegroundColor White
Write-Host "  LangGraph:     http://localhost:2024" -ForegroundColor White
Write-Host ""

if (Get-Command "nginx" -ErrorAction SilentlyContinue) {
    Write-Host "  (If nginx is installed, access via http://localhost:2026)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "  Logs:" -ForegroundColor Gray
Write-Host "     - LangGraph: logs\langgraph.log" -ForegroundColor Gray
Write-Host "     - Gateway:   logs\gateway.log" -ForegroundColor Gray
Write-Host "     - Frontend:  logs\frontend.log" -ForegroundColor Gray
Write-Host ""
Write-Host "Press Ctrl+C to stop all services" -ForegroundColor Yellow

# Wait for Ctrl+C
try {
    while ($true) {
        Start-Sleep -Seconds 5

        # Check if any job failed
        $failedJobs = @($langgraphJob, $gatewayJob, $frontendJob) | Where-Object { $_.State -eq "Failed" }
        if ($failedJobs.Count -gt 0) {
            Write-Host ""
            Write-Host "One or more services failed. Check logs/ directory for details." -ForegroundColor Red
            break
        }
    }
} finally {
    Write-Host ""
    Write-Host "Shutting down services..." -ForegroundColor Yellow
    Stop-Job $langgraphJob -ErrorAction SilentlyContinue
    Stop-Job $gatewayJob -ErrorAction SilentlyContinue
    Stop-Job $frontendJob -ErrorAction SilentlyContinue
    Remove-Job $langgraphJob -Force -ErrorAction SilentlyContinue
    Remove-Job $gatewayJob -Force -ErrorAction SilentlyContinue
    Remove-Job $frontendJob -Force -ErrorAction SilentlyContinue
    Write-Host "All services stopped." -ForegroundColor Green
}
