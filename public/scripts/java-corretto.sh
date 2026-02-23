#!/usr/bin/env bash
# java-corretto.sh: Download and install Amazon Corretto OpenJDK

set -euo pipefail


print_usage() {
  cat <<'USAGE'
load.sh java-corretto -- [options]

Downloads and installs Amazon Corretto OpenJDK binary distribution for x86_64 Linux.

Options:
  -h, --help           Show this help and exit
  --version <version>  Java major version to install: 25, 21, 17, 11, or 8 (default: 21)
  --dry-run            Print actions without executing them
  --manifest [--version <version>]
                       Print installation manifest and exit
                       Without --version: removes all versions (default)
                       With --version: removes only specific version

Examples:
  load.sh java-corretto
  load.sh java-corretto -- --version 17
  load.sh java-corretto -- --dry-run
  load.sh java-corretto -- --manifest --version 21
USAGE
}

print_manifest() {
  local version="/$1"

  if [[ "$version" == "/all" ]]; then
    # Remove all versions
    version=""
  fi

    cat <<MANIFEST
FOLDERS=\$HOME/.shellscript/java-corretto${version}
SHELLRC_FILE=\$HOME/.shellscript/shellrc/java-corretto-init.sh
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

# Preconditions
require_cmd curl
require_cmd tar

# Configuration
JAVA_HOME_BASE="${SHELLSCRIPT_HOME}/java-corretto"
SHELLRC_DIR="${SHELLSCRIPT_SHELLRC}"

# Build download URL based on version
case "$JAVA_VERSION" in
  25|21|17|11|8)
    DOWNLOAD_URL="https://corretto.aws/downloads/latest/amazon-corretto-${JAVA_VERSION}-x64-linux-jdk.tar.gz"
    ;;
  *)
    err "Unsupported Java version: ${JAVA_VERSION}. Supported versions: 25, 21, 17, 11, 8"
    exit 1
    ;;
esac

TEMP_ARCHIVE="/tmp/corretto.tar.gz"

cleanup() {
  if [[ -f "$TEMP_ARCHIVE" ]]; then
    rm -f "$TEMP_ARCHIVE"
  fi
}
trap cleanup EXIT

log "Installing Amazon Corretto Java ${JAVA_VERSION}"

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
log "Writing environment variables to ${SHELLRC_DIR}/java-corretto-init.sh"
run "mkdir -p \"${SHELLRC_DIR}\""
if [[ "$DRY_RUN" != "1" ]]; then
  cat >"${SHELLRC_DIR}/java-corretto-init.sh" <<WRAP
export JAVA_HOME="\$HOME/.shellscript/java-corretto/${JAVA_VERSION}"
export JDK_HOME="\$HOME/.shellscript/java-corretto/${JAVA_VERSION}"
export PATH="\$HOME/.shellscript/java-corretto/${JAVA_VERSION}/bin:\$PATH"
WRAP
else
  log "[dry-run] Would write to ${SHELLRC_DIR}/java-corretto-init.sh"
fi

log "Done. Amazon Corretto Java ${JAVA_VERSION} installed to ${INSTALL_DIR}"
log "Source ${SHELLRC_DIR}/java-corretto-init.sh from your shell rc for JAVA_HOME environment variable"