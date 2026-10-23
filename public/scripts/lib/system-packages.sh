#!/usr/bin/env bash
# system-packages.sh: code shared by the scripts that install distro packages
# (qemu.sh, podman.sh, buildah.sh, byjg-repo.sh, nerdctl.sh). Sourced, never run.
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

# subuid_hint <label> [<command>]: rootless containers need a range of subordinate ids
# for the user. Tells how to add one, and the command to run after, when it has none.
subuid_hint() {
  if [[ "$(id -u)" != "0" ]] && ! grep -q "^$(id -un):" /etc/subuid 2>/dev/null; then
    log "Rootless $1 needs subordinate ids for your user. If containers fail to start, run:"
    log "  echo \"$(id -un):100000:65536\" | sudo tee -a /etc/subuid /etc/subgid${2:+ && $2}"
  fi
}

# rootless_host_setup <name>: what rootless containers (podman.sh, buildah.sh) need of the
# system, where it does not set it up (Alpine): the tun device, and the cgroups that
# OpenRC mounts only with its service. Now and at boot. What it changes is recorded, for
# rootless_host_undo <name>.
rootless_host_setup() {
  local modules="/etc/modules-load.d/shellscript-$1.conf" marker="${SHELLSCRIPT_HOME}/$1/cgroups-service"
  if [[ ! -e /dev/net/tun ]]; then
    log "Loading the tun module, now and at boot: ${modules}"
    run "${SUDO} modprobe tun"
    run "echo tun | ${SUDO} tee \"${modules}\" >/dev/null"
  fi
  if command -v rc-service >/dev/null 2>&1 && ! rc-service cgroups status >/dev/null 2>&1; then
    log "Starting the cgroups service of OpenRC, now and at boot"
    run "${SUDO} rc-update add cgroups boot"
    run "${SUDO} rc-service cgroups start"
    if [[ "$DRY_RUN" != "1" ]]; then mkdir -p "$(dirname "$marker")"; touch "$marker"; fi
  fi
}

# rootless_host_undo <name>: takes out what rootless_host_setup <name> changed. The
# cgroups stay mounted until the next boot: a container may still use them.
rootless_host_undo() {
  local modules="/etc/modules-load.d/shellscript-$1.conf" marker="${SHELLSCRIPT_HOME}/$1/cgroups-service"
  [[ ! -f "$modules" ]] || run "${SUDO} rm -f \"${modules}\""
  if [[ -f "$marker" ]]; then
    run "${SUDO} rc-update del cgroups boot"
    [[ "$DRY_RUN" == "1" ]] || rm -f "$marker"
  fi
}

# The 'docker' command of the scripts that install another container engine (podman.sh,
# nerdctl.sh): a wrapper in $SHELLSCRIPT_BIN that runs it, for commands and scripts
# written for Docker.
DOCKER_WRAPPER="${SHELLSCRIPT_BIN}/docker"

# docker_command_check <label>
# A 'docker' that is not our own wrapper is the real one: never shadow it
docker_command_check() {
  local found
  while IFS= read -r found; do
    if [[ "$found" != "$DOCKER_WRAPPER" ]]; then
      err "Docker is already installed (${found}): not creating a 'docker' command for $1."
      err "Run again without --docker, or remove Docker first."
      exit 3
    fi
  done < <(type -aP docker 2>/dev/null || true)
}

# docker_command_write <label> <command>: the 'docker' command runs <command>
docker_command_write() {
  run "mkdir -p \"${SHELLSCRIPT_BIN}\""
  if [[ "$DRY_RUN" == "1" ]]; then
    log "[dry-run] Writing ${DOCKER_WRAPPER}"
  else
    printf '#!/usr/bin/env bash\nexec %q "$@"\n' "$2" >"$DOCKER_WRAPPER"
    chmod +x "$DOCKER_WRAPPER"
  fi
  log "The 'docker' command now runs $1."
}
