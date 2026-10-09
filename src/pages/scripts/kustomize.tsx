// ------------------------------------------------------------------------------------
// Auto-generated from public/scripts/kustomize.sh — Do not edit.
// ------------------------------------------------------------------------------------

import { Link } from "react-router-dom";
import { InstallCommand } from "@/components/InstallCommand.tsx";
import { Terminal } from "lucide-react";

export default function Script_kustomize() {
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
        <h1 className="text-foreground" style={{fontSize: "1.5rem", margin: "1rem 0"}}>kustomize.sh</h1>
        <InstallCommand command="load.sh kustomize" spec={{"prefix":"load.sh kustomize","dashes":true,"items":[{"kind":"option","name":"--version","value":"version","equals":false,"required":false,"description":"Version to install (default: latest), e.g. 5.8.3"},{"kind":"option","name":"--force","value":null,"equals":false,"required":false,"description":"Re-download even if already installed"},{"kind":"option","name":"--dry-run","value":null,"equals":false,"required":false,"description":"Print actions without executing them"},{"kind":"option","name":"--manifest","value":null,"equals":false,"required":false,"description":"Print installation manifest and exit"}]}} />
        <pre style={{whiteSpace: 'pre-wrap', fontFamily: 'var(--font-mono)', background: '#0b1020', color: '#e5e7eb', padding: '1rem', borderRadius: '.5rem', marginTop: '1rem'}}>{`load.sh kustomize -- [options]

Downloads the Kustomize binary for x86_64 and aarch64 Linux to
$HOME/.shellscript/kustomize/<version> and creates the 'kustomize' command. Run it again with
another --version to switch.

Options:
  -h, --help           Show this help and exit
  --version <version>  Version to install (default: latest), e.g. 5.8.3
  --force              Re-download even if already installed
  --dry-run            Print actions without executing them
  --manifest           Print installation manifest and exit

Examples:
  load.sh kustomize
  load.sh kustomize -- --version 5.8.3
  load.sh kustomize -- --dry-run`}</pre>
        <br/>
      </div>
    </div>
  );
}
