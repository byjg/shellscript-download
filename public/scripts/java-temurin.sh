#!/usr/bin/env bash
# java-temurin.sh: Download and install Eclipse Temurin Java (OpenJDK)

set -euo pipefail


print_usage() {
  cat <<'USAGE'
load.sh java-temurin -- [options]

Downloads and installs Eclipse Temurin (Adoptium) OpenJDK binary distribution for x86_64 Linux.
Uses the Adoptium API to resolve the latest patch release for the requested major version.

Options:
  -h, --help           Show this help and exit
  --version <version>  Java major version to install (default: 21)
                       LTS versions: 8, 11, 17, 21, 25
                       Non-LTS versions require confirmation (or --yes)
  --yes, -y            Skip confirmation for non-LTS versions
  --dry-run            Print actions without executing them
  --manifest [--version <version>]
                       Print installation manifest and exit
                       Without --version: removes all versions (default)
                       With --version: removes only specific version

Examples:
  load.sh java-temurin
  load.sh java-temurin -- --version 17
  load.sh java-temurin -- --version 14 --yes
  load.sh java-temurin -- --dry-run
  load.sh java-temurin -- --manifest --version 17
USAGE
}

print_manifest() {
  local version="/$1"

  if [[ "$version" == "/all" ]]; then
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
MANIFEST_MODE=0
MANIFEST_VERSION="all"
YES=0

while [[ ${1-} ]]; do
  case "$1" in
    -h|--help) print_usage; exit 0 ;;
    --manifest) MANIFEST_MODE=1 ;;
    --dry-run) DRY_RUN=1 ;;
    -y|--yes) YES=1 ;;
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

# Warn for non-LTS versions
LTS_VERSIONS="8 11 17 21 25"
if ! echo " $LTS_VERSIONS " | grep -q " $JAVA_VERSION "; then
  if [[ "$YES" == "1" ]]; then
    log "WARNING: Java ${JAVA_VERSION} is not an LTS version (--yes passed, skipping confirmation)."
  else
    log "WARNING: Java ${JAVA_VERSION} is not an LTS version and may be EOL or unsupported."
    printf "[java-temurin.sh] Are you sure you want to install it? [y/N] "
    read -r CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
      log "Aborted."
      exit 0
    fi
  fi
fi

# Preconditions
require_cmd curl
require_cmd jq
require_cmd tar

# Configuration
JAVA_HOME_BASE="${SHELLSCRIPT_HOME}/java-temurin"
SHELLRC_DIR="${SHELLSCRIPT_SHELLRC}"

# Resolve download URL via Adoptium API
log "Resolving latest Java ${JAVA_VERSION} release from Adoptium API..."
API_URL="https://api.adoptium.net/v3/assets/latest/${JAVA_VERSION}/hotspot?architecture=x64&image_type=jdk&os=linux&vendor=eclipse"
DOWNLOAD_URL=$(curl -fsSL "$API_URL" | jq -r '.[0].binary.package.link // empty')

if [[ -z "$DOWNLOAD_URL" ]]; then
  err "Could not resolve download URL for Java ${JAVA_VERSION} from Adoptium API."
  err "This version may not be available. Check https://adoptium.net"
  exit 1
fi

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
  TEMP_EXTRACT_DIR=$(mktemp -d)
  tar -xzf "${TEMP_ARCHIVE}" -C "${TEMP_EXTRACT_DIR}"
  EXTRACTED_DIR=$(ls -1 "${TEMP_EXTRACT_DIR}" | head -1)

  if [[ -z "$EXTRACTED_DIR" ]]; then
    err "Failed to find extracted JDK directory"
    rm -rf "${TEMP_EXTRACT_DIR}"
    exit 1
  fi

  rm -rf "${INSTALL_DIR}"
  mv "${TEMP_EXTRACT_DIR}/${EXTRACTED_DIR}" "${INSTALL_DIR}"
  rm -rf "${TEMP_EXTRACT_DIR}"
  log "Extracted to ${INSTALL_DIR}"
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