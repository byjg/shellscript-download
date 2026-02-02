#!/usr/bin/env bash
# remove.sh: Remove installed tools from shellscript.download
#
# Usage:
#   load.sh remove -- <script-name>         - Remove binaries and shell rc files
#   load.sh remove -- --purge <script-name> - Remove everything including tool folders
#
# Examples:
#   # Remove Maven binaries and shell rc files (keeps downloaded folders)
#   load.sh remove -- maven
#   # Remove all traces of Maven including downloaded folders
#   load.sh remove -- --purge maven
#   # Remove NVM completely
#   load.sh remove -- --purge nvm
#   # Dry-run to preview actions
#   load.sh remove -- --dry-run --purge maven
#
# Description:
# - Fetches the script's manifest to know what was installed
# - Removes binaries from $HOME/.shellscript/bin/
# - Removes shell rc files from $HOME/.shellscript/shellrc/
# - With --purge: also removes tool folders from $HOME/.shellscript/<tool-name>/
# - Supports dry-run mode to preview actions

set -euo pipefail

log()  { printf "[remove.sh] %s\n" "$*"; }
err()  { printf "[remove.sh][ERROR] %s\n" "$*" >&2; }
run()  { if [[ "$DRY_RUN" == "1" ]]; then printf "[dry-run] %s\n" "$*"; else eval "$@"; fi }

print_usage() {
  cat <<'USAGE'
load.sh remove -- [--purge] [--dry-run] <script-name>

Removes installed tools from shellscript.download.

Options:
  --purge       Also remove tool folders (binaries/downloads)
  --dry-run     Print actions without executing them
  -h, --help    Show this help and exit

Arguments:
  <script-name> Name of the script/tool to remove (e.g., maven, nvm)

Examples:
  load.sh remove -- maven
  load.sh remove -- --purge maven
  load.sh remove -- --dry-run --purge nvm
USAGE
}

# Parse flags
DRY_RUN=0
PURGE=0
SCRIPT_NAME=""

while [[ ${1-} ]]; do
  case "$1" in
    -h|--help) print_usage; exit 0 ;;
    --dry-run) DRY_RUN=1 ;;
    --purge) PURGE=1 ;;
    -*)
      err "Unknown option: $1"
      print_usage
      exit 2
      ;;
    *)
      if [[ -n "$SCRIPT_NAME" ]]; then
        err "Multiple script names provided: $SCRIPT_NAME and $1"
        print_usage
        exit 2
      fi
      SCRIPT_NAME="$1"
      ;;
  esac
  shift || true
done

if [[ -z "$SCRIPT_NAME" ]]; then
  err "Missing required argument: <script-name>"
  print_usage
  exit 2
fi

log ">_ remove.sh ${PURGE:+--purge }${SCRIPT_NAME}"

# Standard directories
BASE_DIR="$HOME/.shellscript"
BIN_DIR="$BASE_DIR/bin"
DOWNLOADS_DIR="$BASE_DIR/downloads"
SCRIPT_PATH="$DOWNLOADS_DIR/${SCRIPT_NAME}.sh"

# Ensure the script is downloaded
if [[ ! -f "$SCRIPT_PATH" ]]; then
  log "Script not found in cache, downloading..."
  if [[ "$DRY_RUN" == "1" ]]; then
    log "[dry-run] Would download ${SCRIPT_NAME}.sh"
  else
    # Use load.sh if available, otherwise download directly
    if command -v load.sh >/dev/null 2>&1; then
      load.sh --dont-run "$SCRIPT_NAME" >/dev/null 2>&1 || {
        err "Failed to download script using load.sh"
        exit 3
      }
    else
      # Download directly
      mkdir -p "$DOWNLOADS_DIR"
      URL="https://shellscript.download/scripts/${SCRIPT_NAME}.sh"
      if ! curl -fsSL "$URL" -o "$SCRIPT_PATH"; then
        err "Failed to download $URL"
        exit 3
      fi
      chmod +x "$SCRIPT_PATH"
    fi
  fi
fi

# Get the manifest from the script
log "Getting installation manifest from ${SCRIPT_NAME}.sh"

if [[ "$DRY_RUN" == "1" ]]; then
  log "[dry-run] Would execute: $SCRIPT_PATH --manifest"
  # For dry-run, create dummy values
  BIN_FILES=""
  FOLDERS=""
  SHELLRC_FILE=""
else
  # Execute the script with --manifest and parse the output
  MANIFEST_OUTPUT=$("$SCRIPT_PATH" --manifest 2>/dev/null || true)

  if [[ -z "$MANIFEST_OUTPUT" ]]; then
    err "Script $SCRIPT_NAME does not support --manifest flag"
    err "Please update the script to include manifest information"
    exit 4
  fi

  # Parse manifest output
  BIN_FILES=$(echo "$MANIFEST_OUTPUT" | grep "^BIN_FILES=" | cut -d= -f2- || true)
  FOLDERS=$(echo "$MANIFEST_OUTPUT" | grep "^FOLDERS=" | cut -d= -f2- || true)
  SHELLRC_FILE=$(echo "$MANIFEST_OUTPUT" | grep "^SHELLRC_FILE=" | cut -d= -f2- || true)

  # Expand variables in the manifest
  eval "BIN_FILES=\"$BIN_FILES\""
  eval "FOLDERS=\"$FOLDERS\""
  eval "SHELLRC_FILE=\"$SHELLRC_FILE\""
fi

# Track if anything was removed
REMOVED_SOMETHING=0

# Remove bin files (always)
if [[ -n "$BIN_FILES" ]]; then
  for bin_file in $BIN_FILES; do
    bin_path="$BIN_DIR/$bin_file"
    if [[ -f "$bin_path" ]] || [[ "$DRY_RUN" == "1" ]]; then
      log "Removing binary wrapper: $bin_path"
      run "rm -f \"$bin_path\""
      REMOVED_SOMETHING=1
    fi
  done
else
  log "No binary files to remove"
fi

# Remove shell rc file (always)
if [[ -n "$SHELLRC_FILE" ]]; then
  if [[ -f "$SHELLRC_FILE" ]] || [[ "$DRY_RUN" == "1" ]]; then
    log "Removing shell rc file: $SHELLRC_FILE"
    run "rm -f \"$SHELLRC_FILE\""
    REMOVED_SOMETHING=1
  else
    log "Shell rc file not found: $SHELLRC_FILE (skipping)"
  fi
fi

# Remove folders (only with --purge)
if [[ "$PURGE" == "1" ]]; then
  if [[ -n "$FOLDERS" ]]; then
    for folder in $FOLDERS; do
      if [[ -d "$folder" ]] || [[ "$DRY_RUN" == "1" ]]; then
        log "Removing folder: $folder"
        run "rm -rf \"$folder\""
        REMOVED_SOMETHING=1
      else
        log "Folder not found: $folder (skipping)"
      fi
    done
  else
    log "No folders to remove"
  fi
fi

# Final message
if [[ "$REMOVED_SOMETHING" == "1" ]] || [[ "$DRY_RUN" == "1" ]]; then
  log "Done. ${SCRIPT_NAME} has been unloaded."
  if [[ "$PURGE" == "0" ]]; then
    log "Tip: Use --purge to also remove tool folders"
  else
    log "All traces of ${SCRIPT_NAME} have been removed."
  fi
  log "Restart your shell or run: source ~/.bashrc"
else
  log "Nothing to remove for ${SCRIPT_NAME}"
fi