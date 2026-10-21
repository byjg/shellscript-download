#!/usr/bin/env bash
# load.sh: Fetch a script from https://shellscript.download, cache it locally,
#          and optionally execute it.
#
# Cache location used by this script:
#   $HOME/.shellscript/downloads/<script>.sh
#
# Usage and options: load.sh --help
#
# To update the loader, its completion and the scripts this machine has downloaded:
#   load.sh --update
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
#   - What is downloaded from shellscript.download (a script, the files the scripts share,
#     this loader and its completion) is used only when its signature (<url>.sig) is the
#     one of the key written in this file. It needs gpgv. Not with --developer.
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

# The banner goes to stderr: stdout is the script's own output, which a caller
# may capture, e.g. ip=$(load.sh qemu -- address vm1)
echo ">_ load.sh" >&2
echo >&2

print_usage() {
  cat <<'USAGE'
load.sh [--update] [--upgrade] [--dont-run] [--list] [--installed] [--completion] [--developer <path>] <script> [optional args...]

Options:
  --update           Update the loader and the local cached copies of the scripts.
                     With a script: update only that script, then run it
  --upgrade          Install again what is installed, each script with the arguments it
                     was last installed with, so that a tool follows its latest version
                     and one that was given a version keeps it. With a script: only
                     that one. A script that has nothing newer to install skips it
  --dont-run         Do not execute the script after ensuring it is downloaded
  --list             List all available scripts from shellscript.download, with the
                     version of the ones installed on this machine
  --installed        List only the scripts installed on this machine
  --completion       Install/update bash completion for load.sh into ~/.shellscript/shellrc/
  --developer <path> Use a local directory instead of downloading (for development)
  -h, --help         Show this help message

Arguments:
  <script>      The script name (without .sh) to fetch from shellscript.download
  [args...]     Optional arguments to pass through to the downloaded script

Signatures:
  What is downloaded from shellscript.download is used only when it is signed by the
  key of opensource.byjg.com/byjg.gpg. Checking that needs gpgv (apt install gpgv,
  dnf install gnupg2, apk add gpgv).

Environment:
  GITHUB_TOKEN  Sent to the GitHub API, where the scripts look up the latest version of
                a tool. Without it GitHub answers 60 requests an hour per address.
USAGE
}

UPDATE=false
DONT_RUN=false
LIST=false
INSTALLED=false
UPGRADE=false
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
    --installed)
      INSTALLED=true
      shift
      ;;
    --upgrade)
      UPGRADE=true
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

