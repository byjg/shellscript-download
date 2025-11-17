// ------------------------------------------------------------------------------------
// Auto-generated from public/scripts/node-docker.sh — Do not edit.
// ------------------------------------------------------------------------------------

import { Link } from "react-router-dom";
import { InstallCommand } from "@/components/InstallCommand.tsx";
import { Terminal } from "lucide-react";

export default function Script_node_docker() {
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
        <h1 className="text-foreground" style={{fontSize: "1.5rem", margin: "1rem 0"}}>node-docker.sh</h1>
        <InstallCommand command="load.sh node-docker" />
        <pre style={{whiteSpace: 'pre-wrap', fontFamily: 'ui-monospace, monospace', background: '#0b1020', color: '#e5e7eb', padding: '1rem', borderRadius: '.5rem', marginTop: '1rem'}}>{`node-docker.sh: Create Docker-backed Node.js launchers (node, npm, npx, yarn)
Usage (via loader):
  load.sh node-docker -- <node_version>


Examples:
  load.sh node-docker -- 22
  load.sh node-docker -- 20

Description:
- Generates wrapper scripts in "$HOME/.shellscript/bin" for the selected Node version:
    - node<ver> → runs Node inside node:<ver>-alpine
    - npm<ver>  → runs npm inside node:<ver>-alpine (persisting ~/.npm and honoring ~/.npmrc)
    - npx<ver>  → runs npx inside node:<ver>-alpine
    - yarn<ver> → runs yarn inside node:<ver>-alpine (persisting ~/.cache/yarn)
- Also updates convenience symlinks: node, npm, npx, yarn → their <ver> counterparts.
- Pulls the specified Docker image and marks the wrappers executable.
- Intended for environments where Node.js tooling is not installed natively.

Notes:
- Typical versions: 18, 20, 22 (any tag supported by docker hub node:<tag>-alpine)
- Requires Docker installed and available on PATH. Install with \`load.sh docker\`
- This script is idempotent and can be re-run to switch versions.`}</pre>
        <br/>
      </div>
    </div>
  );
}
