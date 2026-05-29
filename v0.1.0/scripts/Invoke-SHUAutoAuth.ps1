Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ConfigPath = Join-Path $ProjectRoot "config\portal.json"
$PasswordPath = Join-Path $ProjectRoot "config\portal.password.bin"
$LogDir = Join-Path $ProjectRoot "logs"
$LogPath = Join-Path $LogDir "shu-autoauth.log"

function Write-Log {
    param([string]$Message)

    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }

    if ((Test-Path $LogPath) -and ((Get-Item $LogPath).Length -gt 1048576)) {
        Move-Item -LiteralPath $LogPath -Destination "$LogPath.1" -Force
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -LiteralPath $LogPath -Value "[$timestamp] $Message" -Encoding UTF8
}

function Test-InternetAccess {
    param([pscustomobject]$Config)

    try {
        $response = Invoke-WebRequest `
            -Uri $Config.OnlineTestUrl `
            -Method Get `
            -TimeoutSec $Config.TimeoutSeconds `
            -UseBasicParsing

        if ([int]$response.StatusCode -ne [int]$Config.OnlineTestExpectedStatus) {
            return $false
        }

        if ($Config.PSObject.Properties.Name -contains "OnlineTestExpectedContent") {
            return [string]$response.Content -like "*$($Config.OnlineTestExpectedContent)*"
        }

        return $true
    }
    catch {
        return $false
    }
}

function Unprotect-MachineString {
    param([string]$ProtectedPassword)

    Add-Type -AssemblyName System.Security

    $protectedBytes = [Convert]::FromBase64String($ProtectedPassword)
    $plainBytes = [Security.Cryptography.ProtectedData]::Unprotect(
        $protectedBytes,
        $null,
        [Security.Cryptography.DataProtectionScope]::LocalMachine
    )

    try {
        return [Text.Encoding]::UTF8.GetString($plainBytes)
    }
    finally {
        [Array]::Clear($plainBytes, 0, $plainBytes.Length)
    }
}

function ConvertTo-FormValue {
    param([string]$Value)

    return [Uri]::EscapeDataString([Uri]::EscapeDataString($Value))
}

function ConvertFrom-HexToBigInteger {
    param([string]$Hex)

    if ($Hex.Length % 2 -eq 1) {
        $Hex = "0$Hex"
    }

    $bytes = New-Object byte[] ($Hex.Length / 2 + 1)
    $index = 0
    for ($i = $Hex.Length - 2; $i -ge 0; $i -= 2) {
        $bytes[$index] = [Convert]::ToByte($Hex.Substring($i, 2), 16)
        $index++
    }

    return [System.Numerics.BigInteger]::new($bytes)
}

function ConvertTo-EPortalEncryptedPassword {
    param(
        [string]$Password,
        [string]$Mac,
        [string]$PublicKeyExponent,
        [string]$PublicKeyModulus
    )

    Add-Type -AssemblyName System.Numerics

    if ([string]::IsNullOrWhiteSpace($Mac)) {
        $Mac = "111111111"
    }

    $chars = ($Password + ">" + $Mac).ToCharArray()
    [Array]::Reverse($chars)
    $plain = -join $chars
    $plainBytes = [Text.Encoding]::ASCII.GetBytes($plain)
    $modulus = ConvertFrom-HexToBigInteger -Hex $PublicKeyModulus
    $exponent = ConvertFrom-HexToBigInteger -Hex $PublicKeyExponent

    $modulusBytes = [Math]::Ceiling($PublicKeyModulus.Length / 2)
    $chunkSize = $modulusBytes - 2
    if ($plainBytes.Length -gt $chunkSize) {
        throw "Password block is too long for the ePortal RSA modulus."
    }

    $block = New-Object byte[] ($chunkSize + 1)
    [Array]::Copy($plainBytes, $block, $plainBytes.Length)

    $number = [System.Numerics.BigInteger]::new($block)
    $encrypted = [System.Numerics.BigInteger]::ModPow($number, $exponent, $modulus)
    $encryptedBytes = $encrypted.ToByteArray()

    if ($encryptedBytes.Length -gt 1 -and $encryptedBytes[-1] -eq 0) {
        $trimmedBytes = $encryptedBytes[0..($encryptedBytes.Length - 2)]
    }
    else {
        $trimmedBytes = $encryptedBytes
    }

    $hex = -join ($trimmedBytes | ForEach-Object { $_.ToString("x2") })
    $pairs = [regex]::Matches($hex, "..") | ForEach-Object { $_.Value }
    [Array]::Reverse($pairs)
    $result = -join $pairs

    while (($result.Length % 4) -ne 0) {
        $result = "0$result"
    }

    return $result
}

