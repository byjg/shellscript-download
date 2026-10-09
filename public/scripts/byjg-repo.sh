#!/usr/bin/env bash
# byjg-repo.sh: Add the ByJG package repository (APT or RPM) to install ByJG tools

set -euo pipefail

print_usage() {
  cat <<'USAGE'
load.sh byjg-repo -- [options]

Adds the ByJG package repository to the system (uses sudo), with its signing key:
the APT one on Debian and Ubuntu, the RPM one on Fedora and RHEL. Its packages are
then installed and updated by the system package manager.
More: https://opensource.byjg.com/docs/packages

Options:
  -h, --help           Show this help and exit
  --install <package>  Also install a package of the repository (can be repeated)
  --list               List the packages of the repository and exit
  --dry-run            Print actions without executing them
  --manifest           Print installation manifest and exit

Examples:
  load.sh byjg-repo
  load.sh byjg-repo -- --list
  load.sh byjg-repo -- --install parolsh
  load.sh remove -- byjg-repo
USAGE
}

print_manifest() {
  cat <<'MANIFEST'
BIN_FILES=
FOLDERS=$HOME/.shellscript/byjg-repo
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
LIST=0
UNINSTALL=0
PACKAGES=""
while [[ ${1-} ]]; do
  case "$1" in
    -h|--help) print_usage; exit 0 ;;
    --manifest) print_manifest; exit 0 ;;
    --dry-run) DRY_RUN=1 ;;
    --list) LIST=1 ;;
    --install)
      shift || { err "--install requires a package name"; exit 2; }
      PACKAGES+=" $1"
      ;;
    uninstall) UNINSTALL=1 ;;
    *) err "Unknown option: $1"; print_usage; exit 2 ;;
  esac
  shift || true
done
PACKAGES="${PACKAGES# }"

REPO_URL="https://opensource.byjg.com"
STATE_DIR="${SHELLSCRIPT_HOME}/byjg-repo"
PACKAGES_STATE="${STATE_DIR}/installed-packages.conf"
# Present when this script added the repository: only then does the removal take it out
REPO_STATE="${STATE_DIR}/repository-added"

APT_KEY="/etc/apt/keyrings/byjg.gpg"
APT_SOURCE="/etc/apt/sources.list.d/byjg.sources"
RPM_REPO="/etc/yum.repos.d/byjg.repo"

PM=$(detect_pm) || true
case "$PM" in
  apt-get) REPO_FILE="$APT_SOURCE" ;;
  dnf)     REPO_FILE="$RPM_REPO" ;;
  *)
    err "The ByJG repository has APT (Debian, Ubuntu) and RPM (Fedora, RHEL) packages only."
    err "See ${REPO_URL}/docs/packages"
    exit 3
    ;;
esac
[[ -z "$SUDO" ]] || require_cmd sudo

# Internal hook, not part of the user interface: executed by 'load.sh remove -- byjg-repo'
# through the UNINSTALL_CMD manifest key.
if [[ "$UNINSTALL" == "1" ]]; then
  remove_recorded_packages "A ByJG package" "$PACKAGES_STATE"
  if [[ ! -e "$REPO_STATE" ]]; then
    log "The repository was not added by this script — leaving it in place."
    exit 0
  fi
  log "Removing the ByJG repository"
  case "$PM" in
    apt-get) run "${SUDO} rm -f ${APT_SOURCE} ${APT_KEY}; ${SUDO} apt-get update" ;;
    dnf)     run "${SUDO} rm -f ${RPM_REPO}; ${SUDO} dnf clean all" ;;
  esac
  [[ "$DRY_RUN" == "1" ]] || rm -f "$REPO_STATE"
  exit 0
fi

if [[ "$LIST" == "1" ]]; then
  [[ -e "$REPO_FILE" ]] || { err "The repository is not set up yet. Run: load.sh byjg-repo"; exit 1; }
  case "$PM" in
    # Read from the repository itself: where apt keeps its index, and whether it is
    # compressed, changes from one system to another
    apt-get) fetch "${REPO_URL}/apt/Packages" | grep '^Package: ' | sed 's/^Package: //' | sort -u ;;
    # -y: the first query imports the signing key of the repository metadata
    dnf)     dnf -q -y repoquery --repo=byjg --available --qf '%{name}\n' | sort -u ;;
  esac
  exit 0
fi

if [[ -e "$REPO_FILE" ]]; then
  log "The ByJG repository is already set up: ${REPO_FILE}"
else
  require_downloader
  TEMP_DIR=$(mktemp -d)
  trap 'rm -rf "$TEMP_DIR"' EXIT

  log "Adding the ByJG repository: ${REPO_FILE}"
  case "$PM" in
    apt-get)
      run "download \"${REPO_URL}/byjg.gpg\" \"${TEMP_DIR}/byjg.gpg\""
      run "${SUDO} install -D -m 644 \"${TEMP_DIR}/byjg.gpg\" ${APT_KEY}"
      run "printf 'Types: deb\nURIs: ${REPO_URL}/apt\nSuites: /\nSigned-By: ${APT_KEY}\n' | ${SUDO} tee ${APT_SOURCE} >/dev/null"
      # See install_packages: the index of another source may fail to update
      run "${SUDO} apt-get update || true"
      ;;
    dnf)
      run "download \"${REPO_URL}/byjg.asc\" \"${TEMP_DIR}/byjg.asc\""
      run "${SUDO} rpm --import \"${TEMP_DIR}/byjg.asc\""
      run "printf '[byjg]\nname=ByJG Packages\nbaseurl=${REPO_URL}/rpm\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=1\ngpgkey=${REPO_URL}/byjg.asc\n' | ${SUDO} tee ${RPM_REPO} >/dev/null"
      ;;
  esac
  if [[ "$DRY_RUN" != "1" ]]; then
    mkdir -p "$STATE_DIR"
    : > "$REPO_STATE"
  fi
fi

[[ -z "$PACKAGES" ]] || install_packages "$PM" "$PACKAGES" "$PACKAGES_STATE"

log "Done. List the packages with: load.sh byjg-repo -- --list"
