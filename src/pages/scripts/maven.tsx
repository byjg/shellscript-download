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
        <pre style={{whiteSpace: 'pre-wrap', fontFamily: 'ui-monospace, monospace', background: '#0b1020', color: '#e5e7eb', padding: '1rem', borderRadius: '.5rem', marginTop: '1rem'}}>{`maven.sh: Download and install Apache Maven

Usage (via loader):
  load.sh maven -- [--version <version>] [--help] [--dry-run]

Examples:
  # Install Maven with default version (3.9.12)
  load.sh maven
  # Install specific Maven version
  load.sh maven -- --version 3.8.8
  # Show help
  load.sh maven -- --help
  # Simulate actions without making changes
  load.sh maven -- --dry-run

Description:
- Downloads Apache Maven binary from the official Apache archive
- Extracts it to $HOME/.shellscript/maven
- Creates wrapper scripts in $HOME/.shellscript/bin (mvn, mvnDebug)
- Creates $HOME/.shellscript/shellrc/maven-init.sh for environment variables
- Idempotent and non-interactive; supports a dry-run mode`}</pre>
        <br/>
      </div>
    </div>
  );
}
