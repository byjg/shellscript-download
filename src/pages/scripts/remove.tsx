// ------------------------------------------------------------------------------------
// Auto-generated from public/scripts/remove.sh — Do not edit.
// ------------------------------------------------------------------------------------

import { Link } from "react-router-dom";
import { InstallCommand } from "@/components/InstallCommand.tsx";
import { Terminal } from "lucide-react";

export default function Script_remove() {
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
        <h1 className="text-foreground" style={{fontSize: "1.5rem", margin: "1rem 0"}}>remove.sh</h1>
        <InstallCommand command="load.sh remove" />
        <pre style={{whiteSpace: 'pre-wrap', fontFamily: 'ui-monospace, monospace', background: '#0b1020', color: '#e5e7eb', padding: '1rem', borderRadius: '.5rem', marginTop: '1rem'}}>{`remove.sh: Remove installed tools from shellscript.download

Usage:
  load.sh remove -- <script-name>         - Remove binaries and shell rc files
  load.sh remove -- --purge <script-name> - Remove everything including tool folders

Examples:
  # Remove Maven binaries and shell rc files (keeps downloaded folders)
  load.sh remove -- maven
  # Remove all traces of Maven including downloaded folders
  load.sh remove -- --purge maven
  # Remove NVM completely
  load.sh remove -- --purge nvm
  # Dry-run to preview actions
  load.sh remove -- --dry-run --purge maven

Description:
- Fetches the script's manifest to know what was installed
- Removes binaries from $HOME/.shellscript/bin/
- Removes shell rc files from $HOME/.shellscript/shellrc/
- With --purge: also removes tool folders from $HOME/.shellscript/<tool-name>/
- Supports dry-run mode to preview actions`}</pre>
        <br/>
      </div>
    </div>
  );
}
