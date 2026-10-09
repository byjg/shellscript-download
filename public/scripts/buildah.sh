#!/usr/bin/env bash
# buildah.sh: Install Buildah on Linux, to build container images without a daemon

set -euo pipefail

print_usage() {
  cat <<'USAGE'
load.sh buildah -- [options]

Installs Buildah from the system package manager (uses sudo). Buildah builds
container images without a daemon and, for a regular user, without root.

Options:
  -h, --help        Show this help and exit
  --dry-run         Print actions without executing them
  --manifest        Print installation manifest and exit

Examples:
  load.sh buildah
  load.sh buildah -- --dry-run
  load.sh remove -- buildah
USAGE
}

print_manifest() {
  cat <<'MANIFEST'
BIN_FILES=
FOLDERS=$HOME/.shellscript/buildah
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
UNINSTALL=0
while [[ ${1-} ]]; do
  case "$1" in
    -h|--help) print_usage; exit 0 ;;
    --manifest) print_manifest; exit 0 ;;
    --dry-run) DRY_RUN=1 ;;
    uninstall) UNINSTALL=1 ;;
    *) err "Unknown option: $1"; print_usage; exit 2 ;;
  esac
  shift || true
done

PACKAGES_STATE="${SHELLSCRIPT_HOME}/buildah/installed-packages.conf"

# Internal hook, not part of the user interface: executed by 'load.sh remove -- buildah'
# through the UNINSTALL_CMD manifest key.
if [[ "$UNINSTALL" == "1" ]]; then
  remove_recorded_packages "Buildah" "$PACKAGES_STATE"
  exit 0
fi

if [[ "${OSTYPE:-}" != linux* ]]; then
  err "This installer supports Linux only. Detected OSTYPE='${OSTYPE:-unknown}'."
  exit 1
fi

ensure_package buildah "Buildah" buildah "$PACKAGES_STATE"

log "Done. Try: buildah --version"
