Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$LoginScript = Join-Path $ProjectRoot "scripts\Invoke-SHUAutoAuth.ps1"
$LogPath = Join-Path $ProjectRoot "logs\shu-autoauth.log"

if (-not (Test-Path $LoginScript)) {
    throw "Login script not found: $LoginScript"
}

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $LoginScript
$exitCode = $LASTEXITCODE

Write-Host "Exit code: $exitCode"

if (Test-Path $LogPath) {
    Write-Host ""
    Write-Host "Recent log:"
    Get-Content -LiteralPath $LogPath -Tail 20
}

exit $exitCode
