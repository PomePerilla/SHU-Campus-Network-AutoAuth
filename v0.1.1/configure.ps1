param(
    [string]$PortalUrl,
    [string]$Username,
    [string]$Service = "shu",
    [string]$PortalProbeUrl = "http://10.10.9.9/"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigDir = Join-Path $ProjectRoot "config"
$ConfigPath = Join-Path $ConfigDir "portal.json"
$PasswordPath = Join-Path $ConfigDir "portal.password.bin"

$DefaultPublicKeyExponent = "10001"
$DefaultPublicKeyModulus = "94dd2a8675fb779e6b9f7103698634cd400f27a154afa67af6166a43fc26417222a79506d34cacc7641946abda1785b7acf9910ad6a0978c91ec84d40b71d2891379af19ffb333e7517e390bd26ac312fe940c340466b4a5d4af1d65c3b5944078f96a1a51a5a53e4bc302818b7c9f63c4a1b07bd7d874cef1c3d4b2f5eb7871"

function Read-WithDefault {
    param(
        [string]$Prompt,
        [string]$Default
    )

    $value = Read-Host "$Prompt [$Default]"
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $Default
    }

    return $value.Trim()
}

function Read-RequiredString {
    param([string]$Prompt)

    while ($true) {
        $value = Read-Host $Prompt
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value.Trim()
        }

        Write-Host "This value is required. Please enter it again." -ForegroundColor Yellow
    }
}

function Read-RequiredSecureString {
    param([string]$Prompt)

    while ($true) {
        $value = Read-Host $Prompt -AsSecureString
        if ($null -ne $value -and $value.Length -gt 0) {
            return $value
        }

        Write-Host "Password is required. Please enter it again." -ForegroundColor Yellow
    }
}

