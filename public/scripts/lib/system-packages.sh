#!/usr/bin/env bash
# system-packages.sh: code shared by the scripts that install distro packages
# (qemu.sh, podman.sh, buildah.sh, byjg-repo.sh). Sourced, never run.
#
# Every install is recorded in a state file, so the script's uninstall hook removes
# only the packages it installed and leaves the ones that were already there.

SUDO="sudo"
[[ "$(id -u)" == "0" ]] && SUDO=""

detect_pm() {
  local pm
  for pm in apt-get dnf pacman zypper apk; do
    command -v "$pm" >/dev/null 2>&1 && { printf '%s' "$pm"; return 0; }
  done
  return 1
}

# install_packages <pm> "<pkg> <pkg>..." <state_file>
install_packages() {
  local pm="$1" pkgs="$2" state="$3"
  log "Installing missing packages: ${pkgs}"
  case "$pm" in
    # An index that fails to update (a third-party source mid-sync) makes apt-get
    # update fail, while apt keeps the old one and can still install: the install
    # runs regardless, and reports the error itself if it truly cannot.
    apt-get) run "${SUDO} apt-get update; ${SUDO} apt-get install -y ${pkgs}" ;;
    dnf)     run "${SUDO} dnf install -y ${pkgs}" ;;
    pacman)  run "${SUDO} pacman -S --noconfirm --needed ${pkgs}" ;;
    zypper)  run "${SUDO} zypper install -y ${pkgs}" ;;
    apk)     run "${SUDO} apk add ${pkgs}" ;;
  esac
  if [[ "$DRY_RUN" != "1" ]]; then
    mkdir -p "$(dirname "$state")"
    printf '%s\n' ${pkgs} >> "$state"
    sort -u -o "$state" "$state"
  fi
}

# ensure_package <command> <label> <package> <state_file>
# Installs <package> unless <command> is already available.
ensure_package() {
  local cmd="$1" label="$2" pkg="$3" state="$4" pm
  if command -v "$cmd" >/dev/null 2>&1; then
    log "${label} is already installed: $("$cmd" --version)"
    return 0
  fi
  pm=$(detect_pm) || {
    err "No supported package manager found (apt, dnf, pacman, zypper, apk)."
    err "Install ${label} manually and re-run your command."
    exit 3
  }
  [[ -z "$SUDO" ]] || require_cmd sudo
  install_packages "$pm" "$pkg" "$state"
}

# remove_recorded_packages <label> <state_file>
# Removes the packages the script installed; the ones that were already there stay.
remove_recorded_packages() {
  local label="$1" state="$2" pm pkgs
  if [[ ! -s "$state" ]]; then
    log "${label} was not installed by this script — leaving system packages untouched."
    return 0
  fi

  pm=$(detect_pm) || { err "No supported package manager found."; exit 3; }
  pkgs=$(tr '\n' ' ' < "$state")
  log "Removing packages installed by this script: ${pkgs}"
  case "$pm" in
    apt-get) run "${SUDO} apt-get remove -y ${pkgs}" ;;
    dnf)     run "${SUDO} dnf remove -y ${pkgs}" ;;
    pacman)  run "${SUDO} pacman -Rns --noconfirm ${pkgs}" ;;
    zypper)  run "${SUDO} zypper remove -y ${pkgs}" ;;
    apk)     run "${SUDO} apk del ${pkgs}" ;;
  esac
  [[ "$DRY_RUN" == "1" ]] || rm -f "$state"
}
