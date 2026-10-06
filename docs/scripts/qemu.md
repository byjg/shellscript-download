---
# Auto-generated from public/scripts/qemu.sh — Do not edit.
description: "Download QEMU and manage local virtual machines (start, list, stop, remove)"
---

# qemu

Download QEMU and manage local virtual machines (start, list, stop, remove)

```bash
load.sh qemu
```

## Usage

```text
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
```

[Script page](https://shellscript.download/scripts/qemu) · [Source](https://github.com/byjg/shellscript-download/blob/main/public/scripts/qemu.sh)
