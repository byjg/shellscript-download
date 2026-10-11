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
# Back to the working copy: the steps that follow test it, not what is published
cp "${SCRIPTS_DIR}/jq.sh" "${SHELLSCRIPT_HOME}/downloads/jq.sh"
cp "${SCRIPTS_DIR}/lib/binary-install.sh" "${SHELLSCRIPT_HOME}/downloads/lib/binary-install.sh"

step "load: a script that is not published"
assert_exit 3 "${LOADER} --dont-run no-such-script-e2e"
assert_missing "${SHELLSCRIPT_HOME}/downloads/no-such-script-e2e.sh"

step "load: the latest release of a repository, without the GitHub API"
fixture latest-probe <<'PROBE'
#!/usr/bin/env bash
set -euo pipefail
echo "final=$(final_url https://github.com/jqlang/jq/releases/latest)"
echo "same=$(final_url https://shellscript.download/list.json)"
echo "tag=$(github_latest_tag jqlang/jq)"
github_latest_tag byjg/no-such-repository-e2e || echo "no-release"
PROBE
assert_exit 0 "${LOADER} latest-probe 2>/dev/null"
assert_log "final=https://github.com/jqlang/jq/releases/tag/jq-"
assert_log "same=https://shellscript.download/list.json"
assert_log "tag=jq-"
# The tag and nothing else: what follows it would end up in the version
assert_output "grep -Ec '^tag=jq-[0-9.]+\$' '$LOG_FILE'" "1"
assert_log "no-release"
# An unknown token would make the API refuse: the lookup does not go through it
assert_output "GITHUB_TOKEN=e2e-not-a-token ${LOADER} latest-probe 2>/dev/null" "tag=jq-"

step "load: GITHUB_TOKEN goes to the GitHub API, and nowhere else"
fixture token-probe <<'PROBE'
#!/usr/bin/env bash
set -euo pipefail
echo "api=[$(github_auth_header https://api.github.com/rate_limit)]"
echo "other=[$(github_auth_header https://shellscript.download/list.json)]"
echo "lookalike=[$(github_auth_header https://api.github.com.example.org/x)]"
PROBE
assert_output "GITHUB_TOKEN=e2e-fake ${LOADER} token-probe 2>/dev/null" "api=[Authorization: Bearer e2e-fake]"
assert_output "GITHUB_TOKEN=e2e-fake ${LOADER} token-probe 2>/dev/null" "other=[]"
assert_output "GITHUB_TOKEN=e2e-fake ${LOADER} token-probe 2>/dev/null" "lookalike=[]"
assert_output "env -u GITHUB_TOKEN ${LOADER} token-probe 2>/dev/null" "api=[]"

# GitHub refuses a token it does not know: that the call fails shows the token was sent
fixture token-fetch <<'PROBE'
#!/usr/bin/env bash
set -euo pipefail
fetch "$1" >/dev/null && echo "fetched"
PROBE
assert_exit 22 "GITHUB_TOKEN=e2e-not-a-token ${LOADER} token-fetch -- https://api.github.com/rate_limit"
assert_output "GITHUB_TOKEN=e2e-not-a-token ${LOADER} token-fetch -- https://shellscript.download/list.json 2>/dev/null" "fetched"

