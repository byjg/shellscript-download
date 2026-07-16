#!/usr/bin/env bash
# load.sh: Fetch a script from https://shellscript.download, cache it locally,
#          and optionally execute it.
#
# Cache location used by this script:
#   $HOME/.shellscript/downloads/<script>.sh
#
# Usage:
#   load.sh [--update] [--dont-run] <script> [optional args...]
#
# Options:
#   --update           Force re-download/update of the script even if it exists locally
#   --dont-run         Do not execute the script after ensuring it is downloaded
#   --developer <path> Use a local directory instead of downloading (for development)
#   -h, --help         Show this help message
#
# Arguments:
#   <script>      The script name (without .sh) to fetch from shellscript.download
#   [args...]     Optional arguments to pass through to the downloaded script
#
# To update the loader to a new version, reinstall it via the installer:
#   /bin/bash -c "$(curl -fsSL https://shellscript.download/install/loader)"
#
# Notes about environment setup:
#   The installer (install/loader) may create and manage additional directories such as
#   $HOME/.shellscript/shellrc (for auto-loading during shell init) and
#   $HOME/.shellscript/bin (added to PATH). This load.sh script itself only ensures
#   the cache directory $HOME/.shellscript/downloads and uses it to store scripts.
#
# Behavior:
#   - If the cached file is missing at "$HOME/.shellscript/downloads/<script>.sh" OR
#     if --update is passed, the script is downloaded from the remote URL.
#   - After ensuring the cached script exists, it is executed with remaining arguments
#     unless --dont-run is provided.
#   - Exits with the same code as the executed script when run.

set -euo pipefail

# Disallow running as root (UID 0)
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  echo "Error: load.sh must not be run as root (UID 0)." >&2
  echo "Please run as a regular user without sudo." >&2
  echo "If necessary the script will call the sudo internally" >&2
  exit 1
fi

echo ">_ load.sh"
echo

print_usage() {
  cat <<'USAGE'
load.sh [--update] [--dont-run] [--list] [--completion] [--developer <path>] <script> [optional args...]

Options:
  --update           Force re-download/update of the script even if it exists locally
  --dont-run         Do not execute the script after ensuring it is downloaded
  --list             List all available scripts from shellscript.download
  --completion       Install/update bash completion for load.sh into ~/.shellscript/shellrc/
  --developer <path> Use a local directory instead of downloading (for development)
  -h, --help         Show this help message

Arguments:
  <script>      The script name (without .sh) to fetch from shellscript.download
  [args...]     Optional arguments to pass through to the downloaded script
USAGE
}

UPDATE=false
DONT_RUN=false
LIST=false
COMPLETION=false
DEVELOPER_PATH=""
SCRIPT_NAME=""
ARGS=()

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "${1}" in
    --update)
      UPDATE=true
      shift
      ;;
    --dont-run)
      DONT_RUN=true
      shift
      ;;
    --list)
      LIST=true
      shift
      ;;
    --completion)
      COMPLETION=true
      shift
      ;;
    --developer)
      shift
      if [[ $# -eq 0 ]]; then
        echo "Error: --developer requires a path argument" >&2
        exit 2
      fi
      DEVELOPER_PATH="$1"
      shift
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    --)
      shift
      # everything else goes to ARGS
      ARGS+=("$@")
      break
      ;;
    -*)
      echo "Error: Unknown option: $1" >&2
      echo >&2
      print_usage >&2
      exit 2
      ;;
    *)
      if [[ -z "${SCRIPT_NAME}" ]]; then
        SCRIPT_NAME="$1"
        shift
      else
        ARGS+=("$1")
        shift
      fi
      ;;
  esac
done

list_scripts() {
  local url="https://shellscript.download/list.json"
  local json
  if command -v curl >/dev/null 2>&1; then
    json=$(curl -fsSL "${url}") || { echo "Error: Failed to download list.json" >&2; exit 3; }
  elif command -v wget >/dev/null 2>&1; then
    json=$(wget -qO- "${url}") || { echo "Error: Failed to download list.json" >&2; exit 3; }
  else
    echo "Error: Neither curl nor wget is installed." >&2
    exit 3
  fi

  if command -v jq >/dev/null 2>&1; then
    printf "%-25s %s\n" "SCRIPT" "DESCRIPTION"
    printf "%-25s %s\n" "-------------------------" "-----------"
    echo "${json}" | jq -r '.[] | [.name, .description] | @tsv' | while IFS=$'\t' read -r name desc; do
      printf "%-25s %s\n" "${name}" "${desc}"
    done
  elif command -v python3 >/dev/null 2>&1; then
    echo "${json}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print('%-25s %s' % ('SCRIPT', 'DESCRIPTION'))
print('%-25s %s' % ('-' * 25, '-----------'))
for item in data:
    print('%-25s %s' % (item['name'], item['description']))
"
  else
    echo "${json}"
  fi
}

install_completion() {
  local dest="$HOME/.shellscript/shellrc/01-load-completion.sh"
  local url="https://shellscript.download/install/load-completion.sh"
  mkdir -p "$(dirname "$dest")"
  echo "Downloading bash completion from ${url}" >&2
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "${url}" -o "${dest}"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "${dest}" "${url}"
  else
    echo "Error: Neither curl nor wget is installed." >&2
    exit 3
  fi
  echo "Installed: ${dest}"
}

