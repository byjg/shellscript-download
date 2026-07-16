#!/usr/bin/env bash
# qemu.sh: Download QEMU and manage local virtual machines (start, list, stop, remove)

set -euo pipefail

print_usage() {
  cat <<'USAGE'
load.sh qemu -- <command> [options]

Manages local QEMU/KVM virtual machines. QEMU and its requirements are
installed automatically whenever something is missing, via the system
package manager (uses sudo). Base images are cached under
$HOME/.shellscript/qemu/images and each VM lives in
$HOME/.shellscript/qemu/vms/<name> with its own copy-on-write disk.
Also installs a 'qemu-vm' launcher, so 'qemu-vm <command>' works directly.
Uninstall everything with: load.sh remove -- qemu

Commands:
  start                 Create and boot a VM, or boot an existing stopped VM by name
  list                  List VMs and their state
  images                Show image alias patterns and cached base images
  stop <name>           Gracefully stop a running VM (ACPI powerdown)
  remove <name>         Remove a VM and its disk

Options:
  -h, --help            Show this help and exit
  --manifest            Print installation manifest and exit
  --dry-run             Print actions without executing them
  --image <src>         start: image alias, URL, or local path (qcow2/raw/iso)
                        Alias patterns: ubuntu-<ver>, debian-<ver>, alpine-<ver>,
                        fedora-<ver>, rocky-<ver> — see the 'images' command
  --arch <arch>         start: guest CPU architecture, x86_64 or aarch64 (default:
                        host arch; a foreign arch uses slow software emulation)
  --name <name>         start: VM name (default: derived from the image)
  --memory <size>       start: RAM, e.g. 2048 or 2G (default: 2G)
  --disk <size>         start: disk size, e.g. 10G (default: 10G)
  --cpus <n>            start: number of virtual CPUs (default: 2)
  --ssh-port <port>     start: host port forwarded to guest port 22 (default: first free port from 2222)
  --port <host:guest>   start: extra port forward, can be repeated
  --no-cloud-init       start: skip the cloud-init seed (default user/SSH key injection)
  --force               stop: kill immediately; remove: remove even if running
  --purge-image         remove: also delete the cached base image if unused

Files and customization:
  $HOME/.shellscript/qemu/images/        Downloaded base images. Shared read-only backing
                                         files — do not delete one while a VM still uses it
                                         ('remove --purge-image' checks this for you).
  $HOME/.shellscript/qemu/vms/<name>/    One folder per VM:
    vm.conf      Memory, CPUs, SSH/extra ports, image reference. Edit while the
                 VM is stopped; values apply on the next 'start <name>'.
    disk.qcow2   The VM's private copy-on-write disk, backed by the base image.
    user-data    cloud-init config (default user, password, SSH keys). Applied on
                 the VM's FIRST boot only — to customize it, create the VM, stop
                 it, edit user-data, regenerate seed.iso (genisoimage -output
                 seed.iso -volid cidata -joliet -rock user-data meta-data) and
                 change instance-id in meta-data so cloud-init runs again.
    seed.iso     The generated cloud-init seed attached as a CD-ROM.

Examples:
  load.sh qemu -- start --image ubuntu-24.04 --name dev1 --memory 2G --disk 10G
  load.sh qemu -- start --image https://example.com/disk.qcow2 --ssh-port 2222
  load.sh qemu -- start --image debian-12 --arch aarch64
  load.sh qemu -- start --name dev1
  load.sh qemu -- list
  load.sh qemu -- images
  load.sh qemu -- stop dev1
  load.sh qemu -- remove dev1 --purge-image
  load.sh remove -- qemu
  qemu-vm start --image alpine-3.22
USAGE
}

print_manifest() {
  cat <<'MANIFEST'
BIN_FILES=qemu-vm
FOLDERS=$HOME/.shellscript/qemu
SHELLRC_FILE=
UNINSTALL_CMD=uninstall
MANIFEST
}

# Parse command and flags
COMMAND=""
VM_ARG=""
IMAGE=""
ARCH_OPT=""
NAME=""
MEMORY="2G"
DISK="10G"
CPUS="2"
SSH_PORT=""
EXTRA_PORTS=()
CLOUD_INIT=1
FORCE=0
PURGE_IMAGE=0
DRY_RUN=0

