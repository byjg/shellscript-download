#!/usr/bin/env bash
# load.sh: the loader itself: how it is installed, its options, what it gives a script,
# require_script, and downloading a published script
source "$(dirname "${BASH_SOURCE[0]}")/../shared/lib.sh"


step "load: the installer puts it on the PATH of a new shell, with its completion"
assert_output "bash -ic 'command -v load.sh' 2>/dev/null" "$LOADER_PATH"
assert_exists "${SHELLSCRIPT_HOME}/shellrc/00-setup.sh"
assert_exists "${SHELLSCRIPT_HOME}/shellrc/01-load-completion.sh"

step "load: as root, installs for root, and never in the HOME of another user"
assert_exit 0 "sudo ${LOADER_PATH} --developer ${SCRIPTS_DIR} jq"
assert_exit 0 "sudo test -x /root/.shellscript/bin/jq"
assert_missing "${SHELLSCRIPT_HOME}/bin/jq"
# As 'sudo -E' does, where the sudoers keep HOME: written out, not to depend on them
assert_exit 1 "sudo env HOME=${HOME} ${LOADER_PATH} --developer ${SCRIPTS_DIR} jq"
assert_log "is not owned by root"
assert_missing "${SHELLSCRIPT_HOME}/bin/jq"

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

step "load: without gpgv, it downloads nothing"
# Ubuntu has gpgv, as apt needs it; Fedora and Alpine images do not
gpgv_path="$(command -v gpgv || true)"
[[ -z "$gpgv_path" ]] || sudo mv "$gpgv_path" "${gpgv_path}.e2e-off"
hash -r
before="$(cksum < "${SHELLSCRIPT_HOME}/downloads/jq.sh")"
assert_exit 3 "${LOADER} --update --dont-run jq"
assert_log "gpgv is needed"
assert_output "cksum < '${SHELLSCRIPT_HOME}/downloads/jq.sh'" "$before"
if [[ -n "$gpgv_path" ]]; then
  sudo mv "${gpgv_path}.e2e-off" "$gpgv_path"
elif on_image fedora; then
  sys_install gnupg2
else
  sys_install gpgv
fi
assert_command gpgv

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

step "load: a download that fails is tried again, and one that keeps failing stops"
# A server that fails the first time a path is asked for (503), and answers after; a path
# that starts with /never fails every time. A 503, and not a dropped connection, which
# GNU wget would try again by itself: each attempt the log counts is one of the loader.
sys_install python3
flaky_log="/tmp/e2e-flaky.log"
: > "$flaky_log"
cat > /tmp/e2e-flaky.py <<'PY'
import http.server, sys
seen = set()
class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        with open(sys.argv[1], "a") as log:
            log.write(self.path + "\n")
        if self.path.startswith("/never") or self.path not in seen:
            seen.add(self.path)
            self.send_error(503)
            return
        body = b"served-e2e\n"
        self.send_response(200)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, *args):
        pass
http.server.HTTPServer(("127.0.0.1", 8766), Handler).serve_forever()
PY
python3 /tmp/e2e-flaky.py "$flaky_log" &
flaky_server=$!
for _ in $(seq 50); do curl -fs http://127.0.0.1:8766/up >/dev/null 2>&1 && break; sleep 0.2; done
flaky="http://127.0.0.1:8766"
fixture flaky-probe <<'PROBE'
#!/usr/bin/env bash
set -euo pipefail
fetch "$1"
download "$2" /tmp/e2e-flaky-download
cat /tmp/e2e-flaky-download
PROBE
assert_exit 0 "${LOADER} flaky-probe -- ${flaky}/fetch-curl ${flaky}/download-curl 2>/dev/null"
assert_output "grep -c served-e2e '$LOG_FILE'" "2"
assert_output "grep -c '^/fetch-curl\$' '$flaky_log'" "2"
load_fails flaky-probe -- "${flaky}/never-curl" "${flaky}/download-unused"
assert_output "grep -c '^/never-curl\$' '$flaky_log'" "3"

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
# A download that fails is tried again with wget too
assert_exit 0 "${LOADER} flaky-probe -- ${flaky}/fetch-wget ${flaky}/download-wget 2>/dev/null"
assert_output "grep -c served-e2e '$LOG_FILE'" "2"
load_fails flaky-probe -- "${flaky}/never-wget" "${flaky}/download-unused"
assert_output "grep -c '^/never-wget\$' '$flaky_log'" "3"
kill "$flaky_server"
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

