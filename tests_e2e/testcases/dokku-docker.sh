#!/usr/bin/env bash
# dokku-docker.sh: Dokku in a container: an older version with a domain, ports, the SSH
# keys and a plugin, run again, the latest version keeps the data and the plugin, remove
# keeps the data, purge
# vm: yes
# needs: docker
source "$(dirname "${BASH_SOURCE[0]}")/../shared/lib.sh"

tool_home="${SHELLSCRIPT_HOME}/dokku-docker"
state="${SYSTEM_STATE}/dokku-docker"
older="0.38.33"
latest="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/dokku/dokku/releases/latest)"
latest="${latest##*/v}"
plugin="maintenance=https://github.com/dokku/dokku-maintenance.git"
in_dokku="docker exec dokku dokku"
keys="$(grep -c '^ssh-' "${HOME}/.ssh/authorized_keys")"

step "dokku-docker: --version starts that version, with the domain, the ports, the keys and a plugin"
load dokku-docker -- --version "$older" --hostname dokku.e2e.test --http-port 8081 --plugin "$plugin"
assert_output "docker inspect -f '{{.Config.Image}} {{.State.Health.Status}}' dokku" "dokku/dokku:${older} healthy"
assert_output "docker port dokku 80" ":8081"
assert_output "docker port dokku 22" ":3022"
assert_output "${in_dokku} domains:report --global --domains-global-vhosts" "dokku.e2e.test"
assert_exit 0 "[ \$(${in_dokku} ssh-keys:list | wc -l) -eq ${keys} ]"
assert_exit 0 "${in_dokku} plugin:installed maintenance"
assert_output "sudo cat /var/lib/dokku/plugin-list" "maintenance: https://github.com/dokku/dokku-maintenance.git"
assert_exit 0 "${in_dokku} apps:create e2e-app"
assert_output "cat '${state}/config'" "VERSION=${older}"
assert_output "cat '${state}/installed-by'" "$(id -un)"

step "dokku-docker: run again keeps the container, its options, the keys and the plugin"
created="$(docker inspect -f '{{.Created}}' dokku)"
load dokku-docker -- --plugin "$plugin"
assert_log "runs Dokku ${older}, as asked"
assert_log "is already in Dokku"
assert_log "Plugin 'maintenance' is already installed"
assert_output "docker inspect -f '{{.Created}}' dokku" "$created"
assert_exit 0 "[ \$(${in_dokku} ssh-keys:list | wc -l) -eq ${keys} ]"
assert_exit 0 "[ \$(sudo grep -c maintenance /var/lib/dokku/plugin-list) -eq 1 ]"

step "dokku-docker: --version with the latest replaces the container; the app, keys and plugin stay"
load dokku-docker -- --version "$latest"
assert_log "Replacing the container"
assert_log "Dokku changed version"
assert_output "docker inspect -f '{{.Config.Image}}' dokku" "dokku/dokku:${latest}"
assert_output "docker port dokku 80" ":8081"
assert_output "${in_dokku} apps:list" "e2e-app"
assert_exit 0 "[ \$(${in_dokku} ssh-keys:list | wc -l) -eq ${keys} ]"
assert_exit 0 "${in_dokku} plugin:installed maintenance"

step "dokku-docker: a user's remove keeps the container, there for every user"
load remove -- dokku-docker
assert_log "Root removes it with 'load.sh remove -- dokku-docker --force'"
assert_exit 0 "docker inspect dokku"

step "dokku-docker: root's remove --force takes out the container and keeps the data"
assert_exit 0 "${ROOT_LOADER} remove -- dokku-docker --force"
assert_log "The data of Dokku stays in /var/lib/dokku"
assert_exit 1 "docker inspect dokku"
assert_exit 0 "sudo test -d /var/lib/dokku/home/dokku/e2e-app"
assert_missing "$state"

step "dokku-docker: purge removes the folder"
load remove -- dokku-docker --purge
assert_missing "$tool_home"

finish
