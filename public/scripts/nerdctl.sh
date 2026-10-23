#!/usr/bin/env bash
# nerdctl.sh: Install nerdctl with containerd and BuildKit, rootless by default

set -euo pipefail

print_usage() {
  cat <<'USAGE'
load.sh nerdctl -- [options]

Installs nerdctl, the Docker-compatible CLI of containerd, from its full bundle
(containerd, runc, BuildKit, RootlessKit and the CNI plugins), and enables the
containerd and BuildKit services.

By default it runs rootless: the bundle goes to $HOME/.shellscript/nerdctl/current and
the services are systemd user services of the current user. With --no-rootless it goes
to /opt/nerdctl, the services are system services and 'nerdctl' runs through sudo.

Rootless mode needs newuidmap (installed when missing), subordinate ids for the user
and a systemd user session. Uses sudo to install the missing packages (uidmap, iptables)
and, where AppArmor restricts user namespaces (Ubuntu 23.10 and later), to add a profile
that lets RootlessKit create them.

Options:
  -h, --help           Show this help and exit
  --version <version>  Version to install (default: latest), e.g. 2.4.0
  --force              Re-download even if already installed
  --no-rootless        Install system-wide and run the services as root (uses sudo)
  --no-services        Install the commands only: no containerd and BuildKit services
                       (for a machine without systemd)
  --docker             Also create a 'docker' command that runs nerdctl
                       (refused when Docker is installed)
  --dry-run            Print actions without executing them
  --manifest           Print installation manifest and exit

Examples:
  load.sh nerdctl
  load.sh nerdctl -- --docker
  load.sh nerdctl -- --no-rootless
  load.sh nerdctl -- --version 2.4.0
  load.sh remove -- nerdctl
USAGE
}

print_manifest() {
  cat <<'MANIFEST'
BIN_FILES=nerdctl docker
FOLDERS=$HOME/.shellscript/nerdctl
SHELLRC_FILE=
UNINSTALL_CMD=uninstall
MANIFEST
}

# Code shared with the other scripts that install distro packages.
# load.sh downloads it with this script, from the name in the line below; a loader
# older than that leaves it missing.
SHARED_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/system-packages.sh"
if [[ ! -f "$SHARED_LIB" ]]; then
  echo "Error: lib/system-packages.sh, which this script needs, is missing: run 'load.sh --update'" >&2
  exit 3
fi
# shellcheck source=lib/system-packages.sh
source "$SHARED_LIB"

# Parse flags
DRY_RUN=0
NERDCTL_VERSION=""
FORCE=0
ROOTLESS=1
SERVICES=1
DOCKER_ALIAS=0
UNINSTALL=0
while [[ ${1-} ]]; do
  case "$1" in
    -h|--help) print_usage; exit 0 ;;
    --manifest) print_manifest; exit 0 ;;
    --dry-run) DRY_RUN=1 ;;
    --force) FORCE=1 ;;
    --no-rootless) ROOTLESS=0 ;;
    --no-services) SERVICES=0 ;;
    --docker) DOCKER_ALIAS=1 ;;
    --version)
      shift || { err "--version requires a value"; exit 2; }
      NERDCTL_VERSION="${1#v}"
      ;;
    uninstall) UNINSTALL=1 ;;
    *) err "Unknown option: $1"; print_usage; exit 2 ;;
  esac
  shift || true
done

