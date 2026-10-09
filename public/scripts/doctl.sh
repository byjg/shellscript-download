#!/usr/bin/env bash
# doctl.sh: Download and install doctl, the DigitalOcean command-line tool

set -euo pipefail

print_usage() {
  cat <<'USAGE'
load.sh doctl -- [options]

Downloads the doctl binary for x86_64 and aarch64 Linux to
$HOME/.shellscript/doctl/<version> and creates the 'doctl' command. Run it again with
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

BINARY_NAME="doctl"
BINARY_LABEL="doctl"

binary_latest_version() {
  github_latest_tag digitalocean/doctl | sed 's/^v//'
}

binary_download_url() {
  echo "https://github.com/digitalocean/doctl/releases/download/v${BINARY_VERSION}/doctl-${BINARY_VERSION}-linux-${BINARY_ARCH}.tar.gz"
}

binary_install "$@"
