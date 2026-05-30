param(
    [string]$ConfigPath,
    [switch]$ShowUrl,
    [switch]$OnlyUrl,
    [switch]$VerboseInfo,
    [switch]$Headed,
    [string]$BrowserChannel = "msedge",
    [int]$WaitSeconds = 5
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptRoot
if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path $ProjectRoot "config\portal.json"
}

$LogDir = Join-Path $ProjectRoot "logs"
$LogPath = Join-Path $LogDir "shu-netauth.log"
$NodeScript = Join-Path $ScriptRoot "detect-portal-url.mjs"

function Write-DetectorLog {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    if (-not (Test-Path -LiteralPath $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -LiteralPath $LogPath -Value "[$timestamp] [$Level] [playwright-detector] $Message" -Encoding UTF8
}

function Get-ConfigValue {
    param(
        [pscustomobject]$Config,
        [string]$Name,
        [string]$Default = ""
    )

    if ($Config -and $Config.PSObject.Properties.Name -contains $Name -and -not [string]::IsNullOrWhiteSpace([string]$Config.$Name)) {
        return [string]$Config.$Name
    }

    return $Default
}

function Get-NodePath {
    $command = Get-Command node -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $codexNode = Join-Path $env:USERPROFILE ".cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe"
    if (Test-Path -LiteralPath $codexNode) {
        return $codexNode
    }

    throw "Node.js was not found. Install Node.js or run this from an environment that provides Node.js."
}

function Add-NodeModulePath {
    $paths = @()

    $localNodeModules = Join-Path $ProjectRoot "node_modules"
    if (Test-Path -LiteralPath $localNodeModules) {
        $paths += $localNodeModules
    }

    $codexNodeModules = Join-Path $env:USERPROFILE ".cache\codex-runtimes\codex-primary-runtime\dependencies\node\node_modules"
    if (Test-Path -LiteralPath $codexNodeModules) {
        $paths += $codexNodeModules
    }

    if ($paths.Count -gt 0) {
        $existing = [string]$env:NODE_PATH
        if (-not [string]::IsNullOrWhiteSpace($existing)) {
            $paths += $existing
        }

        $env:NODE_PATH = ($paths | Select-Object -Unique) -join [IO.Path]::PathSeparator
    }
}

function Get-ResultValue {
    param(
        [pscustomobject]$Result,
        [string]$Name,
        [string]$Default = ""
    )

    if ($Result -and $Result.PSObject.Properties.Name -contains $Name -and $null -ne $Result.$Name) {
        return [string]$Result.$Name
    }

    return $Default
}

if (Test-Path -LiteralPath $ConfigPath) {
    $config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
}
else {
    $config = Get-Content -LiteralPath (Join-Path $ProjectRoot "config\portal.example.json") -Raw -Encoding UTF8 | ConvertFrom-Json
}

$startUrl = Get-ConfigValue -Config $config -Name "PortalGatewayUrl" -Default "http://10.10.9.9/"
if ($startUrl -notmatch "^https?://") {
    $startUrl = "http://$startUrl"
}

$nodePath = Get-NodePath
Add-NodeModulePath

$arguments = @(
    $NodeScript,
    "--url",
    $startUrl,
    "--wait-ms",
    ([string]($WaitSeconds * 1000)),
    "--timeout-ms",
    "15000",
    "--channel",
    $BrowserChannel
)

if ($Headed) {
    $arguments += "--headed"
}

Write-DetectorLog -Message "Starting Playwright detector from $startUrl with WaitSeconds=$WaitSeconds."
$rawOutput = & $nodePath @arguments
$exitCode = $LASTEXITCODE

$result = $null
try {
    $result = ($rawOutput -join "`n") | ConvertFrom-Json
}
catch {
    Write-DetectorLog -Level "WARN" -Message "Detector returned non-JSON output."
    Write-Host "Portal URL detector failed"
    Write-Host "Reason: detector returned non-JSON output"
    Write-Host "Log: $LogPath"
    exit 1
}

if ($OnlyUrl) {
    if ($result.success) {
        Write-Output (Get-ResultValue -Result $result -Name "finalUrl")
        exit 0
    }

    if ((Get-ResultValue -Result $result -Name "state") -eq "already-authenticated") {
        exit 2
    }

    exit 1
}

if ($result.success) {
    Write-DetectorLog -Message "Detected candidate URL at $($result.safeUrl). QueryLength=$($result.queryLength) MatchedKeyCount=$($result.matchedKeyCount)."
}
elseif ((Get-ResultValue -Result $result -Name "state") -eq "already-authenticated") {
    Write-DetectorLog -Message "Portal is already authenticated at $(Get-ResultValue -Result $result -Name "safeUrl")."
}
else {
    $reason = Get-ResultValue -Result $result -Name "error" -Default "Final URL did not match the ePortal long URL format."
    $finalSafeUrl = Get-ResultValue -Result $result -Name "safeUrl" -Default ""
    $title = Get-ResultValue -Result $result -Name "title" -Default ""
    Write-DetectorLog -Level "WARN" -Message "Detector failed. Reason=$reason Final=$finalSafeUrl Title=$title"
}

Write-Host "Portal URL detector result"
Write-Host "Success: $(Get-ResultValue -Result $result -Name "success" -Default "False")"
Write-Host "State: $(Get-ResultValue -Result $result -Name "state" -Default "unknown")"
Write-Host "Launch mode: $(Get-ResultValue -Result $result -Name "launchMode" -Default "unknown")"
Write-Host "Start URL: $(Get-ResultValue -Result $result -Name "startUrl" -Default $startUrl)"
Write-Host "Final safe URL: $(Get-ResultValue -Result $result -Name "safeUrl")"
Write-Host "Query length: $(Get-ResultValue -Result $result -Name "queryLength" -Default "0")"
Write-Host "Matched key count: $(Get-ResultValue -Result $result -Name "matchedKeyCount" -Default "0")"
Write-Host "Wait seconds: $WaitSeconds"
Write-Host "Log: $LogPath"

if ($VerboseInfo) {
    Write-Host "Title: $(Get-ResultValue -Result $result -Name "title")"
    Write-Host "Navigation error: $(Get-ResultValue -Result $result -Name "navigationError")"
}

if ($ShowUrl -and $result.success) {
    Write-Host ""
    Write-Host "Full URL:"
    Write-Host $result.finalUrl
}

if ($exitCode -eq 0 -and ($result.success -or (Get-ResultValue -Result $result -Name "state") -eq "already-authenticated")) {
    exit 0
}

exit 1