# This loader, by its path: to ask a script for its manifest
LOADER_SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

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
# Network helpers with curl -> wget fallback.
# The GitHub API answers 60 requests an hour to who does not identify itself, which a
# shared address (a CI runner, an office) uses up fast. With GITHUB_TOKEN set, fetch and
# download send it to api.github.com, and to no other host.
github_auth_header() {
  if [[ -n "${GITHUB_TOKEN:-}" && "$1" == https://api.github.com/* ]]; then
    printf 'Authorization: Bearer %s' "$GITHUB_TOKEN"
  fi
}
fetch() {
  local auth; auth="$(github_auth_header "$1")"
  if command -v curl >/dev/null 2>&1; then curl -fsSL ${auth:+-H "$auth"} "$1"; else wget -qO- ${auth:+--header="$auth"} "$1"; fi
}
download() {
  local auth; auth="$(github_auth_header "$1")"
  if command -v curl >/dev/null 2>&1; then curl -fsSL ${auth:+-H "$auth"} -o "$2" "$1"; else wget -qO "$2" ${auth:+--header="$auth"} "$1"; fi
}
require_downloader() { command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 || { err "Required command 'curl' or 'wget' not found"; exit 1; }; }
# final_url <url>: where a URL leads after its redirects, without downloading it
final_url() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSIL -o /dev/null -w '%{url_effective}\n' "$1"
  else
    # wget shows every answer of the chain, and the last one is where it ends: as a
    # Location header (GNU Wget, BusyBox), or as "HTTP response 200 [<url>]" (Wget2)
    local answers location
    answers="$(wget -S --spider "$1" 2>&1)" || true
    # GNU Wget also reports each redirect as "Location: <url> [following]"
    location="$(printf '%s\n' "$answers" | sed -n 's/^ *[Ll]ocation: *//p' | tail -n 1 | tr -d '\r' | sed 's/ \[following\]$//')"
    [[ -n "$location" ]] || location="$(printf '%s\n' "$answers" | sed -n 's/^HTTP response [0-9]* *\[\(.*\)\]$/\1/p' | tail -n 1)"
    printf '%s\n' "${location:-$1}"
  fi
}
# remote_stamp <url>: what tells one file a URL serves from the next one, without
# downloading it: the URL with the ETag of the server, or with the date the file changed.
# Nothing when the server gives neither, or with Wget2, which does not show the headers:
# a script then has no way to know, and installs.
remote_stamp() {
  local headers stamp
  if command -v curl >/dev/null 2>&1; then
    headers="$(curl -fsSIL "$1" 2>/dev/null)" || return 0
  else
    headers="$(wget -S --spider "$1" 2>&1)" || return 0
  fi
  headers="$(printf '%s\n' "$headers" | tr -d '\r')"
  stamp="$(sed -n 's/^ *[Ee][Tt][Aa][Gg]: *//p' <<<"$headers" | tail -n 1)"
  [[ -n "$stamp" ]] || stamp="$(sed -n 's/^ *[Ll]ast-[Mm]odified: *//p' <<<"$headers" | tail -n 1)"
  [[ -z "$stamp" ]] || printf '%s %s\n' "$1" "$stamp"
}
# already_installed <url> <stamp file>: true when the file the URL serves now is the one
# the script installed, which it wrote down with record_installed. For a script that has
# to download to know the version: it can skip the download when nothing is newer.
already_installed() {
  local stamp
  stamp="$(remote_stamp "$1")"
  [[ -n "$stamp" && -f "$2" && "$stamp" == "$(cat "$2")" ]]
}
record_installed() {
  mkdir -p "$(dirname "$2")"
  remote_stamp "$1" > "$2"
}
# github_latest_tag <owner/repo>: the tag of the latest release of a repository. Read from
# where github.com/<owner>/<repo>/releases/latest redirects to, which costs no request of
# the GitHub API and its hourly quota.
github_latest_tag() {
  local url
  url="$(final_url "https://github.com/$1/releases/latest")" || return 1
  [[ "$url" == */releases/tag/* ]] || return 1
  printf '%s\n' "${url##*/releases/tag/}"
}
# require_script <script> [command]: for a script that needs a tool another script of
# the catalog installs. Runs 'load.sh <script>' unless <command> (the script name when
# omitted) is already available. Everything goes to stderr, so it is safe to call
# where the output of the script is being captured.
SHELLSCRIPT_LOADER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
SHELLSCRIPT_DEVELOPER_PATH="${DEVELOPER_PATH}"
export SHELLSCRIPT_LOADER SHELLSCRIPT_DEVELOPER_PATH
require_script() {
  local script="$1" cmd="${2:-$1}"
  command -v "$cmd" >/dev/null 2>&1 && return 0
  log "'${cmd}' is required: installing it with 'load.sh ${script}'" >&2
  if [[ "${DRY_RUN:-0}" == "1" ]]; then printf "[dry-run] load.sh %s\n" "$script" >&2; return 0; fi
  local loader=("$SHELLSCRIPT_LOADER")
  [[ -z "$SHELLSCRIPT_DEVELOPER_PATH" ]] || loader+=(--developer "$SHELLSCRIPT_DEVELOPER_PATH")
  "${loader[@]}" "$script" >&2 || { err "'load.sh ${script}' failed"; exit 1; }
  command -v "$cmd" >/dev/null 2>&1 || { err "'${cmd}' is still not available after 'load.sh ${script}'"; exit 1; }
}
# The key everything published on shellscript.download is signed with, base64 of the
# binary key (gpgv does not read an armored one). It is the key of the ByJG APT and RPM
# repositories, https://opensource.byjg.com/byjg.gpg: ByJG Opensource <info@byjg.com.br>,
# fingerprint DB84 6CC3 C109 29D3 43B6 B6DC 4BCC 9780 596C 4BCF. Written here, and not
# downloaded, so that whoever changes the site cannot change the key with it.
SHELLSCRIPT_SIGNING_KEY="
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
"
# download_signed <url> <dest>: for a file of shellscript.download, which is published with
# <url>.sig, its signature. The file goes to <dest> only when the signature is the one of
# the key above: otherwise, or when a download fails, <dest> stays as it was.
download_signed() {
  local tmp status=0
  # Not ending in .sh: the shell init sources every .sh of shellrc, even a hidden one
  tmp="$(dirname "$2")/.$(basename "$2").download"
  if ! command -v gpgv >/dev/null 2>&1; then
    err "gpgv is needed to check the signature of what comes from shellscript.download: install it (apt install gpgv, dnf install gnupg2, apk add gpgv)"
    return 1
  fi
  mkdir -p "$(dirname "$2")"
  if ! download "$1" "$tmp" 2>/dev/null || ! download "$1.sig" "$tmp.sig" 2>/dev/null; then
    err "Failed to download $1"
    status=1
  else
    base64 -d <<<"$SHELLSCRIPT_SIGNING_KEY" > "$tmp.key"
    if gpgv --keyring "$tmp.key" "$tmp.sig" "$tmp" >/dev/null 2>&1; then
      mv "$tmp" "$2"
    else
      err "$1 is not signed by the key of shellscript.download: not used"
      status=1
    fi
  fi
  rm -f "$tmp" "$tmp.sig" "$tmp.key"
  return "$status"
}
export -f log err run require_cmd github_auth_header fetch download require_downloader final_url remote_stamp already_installed record_installed github_latest_tag require_script

# installed_state <script>: prints the installed version of what a script installs, or
# "yes" when it has no version to show, and nothing when it is not on this machine.
# It reads the manifest of the script, the one 'load.sh remove' uses, so it knows only
# the scripts that were downloaded (or, with --developer, that are in that folder):
#   - a command of BIN_FILES is in ~/.shellscript/bin, or SHELLRC_FILE exists
#   - else a folder of FOLDERS has something in it, for a script that declares neither,
#     or that records there what it installed on the system (UNINSTALL_CMD)
# The version is where <folder>/current points, for a folder under ~/.shellscript: in a
# folder of the tool itself, such a link is not ours to read (~/.nvm/current is a Node).
# script_manifest <script>: prints the manifest of a script this machine has, or nothing
script_manifest() {
  local name="$1" dir="${DEVELOPER_PATH:-$HOME/.shellscript/downloads}" manifest
  [[ -f "${dir}/${name}.sh" ]] || return 0
  # Asking for the manifest runs the script: one that does not know --manifest would do
  # what it does by default, which is to install
  grep -q -- '--manifest' "${dir}/${name}.sh" || return 0
  manifest="$("$LOADER_SELF" ${DEVELOPER_PATH:+--developer "$DEVELOPER_PATH"} "$name" -- --manifest 2>/dev/null)" || return 0
  [[ "$manifest" == *"FOLDERS="* ]] || return 0
  printf '%s\n' "$manifest"
}

installed_state() {
  local name="$1"
  local manifest bins shellrc folders hook item found="" version=""
  manifest="$(script_manifest "$name")"
  [[ -n "$manifest" ]] || return 0

  bins="$(sed -n 's/^BIN_FILES=//p' <<<"$manifest")"
  shellrc="$(sed -n 's/^SHELLRC_FILE=//p' <<<"$manifest")"
  folders="$(sed -n 's/^FOLDERS=//p' <<<"$manifest")"
  hook="$(sed -n 's/^UNINSTALL_CMD=//p' <<<"$manifest")"
  shellrc="${shellrc//\$HOME/$HOME}"
  folders="${folders//\$HOME/$HOME}"

  for item in $bins; do
    if [[ -e "$HOME/.shellscript/bin/${item}" ]]; then found=yes; fi
  done
  if [[ -n "$shellrc" && -e "$shellrc" ]]; then found=yes; fi
  if [[ -z "$found" && ( -n "$hook" || ( -z "$bins" && -z "$shellrc" ) ) ]]; then
    for item in $folders; do
      if [[ -d "$item" && -n "$(ls -A "$item" 2>/dev/null)" ]]; then found=yes; fi
    done
  fi
  [[ -n "$found" ]] || return 0

  for item in $folders; do
    if [[ "$item" == "$HOME/.shellscript/"* && -L "${item}/current" ]]; then
      version="$(basename "$(readlink "${item}/current")")"
    fi
  done
  printf '%s\n' "${version:-yes}"
}

LIST_FORMAT="%-16s %-10s %s\n"

list_scripts() {
  local url="https://shellscript.download/list.json"
  local json name desc
  if command -v curl >/dev/null 2>&1; then
    json=$(curl -fsSL "${url}") || { echo "Error: Failed to download list.json" >&2; exit 3; }
  elif command -v wget >/dev/null 2>&1; then
    json=$(wget -qO- "${url}") || { echo "Error: Failed to download list.json" >&2; exit 3; }
  else
    echo "Error: Neither curl nor wget is installed." >&2
    exit 3
  fi

  # list.json has one "name" and one "description" per line, in that order
  # shellcheck disable=SC2059  # the format is a constant
  printf "$LIST_FORMAT" "SCRIPT" "INSTALLED" "DESCRIPTION"
  printf "$LIST_FORMAT" "----------------" "----------" "-----------"
  while IFS= read -r line; do
    case "$line" in
      *'"name":'*)
        name="$(sed 's/^ *"name": *"\(.*\)",\{0,1\}$/\1/' <<<"$line")"
        ;;
      *'"description":'*)
        desc="$(sed 's/^ *"description": *"\(.*\)",\{0,1\}$/\1/; s/\\"/"/g' <<<"$line")"
        printf "$LIST_FORMAT" "$name" "$(installed_state "$name")" "${desc#"${name}.sh: "}"
        ;;
    esac
  done <<<"$json"
}