while [[ ${1-} ]]; do
  case "$1" in
    -h|--help)       print_usage; exit 0 ;;
    --manifest)      print_manifest; exit 0 ;;
    --dry-run)       DRY_RUN=1 ;;
    --image)         shift || { err "--image requires a value"; exit 2; }; IMAGE="$1" ;;
    --arch)          shift || { err "--arch requires a value"; exit 2; }; ARCH_OPT="$1" ;;
    --name)          shift || { err "--name requires a value"; exit 2; }; NAME="$1" ;;
    --memory)        shift || { err "--memory requires a value"; exit 2; }; MEMORY="$1" ;;
    --disk)          shift || { err "--disk requires a value"; exit 2; }; DISK="$1" ;;
    --cpus)          shift || { err "--cpus requires a value"; exit 2; }; CPUS="$1" ;;
    --ssh-port)      shift || { err "--ssh-port requires a value"; exit 2; }; SSH_PORT="$1" ;;
    --port)          shift || { err "--port requires a value"; exit 2; }; EXTRA_PORTS+=("$1") ;;
    --no-cloud-init) CLOUD_INIT=0 ;;
    --force)         FORCE=1 ;;
    --purge-image)   PURGE_IMAGE=1 ;;
    -*)              err "Unknown option: $1"; print_usage >&2; exit 2 ;;
    *)
      if [[ -z "$COMMAND" ]]; then COMMAND="$1"
      elif [[ -z "$VM_ARG" ]]; then VM_ARG="$1"
      else err "Unexpected argument: $1"; exit 2
      fi
      ;;
  esac
  shift || true
done


# Host CPU architecture
case "$(uname -m)" in
  x86_64|amd64)  HOST_ARCH="x86_64" ;;
  aarch64|arm64) HOST_ARCH="aarch64" ;;
  *) err "Unsupported architecture: $(uname -m) (supported: x86_64, aarch64)"; exit 1 ;;
esac

# Guest architecture: host-native by default; --arch enables cross-arch emulation
case "${ARCH_OPT}" in
  "")                   QEMU_ARCH="$HOST_ARCH" ;;
  x86_64|x86|amd64)     QEMU_ARCH="x86_64" ;;
  aarch64|arm64|arm)    QEMU_ARCH="aarch64" ;;
  *) err "Unsupported --arch: ${ARCH_OPT} (supported: x86_64, aarch64)"; exit 2 ;;
esac
QEMU_BIN="qemu-system-${QEMU_ARCH}"

QEMU_HOME="${SHELLSCRIPT_HOME}/qemu"
IMAGES_DIR="${QEMU_HOME}/images"
VMS_DIR="${QEMU_HOME}/vms"
DEFAULT_VM_USER="shellscript"

# ---------- helpers ----------

vm_dir() { printf '%s/%s' "$VMS_DIR" "$1"; }

vm_pid() {
  local pidfile
  pidfile="$(vm_dir "$1")/qemu.pid"
  [[ -f "$pidfile" ]] && cat "$pidfile" 2>/dev/null || true
}

