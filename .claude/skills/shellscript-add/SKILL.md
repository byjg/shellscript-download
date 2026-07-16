---
name: shellscript-add
description: >
  Use this skill whenever the user wants to add a new installer script to the shellscript.download
  project. Trigger when the user says things like "add a script for X", "create a new script to
  install Y", "write a .sh for Z", "add <tool> to the catalog", or any request to create or write
  a new public/scripts/*.sh file. Also trigger when the user asks how to contribute a new script
  or what the pattern for a new script looks like.
---

# Adding a New Script to shellscript.download

## Understand the request first

Before writing anything, identify:
- **What tool** is being installed (name, official website, GitHub repo)
- **Which pattern fits** (see "Installation patterns" below — choose before writing)
- **What binaries/commands** it provides (e.g., `mvn`, `node`, `java`)
- **Does it need a shell init snippet?** (e.g., `JAVA_HOME`, `NVM_DIR`, etc.)
- **Does it need a version parameter?** (most binary installs do; installer scripts usually just use latest)

If anything is unclear, ask before writing.

### Choosing the right pattern

| Pattern | Use when |
|---|---|
| **Binary download** | Tool ships a tarball/zip on GitHub releases (maven, java, gradle, …) |
| **Official installer** | Tool ships a curl-pipe-bash installer (nvm, rustup, …) |
| **Docker-backed wrapper** | Tool should run inside Docker — nothing installed on host (php-docker, node-docker, …) |

When Docker is the right fit (e.g., user wants multiple versions side-by-side without polluting the host, or tool is complex to install natively), use the Docker-backed pattern.

## Script file location

```
public/scripts/<name>.sh
```

The name must be lowercase, hyphenated, no spaces.

## Required structure — copy this skeleton

```bash
#!/usr/bin/env bash
# <name>.sh: One-line description shown in the scripts list table.

set -euo pipefail

print_usage() {
  cat <<'USAGE'
load.sh <name> -- [options]

Short description of what this script installs.

Options:
  -h, --help           Show this help and exit
  --dry-run            Print actions without executing them
  --manifest           Print installation manifest and exit
  --version <version>  Version to install (default: latest)   # omit if no versioning

Examples:
  load.sh <name>
  load.sh <name> -- --dry-run
  load.sh <name> -- --version 1.2.3
USAGE
}

print_manifest() {
  cat <<'MANIFEST'
BIN_FILES=<cmd1> <cmd2>          # space-separated wrapper names, or empty
FOLDERS=$HOME/.shellscript/<name>
SHELLRC_FILE=$HOME/.shellscript/shellrc/<name>-init.sh   # or empty if no init file
MANIFEST
}
```

Optional manifest key for scripts that install **system packages** (via sudo + package
manager, like qemu.sh): add `UNINSTALL_CMD=<subcommand>`. `remove.sh` runs
`<name>.sh <subcommand>` before its normal file cleanup. The subcommand must only remove
what the script itself installed — record newly installed packages in a state file under
`$SHELLSCRIPT_HOME/<name>/` at install time and uninstall exactly those (pre-existing
packages stay). See qemu.sh for the reference implementation.

```bash

# Parse flags
DRY_RUN=0
VERSION=""

while [[ ${1-} ]]; do
  case "$1" in
    -h|--help)    print_usage; exit 0 ;;
    --manifest)   print_manifest; exit 0 ;;
    --dry-run)    DRY_RUN=1 ;;
    --version)
      shift || { err "--version requires a value"; exit 2; }
      VERSION="$1"
      ;;
    *) err "Unknown option: $1"; print_usage; exit 2 ;;
  esac
  shift || true
done

# ... body ...
```

## Critical rules

**DO NOT define these — they are injected by load.sh at runtime:**
- `log()`, `err()`, `run()`, `require_cmd()`
- `fetch()` (URL → stdout), `download()` (URL → file), `require_downloader()`

**DO NOT call `curl` or `wget` directly.** Use `fetch "<url>"` to read a URL to stdout and
`download "<url>" "<dest>"` to save it to a file — both fall back from curl to wget
automatically. Use `require_downloader` (not `require_cmd curl`) as the precondition check.

**DO NOT hardcode `$HOME/.shellscript/...` paths.** Use the injected env vars:
| Variable | Value |
|---|---|
| `$SHELLSCRIPT_HOME` | `$HOME/.shellscript` |
| `$SHELLSCRIPT_BIN` | `$HOME/.shellscript/bin` |
| `$SHELLSCRIPT_SHELLRC` | `$HOME/.shellscript/shellrc` |
| `$SHELLSCRIPT_DOWNLOADS` | `$HOME/.shellscript/downloads` |

**`run "..."` handles dry-run automatically.** Wrap every side-effecting command with `run`. For heredoc writes that can't use `run`, guard them with `if [[ "$DRY_RUN" == "1" ]]; then log "[dry-run] Writing ..."; else ... fi`.

## Installation patterns

### Binary download (the most common — see maven.sh for reference)

```bash
require_downloader
require_cmd tar   # or unzip

# Fetch latest version from GitHub if none given
if [[ -z "$VERSION" ]]; then
  VERSION=$(fetch https://api.github.com/repos/<owner>/<repo>/releases/latest \
    | grep '"tag_name"' | sed 's/.*"tag_name": *"v\?\(.*\)".*/\1/')
  log "Latest version: ${VERSION}"
