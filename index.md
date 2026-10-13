# Linux-Café Ebersbach - Linux Mirror

This machine provides a local apt mirror and an update helper script.

## Run this on your client machine

```bash
curl -fsSL http://linux-mirror/setup.sh | bash -s -- run
```

## What it does

- rewrites apt sources to the local mirror
- runs `apt update`
- runs upgrade steps
- installs additional packages
- installs optional packages interactively
- changes system settings to sensible defaults

## Notes

- run as a user with sudo access
- inspect the script first if you want:

```bash
curl -fsSL http://linux-mirror/setup.sh
```

- you can also dry-run it (script will appear to execute completely but no changes will be done to your system)

```bash
curl -fsSL http://linux-mirror/setup.sh | bash -s -- run --dry-run
```

- or download it:

```bash
curl -fsSLO http://linux-mirror/setup.sh
```

