#!/usr/bin/env bash
# qemu.sh: Download QEMU and manage local virtual machines (start, list, stop, remove)

set -euo pipefail

print_usage() {
  cat <<'USAGE'
load.sh qemu -- [command] [options]

Installs QEMU (with its requirements, via the system package manager) and
manages local QEMU/KVM virtual machines. Base images are cached under
$HOME/.shellscript/qemu/images and each VM lives in
$HOME/.shellscript/qemu/vms/<name> with its own copy-on-write disk.
Also installs a 'qemu-vm' launcher, so 'qemu-vm <command>' works directly.

Commands:
  install               Install QEMU and requirements if anything is missing (the default command)
  uninstall             Remove the QEMU packages that this script installed (pre-existing ones are kept)
  start                 Create and boot a VM, or boot an existing stopped VM by name
                        (installs QEMU first when needed)
  list                  List VMs and their state
  stop <name>           Gracefully stop a running VM (ACPI powerdown)
  remove <name>         Remove a VM and its disk

Options:
  -h, --help            Show this help and exit
  --manifest            Print installation manifest and exit
  --dry-run             Print actions without executing them
  --image <src>         start: image alias, URL, or local path (qcow2/raw/iso)
                        Aliases: ubuntu-24.04, debian-12, alpine-3.22
  --name <name>         start: VM name (default: derived from the image)
  --memory <size>       start: RAM, e.g. 2048 or 2G (default: 2G)
  --disk <size>         start: disk size, e.g. 10G (default: 10G)
  --cpus <n>            start: number of virtual CPUs (default: 2)
  --ssh-port <port>     start: host port forwarded to guest port 22 (default: first free port from 2222)
  --port <host:guest>   start: extra port forward, can be repeated
  --no-cloud-init       start: skip the cloud-init seed (default user/SSH key injection)
  --force               stop: kill immediately; remove: remove even if running
  --purge-image         remove: also delete the cached base image if unused

Examples:
  load.sh qemu
  load.sh qemu -- start --image ubuntu-24.04 --name dev1 --memory 2G --disk 10G
  load.sh qemu -- start --image https://example.com/disk.qcow2 --ssh-port 2222
  load.sh qemu -- start --name dev1
  load.sh qemu -- list
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

# Like every other script in the catalog, running it with no command installs the tool
[[ -n "$COMMAND" ]] || COMMAND="install"

# Detect CPU architecture (VMs are host-native, no cross-arch emulation)
case "$(uname -m)" in
  x86_64|amd64)  QEMU_ARCH="x86_64" ;;
  aarch64|arm64) QEMU_ARCH="aarch64" ;;
  *) err "Unsupported architecture: $(uname -m) (supported: x86_64, aarch64)"; exit 1 ;;
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

find_free_port() {
  local port="$1"
  while ! port_free "$port"; do port=$((port + 1)); done
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

ensure_qemu() {
  if ! command -v "$QEMU_BIN" >/dev/null 2>&1 || ! command -v qemu-img >/dev/null 2>&1; then
    log "QEMU is not installed yet — installing it first."
    cmd_install
  fi
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

resolve_image() {
  # alias -> URL; URL/path passed through
  local ubuntu_arch="amd64" debian_arch="amd64"
  if [[ "$QEMU_ARCH" == "aarch64" ]]; then ubuntu_arch="arm64"; debian_arch="arm64"; fi
  case "$1" in
    ubuntu-24.04) printf 'https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-%s.img' "$ubuntu_arch" ;;
    debian-12)    printf 'https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-%s.qcow2' "$debian_arch" ;;
    alpine-3.22)  resolve_alpine_url "3.22" || { err "Could not resolve the latest alpine-3.22 cloud image"; exit 3; } ;;
    http://*|https://*|/*|./*|../*) printf '%s' "$1" ;;
    *) err "Unknown image alias or path: $1 (aliases: ubuntu-24.04, debian-12, alpine-3.22)"; exit 2 ;;
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