fi

TOOL_HOME="${SHELLSCRIPT_HOME}/<name>"
ARCHIVE="<name>-${VERSION}-linux-x64.tar.gz"
URL="https://..."
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

log "Downloading ${URL}"
run "download \"${URL}\" \"${TEMP_DIR}/${ARCHIVE}\""
run "mkdir -p \"${TOOL_HOME}\""
run "tar -xzf \"${TEMP_DIR}/${ARCHIVE}\" -C \"${TEMP_DIR}\""
run "rm -rf \"${TOOL_HOME}/current\""
run "mv \"${TEMP_DIR}/<extracted-dir>\" \"${TOOL_HOME}/current\""

# Wrapper script
run "mkdir -p \"${SHELLSCRIPT_BIN}\""
if [[ "$DRY_RUN" == "1" ]]; then
  log "[dry-run] Writing ${SHELLSCRIPT_BIN}/<cmd>"
else
  cat >"${SHELLSCRIPT_BIN}/<cmd>" <<'WRAP'
#!/usr/bin/env bash
exec "${HOME}/.shellscript/<name>/current/bin/<cmd>" "$@"
WRAP
  chmod +x "${SHELLSCRIPT_BIN}/<cmd>"
fi

# Shell init snippet — write one whenever the tool needs any shell-level setup
# to be ready in a new terminal session. Examples:
#   - export env vars (JAVA_HOME, MAVEN_HOME, …)
#   - add a secondary bin dir to PATH (composer vendor/bin, npm global bin, …)
#   - source the tool's own init script (like nvm.sh does: \. "$NVM_DIR/nvm.sh")
#   - load shell completions
# If the wrappers in $SHELLSCRIPT_BIN are sufficient and no shell state is needed,
# you can omit this block and leave SHELLRC_FILE empty in print_manifest.
run "mkdir -p \"${SHELLSCRIPT_SHELLRC}\""
if [[ "$DRY_RUN" == "1" ]]; then
  log "[dry-run] Writing ${SHELLSCRIPT_SHELLRC}/<name>-init.sh"
else
  cat >"${SHELLSCRIPT_SHELLRC}/<name>-init.sh" <<'WRAP'
export TOOL_HOME="$HOME/.shellscript/<name>/current"
# source "$TOOL_HOME/init.sh"   # if the tool ships its own init script
WRAP
fi

