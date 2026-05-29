# Security Policy

## Credential Handling

The CLI stores the campus username in `config/portal.json`.

The password is stored separately in `config/portal.password.bin` using Windows DPAPI with `LocalMachine` scope. This supports unattended startup execution by the Windows `SYSTEM` account.

Do not commit these files:

```text
config/portal.json
config/portal.password.bin
logs/
```

## Security Boundary

DPAPI machine-scope encryption protects against casual file disclosure and prevents the encrypted password file from being useful on another machine.

It does not protect against a local administrator, malware running with sufficient privilege, or a compromised Windows installation.

## Reporting

For sensitive issues, avoid posting real campus credentials, MAC addresses, or portal URLs containing personal device parameters in public issues.
