// ------------------------------------------------------------------------------------
// Auto-generated from public/scripts/docker.sh — Do not edit.
// ------------------------------------------------------------------------------------

import { Link } from "react-router-dom";
import { InstallCommand } from "@/components/InstallCommand.tsx";
import { Terminal } from "lucide-react";

export default function Script_docker() {
  return (
    <div style={{maxWidth: 900, margin: "0 auto", padding: "2rem"}}>
      <header className="mb-4 text-center">
        <div className="inline-flex items-center gap-3 rounded-full border border-border bg-card/50 px-6 py-2 backdrop-blur-sm">
          <Terminal className="h-5 w-5 text-accent" />
          <span className="font-mono text-sm font-medium text-foreground">shellscript.download</span>
        </div>
      </header>
      <Link to="/">← Home</Link>
      <h1 style={{fontSize: "1.5rem", margin: "0 0 1rem"}}>docker.sh</h1>
      <InstallCommand command="load.sh docker" />
      <pre style={{whiteSpace: 'pre-wrap', fontFamily: 'ui-monospace, monospace', background: '#0b1020', color: '#e5e7eb', padding: '1rem', borderRadius: '.5rem'}}>{`docker.sh: Install the Docker Engine on Linux in a safe, idempotent, shell-friendly way

Usage (via loader):
  load.sh docker -- [--help] [--dry-run] [--no-group] [--channel CHANNEL]

Examples:
  # Install Docker with sensible defaults
  load.sh docker
  # Show help
  load.sh docker -- --help
  # Simulate actions without making changes
  load.sh docker -- --dry-run

Description:
- Installs Docker Engine using the official convenience script from get.docker.com
- Creates the "docker" group (if missing) and adds the current user to it (unless --no-group)
- Fixes $HOME/.docker permissions for the current user
- Idempotent: safe to re-run, it will skip already completed steps
- Non-interactive: suitable for CI; prints clear logs and exits on first error
- Supports a dry-run mode for previewing actions`}</pre>
      <br/>
    </div>
  );
}