is_running() {
  local pid
  pid=$(vm_pid "$1")
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

require_vm_name() {
  if [[ -z "$VM_ARG" ]]; then err "VM name is required: load.sh qemu -- ${COMMAND} <name>"; exit 2; fi
  if [[ ! -d "$(vm_dir "$VM_ARG")" ]]; then err "VM '${VM_ARG}' not found. Run: load.sh qemu -- list"; exit 3; fi
}

port_free() { ! { exec 3<>"/dev/tcp/127.0.0.1/$1"; } 2>/dev/null || { exec 3>&-; return 1; }; }

# Ports recorded in any VM's vm.conf (SSH, monitor, extra forwards) — reserved even
# while that VM is stopped, so a stopped VM can always be started again later
reserved_ports() {
  local conf
  for conf in "$VMS_DIR"/*/vm.conf; do
    [[ -f "$conf" ]] || continue
    (
      # shellcheck disable=SC1090
      source "$conf" 2>/dev/null || exit 0
      printf '%s\n' "${VM_SSH_PORT:-}" "${VM_MONITOR_PORT:-}"
      local p
      for p in ${VM_PORTS:-}; do printf '%s\n' "${p%%:*}"; done
    )
  done | grep -v '^$' || true
}

port_reserved() { reserved_ports | grep -qx "$1"; }

# Free means: not reserved by any VM's configuration AND not in use by the OS
find_free_port() {
  local port="$1"
  while port_reserved "$port" || ! port_free "$port"; do port=$((port + 1)); done
  printf '%s' "$port"
}

detect_pm() {
  local pm
  for pm in apt-get dnf pacman zypper apk; do
    command -v "$pm" >/dev/null 2>&1 && { printf '%s' "$pm"; return 0; }
  done
  return 1
}

missing_packages() {
  # Check each required component and print the distro package names of the missing ones
  local pm="$1" qemu_pkg img_pkg iso_pkg fw_pkg
  case "$pm" in
    apt-get)
      qemu_pkg="qemu-system-x86"; [[ "$QEMU_ARCH" == "aarch64" ]] && qemu_pkg="qemu-system-arm"
      img_pkg="qemu-utils"; iso_pkg="genisoimage"; fw_pkg="qemu-efi-aarch64" ;;
    dnf)
      qemu_pkg="qemu-system-x86"; [[ "$QEMU_ARCH" == "aarch64" ]] && qemu_pkg="qemu-system-aarch64"
      img_pkg="qemu-img"; iso_pkg="genisoimage"; fw_pkg="edk2-aarch64" ;;
    pacman)
      qemu_pkg="qemu-system-x86"; [[ "$QEMU_ARCH" == "aarch64" ]] && qemu_pkg="qemu-system-aarch64"
      img_pkg="qemu-img"; iso_pkg="libisoburn"; fw_pkg="edk2-armvirt" ;;
    zypper)
      qemu_pkg="qemu-x86"; [[ "$QEMU_ARCH" == "aarch64" ]] && qemu_pkg="qemu-arm"
      img_pkg="qemu-tools"; iso_pkg="mkisofs"; fw_pkg="qemu-uefi-aarch64" ;;
    apk)
      qemu_pkg="qemu-system-${QEMU_ARCH}"; img_pkg="qemu-img"; iso_pkg="cdrkit"; fw_pkg="qemu-efi" ;;
  esac

  local missing=""
  command -v "$QEMU_BIN" >/dev/null 2>&1 || missing+=" $qemu_pkg"
  command -v qemu-img >/dev/null 2>&1 || missing+=" $img_pkg"
  iso_tool >/dev/null || missing+=" $iso_pkg"
  if [[ "$QEMU_ARCH" == "aarch64" ]] && ! aarch64_firmware >/dev/null; then missing+=" $fw_pkg"; fi
  printf '%s' "${missing# }"
}

# Installs whatever is missing (packages, folders, launcher). Idempotent and
# unconditional: every entry point that needs QEMU calls this first.
ensure_qemu() {
  require_downloader
  local pm
  pm=$(detect_pm) || {
    err "No supported package manager found (apt, dnf, pacman, zypper, apk)."
    err "Install QEMU manually and re-run your command."
    exit 3
  }

  local missing
  missing=$(missing_packages "$pm")
  if [[ -n "$missing" ]]; then
    local sudo_cmd="sudo"
    [[ "$(id -u)" == "0" ]] && sudo_cmd=""
    log "Installing missing packages: ${missing}"
    case "$pm" in
      apt-get) run "${sudo_cmd} apt-get update && ${sudo_cmd} apt-get install -y ${missing}" ;;
      dnf)     run "${sudo_cmd} dnf install -y ${missing}" ;;
      pacman)  run "${sudo_cmd} pacman -S --noconfirm --needed ${missing}" ;;
      zypper)  run "${sudo_cmd} zypper install -y ${missing}" ;;
      apk)     run "${sudo_cmd} apk add ${missing}" ;;
    esac
    # Record what this script installed so 'load.sh remove -- qemu' only uninstalls those
    if [[ "$DRY_RUN" != "1" ]]; then
      mkdir -p "$QEMU_HOME"
      printf '%s\n' ${missing} >> "${QEMU_HOME}/installed-packages.conf"
      sort -u -o "${QEMU_HOME}/installed-packages.conf" "${QEMU_HOME}/installed-packages.conf"
    fi
  fi

  run "mkdir -p \"${IMAGES_DIR}\" \"${VMS_DIR}\""
  ensure_wrapper
}

iso_tool() {
  local t
  for t in genisoimage mkisofs xorriso; do
    if command -v "$t" >/dev/null 2>&1; then printf '%s' "$t"; return 0; fi
  done
  return 1
}

aarch64_firmware() {
  local fw
  for fw in \
    /usr/share/qemu/edk2-aarch64-code.fd \
    /usr/share/qemu-efi-aarch64/QEMU_EFI.fd \
    /usr/share/AAVMF/AAVMF_CODE.fd \
    /usr/share/edk2/aarch64/QEMU_EFI.fd \
    /usr/share/edk2/aarch64/QEMU_EFI.silent.fd; do
    if [[ -f "$fw" ]]; then printf '%s' "$fw"; return 0; fi
  done
  return 1
}

resolve_alpine_url() {
  # Alpine cloud image file names are versioned; resolve the newest from the CDN listing
  local minor="$1" flavor="bios"
  [[ "$QEMU_ARCH" == "aarch64" ]] && flavor="uefi"
  local base="https://dl-cdn.alpinelinux.org/alpine/v${minor}/releases/cloud"
  local file
  file=$(fetch "${base}/" | grep -oE "nocloud_alpine-${minor}\.[0-9]+-${QEMU_ARCH}-${flavor}-cloudinit-r[0-9]+\.qcow2" | sort -uV | tail -1)
  [[ -n "$file" ]] || return 1
  printf '%s/%s' "$base" "$file"
}

resolve_fedora_url() {
  # Fedora cloud image file names are versioned; resolve the newest from the primary
  # server listing, falling back to the archive server for EOL releases
  local ver="$1" base file
  for base in \
    "https://dl.fedoraproject.org/pub/fedora/linux/releases/${ver}/Cloud/${QEMU_ARCH}/images" \
    "https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/${ver}/Cloud/${QEMU_ARCH}/images"; do
    file=$(fetch "${base}/" 2>/dev/null | grep -oE 'Fedora-Cloud-Base-Generic[^"]*\.qcow2' | sort -uV | tail -1)
    if [[ -n "$file" ]]; then
      printf '%s/%s' "$base" "$file"
      return 0
    fi
  done
  return 1
}

# Download a base image safely: write to a .part file so an interrupted or failed
# transfer is never mistaken for a valid cached image, and retry transient failures.
download_image() {
  local url="$1" dest="$2" attempt
  if [[ "$DRY_RUN" == "1" ]]; then
    run "download \"${url}\" \"${dest}\""
    return 0
  fi
  for attempt in 1 2 3; do
    [[ "$attempt" -gt 1 ]] && log "Retrying download (attempt ${attempt}/3)..."
    if download "$url" "${dest}.part"; then
      mv "${dest}.part" "$dest"
      return 0
    fi
  done
  rm -f "${dest}.part"
  err "Failed to download after 3 attempts: ${url}"
  exit 3
}

resolve_image() {
  # '<distro>-<version>' alias pattern -> official cloud image URL; URL/path passed through
  local ver codename deb_arch="amd64"
  [[ "$QEMU_ARCH" == "aarch64" ]] && deb_arch="arm64"
  case "$1" in
    ubuntu-*)
      ver="${1#ubuntu-}"
      printf 'https://cloud-images.ubuntu.com/releases/%s/release/ubuntu-%s-server-cloudimg-%s.img' "$ver" "$ver" "$deb_arch" ;;
    debian-*)
      ver="${1#debian-}"
      case "$ver" in
        11) codename="bullseye" ;;
        12) codename="bookworm" ;;
        13) codename="trixie" ;;
        *) err "Unknown Debian version: ${ver} (known: 11, 12, 13)"; exit 2 ;;
      esac
      printf 'https://cloud.debian.org/images/cloud/%s/latest/debian-%s-genericcloud-%s.qcow2' "$codename" "$ver" "$deb_arch" ;;
    alpine-*)
      ver="${1#alpine-}"
      resolve_alpine_url "$ver" || { err "Could not resolve the latest alpine-${ver} cloud image"; exit 3; } ;;
    fedora-*)
      ver="${1#fedora-}"
      resolve_fedora_url "$ver" || { err "Could not resolve the latest fedora-${ver} cloud image"; exit 3; } ;;
    rocky-*)
      ver="${1#rocky-}"
      printf 'https://dl.rockylinux.org/pub/rocky/%s/images/%s/Rocky-%s-GenericCloud-Base.latest.%s.qcow2' "$ver" "$QEMU_ARCH" "$ver" "$QEMU_ARCH" ;;
    http://*|https://*|/*|./*|../*)
      printf '%s' "$1" ;;
    *)
      err "Unknown image alias or path: $1"
      err "Alias patterns: ubuntu-<version>, debian-<version>, alpine-<version>, fedora-<version>, rocky-<version>"
      err "Run 'load.sh qemu -- images' to see them, or pass a URL / local file."
      exit 2 ;;
  esac
}

ensure_wrapper() {
  if [[ "$DRY_RUN" == "1" ]]; then
    log "[dry-run] Writing ${SHELLSCRIPT_BIN}/qemu-vm"
    return
  fi
  mkdir -p "${SHELLSCRIPT_BIN}"
  cat >"${SHELLSCRIPT_BIN}/qemu-vm" <<'WRAP'
#!/usr/bin/env bash
exec "${HOME}/.shellscript/bin/load.sh" qemu -- "$@"
WRAP
  chmod +x "${SHELLSCRIPT_BIN}/qemu-vm"
}

make_seed() {
  # cloud-init NoCloud seed ISO: default user + host SSH public keys
  local dir="$1" name="$2" tool
  tool=$(iso_tool) || { err "No ISO tool found (genisoimage, mkisofs or xorriso) — required for cloud-init. Use --no-cloud-init to skip."; exit 3; }

  local keys=""
  local pub
  for pub in "$HOME"/.ssh/id_*.pub; do
    [[ -f "$pub" ]] && keys+="      - $(cat "$pub")"$'\n'
  done

  local keys_block=""
  if [[ -n "$keys" ]]; then
    keys_block="    ssh_authorized_keys:
${keys}"
  fi

  cat > "${dir}/user-data" <<CFG
#cloud-config
hostname: ${name}
ssh_pwauth: true
users:
  - name: ${DEFAULT_VM_USER}
    shell: /bin/sh
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false
${keys_block}chpasswd:
  expire: false
  users:
    - name: ${DEFAULT_VM_USER}
      password: ${DEFAULT_VM_USER}
      type: text
CFG

  printf 'instance-id: %s\nlocal-hostname: %s\n' "$name" "$name" > "${dir}/meta-data"

  case "$tool" in
    xorriso) (cd "$dir" && xorriso -as mkisofs -output seed.iso -volid cidata -joliet -rock user-data meta-data >/dev/null 2>&1) ;;
    *)       (cd "$dir" && "$tool" -output seed.iso -volid cidata -joliet -rock user-data meta-data >/dev/null 2>&1) ;;
  esac
}

# ---------- commands ----------

# Bare 'load.sh qemu' — install everything, report readiness
cmd_setup() {
  ensure_qemu

  if [[ -e /dev/kvm && ! -w /dev/kvm ]]; then
    log "Note: /dev/kvm exists but is not writable by you."
    log "For hardware acceleration run: sudo usermod -aG kvm \$USER  (then re-login)"
  elif [[ ! -e /dev/kvm ]]; then
    log "Note: /dev/kvm not found — VMs will use software emulation (slow)."
  fi

  log "QEMU is ready. Try: qemu-vm start --image alpine-3.22"
}

# Internal hook, not part of the user interface: executed by 'load.sh remove -- qemu'
# through the UNINSTALL_CMD manifest key.
cmd_uninstall() {
  # Stop any running VMs first
  local dir name
  for dir in "$VMS_DIR"/*/; do
    [[ -d "$dir" ]] || continue
    name=$(basename "$dir")
    if is_running "$name"; then
      log "Stopping running VM: ${name}"
      VM_ARG="$name" FORCE=1 cmd_stop
    fi
  done

  local state="${QEMU_HOME}/installed-packages.conf"
  if [[ ! -s "$state" ]]; then
    log "QEMU was not installed by this script — leaving system packages untouched."
    return
  fi

  local pm pkgs sudo_cmd="sudo"
  pm=$(detect_pm) || { err "No supported package manager found."; exit 3; }
  pkgs=$(tr '\n' ' ' < "$state")
  [[ "$(id -u)" == "0" ]] && sudo_cmd=""
  log "Removing packages installed by this script: ${pkgs}"
  case "$pm" in
    apt-get) run "${sudo_cmd} apt-get remove -y ${pkgs}" ;;
    dnf)     run "${sudo_cmd} dnf remove -y ${pkgs}" ;;
    pacman)  run "${sudo_cmd} pacman -Rns --noconfirm ${pkgs}" ;;
    zypper)  run "${sudo_cmd} zypper remove -y ${pkgs}" ;;
    apk)     run "${sudo_cmd} apk del ${pkgs}" ;;
  esac
  [[ "$DRY_RUN" == "1" ]] || rm -f "$state"
}

