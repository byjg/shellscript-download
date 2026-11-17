#!/usr/bin/env bash
# buildah.sh: Install Buildah on Linux, to build container images without a daemon

set -euo pipefail

# It changes the system: load.sh keeps one copy of it for every user, owned by root
SYSTEM_SCRIPT=yes

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

PACKAGES_STATE="$(system_state buildah)/installed-packages.conf"
system_state_migrate buildah installed-packages.conf cgroups-service

# Internal hook, not part of the user interface: executed by 'load.sh remove -- buildah'
# through the UNINSTALL_CMD manifest key. The package is there for every user: only
# root takes it out, with --force.
if [[ "$UNINSTALL" == "1" ]]; then
  if system_release buildah; then
    remove_recorded_packages "Buildah" "$PACKAGES_STATE"
    rootless_host_undo buildah
    system_forget buildah
  fi
  exit 0
fi

if [[ "${OSTYPE:-}" != linux* ]]; then
  err "This installer supports Linux only. Detected OSTYPE='${OSTYPE:-unknown}'."
  exit 1
fi

# Alpine packages the network helpers apart, and Buildah needs them to build
packages="buildah"
[[ "$(detect_pm || true)" != "apk" ]] || packages="buildah netavark passt"
ensure_package buildah "Buildah" "$packages" "$PACKAGES_STATE"
rootless_host_setup buildah
system_user_add buildah

subuid_hint Buildah

log "Done. Try: buildah --version"
