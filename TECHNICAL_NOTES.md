# Technical Notes

This document records the current SHU NetAuth v1.1.1 technical path and known limitations.

## Observed Campus Portal Behavior

The Shanghai University campus network appears to use a Ruijie-style RG-SAM / RG-ePortal authentication flow.

Observed paths and endpoints include:

```text
http://10.10.9.9/
http://10.10.9.9/eportal/redirectortosuccess.jsp
http://10.10.9.9/eportal/index.jsp?...
http://10.10.9.9/eportal/InterFace.do?method=pageInfo
http://10.10.9.9/eportal/InterFace.do?method=login
http://10.10.9.9/eportal/success.jsp
http://10.10.9.9/eportal/modify_pwd.jsp
http://123.123.123.123/
```

`10.10.9.9` is treated as the main campus portal gateway. During testing, `123.123.123.123` was observed as part of the unauthenticated portal flow. It should not be assumed to be malicious solely because it appears in redirects.

## Why Automatic Long URL Detection Is Not Reliable Yet

The login URL needed by ePortal is a long URL under `/eportal/index.jsp?...`. It contains a query string with access-session parameters. A browser may obtain this URL after network interception, gateway redirects, JavaScript, meta refresh, cookies, user-agent dependent behavior, or by first visiting an external site that the campus network intercepts.

The current PowerShell compatibility probe checks simple targets such as:

```text
http://10.10.9.9/
http://10.10.9.9/eportal/index.jsp
http://123.123.123.123/
```

On some networks, these requests do not return the full `/eportal/index.jsp?...` URL that the browser sees. When that happens, the script cannot construct the login request unless a fallback query string is already configured.

## Current v1.1.1 Approach

SHU NetAuth v1.1.1 uses a pragmatic compatibility approach:

1. The user opens `http://10.10.9.9` in a browser.
2. The user copies the complete ePortal URL from the browser address bar.
3. During `setup.cmd`, the user pastes that URL into `Full ePortal login URL fallback`.
4. `configure.ps1` extracts only the query string and saves it into `config/portal.json`.
5. At runtime, the authentication script first tries the reserved automatic detector interface and the existing simple probe.
6. If those do not produce a URL, it uses the saved fallback query string.

This is why the current version can work even though automatic long URL acquisition is not solved yet.

## Reuse Limits Of The Long URL

The long URL is not a general account login URL. It may include parameters tied to the current device and access environment, such as:

```text
wlanuserip
wlanacname
nasip
mac
nasid
vid
port
nasportid
```

Practical expectation:

- Same Windows device, same network interface, same dormitory port or same router path: likely usable for some time.
- Different device: not recommended.
- Different network port, different router, wired/wireless switch, backend changes, IP changes, or portal session changes: may require a fresh URL.

Users should rerun `setup.cmd` and paste a new URL if authentication stops working after network attachment changes.

## Reserved Automatic Detector Interface

The main script reserves this function:

```powershell
function Get-AutoDetectedPortalUrl {
    param([pscustomobject]$Config)
    return $null
}
```

Future work can replace this empty implementation with a dedicated detector. Possible detector strategies include:

- Visit an external HTTP URL and capture the campus gateway interception result.
- Use a browser-like user agent and redirect handling.
- Parse JavaScript, meta refresh, iframe, or form-based portal redirection.
- Return a full `/eportal/index.jsp?...` URL to the main script.

The main login flow already calls this function before falling back to manual configuration.

## Standalone Detector Prototype

The project now includes a standalone HTTP-style detector prototype:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-PortalUrlDetector.ps1
```

To print the full detected URL for debugging:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-PortalUrlDetector.ps1 -ShowUrl
```

This script is intentionally not connected to the main authentication flow yet. It is used to test whether a browser-like PowerShell request can obtain the full `/eportal/index.jsp?...` URL before the project relies on it automatically.

The prototype currently:

- Sends browser-like request headers.
- Starts from the configured online test URL, the portal gateway root, `/eportal/index.jsp`, and the observed `123.123.123.123` portal target.
- Handles HTTP redirect `Location` headers manually.
- Parses HTML for absolute URLs, relative `/eportal/index.jsp?...` links, meta refresh redirects, and common JavaScript `location` assignments.
- Retries for a short period so it can be tested during startup or immediately after network attachment.
- Writes safe summaries to `logs\shu-netauth.log`.
- Prints the full URL only when `-ShowUrl` is explicitly used.

The detector settings live under `PortalUrlDetector` in `config\portal.json`:

```json
{
  "Mode": "http-browser-like",
  "TimeoutSeconds": 8,
  "MaxRedirects": 8,
  "RetryCount": 6,
  "RetryDelaySeconds": 5
}
```

