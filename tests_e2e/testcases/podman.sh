#!/usr/bin/env bash
# podman.sh: install, run a container, remove and purge, and the 'docker' command
# privileged: yes
source "$(dirname "${BASH_SOURCE[0]}")/../shared/lib.sh"

# Rootless Podman inside a Docker container runs a container as it is on Ubuntu only:
# the Fedora image has no file capabilities on newuidmap, and the storage driver of
# Alpine does not stack on the one of Docker.
runs_a_container() {
  if on_image ubuntu; then
    assert_output "$1 run --rm quay.io/podman/hello" "Hello Podman World"
  else
    skip "$1 run: not in a container of this image"
  fi
}

podman_works() {
  assert_output "podman --version" "podman version"
  # An image whose users have no subordinate ids gets the hint
  if ! grep -q "^$(id -un):" /etc/subuid 2>/dev/null; then
    assert_output "cat '$LOG_FILE'" "sudo tee -a /etc/subuid /etc/subgid"
  fi
  runs_a_container podman
}

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
