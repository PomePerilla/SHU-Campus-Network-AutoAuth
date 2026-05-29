# Technical Notes

This document records the current SHU NetAuth v1.0.0 technical path and known limitations.

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

## Current v1.0.0 Approach

SHU NetAuth v1.0.0 uses a pragmatic compatibility approach:

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

In v1.0.0 this does not enforce rules. The project previously attempted strict host and public-key checks, but those checks blocked the observed SHU portal flow. Security policy work is therefore postponed until the automatic detector and real portal flow are better understood.

Planned policy areas:

- Host allowlist by stage.
- Credential submission endpoint controls.
- Public-key pinning after confirming stable behavior.
- Sensitive log redaction for query strings and user/session parameters.

## Current Priority

v1.0.0 prioritizes a working startup authentication service with clear manual setup. Automatic long URL acquisition and stricter security policy enforcement are intentionally left as future work.
