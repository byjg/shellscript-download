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
