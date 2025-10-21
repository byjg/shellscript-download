// ------------------------------------------------------------------------------------
// Auto-generated from public/scripts/load.sh — Do not edit.
// ------------------------------------------------------------------------------------

import { Link } from "react-router-dom";
import { InstallCommand } from "@/components/InstallCommand.tsx";
import { Terminal } from "lucide-react";

export default function Script_load() {
  return (
    <div style={{maxWidth: 900, margin: "0 auto", padding: "2rem"}}>
      <header className="mb-4 text-center">
        <div className="inline-flex items-center gap-3 rounded-full border border-border bg-card/50 px-6 py-2 backdrop-blur-sm">
          <Terminal className="h-5 w-5 text-accent" />
          <span className="font-mono text-sm font-medium text-foreground">shellscript.download</span>
        </div>
      </header>
      <Link to="/">← Home</Link>
      <h1 style={{fontSize: "1.5rem", margin: "0 0 1rem"}}>load.sh</h1>
      <InstallCommand command="load.sh load" />
      <pre style={{whiteSpace: 'pre-wrap', fontFamily: 'ui-monospace, monospace', background: '#0b1020', color: '#e5e7eb', padding: '1rem', borderRadius: '.5rem'}}>{`load.sh: Download and optionally run shell scripts from shellscript.download
Usage:
  load.sh [--update] [--dont-run] <script> [optional args...]

Behavior:
- If <script> does not exist locally at "$HOME/.local/bin/<script>.sh" OR if --update is passed,
  download it from: https://shellscript.download/scripts/<script>.sh
  and save it to:   $HOME/.local/bin/<script>.sh
- After ensuring the script exists, run it with the remaining arguments, unless --dont-run is passed.
- Exits with the same code as the executed script when run.`}</pre>
      <br/>
    </div>
  );
}
