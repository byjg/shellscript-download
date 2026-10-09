---
# Auto-generated from public/scripts/yq.sh — Do not edit.
description: "Download and install yq, the command-line YAML processor"
---

# yq

Download and install yq, the command-line YAML processor

```bash
load.sh yq
```

## Usage

```text
load.sh yq -- [options]

Downloads the yq binary for x86_64 and aarch64 Linux to
$HOME/.shellscript/yq/<version> and creates the 'yq' command, with its completion for
bash (when the bash-completion package is installed) and zsh. Run it again with
another --version to switch.

Options:
  -h, --help           Show this help and exit
  --version <version>  Version to install (default: latest), e.g. 4.47.1
  --force              Re-download even if already installed
  --dry-run            Print actions without executing them
  --manifest           Print installation manifest and exit

Examples:
  load.sh yq
  load.sh yq -- --version 4.47.1
  load.sh yq -- --dry-run
```

[Script page](https://shellscript.download/scripts/yq) · [Source](https://github.com/byjg/shellscript-download/blob/main/public/scripts/yq.sh)
