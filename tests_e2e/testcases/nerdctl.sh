#!/usr/bin/env bash
# nerdctl.sh: an older version, the latest, the 'docker' command, the system-wide install
# running a container, remove and purge
# privileged: yes
source "$(dirname "${BASH_SOURCE[0]}")/../shared/lib.sh"

# A container has no systemd: every install is --no-services, and the services, rootless
# or not, are not covered. The system-wide one runs a container with a containerd started
# by hand instead.
tool_home="${SHELLSCRIPT_HOME}/nerdctl"

step "nerdctl: without systemd, the services are refused and --no-services is not"
load_fails nerdctl -- --dry-run
assert_log "needs a systemd user session"
before="$(home_snapshot)"
load nerdctl -- --dry-run --no-services
if [[ "$(home_snapshot)" == "$before" ]]; then pass "--dry-run changed nothing"; else fail "--dry-run changed the home"; fi

step "nerdctl: install an older version (--version 2.4.0)"
load nerdctl -- --no-services --version 2.4.0
assert_output "nerdctl --version" "nerdctl version 2.4.0"
assert_output "sed -n 2p '${SHELLSCRIPT_HOME}/bin/nerdctl'" "${tool_home}/current/bin/nerdctl"
assert_output "PATH=\"\$PATH:/usr/sbin:/sbin\" command -v newuidmap" "newuidmap"

step "nerdctl: install with the defaults updates to the latest"
load nerdctl -- --no-services
assert_log "Downloading"
assert_no_output "nerdctl --version" "2.4.0"
assert_output "nerdctl --version" "nerdctl version"

step "nerdctl: install again downloads nothing"
load nerdctl -- --no-services
assert_log "is already installed. Skipping download"

step "nerdctl: --docker creates a 'docker' command that runs nerdctl"
load nerdctl -- --no-services --docker
assert_output "docker --version" "nerdctl version"

step "nerdctl: remove keeps the folder, purge removes it"
load remove -- nerdctl
assert_removed nerdctl
assert_exists "$tool_home"
load remove -- nerdctl --purge
assert_purged "$tool_home"

step "nerdctl: --no-rootless installs to /opt/nerdctl and runs a container"
load nerdctl -- --no-rootless --no-services
assert_output "stat -c '%U' /opt/nerdctl/bin/nerdctl" "root"
# The root of the container is an overlay, where overlayfs does not stack: the images of
# containerd go to a tmpfs
sudo mkdir -p /var/lib/containerd
sudo mount -t tmpfs tmpfs /var/lib/containerd
sudo sh -c 'PATH=/opt/nerdctl/bin:$PATH containerd >/tmp/containerd.log 2>&1 &'
for _ in $(seq 1 30); do
  sudo test -S /run/containerd/containerd.sock && break
  sleep 1
done
assert_output "nerdctl run --rm hello-world 2>&1" "Hello from Docker"

step "nerdctl: remove takes /opt/nerdctl out"
sudo kill $(pidof containerd) 2>/dev/null || true
load remove -- nerdctl --purge
assert_missing /opt/nerdctl
assert_removed nerdctl

step "nerdctl: --docker is refused when Docker is installed"
printf '#!/bin/sh\necho Docker version 0.0.0\n' | sudo tee /usr/local/bin/docker >/dev/null
sudo chmod +x /usr/local/bin/docker
load_fails nerdctl -- --no-services --docker
assert_log "Docker is already installed"
assert_missing "${SHELLSCRIPT_HOME}/bin/docker"
assert_missing "$tool_home/current"

finish