# What is installed, from the scripts this machine has: it needs no network
list_installed() {
  local dir="${DEVELOPER_PATH:-$HOME/.shellscript/downloads}" file name state desc any=""
  for file in "$dir"/*.sh; do
    [[ -f "$file" ]] || continue
    name="$(basename "$file" .sh)"
    state="$(installed_state "$name")"
    [[ -n "$state" ]] || continue
    if [[ -z "$any" ]]; then
      # shellcheck disable=SC2059  # the format is a constant
      printf "$LIST_FORMAT" "SCRIPT" "INSTALLED" "DESCRIPTION"
      printf "$LIST_FORMAT" "----------------" "----------" "-----------"
      any=yes
    fi
    desc="$(sed -n '2s/^# *//p' "$file")"
    printf "$LIST_FORMAT" "$name" "$state" "${desc#"${name}.sh: "}"
  done
  [[ -n "$any" ]] || echo "Nothing installed with load.sh on this machine." >&2
}

# replace_file <url> <dest>: download_signed, saying whether that changed the file. Prints
# "updated" or "up to date"; returns 1 when it could not, and <dest> is left as it was.
# The file is moved into place in one step, so the loader can replace itself as it runs.
replace_file() {
  local before=""
  # cksum, not cmp: a minimal system has no diffutils
  [[ ! -f "$2" ]] || before="$(cksum < "$2")"
  download_signed "$1" "$2" || return 1
  if [[ "$(cksum < "$2")" == "$before" ]]; then echo "up to date"; else echo "updated"; fi
}

