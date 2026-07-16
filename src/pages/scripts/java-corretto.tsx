// ------------------------------------------------------------------------------------
// Auto-generated from public/scripts/java-corretto.sh — Do not edit.
// ------------------------------------------------------------------------------------

import { Link } from "react-router-dom";
import { InstallCommand } from "@/components/InstallCommand.tsx";
import { Terminal } from "lucide-react";

export default function Script_java_corretto() {
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
        <h1 className="text-foreground" style={{fontSize: "1.5rem", margin: "1rem 0"}}>java-corretto.sh</h1>
        <InstallCommand command="load.sh java-corretto" spec={{"prefix":"load.sh java-corretto","dashes":true,"items":[{"kind":"option","name":"--version","value":"version","equals":false,"required":false,"description":"Java major version to install (default: 21)"},{"kind":"option","name":"--yes","value":null,"equals":false,"required":false,"description":"Skip confirmation for non-LTS versions"},{"kind":"option","name":"--force","value":null,"equals":false,"required":false,"description":"Re-download even if already installed"},{"kind":"option","name":"--dry-run","value":null,"equals":false,"required":false,"description":"Print actions without executing them"},{"kind":"option","name":"--manifest","value":null,"equals":false,"required":false,"description":"Print installation manifest and exit"}]}} />
        <pre style={{whiteSpace: 'pre-wrap', fontFamily: 'ui-monospace, monospace', background: '#0b1020', color: '#e5e7eb', padding: '1rem', borderRadius: '.5rem', marginTop: '1rem'}}>{`load.sh java-corretto -- [options]

Downloads and installs Amazon Corretto OpenJDK binary distribution for x86_64 Linux.

Options:
  -h, --help           Show this help and exit
  --version <version>  Java major version to install (default: 21)
                       LTS versions: 8, 11, 17, 21, 25
                       Non-LTS versions require confirmation (or --yes)
  --yes, -y            Skip confirmation for non-LTS versions
  --force              Re-download even if already installed
  --dry-run            Print actions without executing them
  --manifest [--version <version>]
                       Print installation manifest and exit
                       Without --version: removes all versions (default)
                       With --version: removes only specific version

Examples:
  load.sh java-corretto
  load.sh java-corretto -- --version 17
  load.sh java-corretto -- --version 14 --yes
  load.sh java-corretto -- --dry-run
  load.sh java-corretto -- --manifest --version 21`}</pre>
        <br/>
      </div>
    </div>
  );
}
