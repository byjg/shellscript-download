---
sidebar_position: 1
description: "Packages, volumes, environment and post-install scripts for the php-docker and node-docker wrappers"
---

# Docker-backed PHP and Node.js

`php-docker` and `node-docker` install `php`, `composer`, `node`, `npm`, `npx` and `yarn` as
wrappers that run inside a Docker container, so nothing but Docker is installed on the host.
The full option list is in [php-docker](scripts/php-docker.md) and
[node-docker](scripts/node-docker.md).

## Packages and volumes

`php-docker` builds a local `byjg/php:<version>-cli-load` image and remembers how to rebuild it:

```bash
# Alpine packages, saved to ~/.shellscript/php/packages.conf (shared by every PHP version)
load.sh php-docker -- 8.5 --add php85-gd,php85-intl

# Extra host directories to mount, saved to ~/.shellscript/php/volumes.conf
load.sh php-docker -- 8.5 --volume /home/user/projects

# A script for what apk cannot do (PECL builds, vendor clients)
load.sh php-docker -- 8.5 --postinstall ./install-oracle.sh
```

## Post-install script

The post-install script is copied to `~/.shellscript/php/<version>/postinstall.sh`, so it belongs
to that PHP version only. It runs as root inside the image after the packages, on every install
or update of that version, and a failure aborts the install. Delete the file to remove it.
It receives `PHP_VERSION` (`8.5`) and `PHP_VARIANT` (`php85`), and a line `# ENV NAME=value` in
it sets that environment variable in the image.

## Skipping a step

Every run rebuilds the image, replaying the packages and the post-install script. To leave a step
out for one run, or to drop the saved script:

```bash
# Change a volume without recompiling what the post-install script builds
load.sh php-docker -- 8.5 --volume /home/user/other --skip postinstall

# Skip both steps: a plain byjg/php image
load.sh php-docker -- 8.5 --skip packages,postinstall

# Delete the saved post-install script of this version
load.sh php-docker -- 8.5 --no-postinstall
```

## Environment variables

The `php` and `composer` wrappers forward your environment to the container, so
`MYSQL_HOST=db php script.php` works as it would without Docker. Variables that describe the host
are left out: the desktop session (`XDG_*`, `DISPLAY`, `GTK*`, `QT_*`, ...), systemd, the terminal
and IDE, host toolchains (`JAVA_HOME`, `NVM_*`, ...), `SSH_*` and agent variables. To forward one
of those anyway, list its name or a pattern in `~/.shellscript/php/env.conf`, one per line, or:

```bash
load.sh php-docker -- 8.5 --env 'JAVA_HOME,XDG_RUNTIME_DIR'
```

## node-docker

`node-docker` takes the same options (`--add`, `--volume`, `--env`, `--postinstall`,
`--no-postinstall`, `--skip`) and keeps its files under `~/.shellscript/node`:

```bash
load.sh node-docker -- 22 --add python3,make,g++ --volume /home/user/projects
```

Its wrappers (`node`, `npm`, `npx`, `yarn`) forward the environment with the same rule, so
`NODE_ENV=production node app.js` reaches Node, and `load.sh remove -- node-docker` works the same
way.

## Removing

`load.sh remove -- php-docker` removes the wrappers of every installed PHP version. With `--purge`
it also removes `~/.shellscript/php`, which holds `packages.conf`, `volumes.conf` and the
post-install scripts. The `byjg/php:<version>-cli-load` Docker images are left in place.
