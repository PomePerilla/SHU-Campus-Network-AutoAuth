Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$TaskName = "SHUCampusNetworkAutoAuth"
$TaskPath = "\SHU Campus Network AutoAuth\"

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
    Write-Host "Scheduled task removed:"
    Write-Host "  $TaskPath$TaskName"
}
else {
    Write-Host "Scheduled task does not exist:"
    Write-Host "  $TaskPath$TaskName"
}
