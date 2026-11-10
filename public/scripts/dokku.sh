#!/usr/bin/env bash
# dokku.sh: Install Dokku, the self-hosted PaaS, from its APT repository on Debian and Ubuntu

set -euo pipefail

print_usage() {
  cat <<'USAGE'
load.sh dokku -- [options]

Installs Dokku (https://dokku.com) from its APT repository on Debian and Ubuntu (uses
sudo), and Docker with 'load.sh docker' when it is missing. The machine becomes a Dokku
server: Dokku takes ports 80 and 443, and its first install removes the sites enabled in
nginx.

Run again, it installs nothing that is already there: it changes the version of Dokku
only when --version asks for another one. 'load.sh --upgrade' leaves it alone.

Options:
  -h, --help              Show this help and exit
  --version <ver>         Dokku version, e.g. 0.38.34 (default: the latest, when Dokku is
                          not installed yet)
  --hostname <domain>     Global domain of the apps (default, on the first install: the
                          hostname of the machine)
  --ssh-key <file>        Public keys allowed to push apps (default: ~/.ssh/authorized_keys).
                          A key already in Dokku is not added again
  --plugin <name>=<url>   Install a plugin, unless it is installed (can be repeated)
  --dry-run               Print actions without executing them
  --manifest              Print installation manifest and exit

Examples:
  load.sh dokku
  load.sh dokku -- --hostname apps.example.com
  load.sh dokku -- --plugin postgres=https://github.com/dokku/dokku-postgres.git
  load.sh dokku -- --version 0.38.34
  load.sh remove -- dokku
USAGE
}

print_manifest() {
  cat <<'MANIFEST'
BIN_FILES=
FOLDERS=$HOME/.shellscript/dokku
SHELLRC_FILE=
UNINSTALL_CMD=uninstall
UPGRADE=no
MANIFEST
}

# Code shared with dokku-docker.sh.
# load.sh downloads it with this script, from the name in the line below; a loader
# older than that leaves it missing.
SHARED_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/dokku.sh"
if [[ ! -f "$SHARED_LIB" ]]; then
  echo "Error: lib/dokku.sh, which this script needs, is missing: run 'load.sh --update'" >&2
  exit 3
fi
# shellcheck source=lib/dokku.sh
source "$SHARED_LIB"

# Parse flags
DRY_RUN=0
UNINSTALL=0
VERSION=""
DOMAIN=""
SSH_KEY_FILE="${HOME}/.ssh/authorized_keys"
PLUGINS=()
while [[ ${1-} ]]; do
  case "$1" in
    -h|--help) print_usage; exit 0 ;;
    --manifest) print_manifest; exit 0 ;;
    --dry-run) DRY_RUN=1 ;;
    --version)  shift || true; VERSION="${1-}"; [[ -n "$VERSION" ]] || { err "--version requires a value"; exit 2; } ;;
    --hostname) shift || true; DOMAIN="${1-}"; [[ -n "$DOMAIN" ]] || { err "--hostname requires a value"; exit 2; } ;;
    --ssh-key)  shift || true; SSH_KEY_FILE="${1-}"; [[ -f "$SSH_KEY_FILE" ]] || { err "--ssh-key: no such file: ${SSH_KEY_FILE}"; exit 2; } ;;
    --plugin)
      shift || true
      [[ "${1-}" == ?*=?* ]] || { err "--plugin requires <name>=<url>"; exit 2; }
      PLUGINS+=("$1")
      ;;
    uninstall) UNINSTALL=1 ;;
    *) err "Unknown option: $1"; print_usage; exit 2 ;;
  esac
  shift || true
done
VERSION="${VERSION#v}"

# Dokku is installed on the system, or Docker run, with sudo
require_cmd sudo

STATE_DIR="${SHELLSCRIPT_HOME}/dokku"
# Present when this script installed Dokku: only then does the removal take it out
INSTALL_STATE="${STATE_DIR}/installed"

APT_KEY="/etc/apt/keyrings/dokku.asc"
APT_SOURCE="/etc/apt/sources.list.d/dokku.sources"
# Where the official installer (bootstrap.sh) puts the repository
BOOTSTRAP_SOURCE="/etc/apt/sources.list.d/dokku.list"
REPO_URL="https://packagecloud.io/dokku/dokku"

# installed_version: the version of the Dokku package, or nothing
installed_version() {
  { dpkg-query -W -f='${db:Status-Status} ${Version}' dokku 2>/dev/null || true; } | sed -n 's/^installed //p'
}

