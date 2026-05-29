# Security

This document describes how SHU NetAuth v1.0.1 handles credentials and what security limits remain.

## Local Credential Storage

SHU NetAuth stores local runtime data in the extracted project folder.

```text
config/portal.json
```

This file stores non-password configuration:

- Product and version metadata.
- Portal gateway URL.
- ePortal login and pageInfo endpoint URLs.
- Campus network username.
- Service name, normally `shu`.
- Reserved detector and security-policy interface metadata.
- Fallback ePortal query string copied from the user's browser URL.
- ePortal public-key fields used by the compatibility login flow.
- Internet connectivity test settings.

It does not store the plaintext campus network password.

```text
config/portal.password.bin
```

This file stores the campus network password encrypted with Windows DPAPI using `DataProtectionScope.LocalMachine`.

## Why LocalMachine DPAPI

The startup Scheduled Task runs as `SYSTEM` before any interactive Windows user may log in.

User-scoped DPAPI would bind the password to a user profile and would not reliably work for a startup task running as `SYSTEM`. Machine-scoped DPAPI is the practical tradeoff:

- The password file is not directly useful when copied to another Windows installation.
- The `SYSTEM` startup task can decrypt it locally when authentication is needed.
- Casual file disclosure does not reveal the plaintext password.

This is still not a defense against a compromised local machine, local administrator, `SYSTEM`-level process, or malware with sufficient privileges.

## Runtime Flow

1. Windows starts.
2. The Scheduled Task runs `scripts/Invoke-SHUAutoAuth.ps1` as `SYSTEM`.
3. The script tests internet access.
4. If internet access already works, it exits without decrypting the password.
5. If internet access fails, it attempts the compatibility portal discovery flow.
6. If discovery cannot obtain a usable ePortal URL, it uses the configured fallback query string from `config/portal.json`.
7. It requests ePortal pageInfo when available.
8. It decrypts `config/portal.password.bin` locally.
9. It builds the ePortal login request.
10. It sends the login request to the configured ePortal login endpoint.
11. It tests internet access again and writes local logs.

## Current Network Security Status

The Shanghai University ePortal flow observed during development uses HTTP and may involve redirects or pages that are not consistently reproduced by PowerShell's simple HTTP probing.

Earlier strict security checks blocked real authentication in this environment. In v1.0.1, SHU NetAuth prioritizes compatibility:

- `Invoke-SecurityPolicyCheck` is reserved as a future security-policy interface.
- Host pinning is not enforced.
- Public-key pinning is not enforced.
- Credential endpoint restriction rules are not enforced.
- Password-encryption refusal rules are not enforced.

These checks are planned to return only after the real SHU ePortal behavior is understood and tested.

## Long URL Risk

The fallback ePortal URL copied from the browser may contain device and access-environment parameters, such as IP address, access controller, VLAN, port, NAS information, or MAC-related values.

Do not publish the complete URL in GitHub issues, screenshots, or public chat logs.

The fallback query string may work only for the same device and the same network attachment conditions. It may stop working after changing devices, changing network ports, switching between wired and wireless access, reconnecting through a different router, or after backend portal changes.

## What Leaves the Machine

SHU NetAuth has no project-owned backend, telemetry service, analytics endpoint, or cloud sync.

When authentication is needed, the following data is sent to the configured Shanghai University ePortal endpoint:

- Campus network username.
- The ePortal password field generated for the login request.
- Service name, usually `shu`.
- ePortal query-string parameters supplied by the campus network gateway.
- Required ePortal request fields such as operator password, operator user ID, valid code, and password encryption flag.

The local DPAPI password file is not uploaded.

## Recommendations

- Use SHU NetAuth only on your own trusted Windows device.
- Download releases only from the official GitHub Releases page.
- Do not send `config/portal.json` or `config/portal.password.bin` to others.
- Do not publish complete ePortal long URLs.
- If campus network authentication fails after changing network attachment, rerun `setup.cmd` and paste a fresh ePortal URL.
- If you suspect compromise, change your campus network password and rerun setup.

## Logs

User-facing setup output is intentionally minimal. Detailed setup, network, task, and authentication events are written to:

```text
logs\shu-netauth.log
```

Logs should not contain plaintext passwords. They may contain local status, HTTP errors, and operational details useful for troubleshooting.
