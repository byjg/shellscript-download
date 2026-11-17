#!/usr/bin/env bash
# nvm.sh: Install Node Version Manager (NVM) and set up a shell init snippet

set -euo pipefail


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

# Preconditions
require_downloader

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
# A loader older than github_latest_tag does not have it: the GitHub API answers
if declare -F github_latest_tag >/dev/null; then
  NVM_VERSION=$(github_latest_tag nvm-sh/nvm)
else
  NVM_VERSION=$(fetch https://api.github.com/repos/nvm-sh/nvm/releases/latest | grep '"tag_name"' | sed 's/.*"tag_name": *"\(.*\)".*/\1/')
fi
log "Installing NVM ${NVM_VERSION}"
run "fetch https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash"

# Remove noisy trailing additions from rc files (idempotent)
remove_nvm_lines

# Write our shell init snippet
DEST_FOLDER="${SHELLSCRIPT_SHELLRC}"
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

# The Node that NVM downloads needs libatomic, which a minimal system does not have. A
# system package: this script, which installs for the user alone, only says how.
if ! compgen -G '/usr/lib*/libatomic.so.1' >/dev/null && ! compgen -G '/usr/lib/*/libatomic.so.1' >/dev/null \
    && ! compgen -G '/lib*/libatomic.so.1' >/dev/null && ! compgen -G '/lib/*/libatomic.so.1' >/dev/null; then
  case "$(command -v apt-get || command -v dnf || command -v apk || command -v pacman || command -v zypper || true)" in
    */apt-get) libatomic_install="sudo apt-get install -y libatomic1" ;;
    */dnf)     libatomic_install="sudo dnf install -y libatomic" ;;
    */apk)     libatomic_install="sudo apk add libatomic" ;;
    */pacman)  libatomic_install="sudo pacman -S gcc-libs" ;;
    */zypper)  libatomic_install="sudo zypper install -y libatomic1" ;;
    *)         libatomic_install="your package manager (the library libatomic.so.1)" ;;
  esac
  log "Node needs libatomic, which this system does not have: 'node' does not start without it."
  log "Install it with: ${libatomic_install}"
fi

log "Done. Source ${DEST_FOLDER}/nvm-init.sh from your shell rc. Close the terminal and open it again)"
