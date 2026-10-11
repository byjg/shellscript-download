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
- **Which pattern fits** (see "Choosing the right pattern" — choose before writing)
- **What binaries/commands** it provides (e.g., `mvn`, `node`, `java`)
- **Does it need a shell init snippet?** (e.g., `JAVA_HOME`, `NVM_DIR`, etc.)
- **Does it need a version parameter?** (most binary installs do; installer scripts usually just use latest)

If anything is unclear, ask before writing.

### Choosing the right pattern

| Pattern | Use when | Reference |
|---|---|---|
| **Single binary** | Tool is released as one binary, or a .tar.gz that holds it (jq, kubectl, helm, gh, …). The most common case | `jq.sh`, `gh.sh` + `lib/binary-install.sh` |
| **System package** | Tool comes from the distro package manager, with sudo (podman, buildah, …) | `buildah.sh`, `podman.sh` + `lib/system-packages.sh` |
| **Binary download** | Tool ships a tarball/zip with a whole directory tree (maven, ant, gcloud, …) | `maven.sh`, `gcloud.sh` |
| **Official installer** | Tool ships its own installer (nvm, aws-cli, docker, …) | `nvm.sh`, `aws-cli.sh` |
| **Docker-backed wrapper** | Tool should run inside Docker — nothing installed on host (php-docker, node-docker, …) | `node-docker.sh` + `lib/docker-wrapper.sh` |

Check the first two before writing anything by hand: with them a script is its usage text
plus a few lines.

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
manager): add `UNINSTALL_CMD=<subcommand>`. `remove.sh` runs `<name>.sh <subcommand>` before
its normal file cleanup. The subcommand must only remove what the script itself installed
(pre-existing packages stay): `lib/system-packages.sh` does that, see "System package" below.

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
- `require_script <script> [cmd]` — runs `load.sh <script>` unless `<cmd>` (default: the script
  name) is already available. For a tool another script of the catalog installs (e.g. jq).
  Loaders older than it do not have it: `if declare -F require_script >/dev/null; then
  require_script jq; else require_cmd jq; fi`

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

**Wrappers hold the absolute path, written at install time.** Use an unquoted heredoc so
that `${SHELLSCRIPT_HOME}` is expanded and `\$@` is not. A wrapper that looks up `$HOME`
when it runs breaks for another user or another HOME, which is how CI systems run it.

**DO NOT add tool-specific code to `load.sh`.**

## Shared code: `public/scripts/lib/` and the post-load hook

Code used by more than one script lives in `public/scripts/lib/` (not listed on the site).
Before writing install logic, check whether one of these already does it:

| File | What it gives |
|---|---|
| `lib/binary-install.sh` | The whole install of a single-binary tool: flags, architecture, download, versions, `current` link, wrapper, completion, manifest |
| `lib/system-packages.sh` | `detect_pm`, `ensure_package`, `install_packages`, `remove_recorded_packages`, `$SUDO` |
| `lib/java-install.sh` | The install shared by the `java-<vendor>.sh` scripts |
| `lib/docker-wrapper.sh` | The `--add/--volume/--env/--postinstall` options of the Docker-backed wrappers |

A script that uses one carries this block, right after `print_usage`/`print_manifest` and
before it parses its flags (replace the file name in the three places):

```bash
# Code shared with the other <kind of> scripts. load.sh calls postLoad once, right
# after it downloads or updates this script; a loader older than that hook never
# does, so the file is also fetched here when it is missing.
SHARED_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/<file>.sh"

postLoad() {
  mkdir -p "$(dirname "$SHARED_LIB")"
  if ! download "https://shellscript.download/scripts/lib/<file>.sh" "$SHARED_LIB"; then
    echo "Error: could not download lib/<file>.sh, which this script needs" >&2
    exit 3
  fi
}

if [[ "${1-}" == "--post-load" ]]; then
  postLoad
  exit 0
fi

[[ -f "$SHARED_LIB" ]] || postLoad
# shellcheck source=lib/<file>.sh
source "$SHARED_LIB"
```

`postLoad()` must start at the beginning of a line: that is how `load.sh` finds it. When a
second script needs what one script has, move it to `lib/` instead of copying it.

## Installation patterns

### Single binary (see jq.sh and gh.sh for reference)

The script is `print_usage`, the shared-code block for `lib/binary-install.sh`, and this:

```bash
BINARY_NAME="<name>"            # the command, and its folder under $SHELLSCRIPT_HOME
BINARY_LABEL="<Label>"          # name used in the messages
BINARY_COMPLETION="completion"  # optional, see below

# Prints the latest version, as --version takes it (no leading "v")
binary_latest_version() {
  github_latest_tag <owner>/<repo> | sed 's/^v//'
}

# Prints the URL for BINARY_VERSION and BINARY_ARCH (amd64 or arm64): the binary itself,
# or a .tar.gz that holds a file named BINARY_NAME
binary_download_url() {
  echo "https://github.com/<owner>/<repo>/releases/download/v${BINARY_VERSION}/<name>_linux_${BINARY_ARCH}.tar.gz"
}

binary_install "$@"
```

No `print_manifest` and no flag parsing: the shared code has `-h`, `--version`, `--force`,
`--dry-run` and `--manifest`. Copy the usage text from `jq.sh`.

- **Latest version**: `github_latest_tag` reads the latest release of a repository. When
  that is not the tool's (kustomize: the repository also releases its libraries) or the
  project publishes it elsewhere (kubectl: `dl.k8s.io/release/stable.txt`), write the lookup
  in `binary_latest_version`.
