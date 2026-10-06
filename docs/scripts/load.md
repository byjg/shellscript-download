---
# Auto-generated from public/scripts/load.sh — Do not edit.
description: "Fetch a script from https://shellscript.download, cache it locally, and optionally execute it."
---

# load

Fetch a script from https://shellscript.download, cache it locally, and optionally execute it.

## Usage

```text
load.sh [--update] [--dont-run] [--list] [--completion] [--developer <path>] <script> [optional args...]

Options:
  --update           Force re-download/update of the script even if it exists locally
  --dont-run         Do not execute the script after ensuring it is downloaded
  --list             List all available scripts from shellscript.download
  --completion       Install/update bash completion for load.sh into ~/.shellscript/shellrc/
  --developer <path> Use a local directory instead of downloading (for development)
  -h, --help         Show this help message

Arguments:
  <script>      The script name (without .sh) to fetch from shellscript.download
  [args...]     Optional arguments to pass through to the downloaded script
```

[Script page](https://shellscript.download/scripts/load) · [Source](https://github.com/byjg/shellscript-download/blob/main/public/scripts/load.sh)
