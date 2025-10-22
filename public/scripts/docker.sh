#!/usr/bin/env bash
# docker.sh: Install the Docker Engine on Linux in a safe, idempotent, shell-friendly way
#
# Usage (via loader):
#   load.sh docker -- [--help] [--dry-run] [--no-group] [--channel CHANNEL]
#
# Examples:
#   # Install Docker with sensible defaults
#   load.sh docker
#   # Show help
#   load.sh docker -- --help
#   # Simulate actions without making changes
#   load.sh docker -- --dry-run
#
# Description:
# - Installs Docker Engine using the official convenience script from get.docker.com
# - Creates the "docker" group (if missing) and adds the current user to it (unless --no-group)
# - Fixes $HOME/.docker permissions for the current user
# - Idempotent: safe to re-run, it will skip already completed steps
# - Non-interactive: suitable for CI; prints clear logs and exits on first error
# - Supports a dry-run mode for previewing actions
#

set -euo pipefail
IFS=$'\n\t'

log()  { printf "[docker.sh] %s\n" "$*"; }
err()  { printf "[docker.sh][ERROR] %s\n" "$*" >&2; }
run()  { if [[ "$DRY_RUN" == "1" ]]; then printf "[dry-run] %s\n" "$*"; else eval "$@"; fi }
require_cmd() { command -v "$1" >/dev/null 2>&1 || { err "Required command '$1' not found"; exit 1; }; }

print_usage() {
  cat <<'USAGE'
load.sh docker -- [options]

Installs the Docker Engine on Linux using the official convenience script.

Options:
  -h, --help        Show this help and exit
  --dry-run         Print actions without executing them
  --no-group        Skip creating 'docker' group and user membership changes
  --channel CH      Pass a channel to the installer (e.g., 'stable', 'test', 'nightly')

Examples:
  load.sh docker
  load.sh docker -- --dry-run
USAGE
}

# Parse flags
DRY_RUN=0
NO_GROUP=0
CHANNEL=""
while [[ ${1-} ]]; do
  case "$1" in
    -h|--help) print_usage; exit 0 ;;
    --dry-run) DRY_RUN=1 ;;
    --no-group) NO_GROUP=1 ;;
    --channel) CHANNEL=${2-}; shift || true ;;
    *) err "Unknown option: $1"; print_usage; exit 2 ;;
  esac
  shift || true
done

log ">_ docker.sh"

# Preconditions
require_cmd curl
if [[ $EUID -ne 0 ]]; then
  require_cmd sudo
fi

# Linux check (the get.docker.com script is Linux-specific)
if [[ "${OSTYPE:-}" != linux* ]]; then
  err "This installer supports Linux only. Detected OSTYPE='${OSTYPE:-unknown}'."
  exit 1
fi

# Prepare destination folder for downloaded installer
DEST_FOLDER="$HOME/.shellscript/downloads"
run "mkdir -p \"$DEST_FOLDER\""

# Download installer script
INSTALLER="$DEST_FOLDER/get-docker.sh"
if [[ ! -s "$INSTALLER" ]]; then
  log "Downloading Docker installer..."
  run "curl -fsSL https://get.docker.com -o \"$INSTALLER\""
else
  log "Reusing existing installer: $INSTALLER"
fi

# Compose installer command
INSTALL_CMD="sh \"$INSTALLER\""
if [[ -n "$CHANNEL" ]]; then
  INSTALL_CMD="CHANNEL=$CHANNEL $INSTALL_CMD"
fi

# Run installer (with sudo if not root)
if [[ $EUID -ne 0 ]]; then
  run "sudo $INSTALL_CMD"
else
  run "$INSTALL_CMD"
fi

# Group setup (optional)
if [[ "$NO_GROUP" != "1" ]]; then
  if getent group docker >/dev/null 2>&1; then
    log "Group 'docker' already exists"
  else
    log "Creating group 'docker'"
    if [[ $EUID -ne 0 ]]; then run "sudo groupadd docker"; else run "groupadd docker"; fi
  fi

  USER_NAME=$(id -un)
  if id -nG "$USER_NAME" | grep -qw docker; then
    log "User '$USER_NAME' is already in the 'docker' group"
  else
    log "Adding '$USER_NAME' to 'docker' group"
    if [[ $EUID -ne 0 ]]; then run "sudo usermod -aG docker \"$USER_NAME\""; else run "usermod -aG docker \"$USER_NAME\""; fi
    log "You may need to log out and log back in for group changes to take effect."
  fi
fi

# Fix $HOME/.docker permissions for the current user
run "mkdir -p \"$HOME/.docker\""
run "chmod 700 \"$HOME/.docker\" -R"
run "chown \"$(id -un)\":\"$(id -gn)\" \"$HOME/.docker\" -R" || true

log "Done."