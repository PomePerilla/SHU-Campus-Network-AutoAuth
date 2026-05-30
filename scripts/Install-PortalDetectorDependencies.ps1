param(
    [switch]$InstallChromium
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptRoot

function Invoke-ProjectCommand {
    param(
        [string]$Command,
        [string[]]$Arguments
    )

    Push-Location $ProjectRoot
    try {
        & $Command @Arguments
        if ($LASTEXITCODE -ne 0) {
            throw "$Command exited with code $LASTEXITCODE."
        }
    }
    finally {
        Pop-Location
    }
}

if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    throw "npm was not found. Install Node.js first."
}

Write-Host "Installing detector Node dependencies..."
Invoke-ProjectCommand -Command "npm" -Arguments @("install")

if ($InstallChromium) {
    Write-Host "Installing Playwright Chromium browser..."
    Invoke-ProjectCommand -Command "npx" -Arguments @("playwright", "install", "chromium")
}
else {
    Write-Host "Chromium download skipped. The detector will use Microsoft Edge by default."
    Write-Host "Run this script with -InstallChromium if you need a self-contained Playwright browser."
}

Write-Host "Done."