# Internal hook, not part of the user interface: executed by 'load.sh remove -- dokku'
# through the UNINSTALL_CMD manifest key.
if [[ "$UNINSTALL" == "1" ]]; then
  if [[ ! -e "$INSTALL_STATE" ]]; then
    log "Dokku was not installed by this script — leaving it in place."
    exit 0
  fi
  log "Removing Dokku and its repository (Docker stays: 'load.sh remove -- docker')"
  run "sudo DEBIAN_FRONTEND=noninteractive apt-get purge -y dokku herokuish"
  run "sudo rm -f ${APT_SOURCE} ${APT_KEY}; sudo apt-get update || true"
  [[ "$DRY_RUN" == "1" ]] || rm -f "$INSTALL_STATE"
  exit 0
fi

# Dokku publishes packages for Debian and Ubuntu: the repository says which releases.
# Asking it, rather than keeping a list here, follows the releases Dokku adds or drops.
# shellcheck disable=SC1091
OS_ID="$(. /etc/os-release && echo "${ID:-}")"
# shellcheck disable=SC1091
OS_CODENAME="$(. /etc/os-release && echo "${VERSION_CODENAME:-}")"
require_downloader
if ! command -v apt-get >/dev/null 2>&1 || ! fetch "${REPO_URL}/${OS_ID}/dists/${OS_CODENAME}/Release" >/dev/null 2>&1; then
  err "Dokku has no packages for this system (${OS_ID} ${OS_CODENAME}): it supports Debian and Ubuntu."
  err "See https://dokku.com/docs/getting-started/installation/"
  # A dry run tells what would happen, and this is it
  [[ "$DRY_RUN" == "1" ]] && exit 0
  exit 3
fi

MEM_KB="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)"
if (( MEM_KB < 1000000 )); then
  log "Warning: less than 1 GB of memory. Builds may fail without swap."
fi

# 1. Docker
if declare -F require_script >/dev/null; then require_script docker; else require_cmd docker; fi

# 2. The repository
if [[ -e "$BOOTSTRAP_SOURCE" ]]; then
  log "The Dokku repository is already set up by its installer: ${BOOTSTRAP_SOURCE}"
else
  SOURCE_CONTENT="Types: deb
URIs: ${REPO_URL}/${OS_ID}/
Suites: ${OS_CODENAME}
Components: main
Signed-By: ${APT_KEY}"
  if [[ -e "$APT_KEY" && "$(cat "$APT_SOURCE" 2>/dev/null)" == "$SOURCE_CONTENT" ]]; then
    log "The Dokku repository is already set up: ${APT_SOURCE}"
  else
    log "Adding the Dokku repository: ${APT_SOURCE}"
    TEMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TEMP_DIR"' EXIT
    run "download \"${REPO_URL}/gpgkey\" \"${TEMP_DIR}/dokku.asc\""
    run "sudo install -D -m 644 \"${TEMP_DIR}/dokku.asc\" ${APT_KEY}"
    run "printf '%s\n' \"${SOURCE_CONTENT}\" | sudo tee ${APT_SOURCE} >/dev/null"
    # An index of another source that fails to update does not stop the install
    run "sudo apt-get update || true"
  fi
fi

# 3. Dokku
CURRENT="$(installed_version)"
if [[ -n "$CURRENT" && ( -z "$VERSION" || "$VERSION" == "$CURRENT" ) ]]; then
  log "Dokku ${CURRENT} is already installed"
else
  PACKAGE="dokku${VERSION:+=${VERSION}}"
  log "Installing ${PACKAGE}"
  # The SSH keys are added below, not by the package from root's key file
  run "printf 'dokku dokku/skip_key_file boolean true\n' | sudo debconf-set-selections"
  if [[ -z "$CURRENT" ]]; then
    run "sudo apt-get update || true"
  fi
  run "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ${PACKAGE}"
  run "sudo dokku plugin:install-dependencies --core"
  if [[ -z "$CURRENT" && "$DRY_RUN" != "1" ]]; then
    mkdir -p "$STATE_DIR"
    : > "$INSTALL_STATE"
  fi
  if [[ -n "$CURRENT" ]]; then
    log "Dokku changed from ${CURRENT}: rebuild the apps with 'sudo dokku ps:rebuild --all'"
    log "Read the migration guides first: https://dokku.com/docs/getting-started/upgrading/"
  fi
fi

DOKKU_CMD="sudo dokku"
DOKKU_RUNNING=""
command -v dokku >/dev/null 2>&1 && DOKKU_RUNNING=1

# 4. The global domain, when asked for: Dokku sets the hostname of the machine on install
if [[ -n "$DOMAIN" ]]; then
  log "Global domain: ${DOMAIN}"
  run "${DOKKU_CMD} domains:set-global ${DOMAIN}"
fi

# 5. The keys allowed to push, and the plugins
dokku_add_ssh_keys "$SSH_KEY_FILE"
for plugin in ${PLUGINS[@]+"${PLUGINS[@]}"}; do
  dokku_install_plugin "$plugin"
done

log "Done. Deploy an app with: git push dokku@<server>:<app> main"
