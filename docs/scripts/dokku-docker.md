---
# Auto-generated from public/scripts/dokku-docker.sh — Do not edit.
description: "Run Dokku, the self-hosted PaaS, as a Docker container on any Linux with Docker"
---

# dokku-docker

Run Dokku, the self-hosted PaaS, as a Docker container on any Linux with Docker

```bash
load.sh dokku-docker
```

## Usage

```text
load.sh dokku-docker -- [options]

Runs Dokku (https://dokku.com) in a Docker container named 'dokku', from the image
dokku/dokku, and Docker with 'load.sh docker' when it is missing. Its data (apps, config,
SSH keys) is kept in a folder of the host, so the container can be replaced without
losing it. The container has the Docker of the host: it runs the apps beside it.

Run again, it keeps the container as it is, with what it was given before, and replaces
it only when an option asks for something else. 'load.sh --upgrade' leaves it alone:
change the version with --version.

Options:
  -h, --help              Show this help and exit
  --version <ver>         Dokku version, e.g. 0.38.34 (default: the latest, on the first run)
  --hostname <domain>     Global domain of the apps (default: the name of the machine)
  --data-dir <dir>        Folder of the host with the data of Dokku (default: /var/lib/dokku)
  --ssh-port <port>       Port of the host for 'git push' (default: 3022)
  --http-port <port>      Port of the host for the apps over HTTP (default: 8080)
  --https-port <port>     Port of the host for the apps over HTTPS (default: 8443)
  --ssh-key <file>        Public keys allowed to push apps (default: ~/.ssh/authorized_keys).
                          A key already in Dokku is not added again
  --plugin <name>=<url>   Install a plugin, unless it is installed (can be repeated). It is
                          installed again when the container is replaced
  --dry-run               Print actions without executing them
  --manifest              Print installation manifest and exit

Examples:
  load.sh dokku-docker
  load.sh dokku-docker -- --hostname apps.example.com --http-port 80 --https-port 443
  load.sh dokku-docker -- --plugin postgres=https://github.com/dokku/dokku-postgres.git
  load.sh dokku-docker -- --version 0.38.34
  load.sh remove -- dokku-docker      # the data folder stays
```

[Script page](https://shellscript.download/scripts/dokku-docker) · [Source](https://github.com/byjg/shellscript-download/blob/main/public/scripts/dokku-docker.sh)
