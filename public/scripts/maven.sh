#!/usr/bin/env bash
# maven.sh: Download and install Apache Maven

set -euo pipefail


print_usage() {
  cat <<'USAGE'
load.sh maven -- [options]

Downloads and installs Apache Maven binary distribution.

Options:
  -h, --help           Show this help and exit
  --version <version>  Maven version to install (default: latest)
  --dry-run            Print actions without executing them
  --manifest           Print installation manifest and exit

Examples:
  load.sh maven
  load.sh maven -- --version 3.8.8
  load.sh maven -- --dry-run
USAGE
}

print_manifest() {
  cat <<'MANIFEST'
BIN_FILES=mvn mvnDebug
FOLDERS=$HOME/.shellscript/maven
SHELLRC_FILE=$HOME/.shellscript/shellrc/maven-init.sh
MANIFEST
}

# Parse flags
DRY_RUN=0
MAVEN_VERSION=""

while [[ ${1-} ]]; do
  case "$1" in
    -h|--help) print_usage; exit 0 ;;
    --manifest) print_manifest; exit 0 ;;
    --dry-run) DRY_RUN=1 ;;
    --version)
      shift || { err "--version requires a value"; exit 2; }
      MAVEN_VERSION="$1"
      ;;
    *) err "Unknown option: $1"; print_usage; exit 2 ;;
  esac
  shift || true
done

# Preconditions
require_cmd curl
require_cmd tar

# Resolve latest version if not specified
if [[ -z "$MAVEN_VERSION" ]]; then
  MAVEN_VERSION=$(curl -fsSL https://api.github.com/repos/apache/maven/releases/latest | grep '"tag_name"' | sed 's/.*"tag_name": *"maven-\(.*\)".*/\1/')
  log "Latest Maven version: ${MAVEN_VERSION}"
fi

# Configuration
MAVEN_HOME="${SHELLSCRIPT_HOME}/maven"
BIN_DIR="${SHELLSCRIPT_BIN}"
SHELLRC_DIR="${SHELLSCRIPT_SHELLRC}"
MAVEN_ARCHIVE="apache-maven-${MAVEN_VERSION}-bin.tar.gz"
DOWNLOAD_URL="https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/${MAVEN_ARCHIVE}"
TEMP_DIR=$(mktemp -d)

cleanup() {
  if [[ -d "$TEMP_DIR" ]]; then
    rm -rf "$TEMP_DIR"
  fi
}
trap cleanup EXIT

log "Installing Apache Maven ${MAVEN_VERSION}"

# Download Maven
log "Downloading Maven from ${DOWNLOAD_URL}"
run "curl -fsSL -o \"${TEMP_DIR}/${MAVEN_ARCHIVE}\" \"${DOWNLOAD_URL}\""

# Extract Maven
log "Extracting Maven to ${MAVEN_HOME}"
run "mkdir -p \"${MAVEN_HOME}\""
run "tar -xzf \"${TEMP_DIR}/${MAVEN_ARCHIVE}\" -C \"${TEMP_DIR}\""
run "rm -rf \"${MAVEN_HOME}/current\""
run "mv \"${TEMP_DIR}/apache-maven-${MAVEN_VERSION}\" \"${MAVEN_HOME}/current\""

# Create bin directory
run "mkdir -p \"${BIN_DIR}\""

# Create mvn wrapper
log "Creating mvn wrapper in ${BIN_DIR}"
run "cat >\"${BIN_DIR}/mvn\" <<'WRAP'
#!/usr/bin/env bash
exec \"${HOME}/.shellscript/maven/current/bin/mvn\" \"\$@\"
WRAP"
run "chmod +x \"${BIN_DIR}/mvn\""

# Create mvnDebug wrapper
log "Creating mvnDebug wrapper in ${BIN_DIR}"
run "cat >\"${BIN_DIR}/mvnDebug\" <<'WRAP'
#!/usr/bin/env bash
exec \"${HOME}/.shellscript/maven/current/bin/mvnDebug\" \"\$@\"
WRAP"
run "chmod +x \"${BIN_DIR}/mvnDebug\""

# Write shell init snippet
run "mkdir -p \"${SHELLRC_DIR}\""
cat >"${SHELLRC_DIR}/maven-init.sh" <<'WRAP'
export MAVEN_HOME="$HOME/.shellscript/maven/current"
export M2_HOME="$HOME/.shellscript/maven/current"
WRAP

log "Done. Maven ${MAVEN_VERSION} installed to ${MAVEN_HOME}/current"
log "Source ${SHELLRC_DIR}/maven-init.sh from your shell rc for MAVEN_HOME environment variable"
