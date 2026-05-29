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
$LogPath = Join-Path $ProjectRoot "logs\shu-autoauth.log"

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
        }
    }
    catch {
        return [pscustomobject]@{
            Success = $false
            StatusCode = 0
            Category = $_.Exception.Message
        }
    }
}

function Show-SystemStatus {
    Write-Section "System"
    $os = Get-CimInstance Win32_OperatingSystem
    Write-Item "OS" "$($os.Caption) $($os.Version)"
    Write-Item "PowerShell" "$($PSVersionTable.PSVersion)"
    Write-Item "Administrator" "$(Test-IsAdministrator)"
    Write-Item "Project path" $ProjectRoot
    Write-Item "Config exists" "$(Test-Path $ConfigPath)"
    Write-Item "Password exists" "$(Test-Path $PasswordPath)"

    Write-Section "Network"
    if (Get-Command Get-NetAdapter -ErrorAction SilentlyContinue) {
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 6
        if ($adapters) {
            foreach ($adapter in $adapters) {
                Write-Item "Adapter" "$($adapter.Name) / $($adapter.InterfaceDescription) / $($adapter.LinkSpeed)"
            }
        }
        else {
            Write-Item "Adapter" "No active adapter reported"
        }
    }
    else {
        Write-Item "Adapter" "Get-NetAdapter unavailable"
    }

    $internet = Test-HttpProbe `
        -Url "http://www.msftconnecttest.com/connecttest.txt" `
        -ExpectedContent "Microsoft Connect Test"
    Write-Item "Internet test" "$($internet.Success) / HTTP $($internet.StatusCode) / $($internet.Category)"

    $portal = Test-HttpProbe -Url "http://10.10.9.9/"
    Write-Item "Portal gateway" "$($portal.Success) / HTTP $($portal.StatusCode) / $($portal.Category)"

    Write-Section "Scheduled Task"
    $task = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($task) {
        Write-Item "Task" "$TaskPath$TaskName"
        Write-Item "State" "$($task.State)"
        try {
            $taskInfo = Get-ScheduledTaskInfo -TaskPath $TaskPath -TaskName $TaskName
            Write-Item "Last run" "$($taskInfo.LastRunTime)"
            Write-Item "Last result" "$($taskInfo.LastTaskResult)"
        }
        catch {
            Write-Item "Task info" $_.Exception.Message
        }
    }
    else {
        Write-Item "Task" "Not installed"
    }
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
    Show-SystemStatus

    if (Test-Path $LogPath) {
        Write-Section "Recent Log"
        Get-Content -LiteralPath $LogPath -Tail 20
    }
}

if (-not (Test-IsAdministrator)) {
    Write-Host "Administrator permission is required. A Windows UAC prompt will open." -ForegroundColor Yellow
    Start-Elevated
    exit 0
}

try {
    Set-Location -LiteralPath $ProjectRoot
    $host.UI.RawUI.WindowTitle = "SHU Campus Network AutoAuth Setup"

    Write-Host "SHU NetAuth v1.0.0 Setup" -ForegroundColor Green
    Write-Host "This wizard will configure credentials, install the startup task, run a test, and report status."

    Show-SystemStatus

    Write-Host ""
    Read-Host "Press Enter to start configuration, or close this window to cancel"

    Invoke-SetupStep -Name "Configure" -Action {
        & $ConfigureScript
    }

    Invoke-SetupStep -Name "Install Startup Task" -Action {
        & $InstallScript
    }

    Invoke-SetupStep -Name "Test Login Script" -Action {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $TestScript
        $testExitCode = $LASTEXITCODE
        Write-Item "Test exit code" "$testExitCode"
    }

    Write-Section "Final Status"
    Show-FinalStatus

    Write-Host ""
    Write-Host "Setup finished." -ForegroundColor Green
    Read-Host "Press Enter to close"
}
catch {
    Write-Host ""
    Write-Host "Setup failed:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to close"
    exit 1
}
