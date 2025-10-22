// ------------------------------------------------------------------------------------
// Auto-generated from public/scripts/nvm.sh — Do not edit.
// ------------------------------------------------------------------------------------

import { Link } from "react-router-dom";
import { InstallCommand } from "@/components/InstallCommand.tsx";
import { Terminal } from "lucide-react";

export default function Script_nvm() {
  return (
    <div style={{maxWidth: 900, margin: "0 auto", padding: "2rem"}}>
      <header className="mb-4 text-center">
        <div className="inline-flex items-center gap-3 rounded-full border border-border bg-card/50 px-6 py-2 backdrop-blur-sm">
          <Terminal className="h-5 w-5 text-accent" />
          <span className="font-mono text-sm font-medium text-foreground">shellscript.download</span>
        </div>
      </header>
      <Link to="/">← Home</Link>
      <h1 style={{fontSize: "1.5rem", margin: "0 0 1rem"}}>nvm.sh</h1>
      <InstallCommand command="load.sh nvm" />
      <pre style={{whiteSpace: 'pre-wrap', fontFamily: 'ui-monospace, monospace', background: '#0b1020', color: '#e5e7eb', padding: '1rem', borderRadius: '.5rem'}}>{`nvm.sh: Install Node Version Manager (NVM) and set up a shell init snippet

Usage:
  nvm.sh [--help] [--dry-run]

Examples (following load.sh style):
  # Install NVM with sensible defaults
  load.sh nvm
  # Show help
  load.sh nvm -- --help
  # Simulate actions without making changes
  load.sh nvm -- --dry-run

Description:
- Installs NVM using the official install script from nvm-sh/nvm
- Removes the trailing installer-added lines from common shell rc files to avoid duplication
- Creates $HOME/.shellscript/shellrc/nvm-init.sh which you can source from your rc
- Idempotent and non-interactive; supports a dry-run mode`}</pre>
      <br/>
    </div>
  );
}
