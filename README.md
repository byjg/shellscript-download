---
sidebar_key: shellscript-download
tags: [devops, cli, docker]
---

# shellscript.download

[![Sponsor](https://img.shields.io/badge/Sponsor-%23ea4aaa?logo=githubsponsors&logoColor=white&labelColor=0d1117)](https://github.com/sponsors/byjg)
[![Opensource ByJG](https://img.shields.io/badge/opensource-byjg-success.svg)](https://opensource.byjg.com)
[![Install MCP Server](https://img.shields.io/badge/Install-MCP_Server-8A2BE2?logo=modelcontextprotocol&logoColor=white)](https://opensource.byjg.com/docs/ai/mcpserver-byjg-docs/)
[![GitHub source](https://img.shields.io/badge/Github-source-informational?logo=github)](https://github.com/byjg/shellscript-download/)
[![Build Status](https://github.com/byjg/shellscript-download/actions/workflows/e2e.yml/badge.svg?branch=main)](https://github.com/byjg/shellscript-download/actions/workflows/e2e.yml)

Install development tools on Linux with a single command. A small loader, `load.sh`, downloads a
curated script from [shellscript.download](https://shellscript.download) and runs it: Docker, PHP
and Node.js running in Docker, Java, Maven, NVM, QEMU virtual machines and more.

Everything is installed under `$HOME/.shellscript`, and anything a script installed can be removed
again.

## Install the loader

```bash
/bin/bash -c "$(curl -fsSL https://shellscript.download/install/loader)"
```

Or with `wget`:

```bash
/bin/bash -c "$(wget -qO- https://shellscript.download/install/loader)"
```

The loader needs `gpgv`, to check what it downloads. Ubuntu and Debian have it; on Fedora run
`sudo dnf install gnupg2`, on Alpine `sudo apk add gpgv`. To check the installer itself before
running it, see [Signed downloads](docs/signatures.md#the-first-install).

## Run a script

```bash
# Install the Docker Engine
load.sh docker

# Options of the script go after "--"
load.sh maven -- --version 3.9.6

# Show what a script would do, without doing it
load.sh nvm -- --dry-run

# Show the options of a script
load.sh php-docker -- --help
```

`load.sh --list` shows the scripts available, and so does the [script catalog](docs/scripts/).

## How the loader works

- A script that is not on the machine yet is downloaded from
  `https://shellscript.download/scripts/<script>.sh` and cached in
  `$HOME/.shellscript/downloads`.
- The cached copy is used on the next runs. `load.sh --update <script>` downloads it again.
- What is downloaded from shellscript.download (a script, the files the scripts share, the
  loader and its completion) is published with a signature, `<file>.sig`. The loader uses it only
  when that is the signature of the key written in `load.sh`, the one of
  `https://packages.byjg.com/byjg.gpg`; otherwise it stops and keeps what it had. See
  [Signed downloads](docs/signatures.md).
- The script is executed unless `--dont-run` is given, and `load.sh` exits with its status code.
- Commands a script installs go to `$HOME/.shellscript/bin`, which the loader adds to your `PATH`.

All its options are in the [load](docs/scripts/load.md) page.

## Remove what a script installed

```bash
load.sh remove -- maven

# Also remove the downloaded binaries
load.sh remove -- --purge maven
```

## Documentation

- [Script catalog](docs/scripts/): one page per script, with its options and examples
- [Docker-backed PHP and Node.js](docs/docker-wrappers.md): packages, volumes, environment
  variables and post-install scripts for `php-docker` and `node-docker`
- [Signed downloads](docs/signatures.md): what is signed, with which key, how to check the
  installer by hand, and what to do when a check fails

## Contributing

To add a script or work on the website, read the
[contributing guide](https://github.com/byjg/shellscript-download/blob/main/CONTRIBUTING.md#contributing-to-shellscriptdownload).

----
[Open source ByJG](https://opensource.byjg.com)
