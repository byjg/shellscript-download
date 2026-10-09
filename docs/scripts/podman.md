---
# Auto-generated from public/scripts/podman.sh — Do not edit.
description: "Install Podman on Linux, optionally answering to the 'docker' command"
---

# podman

Install Podman on Linux, optionally answering to the 'docker' command

```bash
load.sh podman
```

## Usage

```text
load.sh podman -- [options]

Installs Podman from the system package manager (uses sudo). Podman runs containers
without a daemon and, for a regular user, without root.

Options:
  -h, --help        Show this help and exit
  --dry-run         Print actions without executing them
  --docker          Also create a 'docker' command that runs Podman
                    (for commands and scripts written for Docker; refused when
                    Docker is installed)
  --manifest        Print installation manifest and exit

The 'docker' command is for plain Docker commands. The php-docker and node-docker
wrappers are written for the Docker Engine and are not supported on top of it.

Examples:
  load.sh podman
  load.sh podman -- --docker
  load.sh podman -- --dry-run
  load.sh remove -- podman
```

[Script page](https://shellscript.download/scripts/podman) · [Source](https://github.com/byjg/shellscript-download/blob/main/public/scripts/podman.sh)
