#!/usr/bin/env bash
# eksctl.sh: Download and install eksctl, the command-line tool for Amazon EKS clusters

set -euo pipefail

print_usage() {
  cat <<'USAGE'
load.sh eksctl -- [options]

Downloads the eksctl binary for x86_64 and aarch64 Linux to
$HOME/.shellscript/eksctl/<version> and creates the 'eksctl' command. Run it again with
another --version to switch.

Options:
  -h, --help           Show this help and exit
  --version <version>  Version to install (default: latest), e.g. 0.231.0
  --force              Re-download even if already installed
  --dry-run            Print actions without executing them
  --manifest           Print installation manifest and exit

Examples:
  load.sh eksctl
  load.sh eksctl -- --version 0.231.0
  load.sh eksctl -- --dry-run
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

BINARY_NAME="eksctl"
BINARY_LABEL="eksctl"

binary_latest_version() {
  github_latest_tag eksctl-io/eksctl | sed 's/^v//'
}

binary_download_url() {
  echo "https://github.com/eksctl-io/eksctl/releases/download/v${BINARY_VERSION}/eksctl_Linux_${BINARY_ARCH}.tar.gz"
}

binary_install "$@"
