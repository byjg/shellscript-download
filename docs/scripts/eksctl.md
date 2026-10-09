---
# Auto-generated from public/scripts/eksctl.sh — Do not edit.
description: "Download and install eksctl, the command-line tool for Amazon EKS clusters"
---

# eksctl

Download and install eksctl, the command-line tool for Amazon EKS clusters

```bash
load.sh eksctl
```

## Usage

```text
load.sh eksctl -- [options]

Downloads the eksctl binary for x86_64 and aarch64 Linux to
$HOME/.shellscript/eksctl/<version> and creates the 'eksctl' command. Run it again with
another --version to switch.

Options:
  -h, --help           Show this help and exit
  --version <version>  Version to install (default: latest), e.g. 0.231.0
  --force              Re-download even if already installed
  --dry-run            Print actions without executing them
  --manifest           Print installation manifest and exit

Examples:
  load.sh eksctl
  load.sh eksctl -- --version 0.231.0
  load.sh eksctl -- --dry-run
```

[Script page](https://shellscript.download/scripts/eksctl) · [Source](https://github.com/byjg/shellscript-download/blob/main/public/scripts/eksctl.sh)