log "Done. <name> ${VERSION} installed."
```

### Official installer script (see nvm.sh for reference)

```bash
require_downloader

VERSION=$(fetch https://api.github.com/repos/<owner>/<repo>/releases/latest \
  | grep '"tag_name"' | sed 's/.*"tag_name": *"\(.*\)".*/\1/')
log "Installing <name> ${VERSION}"
run "fetch https://...install.sh | bash"

# Write init snippet
if [[ "$DRY_RUN" == "1" ]]; then
  log "[dry-run] Writing ${SHELLSCRIPT_SHELLRC}/<name>-init.sh"
else
  cat >"${SHELLSCRIPT_SHELLRC}/<name>-init.sh" <<'WRAP'
# init content here
WRAP
fi
```

### Docker-backed wrapper (see php-docker.sh and node-docker.sh for reference)

This pattern installs **nothing on the host** — it creates thin wrapper scripts that run the tool inside a Docker container, mounting the current working directory. Great for tools that benefit from version isolation (e.g., PHP, Node) or that are complex to install natively.

**Key structural differences from the other patterns:**
- Version is a **required positional argument**, not `--version` (because it's the primary parameter)
- Creates both **versioned wrappers** (`php8.3`, `node22`) and **unversioned symlinks** (`php`, `node`)
- `print_manifest` must accept the version as an argument since it's dynamic
- Validates Docker is present before doing anything
- Does **not** use `run()` for most operations — the wrappers themselves are written with heredocs and `chmod`; Docker pulls happen directly (they're interactive by nature)

**Skeleton:**

```bash
#!/usr/bin/env bash
# <name>-docker.sh: Create Docker-backed <name> launchers

set -euo pipefail

print_usage() {
  cat <<'USAGE'
load.sh <name>-docker -- <version> [--manifest]

Installs Docker-backed wrappers for <name> under $HOME/.shellscript/bin
using the <image>:<version> Docker image.

Options:
  --manifest    Print installation manifest and exit

Examples:
  load.sh <name>-docker -- <version>
  load.sh <name>-docker -- <version> --manifest
USAGE
}

print_manifest() {
  local version="${1:-VERSION}"
  cat <<MANIFEST
BIN_FILES=<cmd>${version} <cmd>
FOLDERS=\$HOME/.shellscript/<name>/${version}
SHELLRC_FILE=\$HOME/.shellscript/shellrc/<name>-init.sh
MANIFEST
}

# Help flag
if [[ "${1-}" == "-h" || "${1-}" == "--help" ]]; then
  print_usage; exit 0
fi

# Parse flags (manifest may appear before or after version)
SHOW_MANIFEST=0
VERSION=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)   print_usage; exit 0 ;;
    --manifest)  SHOW_MANIFEST=1; shift ;;
    *)           VERSION="$1"; shift ;;
  esac
done

if [[ -z "$VERSION" ]]; then
  err "<version> is required"; print_usage; exit 2
fi

if [[ "$SHOW_MANIFEST" -eq 1 ]]; then
  print_manifest "$VERSION"; exit 0
fi

# Pre-flight
if ! command -v docker >/dev/null 2>&1; then
  err "Docker is required but was not found on PATH."; exit 3
fi

# Pull image
DOCKER_IMAGE="<image>:${VERSION}"
log "Pulling ${DOCKER_IMAGE}"
docker pull "$DOCKER_IMAGE" || { err "Failed to pull ${DOCKER_IMAGE}"; exit 4; }

# Directories
TOOL_HOME="${SHELLSCRIPT_HOME}/<name>/${VERSION}"
mkdir -p "${SHELLSCRIPT_BIN}" "${SHELLSCRIPT_SHELLRC}" "${TOOL_HOME}"

