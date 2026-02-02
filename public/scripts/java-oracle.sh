#!/usr/bin/env bash
# java-oracle.sh: Download and install Oracle JDK

set -euo pipefail
IFS=$'\n\t'

log()  { printf "[java-oracle.sh] %s\n" "$*"; }
err()  { printf "[java-oracle.sh][ERROR] %s\n" "$*" >&2; }
run()  { if [[ "$DRY_RUN" == "1" ]]; then printf "[dry-run] %s\n" "$*"; else eval "$@"; fi }
require_cmd() { command -v "$1" >/dev/null 2>&1 || { err "Required command '$1' not found"; exit 1; }; }

print_usage() {
  cat <<'USAGE'
load.sh java-oracle -- [options]

Downloads and installs Oracle JDK binary distribution for x86_64 Linux.

Options:
  -h, --help           Show this help and exit
  --version <version>  Java major version to install: 25 or 21 (default: 21)
  --dry-run            Print actions without executing them
  --manifest [--version <version>]
                       Print installation manifest and exit
                       Without --version: removes all versions (default)
                       With --version: removes only specific version

Examples:
  load.sh java-oracle
  load.sh java-oracle -- --version 25
  load.sh java-oracle -- --dry-run
  load.sh java-oracle -- --manifest --version 21

Note:
  By downloading and using Oracle JDK, you agree to the Oracle Technology Network License Agreement.
  For production use, please review Oracle's licensing terms.
USAGE
}

print_manifest() {
  local version="/$1"

  if [[ "$version" == "/all" ]]; then
    # Remove all versions
    version=""
  fi

    cat <<MANIFEST
FOLDERS=\$HOME/.shellscript/java-oracle${version}
SHELLRC_FILE=\$HOME/.shellscript/shellrc/java-oracle-init.sh
MANIFEST
}

# Parse flags
DRY_RUN=0
JAVA_VERSION="21"
MANIFEST_MODE=0
MANIFEST_VERSION="all"

while [[ ${1-} ]]; do
  case "$1" in
    -h|--help) print_usage; exit 0 ;;
    --manifest)
      MANIFEST_MODE=1
      ;;
    --dry-run) DRY_RUN=1 ;;
    --version)
      shift || { err "--version requires a value"; exit 2; }
      JAVA_VERSION="$1"
      if [[ "$MANIFEST_MODE" == "1" ]]; then
        MANIFEST_VERSION="$1"
      fi
      ;;
    *) err "Unknown option: $1"; print_usage; exit 2 ;;
  esac
  shift || true
done

# Handle manifest mode
if [[ "$MANIFEST_MODE" == "1" ]]; then
  print_manifest "$MANIFEST_VERSION"
  exit 0
fi

log ">_ java-oracle.sh"

# Preconditions
require_cmd curl
require_cmd tar

# Configuration
JAVA_HOME_BASE="$HOME/.shellscript/java-oracle"
SHELLRC_DIR="$HOME/.shellscript/shellrc"

# Build download URL based on version
case "$JAVA_VERSION" in
  25)
    DOWNLOAD_URL="https://download.oracle.com/java/25/latest/jdk-25_linux-x64_bin.tar.gz"
    ;;
  21)
    DOWNLOAD_URL="https://download.oracle.com/java/21/latest/jdk-21_linux-x64_bin.tar.gz"
    ;;
  *)
    err "Unsupported Java version: ${JAVA_VERSION}. Supported versions: 25, 21"
    exit 1
    ;;
esac

TEMP_ARCHIVE="/tmp/java-oracle.tar.gz"

cleanup() {
  if [[ -f "$TEMP_ARCHIVE" ]]; then
    rm -f "$TEMP_ARCHIVE"
  fi
}
trap cleanup EXIT

log "Installing Oracle JDK ${JAVA_VERSION}"

# Download Java
log "Downloading Java from ${DOWNLOAD_URL}"
run "curl -fsSL -o \"${TEMP_ARCHIVE}\" \"${DOWNLOAD_URL}\""

# Extract Java
INSTALL_DIR="${JAVA_HOME_BASE}/${JAVA_VERSION}"
log "Extracting Java to ${INSTALL_DIR}"
run "mkdir -p \"${JAVA_HOME_BASE}\""

if [[ "$DRY_RUN" != "1" ]]; then
  # Extract to a temp location to find the actual directory name
  TEMP_EXTRACT_DIR=$(mktemp -d)
  tar -xzf "${TEMP_ARCHIVE}" -C "${TEMP_EXTRACT_DIR}"

  # Find the extracted JDK directory (should be jdk-*.*)
  EXTRACTED_DIR=$(ls -1 "${TEMP_EXTRACT_DIR}" | head -1)

  if [[ -z "$EXTRACTED_DIR" ]]; then
    err "Failed to find extracted JDK directory"
    rm -rf "${TEMP_EXTRACT_DIR}"
    exit 1
  fi

  # Move to final location
  rm -rf "${INSTALL_DIR}"
  mv "${TEMP_EXTRACT_DIR}/${EXTRACTED_DIR}" "${INSTALL_DIR}"
  rm -rf "${TEMP_EXTRACT_DIR}"

  log "Extracted to ${INSTALL_DIR}"
else
  log "[dry-run] Would extract to ${INSTALL_DIR}"
fi

# Write shell init snippet
log "Writing environment variables to ${SHELLRC_DIR}/java-oracle-init.sh"
run "mkdir -p \"${SHELLRC_DIR}\""
if [[ "$DRY_RUN" != "1" ]]; then
  cat >"${SHELLRC_DIR}/java-oracle-init.sh" <<WRAP
export JAVA_HOME="\$HOME/.shellscript/java-oracle/${JAVA_VERSION}"
export JDK_HOME="\$HOME/.shellscript/java-oracle/${JAVA_VERSION}"
export PATH="\$HOME/.shellscript/java-oracle/${JAVA_VERSION}/bin:\$PATH"
WRAP
else
  log "[dry-run] Would write to ${SHELLRC_DIR}/java-oracle-init.sh"
fi

log "Done. Oracle JDK ${JAVA_VERSION} installed to ${INSTALL_DIR}"
log "Source ${SHELLRC_DIR}/java-oracle-init.sh from your shell rc for JAVA_HOME environment variable"
log ""
log "IMPORTANT: By using Oracle JDK, you agree to Oracle's licensing terms."
log "Visit https://www.oracle.com/downloads/licenses/binary-code-license.html for details."