#!/usr/bin/env bash
# helm.sh: Download and install Helm, the Kubernetes package manager

set -euo pipefail

print_usage() {
  cat <<'USAGE'
load.sh helm -- [options]

Downloads the Helm binary for x86_64 and aarch64 Linux to
$HOME/.shellscript/helm/<version> and creates the 'helm' command. Run it again with
another --version to switch.

Options:
  -h, --help           Show this help and exit
  --version <version>  Version to install (default: latest), e.g. 3.19.0
  --force              Re-download even if already installed
  --dry-run            Print actions without executing them
  --manifest           Print installation manifest and exit

Examples:
  load.sh helm
  load.sh helm -- --version 3.19.0
  load.sh helm -- --dry-run
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

BINARY_NAME="helm"
BINARY_LABEL="Helm"

binary_latest_version() {
  github_latest_tag helm/helm | sed 's/^v//'
}

binary_download_url() {
  echo "https://get.helm.sh/helm-v${BINARY_VERSION}-linux-${BINARY_ARCH}.tar.gz"
}

binary_install "$@"
