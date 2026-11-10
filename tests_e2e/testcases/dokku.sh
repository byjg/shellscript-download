#!/usr/bin/env bash
# dokku.sh: install an older version, run again without and with --version, the SSH keys,
# the domain and a plugin added once, an app, remove and purge
# vm: yes
source "$(dirname "${BASH_SOURCE[0]}")/../shared/lib.sh"

tool_home="${SHELLSCRIPT_HOME}/dokku"
apt_source="/etc/apt/sources.list.d/dokku.sources"
older="0.38.33"
plugin="maintenance=https://github.com/dokku/dokku-maintenance.git"

# Dokku has packages for Debian and Ubuntu only
if ! on_image ubuntu; then
  step "dokku: refused where Dokku has no packages"
  load_fails dokku
  assert_log "Dokku has no packages for this system"
  assert_no_command dokku
  finish
  exit 0
fi

step "dokku: --version installs that version, Docker with it, and the user's SSH key"
load dokku -- --version "$older" --plugin "$plugin"
assert_command docker
assert_exists "$apt_source"
assert_exists "${tool_home}/installed"
assert_output "dpkg-query -W -f='\${Version}' dokku" "$older"
assert_output "sudo dokku ssh-keys:list" 'NAME="admin"'
keys="$(grep -c '^ssh-' "${HOME}/.ssh/authorized_keys")"
assert_exit 0 "[ \$(sudo dokku ssh-keys:list | wc -l) -eq ${keys} ]"
assert_output "sudo cat /home/dokku/VHOST" "$(hostname)"
assert_exit 0 "sudo dokku plugin:installed maintenance"

step "dokku: run again, nothing changes: the version, the key, the plugin"
load dokku -- --plugin "$plugin"
assert_log "Dokku ${older} is already installed"
assert_log "The Dokku repository is already set up"
assert_log "is already in Dokku"
assert_log "Plugin 'maintenance' is already installed"
assert_exit 0 "[ \$(sudo dokku ssh-keys:list | wc -l) -eq ${keys} ]"
assert_output "dpkg-query -W -f='\${Version}' dokku" "$older"

step "dokku: --version with the latest changes the version, and says to rebuild the apps"
latest="$(apt-cache policy dokku | awk '/Candidate:/ {print $2}')"
load dokku -- --version "$latest"
assert_log "Dokku changed from ${older}"
assert_output "dpkg-query -W -f='\${Version}' dokku" "$latest"

step "dokku: --hostname sets the global domain, and an app gets a domain under it"
load dokku -- --hostname apps.example.test
assert_output "sudo cat /home/dokku/VHOST" "apps.example.test"
assert_exit 0 "sudo dokku apps:create e2e-app"
assert_output "sudo dokku domains:report e2e-app --domains-app-vhosts" "e2e-app.apps.example.test"

step "dokku: remove takes out Dokku and its repository, keeps the folder and Docker"
load remove -- dokku
assert_no_command dokku
assert_missing "$apt_source"
assert_exists "$tool_home"
assert_command docker

step "dokku: purge removes the folder"
load remove -- dokku --purge
assert_missing "$tool_home"

finish
