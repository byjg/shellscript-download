#!/usr/bin/env bash
# eksctl.sh: Download and install eksctl, the command-line tool for Amazon EKS clusters

set -euo pipefail

print_usage() {
  cat <<'USAGE'
load.sh eksctl -- [options]

Downloads the eksctl binary for x86_64 and aarch64 Linux to
$HOME/.shellscript/eksctl/<version> and creates the 'eksctl' command, with its completion for
bash (when the bash-completion package is installed) and zsh. Run it again with
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

BINARY_NAME="eksctl"
BINARY_LABEL="eksctl"
BINARY_COMPLETION="completion"

binary_latest_version() {
  github_latest_tag eksctl-io/eksctl | sed 's/^v//'
}

binary_download_url() {
  echo "https://github.com/eksctl-io/eksctl/releases/download/v${BINARY_VERSION}/eksctl_Linux_${BINARY_ARCH}.tar.gz"
}

binary_install "$@"
