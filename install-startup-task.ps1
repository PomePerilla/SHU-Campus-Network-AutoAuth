Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$LoginScript = Join-Path $ProjectRoot "scripts\Invoke-SHUAutoAuth.ps1"
$ConfigPath = Join-Path $ProjectRoot "config\portal.json"
$PasswordPath = Join-Path $ProjectRoot "config\portal.password.bin"
$TaskName = "SHUCampusNetworkAutoAuth"
$TaskPath = "\SHU NetAuth\"
$LegacyTaskPath = "\SHU Campus Network AutoAuth\"

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

$legacyTask = Get-ScheduledTask -TaskPath $LegacyTaskPath -TaskName $TaskName -ErrorAction SilentlyContinue
if ($legacyTask) {
    Unregister-ScheduledTask -TaskPath $LegacyTaskPath -TaskName $TaskName -Confirm:$false
    Write-Host "Removed legacy scheduled task:"
    Write-Host "  $LegacyTaskPath$TaskName"
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
    -Description "SHU NetAuth automatic campus network authentication service." `
    -Force | Out-Null

Write-Host "Scheduled task installed:"
Write-Host "  $TaskPath$TaskName"
Write-Host "The task runs at Windows startup as SYSTEM and checks every 5 minutes."
