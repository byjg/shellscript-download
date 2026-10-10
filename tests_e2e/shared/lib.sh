#!/usr/bin/env bash
# lib.sh: what the tests share. Sourced by each test, never run.
#
# A test runs inside a container started by run.sh, as a regular user, with the
# scripts of the repository in /repo. It installs with the loader of the repository,
# in --developer mode, so that it tests the working copy and not what is published.

set -euo pipefail

SCRIPTS_DIR="/repo"
SHELLSCRIPT_HOME="${HOME}/.shellscript"
export PATH="${SHELLSCRIPT_HOME}/bin:${PATH}"

FAILURES=0
LOG_FILE="$(mktemp)"

step() { printf '\n== %s\n' "$*"; }
pass() { printf '  ok    %s\n' "$*"; }
fail() { printf '  FAIL  %s\n' "$*"; FAILURES=$((FAILURES + 1)); }

# The loader of the repository, and the same in --developer mode on its scripts
LOADER="bash ${SCRIPTS_DIR}/load.sh"
DEV="${LOADER} --developer ${SCRIPTS_DIR}"

# load <script> [-- options]: runs the loader of the repository. Its output is shown
# only when it fails, or always with 'run.sh --verbose'.
load() {
  if $DEV "$@" >"$LOG_FILE" 2>&1; then
    pass "load.sh $*"
    [[ -z "${E2E_VERBOSE:-}" ]] || sed 's/^/        /' "$LOG_FILE"
  else
    fail "load.sh $* (exit $?)"
    sed 's/^/        /' "$LOG_FILE"
  fi
}

# load_fails <script> [-- options]: the loader must stop with an error
load_fails() {
  if $DEV "$@" >"$LOG_FILE" 2>&1; then
    fail "load.sh $* should have failed"
  else
    pass "load.sh $* fails"
  fi
}

# assert_exit <code> "<command>": the command ends with that exit code. What it printed
# is left in $LOG_FILE.
assert_exit() {
  local code=0
  bash -c "$2" >"$LOG_FILE" 2>&1 || code=$?
  if [[ "$code" == "$1" ]]; then pass "exit $1: $2"; else fail "$2: expected exit $1, got ${code}"; fi
}

# assert_log "<text>": what the last load, load_fails or assert_exit printed has the text
assert_log() {
  if grep -qF -- "$1" "$LOG_FILE"; then pass "printed: $1"; else fail "did not print: $1"; sed 's/^/        /' "$LOG_FILE"; fi
}

# assert_no_output "<command>" "<text>": the command does not print the text
assert_no_output() {
  local output
  output="$(bash -c "$1" 2>&1)" || true
  if [[ "$output" == *"$2"* ]]; then fail "$1: printed '$2'"; else pass "$1 does not print: $2"; fi
}

# fixtures: a copy of the scripts of the repository, where a test adds scripts of its own
# to drive the loader. Run them with: $LOADER --developer "$FIXTURES" <script>
FIXTURES="/tmp/e2e-fixtures"
fixtures() {
  rm -rf "$FIXTURES"
  cp -r "$SCRIPTS_DIR" "$FIXTURES"
}
fixture() {
  cat > "${FIXTURES}/$1.sh"
  chmod +x "${FIXTURES}/$1.sh"
}

# home_snapshot: what is in the home, apart from the folders the loader always creates
home_snapshot() {
  # grep ends with 1 when it prints nothing: an empty home is not an error
  find "$HOME" -mindepth 1 2>/dev/null \
    | { grep -vx -e "${SHELLSCRIPT_HOME}" -e "${SHELLSCRIPT_HOME}/bin" -e "${SHELLSCRIPT_HOME}/shellrc" -e "${SHELLSCRIPT_HOME}/downloads" || true; } \
    | sort
}

# assert_output "<command>" "<text>": the command succeeds and prints the text
assert_output() {
  local output
  if output="$(bash -c "$1" 2>&1)" && [[ "$output" == *"$2"* ]]; then
    pass "$1 -> $2"
  else
    fail "$1: expected '$2', got '${output}'"
  fi
}

# hash -r: the shell remembers where it found a command, even after it is uninstalled
assert_command()    { hash -r; if command -v "$1" >/dev/null 2>&1; then pass "command: $1"; else fail "no command: $1"; fi; }
assert_no_command() { hash -r; if command -v "$1" >/dev/null 2>&1; then fail "command still there: $1"; else pass "no command: $1"; fi; }
assert_exists()  { if [[ -e "$1" ]]; then pass "exists: $1"; else fail "missing: $1"; fi; }
assert_missing() { if [[ -e "$1" || -L "$1" ]]; then fail "still there: $1"; else pass "gone: $1"; fi; }

