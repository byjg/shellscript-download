#!/usr/bin/env bash
# all-scripts.sh: what every script of the catalog must do: --help, --manifest, refuse an
# option it does not know, and change nothing with --dry-run
source "$(dirname "${BASH_SOURCE[0]}")/../shared/lib.sh"

# The loader and 'remove' install nothing. byjg-gluo needs its arguments first.
NO_MANIFEST=" load remove byjg-gluo "
# The Docker-backed wrappers have no --dry-run. ssh-agent has its own test, with the
# OpenSSH client it needs.
NO_DRY_RUN=" load remove byjg-gluo node-docker php-docker ssh-agent "

# aws-cli checks for unzip before anything else
if sys_install unzip; then pass "installed unzip"; else fail "could not install unzip"; fi

for file in "${SCRIPTS_DIR}"/*.sh; do
  name="$(basename "$file" .sh)"
  step "${name}"

  assert_exit 0 "${LOADER} ${name} -- --help"
  assert_log "$name"

  if [[ "$NO_MANIFEST" != *" ${name} "* ]]; then
    assert_exit 0 "${LOADER} ${name} -- --manifest"
    assert_log "FOLDERS="
    assert_log "SHELLRC_FILE="
  fi

  code=0
  $LOADER "$name" -- --no-such-option-e2e >"$LOG_FILE" 2>&1 || code=$?
  if [[ "$code" != "0" ]]; then pass "refuses an unknown option (exit ${code})"; else fail "accepted an unknown option"; fi

  if [[ "$name" == "byjg-repo" ]] && on_image alpine; then
    skip "--dry-run: byjg-repo has no packages for this image, see its own test"
  elif [[ "$NO_DRY_RUN" != *" ${name} "* ]]; then
    before="$(home_snapshot)"
    assert_exit 0 "${LOADER} ${name} -- --dry-run"
    if [[ "$(home_snapshot)" == "$before" ]]; then
      pass "--dry-run changed nothing"
    else
      fail "--dry-run changed the home:"
      diff <(echo "$before") <(home_snapshot) | sed 's/^/        /'
    fi
  fi
done

finish
