---
# Auto-generated from public/scripts/buildah.sh — Do not edit.
description: "Install Buildah on Linux, to build container images without a daemon"
---

# buildah

Install Buildah on Linux, to build container images without a daemon

```bash
load.sh buildah
```

## Usage

```text
load.sh buildah -- [options]

Installs Buildah from the system package manager (uses sudo). Buildah builds
container images without a daemon and, for a regular user, without root.

Options:
  -h, --help        Show this help and exit
  --dry-run         Print actions without executing them
  --manifest        Print installation manifest and exit

Examples:
  load.sh buildah
  load.sh buildah -- --dry-run
  load.sh remove -- buildah
```

[Script page](https://shellscript.download/scripts/buildah) · [Source](https://github.com/byjg/shellscript-download/blob/main/public/scripts/buildah.sh)
