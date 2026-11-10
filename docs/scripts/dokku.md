---
# Auto-generated from public/scripts/dokku.sh — Do not edit.
description: "Install Dokku, the self-hosted PaaS, from its APT repository on Debian and Ubuntu"
---

# dokku

Install Dokku, the self-hosted PaaS, from its APT repository on Debian and Ubuntu

```bash
load.sh dokku
```

## Usage

```text
load.sh dokku -- [options]

Installs Dokku (https://dokku.com) from its APT repository on Debian and Ubuntu (uses
sudo), and Docker with 'load.sh docker' when it is missing. The machine becomes a Dokku
server: Dokku takes ports 80 and 443, and its first install removes the sites enabled in
nginx.

Run again, it installs nothing that is already there: it changes the version of Dokku
only when --version asks for another one. 'load.sh --upgrade' leaves it alone.

Options:
  -h, --help              Show this help and exit
  --version <ver>         Dokku version, e.g. 0.38.34 (default: the latest, when Dokku is
                          not installed yet)
  --hostname <domain>     Global domain of the apps (default, on the first install: the
                          hostname of the machine)
  --ssh-key <file>        Public keys allowed to push apps (default: ~/.ssh/authorized_keys).
                          A key already in Dokku is not added again
  --plugin <name>=<url>   Install a plugin, unless it is installed (can be repeated)
  --dry-run               Print actions without executing them
  --manifest              Print installation manifest and exit

Examples:
  load.sh dokku
  load.sh dokku -- --hostname apps.example.com
  load.sh dokku -- --plugin postgres=https://github.com/dokku/dokku-postgres.git
  load.sh dokku -- --version 0.38.34
  load.sh remove -- dokku
```

[Script page](https://shellscript.download/scripts/dokku) · [Source](https://github.com/byjg/shellscript-download/blob/main/public/scripts/dokku.sh)