# Configuration
NERDCTL_HOME="${SHELLSCRIPT_HOME}/nerdctl"
PACKAGES_STATE="${NERDCTL_HOME}/installed-packages.conf"
STAMP_FILE="${NERDCTL_HOME}/installed-stamp"
ROOTLESS_DIR="${NERDCTL_HOME}/current"
ROOTFUL_DIR="/opt/nerdctl"
USER_UNITS="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
SYSTEM_UNITS="/etc/systemd/system"
UNITS="containerd.service buildkit.service"
# Written in the system units this script installs: only those are taken out
UNIT_MARKER="# Installed by shellscript.download nerdctl.sh"
# Ubuntu lets only the programs AppArmor allows create user namespaces: RootlessKit gets
# a profile of its own, named after its path, as RootlessKit itself suggests
APPARMOR_PROFILE="/etc/apparmor.d/$(printf '%s' "${ROOTLESS_DIR#/}/bin/rootlesskit" | tr / .)"

# Internal hook, not part of the user interface: executed by 'load.sh remove -- nerdctl'
# through the UNINSTALL_CMD manifest key. Each mode is removed when this script set it up.
if [[ "$UNINSTALL" == "1" ]]; then
  if grep -qs "${ROOTLESS_DIR}/bin" "${USER_UNITS}/containerd.service"; then
    log "Removing the rootless containerd and BuildKit services"
    run "PATH=\"${ROOTLESS_DIR}/bin:\$PATH\" containerd-rootless-setuptool.sh uninstall"
    # buildkitd ends with an error when it is stopped: systemd would list it as failed
    run "systemctl --user reset-failed ${UNITS} 2>/dev/null || true"
  fi
  if [[ -f "$APPARMOR_PROFILE" ]]; then
    log "Removing the AppArmor profile of RootlessKit: ${APPARMOR_PROFILE}"
    run "${SUDO} apparmor_parser -R \"${APPARMOR_PROFILE}\" || true"
    run "${SUDO} rm -f \"${APPARMOR_PROFILE}\""
  fi
  if grep -qsx "$UNIT_MARKER" "${SYSTEM_UNITS}/containerd.service"; then
    log "Removing the containerd and BuildKit system services and ${ROOTFUL_DIR}"
    run "${SUDO} systemctl disable --now ${UNITS}"
    run "${SUDO} rm -f ${SYSTEM_UNITS}/containerd.service ${SYSTEM_UNITS}/buildkit.service"
    run "${SUDO} systemctl daemon-reload"
    # buildkitd ends with an error when it is stopped: systemd would list it as failed
    run "${SUDO} systemctl reset-failed ${UNITS} 2>/dev/null || true"
  fi
  [[ ! -d "$ROOTFUL_DIR" ]] || run "${SUDO} rm -rf \"${ROOTFUL_DIR}\""
  remove_recorded_packages "nerdctl" "$PACKAGES_STATE"
  exit 0
fi

# Preconditions
if [[ "${OSTYPE:-}" != linux* ]]; then
  err "This installer supports Linux only. Detected OSTYPE='${OSTYPE:-unknown}'."
  exit 1
fi
require_downloader
require_cmd tar

case "$(uname -m)" in
  x86_64|amd64)  NERDCTL_ARCH="amd64" ;;
  aarch64|arm64) NERDCTL_ARCH="arm64" ;;
  *) err "Unsupported architecture: $(uname -m) (supported: x86_64, aarch64)"; exit 1 ;;
esac

if [[ "$ROOTLESS" == "1" ]]; then
  if [[ "$(id -u)" == "0" ]]; then
    err "Rootless mode is for a regular user: run as one, or use --no-rootless."
    exit 1
  fi
  if [[ "$SERVICES" == "1" ]] && ! systemctl --user show-environment >/dev/null 2>&1; then
    err "Rootless mode needs a systemd user session (systemctl --user)."
    err "Log in again as this user (not with su or sudo), or use --no-services."
    exit 1
  fi
  INSTALL_DIR="$ROOTLESS_DIR"
  AS_OWNER=""
else
  if [[ "$SERVICES" == "1" && ! -d /run/systemd/system ]]; then
    err "The system services need systemd. Use --no-services to install the commands only."
    exit 1
  fi
  # Never take over the containerd of another install (the one of Docker)
  if [[ "$SERVICES" == "1" ]] && systemctl cat containerd.service >/dev/null 2>&1 \
      && ! grep -qsx "$UNIT_MARKER" "${SYSTEM_UNITS}/containerd.service"; then
    err "A containerd service is already installed: not replacing it."
    exit 3
  fi
  [[ -z "$SUDO" ]] || require_cmd sudo
  INSTALL_DIR="$ROOTFUL_DIR"
  AS_OWNER="${SUDO:+$SUDO }"
fi

[[ "$DOCKER_ALIAS" != "1" ]] || docker_command_check nerdctl

