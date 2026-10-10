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

# load <script> [-- options]: runs the loader of the repository. Its output is shown
# only when it fails.
load() {
  if bash "${SCRIPTS_DIR}/load.sh" --developer "${SCRIPTS_DIR}" "$@" >"$LOG_FILE" 2>&1; then
    pass "load.sh $*"
  else
    fail "load.sh $* (exit $?)"
    sed 's/^/        /' "$LOG_FILE"
  fi
}

# load_fails <script> [-- options]: the loader must stop with an error
load_fails() {
  if bash "${SCRIPTS_DIR}/load.sh" --developer "${SCRIPTS_DIR}" "$@" >"$LOG_FILE" 2>&1; then
    fail "load.sh $* should have failed"
  else
    pass "load.sh $* fails"
  fi
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

assert_exists()  { if [[ -e "$1" ]]; then pass "exists: $1"; else fail "missing: $1"; fi; }
assert_missing() { if [[ -e "$1" || -L "$1" ]]; then fail "still there: $1"; else pass "gone: $1"; fi; }

# The version the 'current' link of a tool points at
current_version() { readlink "${SHELLSCRIPT_HOME}/$1/current"; }

# finish: the last line of every test
finish() {
  rm -f "$LOG_FILE"
  if [[ "$FAILURES" -gt 0 ]]; then
    printf '\n%s check(s) failed\n' "$FAILURES"
    exit 1
  fi
  printf '\nAll checks passed\n'
}

# ---------------------------------------------------------------------------
# Shared tests
# ---------------------------------------------------------------------------

# test_single_binary <name> <old_version> [check]
# For the tools installed by lib/binary-install.sh: the latest version by default, one
# older version, remove and purge. <check> is a function of the test that proves the
# tool works; it runs after each install.
test_single_binary() {
  local name="$1" old_version="$2" check="${3:-}"
  local tool_home="${SHELLSCRIPT_HOME}/${name}" wrapper="${SHELLSCRIPT_HOME}/bin/${name}" latest

  step "${name}: install with the defaults (latest version)"
  load "$name"
  assert_exists "$wrapper"
  latest="$(current_version "$name")"
  assert_exists "${tool_home}/${latest}/${name}"
  assert_output "${name} --version" "$latest"
  [[ -z "$check" ]] || "$check"

  step "${name}: install again changes nothing"
  load "$name"
  assert_output "cat '$LOG_FILE'" "already installed"

  step "${name}: install an older version (--version ${old_version})"
  if [[ "$latest" == "$old_version" ]]; then
    fail "the older version of the test is the latest one: pick another"
  fi
  load "$name" -- --version "$old_version"
  assert_output "${name} --version" "$old_version"
  assert_exists "${tool_home}/${latest}/${name}"
  [[ -z "$check" ]] || "$check"

  step "${name}: a version that does not exist stops and changes nothing"
  load_fails "$name" -- --version 0.0.0
  assert_output "${name} --version" "$old_version"
  assert_missing "${tool_home}/0.0.0"

  step "${name}: the wrapper does not depend on HOME"
  assert_output "HOME=/nonexistent ${name} --version" "$old_version"

  step "${name}: remove keeps the folder"
  load remove -- "$name"
  assert_missing "$wrapper"
  assert_exists "$tool_home"

  step "${name}: purge removes the folder"
  load "$name" -- --version "$old_version"
  load remove -- "$name" --purge
  assert_missing "$wrapper"
  assert_missing "$tool_home"
}
