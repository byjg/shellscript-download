# Contributing to shellscript.download

## How it works (big picture)

Users install a single loader (`load.sh`) once. From then on they run:

```bash
load.sh <script-name>
```

`load.sh` downloads `<script-name>.sh` from the site, caches it locally, injects helpers and
standard environment variables, and then `exec`s the script. Scripts never need to define those
helpers themselves — they just use them.

---

## Adding a new script

### 1. Create the file

```
public/scripts/<name>.sh
```

### 2. Make it executable

```bash
chmod +x public/scripts/<name>.sh
git update-index --chmod=+x public/scripts/<name>.sh
```

Both steps are required: `chmod` sets the bit on disk, `git update-index` records it in the repository so it survives a fresh clone.

### 3. Required structure

```bash
#!/usr/bin/env bash
# <name>.sh: One-line description shown in the scripts list on the website.
#
# (optional additional header comments — shown on the script's detail page
#  when print_usage is absent)

set -euo pipefail

print_usage() {
  cat <<'USAGE'
load.sh <name> -- [options]

Short description of what this script does.

Options:
  -h, --help    Show this help and exit
  --dry-run     Print actions without executing them
  --manifest    Print installation manifest and exit

Examples:
  load.sh <name>
  load.sh <name> -- --dry-run
USAGE
}

print_manifest() {
  cat <<'MANIFEST'
BIN_FILES=<space-separated wrapper names, or empty>
FOLDERS=$HOME/.shellscript/<name>
SHELLRC_FILE=$HOME/.shellscript/shellrc/<name>-init.sh
MANIFEST
}

# Parse flags
DRY_RUN=0
while [[ ${1-} ]]; do
  case "$1" in
    -h|--help)   print_usage; exit 0 ;;
    --manifest)  print_manifest; exit 0 ;;
    --dry-run)   DRY_RUN=1 ;;
    *) err "Unknown option: $1"; print_usage; exit 2 ;;
  esac
  shift || true
done

# ... script body ...
```

#### What the generator reads from your file

| Part | Used for |
|---|---|
| Second line (`# <name>.sh: …`) | One-line description in the scripts list table |
| Consecutive `#` comment block at the top | Fallback detail page content (when `print_usage` is absent) |
| `print_usage` heredoc (`USAGE`…`USAGE`) | Content shown on the script's detail page |

---

## What `load.sh` injects

Every script is launched by `load.sh` via `exec`. Before handing off, `load.sh` exports the
following so scripts can use them without redeclaring:

### Helper functions

| Function | Behaviour |
|---|---|
| `log "message"` | Prints `[<script>.sh] message` to stdout |
| `err "message"` | Prints `[<script>.sh][ERROR] message` to stderr |
| `run "command"` | Runs the command normally, or prints `[dry-run] command` when `DRY_RUN=1` |
| `require_cmd curl` | Exits with an error if the command is not on `PATH` |
| `fetch "<url>"`, `download "<url>" "<file>"` | Read a URL to stdout, or save it to a file, with curl or wget. With `GITHUB_TOKEN` set they send it to `api.github.com`, and to no other host |
| `github_latest_tag jqlang/jq` | Prints the tag of the latest release of a GitHub repository (`jq-1.8.2`). It reads where `github.com/<owner>/<repo>/releases/latest` redirects to, with `final_url "<url>"`, so it costs no request of the GitHub API, which allows 60 an hour. Loaders older than it do not have it: fall back to the API, as `maven.sh` does |
| `already_installed "<url>" <file>`, `record_installed "<url>" <file>` | For a script that only knows the version by downloading: `record_installed` writes down what the URL served when it was installed, and `already_installed` is true while the URL still serves that, so the script can skip the download. See `aws-cli.sh` |
| `require_script jq` | Runs `load.sh jq` unless the `jq` command is already on `PATH`. A second argument names the command when it differs from the script |

`log` and `err` use `basename "$0"` so the script name in the output is always correct.

`run` reads `DRY_RUN` at call-time — scripts set it in their own flag parsing with no conflict.

### Environment variables

