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
  --user NAME       The user to add to the 'docker' group (default: you; as root,
                    the user who ran sudo)
  --channel CH      Pass a channel to the installer (e.g., 'stable', 'test', 'nightly')
  --manifest        Print installation manifest and exit

Docker is installed for every user of the machine: 'load.sh remove -- docker' leaves
it in place.

Examples:
  load.sh docker
  load.sh docker -- --dry-run
  sudo ~/.shellscript/bin/load.sh docker -- --user alice
```

[Script page](https://shellscript.download/scripts/docker) · [Source](https://github.com/byjg/shellscript-download/blob/main/public/scripts/docker.sh)