function Convert-SecureStringToPlainText {
    param([securestring]$SecureString)

    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function Protect-MachineString {
    param([securestring]$SecureString)

    Add-Type -AssemblyName System.Security

    $plainText = Convert-SecureStringToPlainText -SecureString $SecureString
    $plainBytes = [Text.Encoding]::UTF8.GetBytes($plainText)

    try {
        $protectedBytes = [Security.Cryptography.ProtectedData]::Protect(
            $plainBytes,
            $null,
            [Security.Cryptography.DataProtectionScope]::LocalMachine
        )

        return [Convert]::ToBase64String($protectedBytes)
    }
    finally {
        [Array]::Clear($plainBytes, 0, $plainBytes.Length)
    }
}

function ConvertTo-FormValue {
    param([string]$Value)

    return [Uri]::EscapeDataString([Uri]::EscapeDataString($Value))
}

function Get-PortalBaseUrl {
    param([uri]$Uri)

    return "$($Uri.Scheme)://$($Uri.Authority)/eportal/"
}

function Test-IsUsablePortalUrl {
    param([string]$CandidateUrl)

    if ([string]::IsNullOrWhiteSpace($CandidateUrl)) {
        return $false
    }

    try {
        $candidate = [uri]$CandidateUrl
        return -not [string]::IsNullOrWhiteSpace($candidate.Query)
    }
    catch {
        return $false
    }
}

function ConvertTo-AbsolutePortalUrl {
    param(
        [string]$CandidateUrl,
        [uri]$BaseUri
    )

    if ($CandidateUrl -match "^https?://") {
        return $CandidateUrl
    }

    if ($CandidateUrl.StartsWith("/")) {
        return "$($BaseUri.Scheme)://$($BaseUri.Authority)$CandidateUrl"
    }

    return ([uri]::new($BaseUri, $CandidateUrl)).AbsoluteUri
}

function Find-PortalUrlInContent {
    param(
        [string]$Content,
        [uri]$BaseUri
    )

    if ([string]::IsNullOrWhiteSpace($Content)) {
        return $null
    }

    $decoded = [Net.WebUtility]::HtmlDecode($Content)

    foreach ($match in [regex]::Matches($decoded, 'https?://[^\s"''<>]+')) {
        $candidate = $match.Value
        if ($candidate -like "*/eportal/index.jsp?*" -and (Test-IsUsablePortalUrl -CandidateUrl $candidate)) {
            return $candidate
        }
    }

    foreach ($match in [regex]::Matches($decoded, '/eportal/index\.jsp\?[^\s"''<>]+')) {
        $candidate = ConvertTo-AbsolutePortalUrl -CandidateUrl $match.Value -BaseUri $BaseUri
        if (Test-IsUsablePortalUrl -CandidateUrl $candidate) {
            return $candidate
        }
    }

    return $null
}

function Find-PortalUrl {
    param([string]$ProbeUrl)

    $probeUri = [uri]$ProbeUrl
    $probeBase = "$($probeUri.Scheme)://$($probeUri.Authority)"
    $probeTargets = @(
        $ProbeUrl,
        "$probeBase/eportal/index.jsp",
        "http://123.123.123.123/"
    ) | Select-Object -Unique

    Write-Host "Trying to auto-detect the SHU ePortal login URL..."

    foreach ($target in $probeTargets) {
        try {
            Write-Host "  Probing $target"
            $response = Invoke-WebRequest `
                -Uri $target `
                -MaximumRedirection 5 `
                -TimeoutSec 15 `
                -UseBasicParsing

            if ($response.BaseResponse -and $response.BaseResponse.ResponseUri) {
                $finalUrl = $response.BaseResponse.ResponseUri.AbsoluteUri
                if ($finalUrl -like "*/eportal/index.jsp?*" -and (Test-IsUsablePortalUrl -CandidateUrl $finalUrl)) {
                    return $finalUrl
                }

                if ($finalUrl -like "*/eportal/success.jsp*") {
                    Write-Host "  The portal reports this device is already authenticated, so no login URL was returned." -ForegroundColor DarkYellow
                }
            }

            $foundUrl = Find-PortalUrlInContent -Content $response.Content -BaseUri ([uri]$target)
            if ($foundUrl) {
                return $foundUrl
            }
        }
        catch {
            Write-Host "  Probe failed: $($_.Exception.Message)" -ForegroundColor DarkYellow
        }
    }

    return $null
}

function Get-PageInfo {
    param(
        [string]$PortalBaseUrl,
        [string]$QueryString
    )

    $url = $PortalBaseUrl + "InterFace.do?method=pageInfo"
    $body = "queryString=$(ConvertTo-FormValue $QueryString)"

    try {
        $response = Invoke-WebRequest `
            -Uri $url `
            -Method Post `
            -Body $body `
            -ContentType "application/x-www-form-urlencoded; charset=UTF-8" `
            -TimeoutSec 15 `
            -UseBasicParsing

        return $response.Content | ConvertFrom-Json
    }
    catch {
        Write-Warning "Could not fetch ePortal pageInfo. The script will use built-in SHU defaults."
        return $null
    }
}

if (-not (Test-Path $ConfigDir)) {
    New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
}

Write-Host "SHU Campus Network AutoAuth CLI v0.1.1"
Write-Host ""

if ([string]::IsNullOrWhiteSpace($PortalUrl)) {
    $PortalUrl = Read-Host "Paste the full SHU campus network login page URL, or press Enter to auto-detect"
}

if ([string]::IsNullOrWhiteSpace($PortalUrl)) {
    $PortalUrl = Find-PortalUrl -ProbeUrl $PortalProbeUrl
    if ([string]::IsNullOrWhiteSpace($PortalUrl)) {
        throw "Could not auto-detect the portal URL. If this device is already online, log out from ePortal or paste a saved full ePortal login URL."
    }

    Write-Host "Detected portal URL:"
    Write-Host "  $PortalUrl"
}

if (-not (Test-IsUsablePortalUrl -CandidateUrl $PortalUrl)) {
    throw "Portal URL must include the query string after '?'. Please paste the full ePortal login URL."
}

$portalUri = [uri]$PortalUrl

if ([string]::IsNullOrWhiteSpace($Username)) {
    $Username = Read-RequiredString -Prompt "Campus network username"
}

$password = Read-RequiredSecureString -Prompt "Campus network password"
$Service = Read-WithDefault -Prompt "Service name" -Default $Service

$portalBaseUrl = Get-PortalBaseUrl -Uri $portalUri
$queryString = $portalUri.Query.TrimStart("?")
$pageInfo = Get-PageInfo -PortalBaseUrl $portalBaseUrl -QueryString $queryString

$publicKeyExponent = $DefaultPublicKeyExponent
$publicKeyModulus = $DefaultPublicKeyModulus
$passwordEncrypt = "true"

if ($null -ne $pageInfo) {
    if ($pageInfo.PSObject.Properties.Name -contains "publicKeyExponent" -and -not [string]::IsNullOrWhiteSpace($pageInfo.publicKeyExponent)) {
        $publicKeyExponent = [string]$pageInfo.publicKeyExponent
    }

    if ($pageInfo.PSObject.Properties.Name -contains "publicKeyModulus" -and -not [string]::IsNullOrWhiteSpace($pageInfo.publicKeyModulus)) {
        $publicKeyModulus = [string]$pageInfo.publicKeyModulus
    }

    if ($pageInfo.PSObject.Properties.Name -contains "passwordEncrypt" -and -not [string]::IsNullOrWhiteSpace($pageInfo.passwordEncrypt)) {
        $passwordEncrypt = [string]$pageInfo.passwordEncrypt
    }
}

$config = [ordered]@{
    ProductName = "SHU Campus Network AutoAuth"
    Version = "0.1.1"
    PortalType = "SHU-EPortal"
    LoginUrl = $portalBaseUrl + "InterFace.do?method=login"
    Method = "POST"
    ContentType = "application/x-www-form-urlencoded; charset=UTF-8"
    Username = $Username.Trim()
    Service = $Service.Trim()
    QueryString = $queryString
    PasswordEncrypt = $passwordEncrypt
    PublicKeyExponent = $publicKeyExponent
    PublicKeyModulus = $publicKeyModulus
    OnlineTestUrl = "http://www.msftconnecttest.com/connecttest.txt"
    OnlineTestExpectedStatus = 200
    OnlineTestExpectedContent = "Microsoft Connect Test"
    TimeoutSeconds = 15
    SuccessCheckDelaySeconds = 5
}

$config | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ConfigPath -Encoding UTF8
Protect-MachineString -SecureString $password | Set-Content -LiteralPath $PasswordPath -Encoding ASCII

Write-Host ""
Write-Host "Configuration saved:"
Write-Host "  $ConfigPath"
Write-Host "Encrypted password saved:"
Write-Host "  $PasswordPath"
Write-Host ""
Write-Host "Next step: run install-startup-task.ps1 from an administrator PowerShell."
