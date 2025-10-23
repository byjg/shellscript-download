// ------------------------------------------------------------------------------------
// Auto-generated from public/scripts/load.sh — Do not edit.
// ------------------------------------------------------------------------------------

import { Link } from "react-router-dom";
import { InstallCommand } from "@/components/InstallCommand.tsx";
import { Terminal } from "lucide-react";

export default function Script_load() {
  return (
    <div style={{maxWidth: 900, margin: "0 auto", padding: "2rem"}}>
      <header className="mb-4 text-center">
        <div className="inline-flex items-center gap-3 rounded-full border border-border bg-card/50 px-6 py-2 backdrop-blur-sm">
          <Terminal className="h-5 w-5 text-accent" />
          <span className="font-mono text-sm font-medium text-foreground">shellscript.download</span>
        </div>
      </header>
      <Link to="/">← Home</Link>
      <h1 style={{fontSize: "1.5rem", margin: "0 0 1rem"}}>load.sh</h1>
      <InstallCommand command="load.sh load" />
      <pre style={{whiteSpace: 'pre-wrap', fontFamily: 'ui-monospace, monospace', background: '#0b1020', color: '#e5e7eb', padding: '1rem', borderRadius: '.5rem'}}>{`load.sh: Fetch a script from https://shellscript.download, cache it locally,
         and optionally execute it.

Cache location used by this script:
  $HOME/.shellscript/downloads/<script>.sh

Usage:
  load.sh [--update] [--dont-run] <script> [optional args...]

Options:
  --update      Force re-download/update of the script even if it exists locally
  --dont-run    Do not execute the script after ensuring it is downloaded
  -h, --help    Show this help message

Arguments:
  <script>      The script name (without .sh) to fetch from shellscript.download
  [args...]     Optional arguments to pass through to the downloaded script

To update the loader to a new version, reinstall it via the installer:
  /bin/bash -c "$(curl -fsSL https://shellscript.download/install/loader)"

Notes about environment setup:
  The installer (install/loader) may create and manage additional directories such as
  $HOME/.shellscript/shellrc (for auto-loading during shell init) and
  $HOME/.shellscript/bin (added to PATH). This load.sh script itself only ensures
  the cache directory $HOME/.shellscript/downloads and uses it to store scripts.

Behavior:
  - If the cached file is missing at "$HOME/.shellscript/downloads/<script>.sh" OR
    if --update is passed, the script is downloaded from the remote URL.
  - After ensuring the cached script exists, it is executed with remaining arguments
    unless --dont-run is provided.
  - Exits with the same code as the executed script when run.`}</pre>
      <br/>
    </div>
  );
}
