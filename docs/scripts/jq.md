---
# Auto-generated from public/scripts/jq.sh — Do not edit.
description: "Download and install jq, the command-line JSON processor"
---

# jq

Download and install jq, the command-line JSON processor

```bash
load.sh jq
```

## Usage

```text
load.sh jq -- [options]

Downloads the jq binary for x86_64 and aarch64 Linux to
$HOME/.shellscript/jq/<version> and creates the 'jq' command. Run it again with
another --version to switch.

Options:
  -h, --help           Show this help and exit
  --version <version>  Version to install (default: latest), e.g. 1.8.1
  --force              Re-download even if already installed
  --dry-run            Print actions without executing them
  --manifest           Print installation manifest and exit

Examples:
  load.sh jq
  load.sh jq -- --version 1.8.1
  load.sh jq -- --dry-run
```

[Script page](https://shellscript.download/scripts/jq) · [Source](https://github.com/byjg/shellscript-download/blob/main/public/scripts/jq.sh)
