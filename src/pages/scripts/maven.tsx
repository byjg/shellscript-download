// ------------------------------------------------------------------------------------
// Auto-generated from public/scripts/maven.sh — Do not edit.
// ------------------------------------------------------------------------------------

import { Link } from "react-router-dom";
import { InstallCommand } from "@/components/InstallCommand.tsx";
import { Terminal } from "lucide-react";

export default function Script_maven() {
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
        <h1 className="text-foreground" style={{fontSize: "1.5rem", margin: "1rem 0"}}>maven.sh</h1>
        <InstallCommand command="load.sh maven" />
        <pre style={{whiteSpace: 'pre-wrap', fontFamily: 'ui-monospace, monospace', background: '#0b1020', color: '#e5e7eb', padding: '1rem', borderRadius: '.5rem', marginTop: '1rem'}}>{`load.sh maven -- [options]

Downloads and installs Apache Maven binary distribution.

Options:
  -h, --help           Show this help and exit
  --version <version>  Maven version to install (default: 3.9.12)
  --dry-run            Print actions without executing them
  --manifest           Print installation manifest and exit

Examples:
  load.sh maven
  load.sh maven -- --version 3.8.8
  load.sh maven -- --dry-run`}</pre>
        <br/>
      </div>
    </div>
  );
}
