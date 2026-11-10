#!/usr/bin/env bash
# dokku-docker.sh: Run Dokku, the self-hosted PaaS, as a Docker container on any Linux with Docker

set -euo pipefail

print_usage() {
  cat <<'USAGE'
load.sh dokku-docker -- [options]

Runs Dokku (https://dokku.com) in a Docker container named 'dokku', from the image
dokku/dokku, and Docker with 'load.sh docker' when it is missing. Its data (apps, config,
SSH keys) is kept in a folder of the host, so the container can be replaced without
losing it. The container has the Docker of the host: it runs the apps beside it.

Run again, it keeps the container as it is, with what it was given before, and replaces
it only when an option asks for something else. 'load.sh --upgrade' leaves it alone:
change the version with --version.

Options:
  -h, --help              Show this help and exit
  --version <ver>         Dokku version, e.g. 0.38.34 (default: the latest, on the first run)
  --hostname <domain>     Global domain of the apps (default: the name of the machine)
  --data-dir <dir>        Folder of the host with the data of Dokku (default: /var/lib/dokku)
  --ssh-port <port>       Port of the host for 'git push' (default: 3022)
  --http-port <port>      Port of the host for the apps over HTTP (default: 8080)
  --https-port <port>     Port of the host for the apps over HTTPS (default: 8443)
  --ssh-key <file>        Public keys allowed to push apps (default: ~/.ssh/authorized_keys).
                          A key already in Dokku is not added again
  --plugin <name=url>     Install a plugin, unless it is installed (can be repeated). It is
                          installed again when the container is replaced
  --dry-run               Print actions without executing them
  --manifest              Print installation manifest and exit

Examples:
  load.sh dokku-docker
  load.sh dokku-docker -- --hostname apps.example.com --http-port 80 --https-port 443
  load.sh dokku-docker -- --plugin postgres=https://github.com/dokku/dokku-postgres.git
  load.sh dokku-docker -- --version 0.38.34
  load.sh remove -- dokku-docker      # the data folder stays
USAGE
}

print_manifest() {
  cat <<'MANIFEST'
BIN_FILES=
FOLDERS=$HOME/.shellscript/dokku-docker
SHELLRC_FILE=
UNINSTALL_CMD=uninstall
UPGRADE=no
MANIFEST
}

# Code shared with dokku.sh.
# load.sh downloads it with this script, from the name in the line below; a loader
# older than that leaves it missing.
SHARED_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/dokku.sh"
if [[ ! -f "$SHARED_LIB" ]]; then
  echo "Error: lib/dokku.sh, which this script needs, is missing: run 'load.sh --update'" >&2
  exit 3
fi
# shellcheck source=lib/dokku.sh
source "$SHARED_LIB"

STATE_DIR="${SHELLSCRIPT_HOME}/dokku-docker"
# What the container was created with: the options a run again does not give keep it
CONFIG_FILE="${STATE_DIR}/config"
CONTAINER="dokku"
IMAGE="dokku/dokku"

# What the last run used: the options given below change it, the defaults fill the rest
VERSION="" DOMAIN="" DATA_DIR="" SSH_PORT="" HTTP_PORT="" HTTPS_PORT=""
# shellcheck source=/dev/null
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

# Parse flags
DRY_RUN=0
UNINSTALL=0
SSH_KEY_FILE="${HOME}/.ssh/authorized_keys"
PLUGINS=()
value() { [[ -n "${2-}" ]] || { err "$1 requires a value"; exit 2; }; }
while [[ ${1-} ]]; do
  case "$1" in
    -h|--help) print_usage; exit 0 ;;
    --manifest) print_manifest; exit 0 ;;
    --dry-run) DRY_RUN=1 ;;
    --version)    value "$1" "${2-}"; VERSION="${2#v}"; shift ;;
    --hostname)   value "$1" "${2-}"; DOMAIN="$2"; shift ;;
    --data-dir)   value "$1" "${2-}"; DATA_DIR="$2"; shift ;;
    --ssh-port)   value "$1" "${2-}"; SSH_PORT="$2"; shift ;;
    --http-port)  value "$1" "${2-}"; HTTP_PORT="$2"; shift ;;
    --https-port) value "$1" "${2-}"; HTTPS_PORT="$2"; shift ;;
    --ssh-key)
      value "$1" "${2-}"; SSH_KEY_FILE="$2"; shift
      [[ -f "$SSH_KEY_FILE" ]] || { err "--ssh-key: no such file: ${SSH_KEY_FILE}"; exit 2; }
      ;;
    --plugin)
      [[ "${2-}" == ?*=?* ]] || { err "--plugin requires <name=url>"; exit 2; }
      PLUGINS+=("$2"); shift
      ;;
    uninstall) UNINSTALL=1 ;;
    *) err "Unknown option: $1"; print_usage; exit 2 ;;
  esac
  shift || true
done
DOMAIN="${DOMAIN:-$(uname -n)}"
DATA_DIR="${DATA_DIR:-/var/lib/dokku}"
SSH_PORT="${SSH_PORT:-3022}"
HTTP_PORT="${HTTP_PORT:-8080}"
HTTPS_PORT="${HTTPS_PORT:-8443}"

# Dokku is installed on the system, or Docker run, with sudo
require_cmd sudo

# docker of the user, or with sudo while the user is not in the 'docker' group yet (a
# group given by 'load.sh docker' only counts after logging in again)
DOCKER="docker"
docker info >/dev/null 2>&1 || DOCKER="sudo docker"

# The configuration of the container, as a label on it: the same means nothing to do
container_config() {
  ${DOCKER} inspect -f '{{index .Config.Labels "shellscript.config"}}' "$CONTAINER" 2>/dev/null || true
}

