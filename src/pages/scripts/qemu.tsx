// ------------------------------------------------------------------------------------
// Auto-generated from public/scripts/qemu.sh — Do not edit.
// ------------------------------------------------------------------------------------

import { Link } from "react-router-dom";
import { InstallCommand } from "@/components/InstallCommand.tsx";
import { Terminal } from "lucide-react";

export default function Script_qemu() {
  return (
    <div className="min-h-screen bg-(--gradient-hero)">
      <div style={{maxWidth: 900, margin: "0 auto", padding: "2rem"}}>
        <header className="mb-4 text-center">
          <div className="inline-flex items-center gap-3 rounded-full border border-border bg-card/50 px-6 py-2 backdrop-blur-xs">
            <Terminal className="h-5 w-5 text-accent" />
            <span className="font-mono text-sm font-medium text-foreground">shellscript.download</span>
          </div>
        </header>
        <Link to="/" className="text-accent hover:text-accent/80 transition-colors">← Home</Link>
        <h1 className="text-foreground" style={{fontSize: "1.5rem", margin: "1rem 0"}}>qemu.sh</h1>
        <InstallCommand command="load.sh qemu" spec={{"prefix":"load.sh qemu","dashes":true,"items":[{"kind":"arg","name":"command","required":true,"description":""},{"kind":"option","name":"--manifest","value":null,"equals":false,"required":false,"description":"Print installation manifest and exit"},{"kind":"option","name":"--dry-run","value":null,"equals":false,"required":false,"description":"Print actions without executing them"},{"kind":"option","name":"--image","value":"src","equals":false,"required":false,"description":"start: image alias, URL, or local path (qcow2/raw/iso)"},{"kind":"option","name":"--arch","value":"arch","equals":false,"required":false,"description":"start: guest CPU architecture, x86_64 or aarch64 (default:"},{"kind":"option","name":"--name","value":"name","equals":false,"required":false,"description":"start: VM name (default: derived from the image)"},{"kind":"option","name":"--memory","value":"size","equals":false,"required":false,"description":"start: RAM, e.g. 2048 or 2G (default: 2G)"},{"kind":"option","name":"--disk","value":"size","equals":false,"required":false,"description":"start: disk size, e.g. 10G (default: 10G)"},{"kind":"option","name":"--cpus","value":"n","equals":false,"required":false,"description":"start: number of virtual CPUs (default: 2)"},{"kind":"option","name":"--ssh-port","value":"port","equals":false,"required":false,"description":"start: host port forwarded to guest port 22 (default: first free port from 2222)"},{"kind":"option","name":"--port","value":"host:guest","equals":false,"required":false,"description":"start: extra port forward, can be repeated"},{"kind":"option","name":"--gpu","value":"pci-address","equals":false,"required":false,"description":"start: give the VM a host PCI device, such as a GPU, through VFIO"},{"kind":"option","name":"--bridge","value":"bridge","equals":false,"required":false,"description":"start: attach the VM to a host bridge (e.g. virbr0) instead of"},{"kind":"option","name":"--no-cloud-init","value":null,"equals":false,"required":false,"description":"start: skip the cloud-init seed (default user/SSH key injection)"},{"kind":"option","name":"--force","value":null,"equals":false,"required":false,"description":"stop: kill immediately; remove: remove even if running"},{"kind":"option","name":"--purge-image","value":null,"equals":false,"required":false,"description":"remove: also delete the cached base image if unused"}]}} />
        <pre style={{whiteSpace: 'pre-wrap', fontFamily: 'var(--font-mono)', background: '#0b1020', color: '#e5e7eb', padding: '1rem', borderRadius: '.5rem', marginTop: '1rem'}}>{`load.sh qemu -- <command> [options]

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
  address <name>        Print a bridged VM's address (exit 1 until it has one)
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
  --gpu <pci-address>   start: give the VM a host PCI device, such as a GPU, through VFIO
                        (e.g. 01:00.0, from lspci). The host loses it while the VM runs;
                        see 'GPU passthrough' below.
  --bridge <bridge>     start: attach the VM to a host bridge (e.g. virbr0) instead of
                        the private user-mode network. The VM gets its own address on the
                        bridge, reachable from the host and from other VMs on it; there is
                        no port forwarding (--ssh-port/--port do not apply). See 'Bridged
                        VMs' below for the one-time host setup.
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
    user-data    cloud-init config (default user, password, the SSH public keys in
                 ~/.ssh and in ssh-agent). Applied on
                 the VM's FIRST boot only — to customize it, create the VM, stop
                 it, edit user-data, regenerate seed.iso (genisoimage -output
                 seed.iso -volid cidata -joliet -rock user-data meta-data) and
                 change instance-id in meta-data so cloud-init runs again.
    seed.iso     The generated cloud-init seed attached as a CD-ROM.

Bridged VMs:
  By default each VM sits behind its own NAT (10.0.2.15) and is reached through ports
  forwarded on 127.0.0.1, so VMs cannot talk to each other. With --bridge the VM joins
  a host bridge instead, and 'list' shows the address it was given (by the bridge's
  DHCP). The first bridged 'start' sets the host up, with sudo, like any other
  requirement:
    - virbr0 is libvirt's default network (DHCP and NAT): its packages are installed
      (apt, dnf) and the network started. A bridge with another name must exist.
    - "allow <bridge>" is added to /etc/qemu/bridge.conf, and qemu-bridge-helper is
      made setuid, so QEMU can attach VMs to the bridge as your user.
  'load.sh remove -- qemu' undoes these, like the packages.

GPU passthrough:
  --gpu gives the VM the device itself, through VFIO, so it runs the vendor's driver
  (an NVIDIA GPU with CUDA and nvidia-smi, for example). Before anything changes,
  'start' checks that IOMMU is on, that the device's IOMMU group holds only its own
  functions (all of them go to the VM), and that the VM's memory fits under
  'ulimit -l', since VFIO locks it. Then, with sudo, the devices move from their host
  driver to vfio-pci; a device still in use on the host is refused. 'stop' and
  'remove' give each back to the driver it came from, also when the VM shut itself
  down; 'load.sh remove -- qemu' gives back anything left. Some laptop GPUs do not
  reset cleanly, and giving one back may then need a reboot.

Examples:
  load.sh qemu -- start --image ubuntu-24.04 --name dev1 --memory 2G --disk 10G
  load.sh qemu -- start --image ubuntu-24.04 --name node1 --bridge virbr0
  load.sh qemu -- start --image ubuntu-24.04 --name gpu1 --memory 3G --gpu 01:00.0
  load.sh qemu -- start --image https://example.com/disk.qcow2 --ssh-port 2222
  load.sh qemu -- start --image debian-12 --arch aarch64
  load.sh qemu -- start --name dev1
  load.sh qemu -- list
  load.sh qemu -- address node1
  load.sh qemu -- images
  load.sh qemu -- stop dev1
  load.sh qemu -- remove dev1 --purge-image
  load.sh remove -- qemu
  qemu-vm start --image alpine-3.22`}</pre>
        <br/>
      </div>
    </div>
  );
}
