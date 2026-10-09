---
# Auto-generated from public/scripts/kustomize.sh — Do not edit.
description: "Download and install Kustomize, to customize Kubernetes manifests"
---

# kustomize

Download and install Kustomize, to customize Kubernetes manifests

```bash
load.sh kustomize
```

## Usage

```text
load.sh kustomize -- [options]

Downloads the Kustomize binary for x86_64 and aarch64 Linux to
$HOME/.shellscript/kustomize/<version> and creates the 'kustomize' command, with its completion for
bash (when the bash-completion package is installed) and zsh. Run it again with
another --version to switch.

Options:
  -h, --help           Show this help and exit
  --version <version>  Version to install (default: latest), e.g. 5.8.3
  --force              Re-download even if already installed
  --dry-run            Print actions without executing them
  --manifest           Print installation manifest and exit

Examples:
  load.sh kustomize
  load.sh kustomize -- --version 5.8.3
  load.sh kustomize -- --dry-run
```

[Script page](https://shellscript.download/scripts/kustomize) · [Source](https://github.com/byjg/shellscript-download/blob/main/public/scripts/kustomize.sh)
