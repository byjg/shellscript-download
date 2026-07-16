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
        <InstallCommand command="load.sh php-rest-api" spec={{"prefix":"load.sh php-rest-api","dashes":true,"items":[{"kind":"arg","name":"folder","required":true,"description":"Target folder name where the project will be created"},{"kind":"option","name":"--namespace","value":"name","equals":true,"required":true,"description":"Project namespace (CamelCase, e.g., MyApp, Tutorial)"},{"kind":"option","name":"--name","value":"vendor/package","equals":true,"required":true,"description":"Composer package name (e.g., mycompany/myapp)"},{"kind":"option","name":"--mysql-uri","value":"uri","equals":true,"required":false,"description":"MySQL connection string"},{"kind":"option","name":"--install-examples","value":"Y|n","equals":true,"required":false,"description":"Install example code (default: Y)"},{"kind":"option","name":"--version","value":"constraint","equals":true,"required":false,"description":"Composer version constraint (default: ^6.0)"},{"kind":"option","name":"--php-version","value":"version","equals":true,"required":false,"description":"PHP version for Docker (8.1-8.4, default: current)"},{"kind":"option","name":"--timezone","value":"tz","equals":true,"required":false,"description":"Server timezone (default: UTC)"},{"kind":"option","name":"--git-name","value":"name","equals":true,"required":false,"description":"Git user name (default: from git config)"},{"kind":"option","name":"--git-email","value":"email","equals":true,"required":false,"description":"Git user email (default: from git config)"},{"kind":"option","name":"--manifest","value":null,"equals":false,"required":false,"description":"Print installation manifest and exit"}]}} />
        <pre style={{whiteSpace: 'pre-wrap', fontFamily: 'ui-monospace, monospace', background: '#0b1020', color: '#e5e7eb', padding: '1rem', borderRadius: '.5rem', marginTop: '1rem'}}>{`php-rest-api.sh <folder> --namespace=<name> --name=<name/name> [options]

Installs byjg/rest-reference-architecture in unattended mode.

Required Arguments:
  <folder>                  Target folder name where the project will be created
  --namespace=<name>        Project namespace (CamelCase, e.g., MyApp, Tutorial)
  --name=<vendor/package>   Composer package name (e.g., mycompany/myapp)

Optional Arguments:
  --mysql-uri=<uri>         MySQL connection string
                            (default values: schema=mysql, host=mysql-container,
                             user=root, password=mysqlp455w0rd, dev db=localdev, test db=localtest)
  --install-examples=<Y|n>  Install example code (default: Y)
  --version=<constraint>    Composer version constraint (default: ^6.0)
  --php-version=<version>   PHP version for Docker (8.1-8.4, default: current)
  --timezone=<tz>           Server timezone (default: UTC)
  --git-name=<name>         Git user name (default: from git config)
  --git-email=<email>       Git user email (default: from git config)
  --manifest                Print installation manifest and exit
  -h, --help                Show this help and exit

Examples:
  # Minimal installation
  load.sh php-rest-api -- myproject --namespace=MyApp --name=mycompany/myapp

  # Full configuration
  load.sh php-rest-api -- myproject --namespace=MyApp --name=mycompany/myapp \
    --mysql-uri=mysql://root:secret@mysql-container/mydb \
    --install-examples=n --version="^6.0" --php-version=8.4

  # Show manifest
  load.sh php-rest-api -- myproject --namespace=MyApp --name=mycompany/myapp --manifest
`}</pre>
        <br/>
      </div>
    </div>
  );
}