cmd_install() {
  require_downloader
  local pm
  pm=$(detect_pm) || {
    err "No supported package manager found (apt, dnf, pacman, zypper, apk)."
    err "Install QEMU manually and re-run your command."
    exit 3
  }

  local missing
  missing=$(missing_packages "$pm")
  if [[ -z "$missing" ]]; then
    log "QEMU and all requirements are already installed — nothing to install."
  else
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

  if [[ -e /dev/kvm && ! -w /dev/kvm ]]; then
    log "Note: /dev/kvm exists but is not writable by you."
    log "For hardware acceleration run: sudo usermod -aG kvm \$USER  (then re-login)"
  elif [[ ! -e /dev/kvm ]]; then
    log "Note: /dev/kvm not found — VMs will use software emulation (slow)."
  fi

  log "Done. Try: qemu-vm start --image alpine-3.22"
}

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

  local accel_args="-cpu max"
  if [[ -w /dev/kvm ]]; then
    accel_args="-enable-kvm -cpu host"
  else
    log "Warning: /dev/kvm not accessible — using software emulation (slow)."
  fi

  local machine_args="-machine q35"
  local bios_args=""
  if [[ "$QEMU_ARCH" == "aarch64" ]]; then
    machine_args="-machine virt"
    local fw
    fw=$(aarch64_firmware) || { err "No aarch64 UEFI firmware found. Run: load.sh qemu -- install"; exit 3; }
    bios_args="-bios \"$fw\""
  fi

  local net="user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:${VM_SSH_PORT}-:22"
  local p
  for p in ${VM_PORTS:-}; do
    net+=",hostfwd=tcp:127.0.0.1:${p%%:*}-:${p##*:}"
  done

  local drive_args="-drive file=\"${dir}/disk.qcow2\",if=virtio"
  local cdrom_args=""
  [[ -n "${VM_CDROM:-}" ]] && cdrom_args="-cdrom \"${VM_CDROM}\""
  [[ -f "${dir}/seed.iso" ]] && cdrom_args+=" -drive file=\"${dir}/seed.iso\",media=cdrom"

  run "${QEMU_BIN} ${accel_args} ${machine_args} ${bios_args} \
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
  ensure_qemu
  ensure_wrapper
  run "mkdir -p \"$IMAGES_DIR\" \"$VMS_DIR\""

  local name="${NAME:-$VM_ARG}"

  # Boot an existing stopped VM by name
  if [[ -n "$name" && -d "$(vm_dir "$name")" ]]; then
    if is_running "$name"; then err "VM '${name}' is already running."; exit 3; fi
    if [[ -n "$IMAGE" ]]; then err "VM '${name}' already exists — start it without --image, or remove it first."; exit 2; fi
    boot_vm "$name"
    return
  fi

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
      run "download \"${src}\" \"${image_path}\""
    fi
  else
    image_path=$(readlink -f "$src")
    [[ -f "$image_path" ]] || { err "Image not found: $src"; exit 3; }
  fi

  if [[ -z "$name" ]]; then
    name=$(basename "$base" | sed -E 's/\.(qcow2|img|iso|raw)$//' | tr -cd 'a-zA-Z0-9_-')
  fi
  [[ "$name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]] || { err "Invalid VM name: ${name}"; exit 2; }

  local dir
  dir=$(vm_dir "$name")
  [[ -d "$dir" ]] && { err "VM '${name}' already exists."; exit 3; }

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
VM_MEMORY="${MEMORY}"
VM_CPUS="${CPUS}"
VM_SSH_PORT="${ssh_port}"
VM_MONITOR_PORT="${monitor_port}"
VM_PORTS="${EXTRA_PORTS[*]:-}"
VM_CDROM="${cdrom}"
CONF

  boot_vm "$name"
}

cmd_list() {
  printf '%-20s %-9s %-8s %-5s %-6s %s\n' "NAME" "STATE" "MEMORY" "CPUS" "SSH" "IMAGE"
  local dir name state
  for dir in "$VMS_DIR"/*/; do
    [[ -d "$dir" ]] || continue
    name=$(basename "$dir")
    state="stopped"
    is_running "$name" && state="running"
    (
      # shellcheck disable=SC1091
      source "${dir}/vm.conf" 2>/dev/null || true
      printf '%-20s %-9s %-8s %-5s %-6s %s\n' "$name" "$state" "${VM_MEMORY:-?}" "${VM_CPUS:-?}" "${VM_SSH_PORT:-?}" "$(basename "${VM_IMAGE:-?}")"
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
  install)   cmd_install ;;
  uninstall) cmd_uninstall ;;
  start)     cmd_start ;;
  list)      cmd_list ;;
  stop)      cmd_stop ;;
  remove)    cmd_remove ;;
  *) err "Unknown command: ${COMMAND} (expected: install, uninstall, start, list, stop, remove)"; exit 2 ;;
esac
