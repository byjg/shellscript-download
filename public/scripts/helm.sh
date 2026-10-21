#!/usr/bin/env bash
# helm.sh: Download and install Helm, the Kubernetes package manager

set -euo pipefail

print_usage() {
  cat <<'USAGE'
load.sh helm -- [options]

Downloads the Helm binary for x86_64 and aarch64 Linux to
$HOME/.shellscript/helm/<version> and creates the 'helm' command, with its completion for
bash (when the bash-completion package is installed) and zsh. Run it again with
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

BINARY_NAME="helm"
BINARY_LABEL="Helm"
BINARY_COMPLETION="completion"

binary_latest_version() {
  github_latest_tag helm/helm | sed 's/^v//'
}

binary_download_url() {
  echo "https://get.helm.sh/helm-v${BINARY_VERSION}-linux-${BINARY_ARCH}.tar.gz"
}

binary_install "$@"
