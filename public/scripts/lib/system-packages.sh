#!/usr/bin/env bash
# system-packages.sh: code shared by the scripts that install distro packages
# (qemu.sh, podman.sh). Sourced, never run.
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

# remove_recorded_packages <state_file>
# Does nothing when the state file is empty: the script installed no package.
remove_recorded_packages() {
  local state="$1" pm pkgs
  [[ -s "$state" ]] || return 0

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
