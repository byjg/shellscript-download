#!/usr/bin/env bash
# kubectl.sh: Download and install kubectl, the Kubernetes command-line tool

set -euo pipefail

print_usage() {
  cat <<'USAGE'
load.sh kubectl -- [options]

Downloads the kubectl binary for x86_64 and aarch64 Linux to
$HOME/.shellscript/kubectl/<version> and creates the 'kubectl' command, with its completion for
bash (when the bash-completion package is installed) and zsh. Run it again with
another --version to switch.

Options:
  -h, --help           Show this help and exit
  --version <version>  Version to install (default: latest stable), e.g. 1.37.1
  --force              Re-download even if already installed
  --dry-run            Print actions without executing them
  --manifest           Print installation manifest and exit

Examples:
  load.sh kubectl
  load.sh kubectl -- --version 1.37.1
  load.sh kubectl -- --dry-run
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

BINARY_NAME="kubectl"
BINARY_LABEL="kubectl"
BINARY_COMPLETION="completion"

binary_latest_version() {
  fetch https://dl.k8s.io/release/stable.txt | sed 's/^v//'
}

binary_download_url() {
  echo "https://dl.k8s.io/release/v${BINARY_VERSION}/bin/linux/${BINARY_ARCH}/kubectl"
}

binary_install "$@"
