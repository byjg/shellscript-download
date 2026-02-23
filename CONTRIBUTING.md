# Contributing to shellscript.download

## How it works (big picture)

Users install a single loader (`load.sh`) once. From then on they run:

```bash
load.sh <script-name>
```

`load.sh` downloads `<script-name>.sh` from the site, caches it locally, injects helpers and
standard environment variables, and then `exec`s the script. Scripts never need to define those
helpers themselves — they just use them.

---

## Adding a new script

### 1. Create the file

```
public/scripts/<name>.sh
```

### 2. Make it executable

```bash
chmod +x public/scripts/<name>.sh
git update-index --chmod=+x public/scripts/<name>.sh
```

Both steps are required: `chmod` sets the bit on disk, `git update-index` records it in the repository so it survives a fresh clone.

### 3. Required structure

```bash
#!/usr/bin/env bash
# <name>.sh: One-line description shown in the scripts list on the website.
#
# (optional additional header comments — shown on the script's detail page
#  when print_usage is absent)

set -euo pipefail

print_usage() {
  cat <<'USAGE'
load.sh <name> -- [options]

Short description of what this script does.

Options:
  -h, --help    Show this help and exit
  --dry-run     Print actions without executing them
  --manifest    Print installation manifest and exit

Examples:
  load.sh <name>
  load.sh <name> -- --dry-run
USAGE
}

print_manifest() {
  cat <<'MANIFEST'
BIN_FILES=<space-separated wrapper names, or empty>
FOLDERS=$HOME/.shellscript/<name>
SHELLRC_FILE=$HOME/.shellscript/shellrc/<name>-init.sh
MANIFEST
}

# Parse flags
DRY_RUN=0
while [[ ${1-} ]]; do
  case "$1" in
    -h|--help)   print_usage; exit 0 ;;
    --manifest)  print_manifest; exit 0 ;;
    --dry-run)   DRY_RUN=1 ;;
    *) err "Unknown option: $1"; print_usage; exit 2 ;;
  esac
  shift || true
done

# ... script body ...
```

#### What the generator reads from your file

| Part | Used for |
|---|---|
| Second line (`# <name>.sh: …`) | One-line description in the scripts list table |
| Consecutive `#` comment block at the top | Fallback detail page content (when `print_usage` is absent) |
| `print_usage` heredoc (`USAGE`…`USAGE`) | Content shown on the script's detail page |

---

## What `load.sh` injects

Every script is launched by `load.sh` via `exec`. Before handing off, `load.sh` exports the
following so scripts can use them without redeclaring:

### Helper functions

| Function | Behaviour |
|---|---|
| `log "message"` | Prints `[<script>.sh] message` to stdout |
| `err "message"` | Prints `[<script>.sh][ERROR] message` to stderr |
| `run "command"` | Runs the command normally, or prints `[dry-run] command` when `DRY_RUN=1` |
| `require_cmd curl` | Exits with an error if the command is not on `PATH` |

`log` and `err` use `basename "$0"` so the script name in the output is always correct.

`run` reads `DRY_RUN` at call-time — scripts set it in their own flag parsing with no conflict.

### Environment variables

| Variable | Default value | Purpose |
|---|---|---|
| `SHELLSCRIPT_HOME` | `$HOME/.shellscript` | Base directory for all installations |
| `SHELLSCRIPT_BIN` | `$HOME/.shellscript/bin` | Wrapper scripts (on `PATH` via the loader) |
| `SHELLSCRIPT_SHELLRC` | `$HOME/.shellscript/shellrc` | Shell init snippets sourced at login |
| `SHELLSCRIPT_DOWNLOADS` | `$HOME/.shellscript/downloads` | Cached script downloads |

All four directories are created by `load.sh` before `exec`, so scripts don't need to
`mkdir -p` them (though doing so is harmless).

**Use these variables for paths instead of hardcoding `$HOME/.shellscript/…`:**

```bash
# Good
TOOL_HOME="${SHELLSCRIPT_HOME}/mytool"
BIN_DIR="${SHELLSCRIPT_BIN}"
SHELLRC_DIR="${SHELLSCRIPT_SHELLRC}"

# Bad — fragile and defeats the abstraction
TOOL_HOME="$HOME/.shellscript/mytool"
```

---

## Standard flags every script must support

