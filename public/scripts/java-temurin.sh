#!/usr/bin/env bash
# java-temurin.sh: Download and install Eclipse Temurin Java (OpenJDK)
#
# Usage (via loader):
#   load.sh java-temurin -- [--version <version>] [--help] [--dry-run]
#
# Examples:
#   # Install Java Temurin with default version (21)
#   load.sh java-temurin
#   # Install specific Java version
#   load.sh java-temurin -- --version 17
#   # Show help
#   load.sh java-temurin -- --help
#   # Simulate actions without making changes
#   load.sh java-temurin -- --dry-run
#
# Description:
# - Downloads Eclipse Temurin (Adoptium) OpenJDK binary for x86_64 Linux
# - Extracts it to $HOME/.shellscript/java-temurin/<version>
# - Creates $HOME/.shellscript/shellrc/java-temurin-init.sh for environment variables
# - Idempotent and non-interactive; supports a dry-run mode
# - Supports Java versions: 25, 21, 17, 11, 8

set -euo pipefail
IFS=$'\n\t'

log()  { printf "[java-temurin.sh] %s\n" "$*"; }
err()  { printf "[java-temurin.sh][ERROR] %s\n" "$*" >&2; }
run()  { if [[ "$DRY_RUN" == "1" ]]; then printf "[dry-run] %s\n" "$*"; else eval "$@"; fi }
require_cmd() { command -v "$1" >/dev/null 2>&1 || { err "Required command '$1' not found"; exit 1; }; }

print_usage() {
  cat <<'USAGE'
load.sh java-temurin -- [options]

Downloads and installs Eclipse Temurin (Adoptium) OpenJDK binary distribution for x86_64 Linux.

Options:
  -h, --help           Show this help and exit
  --version <version>  Java major version to install: 25, 21, 17, 11, or 8 (default: 21)
  --dry-run            Print actions without executing them
  --manifest [--version <version>]
                       Print installation manifest and exit
                       Without --version: removes all versions (default)
                       With --version: removes only specific version

Examples:
  load.sh java-temurin
  load.sh java-temurin -- --version 17
  load.sh java-temurin -- --dry-run
  load.sh java-temurin -- --manifest --version 17
USAGE
}

print_manifest() {
  local version="/$1"

  if [[ "$version" == "/all" ]]; then
    # Remove all versions
    version=""
  fi

    cat <<MANIFEST
FOLDERS=\$HOME/.shellscript/java-temurin${version}
SHELLRC_FILE=\$HOME/.shellscript/shellrc/java-temurin-init.sh
MANIFEST
}

# Parse flags
DRY_RUN=0
JAVA_VERSION="21"
MANIFEST_VERSION=""

while [[ ${1-} ]]; do
  case "$1" in
    -h|--help) print_usage; exit 0 ;;
    --manifest)
      if [[ -z "$MANIFEST_VERSION" ]]; then
        MANIFEST_VERSION="all"
      fi
      ;;
    --dry-run) DRY_RUN=1 ;;
    --version)
      shift || { err "--version requires a value"; exit 2; }
      JAVA_VERSION="$1"
      MANIFEST_VERSION="$1"
      ;;
    *) err "Unknown option: $1"; print_usage; exit 2 ;;
  esac
  shift || true
done

# Handle manifest mode
if [[ -n "$MANIFEST_VERSION" ]]; then
  print_manifest "$MANIFEST_VERSION"
  exit 0
fi

log ">_ java-temurin.sh"

# Preconditions
require_cmd curl
require_cmd tar

# Configuration
JAVA_HOME_BASE="$HOME/.shellscript/java-temurin"
SHELLRC_DIR="$HOME/.shellscript/shellrc"

# Build download URL based on version
# Pattern: https://github.com/adoptium/temurin${VERSION}-binaries/releases/download/${RELEASE_PATH}
case "$JAVA_VERSION" in
  25)
    RELEASE_PATH="jdk-25.0.2%2B10/OpenJDK25U-jdk_x64_linux_hotspot_25.0.2_10.tar.gz"
    EXTRACTED_DIR="jdk-25.0.2+10"
    ;;
  21)
    RELEASE_PATH="jdk-21.0.10%2B7/OpenJDK21U-jdk_x64_linux_hotspot_21.0.10_7.tar.gz"
    EXTRACTED_DIR="jdk-21.0.10+7"
    ;;
  17)
    RELEASE_PATH="jdk-17.0.18%2B8/OpenJDK17U-jdk_x64_linux_hotspot_17.0.18_8.tar.gz"
    EXTRACTED_DIR="jdk-17.0.18+8"
    ;;
  11)
    RELEASE_PATH="jdk-11.0.30%2B7/OpenJDK11U-jdk_x64_linux_hotspot_11.0.30_7.tar.gz"
    EXTRACTED_DIR="jdk-11.0.30+7"
    ;;
  8)
    RELEASE_PATH="jdk8u482-b08/OpenJDK8U-jdk_x64_linux_hotspot_8u482b08.tar.gz"
    EXTRACTED_DIR="jdk8u482-b08"
    ;;
  *)
    err "Unsupported Java version: ${JAVA_VERSION}. Supported versions: 25, 21, 17, 11, 8"
    exit 1
    ;;
esac

DOWNLOAD_URL="https://github.com/adoptium/temurin${JAVA_VERSION}-binaries/releases/download/${RELEASE_PATH}"
TEMP_ARCHIVE="/tmp/temurin.tar.gz"

cleanup() {
  if [[ -f "$TEMP_ARCHIVE" ]]; then
    rm -f "$TEMP_ARCHIVE"
  fi
}
trap cleanup EXIT

log "Installing Eclipse Temurin Java ${JAVA_VERSION}"

# Download Java
log "Downloading Java from ${DOWNLOAD_URL}"
run "curl -fsSL -o \"${TEMP_ARCHIVE}\" \"${DOWNLOAD_URL}\""

# Extract Java
INSTALL_DIR="${JAVA_HOME_BASE}/${JAVA_VERSION}"
log "Extracting Java to ${INSTALL_DIR}"
run "mkdir -p \"${JAVA_HOME_BASE}\""
if [[ "$DRY_RUN" != "1" ]]; then
  tar -xzf "${TEMP_ARCHIVE}" -C "${JAVA_HOME_BASE}"
  rm -rf "${INSTALL_DIR}"
  mv "${JAVA_HOME_BASE}/${EXTRACTED_DIR}" "${INSTALL_DIR}"
else
  log "[dry-run] Would extract to ${INSTALL_DIR}"
fi

# Write shell init snippet
log "Writing environment variables to ${SHELLRC_DIR}/java-temurin-init.sh"
run "mkdir -p \"${SHELLRC_DIR}\""
if [[ "$DRY_RUN" != "1" ]]; then
  cat >"${SHELLRC_DIR}/java-temurin-init.sh" <<WRAP
export JAVA_HOME="\$HOME/.shellscript/java-temurin/${JAVA_VERSION}"
export JDK_HOME="\$HOME/.shellscript/java-temurin/${JAVA_VERSION}"
export PATH="\$HOME/.shellscript/java-temurin/${JAVA_VERSION}/bin:\$PATH"
WRAP
else
  log "[dry-run] Would write to ${SHELLRC_DIR}/java-temurin-init.sh"
fi

log "Done. Java Temurin ${JAVA_VERSION} installed to ${INSTALL_DIR}"
log "Source ${SHELLRC_DIR}/java-temurin-init.sh from your shell rc for JAVA_HOME environment variable"