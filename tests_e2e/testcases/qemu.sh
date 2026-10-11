#!/usr/bin/env bash
# qemu.sh: install QEMU, create a VM and reach it over SSH, stop, start again, remove,
# and uninstall
# privileged: yes
source "$(dirname "${BASH_SOURCE[0]}")/../shared/lib.sh"

tool_home="${SHELLSCRIPT_HOME}/qemu"
vm="e2e-vm"
vm_dir="${tool_home}/vms/${vm}"

# vm_ssh "<command>": runs it in the VM, as the user cloud-init creates
vm_ssh() {
  local port
  port="$(sed -n 's/^VM_SSH_PORT=//p' "${vm_dir}/vm.conf" | tr -d '"')"
  ssh -p "$port" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
    -o ConnectTimeout=5 -o BatchMode=yes shellscript@127.0.0.1 "$1"
}

# The VM takes a while to boot and to apply cloud-init
assert_vm_answers() {
  local i
  for i in $(seq 1 60); do
    if [[ "$(vm_ssh hostname 2>/dev/null)" == "$vm" ]]; then pass "the VM answers over SSH as '${vm}'"; return 0; fi
    sleep 3
  done
  fail "the VM did not answer over SSH in 3 minutes"
}

step "qemu: install with the defaults"
load qemu
assert_log "QEMU is ready"
assert_command qemu-img
assert_command "qemu-system-$(uname -m)"
assert_exists "${SHELLSCRIPT_HOME}/bin/qemu-vm"
assert_exists "${tool_home}/installed-packages.conf"

step "qemu: install again changes nothing"
load qemu
if grep -q "Installing missing packages" "$LOG_FILE"; then fail "installed packages again"; else pass "no package installed again"; fi

step "qemu: list, images, and wrong calls"
assert_output "${LOADER} qemu -- list 2>/dev/null" "NAME"
assert_output "${LOADER} qemu -- images 2>/dev/null" "alpine-"
assert_exit 2 "${LOADER} qemu -- no-such-command"
assert_exit 2 "${LOADER} qemu -- start"
assert_log "--image is required"

step "qemu: --dry-run start creates no VM"
load qemu -- --dry-run start --image alpine-3.22 --name e2e-dry
assert_log "[dry-run] Creating VM 'e2e-dry'"
assert_missing "${tool_home}/vms/e2e-dry"

# Booting a VM in a test needs hardware acceleration: without it QEMU emulates the CPU,
# and a boot takes minutes
if [[ ! -e /dev/kvm ]]; then
  skip "booting a VM: no /dev/kvm in this container"
else
  step "qemu: prepare the SSH key that cloud-init gives the VM, and KVM for the user"
  if on_image ubuntu; then package="openssh-client"; elif on_image fedora; then package="openssh-clients"; else package="openssh"; fi
  if sys_install "$package"; then pass "installed ${package}"; else fail "could not install ${package}"; fi
  mkdir -p ~/.ssh && chmod 700 ~/.ssh
  ssh-keygen -q -t ed25519 -N '' -f ~/.ssh/id_ed25519
  # The device of the container, not the one of the host: a user gets this through the kvm group
  sudo chmod 666 /dev/kvm

  step "qemu: start creates and boots a VM"
  load qemu -- start --image alpine-3.22 --name "$vm" --memory 512M --disk 2G
  assert_exists "${vm_dir}/disk.qcow2"
  assert_exists "${vm_dir}/seed.iso"
  assert_output "${LOADER} qemu -- list 2>/dev/null" "running"
  assert_vm_answers
  assert_output "$(declare -f vm_ssh); vm_dir='${vm_dir}'; vm_ssh 'id -un'" "shellscript"

  step "qemu: the qemu-vm launcher runs the same script"
  assert_output "qemu-vm list 2>/dev/null" "${vm}"

  step "qemu: a running VM is not started twice, nor removed without --force"
  assert_exit 3 "${LOADER} qemu -- start --name ${vm}"
  load_fails qemu -- remove "$vm"
  assert_exists "$vm_dir"

  step "qemu: stop, and start the same VM again"
  load qemu -- stop "$vm"
  assert_output "${LOADER} qemu -- list 2>/dev/null" "stopped"
  load qemu -- start --name "$vm"
  assert_output "${LOADER} qemu -- list 2>/dev/null" "running"
  assert_vm_answers

  step "qemu: remove --force --purge-image takes out the VM and its base image"
  load qemu -- remove "$vm" --force --purge-image
  assert_missing "$vm_dir"
  assert_no_output "ls ${tool_home}/images" "alpine"

  step "qemu: uninstall stops a VM that is still running"
  load qemu -- start --image alpine-3.22 --name "$vm" --memory 512M --disk 2G
  assert_output "${LOADER} qemu -- list 2>/dev/null" "running"
fi

step "qemu: remove uninstalls the packages and keeps the folder"
load remove -- qemu
assert_no_command qemu-img
assert_no_output "pgrep -a qemu-system || true" "$vm"
assert_missing "${SHELLSCRIPT_HOME}/bin/qemu-vm"
assert_exists "$tool_home"

step "qemu: purge removes the folder"
load remove -- qemu --purge
assert_missing "$tool_home"

finish
