#!/usr/bin/env bash
# jq.sh: Download and install jq, the command-line JSON processor

set -euo pipefail

print_usage() {
  cat <<'USAGE'
load.sh jq -- [options]

Downloads the jq binary for x86_64 and aarch64 Linux to
$HOME/.shellscript/jq/<version> and creates the 'jq' command. Run it again with
another --version to switch.

Options:
  -h, --help           Show this help and exit
  --version <version>  Version to install (default: latest), e.g. 1.8.1
  --force              Re-download even if already installed
  --dry-run            Print actions without executing them
  --manifest           Print installation manifest and exit

Examples:
  load.sh jq
  load.sh jq -- --version 1.8.1
  load.sh jq -- --dry-run
USAGE
}

# Code shared with the other single-binary installers.
# load.sh downloads it with this script, from the name in the line below; a loader
# older than that leaves it missing.
SHARED_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/binary-install.sh"
if [[ ! -f "$SHARED_LIB" ]]; then
  echo "Error: lib/binary-install.sh, which this script needs, is missing: run 'load.sh --update'" >&2
  exit 3
fi
# shellcheck source=lib/binary-install.sh
source "$SHARED_LIB"

BINARY_NAME="jq"
BINARY_LABEL="jq"

binary_latest_version() {
  github_latest_tag jqlang/jq | sed 's/^jq-//'
}

binary_download_url() {
  echo "https://github.com/jqlang/jq/releases/download/jq-${BINARY_VERSION}/jq-linux-${BINARY_ARCH}"
}

binary_install "$@"