boot_vm() {
  local name="$1" dir conf
  dir=$(vm_dir "$name")
  conf="${dir}/vm.conf"
  # shellcheck disable=SC1090
  source "$conf"
  local vm_arch="${VM_ARCH:-$HOST_ARCH}"
  local qemu_bin="qemu-system-${vm_arch}"

  local accel_args="-cpu max"
  if [[ "$vm_arch" == "$HOST_ARCH" && -w /dev/kvm ]]; then
    accel_args="-enable-kvm -cpu host"
  elif [[ "$vm_arch" != "$HOST_ARCH" ]]; then
    log "Cross-architecture VM (${vm_arch} guest on ${HOST_ARCH} host) — software emulation, expect it to be slow."
  else
    log "Warning: /dev/kvm not accessible — using software emulation (slow)."
  fi

  local machine_args="-machine q35"
  local bios_args=""
  if [[ "$vm_arch" == "aarch64" ]]; then
    machine_args="-machine virt"
    local fw
    fw=$(aarch64_firmware) || { err "No aarch64 UEFI firmware found. Run: load.sh qemu"; exit 3; }
    bios_args="-bios \"$fw\""
  fi

  # The VM's own forwarded ports must be free on the host before booting
  local p
  for p in "$VM_SSH_PORT" ${VM_PORTS:-}; do
    p="${p%%:*}"
    if ! port_free "$p"; then
      err "Port ${p} needed by VM '${name}' is in use on this host."
      err "Stop whatever is using it, or edit ${conf} to pick another port."
      exit 3
    fi
  done

  # The monitor port is internal — if something took it, silently pick a new one
  if ! port_free "$VM_MONITOR_PORT"; then
    VM_MONITOR_PORT=$(find_free_port 45000)
    sed -i "s/^VM_MONITOR_PORT=.*/VM_MONITOR_PORT=\"${VM_MONITOR_PORT}\"/" "$conf"
    log "Monitor port was in use — moved to ${VM_MONITOR_PORT}."
  fi

  local net="user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:${VM_SSH_PORT}-:22"
  for p in ${VM_PORTS:-}; do
    net+=",hostfwd=tcp:127.0.0.1:${p%%:*}-:${p##*:}"
  done

  local drive_args="-drive file=\"${dir}/disk.qcow2\",if=virtio"
  local cdrom_args=""
  [[ -n "${VM_CDROM:-}" ]] && cdrom_args="-cdrom \"${VM_CDROM}\""
  [[ -f "${dir}/seed.iso" ]] && cdrom_args+=" -drive file=\"${dir}/seed.iso\",media=cdrom"

  run "${qemu_bin} ${accel_args} ${machine_args} ${bios_args} \
    -name \"${name}\" -m \"${VM_MEMORY}\" -smp \"${VM_CPUS}\" \
    ${drive_args} ${cdrom_args} \
    -nic \"${net}\" \
    -display none -daemonize \
    -pidfile \"${dir}/qemu.pid\" \
    -monitor telnet:127.0.0.1:${VM_MONITOR_PORT},server,nowait"

  log "VM '${name}' started."
  log "  SSH:  ssh -p ${VM_SSH_PORT} ${DEFAULT_VM_USER}@localhost   (password: ${DEFAULT_VM_USER})"
  log "  Stop: load.sh qemu -- stop ${name}"
}