# The version the 'current' link of a tool points at
current_version() { readlink "${SHELLSCRIPT_HOME}/$1/current"; }

# on_image <name>: true in a container of that image (ubuntu, fedora, alpine)
on_image() { [[ "$(. /etc/os-release && echo "$ID")" == "$1" ]]; }
skip() { printf '  skip  %s\n' "$*"; }

# sys_install <package>: installs with the package manager of the image, as a user
# would have done before running the script
sys_install() {
  if command -v apt-get >/dev/null 2>&1; then
    sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$1" >"$LOG_FILE" 2>&1
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y -q "$1" >"$LOG_FILE" 2>&1
  else
    sudo apk add -q "$1" >"$LOG_FILE" 2>&1
  fi
}

# start_docker_daemon: a container has no init system to start it. For the tests with
# '# privileged: yes'.
start_docker_daemon() {
  local i
  sudo sh -c 'dockerd >/tmp/dockerd.log 2>&1 &'
  for i in $(seq 1 60); do
    if sudo docker info >/dev/null 2>&1; then pass "the Docker daemon is running"; return 0; fi
    sleep 1
  done
  fail "the Docker daemon did not start"
  sudo tail -5 /tmp/dockerd.log | sed 's/^/        /'
}

# in_new_session "<command>": as the user does after logging in again, which is when a
# new group membership takes effect
in_new_session() { printf 'sudo -u %s -H bash -lc %q' "$(id -un)" "$1"; }

# manifest_value <script> <KEY> [arguments]: what the manifest of a script declares, with
# $HOME expanded. The arguments go before --manifest, for the scripts that take a version.
manifest_value() {
  local script="$1" key="$2" value
  shift 2
  value="$($DEV "$script" -- "$@" --manifest 2>/dev/null | sed -n "s/^${key}=//p")"
  eval "printf '%s' \"${value}\""
}

# need_docker: for the tests of what runs on Docker. Installs it with our own script
# (with the package manager on Alpine, which the installer of Docker does not cover),
# starts the daemon, and starts the test again in a new session, where the user is in
# the 'docker' group. Needs '# privileged: yes'.
need_docker() {
  if docker info >/dev/null 2>&1; then return 0; fi
  if [[ -n "${E2E_DOCKER_READY:-}" ]]; then
    fail "the user cannot use Docker in the new session"
    finish
  fi

  step "prepare: Docker"
  if on_image alpine; then
    if sys_install docker && sudo addgroup "$(id -un)" docker >/dev/null; then pass "installed docker"; else fail "could not install docker"; fi
  else
    load docker
  fi
  start_docker_daemon
  [[ "$FAILURES" == "0" ]] || finish
  exec sudo -u "$(id -un)" -H env E2E_DOCKER_READY=1 E2E_VERBOSE="${E2E_VERBOSE:-}" bash "$0"
}

# finish: the last line of every test
finish() {
  rm -f "$LOG_FILE"
  if [[ "$FAILURES" -gt 0 ]]; then
    printf '\n%s check(s) failed\n' "$FAILURES"
    exit 1
  fi
  printf '\nAll checks passed\n'
}

# What the manifest of a script says 'load.sh remove' takes out, checked against the disk
assert_removed() {
  local name="$1" bin shellrc
  for bin in $(manifest_value "$name" BIN_FILES); do
    assert_missing "${SHELLSCRIPT_HOME}/bin/${bin}"
  done
  shellrc="$(manifest_value "$name" SHELLRC_FILE)"
  [[ -z "$shellrc" ]] || assert_missing "$shellrc"
}

# What 'load.sh remove --purge' takes out too. Read the folders before the purge: the
# manifest of some scripts depends on what is installed.
assert_purged() {
  local folder
  for folder in "$@"; do assert_missing "$folder"; done
}

# ---------------------------------------------------------------------------
# Shared tests
# ---------------------------------------------------------------------------

