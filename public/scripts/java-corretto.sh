#!/usr/bin/env bash
# java-corretto.sh: Download and install Amazon Corretto OpenJDK

set -euo pipefail


print_usage() {
  cat <<'USAGE'
load.sh java-corretto -- [options]

Downloads and installs Amazon Corretto OpenJDK binary distribution for x86_64 and aarch64 Linux.

Options:
  -h, --help           Show this help and exit
  --version <version>  Java major version to install (default: 21)
                       LTS versions: 8, 11, 17, 21, 25
                       Non-LTS versions require confirmation (or --yes)
  --yes, -y            Skip confirmation for non-LTS versions
  --force              Re-download even if already installed
  --dry-run            Print actions without executing them
  --manifest [--version <version>]
                       Print installation manifest and exit
                       Without --version: removes all versions (default)
                       With --version: removes only specific version

Examples:
  load.sh java-corretto
  load.sh java-corretto -- --version 17
  load.sh java-corretto -- --version 14 --yes
  load.sh java-corretto -- --dry-run
  load.sh java-corretto -- --manifest --version 21
USAGE
}

# Code shared with the other java-<vendor> installers. load.sh calls postLoad once,
# right after it downloads or updates this script; a loader older than that hook
# never does, so the file is also fetched here when it is missing.
SHARED_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/java-install.sh"

postLoad() {
  mkdir -p "$(dirname "$SHARED_LIB")"
  if ! download "https://shellscript.download/scripts/lib/java-install.sh" "$SHARED_LIB"; then
    echo "Error: could not download lib/java-install.sh, which this script needs" >&2
    exit 3
  fi
}

if [[ "${1-}" == "--post-load" ]]; then
  postLoad
  exit 0
fi

[[ -f "$SHARED_LIB" ]] || postLoad
# shellcheck source=lib/java-install.sh
source "$SHARED_LIB"

JAVA_VENDOR="corretto"
JAVA_LABEL="Amazon Corretto Java"
JAVA_LTS_VERSIONS="8 11 17 21 25"

java_download_url() {
  echo "https://corretto.aws/downloads/latest/amazon-corretto-${JAVA_VERSION}-${JAVA_ARCH}-linux-jdk.tar.gz"
}

java_install "$@"