| Variable | Default value | Purpose |
|---|---|---|
| `SHELLSCRIPT_HOME` | `$HOME/.shellscript` | Base directory for all installations |
| `SHELLSCRIPT_BIN` | `$HOME/.shellscript/bin` | Wrapper scripts (on `PATH` via the loader) |
| `SHELLSCRIPT_SHELLRC` | `$HOME/.shellscript/shellrc` | Shell init snippets sourced at login |
| `SHELLSCRIPT_DOWNLOADS` | `$HOME/.shellscript/downloads` | Cached script downloads |

All four directories are created by `load.sh` before `exec`, so scripts don't need to
`mkdir -p` them (though doing so is harmless).

**Use these variables for paths instead of hardcoding `$HOME/.shellscript/…`:**

```bash
# Good
TOOL_HOME="${SHELLSCRIPT_HOME}/mytool"
BIN_DIR="${SHELLSCRIPT_BIN}"
SHELLRC_DIR="${SHELLSCRIPT_SHELLRC}"

# Bad — fragile and defeats the abstraction
TOOL_HOME="$HOME/.shellscript/mytool"
```

---

## Standard flags every script must support

| Flag | Behaviour |
|---|---|
| `-h, --help` | Print usage and exit 0 |
| `--dry-run` | Set `DRY_RUN=1`; all `run "…"` calls print instead of execute |
| `--manifest` | Print install manifest and exit 0 (required for `remove.sh`) |

### The `--manifest` format

`remove.sh` calls `<script>.sh --manifest` to know what to clean up. The output must be:

```
BIN_FILES=<space-separated names in $SHELLSCRIPT_BIN, or empty>
FOLDERS=<space-separated absolute paths, or empty>
SHELLRC_FILE=<absolute path to the shellrc snippet, or empty>
```

Paths may use `$HOME` — `remove.sh` expands them via `eval`.

---

## Installation conventions

| What | Where | Example |
|---|---|---|
| Tool binaries / extracted archives | `$SHELLSCRIPT_HOME/<tool>/<version>` | `$SHELLSCRIPT_HOME/maven/current` |
| Wrapper scripts | `$SHELLSCRIPT_BIN/<cmd>` | `$SHELLSCRIPT_BIN/mvn` |
| Shell init snippet | `$SHELLSCRIPT_SHELLRC/<tool>-init.sh` | `$SHELLSCRIPT_SHELLRC/maven-init.sh` |

Wrappers should be minimal. The path is written at install time, not looked up through `$HOME`
when the wrapper runs, so it keeps working for another user or with another `HOME`, as CI
systems run it. Write it with an unquoted heredoc, so that `${SHELLSCRIPT_HOME}` is expanded
and `\$@` is not:

```bash
cat >"${SHELLSCRIPT_BIN}/<cmd>" <<WRAP
#!/usr/bin/env bash
exec "${SHELLSCRIPT_HOME}/<tool>/current/bin/<cmd>" "\$@"
WRAP
```

---

## Local development

### Test your script without deploying

`load.sh --developer ./public/scripts <name>` runs your working copy instead of downloading it,
with the same helpers a published script gets. How to use it, how to test a change to `load.sh`
itself, and how to run the end-to-end tests are in
[Testing scripts before publishing](docs/development.md), which is also published with the
documentation.

### Syntax-check your script

```bash
bash -n public/scripts/<name>.sh
```

### Regenerate the website pages

After creating or editing a script, regenerate the React pages and routes:

```bash
npm run build
```

This runs the generator automatically (`prebuild` hook) and produces:
- `src/pages/scripts/<name>.tsx` — detail page (do not edit manually)
- `src/generated/scriptRoutes.tsx` — route registry (do not edit manually)
- `docs/scripts/<name>.md` — documentation page (do not edit manually)
- `dist/scripts/<name>.html` — static HTML

### Preview the site locally

```bash
npm run dev      # hot-reload dev server
npm run preview  # production build preview
```

---

## Scripts that depend on another file

A script that uses a file it shares with other scripts (`public/scripts/lib/`) names it in its
`SHARED_LIB` line:

```bash
SHARED_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/docker-wrapper.sh"
```

