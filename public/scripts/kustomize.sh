#!/usr/bin/env bash
# kustomize.sh: Download and install Kustomize, to customize Kubernetes manifests

set -euo pipefail

print_usage() {
  cat <<'USAGE'
load.sh kustomize -- [options]

Downloads the Kustomize binary for x86_64 and aarch64 Linux to
$HOME/.shellscript/kustomize/<version> and creates the 'kustomize' command, with its completion for
bash (when the bash-completion package is installed) and zsh. Run it again with
another --version to switch.

Options:
  -h, --help           Show this help and exit
  --version <version>  Version to install (default: latest), e.g. 5.8.3
  --force              Re-download even if already installed
  --dry-run            Print actions without executing them
  --manifest           Print installation manifest and exit

Examples:
  load.sh kustomize
  load.sh kustomize -- --version 5.8.3
  load.sh kustomize -- --dry-run
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

BINARY_NAME="kustomize"
BINARY_LABEL="Kustomize"
BINARY_COMPLETION="completion"

# The repository also releases its libraries (kyaml/..., api/...): the latest release
# of the repository is not always a Kustomize one.
binary_latest_version() {
  fetch "https://api.github.com/repos/kubernetes-sigs/kustomize/releases?per_page=50" \
    | grep '"tag_name": *"kustomize/v' | head -1 | sed 's/.*"kustomize\/v\(.*\)".*/\1/'
}

binary_download_url() {
  echo "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${BINARY_VERSION}/kustomize_v${BINARY_VERSION}_linux_${BINARY_ARCH}.tar.gz"
}

binary_install "$@"
