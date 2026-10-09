---
# Auto-generated from public/scripts/doctl.sh — Do not edit.
description: "Download and install doctl, the DigitalOcean command-line tool"
---

# doctl

Download and install doctl, the DigitalOcean command-line tool

```bash
load.sh doctl
```

## Usage

```text
load.sh doctl -- [options]

Downloads the doctl binary for x86_64 and aarch64 Linux to
$HOME/.shellscript/doctl/<version> and creates the 'doctl' command, with its completion for
bash (when the bash-completion package is installed) and zsh. Run it again with
another --version to switch.

Options:
  -h, --help           Show this help and exit
  --version <version>  Version to install (default: latest), e.g. 1.181.0
  --force              Re-download even if already installed
  --dry-run            Print actions without executing them
  --manifest           Print installation manifest and exit

Examples:
  load.sh doctl
  load.sh doctl -- --version 1.181.0
  load.sh doctl -- --dry-run
```

[Script page](https://shellscript.download/scripts/doctl) · [Source](https://github.com/byjg/shellscript-download/blob/main/public/scripts/doctl.sh)