cmd_start() {
  local name="${NAME:-$VM_ARG}"

  # Boot an existing stopped VM by name
  if [[ -n "$name" && -d "$(vm_dir "$name")" ]]; then
    if is_running "$name"; then err "VM '${name}' is already running."; exit 3; fi
    if [[ -n "$IMAGE" ]]; then err "VM '${name}' already exists — start it without --image, or remove it first."; exit 2; fi
    # Ensure the emulator for this VM's stored architecture, not the host's
    QEMU_ARCH=$( (source "$(vm_dir "$name")/vm.conf" >/dev/null 2>&1 && printf '%s' "${VM_ARCH:-$HOST_ARCH}") || printf '%s' "$HOST_ARCH" )
    QEMU_BIN="qemu-system-${QEMU_ARCH}"
    ensure_qemu
    boot_vm "$name"
    return
  fi

  ensure_qemu

  if [[ -z "$IMAGE" ]]; then
    err "--image is required to create a new VM (aliases: ubuntu-24.04, debian-12, alpine-3.22)"
    exit 2
  fi

  # Resolve and fetch the base image
  local src base
  src=$(resolve_image "$IMAGE")
  base=$(basename "$src")
  local image_path
  if [[ "$src" == http* ]]; then
    image_path="${IMAGES_DIR}/${base}"
    if [[ -f "$image_path" ]]; then
      log "Using cached image: ${image_path}"
    else
      log "Downloading ${src}"
      download_image "$src" "$image_path"
    fi
  else
    image_path=$(readlink -f "$src")
    [[ -f "$image_path" ]] || { err "Image not found: $src"; exit 3; }
  fi

  if [[ -z "$name" ]]; then
    if [[ "$src" != "$IMAGE" ]]; then
      name="$IMAGE"   # --image was an alias — use it as the VM name
    else
      name=$(basename "$base" | sed -E 's/\.(qcow2|img|iso|raw)$//' | tr -cd 'a-zA-Z0-9._-')
    fi
  fi
  [[ "$name" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]] || { err "Invalid VM name: ${name}"; exit 2; }

  local dir
  dir=$(vm_dir "$name")
  [[ -d "$dir" ]] && { err "VM '${name}' already exists."; exit 3; }

  # Explicitly requested ports must not collide with other VMs' configs or live listeners
  local p host_ports=()
  [[ -n "$SSH_PORT" ]] && host_ports+=("$SSH_PORT")
  for p in ${EXTRA_PORTS[@]+"${EXTRA_PORTS[@]}"}; do host_ports+=("${p%%:*}"); done
  for p in ${host_ports[@]+"${host_ports[@]}"}; do
    if port_reserved "$p"; then
      err "Port ${p} is already reserved by another VM (see: load.sh qemu -- list)"
      exit 3
    fi
    if ! port_free "$p"; then
      err "Port ${p} is already in use on this host."
      exit 3
    fi
  done

  local ssh_port="${SSH_PORT:-$(find_free_port 2222)}"
  local monitor_port
  monitor_port=$(find_free_port 45000)

  if [[ "$DRY_RUN" == "1" ]]; then
    log "[dry-run] Creating VM '${name}' (image: ${image_path}, memory: ${MEMORY}, disk: ${DISK}, cpus: ${CPUS}, ssh: ${ssh_port})"
    return
  fi

  mkdir -p "$dir"

  local cdrom=""
  if [[ "$image_path" == *.iso ]]; then
    qemu-img create -f qcow2 "${dir}/disk.qcow2" "$DISK" >/dev/null
    cdrom="$image_path"
  else
    qemu-img create -f qcow2 -b "$image_path" -F qcow2 "${dir}/disk.qcow2" "$DISK" >/dev/null
  fi

  if [[ "$CLOUD_INIT" == "1" && -z "$cdrom" ]]; then
    make_seed "$dir" "$name"
  fi

  cat >"${dir}/vm.conf" <<CONF
VM_IMAGE="${image_path}"
VM_ARCH="${QEMU_ARCH}"
VM_MEMORY="${MEMORY}"
VM_CPUS="${CPUS}"
VM_SSH_PORT="${ssh_port}"
VM_MONITOR_PORT="${monitor_port}"
VM_PORTS="${EXTRA_PORTS[*]:-}"
VM_CDROM="${cdrom}"
CONF

  boot_vm "$name"
}

