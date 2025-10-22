#!/usr/bin/env bash
# load.sh: Download and optionally run shell scripts from https://shellscript.download
# Usage:
#   load.sh [--update] [--dont-run] <script> [optional args...]
#
# Behavior:
# - If <script> does not exist locally at "$HOME/.shellscript/bin/<script>.sh" OR if --update is passed,
#   download it from: https://shellscript.download/scripts/<script>.sh
#   and save it to:   $HOME/.shellscript/bin/<script>.sh
# - After ensuring the script exists, run it with the remaining arguments, unless --dont-run is passed.
# - Exits with the same code as the executed script when run.
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
load.sh [--update] [--dont-run] <script> [optional args...]

Options:
  --update      Force re-download/update of the script even if it exists locally
  --dont-run    Do not execute the script after ensuring it is downloaded
  -h, --help    Show this help message

Arguments:
  <script>      The script name (without .sh) to fetch from shellscript.download
  [args...]     Optional arguments to pass through to the downloaded script
USAGE
}

UPDATE=false
DONT_RUN=false
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

if [[ -z "${SCRIPT_NAME}" ]]; then
  echo "Error: <script> is required." >&2
  echo >&2
  print_usage >&2
  exit 2
fi

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

if [[ "${DONT_RUN}" == true ]]; then
  echo "Script ensured at: ${DEST_PATH}" >&2
  exit 0
fi

# Execute the script with passed arguments
exec "${DEST_PATH}" "${ARGS[@]}"

