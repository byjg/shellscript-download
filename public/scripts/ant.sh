#!/usr/bin/env bash
# ant.sh: Download and install Apache Ant

set -euo pipefail


print_usage() {
  cat <<'USAGE'
load.sh ant -- [options]

Downloads and installs Apache Ant binary distribution.

Options:
  -h, --help           Show this help and exit
  --version <version>  Ant version to install (default: latest)
  --dry-run            Print actions without executing them
  --manifest           Print installation manifest and exit

Examples:
  load.sh ant
  load.sh ant -- --version 1.10.15
  load.sh ant -- --dry-run
USAGE
}

print_manifest() {
  cat <<'MANIFEST'
BIN_FILES=ant
FOLDERS=$HOME/.shellscript/ant
SHELLRC_FILE=$HOME/.shellscript/shellrc/ant-init.sh
MANIFEST
}

# Parse flags
DRY_RUN=0
ANT_VERSION=""

while [[ ${1-} ]]; do
  case "$1" in
    -h|--help) print_usage; exit 0 ;;
    --manifest) print_manifest; exit 0 ;;
    --dry-run) DRY_RUN=1 ;;
    --version)
      shift || { err "--version requires a value"; exit 2; }
      ANT_VERSION="$1"
      ;;
    *) err "Unknown option: $1"; print_usage; exit 2 ;;
  esac
  shift || true
done

# Preconditions
require_downloader
require_cmd tar

# Resolve latest version if not specified
if [[ -z "$ANT_VERSION" ]]; then
  # apache/ant publishes no GitHub releases, only rel/<version> tags (newest first)
  ANT_VERSION=$(fetch https://api.github.com/repos/apache/ant/tags | grep -o '"name": *"rel/[^"]*"' | head -1 | sed 's/.*"rel\/\(.*\)"/\1/')
  log "Latest Ant version: ${ANT_VERSION}"
fi

# Configuration
ANT_HOME="${SHELLSCRIPT_HOME}/ant"
BIN_DIR="${SHELLSCRIPT_BIN}"
SHELLRC_DIR="${SHELLSCRIPT_SHELLRC}"
ANT_ARCHIVE="apache-ant-${ANT_VERSION}-bin.tar.gz"
DOWNLOAD_URL="https://archive.apache.org/dist/ant/binaries/${ANT_ARCHIVE}"
TEMP_DIR=$(mktemp -d)

cleanup() {
  if [[ -d "$TEMP_DIR" ]]; then
    rm -rf "$TEMP_DIR"
  fi
}
trap cleanup EXIT

log "Installing Apache Ant ${ANT_VERSION}"

# Download Ant
log "Downloading Ant from ${DOWNLOAD_URL}"
run "download \"${DOWNLOAD_URL}\" \"${TEMP_DIR}/${ANT_ARCHIVE}\""

# Extract Ant
log "Extracting Ant to ${ANT_HOME}"
run "mkdir -p \"${ANT_HOME}\""
run "tar -xzf \"${TEMP_DIR}/${ANT_ARCHIVE}\" -C \"${TEMP_DIR}\""
run "rm -rf \"${ANT_HOME}/current\""
run "mv \"${TEMP_DIR}/apache-ant-${ANT_VERSION}\" \"${ANT_HOME}/current\""

# Create bin directory
run "mkdir -p \"${BIN_DIR}\""

# Create ant wrapper
log "Creating ant wrapper in ${BIN_DIR}"
if [[ "$DRY_RUN" == "1" ]]; then
  log "[dry-run] Writing ${BIN_DIR}/ant"
else
  cat >"${BIN_DIR}/ant" <<WRAP
#!/usr/bin/env bash
exec "${HOME}/.shellscript/ant/current/bin/ant" "\$@"
WRAP
  chmod +x "${BIN_DIR}/ant"
fi

# Write shell init snippet
run "mkdir -p \"${SHELLRC_DIR}\""
if [[ "$DRY_RUN" == "1" ]]; then
  log "[dry-run] Writing ${SHELLRC_DIR}/ant-init.sh"
else
  cat >"${SHELLRC_DIR}/ant-init.sh" <<'WRAP'
export ANT_HOME="$HOME/.shellscript/ant/current"
WRAP
fi

log "Done. Ant ${ANT_VERSION} installed to ${ANT_HOME}/current"
log "Source ${SHELLRC_DIR}/ant-init.sh from your shell rc for ANT_HOME environment variable"