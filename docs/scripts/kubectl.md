---
# Auto-generated from public/scripts/kubectl.sh — Do not edit.
description: "Download and install kubectl, the Kubernetes command-line tool"
---

# kubectl

Download and install kubectl, the Kubernetes command-line tool

```bash
load.sh kubectl
```

## Usage

```text
load.sh kubectl -- [options]

Downloads the kubectl binary for x86_64 and aarch64 Linux to
$HOME/.shellscript/kubectl/<version> and creates the 'kubectl' command, with its completion for
bash (when the bash-completion package is installed) and zsh. Run it again with
another --version to switch.

Options:
  -h, --help           Show this help and exit
  --version <version>  Version to install (default: latest stable), e.g. 1.37.1
  --force              Re-download even if already installed
  --dry-run            Print actions without executing them
  --manifest           Print installation manifest and exit

Examples:
  load.sh kubectl
  load.sh kubectl -- --version 1.37.1
  load.sh kubectl -- --dry-run
```

[Script page](https://shellscript.download/scripts/kubectl) · [Source](https://github.com/byjg/shellscript-download/blob/main/public/scripts/kubectl.sh)
