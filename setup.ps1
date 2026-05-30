param([switch]$Elevated)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSCommandPath
$TaskName = "SHUCampusNetworkAutoAuth"
$TaskPath = "\SHU NetAuth\"
$ConfigPath = Join-Path $ProjectRoot "config\portal.json"
$PasswordPath = Join-Path $ProjectRoot "config\portal.password.bin"
$ConfigureScript = Join-Path $ProjectRoot "configure.ps1"
$InstallScript = Join-Path $ProjectRoot "install-startup-task.ps1"
$TestScript = Join-Path $ProjectRoot "test-login.ps1"
$LogDir = Join-Path $ProjectRoot "logs"
$LogPath = Join-Path $LogDir "shu-netauth.log"

function Write-AppLog {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$Component = "setup"
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

function Start-Elevated {
    $powerShell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
    $arguments = @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        "`"$PSCommandPath`"",
        "-Elevated"
    )

    Start-Process `
        -FilePath $powerShell `
        -ArgumentList $arguments `
        -WorkingDirectory $ProjectRoot `
        -Verb RunAs
}

function Write-Section {
    param([string]$Title)

    Write-Host ""
    Write-Host "== $Title ==" -ForegroundColor Cyan
}

function Write-Item {
    param(
        [string]$Name,
        [string]$Value
    )

    Write-Host ("{0,-28} {1}" -f ($Name + ":"), $Value)
}

function Test-HttpProbe {
    param(
        [string]$Url,
        [string]$ExpectedContent = ""
    )

    try {
        $response = Invoke-WebRequest -Uri $Url -TimeoutSec 8 -UseBasicParsing -MaximumRedirection 5
        $matched = $true
        if (-not [string]::IsNullOrWhiteSpace($ExpectedContent)) {
            $matched = [string]$response.Content -like "*$ExpectedContent*"
        }

        $category = "reachable"
        if ($response.BaseResponse -and $response.BaseResponse.ResponseUri) {
            $finalUrl = $response.BaseResponse.ResponseUri.AbsoluteUri
            if ($finalUrl -like "*/eportal/index.jsp?*") {
                $category = "ePortal login page"
            }
            elseif ($finalUrl -like "*/eportal/success.jsp*") {
                $category = "ePortal success page"
            }
        }

        return [pscustomobject]@{
            Success = $matched
            StatusCode = [int]$response.StatusCode
            Category = $category
            Error = ""
        }
    }
    catch {
        Write-AppLog -Level "WARN" -Message "HTTP probe failed. Url=$Url Error=$($_.Exception.Message)"
        return [pscustomobject]@{
            Success = $false
            StatusCode = 0
            Category = "unavailable"
            Error = $_.Exception.Message
        }
    }
}

function Show-UserStatus {
    Write-Section "Project Status"
    $configExists = Test-Path $ConfigPath
    $passwordExists = Test-Path $PasswordPath
    Write-Item "Config" $(if ($configExists) { "Ready" } else { "Not configured" })
    Write-Item "Password" $(if ($passwordExists) { "Ready" } else { "Not configured" })

    $task = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction SilentlyContinue
    Write-Item "Startup task" $(if ($task) { "Installed" } else { "Not installed" })
    if ($task) {
        try {
            $taskInfo = Get-ScheduledTaskInfo -TaskPath $TaskPath -TaskName $TaskName
            Write-AppLog -Message "Task status checked. State=$($task.State) LastRun=$($taskInfo.LastRunTime) LastResult=$($taskInfo.LastTaskResult)"
        }
        catch {
            Write-AppLog -Level "WARN" -Message "Could not read task info: $($_.Exception.Message)"
        }
    }

    Write-Section "Network Status"
    $internet = Test-HttpProbe `
        -Url "http://www.msftconnecttest.com/connecttest.txt" `
        -ExpectedContent "Microsoft Connect Test"
    Write-Item "Internet" $(if ($internet.Success) { "Available" } else { "Unavailable" })
    Write-AppLog -Message "Internet probe finished. Success=$($internet.Success) Status=$($internet.StatusCode) Category=$($internet.Category)"

    $portal = Test-HttpProbe -Url "http://10.10.9.9/"
    Write-Item "Portal gateway" $(if ($portal.Success) { "Reachable" } else { "Unavailable" })
    Write-AppLog -Message "Portal probe finished. Success=$($portal.Success) Status=$($portal.StatusCode) Category=$($portal.Category)"
}

function Invoke-SetupStep {
    param(
        [string]$Name,
        [scriptblock]$Action
    )

    Write-Section $Name
    & $Action
}

function Show-FinalStatus {
    Show-UserStatus
    Write-Item "Detailed logs" $LogPath
}

if (-not (Test-IsAdministrator)) {
    Write-Host "Administrator permission is required. A Windows UAC prompt will open." -ForegroundColor Yellow
    Write-AppLog -Message "Setup started without administrator permission. Requesting elevation."
    Start-Elevated
    exit 0
}

try {
    Set-Location -LiteralPath $ProjectRoot
    $host.UI.RawUI.WindowTitle = "SHU NetAuth Setup"

    Write-AppLog -Message "Setup wizard started."
    Write-Host "SHU NetAuth v1.1.1 Setup" -ForegroundColor Green
    Write-Host "This wizard will configure SHU NetAuth and keep detailed logs in logs\shu-netauth.log."

    Show-UserStatus

    Write-Host ""
    Read-Host "Press Enter to start configuration, or close this window to cancel"

    Invoke-SetupStep -Name "Configure" -Action {
        Write-AppLog -Message "Configure step started."
        & $ConfigureScript
        Write-AppLog -Message "Configure step completed."
    }

    Invoke-SetupStep -Name "Install Startup Task" -Action {
        Write-AppLog -Message "Install task step started."
        & $InstallScript
        Write-AppLog -Message "Install task step completed."
    }

    Invoke-SetupStep -Name "Test Login Script" -Action {
        Write-AppLog -Message "Test login step started."
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $TestScript
        $testExitCode = $LASTEXITCODE
        Write-AppLog -Message "Test login step completed. ExitCode=$testExitCode"
        if ($testExitCode -ne 0) {
            throw "Authentication test failed. See logs\shu-netauth.log for details."
        }
    }

    Write-Host ""
    Write-Host "SUCCESS" -ForegroundColor Green
    Write-Host "SHU NetAuth is installed and ready."
    Write-Host "Detailed logs: logs\shu-netauth.log"
    Write-AppLog -Message "Setup completed successfully."
    Read-Host "Press Enter to close"
}
catch {
    Write-Host ""
    Write-Host "SETUP NEEDS ATTENTION" -ForegroundColor Red
    Write-Host "Please check the ePortal login URL and run setup again."
    Write-Host "Detailed logs: logs\shu-netauth.log"
    Write-AppLog -Level "ERROR" -Message "Setup failed: $($_.Exception.Message)"
    Write-Host ""
    Read-Host "Press Enter to close"
    exit 1
}
