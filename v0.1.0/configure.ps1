param(
    [string]$PortalUrl,
    [string]$Username,
    [string]$Service = "shu"
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

Write-Host "SHU Campus Network AutoAuth CLI v0.1.0"
Write-Host ""

if ([string]::IsNullOrWhiteSpace($PortalUrl)) {
    $PortalUrl = Read-Host "Paste the full SHU campus network login page URL"
}

if ([string]::IsNullOrWhiteSpace($PortalUrl)) {
    throw "Portal URL is required."
}

$portalUri = [uri]$PortalUrl
if ([string]::IsNullOrWhiteSpace($portalUri.Query)) {
    throw "Portal URL must include the query string after '?'."
}

if ([string]::IsNullOrWhiteSpace($Username)) {
    $Username = Read-Host "Campus network username"
}

if ([string]::IsNullOrWhiteSpace($Username)) {
    throw "Username is required."
}

$password = Read-Host "Campus network password" -AsSecureString
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
    Version = "0.1.0"
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
