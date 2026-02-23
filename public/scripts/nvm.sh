#!/usr/bin/env bash
# nvm.sh: Install Node Version Manager (NVM) and set up a shell init snippet

set -euo pipefail

log()  { printf "[nvm.sh] %s\n" "$*"; }
err()  { printf "[nvm.sh][ERROR] %s\n" "$*" >&2; }
run()  { if [[ "$DRY_RUN" == "1" ]]; then printf "[dry-run] %s\n" "$*"; else bash -c "$@"; fi }
require_cmd() { command -v "$1" >/dev/null 2>&1 || { err "Required command '$1' not found"; exit 1; }; }

print_usage() {
  cat <<'USAGE'
load.sh nvm -- [options]

Installs NVM and writes a shell init snippet under $HOME/.shellscript/shellrc/nvm-init.sh.

Options:
  -h, --help    Show this help and exit
  --dry-run     Print actions without executing them
  --manifest    Print installation manifest and exit

Examples:
  load.sh nvm
  load.sh nvm -- --dry-run
USAGE
}

print_manifest() {
  cat <<'MANIFEST'
BIN_FILES=
FOLDERS=$HOME/.nvm
SHELLRC_FILE=$HOME/.shellscript/shellrc/nvm-init.sh
MANIFEST
}

# Parse flags
DRY_RUN=0
while [[ ${1-} ]]; do
  case "$1" in
    -h|--help) print_usage; exit 0 ;;
    --manifest) print_manifest; exit 0 ;;
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
        run "sed -i -e :a -e '\$d;N;2,3ba' -e 'P;D' \"$file\""
      fi
    fi
  done
}

# Install NVM
# Using the official installer; see https://github.com/nvm-sh/nvm
NVM_VERSION=$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest | grep '"tag_name"' | sed 's/.*"tag_name": *"\(.*\)".*/\1/')
log "Installing NVM ${NVM_VERSION}"
run "curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash"

# Remove noisy trailing additions from rc files (idempotent)
remove_nvm_lines

# Write our shell init snippet
DEST_FOLDER="$HOME/.shellscript/shellrc"
run "mkdir -p \"$DEST_FOLDER\""

if [[ "$DRY_RUN" == "1" ]]; then
  log "[dry-run] Writing ${DEST_FOLDER}/nvm-init.sh"
else
  cat >"${DEST_FOLDER}/nvm-init.sh" <<'WRAP'
export NVM_DIR="$HOME/.nvm"
export NVM_SYMLINK_CURRENT=true
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
WRAP
fi

log "Done. Source ${DEST_FOLDER}/nvm-init.sh from your shell rc. Close the terminal and open it again)"
