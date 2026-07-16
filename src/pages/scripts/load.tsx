// ------------------------------------------------------------------------------------
// Auto-generated from public/scripts/load.sh — Do not edit.
// ------------------------------------------------------------------------------------

import { Link } from "react-router-dom";
import { InstallCommand } from "@/components/InstallCommand.tsx";
import { Terminal } from "lucide-react";

export default function Script_load() {
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
        <h1 className="text-foreground" style={{fontSize: "1.5rem", margin: "1rem 0"}}>load.sh</h1>
        <InstallCommand command="load.sh load" spec={{"prefix":"load.sh","dashes":false,"items":[{"kind":"option","name":"--update","value":null,"equals":false,"required":false,"description":"Force re-download/update of the script even if it exists locally"},{"kind":"option","name":"--dont-run","value":null,"equals":false,"required":false,"description":"Do not execute the script after ensuring it is downloaded"},{"kind":"option","name":"--list","value":null,"equals":false,"required":false,"description":"List all available scripts from shellscript.download"},{"kind":"option","name":"--completion","value":null,"equals":false,"required":false,"description":"Install/update bash completion for load.sh into ~/.shellscript/shellrc/"},{"kind":"option","name":"--developer","value":"path","equals":false,"required":false,"description":"Use a local directory instead of downloading (for development)"},{"kind":"arg","name":"script","required":true,"description":"The script name (without .sh) to fetch from shellscript.download"}]}} />
        <pre style={{whiteSpace: 'pre-wrap', fontFamily: 'ui-monospace, monospace', background: '#0b1020', color: '#e5e7eb', padding: '1rem', borderRadius: '.5rem', marginTop: '1rem'}}>{`load.sh [--update] [--dont-run] [--list] [--completion] [--developer <path>] <script> [optional args...]

Options:
  --update           Force re-download/update of the script even if it exists locally
  --dont-run         Do not execute the script after ensuring it is downloaded
  --list             List all available scripts from shellscript.download
  --completion       Install/update bash completion for load.sh into ~/.shellscript/shellrc/
  --developer <path> Use a local directory instead of downloading (for development)
  -h, --help         Show this help message

Arguments:
  <script>      The script name (without .sh) to fetch from shellscript.download
  [args...]     Optional arguments to pass through to the downloaded script`}</pre>
        <br/>
      </div>
    </div>
  );
}
