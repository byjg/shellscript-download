#!/usr/bin/env bash
# docker.sh: install the Docker Engine, with and without the 'docker' group, and check
# that the user can run a container
# privileged: yes
source "$(dirname "${BASH_SOURCE[0]}")/../shared/lib.sh"

user="$(id -un)"

# The installer of Docker has no packages for Alpine
if on_image alpine; then
  step "docker: refused where the installer of Docker has no packages"
  load_fails docker
  assert_no_command docker
  finish
  exit 0
fi

step "docker: --no-group installs Docker and leaves the user out of the 'docker' group"
load docker -- --no-group
assert_output "docker --version" "Docker version"
assert_no_output "id -nG ${user}" "docker"
start_docker_daemon

step "docker: out of the group, the user needs sudo"
assert_exit 1 "docker ps"
assert_log "permission denied"
assert_output "sudo docker run --rm hello-world" "Hello from Docker"

step "docker: install with the defaults puts the user in the 'docker' group"
load docker
assert_log "Adding '${user}' to 'docker' group"
assert_log "log out and log back in"
assert_output "id -nG ${user}" "docker"

step "docker: after logging in again, the user runs a container without sudo"
assert_output "$(in_new_session 'docker run --rm hello-world')" "Hello from Docker"

step "docker: install again finds the user in the group"
load docker
assert_log "is already in the 'docker' group"

step "docker: the configuration folder belongs to the user alone"
assert_output "stat -c '%a %U' ${HOME}/.docker" "700 ${user}"

step "docker: purge removes the configuration folder"
load remove -- docker --purge
assert_missing "${HOME}/.docker"

finish
