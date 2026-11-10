#!/usr/bin/env bash
# dokku.sh: code shared by dokku.sh and dokku-docker.sh. Sourced, never run.
#
# The script sets, before calling these:
#   DOKKU_CMD      how the dokku command runs: "sudo dokku", or "docker exec -i dokku dokku"
#   DOKKU_RUNNING  1 when Dokku can answer now; empty in a dry run of the first install,
#                  when there is nothing to ask yet

# dokku_query <arguments>: what Dokku answers, or nothing when it is not running
dokku_query() {
  [[ "${DOKKU_RUNNING:-}" == "1" ]] || return 0
  bash -c "${DOKKU_CMD} $*" 2>/dev/null || true
}

# dokku_ok <arguments>: true when Dokku runs and the command succeeds
dokku_ok() {
  [[ "${DOKKU_RUNNING:-}" == "1" ]] && bash -c "${DOKKU_CMD} $*" >/dev/null 2>&1
}

# dokku_add_ssh_keys <file>: the keys of the file allowed to push, each one once,
# named admin, admin-2, ...
dokku_add_ssh_keys() {
  local file="$1" keys key fingerprint name n
  if [[ ! -s "$file" ]]; then
    log "No SSH key to add (${file} is empty or missing): add one with --ssh-key <file>"
    return 0
  fi
  require_cmd ssh-keygen
  keys="$(dokku_query ssh-keys:list)"
  while IFS= read -r key; do
    [[ -n "$key" && "$key" != \#* ]] || continue
    fingerprint="$(ssh-keygen -lf - <<<"$key" 2>/dev/null | awk '{print $2}')" || true
    if [[ -z "$fingerprint" ]]; then
      log "Skipping a line of ${file} that is not a public key"
      continue
    fi
    if grep -qF "$fingerprint" <<<"$keys"; then
      log "SSH key ${fingerprint} is already in Dokku"
      continue
    fi
    name="admin"; n=1
    while grep -qF "NAME=\"${name}\"" <<<"$keys"; do n=$((n + 1)); name="admin-${n}"; done
    log "Adding SSH key ${fingerprint} as '${name}'"
    run "printf '%s\n' $(printf '%q' "$key") | ${DOKKU_CMD} ssh-keys:add ${name}"
    keys+=$'\n'"${fingerprint} NAME=\"${name}\""
  done < "$file"
}

# dokku_install_plugin <name>=<url>: installs it, unless it is installed
dokku_install_plugin() {
  local name="${1%%=*}" url="${1#*=}"
  if dokku_ok plugin:installed "$name"; then
    log "Plugin '${name}' is already installed"
  else
    log "Installing plugin '${name}' from ${url}"
    run "${DOKKU_CMD} plugin:install ${url} --name ${name}"
  fi
}
