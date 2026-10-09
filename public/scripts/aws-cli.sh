#!/usr/bin/env bash
# aws-cli.sh: Download and install the AWS CLI v2

set -euo pipefail

print_usage() {
  cat <<'USAGE'
load.sh aws-cli -- [options]

Downloads the AWS CLI v2 for x86_64 and aarch64 Linux and runs its installer for the
current user: it goes to $HOME/.shellscript/aws-cli, with the 'aws' command in
$HOME/.shellscript/bin. Nothing needs root. Run it again to update.

Options:
  -h, --help           Show this help and exit
  --version <version>  Version to install (default: latest), e.g. 2.31.0
  --dry-run            Print actions without executing them
  --manifest           Print installation manifest and exit

Examples:
  load.sh aws-cli
  load.sh aws-cli -- --version 2.31.0
  load.sh aws-cli -- --dry-run
USAGE
}

print_manifest() {
  cat <<'MANIFEST'
BIN_FILES=aws aws_completer
FOLDERS=$HOME/.shellscript/aws-cli
SHELLRC_FILE=$HOME/.shellscript/shellrc/aws-cli-init.sh
MANIFEST
}

# Parse flags
DRY_RUN=0
AWS_VERSION=""
while [[ ${1-} ]]; do
  case "$1" in
    -h|--help) print_usage; exit 0 ;;
    --manifest) print_manifest; exit 0 ;;
    --dry-run) DRY_RUN=1 ;;
    --version)
      shift || { err "--version requires a value"; exit 2; }
      AWS_VERSION="$1"
      ;;
    *) err "Unknown option: $1"; print_usage; exit 2 ;;
  esac
  shift || true
done

# Preconditions
require_downloader
require_cmd unzip

case "$(uname -m)" in
  x86_64|amd64)  AWS_ARCH="x86_64" ;;
  aarch64|arm64) AWS_ARCH="aarch64" ;;
  *) err "Unsupported architecture: $(uname -m) (supported: x86_64, aarch64)"; exit 1 ;;
esac

# Configuration
AWS_HOME="${SHELLSCRIPT_HOME}/aws-cli"
SHELLRC_FILE="${SHELLSCRIPT_SHELLRC}/aws-cli-init.sh"
DOWNLOAD_URL="https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}${AWS_VERSION:+-${AWS_VERSION}}.zip"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

log "Installing the AWS CLI ${AWS_VERSION:-(latest)}"
log "Downloading ${DOWNLOAD_URL}"
run "download \"${DOWNLOAD_URL}\" \"${TEMP_DIR}/awscli.zip\"" || {
  err "Could not download the AWS CLI ${AWS_VERSION:-(latest)} for ${AWS_ARCH}: check the version."
  exit 1
}

# Its installer keeps each version under <install-dir>/v2 and links the commands
run "unzip -q \"${TEMP_DIR}/awscli.zip\" -d \"${TEMP_DIR}\""
run "mkdir -p \"${SHELLSCRIPT_BIN}\""
run "\"${TEMP_DIR}/aws/install\" --install-dir \"${AWS_HOME}\" --bin-dir \"${SHELLSCRIPT_BIN}\" --update"

# Write shell init snippet: command completion
run "mkdir -p \"${SHELLSCRIPT_SHELLRC}\""
if [[ "$DRY_RUN" == "1" ]]; then
  log "[dry-run] Writing ${SHELLRC_FILE}"
else
  cat >"${SHELLRC_FILE}" <<'WRAP'
if [ -n "${BASH_VERSION:-}" ]; then
  complete -C "$HOME/.shellscript/bin/aws_completer" aws
fi
WRAP
fi

log "Done. AWS CLI installed to ${AWS_HOME}. Try: aws --version"