function Get-QueryValue {
    param(
        [string]$QueryString,
        [string]$Name
    )

    Add-Type -AssemblyName System.Web
    $pairs = [System.Web.HttpUtility]::ParseQueryString($QueryString)
    return $pairs[$Name]
}

function New-EPortalLoginBody {
    param(
        [pscustomobject]$Config,
        [string]$Password
    )

    $queryString = [string]$Config.QueryString
    $mac = Get-QueryValue -QueryString $queryString -Name "mac"
    $passwordForLogin = $Password

    if ([string]$Config.PasswordEncrypt -eq "true") {
        $passwordForLogin = ConvertTo-EPortalEncryptedPassword `
            -Password $Password `
            -Mac $mac `
            -PublicKeyExponent ([string]$Config.PublicKeyExponent) `
            -PublicKeyModulus ([string]$Config.PublicKeyModulus)
    }

    return "userId=$(ConvertTo-FormValue ([string]$Config.Username))" +
        "&password=$(ConvertTo-FormValue $passwordForLogin)" +
        "&service=$(ConvertTo-FormValue ([string]$Config.Service))" +
        "&queryString=$(ConvertTo-FormValue $queryString)" +
        "&operatorPwd=" +
        "&operatorUserId=" +
        "&validcode=" +
        "&passwordEncrypt=$(ConvertTo-FormValue ([string]$Config.PasswordEncrypt))"
}

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    if (-not (Test-Path $ConfigPath)) {
        Write-Log "Config file not found: $ConfigPath"
        exit 2
    }

    if (-not (Test-Path $PasswordPath)) {
        Write-Log "Encrypted password file not found: $PasswordPath"
        exit 2
    }

    $config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json

    if (Test-InternetAccess -Config $config) {
        Write-Log "Internet is already available. No login needed."
        exit 0
    }

    $protectedPassword = Get-Content -LiteralPath $PasswordPath -Raw -Encoding ASCII
    $password = Unprotect-MachineString -ProtectedPassword $protectedPassword.Trim()
    $body = New-EPortalLoginBody -Config $config -Password $password

    Write-Log "Internet unavailable. Sending SHU ePortal login request."

    $loginResponse = Invoke-WebRequest `
        -Uri $config.LoginUrl `
        -Method $config.Method `
        -Body $body `
        -ContentType $config.ContentType `
        -TimeoutSec $config.TimeoutSeconds `
        -UseBasicParsing

    Write-Log "Login request completed with HTTP $($loginResponse.StatusCode)."

    try {
        $portalResult = $loginResponse.Content | ConvertFrom-Json
        if ($portalResult.PSObject.Properties.Name -contains "result") {
            Write-Log "Portal result: $($portalResult.result)."
        }
    }
    catch {
        Write-Log "Portal returned a non-JSON response."
    }

    Start-Sleep -Seconds $config.SuccessCheckDelaySeconds

    if (Test-InternetAccess -Config $config) {
        Write-Log "Internet is available after login."
        exit 0
    }

    Write-Log "Login request finished, but internet test still failed."
    exit 1
}
catch {
    Write-Log "Login failed: $($_.Exception.Message)"
    exit 1
}