| Flag | Behaviour |
|---|---|
| `-h, --help` | Print usage and exit 0 |
| `--dry-run` | Set `DRY_RUN=1`; all `run "…"` calls print instead of execute |
| `--manifest` | Print install manifest and exit 0 (required for `remove.sh`) |

### The `--manifest` format

`remove.sh` calls `<script>.sh --manifest` to know what to clean up. The output must be:

```
BIN_FILES=<space-separated names in $SHELLSCRIPT_BIN, or empty>
FOLDERS=<space-separated absolute paths, or empty>
SHELLRC_FILE=<absolute path to the shellrc snippet, or empty>
```

Paths may use `$HOME` — `remove.sh` expands them via `eval`.

---

## Installation conventions

| What | Where | Example |
|---|---|---|
| Tool binaries / extracted archives | `$SHELLSCRIPT_HOME/<tool>/<version>` | `$SHELLSCRIPT_HOME/maven/current` |
| Wrapper scripts | `$SHELLSCRIPT_BIN/<cmd>` | `$SHELLSCRIPT_BIN/mvn` |
| Shell init snippet | `$SHELLSCRIPT_SHELLRC/<tool>-init.sh` | `$SHELLSCRIPT_SHELLRC/maven-init.sh` |

Wrappers should be minimal:

```bash
#!/usr/bin/env bash
exec "${HOME}/.shellscript/<tool>/current/bin/<cmd>" "$@"
```

---

## Local development

### Test your script without deploying

Use the `--developer <path>` flag to point `load.sh` at a local directory instead of
downloading from the internet:

```bash
# Run maven.sh from your working tree
load.sh --developer ./public/scripts maven

# Pass arguments through
load.sh --developer ./public/scripts maven -- --dry-run --version 3.9.6

# Verify injection without running
load.sh --developer ./public/scripts --dont-run maven
```

`load.sh` resolves `<path>/<script>.sh` and errors if the file is not found.

### Syntax-check your script

```bash
bash -n public/scripts/<name>.sh
```

### Regenerate the website pages

After creating or editing a script, regenerate the React pages and routes:

```bash
npm run build
```

This runs the generator automatically (`prebuild` hook) and produces:
- `src/pages/scripts/<name>.tsx` — detail page (do not edit manually)
- `src/generated/scriptRoutes.tsx` — route registry (do not edit manually)
- `dist/scripts/<name>.html` — static HTML

### Preview the site locally

```bash
npm run dev      # hot-reload dev server
npm run preview  # production build preview
```

---

## Testing in a clean environment

Always test scripts in a clean, non-root Linux environment before submitting. The easiest
way is Docker:

```bash
docker run -it --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$(pwd)/public/scripts":/scripts:ro \
  -v "$(pwd)/public/install":/install:ro \
  ubuntu:24.04 bash
```

Inside the container, create an unprivileged user (scripts refuse to run as root):

```bash
apt update && apt install -y curl sudo

useradd -m -s /bin/bash user
echo 'user ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

su - user
```

Then install the loader and test:

```bash
# Use the locally mounted installer with --developer — no network needed
bash /install/loader --developer

load.sh --developer /scripts <name> -- --dry-run
```

### Checklist before opening a PR

- [ ] File is executable: `chmod +x` and `git update-index --chmod=+x`
- [ ] `bash -n public/scripts/<name>.sh` passes
- [ ] Script supports `-h/--help`, `--dry-run`, `--manifest`
- [ ] `--manifest` output is correct (verified with `load.sh remove -- --dry-run <name>`)
- [ ] `--dry-run` prints all actions without side-effects
- [ ] Paths use `$SHELLSCRIPT_*` variables, not hardcoded `$HOME/.shellscript/…`
- [ ] No `log`, `err`, `run`, or `require_cmd` defined locally (they are injected)
- [ ] Tested in a clean Docker container
- [ ] `npm run build` completes without errors
- [ ] Generated files (`src/pages/scripts/`, `src/generated/`) are included in the commit

---

## Opening a pull request

1. Fork the repository and create a branch from `main`.
2. Make your changes — one script per PR is preferred.
3. Run through the checklist above.
4. Open a PR with a clear title and a short description of what the script installs and why
   it belongs in the catalog.

Keep PRs focused. If you are adding a script, the PR should contain only:
- `public/scripts/<name>.sh`
- The auto-generated files produced by `npm run build`
