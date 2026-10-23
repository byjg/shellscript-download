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

# Code shared with the other scripts that install distro packages.
# load.sh downloads it with this script, from the name in the line below; a loader
# older than that leaves it missing.
SHARED_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/system-packages.sh"
if [[ ! -f "$SHARED_LIB" ]]; then
  echo "Error: lib/system-packages.sh, which this script needs, is missing: run 'load.sh --update'" >&2
  exit 3
fi
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

# Internal hook, not part of the user interface: executed by 'load.sh remove -- podman'
# through the UNINSTALL_CMD manifest key.
if [[ "$UNINSTALL" == "1" ]]; then
  remove_recorded_packages "Podman" "$PACKAGES_STATE"
  exit 0
fi

if [[ "${OSTYPE:-}" != linux* ]]; then
  err "This installer supports Linux only. Detected OSTYPE='${OSTYPE:-unknown}'."
  exit 1
fi

[[ "$DOCKER_ALIAS" != "1" ]] || docker_command_check Podman

ensure_package podman "Podman" podman "$PACKAGES_STATE"

[[ "$DOCKER_ALIAS" != "1" ]] || docker_command_write Podman podman

# Rootless containers need a range of subordinate ids for the user
if [[ "$(id -u)" != "0" ]] && ! grep -q "^$(id -un):" /etc/subuid 2>/dev/null; then
  log "Rootless Podman needs subordinate ids for your user. If containers fail to start, run:"
  log "  echo \"$(id -un):100000:65536\" | sudo tee -a /etc/subuid /etc/subgid && podman system migrate"
fi

log "Done. Try: podman run --rm hello-world"