step "load: everything works with wget, where there is no curl"
if sys_install wget; then pass "installed wget"; else fail "could not install wget"; fi
curl_path="$(command -v curl)"
sudo mv "$curl_path" "${curl_path}.e2e-off"
hash -r
assert_no_command curl
assert_exit 0 "${LOADER} latest-probe 2>/dev/null"
assert_log "final=https://github.com/jqlang/jq/releases/tag/jq-"
assert_log "same=https://shellscript.download/list.json"
assert_log "tag=jq-"
# The tag and nothing else: what follows it would end up in the version
assert_output "grep -Ec '^tag=jq-[0-9.]+\$' '$LOG_FILE'" "1"
assert_log "no-release"
assert_output "${LOADER} token-fetch -- https://shellscript.download/list.json 2>/dev/null" "fetched"
assert_output "GITHUB_TOKEN=e2e-not-a-token ${LOADER} token-fetch -- https://shellscript.download/list.json 2>/dev/null" "fetched"
code=0
GITHUB_TOKEN=e2e-not-a-token $LOADER token-fetch -- https://api.github.com/rate_limit >"$LOG_FILE" 2>&1 || code=$?
if [[ "$code" != "0" ]]; then pass "the API refuses an unknown token sent by wget (exit ${code})"; else fail "wget did not send the token"; fi
assert_output "${LOADER} --update --dont-run yq" "Fetching"
cp "${SCRIPTS_DIR}/yq.sh" "${SHELLSCRIPT_HOME}/downloads/yq.sh"
cp "${SCRIPTS_DIR}/lib/binary-install.sh" "${SHELLSCRIPT_HOME}/downloads/lib/binary-install.sh"
load jq
assert_output "jq --version" "jq-"
load remove -- jq --purge
sudo mv "${curl_path}.e2e-off" "$curl_path"
hash -r

fixture ssh-agent-e2e <<'PROBE'
#!/usr/bin/env bash
# ssh-agent-e2e.sh: a script that only writes a shell init file
case "${1-}" in
  --manifest) printf 'BIN_FILES=\nFOLDERS=\nSHELLRC_FILE=$HOME/.shellscript/shellrc/ssh-agent-e2e-init.sh\n' ;;
  *) echo "# init" > "${SHELLSCRIPT_SHELLRC}/ssh-agent-e2e-init.sh" ;;
esac
PROBE

step "load: --list shows the catalog, --installed nothing yet"
assert_output "${LOADER} --list 2>/dev/null" "kubectl"
assert_output "${LOADER} --list 2>/dev/null | sed -n 1p" "INSTALLED"
assert_output "${LOADER} --list 2>/dev/null | grep '^jq ' | awk '{print \$2}'" "Download"
assert_exit 0 "${LOADER} --installed"
assert_log "Nothing installed with load.sh on this machine."

step "load: --list and --installed show the version of what is installed"
load jq -- --version 1.7.1
load ssh-agent-e2e
assert_output "${LOADER} --list 2>/dev/null | grep '^jq ' | awk '{print \$2}'" "1.7.1"
assert_output "${LOADER} --installed 2>/dev/null | grep '^jq '" "1.7.1"
assert_output "${LOADER} --installed 2>/dev/null | grep '^ssh-agent-e2e ' | awk '{print \$2}'" "yes"
assert_no_output "${LOADER} --installed 2>/dev/null" "yq"
assert_output "${LOADER} --installed 2>/dev/null | grep -c ." "4"

step "load: listing does not run a script that has no manifest"
fixture no-manifest-e2e <<'PROBE'
#!/usr/bin/env bash
# no-manifest-e2e.sh: a script that takes any option as a reason to run
touch "$HOME/e2e-listing-ran-a-script"
PROBE
assert_exit 0 "${LOADER} --installed"
assert_exit 0 "${LOADER} --list"
assert_missing "${HOME}/e2e-listing-ran-a-script"

step "load: what was removed is not listed, even with its folder kept"
load remove -- jq
assert_exists "${SHELLSCRIPT_HOME}/jq"
assert_no_output "${LOADER} --installed 2>/dev/null" "jq"
load remove -- jq --purge

step "load: a script that installs on the system is listed by what it recorded"
fixture system-e2e <<'PROBE'
#!/usr/bin/env bash
# system-e2e.sh: a script that records what it installed on the system
case "${1-}" in
  --manifest) printf 'BIN_FILES=never-created-e2e\nFOLDERS=$HOME/.shellscript/system-e2e\nSHELLRC_FILE=\nUNINSTALL_CMD=uninstall\n' ;;
