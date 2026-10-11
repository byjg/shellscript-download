#!/usr/bin/env bash
# developer.sh: 'load.sh --developer <path>': the scripts of a local folder are the ones
# that run, to install, to remove, and for what a script needs
source "$(dirname "${BASH_SOURCE[0]}")/../shared/lib.sh"

# A working copy: the scripts of the repository, and some of the test itself. The same
# 'probe' is in the cache of the loader, saying where it ran from.
dev="/tmp/e2e-developer"
cp -r "$SCRIPTS_DIR" "$dev"
local_script() {
  cat > "${dev}/$1.sh"
  chmod +x "${dev}/$1.sh"
}
fixture probe <<'PROBE'
#!/usr/bin/env bash
echo "ran from the cache"
PROBE
local_script probe <<'PROBE'
#!/usr/bin/env bash
echo "ran from the developer folder"
PROBE

step "developer: the script of the folder runs, not the one of the cache"
assert_output "${LOADER} probe 2>/dev/null" "ran from the cache"
assert_output "${LOADER} --developer ${dev} probe 2>/dev/null" "ran from the developer folder"

step "developer: a script that is nowhere else runs, and is not copied to the cache"
local_script only-local <<'PROBE'
#!/usr/bin/env bash
set -euo pipefail
case "${1-}" in
  --manifest) printf 'BIN_FILES=e2e-local-tool\nFOLDERS=\nSHELLRC_FILE=\nUNINSTALL_CMD=uninstall\n' ;;
  uninstall)  echo "hook ran" > "$HOME/e2e-developer-hook" ;;
  *)          printf '#!/bin/sh\necho local tool\n' > "${SHELLSCRIPT_BIN}/e2e-local-tool"
              chmod +x "${SHELLSCRIPT_BIN}/e2e-local-tool"
              log "installed e2e-local-tool" ;;
esac
PROBE
assert_exit 0 "${LOADER} --developer ${dev} only-local"
assert_log "installed e2e-local-tool"
assert_missing "${SHELLSCRIPT_HOME}/downloads/only-local.sh"
assert_exit 3 "${LOADER} only-local"

step "developer: wrong calls"
assert_exit 3 "${LOADER} --developer ${dev} no-such-script"
assert_log "Developer script not found"
assert_exit 2 "${LOADER} --developer"

step "developer: a file the scripts share comes from the folder"
echo 'echo "the shared file of the developer folder" >&2' >> "${dev}/lib/binary-install.sh"
assert_output "${LOADER} --developer ${dev} jq -- --manifest" "the shared file of the developer folder"
assert_no_output "${LOADER} jq -- --manifest" "the shared file of the developer folder"

step "developer: the post-load hook is not called, nothing was downloaded"
local_script hooked <<'PROBE'
#!/usr/bin/env bash
postLoad() {
  touch "$HOME/e2e-developer-post-load"
}
if [[ "${1-}" == "--post-load" ]]; then postLoad; exit 0; fi
echo "hooked ran"
PROBE
assert_output "${LOADER} --developer ${dev} hooked 2>/dev/null" "hooked ran"
assert_missing "${HOME}/e2e-developer-post-load"

step "developer: what a script needs is installed from the folder too"
rm -f "${SHELLSCRIPT_HOME}/bin/e2e-local-tool"
local_script needs-local <<'PROBE'
#!/usr/bin/env bash
set -euo pipefail
require_script only-local e2e-local-tool
e2e-local-tool
PROBE
assert_output "${LOADER} --developer ${dev} needs-local 2>/dev/null" "local tool"

step "developer: remove reads the script of the folder"
assert_exit 0 "${LOADER} --developer ${dev} remove -- only-local"
assert_missing "${SHELLSCRIPT_HOME}/bin/e2e-local-tool"
assert_exists "${HOME}/e2e-developer-hook"
assert_exit 3 "${LOADER} --developer ${dev} remove -- no-such-script"
assert_log "Developer script not found"

finish
