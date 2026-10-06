---
# Auto-generated from public/scripts/docker.sh — Do not edit.
description: "Install the Docker Engine on Linux in a safe, idempotent, shell-friendly way"
---

# docker

Install the Docker Engine on Linux in a safe, idempotent, shell-friendly way

```bash
load.sh docker
```

## Usage

```text
load.sh docker -- [options]

Installs the Docker Engine on Linux using the official convenience script.

Options:
  -h, --help        Show this help and exit
  --dry-run         Print actions without executing them
  --no-group        Skip creating 'docker' group and user membership changes
  --channel CH      Pass a channel to the installer (e.g., 'stable', 'test', 'nightly')
  --manifest        Print installation manifest and exit

Examples:
  load.sh docker
  load.sh docker -- --dry-run
```

[Script page](https://shellscript.download/scripts/docker) · [Source](https://github.com/byjg/shellscript-download/blob/main/public/scripts/docker.sh)
