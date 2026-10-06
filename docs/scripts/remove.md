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
load.sh remove -- [--purge] [--dry-run] <script-name>

Removes installed tools from shellscript.download.

Options:
  --purge       Also remove tool folders (binaries/downloads)
  --dry-run     Print actions without executing them
  -h, --help    Show this help and exit

Arguments:
  <script-name> Name of the script/tool to remove (e.g., maven, nvm)

Examples:
  load.sh remove -- maven
  load.sh remove -- --purge maven
  load.sh remove -- --dry-run --purge nvm
```

[Script page](https://shellscript.download/scripts/remove) · [Source](https://github.com/byjg/shellscript-download/blob/main/public/scripts/remove.sh)