esac
PROBE
mkdir -p "${SHELLSCRIPT_HOME}/system-e2e"
assert_no_output "${LOADER} --installed 2>/dev/null" "system-e2e"
echo "a-package" > "${SHELLSCRIPT_HOME}/system-e2e/installed-packages.conf"
assert_output "${LOADER} --installed 2>/dev/null | grep '^system-e2e ' | awk '{print \$2}'" "yes"
rm -rf "${SHELLSCRIPT_HOME}/system-e2e" "${SHELLSCRIPT_HOME}/shellrc/ssh-agent-e2e-init.sh"

step "load: --completion"
rm -f "${SHELLSCRIPT_HOME}/shellrc/01-load-completion.sh"
assert_exit 0 "${LOADER} --completion"
assert_exists "${SHELLSCRIPT_HOME}/shellrc/01-load-completion.sh"

# The last step: it downloads what is published, and after it this machine no longer has
# the working copy of the loader and of the scripts
step "load: --update alone updates the loader, its completion and the scripts, and runs nothing"
installed="${SHELLSCRIPT_HOME}/bin/load.sh"
cached="${SHELLSCRIPT_HOME}/downloads"
working_copy="/tmp/e2e-load.sh"
cp "$installed" "$working_copy"
echo "# stale-e2e" >> "$installed"
echo "# stale-e2e" >> "${cached}/jq.sh"
echo "# stale-e2e" >> "${cached}/lib/binary-install.sh"
rm -f "${SHELLSCRIPT_HOME}/shellrc/01-load-completion.sh"
fixture only-here-e2e <<'PROBE'
#!/usr/bin/env bash
touch "$HOME/e2e-update-ran-a-script"
PROBE
# The installed loader replaces itself while it runs
assert_exit 0 "${LOADER} --update 2>/dev/null"
cp "$LOG_FILE" /tmp/e2e-update.log
assert_output "grep '^load.sh ' /tmp/e2e-update.log" "updated"
assert_output "grep '^completion ' /tmp/e2e-update.log" "updated"
assert_output "grep '^jq.sh ' /tmp/e2e-update.log" "updated"
assert_output "grep '^only-here-e2e.sh ' /tmp/e2e-update.log" "could not be downloaded, kept as it is"
assert_no_output "cat '${installed}' '${cached}/jq.sh' '${cached}/lib/binary-install.sh'" "stale-e2e"
assert_output "head -c 2 '${installed}'; test -x '${installed}' && echo ' executable'" "#! executable"
assert_exists "${SHELLSCRIPT_HOME}/shellrc/01-load-completion.sh"
assert_exists "${cached}/only-here-e2e.sh"
assert_missing "${SHELLSCRIPT_HOME}/bin/jq"
assert_missing "${HOME}/e2e-update-ran-a-script"

step "load: --update again finds everything up to date"
assert_exit 0 "bash ${working_copy} --update 2>/dev/null"
cp "$LOG_FILE" /tmp/e2e-update.log
assert_output "grep '^load.sh ' /tmp/e2e-update.log" "up to date"
assert_output "grep '^completion ' /tmp/e2e-update.log" "up to date"
assert_output "grep '^jq.sh ' /tmp/e2e-update.log" "up to date"
assert_no_output "grep -v 'only-here-e2e' /tmp/e2e-update.log" "updated"

step "load: a download that fails leaves what was there"
echo "# kept-on-failure-e2e" >> "$installed"
assert_exit 0 "https_proxy=http://127.0.0.1:9 HTTPS_PROXY=http://127.0.0.1:9 bash ${working_copy} --update 2>/dev/null"
cp "$LOG_FILE" /tmp/e2e-update.log
assert_output "grep '^load.sh ' /tmp/e2e-update.log" "could not be downloaded, kept as it is"
assert_output "grep '^jq.sh ' /tmp/e2e-update.log" "could not be downloaded, kept as it is"
assert_output "cat '${installed}'" "kept-on-failure-e2e"
assert_missing "${SHELLSCRIPT_HOME}/bin/.tmp.load.sh"

step "load: --update alone is refused with --developer"
assert_exit 2 "bash ${working_copy} --developer ${SCRIPTS_DIR} --update"
assert_log "not with --developer"

finish
