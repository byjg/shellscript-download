---
# Auto-generated from public/scripts/nerdctl.sh — Do not edit.
description: "Install nerdctl with containerd and BuildKit, rootless by default"
---

# nerdctl

Install nerdctl with containerd and BuildKit, rootless by default

```bash
load.sh nerdctl
```

## Usage

```text
load.sh nerdctl -- [options]

Installs nerdctl, the Docker-compatible CLI of containerd, from its full bundle
(containerd, runc, BuildKit, RootlessKit and the CNI plugins), and enables the
containerd and BuildKit services.

By default it runs rootless: the bundle goes to $HOME/.shellscript/nerdctl/current and
the services are systemd user services of the current user. With --no-rootless it goes
to /opt/nerdctl, the services are system services and 'nerdctl' runs through sudo.

Rootless mode needs newuidmap (installed when missing), subordinate ids for the user
and a systemd user session. Uses sudo to install the missing packages (uidmap, iptables)
and, where AppArmor restricts user namespaces (Ubuntu 23.10 and later), to add a profile
that lets RootlessKit create them.

Options:
  -h, --help           Show this help and exit
  --version <version>  Version to install (default: latest), e.g. 2.4.0
  --force              Re-download even if already installed
  --no-rootless        Install system-wide and run the services as root (uses sudo)
  --no-services        Install the commands only: no containerd and BuildKit services
                       (for a machine without systemd)
  --docker             Also create a 'docker' command that runs nerdctl
                       (refused when Docker is installed)
  --dry-run            Print actions without executing them
  --manifest           Print installation manifest and exit

Examples:
  load.sh nerdctl
  load.sh nerdctl -- --docker
  load.sh nerdctl -- --no-rootless
  load.sh nerdctl -- --version 2.4.0
  load.sh remove -- nerdctl
```

[Script page](https://shellscript.download/scripts/nerdctl) · [Source](https://github.com/byjg/shellscript-download/blob/main/public/scripts/nerdctl.sh)