# test_single_binary <name> <old_version> "<version command>" [check]
# For the tools installed by lib/binary-install.sh: the latest version by default, one
# older version, remove and purge. <version command> prints the installed version.
# <check> is a function of the test that proves the tool works; it runs after each
# install. The containers have bash-completion: a tool whose manifest declares a shell
# init file must have its completion registered.
test_single_binary() {
  local name="$1" old_version="$2" version_cmd="$3" check="${4:-}"
  local tool_home="${SHELLSCRIPT_HOME}/${name}" wrapper="${SHELLSCRIPT_HOME}/bin/${name}"
  local latest shellrc
  shellrc="$(manifest_value "$name" SHELLRC_FILE)"

  step "${name}: install with the defaults (latest version)"
  load "$name"
  assert_exists "$wrapper"
  latest="$(current_version "$name")"
  assert_exists "${tool_home}/${latest}/${name}"
  assert_output "$version_cmd" "$latest"
  [[ -z "$check" ]] || "$check"

  if [[ -n "$shellrc" ]]; then
    step "${name}: command completion"
    assert_exists "$shellrc"
    assert_output ". /usr/share/bash-completion/bash_completion; . '${shellrc}'; complete -p ${name}" "${name}"
  fi

  step "${name}: install again changes nothing"
  load "$name"
  assert_output "cat '$LOG_FILE'" "already installed"

  step "${name}: install an older version (--version ${old_version})"
  if [[ "$latest" == "$old_version" ]]; then
    fail "the older version of the test is the latest one: pick another"
  fi
  load "$name" -- --version "$old_version"
  assert_output "$version_cmd" "$old_version"
  assert_exists "${tool_home}/${latest}/${name}"
  [[ -z "$check" ]] || "$check"

  step "${name}: a version that does not exist stops and changes nothing"
  load_fails "$name" -- --version 0.0.0
  assert_output "$version_cmd" "$old_version"
  assert_missing "${tool_home}/0.0.0"

  step "${name}: the wrapper does not depend on HOME"
  assert_output "HOME=/tmp/another-home ${version_cmd}" "$old_version"

  step "${name}: remove keeps the folder"
  load remove -- "$name"
  assert_missing "$wrapper"
  [[ -z "$shellrc" ]] || assert_missing "$shellrc"
  assert_exists "$tool_home"

  step "${name}: purge removes the folder"
  load "$name" -- --version "$old_version"
  load remove -- "$name" --purge
  assert_missing "$wrapper"
  assert_missing "$tool_home"
}

# test_system_package <name> <command> [check]
# For the scripts that install one package with lib/system-packages.sh: install, remove
# and purge, and a package that was already there is left alone. <check> is a function
# of the test that proves the tool works; it runs after the install.
test_system_package() {
  local name="$1" cmd="$2" check="${3:-}"
  local tool_home="${SHELLSCRIPT_HOME}/${name}"
  local state="${tool_home}/installed-packages.conf"

  step "${name}: install with the defaults"
  load "$name"
  assert_command "$cmd"
  assert_output "cat '${state}'" "$name"
  [[ -z "$check" ]] || "$check"

  step "${name}: install again changes nothing"
  load "$name"
  assert_output "cat '$LOG_FILE'" "already installed"

  step "${name}: remove uninstalls the package and keeps the folder"
  load remove -- "$name"
  assert_no_command "$cmd"
  assert_exists "$tool_home"

  step "${name}: purge removes the folder"
  load remove -- "$name" --purge
  assert_missing "$tool_home"

  step "${name}: a package that was already installed is left alone"
  if sys_install "$name"; then pass "installed ${name} with the package manager"; else fail "could not install ${name}"; fi
  load "$name"
  assert_missing "$state"
  load remove -- "$name" --purge
  assert_output "cat '$LOG_FILE'" "was not installed by this script"
  assert_command "$cmd"
}

