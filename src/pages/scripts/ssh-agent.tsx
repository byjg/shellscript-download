// ------------------------------------------------------------------------------------
// Auto-generated from public/scripts/ssh-agent.sh — Do not edit.
// ------------------------------------------------------------------------------------

import { Link } from "react-router-dom";
import { InstallCommand } from "@/components/InstallCommand.tsx";
import { Terminal } from "lucide-react";

export default function Script_ssh_agent() {
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
        <h1 className="text-foreground" style={{fontSize: "1.5rem", margin: "1rem 0"}}>ssh-agent.sh</h1>
        <InstallCommand command="load.sh ssh-agent" />
        <pre style={{whiteSpace: 'pre-wrap', fontFamily: 'ui-monospace, monospace', background: '#0b1020', color: '#e5e7eb', padding: '1rem', borderRadius: '.5rem', marginTop: '1rem'}}>{`load.sh ssh-agent -- [options]

Writes a shell init snippet that starts ssh-agent (if not already running)
and loads SSH keys on every new shell session.

By default, all private keys found in ~/.ssh are added. Use --key to add
only specific keys. Running this script again overwrites the previous config.

Options:
  -h, --help       Show this help and exit
  --dry-run        Print actions without executing them
  --manifest       Print installation manifest and exit
  --key <path>     Add this key (can be repeated for multiple keys)

Examples:
  load.sh ssh-agent
  load.sh ssh-agent -- --key ~/.ssh/id_ed25519
  load.sh ssh-agent -- --key ~/.ssh/id_rsa --key ~/.ssh/work_key
  load.sh ssh-agent -- --dry-run`}</pre>
        <br/>
      </div>
    </div>
  );
}
