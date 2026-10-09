// ------------------------------------------------------------------------------------
// Auto-generated from public/scripts/podman.sh — Do not edit.
// ------------------------------------------------------------------------------------

import { Link } from "react-router-dom";
import { InstallCommand } from "@/components/InstallCommand.tsx";
import { Terminal } from "lucide-react";

export default function Script_podman() {
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
        <h1 className="text-foreground" style={{fontSize: "1.5rem", margin: "1rem 0"}}>podman.sh</h1>
        <InstallCommand command="load.sh podman" spec={{"prefix":"load.sh podman","dashes":true,"items":[{"kind":"option","name":"--dry-run","value":null,"equals":false,"required":false,"description":"Print actions without executing them"},{"kind":"option","name":"--docker","value":null,"equals":false,"required":false,"description":"Also create a 'docker' command that runs Podman"},{"kind":"option","name":"--manifest","value":null,"equals":false,"required":false,"description":"Print installation manifest and exit"}]}} />
        <pre style={{whiteSpace: 'pre-wrap', fontFamily: 'var(--font-mono)', background: '#0b1020', color: '#e5e7eb', padding: '1rem', borderRadius: '.5rem', marginTop: '1rem'}}>{`load.sh podman -- [options]

Installs Podman from the system package manager (uses sudo). Podman runs containers
without a daemon and, for a regular user, without root.

Options:
  -h, --help        Show this help and exit
  --dry-run         Print actions without executing them
  --docker          Also create a 'docker' command that runs Podman
                    (for commands and scripts written for Docker; refused when
                    Docker is installed)
  --manifest        Print installation manifest and exit

The 'docker' command is for plain Docker commands. The php-docker and node-docker
wrappers are written for the Docker Engine and are not supported on top of it.

Examples:
  load.sh podman
  load.sh podman -- --docker
  load.sh podman -- --dry-run
  load.sh remove -- podman`}</pre>
        <br/>
      </div>
    </div>
  );
}