# Packages the containers need. A regular user may not have the sbin folders in PATH.
have_cmd() { PATH="${PATH}:/usr/sbin:/sbin" command -v "$1" >/dev/null 2>&1; }
PM=$(detect_pm) || PM=""
MISSING=""
have_cmd iptables || MISSING="iptables"
if [[ "$ROOTLESS" == "1" ]] && ! have_cmd newuidmap; then
  case "$PM" in
    apt-get) MISSING="${MISSING:+$MISSING }uidmap" ;;
    dnf)     MISSING="${MISSING:+$MISSING }shadow-utils" ;;
    apk)     MISSING="${MISSING:+$MISSING }shadow-uidmap" ;;
    *)       MISSING="${MISSING:+$MISSING }shadow" ;;
  esac
fi
if [[ -n "$MISSING" ]]; then
  if [[ -z "$PM" ]]; then
    err "No supported package manager found (apt, dnf, pacman, zypper, apk)."
    err "Install ${MISSING} manually and re-run your command."
    exit 3
  fi
  [[ -z "$SUDO" ]] || require_cmd sudo
  install_packages "$PM" "$MISSING" "$PACKAGES_STATE"
fi

# Latest version from GitHub if none given. A loader older than github_latest_tag
# does not have it: the GitHub API answers
if [[ -z "$NERDCTL_VERSION" ]]; then
  if declare -F github_latest_tag >/dev/null; then
    NERDCTL_VERSION=$(github_latest_tag containerd/nerdctl | sed 's/^v//')
  else
    NERDCTL_VERSION=$(fetch https://api.github.com/repos/containerd/nerdctl/releases/latest \
      | grep '"tag_name"' | sed 's/.*"tag_name": *"v\?\(.*\)".*/\1/')
  fi
  log "Latest nerdctl version: ${NERDCTL_VERSION}"
fi

ARCHIVE="nerdctl-full-${NERDCTL_VERSION}-linux-${NERDCTL_ARCH}.tar.gz"
DOWNLOAD_URL="https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VERSION}/${ARCHIVE}"

# The services restart only when they were there and the bundle changed
UNIT_DIR="$SYSTEM_UNITS"
[[ "$ROOTLESS" == "1" ]] && UNIT_DIR="$USER_UNITS"
RESTART=0

# A loader older than already_installed does not have it: it installs every time
if [[ "$FORCE" != "1" && -x "${INSTALL_DIR}/bin/nerdctl" ]] \
    && declare -F already_installed >/dev/null && already_installed "$DOWNLOAD_URL" "$STAMP_FILE"; then
  log "nerdctl ${NERDCTL_VERSION} is already installed. Skipping download (use --force to re-download)."
else
  # Close to 1 GB with the archive: on the home disk, since /tmp is often a small tmpfs
  mkdir -p "${SHELLSCRIPT_DOWNLOADS}"
  TEMP_DIR=$(mktemp -d "${SHELLSCRIPT_DOWNLOADS}/nerdctl.XXXXXX")
  trap 'rm -rf "$TEMP_DIR"' EXIT

  log "Installing nerdctl ${NERDCTL_VERSION} to ${INSTALL_DIR}"
  log "Downloading ${DOWNLOAD_URL}"
  run "download \"${DOWNLOAD_URL}\" \"${TEMP_DIR}/${ARCHIVE}\"" || {
    err "Could not download nerdctl ${NERDCTL_VERSION} for ${NERDCTL_ARCH}: check the version."
    exit 1
  }
  run "mkdir -p \"${TEMP_DIR}/nerdctl\""
  run "tar -xzf \"${TEMP_DIR}/${ARCHIVE}\" -C \"${TEMP_DIR}/nerdctl\""
  # A real folder, not a link to a versioned one: the services keep this path
  run "${AS_OWNER}mkdir -p \"$(dirname "$INSTALL_DIR")\""
  run "${AS_OWNER}rm -rf \"${INSTALL_DIR}\""
  run "${AS_OWNER}mv \"${TEMP_DIR}/nerdctl\" \"${INSTALL_DIR}\""
  [[ "$ROOTLESS" == "1" ]] || run "${AS_OWNER}chown -R root:root \"${INSTALL_DIR}\""

  if [[ "$DRY_RUN" != "1" ]] && declare -F record_installed >/dev/null; then
    record_installed "$DOWNLOAD_URL" "$STAMP_FILE"
  fi
  [[ ! -f "${UNIT_DIR}/containerd.service" ]] || RESTART=1
fi

