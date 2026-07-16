// ------------------------------------------------------------------------------------
// Auto-generated from public/scripts/java-oracle.sh — Do not edit.
// ------------------------------------------------------------------------------------

import { Link } from "react-router-dom";
import { InstallCommand } from "@/components/InstallCommand.tsx";
import { Terminal } from "lucide-react";

export default function Script_java_oracle() {
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
        <h1 className="text-foreground" style={{fontSize: "1.5rem", margin: "1rem 0"}}>java-oracle.sh</h1>
        <InstallCommand command="load.sh java-oracle" spec={{"prefix":"load.sh java-oracle","dashes":true,"items":[{"kind":"option","name":"--version","value":"version","equals":false,"required":false,"description":"Java major version to install (default: 21)"},{"kind":"option","name":"--yes","value":null,"equals":false,"required":false,"description":"Skip confirmation for non-LTS versions"},{"kind":"option","name":"--force","value":null,"equals":false,"required":false,"description":"Re-download even if already installed"},{"kind":"option","name":"--dry-run","value":null,"equals":false,"required":false,"description":"Print actions without executing them"},{"kind":"option","name":"--manifest","value":null,"equals":false,"required":false,"description":"Print installation manifest and exit"}]}} />
        <pre style={{whiteSpace: 'pre-wrap', fontFamily: 'ui-monospace, monospace', background: '#0b1020', color: '#e5e7eb', padding: '1rem', borderRadius: '.5rem', marginTop: '1rem'}}>{`load.sh java-oracle -- [options]

Downloads and installs Oracle JDK binary distribution for x86_64 Linux.

Options:
  -h, --help           Show this help and exit
  --version <version>  Java major version to install (default: 21)
                       LTS versions: 17, 21, 25 (publicly available)
                       Non-LTS versions require confirmation (or --yes)
                       Note: Oracle only provides public downloads for recent LTS versions
  --yes, -y            Skip confirmation for non-LTS versions
  --force              Re-download even if already installed
  --dry-run            Print actions without executing them
  --manifest [--version <version>]
                       Print installation manifest and exit
                       Without --version: removes all versions (default)
                       With --version: removes only specific version

Examples:
  load.sh java-oracle
  load.sh java-oracle -- --version 25
  load.sh java-oracle -- --version 24 --yes
  load.sh java-oracle -- --dry-run
  load.sh java-oracle -- --manifest --version 21

Note:
  By downloading and using Oracle JDK, you agree to the Oracle Technology Network License Agreement.
  For production use, please review Oracle's licensing terms.`}</pre>
        <br/>
      </div>
    </div>
  );
}
