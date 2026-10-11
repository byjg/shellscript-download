#!/usr/bin/env bash
# node-docker.sh: the node, npm, npx and yarn wrappers: a version, an older one, the
# options, remove and purge
# privileged: yes
source "$(dirname "${BASH_SOURCE[0]}")/../shared/lib.sh"

need_docker

# in_container <command> "<shell command>": runs it inside the container of the wrapper
in_container() {
  printf "%s -e 'try { require(\"child_process\").execSync(\"%s\", {stdio: \"inherit\"}) } catch (e) { process.exit(e.status || 1) }'" "$1" "$2"
}

# The node wrappers mount the folders of the host under /c
container_path() {
  echo "/c$1"
}

extra_checks() {
  assert_exit 0 "npm --version"
  assert_exit 0 "npx --version"
  assert_exit 0 "yarn --version"
}

test_docker_wrapper node-docker node node 22 20 "v%s."

finish