# Backend services: containerd, and BuildKit for 'nerdctl build'
if [[ "$SERVICES" == "1" && "$ROOTLESS" == "1" ]]; then
  if [[ "$(cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns 2>/dev/null)" == "1" \
      && ! -f "$APPARMOR_PROFILE" ]]; then
    log "Allowing RootlessKit to create user namespaces: ${APPARMOR_PROFILE}"
    if [[ "$DRY_RUN" == "1" ]]; then
      log "[dry-run] Writing ${APPARMOR_PROFILE}"
    else
      require_cmd sudo
      sudo tee "$APPARMOR_PROFILE" >/dev/null <<PROFILE
abi <abi/4.0>,
include <tunables/global>

${INSTALL_DIR}/bin/rootlesskit flags=(unconfined) {
  userns,
}
PROFILE
    fi
    run "sudo apparmor_parser -r \"${APPARMOR_PROFILE}\""
  fi

  # The setup tool of the bundle writes the user services, starts and enables them, and
  # leaves alone the ones already there
  SETUPTOOL="PATH=\"${INSTALL_DIR}/bin:\$PATH\" containerd-rootless-setuptool.sh"
  run "${SETUPTOOL} install"
  run "${SETUPTOOL} install-buildkit"
  # BuildKit runs in the namespace of containerd: it restarts after it
  if [[ "$RESTART" == "1" ]]; then
    run "systemctl --user restart containerd.service"
    run "systemctl --user restart buildkit.service"
  fi
elif [[ "$SERVICES" == "1" ]]; then
  for unit in $UNITS; do
    log "Writing ${SYSTEM_UNITS}/${unit}"
    run "{ echo '${UNIT_MARKER}'; sed -e 's|/usr/local/bin/|${INSTALL_DIR}/bin/|' \
      -e 's|^\[Service\]\$|[Service]\nEnvironment=PATH=${INSTALL_DIR}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin|' \
      \"${INSTALL_DIR}/lib/systemd/system/${unit}\"; } | ${SUDO} tee \"${SYSTEM_UNITS}/${unit}\" >/dev/null"
  done
  run "${SUDO} systemctl daemon-reload"
  run "${SUDO} systemctl enable --now ${UNITS}"
  [[ "$RESTART" != "1" ]] || run "${SUDO} systemctl restart ${UNITS}"
fi

# The 'nerdctl' command: finds buildctl (for 'nerdctl build') and the CNI plugins of the
# bundle. System-wide, it runs as root with a PATH of the system only.
if [[ "$ROOTLESS" == "1" ]]; then
  WRAPPER_PATH="${INSTALL_DIR}/bin:\$PATH"
else
  WRAPPER_PATH="${INSTALL_DIR}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
fi
run "mkdir -p \"${SHELLSCRIPT_BIN}\""
if [[ "$DRY_RUN" == "1" ]]; then
  log "[dry-run] Writing ${SHELLSCRIPT_BIN}/nerdctl"
else
  # Unquoted heredoc: the path is written now, not looked up through $HOME at run time
  cat >"${SHELLSCRIPT_BIN}/nerdctl" <<WRAP
#!/usr/bin/env bash
exec ${AS_OWNER}env PATH="${WRAPPER_PATH}" CNI_PATH="${INSTALL_DIR}/libexec/cni" "${INSTALL_DIR}/bin/nerdctl" "\$@"
WRAP
  chmod +x "${SHELLSCRIPT_BIN}/nerdctl"
fi

[[ "$DOCKER_ALIAS" != "1" ]] || docker_command_write nerdctl "${SHELLSCRIPT_BIN}/nerdctl"

if [[ "$ROOTLESS" == "1" ]]; then
  # Rootless containers need a range of subordinate ids for the user
  if ! grep -q "^$(id -un):" /etc/subuid 2>/dev/null; then
    log "Rootless containerd needs subordinate ids for your user. If containers fail to start, run:"
    log "  echo \"$(id -un):100000:65536\" | sudo tee -a /etc/subuid /etc/subgid && systemctl --user restart containerd.service"
  fi
  if [[ "$SERVICES" == "1" ]]; then
    log "To start the services at boot, without logging in: sudo loginctl enable-linger $(id -un)"
  fi
fi

log "Done. Try: nerdctl run --rm hello-world"
