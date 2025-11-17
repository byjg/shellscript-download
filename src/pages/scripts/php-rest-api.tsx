// ------------------------------------------------------------------------------------
// Auto-generated from public/scripts/php-rest-api.sh — Do not edit.
// ------------------------------------------------------------------------------------

import { Link } from "react-router-dom";
import { InstallCommand } from "@/components/InstallCommand.tsx";
import { Terminal } from "lucide-react";

export default function Script_php_rest_api() {
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
        <h1 className="text-foreground" style={{fontSize: "1.5rem", margin: "1rem 0"}}>php-rest-api.sh</h1>
        <InstallCommand command="load.sh php-rest-api" />
        <pre style={{whiteSpace: 'pre-wrap', fontFamily: 'ui-monospace, monospace', background: '#0b1020', color: '#e5e7eb', padding: '1rem', borderRadius: '.5rem', marginTop: '1rem'}}>{`php-rest-api.sh: Install byjg/rest-reference-architecture in unattended mode

Usage (via loader):
  load.sh php-rest-api -- <folder> --namespace=<name> --name=<name/name> \
    [--mysql-uri=<uri>] [--install-examples=Y|n] [--version=<version>] \
    [--php-version=<version>] [--timezone=<tz>] [--git-name=<name>] [--git-email=<email>]

Examples:
  # Minimal installation
  load.sh php-rest-api -- myproject --namespace=MyApp --name=mycompany/myapp

  # Full configuration
  load.sh php-rest-api -- myproject --namespace=MyApp --name=mycompany/myapp \
    --mysql-uri=mysql://root:secret@mysql-container/mydb \
    --install-examples=n --version="^6.0" --php-version=8.4 \
    --timezone=America/New_York

Description:
- Creates a setup.json file in the parent directory for unattended installation
- Runs composer create-project with byjg/rest-reference-architecture
- Automatically configures the project using the provided parameters
- Cleans up the setup.json file after successful installation
- Idempotent: safe to re-run, though it will recreate the project folder

Required Arguments:
  <folder>          Target folder name where the project will be created
  --namespace       Project namespace (CamelCase, e.g., MyApp, Tutorial)
  --name            Composer package name (vendor/package format, e.g., mycompany/myapp)

Optional Arguments:
  --mysql-uri       MySQL connection string (default values: schema=mysql, host=mysql-container,
                    user=root, password=mysqlp455w0rd, dev db=localdev, test db=localtest)
  --install-examples Install example code (Y or n, default: Y)
  --version         Composer version constraint (default: ^6.0)
  --php-version     PHP version for Docker (8.1, 8.2, 8.3, 8.4, default: current PHP version)
  --timezone        Server timezone (default: UTC)
  --git-name        Git user name for the project (default: from git config or "Your Name")
  --git-email       Git user email for the project (default: from git config or "your.email@example.com")
  -h, --help        Show this help and exit

Notes:
- Requires composer installed on the system or use load.sh php-docker first
- The setup.json file will be created in the parent directory of the target folder
- The setup.json file is automatically removed after successful installation
- If the target folder exists, the script will fail (safety measure)`}</pre>
        <br/>
      </div>
    </div>
  );
}
