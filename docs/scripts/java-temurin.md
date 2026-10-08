---
# Auto-generated from public/scripts/java-temurin.sh — Do not edit.
description: "Download and install Eclipse Temurin Java (OpenJDK)"
---

# java-temurin

Download and install Eclipse Temurin Java (OpenJDK)

```bash
load.sh java-temurin
```

## Usage

```text
load.sh java-temurin -- [options]

Downloads and installs Eclipse Temurin (Adoptium) OpenJDK binary distribution for x86_64 and aarch64 Linux.
Uses the Adoptium API to resolve the latest patch release for the requested major version.

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
  load.sh java-temurin
  load.sh java-temurin -- --version 17
  load.sh java-temurin -- --version 14 --yes
  load.sh java-temurin -- --dry-run
  load.sh java-temurin -- --manifest --version 17
```

[Script page](https://shellscript.download/scripts/java-temurin) · [Source](https://github.com/byjg/shellscript-download/blob/main/public/scripts/java-temurin.sh)
