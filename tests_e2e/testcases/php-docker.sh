#!/usr/bin/env bash
# php-docker.sh: the php and composer wrappers: a version, an older one, the options,
# remove and purge
# privileged: yes
source "$(dirname "${BASH_SOURCE[0]}")/../shared/lib.sh"

need_docker

# in_container <command> "<shell command>": runs it inside the container of the wrapper
in_container() {
  printf "%s -r 'passthru(\"%s\", \$code); exit(\$code);'" "$1" "$2"
}

extra_checks() {
  assert_output "composer --version" "Composer version"
}

test_docker_wrapper php-docker php php 8.4 8.3 "PHP %s"

finish
