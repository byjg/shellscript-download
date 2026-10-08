---
# Auto-generated from public/scripts/java-corretto.sh — Do not edit.
description: "Download and install Amazon Corretto OpenJDK"
---

# java-corretto

Download and install Amazon Corretto OpenJDK

```bash
load.sh java-corretto
```

## Usage

```text
load.sh java-corretto -- [options]

Downloads and installs Amazon Corretto OpenJDK binary distribution for x86_64 and aarch64 Linux.

The installed version becomes the active Java, whatever its vendor:
$HOME/.shellscript/java/current points at it and JAVA_HOME follows. Run the installer
again with another --version to switch.

Options:
  -h, --help           Show this help and exit
  --version <version>  Java major version to install (default: 21)
                       LTS versions: 8, 11, 17, 21, 25
                       Non-LTS versions require confirmation (or --yes)
  --yes, -y            Skip confirmation for non-LTS versions
  --force              Re-download even if already installed
  --dry-run            Print actions without executing them
  --manifest [--version <version>]
                       Print installation manifest and exit
                       Without --version: removes all versions (default)
                       With --version: removes only specific version

Examples:
  load.sh java-corretto
  load.sh java-corretto -- --version 17
  load.sh java-corretto -- --version 14 --yes
  load.sh java-corretto -- --dry-run
  load.sh java-corretto -- --manifest --version 21
```

[Script page](https://shellscript.download/scripts/java-corretto) · [Source](https://github.com/byjg/shellscript-download/blob/main/public/scripts/java-corretto.sh)
