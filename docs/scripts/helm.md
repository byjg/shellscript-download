---
# Auto-generated from public/scripts/helm.sh — Do not edit.
description: "Download and install Helm, the Kubernetes package manager"
---

# helm

Download and install Helm, the Kubernetes package manager

```bash
load.sh helm
```

## Usage

```text
load.sh helm -- [options]

Downloads the Helm binary for x86_64 and aarch64 Linux to
$HOME/.shellscript/helm/<version> and creates the 'helm' command. Run it again with
another --version to switch.

Options:
  -h, --help           Show this help and exit
  --version <version>  Version to install (default: latest), e.g. 3.19.0
  --force              Re-download even if already installed
  --dry-run            Print actions without executing them
  --manifest           Print installation manifest and exit

Examples:
  load.sh helm
  load.sh helm -- --version 3.19.0
  load.sh helm -- --dry-run
```

[Script page](https://shellscript.download/scripts/helm) · [Source](https://github.com/byjg/shellscript-download/blob/main/public/scripts/helm.sh)
