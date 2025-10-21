// ------------------------------------------------------------------------------------
// Auto-generated from public/scripts/php-docker.sh — Do not edit.
// ------------------------------------------------------------------------------------

import React from "react";
import { Link } from "react-router-dom";

export default function Script_php_docker() {
  return (
    <div style={{maxWidth: 900, margin: "0 auto", padding: "2rem"}}>
      <Link to="/">← Home</Link>
      <h1 style={{fontSize: "1.5rem", margin: "0 0 1rem"}}>php-docker.sh</h1>
      <pre style={{whiteSpace: 'pre-wrap', fontFamily: 'ui-monospace, monospace', background: '#0b1020', color: '#e5e7eb', padding: '1rem', borderRadius: '.5rem'}}>{`php-docker.sh: Create Docker-backed php and composer launchers
Usage:
  php-docker.sh <php_version>

Example (following load.sh style):
  # Ensure this installer exists locally, then run it with PHP 8.3
  # load.sh php-docker 8.3

Description:
- Generates two wrapper scripts in "$HOME/.local/bin":
    - php       → runs PHP inside the byjg/php:<version>-cli Docker image
    - composer  → runs Composer inside the same image, persisting your ~/.composer dir
- Pulls the specified Docker image and marks the wrappers executable.
- Intended for environments where PHP/Composer are not installed natively.

Notes:
- Supported versions: 5.6, 7.0–7.4, 8.0–8.5
- Requires Docker installed and available on PATH.
- This script is idempotent and can be re-run to switch versions.`}</pre>
    </div>
  );
}
