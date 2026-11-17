---
# Auto-generated from public/scripts/remove.sh — Do not edit.
description: "Remove installed tools from shellscript.download"
---

# remove

Remove installed tools from shellscript.download

```bash
load.sh remove
```

## Usage

```text
load.sh remove -- [--purge] [--force] [--dry-run] <script-name>

Removes installed tools from shellscript.download.

What a script installed on the system (packages, repositories, services) is there for
every user of the machine: a user's remove takes out only what is the user's own.
Root takes out the rest, for everyone, with --force.

Options:
  --purge       Also remove tool folders (binaries/downloads)
  --force       As root: also remove what the script installed on the system
  --dry-run     Print actions without executing them
  -h, --help    Show this help and exit

Arguments:
  <script-name> Name of the script/tool to remove (e.g., maven, nvm)

Examples:
  load.sh remove -- maven
  load.sh remove -- --purge maven
  load.sh remove -- --dry-run --purge nvm
  sudo ~/.shellscript/bin/load.sh remove -- podman --force
```

[Script page](https://shellscript.download/scripts/remove) · [Source](https://github.com/byjg/shellscript-download/blob/main/public/scripts/remove.sh)
