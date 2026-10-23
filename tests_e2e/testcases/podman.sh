#!/usr/bin/env bash
# podman.sh: install, run a container, remove and purge, and the 'docker' command
# vm: yes
source "$(dirname "${BASH_SOURCE[0]}")/../shared/lib.sh"

runs_a_container() {
  assert_output "$1 run --rm quay.io/podman/hello" "Hello Podman World"
}

podman_works() {
  assert_output "podman --version" "podman version"
  assert_subuid_hint
  assert_exists /dev/net/tun
  runs_a_container podman
}

# The cloud image of Fedora comes with Podman: the test starts without it, as on the others
if command -v podman >/dev/null 2>&1; then
  if sys_remove podman; then pass "removed the Podman of the image"; else fail "could not remove the Podman of the image"; fi
fi

test_system_package podman podman podman_works

step "podman: --docker creates a 'docker' command that runs Podman"
load podman -- --docker
assert_output "docker --version" "podman"
runs_a_container docker

step "podman: remove takes the 'docker' command out"
load remove -- podman --purge
assert_missing "${SHELLSCRIPT_HOME}/bin/docker"

step "podman: --docker is refused when Docker is installed"
printf '#!/bin/sh\necho Docker version 0.0.0\n' | sudo tee /usr/local/bin/docker >/dev/null
sudo chmod +x /usr/local/bin/docker
load_fails podman -- --docker
assert_output "cat '$LOG_FILE'" "Docker is already installed"
assert_missing "${SHELLSCRIPT_HOME}/bin/docker"

finish
