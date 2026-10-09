---
# Auto-generated from public/scripts/aws-cli.sh — Do not edit.
description: "Download and install the AWS CLI v2"
---

# aws-cli

Download and install the AWS CLI v2

```bash
load.sh aws-cli
```

## Usage

```text
load.sh aws-cli -- [options]

Downloads the AWS CLI v2 for x86_64 and aarch64 Linux and runs its installer for the
current user: it goes to $HOME/.shellscript/aws-cli, with the 'aws' command in
$HOME/.shellscript/bin. Nothing needs root. Run it again to update.

Options:
  -h, --help           Show this help and exit
  --version <version>  Version to install (default: latest), e.g. 2.31.0
  --dry-run            Print actions without executing them
  --manifest           Print installation manifest and exit

Examples:
  load.sh aws-cli
  load.sh aws-cli -- --version 2.31.0
  load.sh aws-cli -- --dry-run
```

[Script page](https://shellscript.download/scripts/aws-cli) · [Source](https://github.com/byjg/shellscript-download/blob/main/public/scripts/aws-cli.sh)
