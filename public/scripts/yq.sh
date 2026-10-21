#!/usr/bin/env bash
# yq.sh: Download and install yq, the command-line YAML processor

set -euo pipefail

print_usage() {
  cat <<'USAGE'
load.sh yq -- [options]

Downloads the yq binary for x86_64 and aarch64 Linux to
$HOME/.shellscript/yq/<version> and creates the 'yq' command, with its completion for
bash (when the bash-completion package is installed) and zsh. Run it again with
another --version to switch.

Options:
  -h, --help           Show this help and exit
  --version <version>  Version to install (default: latest), e.g. 4.47.1
  --force              Re-download even if already installed
  --dry-run            Print actions without executing them
  --manifest           Print installation manifest and exit

Examples:
  load.sh yq
  load.sh yq -- --version 4.47.1
  load.sh yq -- --dry-run
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

BINARY_NAME="yq"
BINARY_LABEL="yq"
BINARY_COMPLETION="shell-completion"

binary_latest_version() {
  github_latest_tag mikefarah/yq | sed 's/^v//'
}

binary_download_url() {
  echo "https://github.com/mikefarah/yq/releases/download/v${BINARY_VERSION}/yq_linux_${BINARY_ARCH}"
}

binary_install "$@"
