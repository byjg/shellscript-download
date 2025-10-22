#!/usr/bin/env bash
# nvm.sh: Install Node Version Manager (NVM) and set up a shell init snippet
#
# Usage (via loader):
#   load.sh nvm -- [--help] [--dry-run]
#
# Examples:
#   # Install NVM with sensible defaults
#   load.sh nvm
#   # Show help
#   load.sh nvm -- --help
#   # Simulate actions without making changes
#   load.sh nvm -- --dry-run
#
# Description:
# - Installs NVM using the official install script from nvm-sh/nvm
# - Removes the trailing installer-added lines from common shell rc files to avoid duplication
# - Creates $HOME/.shellscript/shellrc/nvm-init.sh which you can source from your rc
# - Idempotent and non-interactive; supports a dry-run mode

set -euo pipefail
IFS=$'\n\t'

log()  { printf "[nvm.sh] %s\n" "$*"; }
err()  { printf "[nvm.sh][ERROR] %s\n" "$*" >&2; }
run()  { if [[ "$DRY_RUN" == "1" ]]; then printf "[dry-run] %s\n" "$*"; else eval "$@"; fi }
require_cmd() { command -v "$1" >/dev/null 2>&1 || { err "Required command '$1' not found"; exit 1; }; }

print_usage() {
  cat <<'USAGE'
load.sh nvm -- [options]

Installs NVM and writes a shell init snippet under $HOME/.shellscript/shellrc/nvm-init.sh.

Options:
  -h, --help    Show this help and exit
  --dry-run     Print actions without executing them

Examples:
  load.sh nvm
  load.sh nvm -- --dry-run
USAGE
}

# Parse flags
DRY_RUN=0
while [[ ${1-} ]]; do
  case "$1" in
    -h|--help) print_usage; exit 0 ;;
    --dry-run) DRY_RUN=1 ;;
    *) err "Unknown option: $1"; print_usage; exit 2 ;;
  esac
  shift || true
done

log ">_ nvm.sh"

# Preconditions
require_cmd curl

remove_nvm_lines() {
  local files=(~/.bashrc ~/.bash_profile ~/.profile ~/.zshrc ~/.zprofile)
  for file in "${files[@]}"; do
    if [[ -f "$file" ]]; then
      # Only remove the last up-to-3 lines if they contain NVM_DIR marker
      if tail -n 3 "$file" 2>/dev/null | grep -q "NVM_DIR"; then
        log "Cleaning trailing NVM lines from $file"
        run "sed -i -e :a -e '$d;N;2,3ba' -e 'P;D' \"$file\""
      fi
    fi
  done
}

# Install NVM
# Using the official installer; see https://github.com/nvm-sh/nvm
run "curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash"

# Remove noisy trailing additions from rc files (idempotent)
remove_nvm_lines

# Write our shell init snippet
DEST_FOLDER="$HOME/.shellscript/shellrc"
run "mkdir -p \"$DEST_FOLDER\""
run "cat >\"${DEST_FOLDER}/nvm-init.sh\" <<'WRAP'\nexport NVM_DIR=\"$HOME/.nvm\"\n[ -s \"$NVM_DIR/nvm.sh\" ] && \\ . \"$NVM_DIR/nvm.sh\"  # This loads nvm\n[ -s \"$NVM_DIR/bash_completion\" ] && \\ . \"$NVM_DIR/bash_completion\"  # This loads nvm bash_completion\nWRAP"

log "Done. Source ${DEST_FOLDER}/nvm-init.sh from your shell rc (e.g., echo 'source \"$DEST_FOLDER/nvm-init.sh\"' >> ~/.bashrc)"
