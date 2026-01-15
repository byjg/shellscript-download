- When coding following some principles: Eliminate All Stupid Yields (EASY) Code should be EASY. It it's hard, It is wrong. ; KISS – Keep It Stupidly Simple ; DRY – Don't Repeat Yourself

## Adding New Scripts to shellscript.download

When adding a new script to the project, follow these patterns:

### 1. Script Location and Structure
- Create the script in `public/scripts/<name>.sh`
- Use bash shebang: `#!/usr/bin/env bash`
- Include header comments with: usage, examples, and description
- Use strict mode: `set -euo pipefail` and `IFS=$'\n\t'`

### 2. Standard Helper Functions
Every script should include these helper functions:
```bash
log()  { printf "[<script-name>.sh] %s\n" "$*"; }
err()  { printf "[<script-name>.sh][ERROR] %s\n" "$*" >&2; }
run()  { if [[ "$DRY_RUN" == "1" ]]; then printf "[dry-run] %s\n" "$*"; else eval "$@"; fi }
require_cmd() { command -v "$1" >/dev/null 2>&1 || { err "Required command '$1' not found"; exit 1; }; }
print_usage() { cat <<'USAGE' ... USAGE }
```

### 3. Standard Flags Support
All scripts should support:
- `-h, --help` - Show usage and exit
- `--dry-run` - Print actions without executing them
- Additional custom flags as needed (e.g., `--version <ver>`)

### 4. Installation Patterns
- **Binary installations**: Extract to `$HOME/.shellscript/<tool-name>/<version>` (if the tool can have different versions)
- **Wrapper scripts**: Create in `$HOME/.shellscript/bin/` (automatically in PATH via load.sh framework)
- **Environment variables**: Write to `$HOME/.shellscript/shellrc/<tool-name>-init.sh`
- Wrappers should be simple: `exec "${HOME}/.shellscript/<tool>/current/bin/<cmd>" "$@"`

### 5. After Creating the Script
- Run `npm run build` to auto-generate:
  - React page in `src/pages/scripts/<name>.tsx`
  - Route in `src/generated/scriptRoutes.tsx`
  - Static HTML in `dist/scripts/<name>.html`
- The generated files should NOT be edited manually

### 6. Example Reference
See `public/scripts/maven.sh` for a complete example of:
- Binary download and extraction
- Simple wrapper creation
- Shell rc file generation
- Proper flag parsing and error handling