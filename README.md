# SHU NetAuth

SHU NetAuth is a lightweight Windows setup wizard and startup task for Shanghai University campus network ePortal authentication.

It is designed for unattended Windows devices that need to regain campus network access after reboot, power loss, cable reconnection, or portal session expiration.

## Supported Network Environments

SHU NetAuth is intended for Shanghai University networks that use the ePortal gateway at `http://10.10.9.9`.

It is expected to work in these cases:

- Wired campus network: a Windows PC connects directly to a dormitory, lab, or campus Ethernet port.
- Sub-network devices: a Windows PC connects through a router, switch, or similar local network device, as long as the Windows PC can reach `http://10.10.9.9` and complete ePortal authentication.
- Wireless campus network: a Windows PC connects to `Shu(ForAll)`.
- Other campus network paths where a browser can reach `http://10.10.9.9` and open the Shanghai University ePortal login page.

It is not intended for:

- Devices outside Shanghai University campus network environments.
- Networks where `http://10.10.9.9` is unreachable.
- Networks that do not use Shanghai University ePortal authentication.
- Interactive login flows requiring SMS, QR codes, CAS single sign-on, or CAPTCHA.

## Download

Download the release package from GitHub Releases:

[SHU-NetAuth-v1.0.0.zip](https://github.com/PomePerilla/SHU-Campus-Network-AutoAuth/releases/download/v1.0.0/SHU-NetAuth-v1.0.0.zip)

Extract the ZIP file. The extracted folder should look like:

```text
SHU-NetAuth-v1.0.0/
  setup.cmd
  setup.ps1
  configure.ps1
  install-startup-task.ps1
  uninstall-startup-task.ps1
  test-login.ps1
  scripts/
  config/
```

## Quick Setup

Open the extracted folder and double-click:

```text
setup.cmd
```

The setup wizard will:

- Request administrator permission through Windows UAC.
- Show Windows, PowerShell, project path, configuration, and credential-file status.
- Show active network adapters.
- Check internet connectivity.
- Check the campus portal gateway at `http://10.10.9.9`.
- Check whether the startup Scheduled Task is already installed.
- Ask for campus network username, password, service name, and portal gateway.
- Save local configuration and encrypted password files.
- Install the Windows startup Scheduled Task.
- Run one test pass.
- Show final task status and recent logs.

The UAC prompt must be approved by the user. SHU NetAuth cannot bypass Windows administrator permission.

## Configuration Inputs

The setup wizard asks for:

- Campus network username.
- Campus network password. Empty passwords are rejected and the wizard will ask again.
- Service name. The default is `shu`.
- Portal gateway URL. The default is `http://10.10.9.9/`.
- Optional full ePortal login URL fallback. Most users should press Enter to skip this.

The normal setup flow does not require copying the long ePortal login URL from a browser. SHU NetAuth fetches current ePortal login parameters only when authentication is actually needed.

## How It Runs

After installation, SHU NetAuth creates this Windows Scheduled Task:

```text
\SHU NetAuth\SHUCampusNetworkAutoAuth
```

The task runs as `SYSTEM` at Windows startup and then checks every 5 minutes. If internet access is already available, it exits without reading the password or sending a login request. If internet access is unavailable, it probes the trusted campus portal gateway and submits an ePortal authentication request.

## Manual Commands

The setup wizard is recommended. These commands are available for manual operation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\configure.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-startup-task.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\test-login.ps1
```

`install-startup-task.ps1` must be run from an administrator PowerShell.

## Logs

Runtime logs are written locally:

```text
logs\shu-autoauth.log
```

To view recent logs:

```powershell
Get-Content .\logs\shu-autoauth.log -Tail 50
```

## Uninstall

Run from an administrator PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\uninstall-startup-task.ps1
```

To remove local credentials after uninstalling, delete:

```text
config\portal.json
config\portal.password.bin
```

## Security

Read [SECURITY.md](SECURITY.md) before using SHU NetAuth on shared or untrusted devices.

In short:

- SHU NetAuth runs locally and does not use a project-owned remote server.
- The campus password is stored in `config\portal.password.bin`.
- The password file is protected by Windows DPAPI `LocalMachine`.
- The ePortal protocol uses HTTP, so SHU NetAuth restricts authentication to the configured trusted portal host and validates the ePortal public key before submitting credentials.
- A local administrator, `SYSTEM`-level process, or malware with sufficient local privileges may still access or indirectly use stored credentials.

## Versioning

This project uses Git tags and GitHub Releases for versioning. The current stable release is `v1.0.0`.
