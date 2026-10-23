#!/usr/bin/env bash
# nerdctl.sh: rootless with its services, an older version and the latest, the 'docker'
# command, system-wide with its services, remove and purge
# vm: yes
source "$(dirname "${BASH_SOURCE[0]}")/../shared/lib.sh"

tool_home="${SHELLSCRIPT_HOME}/nerdctl"
user_units="${HOME}/.config/systemd/user"

# runs_containers: a container, a published port and a build, with the services running
runs_containers() {
  assert_output "nerdctl run --rm hello-world 2>&1" "Hello from Docker"
  nerdctl run -d --name e2e-web -p 8080:80 nginx:alpine >/dev/null 2>&1
  assert_output "for i in \$(seq 1 20); do curl -s localhost:8080 && break; sleep 1; done" "Welcome to nginx"
  nerdctl rm -f e2e-web >/dev/null 2>&1
  mkdir -p /tmp/e2e-build
  printf 'FROM alpine\nRUN echo built > /built\nCMD cat /built\n' > /tmp/e2e-build/Dockerfile
  assert_output "nerdctl build -q -t e2e-build /tmp/e2e-build >/dev/null 2>&1 && nerdctl run --rm e2e-build" "built"
}

# Alpine has no systemd: the services are refused, the commands alone are not
if on_image alpine; then
  step "nerdctl: without systemd, the services are refused and --no-services is not"
  load_fails nerdctl
  assert_log "needs a systemd user session"
  load nerdctl -- --no-services --version 2.4.0
  assert_output "nerdctl --version" "nerdctl version 2.4.0"

  step "nerdctl: --no-services again updates to the latest"
  load nerdctl -- --no-services --docker
  assert_no_output "nerdctl --version" "2.4.0"
  assert_output "docker --version" "nerdctl version"

  step "nerdctl: remove and purge"
  load remove -- nerdctl --purge
  assert_removed nerdctl
  assert_purged "$tool_home"
  finish
  exit 0
fi

step "nerdctl: --dry-run changes nothing"
before="$(home_snapshot)"
load nerdctl -- --dry-run
if [[ "$(home_snapshot)" == "$before" ]]; then pass "--dry-run changed nothing"; else fail "--dry-run changed the home"; fi

# Rootless containers cannot use the legacy iptables, which Fedora 42 comes with:
# there, the rootless install is refused, and only the system-wide one is tested
rootless=yes
if PATH="${PATH}:/usr/sbin:/sbin" iptables --version 2>/dev/null | grep -q legacy; then
  rootless=no
  step "nerdctl: the legacy iptables stops the rootless install, and says what works"
  load_fails nerdctl -- --version 2.4.0
  assert_log "load.sh nerdctl -- --no-rootless"
  assert_missing "${tool_home}/current"
fi

if [[ "$rootless" == "yes" ]]; then
  step "nerdctl: rootless install of an older version (--version 2.4.0) starts the services"
  load nerdctl -- --version 2.4.0
  assert_subuid_hint
  assert_output "nerdctl --version" "nerdctl version 2.4.0"
  assert_exit 0 "systemctl --user is-active --quiet containerd.service buildkit.service"
  assert_exit 0 "systemctl --user is-enabled --quiet containerd.service buildkit.service"
  runs_containers

  step "nerdctl: install with the defaults updates to the latest and restarts the services"
  load nerdctl
  assert_log "Downloading"
  assert_no_output "nerdctl --version" "2.4.0"
  assert_exit 0 "systemctl --user is-active --quiet containerd.service buildkit.service"
  runs_containers

  step "nerdctl: install again downloads nothing"
  load nerdctl
  assert_log "is already installed. Skipping download"

  step "nerdctl: --docker creates a 'docker' command that runs nerdctl"
  load nerdctl -- --docker
  assert_output "docker --version" "nerdctl version"
  assert_output "docker run --rm hello-world 2>&1" "Hello from Docker"

  step "nerdctl: remove takes the services out, and leaves no failed unit"
  load remove -- nerdctl
  assert_removed nerdctl
  assert_missing "${user_units}/containerd.service"
  assert_missing "${user_units}/buildkit.service"
  assert_no_output "systemctl --user --failed --no-legend" "service"
  assert_no_output "ls /etc/apparmor.d" "shellscript.nerdctl"
  assert_exists "$tool_home"
  load remove -- nerdctl --purge
  assert_purged "$tool_home"
fi

step "nerdctl: --no-rootless installs to /opt/nerdctl and starts the system services"
load nerdctl -- --no-rootless
assert_output "stat -c '%U' /opt/nerdctl/bin/nerdctl" "root"
assert_exit 0 "systemctl is-active --quiet containerd.service buildkit.service"
runs_containers

step "nerdctl: remove takes /opt/nerdctl and the system services out"
load remove -- nerdctl --purge
assert_missing /opt/nerdctl
assert_missing /etc/systemd/system/containerd.service
assert_missing /etc/systemd/system/buildkit.service
assert_no_output "systemctl --failed --no-legend" "service"
assert_removed nerdctl

step "nerdctl: --docker is refused when Docker is installed"
printf '#!/bin/sh\necho Docker version 0.0.0\n' | sudo tee /usr/local/bin/docker >/dev/null
sudo chmod +x /usr/local/bin/docker
load_fails nerdctl -- --docker
assert_log "Docker is already installed"
assert_missing "${SHELLSCRIPT_HOME}/bin/docker"
assert_missing "${tool_home}/current"

finish