cmd_images() {
  cat <<PATTERNS
Image alias patterns (resolved to official cloud images for ${QEMU_ARCH}):
  ubuntu-<version>   Ubuntu cloud image     e.g. ubuntu-24.04, ubuntu-22.04
  debian-<version>   Debian generic cloud   e.g. debian-12, debian-13
  alpine-<version>   Alpine nocloud image   e.g. alpine-3.22, alpine-3.21
  fedora-<version>   Fedora Cloud Base      e.g. fedora-42
  rocky-<version>    Rocky GenericCloud     e.g. rocky-9, rocky-10

Any http(s) URL or local path to a qcow2/img/iso file also works.

PATTERNS
  printf 'Cached base images (%s):\n' "$IMAGES_DIR"
  if [[ -d "$IMAGES_DIR" ]] && [[ -n "$(ls -A "$IMAGES_DIR" 2>/dev/null)" ]]; then
    du -h "$IMAGES_DIR"/* 2>/dev/null | sed 's/^/  /'
  else
    printf '  (none)\n'
  fi
}

cmd_list() {
  printf '%-20s %-9s %-9s %-8s %-5s %-6s %s\n' "NAME" "STATE" "ARCH" "MEMORY" "CPUS" "SSH" "IMAGE"
  local dir name state
  for dir in "$VMS_DIR"/*/; do
    [[ -d "$dir" ]] || continue
    name=$(basename "$dir")
    state="stopped"
    is_running "$name" && state="running"
    (
      # shellcheck disable=SC1091
      source "${dir}/vm.conf" 2>/dev/null || true
      printf '%-20s %-9s %-9s %-8s %-5s %-6s %s\n' "$name" "$state" "${VM_ARCH:-$HOST_ARCH}" "${VM_MEMORY:-?}" "${VM_CPUS:-?}" "${VM_SSH_PORT:-?}" "$(basename "${VM_IMAGE:-?}")"
    )
  done
}