# Wrapper — handles TTY detection, mounts CWD, forwards env vars
cat >"${SHELLSCRIPT_BIN}/<cmd>${VERSION}" <<WRAP
#!/usr/bin/env bash
set -euo pipefail
TTY_ARG=""
[ -t 0 ] && TTY_ARG="-i"
[ -t 1 ] && TTY_ARG="\${TTY_ARG} -t"
exec docker run \${TTY_ARG} --rm \\
  -v "\${PWD}:\${PWD}" -w "\${PWD}" \\
  --network host \\
  $DOCKER_IMAGE <cmd> "\$@"
WRAP
chmod +x "${SHELLSCRIPT_BIN}/<cmd>${VERSION}"

# Unversioned symlink (points to this version, overwritten on reinstall)
ln -sf "${SHELLSCRIPT_BIN}/<cmd>${VERSION}" "${SHELLSCRIPT_BIN}/<cmd>"

# Shell init snippet — write one whenever the shell needs initialization for
# the tool to be fully usable in a new terminal session. Examples:
#   - add a secondary bin dir to PATH (e.g. npm global bin, composer vendor/bin)
#   - export env vars the tool expects
#   - source the tool's own init script
# Omit entirely (and leave SHELLRC_FILE empty in print_manifest) if the
# wrappers in $SHELLSCRIPT_BIN are all the user needs.
cat >"${SHELLSCRIPT_SHELLRC}/<name>-init.sh" <<WRAP
export PATH="\$PATH:${TOOL_HOME}/bin"
WRAP

log "Done. <name> ${VERSION} wrappers created in ${SHELLSCRIPT_BIN}."
```

**Tips for Docker wrappers:**
- **TTY detection** (`[ -t 0 ]`, `[ -t 1 ]`) is important — without it interactive commands won't work properly
- **`--network host`** avoids most networking surprises inside the container
- **Volume mounts** — at minimum mount CWD; add more (cache dirs, config files, SSH socket) as the tool needs
- **Env forwarding** — for tools that need the host environment, loop over `env -0` and pass vars with `-e`, but skip host-specific ones like `PATH`, `HOME`, `USER`, `PWD`, `SHELL`
- **`ln -sf`** for unversioned symlinks makes reinstall idempotent
- **`--user $(id -u):$(id -g)`** — run as the host user so generated files aren't owned by root

## After writing the script

Run these steps in order:

```bash
# 1. Make executable (both steps required)
chmod +x public/scripts/<name>.sh
git update-index --chmod=+x public/scripts/<name>.sh

# 2. Syntax check
bash -n public/scripts/<name>.sh

# 3. Quick smoke test with dry-run
load.sh --developer ./public/scripts <name> -- --dry-run
load.sh --developer ./public/scripts <name> -- --help
load.sh --developer ./public/scripts <name> -- --manifest

# 4. Regenerate website pages
npm run build
```

If `npm run build` fails, check:
- The second line of the script must be `# <name>.sh: description text`
- The `print_usage` heredoc must use exactly `<<'USAGE'` ... `USAGE` markers

## Checklist before committing

- [ ] `bash -n` passes (no syntax errors)
- [ ] `-h/--help`, `--dry-run`, `--manifest` all work
- [ ] `--manifest` lists exactly what gets installed (for `remove.sh` compatibility)
- [ ] `--dry-run` prints all actions without side effects
- [ ] Paths use `$SHELLSCRIPT_*` variables, not hardcoded `$HOME/.shellscript/…`
- [ ] No `log`, `err`, `run`, `require_cmd`, `fetch`, or `download` defined locally
- [ ] No direct `curl`/`wget` calls — uses injected `fetch`/`download` helpers
- [ ] File is executable in git (`git update-index --chmod=+x`)
- [ ] `npm run build` completes without errors
- [ ] Generated files in `src/pages/scripts/` and `src/generated/` are staged

## Commit

Stage the script and the generated files together:

```bash
git add public/scripts/<name>.sh src/pages/scripts/<name>.tsx src/generated/scriptRoutes.tsx src/components/List.tsx
git commit -m "Add <name>.sh: <one-line description>"
```