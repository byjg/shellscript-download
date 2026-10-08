#!/usr/bin/env bash
# java-oracle.sh: Download and install Oracle JDK

set -euo pipefail


print_usage() {
  cat <<'USAGE'
load.sh java-oracle -- [options]

Downloads and installs Oracle JDK binary distribution for x86_64 and aarch64 Linux.

The installed version becomes the active Java, whatever its vendor:
$HOME/.shellscript/java/current points at it and JAVA_HOME follows. Run the installer
again with another --version to switch.

Options:
  -h, --help           Show this help and exit
  --version <version>  Java major version to install (default: 21)
                       LTS versions: 17, 21, 25 (publicly available)
                       Non-LTS versions require confirmation (or --yes)
                       Note: Oracle only provides public downloads for recent LTS versions
  --yes, -y            Skip confirmation for non-LTS versions
  --force              Re-download even if already installed
  --dry-run            Print actions without executing them
  --manifest [--version <version>]
                       Print installation manifest and exit
                       Without --version: removes all versions (default)
                       With --version: removes only specific version

Examples:
  load.sh java-oracle
  load.sh java-oracle -- --version 25
  load.sh java-oracle -- --version 24 --yes
  load.sh java-oracle -- --dry-run
  load.sh java-oracle -- --manifest --version 21

Note:
  By downloading and using Oracle JDK, you agree to the Oracle Technology Network License Agreement.
  For production use, please review Oracle's licensing terms.
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

JAVA_VENDOR="oracle"
JAVA_LABEL="Oracle JDK"
JAVA_LTS_VERSIONS="17 21 25"
JAVA_NON_LTS_NOTE="Oracle only provides public downloads for recent LTS versions. Other versions may fail."

java_download_url() {
  echo "https://download.oracle.com/java/${JAVA_VERSION}/latest/jdk-${JAVA_VERSION}_linux-${JAVA_ARCH}_bin.tar.gz"
}

java_install "$@"

log ""
log "IMPORTANT: By using Oracle JDK, you agree to Oracle's licensing terms."
log "Visit https://www.oracle.com/downloads/licenses/binary-code-license.html for details."