cmd_stop() {
  require_vm_name
  local name="$VM_ARG" dir pid
  dir=$(vm_dir "$name")
  if ! is_running "$name"; then log "VM '${name}' is not running."; return; fi
  pid=$(vm_pid "$name")

  if [[ "$DRY_RUN" == "1" ]]; then log "[dry-run] Stopping VM '${name}' (pid ${pid})"; return; fi

  if [[ "$FORCE" == "1" ]]; then
    kill -9 "$pid" 2>/dev/null || true
  else
    # Graceful ACPI powerdown via the QEMU monitor (loopback telnet, plain bash /dev/tcp)
    # shellcheck disable=SC1091
    source "${dir}/vm.conf"
    if { exec 3<>"/dev/tcp/127.0.0.1/${VM_MONITOR_PORT}"; } 2>/dev/null; then
      printf 'system_powerdown\n' >&3
      exec 3>&-
    fi
    local waited=0
    while kill -0 "$pid" 2>/dev/null && [[ "$waited" -lt 30 ]]; do
      sleep 1
      waited=$((waited + 1))
    done
    if kill -0 "$pid" 2>/dev/null; then
      log "VM did not power down gracefully, killing it."
      kill -9 "$pid" 2>/dev/null || true
    fi
  fi
  rm -f "${dir}/qemu.pid"
  log "VM '${name}' stopped."
}