if [[ "${LIST}" == true ]]; then
  list_scripts
  exit 0
fi

if [[ "${COMPLETION}" == true ]]; then
  install_completion
  exit 0
fi

if [[ -z "${SCRIPT_NAME}" ]]; then
  echo "Error: <script> is required." >&2
  echo >&2
  print_usage >&2
  exit 2
fi

if [[ -n "${DEVELOPER_PATH}" ]]; then
  DEST_PATH="${DEVELOPER_PATH}/${SCRIPT_NAME}.sh"
  if [[ ! -f "${DEST_PATH}" ]]; then
    echo "Error: Developer script not found: ${DEST_PATH}" >&2
    exit 3
  fi
else
  DEST_DIR="$HOME/.shellscript/downloads"
  DEST_PATH="$DEST_DIR/${SCRIPT_NAME}.sh"
  DEST_PATH_TMP="$DEST_DIR/.tmp.${SCRIPT_NAME}.sh"
  URL="https://shellscript.download/scripts/${SCRIPT_NAME}.sh"

  ensure_downloaded() {
    mkdir -p "${DEST_DIR}"

    # Download if missing or update requested
    if [[ "${UPDATE}" == true || ! -f "${DEST_PATH}" ]]; then
      echo "Fetching: ${URL}" >&2
      if command -v curl >/dev/null 2>&1; then
        # Check final HTTP status code with curl
        http_code=$(curl -sS -o /dev/null -w "%{http_code}" -L "${URL}")
        if [[ "${http_code}" != "200" ]]; then
          echo "Error: Remote URL responded with HTTP ${http_code} for ${URL}" >&2
          exit 3
        fi
        # Proceed to download only after confirming HTTP 200
        if ! curl -fsSL "${URL}" -o "${DEST_PATH_TMP}"; then
          echo "Error: Failed to download ${URL} using curl" >&2
          exit 3
        fi
      elif command -v wget >/dev/null 2>&1; then
        # Check final HTTP status code with wget (spider request)
        http_code=$(wget -q --server-response --spider "${URL}" 2>&1 | awk '/HTTP\//{code=$2} END{print code}')
        if [[ -z "${http_code}" || "${http_code}" != "200" ]]; then
          [[ -z "${http_code}" ]] && http_code="unknown"
          echo "Error: Remote URL responded with HTTP ${http_code} for ${URL}" >&2
          exit 3
        fi
        # Proceed to download only after confirming HTTP 200
        if ! wget -q -O "${DEST_PATH_TMP}" "${URL}"; then
          echo "Error: Failed to download ${URL} using wget" >&2
          exit 3
        fi
      else
        echo "Error: Neither curl nor wget is installed; cannot download scripts." >&2
        exit 3
      fi
      mv "${DEST_PATH_TMP}" "${DEST_PATH}"
      chmod +x "${DEST_PATH}" || true
    fi
  }

  ensure_downloaded
fi

if [[ "${DONT_RUN}" == true ]]; then
  echo "Script ensured at: ${DEST_PATH}" >&2
  exit 0
fi

echo ">_ ${SCRIPT_NAME}.sh"
echo

# Inject standard paths and helpers into child script environment
SHELLSCRIPT_HOME="${HOME}/.shellscript"
SHELLSCRIPT_BIN="${SHELLSCRIPT_HOME}/bin"
SHELLSCRIPT_SHELLRC="${SHELLSCRIPT_HOME}/shellrc"
SHELLSCRIPT_DOWNLOADS="${SHELLSCRIPT_HOME}/downloads"
export SHELLSCRIPT_HOME SHELLSCRIPT_BIN SHELLSCRIPT_SHELLRC SHELLSCRIPT_DOWNLOADS

# Ensure standard directories exist
mkdir -p "${SHELLSCRIPT_BIN}" "${SHELLSCRIPT_SHELLRC}" "${SHELLSCRIPT_DOWNLOADS}"

# Inject helpers — exported functions resolve $0 to the child script's name
log()         { printf "[%s] %s\n"        "$(basename "$0")" "$*"; }
err()         { printf "[%s][ERROR] %s\n" "$(basename "$0")" "$*" >&2; }
run()         { if [[ "${DRY_RUN:-0}" == "1" ]]; then printf "[dry-run] %s\n" "$*"; else bash -c "$@"; fi; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || { err "Required command '$1' not found"; exit 1; }; }
# Network helpers with curl -> wget fallback
fetch()       { if command -v curl >/dev/null 2>&1; then curl -fsSL "$1"; else wget -qO- "$1"; fi; }
download()    { if command -v curl >/dev/null 2>&1; then curl -fsSL -o "$2" "$1"; else wget -qO "$2" "$1"; fi; }
require_downloader() { command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 || { err "Required command 'curl' or 'wget' not found"; exit 1; }; }
export -f log err run require_cmd fetch download require_downloader

# Execute the script with passed arguments
exec "${DEST_PATH}" "${ARGS[@]}"

