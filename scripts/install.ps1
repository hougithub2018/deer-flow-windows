#!/usr/bin/env pwsh
#
# install.ps1 - Install all DeerFlow dependencies on Windows
#
# Must be run from the repo root directory.

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $RepoRoot

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Installing DeerFlow Dependencies" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Check prerequisites
$missingTools = @()

if (-not (Get-Command "node" -ErrorAction SilentlyContinue)) {
    $missingTools += "Node.js (v22+) - https://nodejs.org/"
}
if (-not (Get-Command "pnpm" -ErrorAction SilentlyContinue)) {
    $missingTools += "pnpm - run: npm install -g pnpm"
}
if (-not (Get-Command "uv" -ErrorAction SilentlyContinue)) {
    $missingTools += "uv - https://docs.astral.sh/uv/getting-started/installation/"
}

if ($missingTools.Count -gt 0) {
    Write-Host "Missing prerequisites:" -ForegroundColor Red
    foreach ($tool in $missingTools) {
        Write-Host "  - $tool" -ForegroundColor Yellow
    }
    exit 1
}

# Install backend dependencies
Write-Host "Installing backend dependencies..." -ForegroundColor White
Set-Location "$RepoRoot\backend"
uv sync
if ($LASTEXITCODE -ne 0) {
    Write-Host "Backend dependency installation failed!" -ForegroundColor Red
    exit 1
}
Write-Host "  Backend dependencies installed." -ForegroundColor Green

# Install frontend dependencies
Write-Host "Installing frontend dependencies..." -ForegroundColor White
Set-Location "$RepoRoot\frontend"
pnpm install
if ($LASTEXITCODE -ne 0) {
    Write-Host "Frontend dependency installation failed!" -ForegroundColor Red
    exit 1
}
Write-Host "  Frontend dependencies installed." -ForegroundColor Green

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  All dependencies installed!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. Run 'python scripts\configure.py' to generate config.yaml"
Write-Host "  2. Edit config.yaml to set your model API keys"
Write-Host "  3. Run '.\scripts\dev.ps1' to start the development server"
Write-Host ""
