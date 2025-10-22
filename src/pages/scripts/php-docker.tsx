// ------------------------------------------------------------------------------------
// Auto-generated from public/scripts/php-docker.sh — Do not edit.
// ------------------------------------------------------------------------------------

import { Link } from "react-router-dom";
import { InstallCommand } from "@/components/InstallCommand.tsx";
import { Terminal } from "lucide-react";

export default function Script_php_docker() {
  return (
    <div style={{maxWidth: 900, margin: "0 auto", padding: "2rem"}}>
      <header className="mb-4 text-center">
        <div className="inline-flex items-center gap-3 rounded-full border border-border bg-card/50 px-6 py-2 backdrop-blur-sm">
          <Terminal className="h-5 w-5 text-accent" />
          <span className="font-mono text-sm font-medium text-foreground">shellscript.download</span>
        </div>
      </header>
      <Link to="/">← Home</Link>
      <h1 style={{fontSize: "1.5rem", margin: "0 0 1rem"}}>php-docker.sh</h1>
      <InstallCommand command="load.sh php-docker" />
      <pre style={{whiteSpace: 'pre-wrap', fontFamily: 'ui-monospace, monospace', background: '#0b1020', color: '#e5e7eb', padding: '1rem', borderRadius: '.5rem'}}>{`php-docker.sh: Create Docker-backed php and composer launchers
Usage (via loader):
  load.sh php-docker -- <php_version>

Examples:
  load.sh php-docker -- 8.3
  load.sh php-docker -- 7.4

Description:
- Generates two wrapper scripts in "$HOME/.shellscript/bin":
    - php       → runs PHP inside the byjg/php:<version>-cli Docker image
    - composer  → runs Composer inside the same image, persisting your ~/.composer dir
- Pulls the specified Docker image and marks the wrappers executable.
- Intended for environments where PHP/Composer are not installed natively.

Port usage (wrappers):
- php wrapper publishes:
    - 8080:8080 (PHP built-in web server or other services on 8080)
    - 9003:9003 (Xdebug v3 default debug port)
  Environment:
    - XDEBUG_CLIENT_PORT=9003

Notes:
- Supported versions: 5.6, 7.0–7.4, 8.0–8.5
- Requires Docker installed and available on PATH.
- All scripts are intended to be invoked via load.sh; running this file directly is not required.
- This script is idempotent and can be re-run to switch versions.`}</pre>
      <br/>
    </div>
  );
}
