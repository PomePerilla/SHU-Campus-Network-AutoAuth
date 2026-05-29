Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$LoginScript = Join-Path $ProjectRoot "scripts\Invoke-SHUAutoAuth.ps1"
$ConfigPath = Join-Path $ProjectRoot "config\portal.json"
$PasswordPath = Join-Path $ProjectRoot "config\portal.password.bin"
$LogDir = Join-Path $ProjectRoot "logs"
$LogPath = Join-Path $LogDir "shu-netauth.log"
$TaskName = "SHUCampusNetworkAutoAuth"
$TaskPath = "\SHU NetAuth\"

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
    throw "Administrator PowerShell is required to install the startup task."
}

if (-not (Test-Path $LoginScript)) {
    throw "Login script not found: $LoginScript"
}

if (-not (Test-Path $ConfigPath) -or -not (Test-Path $PasswordPath)) {
    throw "Configuration is missing. Run configure.ps1 first."
}

$powerShell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
$arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$LoginScript`""

$action = New-ScheduledTaskAction -Execute $powerShell -Argument $arguments
$startupTrigger = New-ScheduledTaskTrigger -AtStartup
$repeatTrigger = New-ScheduledTaskTrigger `
    -Once `
    -At ((Get-Date).AddMinutes(1)) `
    -RepetitionInterval (New-TimeSpan -Minutes 5) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

$principal = New-ScheduledTaskPrincipal `
    -UserId "SYSTEM" `
    -LogonType ServiceAccount `
    -RunLevel Highest

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew

Register-ScheduledTask `
    -TaskName $TaskName `
    -TaskPath $TaskPath `
    -Action $action `
    -Trigger @($startupTrigger, $repeatTrigger) `
    -Principal $principal `
    -Settings $settings `
    -Description "Shanghai University campus network automatic authentication service." `
    -Force | Out-Null
Write-AppLog -Message "Scheduled task registered: $TaskPath$TaskName"

$legacyTaskPath = "\SHU Campus Network AutoAuth\"
$legacyTask = Get-ScheduledTask -TaskPath $legacyTaskPath -TaskName $TaskName -ErrorAction SilentlyContinue
if ($legacyTask) {
    Unregister-ScheduledTask -TaskPath $legacyTaskPath -TaskName $TaskName -Confirm:$false
    Write-AppLog -Message "Legacy scheduled task removed: $legacyTaskPath$TaskName"
}

Write-Host "Startup task installed."