install_completion() {
  local dest="$HOME/.shellscript/shellrc/01-load-completion.sh"
  local url="https://shellscript.download/install/load-completion.sh"
  echo "Downloading bash completion from ${url}" >&2
  if ! replace_file "$url" "$dest" >/dev/null; then
    echo "Error: Failed to download ${url}" >&2
    exit 3
  fi
  echo "Installed: ${dest}"
}

if [[ "${LIST}" == true ]]; then
  list_scripts
  exit 0
fi

if [[ "${INSTALLED}" == true ]]; then
  list_installed
  exit 0
fi

# 'load.sh --update' without a script: the loader, its completion and every script this
# machine has downloaded, with the files they share. Nothing is run: a tool is brought to
# a newer version by running its script, which this does not do.
update_all() {
  local base="https://shellscript.download" home="$HOME/.shellscript"
  local loader="${home}/bin/load.sh" file name before state
  local format="%-22s %s\n"

  # shellcheck disable=SC2059  # the format is a constant
  if state="$(replace_file "${base}/scripts/load.sh" "$loader")"; then
    chmod +x "$loader"
    printf "$format" "load.sh" "$state"
  else
    printf "$format" "load.sh" "could not be downloaded, kept as it is"
  fi
  if state="$(replace_file "${base}/install/load-completion.sh" "${home}/shellrc/01-load-completion.sh")"; then
    printf "$format" "completion" "$state"
  else
    printf "$format" "completion" "could not be downloaded, kept as it is"
  fi

  # Each script goes through the loader just updated, which also downloads the file it
  # shares with other scripts
  for file in "${home}/downloads"/*.sh; do
    [[ -f "$file" ]] || continue
    name="$(basename "$file" .sh)"
    before="$(cksum < "$file")"
    if "$loader" --update --dont-run "$name" >/dev/null 2>&1; then
      if [[ "$(cksum < "$file")" == "$before" ]]; then state="up to date"; else state="updated"; fi
    else
      # A script that left the catalog, or a download that failed: the same answer
      state="could not be downloaded, kept as it is"
    fi
    printf "$format" "${name}.sh" "$state"
  done
}

# Where the loader keeps the arguments each script was last installed with
saved_arguments_file() { echo "$HOME/.shellscript/downloads/$1.args"; }

# 'load.sh --upgrade [script]': installs again what is installed, each script with the
# arguments it was last installed with. A script says in its manifest when that is not
# something to do to it (UPGRADE=no): its arguments are commands, not what to install.
upgrade_installed() {
  local only="$1" dir="${DEVELOPER_PATH:-$HOME/.shellscript/downloads}"
  local file name manifest saved upgraded="" failed="" left="" any=""
  local -a arguments

  for file in "$dir"/*.sh; do
    [[ -f "$file" ]] || continue
    name="$(basename "$file" .sh)"
    [[ -z "$only" || "$only" == "$name" ]] || continue
    manifest="$(script_manifest "$name")"
    if grep -qx 'UPGRADE=no' <<<"$manifest"; then
      [[ -z "$only" ]] || { echo "${name} cannot be upgraded this way: run it with what you want it to do." >&2; return 1; }
      continue
    fi
    if [[ -z "$(installed_state "$name")" ]]; then
      [[ -z "$only" ]] || { echo "${name} is not installed: install it with 'load.sh ${name}'." >&2; return 1; }
      continue
    fi

    any=yes
    arguments=()
    saved="$(saved_arguments_file "$name")"
    if [[ -f "$saved" ]]; then
      mapfile -t arguments < "$saved"
      echo "== ${name}: ${arguments[*]:-(no arguments)}"
    else
      echo "== ${name}: installed before the arguments were kept, with the defaults"
    fi
    if "$LOADER_SELF" ${DEVELOPER_PATH:+--developer "$DEVELOPER_PATH"} "$name" -- ${arguments[@]+"${arguments[@]}"}; then
      upgraded+=" ${name}"
    else
      failed+=" ${name}"
    fi
  done

  if [[ -z "$any" ]]; then
    [[ -z "$only" ]] || { echo "No such script on this machine: ${only}" >&2; return 1; }
    echo "Nothing installed with load.sh on this machine." >&2
    return 0
  fi
  echo
  echo "Upgraded:${upgraded:- none}"
  [[ -z "$failed" ]] || { echo "Failed:${failed}" >&2; return 1; }
}

if [[ "${UPGRADE}" == true ]]; then
  upgrade_installed "${SCRIPT_NAME}"
  exit $?
fi

if [[ "${UPDATE}" == true && -z "${SCRIPT_NAME}" ]]; then
  if [[ -n "${DEVELOPER_PATH}" ]]; then
    echo "Error: --update without a script downloads what is published: not with --developer." >&2
    exit 2
  fi
  update_all
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

DOWNLOADED=false
if [[ -n "${DEVELOPER_PATH}" ]]; then
  DEST_PATH="${DEVELOPER_PATH}/${SCRIPT_NAME}.sh"
  if [[ ! -f "${DEST_PATH}" ]]; then
    echo "Error: Developer script not found: ${DEST_PATH}" >&2
    exit 3
  fi
else
  DEST_DIR="$HOME/.shellscript/downloads"
  DEST_PATH="$DEST_DIR/${SCRIPT_NAME}.sh"
  URL="https://shellscript.download/scripts/${SCRIPT_NAME}.sh"

  ensure_downloaded() {
    # Download if missing or update requested
    if [[ "${UPDATE}" == true || ! -f "${DEST_PATH}" ]]; then
      echo "Fetching: ${URL}" >&2
      download_signed "${URL}" "${DEST_PATH}" || exit 3
      chmod +x "${DEST_PATH}" || true
      DOWNLOADED=true
    fi
  }

  ensure_downloaded

  # The file the script shares with other scripts (public/scripts/lib), named by its
  # SHARED_LIB line: downloaded with the script, and again when it is missing
  shared_lib="$(sed -n 's|^SHARED_LIB=.*/\(lib/[a-z0-9-]*\.sh\)"$|\1|p' "${DEST_PATH}")"
  if [[ -n "${shared_lib}" && ( "${DOWNLOADED}" == true || ! -f "${DEST_DIR}/${shared_lib}" ) ]]; then
    download_signed "https://shellscript.download/scripts/${shared_lib}" "${DEST_DIR}/${shared_lib}" || exit 3
  fi
fi

# What the scripts install to ${SHELLSCRIPT_BIN} must be found by the ones that run next
case ":${PATH}:" in
  *":${SHELLSCRIPT_BIN}:"*) ;;
  *) PATH="${SHELLSCRIPT_BIN}:${PATH}" ;;
