#!/usr/bin/env bash
# doctl.sh: Download and install doctl, the DigitalOcean command-line tool

set -euo pipefail

print_usage() {
  cat <<'USAGE'
load.sh doctl -- [options]

Downloads the doctl binary for x86_64 and aarch64 Linux to
$HOME/.shellscript/doctl/<version> and creates the 'doctl' command, with its completion for
bash (when the bash-completion package is installed) and zsh. Run it again with
another --version to switch.

Options:
  -h, --help           Show this help and exit
  --version <version>  Version to install (default: latest), e.g. 1.181.0
  --force              Re-download even if already installed
  --dry-run            Print actions without executing them
  --manifest           Print installation manifest and exit

Examples:
  load.sh doctl
  load.sh doctl -- --version 1.181.0
  load.sh doctl -- --dry-run
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

BINARY_NAME="doctl"
BINARY_LABEL="doctl"
BINARY_COMPLETION="completion"

binary_latest_version() {
  github_latest_tag digitalocean/doctl | sed 's/^v//'
}

binary_download_url() {
  echo "https://github.com/digitalocean/doctl/releases/download/v${BINARY_VERSION}/doctl-${BINARY_VERSION}-linux-${BINARY_ARCH}.tar.gz"
}

binary_install "$@"