The loader reads that line and downloads the file next to the script, in
`$HOME/.shellscript/downloads/lib`, with the script and whenever it is missing. It checks its
signature like the one of the script: everything the loader downloads from shellscript.download is
signed when the site is deployed (see [Deployment](#deployment)). With `--developer`, the file is
read from the local folder. The script itself only stops, saying to run `load.sh --update`, when
the file is not there: a loader older than that does not download it.

## Scripts that depend on another script

A script that needs a tool installed by another script of the catalog calls `require_script`:

```bash
# A loader older than require_script cannot install jq: it has to be there already
if declare -F require_script >/dev/null; then require_script jq; else require_cmd jq; fi
```

`require_script jq` does nothing when `jq` is already available, and runs `load.sh jq` otherwise.
It writes to stderr only, so it can be called where the output of the script is being captured.
With `--dry-run` it prints what it would install and installs nothing.

---

## Documentation

The documentation is published on [opensource.byjg.com](https://opensource.byjg.com) from
`README.md` and the `docs/` folder, on every push to `main`.

- `docs/scripts/` is generated from `public/scripts/*.sh` by `npm run build`. Do not edit it: the
  folder is erased and written again on every build.
- Guides written by hand, such as `docs/docker-wrappers.md`, go directly in `docs/`.
- Pages are parsed as MDX there. Outside a code block, write `&lt;` instead of `<` and avoid `{`.

---

## Deployment

The website is a static Vite build (`npm run build` writes `dist/`), hosted on Cloudflare Pages
(`wrangler.toml`). It is deployed by the `deploy` job of `.github/workflows/e2e.yml`, on every
push to `main`, and not by Cloudflare from git:

1. `npm run build`
2. `scripts/sign-dist.sh dist` writes `<file>.sig` next to each script, `lib/` file, `install/loader`
   and `install/load-completion.sh`: a detached GPG signature by the key that also signs the
   [APT and RPM repositories](https://opensource.byjg.com/docs/opensource/guidelines/linux-packages),
   checked against `https://opensource.byjg.com/byjg.gpg` before anything is deployed
3. `wrangler pages deploy dist`

The signatures are made in the job and exist only on the site, never in the repository. How the
loader checks them is in [Signed downloads](docs/signatures.md). The
secrets (`GPG_PRIVATE_KEY`, `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`) are declared in
`inhouse/infra-automation` (`config.yml`), like the other secrets of the ByJG repositories.

---

## Testing

Every script has an end-to-end test in `tests_e2e/testcases/`, and a new script comes with
its own. `tests_e2e/run.sh <name>` runs it in a fresh container of each standard image, with
nothing installed on your machine: see
[Run the end-to-end tests](docs/development.md#run-the-end-to-end-tests).

A pull request runs, by itself, the test of each script it changes, and `all-scripts`.
`tests_e2e/run.sh --changed main` runs the same tests on your machine.

### Checklist before opening a PR

- [ ] File is executable: `chmod +x` and `git update-index --chmod=+x`
- [ ] `bash -n public/scripts/<name>.sh` passes
- [ ] Script supports `-h/--help`, `--dry-run`, `--manifest`
- [ ] `--manifest` output is correct (verified with `load.sh remove -- --dry-run <name>`)
- [ ] `--dry-run` prints all actions without side-effects
- [ ] Paths use `$SHELLSCRIPT_*` variables, not hardcoded `$HOME/.shellscript/…`
- [ ] No injected helper (`log`, `err`, `run`, `require_cmd`, `fetch`, `download`, ...) defined locally
- [ ] `tests_e2e/testcases/<name>.sh` exists and passes: `tests_e2e/run.sh <name> all-scripts`
- [ ] `npm run build` completes without errors
- [ ] Generated files (`src/pages/scripts/`, `src/generated/`, `docs/scripts/`) are included in the commit

---

## Opening a pull request

1. Fork the repository and create a branch from `main`.
2. Make your changes — one script per PR is preferred.
3. Run through the checklist above.
4. Open a PR with a clear title and a short description of what the script installs and why
   it belongs in the catalog.

Keep PRs focused. If you are adding a script, the PR should contain only:
- `public/scripts/<name>.sh`
- The auto-generated files produced by `npm run build`
