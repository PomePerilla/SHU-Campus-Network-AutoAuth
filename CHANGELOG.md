# Changelog

## v1.0.0 - 2026-05-30

- Formalized the project as SHU NetAuth.
- Moved the current release structure to the repository root.
- Switched public release package naming to `SHU-NetAuth-v1.0.0.zip`.
- Removed the version-directory workflow from `main`; historical versions remain available through Git tags.
- Removed the old roadmap document and deferred UI plans.
- Added trusted portal host validation for ePortal URLs.
- Added trusted ePortal public key validation before credential submission.
- Added refusal behavior for unknown portal hosts, unknown `/eportal/` endpoints, public-key mismatch, and disabled password encryption.
- Rewrote `README.md` for normal user installation through GitHub Releases and `setup.cmd`.
- Rewrote `SECURITY.md` with credential storage, local data flow, network hijacking risk, remaining risks, and user recommendations.
- Consolidated release history into this root changelog.

## v0.1.3 - 2026-05-30

- Added `setup.cmd` one-click setup entry point.
- Added `setup.ps1` setup wizard with automatic administrator elevation.
- Added system, network, portal gateway, scheduled task, test, and log status reporting.
- Started publishing a user-friendly Release ZIP package.

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
