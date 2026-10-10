#!/usr/bin/env bash
# load.sh: the loader itself: how it is installed, its options, what it gives a script,
# require_script, and downloading a published script
source "$(dirname "${BASH_SOURCE[0]}")/../shared/lib.sh"


step "load: the installer puts it on the PATH of a new shell, with its completion"
assert_output "bash -ic 'command -v load.sh' 2>/dev/null" "$LOADER_PATH"
assert_exists "${SHELLSCRIPT_HOME}/shellrc/00-setup.sh"
assert_exists "${SHELLSCRIPT_HOME}/shellrc/01-load-completion.sh"

step "load: never runs as root"
assert_exit 1 "sudo ${LOADER_PATH} jq"
assert_log "must not be run as root"

step "load: usage and wrong calls"
assert_exit 0 "${LOADER} --help"
assert_exit 2 "${LOADER}"
assert_exit 2 "${LOADER} --no-such-option jq"

step "load: what a script receives"
fixture probe <<'PROBE'
#!/usr/bin/env bash
set -euo pipefail
log "to stdout"
err "to stderr"
run "echo ran"
DRY_RUN=1 run "echo not-run"
require_cmd bash
require_downloader
echo "home=${SHELLSCRIPT_HOME} bin=${SHELLSCRIPT_BIN} shellrc=${SHELLSCRIPT_SHELLRC} downloads=${SHELLSCRIPT_DOWNLOADS}"
case ":${PATH}:" in *":${SHELLSCRIPT_BIN}:"*) echo "bin-on-path" ;; esac
echo "args=$*"
fetch https://shellscript.download/list.json | grep -c '"name"' | sed 's/^/fetched-lines=/'
download https://shellscript.download/list.json /tmp/e2e-download.json && echo "downloaded=$(wc -c < /tmp/e2e-download.json | tr -d ' ')"
PROBE
assert_exit 0 "${LOADER} probe -- one two --three 2>/dev/null"
assert_log "[probe.sh] to stdout"
assert_log "ran"
assert_log "[dry-run] echo not-run"
assert_log "home=${SHELLSCRIPT_HOME} bin=${SHELLSCRIPT_HOME}/bin shellrc=${SHELLSCRIPT_HOME}/shellrc downloads=${SHELLSCRIPT_HOME}/downloads"
assert_log "bin-on-path"
assert_log "args=one two --three"
assert_log "fetched-lines="
assert_log "downloaded="

step "load: its own messages go to stderr, the output of the script stays clean"
assert_no_output "${LOADER} probe 2>/dev/null" ">_"
assert_no_output "${LOADER} probe 2>/dev/null" "to stderr"
assert_output "${LOADER} probe 2>&1 >/dev/null" "[probe.sh][ERROR] to stderr"

step "load: a missing command stops the script"
fixture needs-nothing <<'PROBE'
#!/usr/bin/env bash
set -euo pipefail
require_cmd no-such-command-e2e
echo "should not get here"
PROBE
assert_exit 1 "${LOADER} needs-nothing"
assert_log "Required command 'no-such-command-e2e' not found"

step "load: --dont-run does not run the script"
assert_exit 0 "${LOADER} --dont-run probe"
assert_log "Script ensured at"
assert_no_output "${LOADER} --dont-run probe" "to stdout"

step "load: require_script installs what a script needs"
fixture needs-jq <<'PROBE'
#!/usr/bin/env bash
set -euo pipefail
[[ "${1-}" != "--dry-run" ]] || DRY_RUN=1
require_script jq
[[ "${DRY_RUN:-0}" == "1" ]] || jq --version
PROBE
assert_exit 0 "${LOADER} needs-jq -- --dry-run"
assert_log "[dry-run] load.sh jq"
assert_missing "${SHELLSCRIPT_HOME}/bin/jq"
assert_exit 0 "${LOADER} needs-jq"
assert_log "'jq' is required: installing it"
assert_exists "${SHELLSCRIPT_HOME}/bin/jq"
assert_output "${LOADER} needs-jq 2>/dev/null" "jq-"
assert_no_output "${LOADER} needs-jq" "is required"
load remove -- jq --purge

step "load: downloads a published script, with what it depends on"
# Out of the cache, the loader has to fetch it, and the script the file it shares
rm -f "${SHELLSCRIPT_HOME}/downloads/jq.sh" "${SHELLSCRIPT_HOME}/downloads/lib/binary-install.sh"
assert_exit 0 "${LOADER} --dont-run jq"
assert_log "Fetching: https://shellscript.download/scripts/jq.sh"
assert_exists "${SHELLSCRIPT_HOME}/downloads/jq.sh"
assert_exists "${SHELLSCRIPT_HOME}/downloads/lib/binary-install.sh"
assert_no_output "${LOADER} --dont-run jq" "Fetching"
assert_output "${LOADER} --update --dont-run jq" "Fetching"

step "load: a script that is not published"
assert_exit 3 "${LOADER} --dont-run no-such-script-e2e"
assert_missing "${SHELLSCRIPT_HOME}/downloads/no-such-script-e2e.sh"

step "load: --list and --completion"
assert_output "${LOADER} --list 2>/dev/null" "kubectl"
rm -f "${SHELLSCRIPT_HOME}/shellrc/01-load-completion.sh"
assert_exit 0 "${LOADER} --completion"
assert_exists "${SHELLSCRIPT_HOME}/shellrc/01-load-completion.sh"

finish
