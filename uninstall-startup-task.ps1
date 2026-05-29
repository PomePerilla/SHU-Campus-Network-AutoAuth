Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$TaskName = "SHUCampusNetworkAutoAuth"
$TaskPath = "\SHU NetAuth\"
$LegacyTaskPath = "\SHU Campus Network AutoAuth\"

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdministrator)) {
    throw "Administrator PowerShell is required to uninstall the startup task."
}

$removed = $false
foreach ($path in @($TaskPath, $LegacyTaskPath)) {
    $task = Get-ScheduledTask -TaskPath $path -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($task) {
        Unregister-ScheduledTask -TaskPath $path -TaskName $TaskName -Confirm:$false
        Write-Host "Scheduled task removed:"
        Write-Host "  $path$TaskName"
        $removed = $true
    }
}

if (-not $removed) {
    Write-Host "Scheduled task does not exist:"
    Write-Host "  $TaskPath$TaskName"
}
