#!/usr/bin/env bash
# docker.sh: Install the Docker Engine on Linux in a safe, idempotent, shell-friendly way

set -euo pipefail

# It changes the system: load.sh keeps one copy of it for every user, owned by root
SYSTEM_SCRIPT=yes


print_usage() {
  cat <<'USAGE'
load.sh docker -- [options]

Installs the Docker Engine on Linux using the official convenience script.

Options:
  -h, --help        Show this help and exit
  --dry-run         Print actions without executing them
  --no-group        Skip creating 'docker' group and user membership changes
  --user NAME       The user to add to the 'docker' group (default: you; as root,
                    the user who ran sudo)
  --channel CH      Pass a channel to the installer (e.g., 'stable', 'test', 'nightly')
  --force           Run the installer of Docker even when Docker is installed
  --manifest        Print installation manifest and exit

Docker is installed for every user of the machine: 'load.sh remove -- docker' leaves
it in place. Run again, the installer does not run when Docker is installed: the
package manager upgrades it (apt upgrade, dnf upgrade). The 'docker' group is set up
each time.

Examples:
  load.sh docker
  load.sh docker -- --dry-run
  sudo ~/.shellscript/bin/load.sh docker -- --user alice
USAGE
}

print_manifest() {
  cat <<'MANIFEST'
BIN_FILES=
FOLDERS=$HOME/.docker
SHELLRC_FILE=
MANIFEST
}

# Parse flags
DRY_RUN=0
NO_GROUP=0
CHANNEL=""
GROUP_USER=""
FORCE=0
while [[ ${1-} ]]; do
  case "$1" in
    -h|--help) print_usage; exit 0 ;;
    --manifest) print_manifest; exit 0 ;;
    --dry-run) DRY_RUN=1 ;;
    --no-group) NO_GROUP=1 ;;
    --channel) CHANNEL=${2-}; shift || true ;;
    --user) GROUP_USER=${2-}; [[ -n "$GROUP_USER" ]] || { err "--user requires a name"; exit 2; }; shift ;;
    --force) FORCE=1 ;;
    *) err "Unknown option: $1"; print_usage; exit 2 ;;
  esac
  shift || true
done

# The system state helpers come from load.sh: an older one does not have them
if ! declare -F system_user_add >/dev/null; then
  echo "Error: this script needs a newer load.sh: run 'load.sh --update'" >&2
  exit 3
fi

SUDO="$(sudo_cmd)"

# Preconditions
require_downloader
[[ -z "$SUDO" ]] || require_cmd sudo

# Linux check (the get.docker.com script is Linux-specific)
if [[ "${OSTYPE:-}" != linux* ]]; then
  err "This installer supports Linux only. Detected OSTYPE='${OSTYPE:-unknown}'."
  exit 1
fi

# Docker installed: its packages come from its repository, and the package manager
# upgrades them. The installer would install them again, and reset the configuration of
# the repository, after a warning and 20 seconds of wait: not without --force.
if [[ "$FORCE" != "1" ]] && command -v docker >/dev/null 2>&1; then
  log "$(docker --version) is already installed: the package manager upgrades it (apt upgrade, dnf upgrade). --force runs its installer again."
else
  # Prepare destination folder for downloaded installer
  DEST_FOLDER="${SHELLSCRIPT_DOWNLOADS}"
  run "mkdir -p \"$DEST_FOLDER\""

  # The installer of Docker, downloaded each time it runs: Docker changes it, and an old
  # one could install what Docker no longer publishes
  INSTALLER="$DEST_FOLDER/get-docker.sh"
  log "Downloading Docker installer..."
  run "download https://get.docker.com \"$INSTALLER\""

  # Run the installer as root
  INSTALL_CMD="sh \"$INSTALLER\""
  if [[ -n "$CHANNEL" ]]; then
    INSTALL_CMD="CHANNEL=$CHANNEL $INSTALL_CMD"
  fi
  run "${SUDO} $INSTALL_CMD"
fi

# Who goes in the 'docker' group: the caller, or as root the user who ran sudo. Root
# itself needs no group to use Docker.
if [[ -z "$GROUP_USER" ]]; then
  if [[ -n "$SUDO" ]]; then GROUP_USER=$(id -un); else GROUP_USER="${SUDO_USER:-}"; fi
  [[ "$GROUP_USER" != "root" ]] || GROUP_USER=""
fi
if [[ -n "$GROUP_USER" ]] && ! id "$GROUP_USER" >/dev/null 2>&1; then
  err "No such user: ${GROUP_USER}"
  exit 2
fi

# Group setup (optional)
if [[ "$NO_GROUP" != "1" && -z "$GROUP_USER" ]]; then
  log "As root, there is nobody to add to the 'docker' group: name the user with --user <name>"
elif [[ "$NO_GROUP" != "1" ]]; then
  if getent group docker >/dev/null 2>&1; then
    log "Group 'docker' already exists"
  else
    log "Creating group 'docker'"
    run "${SUDO} groupadd docker"
  fi

  if id -nG "$GROUP_USER" | grep -qw docker; then
    log "User '$GROUP_USER' is already in the 'docker' group"
  else
    log "Adding '$GROUP_USER' to 'docker' group"
    run "${SUDO} usermod -aG docker \"$GROUP_USER\""
    log "You may need to log out and log back in for group changes to take effect."
  fi
fi

# Fix $HOME/.docker permissions for the current user
run "mkdir -p \"$HOME/.docker\""
run "chmod 700 \"$HOME/.docker\" -R"
run "chown \"$(id -un)\":\"$(id -gn)\" \"$HOME/.docker\" -R" || true

system_user_add docker

log "Done."