- **Completion**: set `BINARY_COMPLETION` to the arguments that make the tool print its
  completion script, without the shell name: `"completion"` for most, `"completion -s"` for
  gh, `"shell-completion"` for yq. Leave it out when the tool has none (jq). It is generated
  at install time, for bash only when the bash-completion package is installed and for zsh
  only when zsh is; with neither, no shell init file is written.
- Check that the download exists for both architectures before you finish.

### System package (see buildah.sh and podman.sh for reference)

The script is `print_usage`, a manifest with `UNINSTALL_CMD=uninstall`, the shared-code
block for `lib/system-packages.sh`, flag parsing that accepts the `uninstall` word, and:

```bash
PACKAGES_STATE="${SHELLSCRIPT_HOME}/<name>/installed-packages.conf"

# Internal hook, not part of the user interface: executed by 'load.sh remove -- <name>'
# through the UNINSTALL_CMD manifest key.
if [[ "$UNINSTALL" == "1" ]]; then
  remove_recorded_packages "<Label>" "$PACKAGES_STATE"
  exit 0
fi

# <command> <label> <package> <state file>: installs unless the command is there
ensure_package <cmd> "<Label>" <package> "$PACKAGES_STATE"
```

`ensure_package` records what it installs, and `remove_recorded_packages` removes only
that. Use `install_packages "$pm" "<pkg> <pkg>" "$PACKAGES_STATE"` when the package names
change with the package manager (`pm=$(detect_pm)`). A file the script writes outside the
home (a repository, a key) needs its own marker, so that the removal takes out only what
the script added: see `byjg-repo.sh`.

### Binary download (see maven.sh for reference)

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
  # Unquoted heredoc: the path is written now, not looked up through $HOME at run time
  cat >"${SHELLSCRIPT_BIN}/<cmd>" <<WRAP
#!/usr/bin/env bash
exec "${SHELLSCRIPT_HOME}/<name>/current/bin/<cmd>" "\$@"
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

The skeleton below is the minimum. `php-docker.sh` and `node-docker.sh` also take
`--add`, `--volume`, `--env` and `--postinstall`, all from `lib/docker-wrapper.sh`
(`docker_wrapper_option`, `docker_wrapper_configure`, `docker_image_packages`,
`docker_volume_args`, `docker_env_filter`, `docker_manifest_all`): a new Docker-backed
wrapper should use it too. Read `node-docker.sh` and `docs/docker-wrappers.md` first.

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

# 3. Quick smoke test with dry-run. Run the loader of the repository, not the installed
#    one: it is the one that has what this change may depend on.
bash public/scripts/load.sh --developer ./public/scripts <name> -- --dry-run
bash public/scripts/load.sh --developer ./public/scripts <name> -- --help
bash public/scripts/load.sh --developer ./public/scripts <name> -- --manifest

# 4. Regenerate website pages
npm run build
```

Then run it for real, in a throwaway container and never on the user's machine. `load.sh`
refuses to run as root, so create a user (with passwordless sudo when the script needs it):

```bash
docker run --rm -v "$PWD/public/scripts:/repo:ro" ubuntu:24.04 bash -c '
  apt-get update -qq && apt-get install -y -qq curl ca-certificates sudo >/dev/null
  useradd -m tester && echo "tester ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/tester
  su tester -c "bash /repo/load.sh --developer /repo <name> && \$HOME/.shellscript/bin/<cmd> --version"'
```

Check what applies: the tool runs, a rerun changes nothing, `--version` switches, a wrong
version stops without damage, and the removal takes out what was installed and nothing
else. `load.sh remove` reads the script from `~/.shellscript/downloads`, so copy the script
and `lib/` there before testing it in `--developer` mode. A script that installs packages
is tested on each package manager it claims (`fedora`, `alpine` images). Say what was not
tested.

If `npm run build` fails, check:
- The second line of the script must be `# <name>.sh: description text`
- The `print_usage` heredoc must use exactly `<<'USAGE'` ... `USAGE` markers

## Checklist before committing

- [ ] `bash -n` passes (no syntax errors)
- [ ] `-h/--help`, `--dry-run`, `--manifest` all work
- [ ] `--manifest` lists exactly what gets installed (for `remove.sh` compatibility)
- [ ] `--dry-run` prints all actions without side effects
- [ ] Paths use `$SHELLSCRIPT_*` variables, not hardcoded `$HOME/.shellscript/…`
- [ ] No `log`, `err`, `run`, `require_cmd`, `fetch`, `download` or `require_script` defined locally
- [ ] Nothing copied from another script: shared code is in `public/scripts/lib/`
- [ ] Wrappers hold the absolute path, not `$HOME`
- [ ] A real install was run in a container, and what was not tested is stated
- [ ] No direct `curl`/`wget` calls — uses injected `fetch`/`download` helpers
- [ ] File is executable in git (`git update-index --chmod=+x`)
- [ ] `npm run build` completes without errors
- [ ] Generated files are staged: `src/pages/scripts/`, `src/generated/`, `src/components/List.tsx`,
      `docs/scripts/` and `public/install/load-completion.sh`

## Commit

Work on a branch, never on `main`, and show the diff before committing. Stage the script,
any `lib/` file it touched and the generated files together:

```bash
git add public/scripts/<name>.sh public/scripts/lib src/pages/scripts/<name>.tsx \
  src/generated/scriptRoutes.tsx src/components/List.tsx docs/scripts \
  public/install/load-completion.sh
git commit -m "Add <name>.sh: <one-line description>"
```