esac
export PATH

if [[ "${DONT_RUN}" == true ]]; then
  echo "Script ensured at: ${DEST_PATH}" >&2
  exit 0
fi

echo ">_ ${SCRIPT_NAME}.sh" >&2
echo >&2

# Execute the script with passed arguments
status=0
"${DEST_PATH}" ${ARGS[@]+"${ARGS[@]}"} || status=$?

# Keep the arguments of an install that worked, for 'load.sh --upgrade' to install again
# the same way. Not what only asks or tries (--help, --manifest, --dry-run), not 'remove',
# and not a working copy run with --developer.
if [[ "$status" == "0" && -z "${DEVELOPER_PATH}" && "${SCRIPT_NAME}" != "remove" ]]; then
  keep=yes
  for argument in ${ARGS[@]+"${ARGS[@]}"}; do
    case "$argument" in -h|--help|--manifest|--dry-run) keep="" ;; esac
  done
  if [[ -n "$keep" ]]; then
    printf '%s\n' ${ARGS[@]+"${ARGS[@]}"} > "$(saved_arguments_file "${SCRIPT_NAME}")"
    # printf with no argument still writes an empty line
    [[ ${#ARGS[@]} -gt 0 ]] || : > "$(saved_arguments_file "${SCRIPT_NAME}")"
  fi
fi
exit "$status"

