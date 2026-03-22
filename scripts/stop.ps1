#!/usr/bin/env pwsh
#
# stop.ps1 - Stop all DeerFlow development services on Windows
#
# Must be run from the repo root directory.

$ErrorActionPreference = "Continue"
$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $RepoRoot

Write-Host "Stopping all DeerFlow services..." -ForegroundColor Yellow

# Kill by port (most reliable method)
$portsToFree = @(2024, 8001, 3000)
$killedCount = 0

foreach ($port in $portsToFree) {
    $pids = cmd /c "netstat -ano | findstr :$port" 2>$null |
        Where-Object { $_ -match "LISTENING\s+(\d+)" } |
        ForEach-Object { $matches[1] } | Select-Object -Unique
    foreach ($procId in $pids) {
        $result = cmd /c "taskkill /F /PID $procId /T" 2>&1
        if ($result -match "SUCCESS") {
            Write-Host "  Killed PID $procId on port $port" -ForegroundColor Gray
            $killedCount++
        }
    }
}

# Fallback: kill by process name
$processesToKill = @("langgraph", "uvicorn", "next", "node")
foreach ($proc in $processesToKill) {
    Get-Process -Name $proc -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

# Stop nginx
$nginxProc = Get-Process -Name "nginx" -ErrorAction SilentlyContinue
if ($nginxProc) {
    Stop-Process -Name "nginx" -Force -ErrorAction SilentlyContinue
    Write-Host "  Stopped nginx" -ForegroundColor Gray
}

Start-Sleep -Seconds 1

# Verify
$stalePorts = @()
foreach ($port in $portsToFree) {
    $check = cmd /c "netstat -ano | findstr :$port" 2>$null
    if ($check -match "LISTENING") {
        $stalePorts += $port
    }
}

if ($stalePorts.Count -gt 0) {
    Write-Host ""
    Write-Host "  WARNING: Ports $($stalePorts -join ', ') are still in use." -ForegroundColor Yellow
    Write-Host "  Please close all PowerShell/terminal windows and try again." -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "All services stopped." -ForegroundColor Green
}
