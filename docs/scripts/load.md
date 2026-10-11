---
# Auto-generated from public/scripts/load.sh — Do not edit.
description: "Fetch a script from https://shellscript.download, cache it locally, and optionally execute it."
---

# load

Fetch a script from https://shellscript.download, cache it locally, and optionally execute it.

## Usage

```text
load.sh [--update] [--upgrade] [--dont-run] [--list] [--installed] [--completion] [--developer <path>] <script> [optional args...]

Options:
  --update           Update the loader and the local cached copies of the scripts.
                     With a script: update only that script, then run it
  --upgrade          Install again what is installed, each script with the arguments it
                     was last installed with, so that a tool follows its latest version
                     and one that was given a version keeps it. With a script: only
                     that one. A script that has nothing newer to install skips it
  --dont-run         Do not execute the script after ensuring it is downloaded
  --list             List all available scripts from shellscript.download, with the
                     version of the ones installed on this machine
  --installed        List only the scripts installed on this machine
  --completion       Install/update bash completion for load.sh into ~/.shellscript/shellrc/
  --developer <path> Use a local directory instead of downloading (for development)
  -h, --help         Show this help message

Arguments:
  <script>      The script name (without .sh) to fetch from shellscript.download
  [args...]     Optional arguments to pass through to the downloaded script

Environment:
  GITHUB_TOKEN  Sent to the GitHub API, where the scripts look up the latest version of
                a tool. Without it GitHub answers 60 requests an hour per address.
```

[Script page](https://shellscript.download/scripts/load) · [Source](https://github.com/byjg/shellscript-download/blob/main/public/scripts/load.sh)
