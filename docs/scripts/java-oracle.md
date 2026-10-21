---
# Auto-generated from public/scripts/java-oracle.sh — Do not edit.
description: "Download and install Oracle JDK"
---

# java-oracle

Download and install Oracle JDK

```bash
load.sh java-oracle
```

## Usage

```text
load.sh java-oracle -- [options]

Downloads and installs Oracle JDK binary distribution for x86_64 and aarch64 Linux.

The installed version becomes the active Java, whatever its vendor:
$HOME/.shellscript/java/current points at it and JAVA_HOME follows. Run the installer
again with another --version to switch. To use another installed version in the
current shell only: java-use <vendor> <version>, e.g. java-use temurin 17.

Options:
  -h, --help           Show this help and exit
  --version <version>  Java major version to install (default: 25)
                       LTS versions: 25, and 17 and 21 as their last public build
                       (17.0.12, 21.0.12), which gets no more updates: later updates
                       need an Oracle account. For updates of 17 or 21: java-temurin
                       Non-LTS versions require confirmation (or --yes)
  --yes, -y            Skip confirmation for non-LTS versions
  --force              Re-download even if already installed
  --dry-run            Print actions without executing them
  --manifest [--version <version>]
                       Print installation manifest and exit
                       Without --version: removes all versions (default)
                       With --version: removes only specific version

Examples:
  load.sh java-oracle
  load.sh java-oracle -- --version 21
  load.sh java-oracle -- --version 27 --yes
  load.sh java-oracle -- --dry-run
  load.sh java-oracle -- --manifest --version 21

Note:
  By downloading and using Oracle JDK, you agree to the Oracle Technology Network License Agreement.
  For production use, please review Oracle's licensing terms.
```

[Script page](https://shellscript.download/scripts/java-oracle) · [Source](https://github.com/byjg/shellscript-download/blob/main/public/scripts/java-oracle.sh)
