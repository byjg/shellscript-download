#!/usr/bin/env bash
# gcloud.sh: Download and install the Google Cloud CLI (gcloud, gsutil, bq)

set -euo pipefail

print_usage() {
  cat <<'USAGE'
load.sh gcloud -- [options]

Downloads the Google Cloud CLI for x86_64 and aarch64 Linux to
$HOME/.shellscript/gcloud and creates the 'gcloud', 'gsutil' and 'bq' commands.
Nothing needs root. Run it again to replace it with the latest version.

Options:
  -h, --help           Show this help and exit
  --version <version>  Version to install (default: latest), e.g. 540.0.0
  --dry-run            Print actions without executing them
  --manifest           Print installation manifest and exit

Examples:
  load.sh gcloud
  load.sh gcloud -- --version 540.0.0
  load.sh gcloud -- --dry-run
USAGE
}

print_manifest() {
  cat <<'MANIFEST'
BIN_FILES=gcloud gsutil bq
FOLDERS=$HOME/.shellscript/gcloud
SHELLRC_FILE=$HOME/.shellscript/shellrc/gcloud-init.sh
MANIFEST
}

# Parse flags
DRY_RUN=0
GCLOUD_VERSION=""
while [[ ${1-} ]]; do
  case "$1" in
    -h|--help) print_usage; exit 0 ;;
    --manifest) print_manifest; exit 0 ;;
    --dry-run) DRY_RUN=1 ;;
    --version)
      shift || { err "--version requires a value"; exit 2; }
      GCLOUD_VERSION="$1"
      ;;
    *) err "Unknown option: $1"; print_usage; exit 2 ;;
  esac
  shift || true
done

# Preconditions
require_downloader
require_cmd tar

case "$(uname -m)" in
  x86_64|amd64)  GCLOUD_ARCH="x86_64" ;;
  aarch64|arm64) GCLOUD_ARCH="arm" ;;
  *) err "Unsupported architecture: $(uname -m) (supported: x86_64, aarch64)"; exit 1 ;;
esac

# Configuration
GCLOUD_HOME="${SHELLSCRIPT_HOME}/gcloud"
SHELLRC_FILE="${SHELLSCRIPT_SHELLRC}/gcloud-init.sh"
DOWNLOAD_URL="https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-${GCLOUD_VERSION:+${GCLOUD_VERSION}-}linux-${GCLOUD_ARCH}.tar.gz"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

log "Installing the Google Cloud CLI ${GCLOUD_VERSION:-(latest)}"
log "Downloading ${DOWNLOAD_URL}"
run "download \"${DOWNLOAD_URL}\" \"${TEMP_DIR}/gcloud.tar.gz\"" || {
  err "Could not download the Google Cloud CLI ${GCLOUD_VERSION:-(latest)} for ${GCLOUD_ARCH}: check the version."
  exit 1
}

# The archive holds one directory, google-cloud-sdk
log "Extracting to ${GCLOUD_HOME}"
run "tar -xzf \"${TEMP_DIR}/gcloud.tar.gz\" -C \"${TEMP_DIR}\""
run "mkdir -p \"${GCLOUD_HOME}\" \"${SHELLSCRIPT_BIN}\""
run "rm -rf \"${GCLOUD_HOME}/google-cloud-sdk\""
run "mv \"${TEMP_DIR}/google-cloud-sdk\" \"${GCLOUD_HOME}/google-cloud-sdk\""

for cmd in gcloud gsutil bq; do
  if [[ "$DRY_RUN" == "1" ]]; then
    log "[dry-run] Writing ${SHELLSCRIPT_BIN}/${cmd}"
  else
    # The path is written now, not looked up through \$HOME when the wrapper runs:
    # it keeps working for another user or with another HOME, as CI systems run it.
    cat >"${SHELLSCRIPT_BIN}/${cmd}" <<WRAP
#!/usr/bin/env bash
exec "${GCLOUD_HOME}/google-cloud-sdk/bin/${cmd}" "\$@"
WRAP
    chmod +x "${SHELLSCRIPT_BIN}/${cmd}"
  fi
done

# Write shell init snippet: command completion
run "mkdir -p \"${SHELLSCRIPT_SHELLRC}\""
if [[ "$DRY_RUN" == "1" ]]; then
  log "[dry-run] Writing ${SHELLRC_FILE}"
else
  cat >"${SHELLRC_FILE}" <<'WRAP'
if [ -n "${BASH_VERSION:-}" ]; then
  . "$HOME/.shellscript/gcloud/google-cloud-sdk/completion.bash.inc"
elif [ -n "${ZSH_VERSION:-}" ]; then
  . "$HOME/.shellscript/gcloud/google-cloud-sdk/completion.zsh.inc"
fi
WRAP
fi

log "Done. Google Cloud CLI installed to ${GCLOUD_HOME}. Try: gcloud --version"
