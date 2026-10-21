#!/usr/bin/env bash
# gh.sh: Download and install gh, the GitHub command-line tool

set -euo pipefail

print_usage() {
  cat <<'USAGE'
load.sh gh -- [options]

Downloads the GitHub CLI binary for x86_64 and aarch64 Linux to
$HOME/.shellscript/gh/<version> and creates the 'gh' command, with its completion for
bash (when the bash-completion package is installed) and zsh. Run it again with
another --version to switch.

Options:
  -h, --help           Show this help and exit
  --version <version>  Version to install (default: latest), e.g. 2.102.0
  --force              Re-download even if already installed
  --dry-run            Print actions without executing them
  --manifest           Print installation manifest and exit

Examples:
  load.sh gh
  load.sh gh -- --version 2.102.0
  load.sh gh -- --dry-run
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

BINARY_NAME="gh"
BINARY_LABEL="GitHub CLI"
BINARY_COMPLETION="completion -s"

binary_latest_version() {
  github_latest_tag cli/cli | sed 's/^v//'
}

binary_download_url() {
  echo "https://github.com/cli/cli/releases/download/v${BINARY_VERSION}/gh_${BINARY_VERSION}_linux_${BINARY_ARCH}.tar.gz"
}

binary_install "$@"
