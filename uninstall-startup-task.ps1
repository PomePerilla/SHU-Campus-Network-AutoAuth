Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$TaskName = "SHUCampusNetworkAutoAuth"
$TaskPath = "\SHU NetAuth\"
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogDir = Join-Path $ProjectRoot "logs"
$LogPath = Join-Path $LogDir "shu-netauth.log"

function Write-AppLog {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$Component = "task"
    )

    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -LiteralPath $LogPath -Value "[$timestamp] [$Level] [$Component] $Message" -Encoding UTF8
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdministrator)) {
    throw "Administrator PowerShell is required to uninstall the startup task."
}

$task = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction SilentlyContinue
if ($task) {
    Unregister-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -Confirm:$false
    Write-AppLog -Message "Scheduled task removed: $TaskPath$TaskName"
    Write-Host "Scheduled task removed:"
    Write-Host "  $TaskPath$TaskName"
}
else {
    Write-Host "Scheduled task does not exist:"
    Write-Host "  $TaskPath$TaskName"
}

$legacyTaskPath = "\SHU Campus Network AutoAuth\"
$legacyTask = Get-ScheduledTask -TaskPath $legacyTaskPath -TaskName $TaskName -ErrorAction SilentlyContinue
if ($legacyTask) {
    Unregister-ScheduledTask -TaskPath $legacyTaskPath -TaskName $TaskName -Confirm:$false
    Write-AppLog -Message "Legacy scheduled task removed: $legacyTaskPath$TaskName"
    Write-Host "Legacy scheduled task removed:"
    Write-Host "  $legacyTaskPath$TaskName"
}