# Internal hook, not part of the user interface: executed by 'load.sh remove --
# dokku-docker' through the UNINSTALL_CMD manifest key.
if [[ "$UNINSTALL" == "1" ]]; then
  if [[ ! -f "$CONFIG_FILE" ]]; then
    log "Dokku was not started by this script — leaving it in place."
    exit 0
  fi
  log "Removing the container '${CONTAINER}' and its image"
  run "${DOCKER} rm -f ${CONTAINER} || true"
  run "${DOCKER} rmi ${IMAGE}:${VERSION} || true"
  log "The data of Dokku stays in ${DATA_DIR}: remove it with 'sudo rm -rf ${DATA_DIR}'"
  [[ "$DRY_RUN" == "1" ]] || rm -f "$CONFIG_FILE"
  exit 0
fi

# Both take the ports and /var/lib/dokku: one or the other
if command -v dokku >/dev/null 2>&1; then
  err "Dokku is installed on this machine ('load.sh dokku'): it runs as a package or as a container, not both."
  exit 3
fi

# 1. Docker
if declare -F require_script >/dev/null; then require_script docker; else require_cmd docker; fi
docker info >/dev/null 2>&1 || DOCKER="sudo docker"

if [[ -z "$VERSION" ]]; then
  VERSION="$(github_latest_tag dokku/dokku)" || { err "Could not find the latest version of Dokku"; exit 1; }
  VERSION="${VERSION#v}"
fi

# 2. The plugins, in the list the container installs from on each start: a plugin is
# not kept in the data folder, so a new container installs it again
PLUGIN_LIST="${DATA_DIR}/plugin-list"
for plugin in ${PLUGINS[@]+"${PLUGINS[@]}"}; do
  line="${plugin%%=*}: ${plugin#*=}"
  if sudo grep -qxF "$line" "$PLUGIN_LIST" 2>/dev/null; then
    continue
  fi
  log "Adding plugin '${plugin%%=*}' to ${PLUGIN_LIST}"
  run "sudo mkdir -p ${DATA_DIR}; printf '%s\n' '${line}' | sudo tee -a ${PLUGIN_LIST} >/dev/null"
done

# 3. The container
CONFIG="VERSION=${VERSION}
DOMAIN=${DOMAIN}
DATA_DIR=${DATA_DIR}
SSH_PORT=${SSH_PORT}
HTTP_PORT=${HTTP_PORT}
HTTPS_PORT=${HTTPS_PORT}"
CURRENT="$(container_config)"
if [[ "$CURRENT" == "$CONFIG" ]]; then
  log "The container '${CONTAINER}' runs Dokku ${VERSION}, as asked"
  run "${DOCKER} start ${CONTAINER} >/dev/null"
else
  if ${DOCKER} inspect "$CONTAINER" >/dev/null 2>&1; then
    if [[ -z "$CURRENT" ]]; then
      err "A container named '${CONTAINER}' exists, not made by this script: remove it first."
      exit 3
    fi
    log "Replacing the container '${CONTAINER}': its data stays in ${DATA_DIR}"
  else
    log "Starting Dokku ${VERSION} in the container '${CONTAINER}'"
  fi
  run "${DOCKER} pull ${IMAGE}:${VERSION}"
  run "${DOCKER} rm -f ${CONTAINER} >/dev/null 2>&1 || true"
  run "${DOCKER} run -d --name ${CONTAINER} --restart unless-stopped \
--label shellscript.config=$(printf '%q' "$CONFIG") \
--env DOKKU_HOSTNAME=${DOMAIN} \
--env DOKKU_HOST_ROOT=${DATA_DIR}/home/dokku \
--env DOKKU_LIB_HOST_ROOT=${DATA_DIR}/var/lib/dokku \
--publish ${SSH_PORT}:22 --publish ${HTTP_PORT}:80 --publish ${HTTPS_PORT}:443 \
--volume ${DATA_DIR}:/mnt/dokku \
--volume /var/run/docker.sock:/var/run/docker.sock \
${IMAGE}:${VERSION} >/dev/null"
  if [[ "$CURRENT" == *"VERSION="* && "$CURRENT" != *"VERSION=${VERSION}"$'\n'* ]]; then
    log "Dokku changed version: rebuild the apps with 'docker exec ${CONTAINER} dokku ps:rebuild --all'"
    log "Read the migration guides first: https://dokku.com/docs/getting-started/upgrading/"
  fi
fi
if [[ "$DRY_RUN" != "1" ]]; then
  mkdir -p "$STATE_DIR"
  printf '%s\n' "$CONFIG" > "$CONFIG_FILE"
fi

# 4. Ready: its first start makes keys and installs the plugins, which takes minutes
DOKKU_CMD="${DOCKER} exec -i ${CONTAINER} dokku"
DOKKU_RUNNING=""
if [[ "$DRY_RUN" != "1" ]]; then
  log "Waiting for Dokku to be ready"
  for _ in $(seq 1 120); do
    [[ "$(${DOCKER} inspect -f '{{.State.Health.Status}}' "$CONTAINER" 2>/dev/null)" == "healthy" ]] && { DOKKU_RUNNING=1; break; }
    sleep 5
  done
  [[ "$DOKKU_RUNNING" == "1" ]] || { err "Dokku is not ready after 10 minutes: see 'docker logs ${CONTAINER}'"; exit 1; }
fi

# 5. The keys allowed to push, and the plugins of a container that was already running
dokku_add_ssh_keys "$SSH_KEY_FILE"
for plugin in ${PLUGINS[@]+"${PLUGINS[@]}"}; do
  dokku_install_plugin "$plugin"
done

log "Done. Deploy an app with: git push ssh://dokku@<server>:${SSH_PORT}/<app> main"
