#!/usr/bin/env bash
# remove.sh: 'load.sh remove': its options, the dry run, and the uninstall hook
source "$(dirname "${BASH_SOURCE[0]}")/../shared/lib.sh"

wrapper="${SHELLSCRIPT_HOME}/bin/jq"
tool_home="${SHELLSCRIPT_HOME}/jq"

step "remove: usage and wrong calls"
assert_exit 0 "${LOADER} remove -- --help"
assert_exit 2 "${LOADER} remove"
assert_exit 2 "${LOADER} remove -- --no-such-option jq"
assert_exit 2 "${LOADER} remove -- jq yq"
assert_exit 3 "${LOADER} remove -- no-such-script"

step "remove: nothing installed"
load remove -- jq
assert_log "Nothing to remove for jq"

step "remove: --dry-run takes nothing out"
load jq
load remove -- --dry-run --purge jq
assert_exists "$wrapper"
assert_exists "$tool_home"

step "remove: without --purge the folder stays"
load remove -- jq
assert_missing "$wrapper"
assert_exists "$tool_home"
assert_log "Use --purge to also remove tool folders"

step "remove: --purge, before or after the name"
load jq
load remove -- --purge jq
assert_missing "$tool_home"
load jq
load remove -- jq --purge
assert_missing "$tool_home"

step "remove: runs the uninstall hook of the script"
fixture hooked <<'PROBE'
#!/usr/bin/env bash
set -euo pipefail
case "${1-}" in
  --manifest) printf 'BIN_FILES=\nFOLDERS=\nSHELLRC_FILE=\nUNINSTALL_CMD=uninstall\n' ;;
  uninstall)  echo "hook ran" > "$HOME/e2e-hook-ran" ;;
esac
PROBE
assert_exit 0 "${LOADER} remove -- hooked"
assert_exists "${HOME}/e2e-hook-ran"

step "remove: a hook that is not one word is not run"
fixture bad-hook <<'PROBE'
#!/usr/bin/env bash
set -euo pipefail
case "${1-}" in
  --manifest) printf 'BIN_FILES=\nFOLDERS=\nSHELLRC_FILE=\nUNINSTALL_CMD=touch %s/e2e-bad-hook\n' "$HOME" ;;
esac
touch "$HOME/e2e-bad-hook-called-with-${1-nothing}"
PROBE
assert_exit 0 "${LOADER} remove -- bad-hook"
assert_log "Ignoring invalid UNINSTALL_CMD"
assert_missing "${HOME}/e2e-bad-hook"
assert_missing "${HOME}/e2e-bad-hook-called-with-touch"

finish
