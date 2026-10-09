// ------------------------------------------------------------------------------------
// Auto-generated from public/scripts/byjg-repo.sh — Do not edit.
// ------------------------------------------------------------------------------------

import { Link } from "react-router-dom";
import { InstallCommand } from "@/components/InstallCommand.tsx";
import { Terminal } from "lucide-react";

export default function Script_byjg_repo() {
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
        <h1 className="text-foreground" style={{fontSize: "1.5rem", margin: "1rem 0"}}>byjg-repo.sh</h1>
        <InstallCommand command="load.sh byjg-repo" spec={{"prefix":"load.sh byjg-repo","dashes":true,"items":[{"kind":"option","name":"--install","value":"package","equals":false,"required":false,"description":"Also install a package of the repository (can be repeated)"},{"kind":"option","name":"--list","value":null,"equals":false,"required":false,"description":"List the packages of the repository and exit"},{"kind":"option","name":"--dry-run","value":null,"equals":false,"required":false,"description":"Print actions without executing them"},{"kind":"option","name":"--manifest","value":null,"equals":false,"required":false,"description":"Print installation manifest and exit"}]}} />
        <pre style={{whiteSpace: 'pre-wrap', fontFamily: 'var(--font-mono)', background: '#0b1020', color: '#e5e7eb', padding: '1rem', borderRadius: '.5rem', marginTop: '1rem'}}>{`load.sh byjg-repo -- [options]

Adds the ByJG package repository to the system (uses sudo), with its signing key:
the APT one on Debian and Ubuntu, the RPM one on Fedora and RHEL. Its packages are
then installed and updated by the system package manager.
More: https://opensource.byjg.com/docs/packages

Options:
  -h, --help           Show this help and exit
  --install <package>  Also install a package of the repository (can be repeated)
  --list               List the packages of the repository and exit
  --dry-run            Print actions without executing them
  --manifest           Print installation manifest and exit

Examples:
  load.sh byjg-repo
  load.sh byjg-repo -- --list
  load.sh byjg-repo -- --install parolsh
  load.sh remove -- byjg-repo`}</pre>
        <br/>
      </div>
    </div>
  );
}
