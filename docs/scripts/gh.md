---
# Auto-generated from public/scripts/gh.sh — Do not edit.
description: "Download and install gh, the GitHub command-line tool"
---

# gh

Download and install gh, the GitHub command-line tool

```bash
load.sh gh
```

## Usage

```text
load.sh gh -- [options]

Downloads the GitHub CLI binary for x86_64 and aarch64 Linux to
$HOME/.shellscript/gh/<version> and creates the 'gh' command, with its completion for
bash (when the bash-completion package is installed) and zsh. Run it again with
another --version to switch.

Options:
  -h, --help           Show this help and exit
  --version <version>  Version to install (default: latest), e.g. 2.102.0
  --force              Re-download even if already installed
  --dry-run            Print actions without executing them
  --manifest           Print installation manifest and exit

Examples:
  load.sh gh
  load.sh gh -- --version 2.102.0
  load.sh gh -- --dry-run
```

[Script page](https://shellscript.download/scripts/gh) · [Source](https://github.com/byjg/shellscript-download/blob/main/public/scripts/gh.sh)