step "load: keeps the arguments of an install that worked, and only of that"
saved="${SHELLSCRIPT_HOME}/downloads"
load jq -- --version 1.7.1
assert_output "tr '\n' ' ' < '${saved}/jq.args'" "--version 1.7.1"
load yq
assert_exists "${saved}/yq.args"
assert_output "wc -c < '${saved}/yq.args' | tr -d ' '" "0"
load_fails jq -- --version 0.0.0
assert_exit 0 "${LOADER} jq -- --dry-run --version 1.8.0"
assert_exit 0 "${LOADER} jq -- --manifest"
assert_output "tr '\n' ' ' < '${saved}/jq.args'" "--version 1.7.1"

step "load: --upgrade installs again with those arguments: a given version stays"
assert_exit 0 "${LOADER} --upgrade"
assert_log "== jq: --version 1.7.1"
assert_log "== yq: (no arguments)"
assert_log "Upgraded: jq yq"
assert_output "jq --version" "jq-1.7.1"

step "load: --upgrade brings what follows the latest to it"
# As a yq installed with the defaults some time ago: an older one, and no version asked
load yq -- --version 4.44.1
: > "${saved}/yq.args"
assert_output "yq --version" "4.44.1"
assert_exit 0 "${LOADER} --upgrade yq"
assert_log "Upgraded: yq"
assert_no_output "yq --version" "4.44.1"
assert_output "jq --version" "jq-1.7.1"

step "load: --upgrade of what was installed before the arguments were kept"
rm -f "${saved}/yq.args"
assert_exit 0 "${LOADER} --upgrade yq"
assert_log "installed before the arguments were kept, with the defaults"

step "load: --upgrade leaves out what is not installed, and what cannot be upgraded"
fixture commands-e2e <<'PROBE'
#!/usr/bin/env bash
# commands-e2e.sh: a script whose arguments are commands
case "${1-}" in
  --manifest) printf 'BIN_FILES=\nFOLDERS=\nSHELLRC_FILE=$HOME/.shellscript/shellrc/commands-e2e-init.sh\nUPGRADE=no\n' ;;
  *) echo "# init" > "${SHELLSCRIPT_SHELLRC}/commands-e2e-init.sh"; touch "$HOME/e2e-commands-ran-$#" ;;
esac
PROBE
load commands-e2e -- start something
rm -f "${HOME}"/e2e-commands-ran-*
assert_exit 1 "${LOADER} --upgrade commands-e2e"
assert_log "cannot be upgraded this way"
assert_exit 1 "${LOADER} --upgrade kubectl"
assert_log "kubectl is not installed"
assert_exit 1 "${LOADER} --upgrade no-such-script-e2e"
assert_exit 0 "${LOADER} --upgrade"
assert_log "Upgraded: jq yq"
assert_output "ls ${HOME} | grep -c e2e-commands-ran || true" "0"

step "load: --upgrade says what failed, and fails"
fixture broken-e2e <<'PROBE'
#!/usr/bin/env bash
# broken-e2e.sh: a script that installed once, and fails since
case "${1-}" in
  --manifest) printf 'BIN_FILES=\nFOLDERS=\nSHELLRC_FILE=$HOME/.shellscript/shellrc/broken-e2e-init.sh\n' ;;
  *) [[ ! -e "${SHELLSCRIPT_SHELLRC}/broken-e2e-init.sh" ]] || exit 1
     echo "# init" > "${SHELLSCRIPT_SHELLRC}/broken-e2e-init.sh" ;;
esac
PROBE
load broken-e2e
assert_exit 1 "${LOADER} --upgrade"
assert_log "Upgraded: jq yq"
assert_log "Failed: broken-e2e"

