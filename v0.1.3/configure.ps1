param(
    [string]$Username,
    [string]$Service = "shu",
    [string]$PortalGatewayUrl = "http://10.10.9.9/",
    [string]$FallbackPortalUrl
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

function Read-OptionalString {
    param([string]$Prompt)

    $value = Read-Host $Prompt
    if ([string]::IsNullOrWhiteSpace($value)) {
        return ""
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

function Normalize-PortalGatewayUrl {
    param([string]$Url)

    if ([string]::IsNullOrWhiteSpace($Url)) {
        $Url = "http://10.10.9.9/"
    }

    $Url = $Url.Trim()
    if ($Url -notmatch "^https?://") {
        $Url = "http://$Url"
    }

    $uri = [uri]$Url
    return "$($uri.Scheme)://$($uri.Authority)/"
}

function Get-PortalBaseUrl {
    param([string]$GatewayUrl)

    $uri = [uri]$GatewayUrl
    return "$($uri.Scheme)://$($uri.Authority)/eportal/"
}

function Get-FallbackQueryString {
    param([string]$PortalUrl)

    if ([string]::IsNullOrWhiteSpace($PortalUrl)) {
        return ""
    }

    $uri = [uri]$PortalUrl
    if ([string]::IsNullOrWhiteSpace($uri.Query)) {
        throw "Fallback ePortal URL must include the query string after '?'."
    }

    return $uri.Query.TrimStart("?")
}

if (-not (Test-Path $ConfigDir)) {
    New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
}

Write-Host "SHU Campus Network AutoAuth CLI v0.1.3"
Write-Host ""
Write-Host "This version does not require a current ePortal login URL during configuration."
Write-Host "The startup task will fetch the current ePortal query string when login is actually needed."
Write-Host ""

if ([string]::IsNullOrWhiteSpace($Username)) {
    $Username = Read-RequiredString -Prompt "Campus network username"
}

$password = Read-RequiredSecureString -Prompt "Campus network password"
$Service = Read-WithDefault -Prompt "Service name" -Default $Service
$PortalGatewayUrl = Read-WithDefault -Prompt "Portal gateway URL" -Default $PortalGatewayUrl

if ([string]::IsNullOrWhiteSpace($FallbackPortalUrl)) {
    $FallbackPortalUrl = Read-OptionalString -Prompt "Optional full ePortal login URL fallback (press Enter to skip)"
}

$normalizedGatewayUrl = Normalize-PortalGatewayUrl -Url $PortalGatewayUrl
$portalBaseUrl = Get-PortalBaseUrl -GatewayUrl $normalizedGatewayUrl
$fallbackQueryString = Get-FallbackQueryString -PortalUrl $FallbackPortalUrl

$config = [ordered]@{
    ProductName = "SHU Campus Network AutoAuth"
    Version = "0.1.3"
    PortalType = "SHU-EPortal"
    PortalGatewayUrl = $normalizedGatewayUrl
    LoginUrl = $portalBaseUrl + "InterFace.do?method=login"
    PageInfoUrl = $portalBaseUrl + "InterFace.do?method=pageInfo"
    Method = "POST"
    ContentType = "application/x-www-form-urlencoded; charset=UTF-8"
    Username = $Username.Trim()
    Service = $Service.Trim()
    FallbackQueryString = $fallbackQueryString
    PasswordEncrypt = "true"
    PublicKeyExponent = $DefaultPublicKeyExponent
    PublicKeyModulus = $DefaultPublicKeyModulus
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