cmd_remove() {
  require_vm_name
  local name="$VM_ARG" dir
  dir=$(vm_dir "$name")

  if is_running "$name"; then
    if [[ "$FORCE" == "1" ]]; then
      cmd_stop
    else
      err "VM '${name}' is running. Stop it first, or use --force."
      exit 3
    fi
  fi

  local image=""
  # shellcheck disable=SC1091
  image=$(source "${dir}/vm.conf" 2>/dev/null && printf '%s' "${VM_IMAGE:-}") || true

  run "rm -rf \"${dir}\""

  if [[ "$PURGE_IMAGE" == "1" && -n "$image" && "$image" == "${IMAGES_DIR}/"* ]]; then
    if grep -qs "VM_IMAGE=\"${image}\"" "$VMS_DIR"/*/vm.conf 2>/dev/null; then
      log "Base image still used by another VM, keeping: ${image}"
    else
      run "rm -f \"${image}\""
    fi
  fi
  log "VM '${name}' removed."
}

case "$COMMAND" in
  "")        cmd_setup ;;
  start)     cmd_start ;;
  list)      cmd_list ;;
  images)    cmd_images ;;
  stop)      cmd_stop ;;
  remove)    cmd_remove ;;
  uninstall) cmd_uninstall ;;
  *) err "Unknown command: ${COMMAND} (expected: start, list, images, stop, remove)"; exit 2 ;;
esac