step "load: purge forgets the arguments"
load remove -- jq --purge
assert_missing "${saved}/jq.args"
load remove -- yq --purge
rm -f "${SHELLSCRIPT_HOME}"/shellrc/*-e2e-init.sh

step "load: --completion"
rm -f "${SHELLSCRIPT_HOME}/shellrc/01-load-completion.sh"
assert_exit 0 "${LOADER} --completion"
assert_exists "${SHELLSCRIPT_HOME}/shellrc/01-load-completion.sh"

step "load: uses only what is signed by the key it has"
# A site of the test: the working copy, signed by a key of the test, served from here.
# The loader and the installer are the working copy too, with that site and that key.
if on_image fedora; then sys_install gnupg2; else sys_install gnupg; fi
sys_install python3
site="$(mktemp -d)"
url="http://127.0.0.1:8765"
GNUPGHOME="$(mktemp -d)"
export GNUPGHOME
gpg --batch --quiet --passphrase '' --quick-gen-key "e2e <e2e@example.org>" ed25519 sign never 2>/dev/null
test_key="$(gpg --export | base64 | tr -d '\n')"
to_site() { sed -e "s#https://shellscript.download#${url}#g" -e "s#https://packages.byjg.com/byjg.gpg#${url}/byjg.gpg#g" "$1"; }
sign() { gpg --batch --yes --quiet --detach-sign -o "$1.sig" "$1"; }
mkdir -p "${site}/scripts/lib" "${site}/install"
cp "${SCRIPTS_DIR}/jq.sh" "${site}/scripts/"
cp "${SCRIPTS_DIR}/lib/binary-install.sh" "${site}/scripts/lib/"
cp "${SCRIPTS_DIR}/yq.sh" "${site}/scripts/unsigned-e2e.sh"
cp "${SCRIPTS_DIR}/yq.sh" "${site}/scripts/other-key-e2e.sh"
cp /repo/install/load-completion.sh "${site}/install/"
to_site /repo/install/loader > "${site}/install/loader"
# The key of the loader, in place of the one of shellscript.download
to_site "${SCRIPTS_DIR}/load.sh" | awk -v key="$test_key" '
  /^SHELLSCRIPT_SIGNING_KEY="$/ { print "SHELLSCRIPT_SIGNING_KEY=\"" key "\""; skip = 1; next }
  skip && /^"$/ { skip = 0; next }
  !skip' > "${site}/scripts/load.sh"
gpg --export > "${site}/byjg.gpg"
for file in "${site}"/scripts/jq.sh "${site}"/scripts/lib/*.sh "${site}"/scripts/load.sh "${site}"/install/*; do sign "$file"; done
# Signed, by a key that is not the one of the loader
GNUPGHOME="$(mktemp -d)" bash -c 'gpg --batch --quiet --passphrase "" --quick-gen-key "other <other@example.org>" ed25519 sign never 2>/dev/null
  gpg --batch --quiet --detach-sign -o "$1.sig" "$1"' _ "${site}/scripts/other-key-e2e.sh"
python3 -m http.server 8765 --bind 127.0.0.1 --directory "$site" >/dev/null 2>&1 &
server=$!
for _ in $(seq 50); do curl -fs "${url}/byjg.gpg" >/dev/null && break; sleep 0.2; done
signed_loader="/tmp/e2e-signed-load.sh"
cp "${site}/scripts/load.sh" "$signed_loader"
chmod +x "$signed_loader"
cached="${SHELLSCRIPT_HOME}/downloads"

rm -f "${cached}/jq.sh" "${cached}/lib/binary-install.sh"
assert_exit 0 "${signed_loader} --dont-run jq"
assert_output "cmp '${site}/scripts/jq.sh' '${cached}/jq.sh' && echo same" "same"
assert_output "cmp '${site}/scripts/lib/binary-install.sh' '${cached}/lib/binary-install.sh' && echo same" "same"
assert_missing "${cached}/.jq.sh.download.sig"

# Changed after it was signed: refused, and what was there stays
echo "# tampered-e2e" >> "${site}/scripts/jq.sh"
assert_exit 3 "${signed_loader} --update --dont-run jq"
assert_log "is not signed by the key of shellscript.download"
assert_no_output "cat '${cached}/jq.sh'" "tampered-e2e"
assert_missing "${cached}/.jq.sh.download"
sign "${site}/scripts/jq.sh"

assert_exit 3 "${signed_loader} --dont-run unsigned-e2e"
assert_log "Failed to download ${url}/scripts/unsigned-e2e.sh"
assert_missing "${cached}/unsigned-e2e.sh"
assert_exit 3 "${signed_loader} --dont-run other-key-e2e"
assert_log "is not signed by the key of shellscript.download"
assert_missing "${cached}/other-key-e2e.sh"

# The file a script shares, which the loader downloads with it
echo "# tampered-e2e" >> "${site}/scripts/lib/binary-install.sh"
rm -f "${cached}/lib/binary-install.sh"
assert_exit 3 "${signed_loader} --update --dont-run jq"
assert_log "${url}/scripts/lib/binary-install.sh is not signed by the key of shellscript.download"
assert_missing "${cached}/lib/binary-install.sh"
sign "${site}/scripts/lib/binary-install.sh"
# Missing, with the script in the cache: downloaded again
assert_exit 0 "${signed_loader} --dont-run jq"
assert_output "cmp '${site}/scripts/lib/binary-install.sh' '${cached}/lib/binary-install.sh' && echo same" "same"
# The script says so when it runs without it, under a loader older than that
rm -f "${cached}/lib/binary-install.sh"
assert_exit 3 "bash ${cached}/jq.sh --help"
assert_log "lib/binary-install.sh, which this script needs, is missing: run 'load.sh --update'"

# A script that changes the system: one copy for every user, owned by root, with its lib
shared="/var/lib/shellscript/scripts"
cat > "${site}/scripts/shared-e2e.sh" <<'PROBE'
#!/usr/bin/env bash
# shared-e2e.sh: a script that changes the system
SYSTEM_SCRIPT=yes
SHARED_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/binary-install.sh"
[[ -f "$SHARED_LIB" ]] || exit 3
echo "ran from $(dirname "${BASH_SOURCE[0]}")"
PROBE
sign "${site}/scripts/shared-e2e.sh"
assert_exit 0 "${signed_loader} shared-e2e"
assert_log "Sharing shared-e2e.sh with every user of this machine"
assert_log "ran from ${shared}"
assert_output "stat -c '%U %a' ${shared}/shared-e2e.sh" "root 755"
assert_output "stat -c '%U %a' ${shared}/lib/binary-install.sh" "root 644"
assert_missing "${cached}/shared-e2e.sh"
# Run again: from there, with nothing downloaded
assert_exit 0 "${signed_loader} shared-e2e"
assert_log "ran from ${shared}"
assert_no_output "cat '${LOG_FILE}'" "Fetching"
# Changed after it was signed: refused, and the shared copy stays
echo "# tampered-e2e" >> "${site}/scripts/shared-e2e.sh"
assert_exit 3 "${signed_loader} --update --dont-run shared-e2e"
assert_no_output "cat '${shared}/shared-e2e.sh'" "tampered-e2e"
sign "${site}/scripts/shared-e2e.sh"
# One in the cache of the user, from an older loader: runs from there, until --update
# moves it where every user has it
sudo rm -f "${shared}/shared-e2e.sh"
cp "${site}/scripts/shared-e2e.sh" "${cached}/shared-e2e.sh"
chmod +x "${cached}/shared-e2e.sh"
assert_exit 0 "${signed_loader} shared-e2e"
assert_log "ran from ${cached}"
assert_exit 0 "${signed_loader} --update --dont-run shared-e2e"
assert_exists "${shared}/shared-e2e.sh"
assert_missing "${cached}/shared-e2e.sh"
sudo rm -rf "$shared"

# The completion, as the loader replaces its own files
echo "# tampered-e2e" >> "${site}/install/load-completion.sh"
assert_exit 3 "${signed_loader} --completion"
assert_no_output "cat '${SHELLSCRIPT_HOME}/shellrc/01-load-completion.sh'" "tampered-e2e"
sign "${site}/install/load-completion.sh"
assert_exit 0 "${signed_loader} --completion"

# The installer, with the key of its site
installed="${SHELLSCRIPT_HOME}/bin/load.sh"
cp "$installed" /tmp/e2e-installed-load.sh
echo "# tampered-e2e" >> "${site}/scripts/load.sh"
assert_exit 3 "sh ${site}/install/loader"
assert_log "is not signed by ${url}/byjg.gpg"
assert_output "cmp '${installed}' /tmp/e2e-installed-load.sh && echo kept" "kept"
sign "${site}/scripts/load.sh"
assert_exit 0 "sh ${site}/install/loader"
assert_output "cmp '${site}/scripts/load.sh' '${installed}' && echo installed" "installed"
assert_missing "${installed}.new"
assert_missing "${installed}.sig"

kill "$server"
unset GNUPGHOME
cp /tmp/e2e-installed-load.sh "$installed"
rm -f "${cached}/unsigned-e2e.sh" "${cached}/other-key-e2e.sh"
cp "${SCRIPTS_DIR}/jq.sh" "${cached}/jq.sh"
cp "${SCRIPTS_DIR}/lib/binary-install.sh" "${cached}/lib/binary-install.sh"
cp /repo/install/load-completion.sh "${SHELLSCRIPT_HOME}/shellrc/01-load-completion.sh"

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
assert_missing "${SHELLSCRIPT_HOME}/bin/.load.sh.download"

step "load: --update alone is refused with --developer"
assert_exit 2 "bash ${working_copy} --developer ${SCRIPTS_DIR} --update"
assert_log "not with --developer"

finish
