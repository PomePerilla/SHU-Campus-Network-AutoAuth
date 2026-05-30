param(
    [string]$ConfigPath,
    [switch]$ShowUrl
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptRoot
if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path $ProjectRoot "config\portal.json"
}

$LogDir = Join-Path $ProjectRoot "logs"
$LogPath = Join-Path $LogDir "shu-netauth.log"

function Write-DetectorLog {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -LiteralPath $LogPath -Value "[$timestamp] [$Level] [detector] $Message" -Encoding UTF8
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

function Get-DetectorConfigValue {
    param(
        [pscustomobject]$Config,
        [string]$Name,
        [string]$Default = ""
    )

    if ($Config -and $Config.PSObject.Properties.Name -contains "PortalUrlDetector" -and $null -ne $Config.PortalUrlDetector) {
        if ($Config.PortalUrlDetector.PSObject.Properties.Name -contains $Name -and -not [string]::IsNullOrWhiteSpace([string]$Config.PortalUrlDetector.$Name)) {
            return [string]$Config.PortalUrlDetector.$Name
        }
    }

    return $Default
}

function ConvertTo-AbsoluteUrl {
    param(
        [string]$Url,
        [uri]$BaseUri
    )

    if ([string]::IsNullOrWhiteSpace($Url)) {
        return ""
    }

    if ($Url -match "^https?://") {
        return $Url
    }

    return ([uri]::new($BaseUri, $Url)).AbsoluteUri
}

function Test-IsPortalLoginUrl {
    param([string]$Url)

    if ([string]::IsNullOrWhiteSpace($Url)) {
        return $false
    }

    try {
        $uri = [uri]$Url
        return $uri.AbsolutePath -like "*/eportal/index.jsp" -and -not [string]::IsNullOrWhiteSpace($uri.Query)
    }
    catch {
        return $false
    }
}

function Get-SafeUrlSummary {
    param([string]$Url)

    try {
        $uri = [uri]$Url
        return "$($uri.Host)$($uri.AbsolutePath)"
    }
    catch {
        return "<invalid-url>"
    }
}

function Get-QuerySummary {
    param([string]$Url)

    try {
        Add-Type -AssemblyName System.Web
        $uri = [uri]$Url
        $pairs = [System.Web.HttpUtility]::ParseQueryString($uri.Query)
        $keys = @($pairs.AllKeys | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        return [pscustomobject]@{
            Length = $uri.Query.TrimStart("?").Length
            KeyCount = $keys.Count
        }
    }
    catch {
        return [pscustomobject]@{
            Length = 0
            KeyCount = 0
        }
    }
}

function Get-ResponseHeader {
    param(
        $Response,
        [string]$Name
    )

    if ($null -eq $Response -or $null -eq $Response.Headers) {
        return ""
    }

    try {
        $value = $Response.Headers[$Name]
        if ($null -eq $value) {
            return ""
        }

        return [string]$value
    }
    catch {
        return ""
    }
}

function Find-PortalLoginUrlInHtml {
    param(
        [string]$Content,
        [uri]$BaseUri
    )

    if ([string]::IsNullOrWhiteSpace($Content)) {
        return ""
    }

    $decoded = [Net.WebUtility]::HtmlDecode($Content)

    foreach ($match in [regex]::Matches($decoded, 'https?://[^\s"''<>]+')) {
        if (Test-IsPortalLoginUrl -Url $match.Value) {
            return $match.Value
        }
    }

    foreach ($match in [regex]::Matches($decoded, '/eportal/index\.jsp\?[^\s"''<>]+')) {
        $candidate = ConvertTo-AbsoluteUrl -Url $match.Value -BaseUri $BaseUri
        if (Test-IsPortalLoginUrl -Url $candidate) {
            return $candidate
        }
    }

    $metaPattern = '<meta[^>]+http-equiv\s*=\s*["'']?refresh["'']?[^>]+content\s*=\s*["''][^"'']*url\s*=\s*([^"'']+)["'']'
    foreach ($match in [regex]::Matches($decoded, $metaPattern, [Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
        $candidate = ConvertTo-AbsoluteUrl -Url $match.Groups[1].Value.Trim() -BaseUri $BaseUri
        if (Test-IsPortalLoginUrl -Url $candidate) {
            return $candidate
        }
    }

    $scriptPatterns = @(
        'window\.location(?:\.href)?\s*=\s*["'']([^"'']+)["'']',
        'location(?:\.href)?\s*=\s*["'']([^"'']+)["'']',
        'top\.location(?:\.href)?\s*=\s*["'']([^"'']+)["'']',
        'self\.location(?:\.href)?\s*=\s*["'']([^"'']+)["'']'
    )
    foreach ($pattern in $scriptPatterns) {
        foreach ($match in [regex]::Matches($decoded, $pattern, [Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
            $candidate = ConvertTo-AbsoluteUrl -Url $match.Groups[1].Value.Trim() -BaseUri $BaseUri
            if (Test-IsPortalLoginUrl -Url $candidate) {
                return $candidate
            }
        }
    }

    return ""
}

function Get-DetectorProbeTargets {
    param([pscustomobject]$Config)

    $gatewayUrl = Get-ConfigValue -Config $Config -Name "PortalGatewayUrl" -Default "http://10.10.9.9/"
    if ($gatewayUrl -notmatch "^https?://") {
        $gatewayUrl = "http://$gatewayUrl"
    }

    $gatewayUri = [uri]$gatewayUrl
    $gatewayBase = "$($gatewayUri.Scheme)://$($gatewayUri.Authority)"
    $onlineTestUrl = Get-ConfigValue -Config $Config -Name "OnlineTestUrl" -Default "http://www.msftconnecttest.com/connecttest.txt"

    return @(
        $onlineTestUrl,
        "$gatewayBase/",
        "$gatewayBase/eportal/index.jsp",
        "http://123.123.123.123/"
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
}

function Invoke-DetectorRequest {
    param(
        [string]$StartUrl,
        [int]$TimeoutSeconds,
        [int]$MaxRedirects
    )

    $headers = @{
        "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"
        "Accept" = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
        "Accept-Language" = "zh-Hans,zh;q=0.9,en;q=0.8"
        "Cache-Control" = "no-cache"
        "Pragma" = "no-cache"
    }

    $current = [uri]$StartUrl
    for ($i = 0; $i -le $MaxRedirects; $i++) {
        Write-DetectorLog -Message "Requesting $(Get-SafeUrlSummary -Url $current.AbsoluteUri)."

        if (Test-IsPortalLoginUrl -Url $current.AbsoluteUri) {
            return $current.AbsoluteUri
        }

        try {
            $response = Invoke-WebRequest `
                -Uri $current.AbsoluteUri `
                -Headers $headers `
                -MaximumRedirection 0 `
                -TimeoutSec $TimeoutSeconds `
                -UseBasicParsing

            if ($response.BaseResponse -and $response.BaseResponse.ResponseUri) {
                $responseUrl = $response.BaseResponse.ResponseUri.AbsoluteUri
                if (Test-IsPortalLoginUrl -Url $responseUrl) {
                    return $responseUrl
                }
            }

            $location = Get-ResponseHeader -Response $response -Name "Location"
            if (-not [string]::IsNullOrWhiteSpace($location)) {
                $nextUrl = ConvertTo-AbsoluteUrl -Url $location -BaseUri $current
                Write-DetectorLog -Message "Following redirect to $(Get-SafeUrlSummary -Url $nextUrl)."
                $current = [uri]$nextUrl
                continue
            }

            $foundUrl = Find-PortalLoginUrlInHtml -Content ([string]$response.Content) -BaseUri $current
            if (-not [string]::IsNullOrWhiteSpace($foundUrl)) {
                return $foundUrl
            }

            return ""
        }
        catch {
            $webResponse = $null
            if ($_.Exception.PSObject.Properties.Name -contains "Response") {
                $webResponse = $_.Exception.Response
            }

            if ($null -eq $webResponse) {
                Write-DetectorLog -Level "WARN" -Message "Request failed for $(Get-SafeUrlSummary -Url $current.AbsoluteUri): $($_.Exception.Message)"
                return ""
            }

            $location = Get-ResponseHeader -Response $webResponse -Name "Location"
            if (-not [string]::IsNullOrWhiteSpace($location)) {
                $nextUrl = ConvertTo-AbsoluteUrl -Url $location -BaseUri $current
                Write-DetectorLog -Message "Following redirect to $(Get-SafeUrlSummary -Url $nextUrl)."
                $current = [uri]$nextUrl
                continue
            }

            Write-DetectorLog -Level "WARN" -Message "Request failed for $(Get-SafeUrlSummary -Url $current.AbsoluteUri): $($_.Exception.Message)"
            return ""
        }
    }

    Write-DetectorLog -Level "WARN" -Message "Redirect chain exceeded $MaxRedirects redirects for $(Get-SafeUrlSummary -Url $StartUrl)."
    return ""
}

function Invoke-PortalUrlDetector {
    param([pscustomobject]$Config)

    $timeoutSeconds = [int](Get-DetectorConfigValue -Config $Config -Name "TimeoutSeconds" -Default "8")
    $maxRedirects = [int](Get-DetectorConfigValue -Config $Config -Name "MaxRedirects" -Default "8")
    $retryCount = [int](Get-DetectorConfigValue -Config $Config -Name "RetryCount" -Default "6")
    $retryDelaySeconds = [int](Get-DetectorConfigValue -Config $Config -Name "RetryDelaySeconds" -Default "5")

    $targets = Get-DetectorProbeTargets -Config $Config
    Write-DetectorLog -Message "Portal URL detector started. Targets=$($targets.Count) Retries=$retryCount."

    for ($attempt = 1; $attempt -le $retryCount; $attempt++) {
        Write-DetectorLog -Message "Detector attempt $attempt of $retryCount."

        foreach ($target in $targets) {
            $detectedUrl = Invoke-DetectorRequest -StartUrl $target -TimeoutSeconds $timeoutSeconds -MaxRedirects $maxRedirects
            if (Test-IsPortalLoginUrl -Url $detectedUrl) {
                $summary = Get-QuerySummary -Url $detectedUrl
                Write-DetectorLog -Message "Detected ePortal login URL at $(Get-SafeUrlSummary -Url $detectedUrl). QueryLength=$($summary.Length) QueryKeyCount=$($summary.KeyCount)."
                return [pscustomobject]@{
                    Success = $true
                    Url = $detectedUrl
                    SafeUrl = Get-SafeUrlSummary -Url $detectedUrl
                    QueryLength = $summary.Length
                    QueryKeyCount = $summary.KeyCount
                    Source = $target
                    Attempt = $attempt
                }
            }
        }

        if ($attempt -lt $retryCount) {
            Start-Sleep -Seconds $retryDelaySeconds
        }
    }

    Write-DetectorLog -Level "WARN" -Message "Portal URL detector finished without a usable ePortal login URL."
    return [pscustomobject]@{
        Success = $false
        Url = ""
        SafeUrl = ""
        QueryLength = 0
        QueryKeyCount = 0
        Source = ""
        Attempt = $retryCount
    }
}

if (Test-Path -LiteralPath $ConfigPath) {
    $config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
}
else {
    $config = Get-Content -LiteralPath (Join-Path $ProjectRoot "config\portal.example.json") -Raw -Encoding UTF8 | ConvertFrom-Json
}

$result = Invoke-PortalUrlDetector -Config $config

Write-Host "Portal URL detector result"
Write-Host "Success: $($result.Success)"
Write-Host "Safe URL: $($result.SafeUrl)"
Write-Host "Query length: $($result.QueryLength)"
Write-Host "Query key count: $($result.QueryKeyCount)"
Write-Host "Source: $($result.Source)"
Write-Host "Attempt: $($result.Attempt)"
Write-Host "Log: $LogPath"

if ($ShowUrl -and $result.Success) {
    Write-Host ""
    Write-Host "Full URL:"
    Write-Host $result.Url
}

if ($result.Success) {
    exit 0
}

exit 1