The output should be treated as experimental until it has been tested on unauthenticated SHU wired and `Shu(ForAll)` network states.

## Minimal Playwright Detector

The current MVP detector is intentionally narrower than the HTTP-style detector. It reproduces the user action more directly:

```text
Open http://10.10.9.9/
Wait a few seconds
Read the final browser address
Check whether it looks like /eportal/index.jsp?...
```

Run it with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Detect-PortalUrl.Playwright.ps1
```

The default mode is background execution. It should not open a foreground browser window.

Print the full detected URL:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Detect-PortalUrl.Playwright.ps1 -ShowUrl
```

Return only the full detected URL:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Detect-PortalUrl.Playwright.ps1 -OnlyUrl
```

`-OnlyUrl` is intended for future programmatic integration. Its stdout contract is:

```text
exit 0: prints exactly one line, the detected full /eportal/index.jsp?... URL
exit 2: already authenticated, prints nothing
exit 1: detection failed, prints nothing
```

Watch the browser during debugging:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Detect-PortalUrl.Playwright.ps1 -Headed
```

`-Headed` is only for manual debugging. It intentionally opens a visible browser window.

Show extra debug information such as page title and navigation error:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Detect-PortalUrl.Playwright.ps1 -VerboseInfo
```

The normal output intentionally hides page title text to avoid console encoding noise. The detector sets PowerShell output encoding to UTF-8, but title text is debug-only and is not needed by the URL acquisition flow.

Change the wait time:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Detect-PortalUrl.Playwright.ps1 -WaitSeconds 8
```

This MVP only starts from the configured `PortalGatewayUrl`, which defaults to:

```text
http://10.10.9.9/
```

It does not use the online test URL and does not intentionally visit `msftconnecttest.com`. If that URL appears during testing, the old HTTP detector or the main authentication script is being run instead of this Playwright detector.

To reduce browser-originated background traffic, the Playwright detector starts Chromium/Edge with background networking disabled and routes page requests through a small allowlist. It allows the observed portal hosts:

```text
10.10.9.9
123.123.123.123
```

Other hosts are blocked inside the detector page. If the final browser URL still indicates a Microsoft captive portal check, the detector reports `State: external-captive-check` instead of treating it as a usable login URL.

It considers the result usable when the final browser URL:

- Uses host `10.10.9.9`.
- Uses path `/eportal/index.jsp`.
- Has a non-empty query string.
- Contains at least two known campus access parameters such as `wlanuserip`, `wlanacname`, `nasip`, `mac`, `nasid`, `vid`, `port`, or `nasportid`.

The detector can also return `State: already-authenticated` when the final browser URL is `/eportal/success.jsp` or `/eportal/modify_pwd.jsp`. In that state, no long login URL is expected because the current network session is already authenticated.

The Node implementation closes the browser from a `finally` path, so normal navigation failures, timeout failures, and format mismatches should not leave a browser process open.

## Detector Dependencies

Install or refresh the detector dependencies with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Install-PortalDetectorDependencies.ps1
```

The default dependency mode installs the Playwright package but does not download Chromium. The detector launches Microsoft Edge through Playwright by default:

```text
Launch mode: msedge
```

For a more self-contained detector environment, install Playwright's Chromium browser:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Install-PortalDetectorDependencies.ps1 -InstallChromium
```

This mode is larger and slower to install, but it reduces reliance on the system Edge installation. If Edge launch fails and Chromium has been installed, the detector can fall back to the bundled Chromium runtime:

```text
Launch mode: bundled-chromium
```

This module is not connected to the startup authentication flow yet.

## Reserved Security Policy Interface

The main script also reserves:

```powershell
function Invoke-SecurityPolicyCheck {
    param(
        [pscustomobject]$Config,
        [string]$Stage,
        [string]$TargetUrl = ""
    )
    return $true
}
```

In v1.1.1 this does not enforce rules. The project previously attempted strict host and public-key checks, but those checks blocked the observed SHU portal flow. Security policy work is therefore postponed until the automatic detector and real portal flow are better understood.

Planned policy areas:

- Host allowlist by stage.
- Credential submission endpoint controls.
- Public-key pinning after confirming stable behavior.
- Sensitive log redaction for query strings and user/session parameters.

## User Interface And Logging

v1.1.1 keeps the setup window simple. Users see only project status, network status, and the final result. Raw HTTP errors such as `502 Bad Gateway` are written to `logs\shu-netauth.log` instead of being shown in the normal setup UI.

## Current Priority

v1.1.1 prioritizes a working startup authentication service with clear manual setup. The standalone Playwright detector is now available for testing automatic long URL acquisition, but it is intentionally not connected to the startup authentication flow yet.
