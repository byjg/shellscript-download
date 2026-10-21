#!/usr/bin/env bash
# java-oracle.sh: Download and install Oracle JDK

set -euo pipefail


print_usage() {
  cat <<'USAGE'
load.sh java-oracle -- [options]

Downloads and installs Oracle JDK binary distribution for x86_64 and aarch64 Linux.

The installed version becomes the active Java, whatever its vendor:
$HOME/.shellscript/java/current points at it and JAVA_HOME follows. Run the installer
again with another --version to switch. To use another installed version in the
current shell only: java-use <vendor> <version>, e.g. java-use temurin 17.

Options:
  -h, --help           Show this help and exit
  --version <version>  Java major version to install (default: 25)
                       LTS versions: 25, and 17 and 21 as their last public build
                       (17.0.12, 21.0.12), which gets no more updates: later updates
                       need an Oracle account. For updates of 17 or 21: java-temurin
                       Non-LTS versions require confirmation (or --yes)
  --yes, -y            Skip confirmation for non-LTS versions
  --force              Re-download even if already installed
  --dry-run            Print actions without executing them
  --manifest [--version <version>]
                       Print installation manifest and exit
                       Without --version: removes all versions (default)
                       With --version: removes only specific version

Examples:
  load.sh java-oracle
  load.sh java-oracle -- --version 21
  load.sh java-oracle -- --version 27 --yes
  load.sh java-oracle -- --dry-run
  load.sh java-oracle -- --manifest --version 21

Note:
  By downloading and using Oracle JDK, you agree to the Oracle Technology Network License Agreement.
  For production use, please review Oracle's licensing terms.
USAGE
}

# Code shared with the other java-<vendor> installers.
# load.sh downloads it with this script, from the name in the line below; a loader
# older than that leaves it missing.
SHARED_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/java-install.sh"
if [[ ! -f "$SHARED_LIB" ]]; then
  echo "Error: lib/java-install.sh, which this script needs, is missing: run 'load.sh --update'" >&2
  exit 3
fi
# shellcheck source=lib/java-install.sh
source "$SHARED_LIB"

JAVA_VENDOR="oracle"
JAVA_LABEL="Oracle JDK"
JAVA_LTS_VERSIONS="17 21 25"
JAVA_DEFAULT_VERSION="25"
JAVA_NON_LTS_NOTE="Oracle publishes, without an account, only its latest releases. Other versions may fail."

java_download_url() {
  local build
  case "$JAVA_VERSION" in
    # The last builds Oracle published without an account (No-Fee Terms): the updates
    # after them need an Oracle account
    17) build="17.0.12" ;;
    21) build="21.0.12" ;;
    *)
      echo "https://download.oracle.com/java/${JAVA_VERSION}/latest/jdk-${JAVA_VERSION}_linux-${JAVA_ARCH}_bin.tar.gz"
      return
      ;;
  esac
  # On stderr: the URL is what the caller reads from stdout
  log "WARNING: ${build} is the last public build of Oracle JDK ${JAVA_VERSION}, and gets no more updates. For updates: java-temurin." >&2
  echo "https://download.oracle.com/java/${JAVA_VERSION}/archive/jdk-${build}_linux-${JAVA_ARCH}_bin.tar.gz"
}

java_install "$@"

log ""
log "IMPORTANT: By using Oracle JDK, you agree to Oracle's licensing terms."
log "Visit https://www.oracle.com/downloads/licenses/binary-code-license.html for details."
