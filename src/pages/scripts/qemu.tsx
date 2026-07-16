// ------------------------------------------------------------------------------------
// Auto-generated from public/scripts/qemu.sh — Do not edit.
// ------------------------------------------------------------------------------------

import { Link } from "react-router-dom";
import { InstallCommand } from "@/components/InstallCommand.tsx";
import { Terminal } from "lucide-react";

export default function Script_qemu() {
  return (
    <div className="min-h-screen bg-[var(--gradient-hero)]">
      <div style={{maxWidth: 900, margin: "0 auto", padding: "2rem"}}>
        <header className="mb-4 text-center">
          <div className="inline-flex items-center gap-3 rounded-full border border-border bg-card/50 px-6 py-2 backdrop-blur-sm">
            <Terminal className="h-5 w-5 text-accent" />
            <span className="font-mono text-sm font-medium text-foreground">shellscript.download</span>
          </div>
        </header>
        <Link to="/" className="text-accent hover:text-accent/80 transition-colors">← Home</Link>
        <h1 className="text-foreground" style={{fontSize: "1.5rem", margin: "1rem 0"}}>qemu.sh</h1>
        <InstallCommand command="load.sh qemu" spec={{"prefix":"load.sh qemu","dashes":true,"items":[{"kind":"arg","name":"command","required":true,"description":""},{"kind":"option","name":"--manifest","value":null,"equals":false,"required":false,"description":"Print installation manifest and exit"},{"kind":"option","name":"--dry-run","value":null,"equals":false,"required":false,"description":"Print actions without executing them"},{"kind":"option","name":"--image","value":"src","equals":false,"required":false,"description":"start: image alias, URL, or local path (qcow2/raw/iso)"},{"kind":"option","name":"--arch","value":"arch","equals":false,"required":false,"description":"start: guest CPU architecture, x86_64 or aarch64 (default:"},{"kind":"option","name":"--name","value":"name","equals":false,"required":false,"description":"start: VM name (default: derived from the image)"},{"kind":"option","name":"--memory","value":"size","equals":false,"required":false,"description":"start: RAM, e.g. 2048 or 2G (default: 2G)"},{"kind":"option","name":"--disk","value":"size","equals":false,"required":false,"description":"start: disk size, e.g. 10G (default: 10G)"},{"kind":"option","name":"--cpus","value":"n","equals":false,"required":false,"description":"start: number of virtual CPUs (default: 2)"},{"kind":"option","name":"--ssh-port","value":"port","equals":false,"required":false,"description":"start: host port forwarded to guest port 22 (default: first free port from 2222)"},{"kind":"option","name":"--port","value":"host:guest","equals":false,"required":false,"description":"start: extra port forward, can be repeated"},{"kind":"option","name":"--no-cloud-init","value":null,"equals":false,"required":false,"description":"start: skip the cloud-init seed (default user/SSH key injection)"},{"kind":"option","name":"--force","value":null,"equals":false,"required":false,"description":"stop: kill immediately; remove: remove even if running"},{"kind":"option","name":"--purge-image","value":null,"equals":false,"required":false,"description":"remove: also delete the cached base image if unused"}]}} />
        <pre style={{whiteSpace: 'pre-wrap', fontFamily: 'ui-monospace, monospace', background: '#0b1020', color: '#e5e7eb', padding: '1rem', borderRadius: '.5rem', marginTop: '1rem'}}>{`load.sh qemu -- <command> [options]

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
  qemu-vm start --image alpine-3.22`}</pre>
        <br/>
      </div>
    </div>
  );
}
