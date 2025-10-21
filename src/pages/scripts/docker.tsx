// ------------------------------------------------------------------------------------
// Auto-generated from public/scripts/docker.sh — Do not edit.
// ------------------------------------------------------------------------------------

import React from "react";
import { Link } from "react-router-dom";

export default function Script_docker() {
  return (
    <div style={{maxWidth: 900, margin: "0 auto", padding: "2rem"}}>
      <Link to="/">← Home</Link>
      <h1 style={{fontSize: "1.5rem", margin: "0 0 1rem"}}>docker.sh</h1>
      <pre style={{whiteSpace: 'pre-wrap', fontFamily: 'ui-monospace, monospace', background: '#0b1020', color: '#e5e7eb', padding: '1rem', borderRadius: '.5rem'}}>{`docker.sh: Install the Docker Engine on Linux in a safe, idempotent, shell-friendly way

Usage:
  docker.sh [--help] [--dry-run] [--no-group] [--channel CHANNEL]

Examples (following load.sh style):
  # Install Docker with sensible defaults
  load.sh docker
  # Show help
  docker.sh --help
  # Simulate actions without making changes
  docker.sh --dry-run

Description:
- Installs Docker Engine using the official convenience script from get.docker.com
- Creates the "docker" group (if missing) and adds the current user to it (unless --no-group)
- Fixes $HOME/.docker permissions for the current user
- Idempotent: safe to re-run, it will skip already completed steps
- Non-interactive: suitable for CI; prints clear logs and exits on first error
- Supports a dry-run mode for previewing actions`}</pre>
    </div>
  );
}
