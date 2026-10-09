#!/usr/bin/env bash
# java-temurin.sh: Download and install Eclipse Temurin Java (OpenJDK)

set -euo pipefail


print_usage() {
  cat <<'USAGE'
load.sh java-temurin -- [options]

Downloads and installs Eclipse Temurin (Adoptium) OpenJDK binary distribution for x86_64 and aarch64 Linux.
Uses the Adoptium API to resolve the latest patch release for the requested major version.

The installed version becomes the active Java, whatever its vendor:
$HOME/.shellscript/java/current points at it and JAVA_HOME follows. Run the installer
again with another --version to switch. To use another installed version in the
current shell only: java-use <vendor> <version>, e.g. java-use temurin 17.

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
  load.sh java-temurin
  load.sh java-temurin -- --version 17
  load.sh java-temurin -- --version 14 --yes
  load.sh java-temurin -- --dry-run
  load.sh java-temurin -- --manifest --version 17
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

JAVA_VENDOR="temurin"
JAVA_LABEL="Eclipse Temurin Java"
JAVA_LTS_VERSIONS="8 11 17 21 25"

# Resolve the latest patch release of the major version through the Adoptium API
java_download_url() {
  require_cmd jq
  local url
  url=$(fetch "https://api.adoptium.net/v3/assets/latest/${JAVA_VERSION}/hotspot?architecture=${JAVA_ARCH}&image_type=jdk&os=linux&vendor=eclipse" \
    | jq -r '.[0].binary.package.link // empty') || true

  # Hardcoded fallback for EOL versions not available via Adoptium (hosted under AdoptOpenJDK, x64 only)
  if [[ -z "$url" && "$JAVA_ARCH" == "x64" ]]; then
    case "$JAVA_VERSION" in
      14) url="https://github.com/AdoptOpenJDK/openjdk14-binaries/releases/download/jdk-14.0.2%2B12/OpenJDK14U-jdk_x64_linux_hotspot_14.0.2_12.tar.gz" ;;
    esac
  fi

  if [[ -z "$url" ]]; then
    err "This version may not be available on Adoptium. Check https://adoptium.net"
  fi
  echo "$url"
}

java_install "$@"
