# SHU NetAuth

Languages: [English](README.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

SHU NetAuth is a Windows startup authentication tool for the Shanghai University campus network ePortal environment.

Version `v1.1.1` adds an experimental Playwright-based ePortal long URL detector while keeping the startup authentication flow stable. Users can still complete setup with one full ePortal login URL copied from the browser, and detailed diagnostics are written to `logs\shu-netauth.log` instead of being shown in the setup window.

## Supported Environment

SHU NetAuth is intended for Shanghai University networks where a Windows device can access:

```text
http://10.10.9.9
```

Typical supported cases:

- Wired campus network.
- A Windows PC connected through a router or switch to the campus network.
- Wireless network `Shu(ForAll)`.
- Other campus access paths that can open the SHU ePortal login page.

Unsupported cases:

- Non-SHU networks.
- Networks where `http://10.10.9.9` is unreachable.
- Login flows requiring SMS, QR code, CAS, CAPTCHA, or other interactive verification.

## Download

Download from GitHub Releases:

[SHU-NetAuth-v1.1.1.zip](https://github.com/PomePerilla/SHU-Campus-Network-AutoAuth/releases/download/v1.1.1/SHU-NetAuth-v1.1.1.zip)

Extract the package and open:

```text
SHU-NetAuth-v1.1.1
```

## Setup

Before running setup, open this address in your browser:

```text
http://10.10.9.9
```

Wait until the browser redirects to the ePortal login page. Then copy the full long URL from the browser address bar. It usually starts with:

```text
http://10.10.9.9/eportal/index.jsp?
```

Do not copy only `http://10.10.9.9/`. The full URL must include the long query string after `?`.

Then run:

```text
setup.cmd
```

The setup wizard asks for:

- Campus network username.
- Campus network password.
- Full ePortal login URL fallback.

The service name and portal gateway are hidden from the normal setup flow and use these defaults:

```text
Service = shu
PortalGatewayUrl = http://10.10.9.9/
```

After setup, SHU NetAuth creates this Scheduled Task:

```text
\SHU NetAuth\SHUCampusNetworkAutoAuth
```

It runs as `SYSTEM` at Windows startup and checks every 5 minutes.

## User Interface

The setup window intentionally shows only simple user-facing status:

```text
Project Status
Network Status
SUCCESS
SETUP NEEDS ATTENTION
```

Raw HTTP errors, gateway status codes, file paths, and runtime details are written to:

```text
logs\shu-netauth.log
```

## Current Limitation

SHU NetAuth cannot yet reliably obtain the full ePortal login URL automatically from `http://10.10.9.9/` in every campus network state. The current release therefore asks users to manually copy the browser's full ePortal URL once during setup.

The copied long URL may be tied to the current device, network interface, access controller, port, VLAN, or IP environment. It may work for the same device and same access path for some time, but it is not guaranteed to work across devices or after network attachment changes.

If authentication stops working after changing ports, routers, wired/wireless mode, or network environment, run `setup.cmd` again and paste a fresh ePortal URL.

## Experimental URL Detector

v1.1.1 includes an independent Playwright-based detector for testing automatic ePortal long URL acquisition:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Detect-PortalUrl.Playwright.ps1
```

Return only the detected long URL:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Detect-PortalUrl.Playwright.ps1 -OnlyUrl
```

Install detector dependencies:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Install-PortalDetectorDependencies.ps1
```

The detector is currently a standalone module. It is not connected to the startup authentication flow yet.

## Reserved Interfaces

The main authentication script reserves:

```powershell
Get-AutoDetectedPortalUrl
```

for future automatic long URL detection.

It also reserves:

```powershell
Invoke-SecurityPolicyCheck
```

for future security policy enforcement. In `v1.1.1`, this interface does not enforce host pinning, public-key pinning, or credential endpoint restrictions.

## Manual Commands

The setup wizard is recommended. Manual commands are:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\configure.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-startup-task.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\test-login.ps1
```

`install-startup-task.ps1` requires administrator PowerShell.

View logs:

```powershell
Get-Content .\logs\shu-netauth.log -Tail 50
```

## Security

The username is stored in:

```text
config\portal.json
```

The password is stored in:

```text
config\portal.password.bin
```

The password file is protected with Windows DPAPI `LocalMachine` scope so the startup task can run as `SYSTEM` before user login. Use SHU NetAuth only on trusted personal devices.

See [SECURITY.md](SECURITY.md) and [TECHNICAL_NOTES.md](TECHNICAL_NOTES.md) for details.

