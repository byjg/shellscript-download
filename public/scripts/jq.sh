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

# Code shared with the other single-binary installers. load.sh calls postLoad once,
# right after it downloads or updates this script; a loader older than that hook
# never does, so the file is also fetched here when it is missing.
SHARED_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/binary-install.sh"

postLoad() {
  mkdir -p "$(dirname "$SHARED_LIB")"
  if ! download "https://shellscript.download/scripts/lib/binary-install.sh" "$SHARED_LIB"; then
    echo "Error: could not download lib/binary-install.sh, which this script needs" >&2
    exit 3
  fi
}

if [[ "${1-}" == "--post-load" ]]; then
  postLoad
  exit 0
fi

[[ -f "$SHARED_LIB" ]] || postLoad
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
