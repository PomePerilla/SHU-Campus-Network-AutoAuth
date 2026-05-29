# Security

This document describes how SHU NetAuth handles credentials, what data moves through the system, and which risks remain.

## Credential Storage

SHU NetAuth stores local runtime data in the extracted project folder.

```text
config/portal.json
```

This file stores non-password configuration:

- Product and version metadata.
- Portal gateway URL.
- Trusted portal host.
- ePortal login and pageInfo endpoint URLs.
- Campus network username.
- Service name, normally `shu`.
- Optional fallback ePortal query string.
- Trusted ePortal public key information.
- Internet connectivity test settings.

It does not store the plaintext campus network password.

```text
config/portal.password.bin
```

This file stores the campus network password encrypted with Windows DPAPI using `DataProtectionScope.LocalMachine`.

## Why DPAPI LocalMachine

SHU NetAuth is designed to run before any user logs into Windows. The startup Scheduled Task runs as `SYSTEM`.

Plaintext password storage is not acceptable because any user or process that can read the project folder could directly read the password.

User-scoped DPAPI is also not suitable for the default startup flow. It binds decryption to a specific Windows user profile. A startup task running as `SYSTEM` before user logon cannot reliably decrypt a password protected under an interactive user's DPAPI scope.

Machine-scoped DPAPI is the practical tradeoff:

- The password file is not useful when copied to another Windows installation.
- The `SYSTEM` startup task can decrypt it locally when authentication is needed.
- Casual file disclosure does not reveal the plaintext password.

This is still not a defense against a compromised local machine or local administrator.

## Local Data Flow

Setup flow:

1. The user extracts the Release ZIP.
2. The user runs `setup.cmd`.
3. `setup.cmd` launches `setup.ps1`.
4. `setup.ps1` requests administrator permission through Windows UAC.
5. The setup wizard displays system, network, portal gateway, and Scheduled Task status.
6. `configure.ps1` reads the campus username, password, service name, portal gateway, and optional fallback URL.
7. `configure.ps1` writes non-password settings to `config/portal.json`.
8. `configure.ps1` encrypts the password through Windows DPAPI `LocalMachine`.
9. The encrypted password is written to `config/portal.password.bin`.
10. `install-startup-task.ps1` creates the Windows Scheduled Task.
11. `test-login.ps1` runs one test pass and prints recent logs.

Runtime flow:

1. Windows starts.
2. The Scheduled Task runs `scripts/Invoke-SHUAutoAuth.ps1` as `SYSTEM`.
3. The script tests internet access with `http://www.msftconnecttest.com/connecttest.txt`.
4. If internet access is already available, the script exits without decrypting the password.
5. If internet access is unavailable, the script probes the configured portal gateway, normally `http://10.10.9.9/`.
6. The script only accepts ePortal login URLs under the trusted portal host and `/eportal/` path.
7. The script requests ePortal page information and checks the returned public key against the configured trusted public key.
8. If the host or public key validation fails, the script refuses to submit credentials.
9. If validation succeeds, the script decrypts `config/portal.password.bin` locally.
10. The decrypted password exists only in process memory while the login request is being built.
11. The script builds the ePortal authentication request.
12. The password field is transformed using the ePortal-required public-key routine before submission.
13. The request is sent to the trusted ePortal login endpoint.
14. The script tests internet access again and writes local logs.

## What Leaves the Machine

SHU NetAuth has no project-owned backend, telemetry service, analytics endpoint, or cloud sync.

When authentication is needed, the following data is sent to the Shanghai University ePortal endpoint:

- Campus network username.
- The ePortal password field generated for the login request.
- Service name, usually `shu`.
- ePortal query-string parameters supplied by the campus network gateway.
- Required ePortal request fields such as operator password, operator user ID, valid code, and password encryption flag. Unused fields are sent empty.

The local DPAPI password file is not uploaded.

## HTTP Portal and Network Hijacking Risk

The campus ePortal gateway is accessed through HTTP:

```text
http://10.10.9.9
```

HTTP does not provide TLS server identity verification. A hostile network, rogue gateway, ARP spoofing attack, proxy, or malware with network control may try to impersonate the portal.

This matters because the ePortal pageInfo response includes public-key material used by the client-side password transformation. If an attacker can replace the ePortal response and provide an attacker-controlled public key, "encrypted" password fields may still be exposed to that attacker.

SHU NetAuth reduces this risk by:

- Restricting accepted login and pageInfo URLs to the configured trusted portal host.
- Requiring the `/eportal/` path.
- Rejecting redirects to unknown hosts.
- Storing a trusted ePortal public key in local configuration.
- Refusing authentication if the runtime ePortal public key does not match the trusted key.
- Refusing authentication if ePortal reports password encryption is disabled.

These checks reduce accidental credential submission to a wrong endpoint, but they do not turn HTTP into HTTPS. Users should only run SHU NetAuth on trusted Shanghai University campus network connections.

## Remaining Local Risks

Machine-scoped DPAPI protects the password file against simple copying, but the local machine remains the trust boundary.

The following actors may still read, recover, or indirectly use credentials:

- A local administrator.
- A process running as `SYSTEM`.
- Malware with sufficient local privilege.
- A user or process that can modify SHU NetAuth scripts before the next run.
- A tool that can inspect process memory while authentication is running.

Logs do not intentionally record passwords, but logs may reveal:

- Whether authentication succeeded.
- Portal status.
- Local file paths.
- Scheduled Task behavior.

## User Recommendations

- Download SHU NetAuth only from the official GitHub Releases page.
- Avoid modified copies from third-party file shares.
- Do not use SHU NetAuth on shared, public, or untrusted Windows devices.
- Do not send your `config/portal.json` or `config/portal.password.bin` to other people.
- Do not run the setup wizard while connected to unknown hotspots, proxy networks, or suspicious gateways.
- If you suspect compromise, change your campus network password immediately.
- After changing the password, delete `config/portal.password.bin` and run setup again.
- If you stop using SHU NetAuth, run `uninstall-startup-task.ps1` and delete the local `config` directory.
