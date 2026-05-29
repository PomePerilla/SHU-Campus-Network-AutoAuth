# Changelog

## v0.1.3 - 2026-05-30

- Added `setup.cmd` one-click setup entry point.
- Added `setup.ps1` setup wizard with automatic administrator elevation.
- Added pre-install system, network, portal gateway, and scheduled task status reporting.
- Added continuous configure, install, test, and final status flow.

## v0.1.2 - 2026-05-30

- Moved ePortal query string discovery from configuration time to login time.
- Removed the requirement to paste a current long ePortal login URL during normal setup.
- Added portal gateway configuration with `http://10.10.9.9/` as the default.
- Kept optional fallback support for a full ePortal login URL.

## v0.1.1 - 2026-05-30

- Added required password validation during configuration.
- Added automatic SHU ePortal login URL detection through `10.10.9.9`.
- Improved installation documentation and download paths.
- Added detailed supported network environment notes.

## v0.1.0 - 2026-05-29

- Added Shanghai University ePortal automatic authentication.
- Added Windows startup Scheduled Task installation as `SYSTEM`.
- Added interactive CLI configuration.
- Added Windows DPAPI machine-scope password storage.
- Added internet availability detection before login.
- Added log output and manual test command.
- Added publish-safe example configuration.