# test_java_vendor <vendor>
# For the java-<vendor> installers of lib/java-install.sh: Java 21 by default, then
# Java 25, the active Java and java-use, remove and purge.
test_java_vendor() {
  local vendor="$1" name="java-$1"
  local vendor_home="${SHELLSCRIPT_HOME}/java-$1" java_home="${SHELLSCRIPT_HOME}/java"
  local shellrc="${SHELLSCRIPT_HOME}/shellrc/java-init.sh"
  local java="${java_home}/current/bin/java"

  step "${name}: install with the defaults (Java 21)"
  load "$name"
  assert_exists "${vendor_home}/21/bin/java"
  assert_output "${java} -version" 'version "21.'
  assert_output ". '${shellrc}'; echo \$JAVA_HOME; java -version" 'version "21.'
  assert_output ". '${shellrc}'; echo \$JAVA_HOME" "${java_home}/current"

  step "${name}: install again changes nothing"
  load "$name"
  assert_output "cat '$LOG_FILE'" "already installed"

  step "${name}: install another version (--version 25), which becomes the active Java"
  load "$name" -- --version 25
  assert_output "${java} -version" 'version "25.'
  assert_exists "${vendor_home}/21/bin/java"

  step "${name}: java-use picks another installed Java in one shell"
  assert_output ". '${shellrc}'; java-use ${vendor} 21; java -version" 'version "21.'
  assert_output "${java} -version" 'version "25.'

  step "${name}: a version that is not LTS asks first, and installs nothing on 'n'"
  assert_output "echo n | bash ${SCRIPTS_DIR}/load.sh --developer ${SCRIPTS_DIR} ${name} -- --version 22" "Aborted."
  assert_missing "${vendor_home}/22"

  step "${name}: remove keeps the folders"
  load remove -- "$name"
  assert_missing "$shellrc"
  assert_exists "${vendor_home}/21/bin/java"

  step "${name}: purge removes the versions and the active Java"
  load "$name" -- --version 25
  load remove -- "$name" --purge
  assert_purged "$vendor_home" "$java_home"
  assert_missing "$shellrc"
}

# test_java_build_tool <name> <old_version> "<version command>" "<latest text>" "<old text>"
# For the tools that need Java to run (maven, ant): the latest version by default, one
# older version, remove and purge. Java comes from java-temurin.
test_java_build_tool() {
  local name="$1" old_version="$2" version_cmd="$3" latest_text="$4" old_text="$5"
  local tool_home="${SHELLSCRIPT_HOME}/${name}" java_rc="${SHELLSCRIPT_HOME}/shellrc/java-init.sh"
  local shellrc bin
  shellrc="$(manifest_value "$name" SHELLRC_FILE)"

  step "${name}: needs Java"
  load java-temurin

  step "${name}: install with the defaults (latest version)"
  load "$name"
  for bin in $(manifest_value "$name" BIN_FILES); do
    assert_exists "${SHELLSCRIPT_HOME}/bin/${bin}"
  done
  assert_exists "$shellrc"
  assert_output ". '${java_rc}'; ${version_cmd}" "$latest_text"

  step "${name}: install an older version (--version ${old_version})"
  load "$name" -- --version "$old_version"
  assert_output ". '${java_rc}'; ${version_cmd}" "$old_text"

  step "${name}: a version that does not exist stops and changes nothing"
  load_fails "$name" -- --version 0.0.0
  assert_output ". '${java_rc}'; ${version_cmd}" "$old_text"

  step "${name}: the wrapper does not depend on HOME"
  assert_output ". '${java_rc}'; HOME=/tmp/another-home ${version_cmd}" "$old_text"

  step "${name}: remove keeps the folder"
  load remove -- "$name"
  assert_removed "$name"
  assert_exists "$tool_home"

  step "${name}: purge removes the folder"
  load "$name" -- --version "$old_version"
  load remove -- "$name" --purge
  assert_removed "$name"
  assert_purged "$tool_home"
}

