#!/usr/bin/env bash
# podman.sh: Install Podman on Linux, optionally answering to the 'docker' command

set -euo pipefail

print_usage() {
  cat <<'USAGE'
load.sh podman -- [options]

Installs Podman from the system package manager (uses sudo). Podman runs containers
without a daemon and, for a regular user, without root.

Options:
  -h, --help        Show this help and exit
  --dry-run         Print actions without executing them
  --docker          Also create a 'docker' command that runs Podman
                    (for commands and scripts written for Docker; refused when
                    Docker is installed)
  --manifest        Print installation manifest and exit

The 'docker' command is for plain Docker commands. The php-docker and node-docker
wrappers are written for the Docker Engine and are not supported on top of it.

Examples:
  load.sh podman
  load.sh podman -- --docker
  load.sh podman -- --dry-run
  load.sh remove -- podman
USAGE
}

print_manifest() {
  cat <<'MANIFEST'
BIN_FILES=docker
FOLDERS=$HOME/.shellscript/podman
SHELLRC_FILE=
UNINSTALL_CMD=uninstall
MANIFEST
}

# Code shared with the other scripts that install distro packages. load.sh calls
# postLoad once, right after it downloads or updates this script; a loader older than
# that hook never does, so the file is also fetched here when it is missing.
SHARED_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/system-packages.sh"

postLoad() {
  mkdir -p "$(dirname "$SHARED_LIB")"
  if ! download "https://shellscript.download/scripts/lib/system-packages.sh" "$SHARED_LIB"; then
    echo "Error: could not download lib/system-packages.sh, which this script needs" >&2
    exit 3
  fi
}

if [[ "${1-}" == "--post-load" ]]; then
  postLoad
  exit 0
fi

[[ -f "$SHARED_LIB" ]] || postLoad
# shellcheck source=lib/system-packages.sh
source "$SHARED_LIB"

# Parse flags
DRY_RUN=0
DOCKER_ALIAS=0
UNINSTALL=0
while [[ ${1-} ]]; do
  case "$1" in
    -h|--help) print_usage; exit 0 ;;
    --manifest) print_manifest; exit 0 ;;
    --dry-run) DRY_RUN=1 ;;
    --docker) DOCKER_ALIAS=1 ;;
    uninstall) UNINSTALL=1 ;;
    *) err "Unknown option: $1"; print_usage; exit 2 ;;
  esac
  shift || true
done

PACKAGES_STATE="${SHELLSCRIPT_HOME}/podman/installed-packages.conf"
DOCKER_WRAPPER="${SHELLSCRIPT_BIN}/docker"

# Internal hook, not part of the user interface: executed by 'load.sh remove -- podman'
# through the UNINSTALL_CMD manifest key.
if [[ "$UNINSTALL" == "1" ]]; then
  if [[ -s "$PACKAGES_STATE" ]]; then
    remove_recorded_packages "$PACKAGES_STATE"
  else
    log "Podman was not installed by this script — leaving system packages untouched."
  fi
  exit 0
fi

if [[ "${OSTYPE:-}" != linux* ]]; then
  err "This installer supports Linux only. Detected OSTYPE='${OSTYPE:-unknown}'."
  exit 1
fi

# A 'docker' that is not our own wrapper is the real one: never shadow it
if [[ "$DOCKER_ALIAS" == "1" ]]; then
  while IFS= read -r found; do
    if [[ "$found" != "$DOCKER_WRAPPER" ]]; then
      err "Docker is already installed (${found}): not creating a 'docker' command for Podman."
      err "Run again without --docker, or remove Docker first."
      exit 3
    fi
  done < <(type -aP docker 2>/dev/null || true)
fi

if command -v podman >/dev/null 2>&1; then
  log "Podman is already installed: $(podman --version)"
else
  pm=$(detect_pm) || {
    err "No supported package manager found (apt, dnf, pacman, zypper, apk)."
    err "Install Podman manually and re-run your command."
    exit 3
  }
  [[ -z "$SUDO" ]] || require_cmd sudo
  install_packages "$pm" "podman" "$PACKAGES_STATE"
fi

if [[ "$DOCKER_ALIAS" == "1" ]]; then
  run "mkdir -p \"${SHELLSCRIPT_BIN}\""
  if [[ "$DRY_RUN" == "1" ]]; then
    log "[dry-run] Writing ${DOCKER_WRAPPER}"
  else
    cat >"$DOCKER_WRAPPER" <<'WRAP'
#!/usr/bin/env bash
exec podman "$@"
WRAP
    chmod +x "$DOCKER_WRAPPER"
  fi
  log "The 'docker' command now runs Podman."
fi

# Rootless containers need a range of subordinate ids for the user
if [[ "$(id -u)" != "0" ]] && ! grep -q "^$(id -un):" /etc/subuid 2>/dev/null; then
  log "Rootless Podman needs subordinate ids for your user. If containers fail to start, run:"
  log "  echo \"$(id -un):100000:65536\" | sudo tee -a /etc/subuid /etc/subgid && podman system migrate"
fi

log "Done. Try: podman run --rm hello-world"