# test_docker_wrapper <script> <tool> <command> <version> <older_version> "<version text>"
# For the Docker-backed wrappers of lib/docker-wrapper.sh (php-docker, node-docker): a
# version, an older one, the options they share, remove and purge. <tool> is the folder
# under ~/.shellscript, <command> the main wrapper, and <version text> what
# '<command> --version' prints, with %s where the version goes.
# The test defines in_container <command> "<shell command>": it prints the command line
# that runs a shell command inside the container of the wrapper. It may define
# extra_checks, which runs after the first install, and container_path <path>, which
# prints where a folder of the host is inside the container when it is not the same path.
test_docker_wrapper() {
  local script="$1" tool="$2" cmd="$3" version="$4" older="$5" version_text="$6"
  local tool_home="${SHELLSCRIPT_HOME}/${tool}" shellrc="${SHELLSCRIPT_HOME}/shellrc/${tool}-init.sh"
  local project="/tmp/e2e-project" extra="${HOME}/e2e-extra" postinstall="/tmp/e2e-postinstall.sh"
  local user bin extra_inside
  user="$(id -un)"
  extra_inside="$extra"
  if declare -F container_path >/dev/null; then extra_inside="$(container_path "$extra")"; fi
  # shellcheck disable=SC2059  # the format comes from the test
  local text_version text_older
  text_version="$(printf "$version_text" "$version")"
  text_older="$(printf "$version_text" "$older")"
  mkdir -p "$project" "$extra"
  echo "from the extra volume" > "${extra}/file.txt"
  printf '#!/bin/sh\necho "post-install ran" > /e2e-postinstall\n' > "$postinstall"
  # The wrappers mount the current folder: work from a project, as a user does
  cd "$project"

  step "${script}: a version is required"
  load_fails "$script"

  step "${script}: install version ${version}"
  load "$script" -- "$version"
  for bin in $(manifest_value "$script" BIN_FILES "$version"); do
    assert_exists "${SHELLSCRIPT_HOME}/bin/${bin}"
  done
  assert_output "${cmd} --version" "$text_version"
  assert_output "${cmd}${version} --version" "$text_version"
  if declare -F extra_checks >/dev/null; then extra_checks; fi

  step "${script}: runs in the current folder, as the user"
  assert_output "cd ${project} && $(in_container "$cmd" 'pwd')" "$project"
  assert_output "cd ${project} && $(in_container "$cmd" 'id -u')" "$(id -u)"
  assert_output "cd ${project} && $(in_container "$cmd" 'touch made-inside') && stat -c %U made-inside" "$user"

  step "${script}: forwards the environment"
  assert_output "E2E_FORWARDED=hello $(in_container "$cmd" 'printenv E2E_FORWARDED')" "hello"

  step "${script}: install an older version (${older}), which becomes the default"
  load "$script" -- "$older"
  assert_output "${cmd} --version" "$text_older"
  assert_output "${cmd}${older} --version" "$text_older"
  assert_output "${cmd}${version} --version" "$text_version"

  step "${script}: --add installs a package in the image, and keeps it for the next installs"
  assert_exit 127 "$(in_container "$cmd" 'jq --version')"
  load "$script" -- "$older" --add jq
  assert_output "cat '${tool_home}/packages.conf'" "jq"
  assert_output "$(in_container "$cmd" 'jq --version')" "jq-"
  load "$script" -- "$older"
  assert_output "$(in_container "$cmd" 'jq --version')" "jq-"

  step "${script}: --skip packages leaves them out of this install only"
  load "$script" -- "$older" --skip packages
  assert_exit 127 "$(in_container "$cmd" 'jq --version')"
  assert_output "cat '${tool_home}/packages.conf'" "jq"

  step "${script}: --volume mounts another folder"
  assert_no_output "cd ${project} && $(in_container "$cmd" "cat ${extra_inside}/file.txt")" "from the extra volume"
  load "$script" -- "$older" --volume "$extra"
  assert_output "cat '${tool_home}/volumes.conf'" "$extra"
  assert_output "cd ${project} && $(in_container "$cmd" "cat ${extra_inside}/file.txt")" "from the extra volume"

  step "${script}: --postinstall runs a script in the image, --no-postinstall forgets it"
  load "$script" -- "$older" --postinstall "$postinstall"
  assert_exists "${tool_home}/${older}/postinstall.sh"
  assert_output "$(in_container "$cmd" 'cat /e2e-postinstall')" "post-install ran"
  load "$script" -- "$older" --no-postinstall
  assert_missing "${tool_home}/${older}/postinstall.sh"
  assert_no_output "$(in_container "$cmd" 'cat /e2e-postinstall')" "post-install ran"

  step "${script}: the manifest of one version, and of everything"
  assert_output "${DEV} ${script} -- ${older} --manifest 2>/dev/null" "FOLDERS=\$HOME/.shellscript/${tool}/${older}"
  assert_output "${DEV} ${script} -- --manifest 2>/dev/null" "${cmd}${version}"
  assert_output "${DEV} ${script} -- --manifest 2>/dev/null" "${cmd}${older}"

  step "${script}: remove takes out the wrappers of every version, keeps the folder"
  load remove -- "$script"
  assert_missing "${SHELLSCRIPT_HOME}/bin/${cmd}"
  assert_missing "${SHELLSCRIPT_HOME}/bin/${cmd}${version}"
  assert_missing "${SHELLSCRIPT_HOME}/bin/${cmd}${older}"
  assert_missing "$shellrc"
  assert_exists "$tool_home"

  step "${script}: purge removes the folder"
  load "$script" -- "$older"
  load remove -- "$script" --purge
  assert_missing "${SHELLSCRIPT_HOME}/bin/${cmd}"
  assert_missing "$tool_home"
}
