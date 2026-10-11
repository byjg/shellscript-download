#!/usr/bin/env bash
# doctl.sh: the latest doctl by default, one older version, remove and purge
source "$(dirname "${BASH_SOURCE[0]}")/../shared/lib.sh"

doctl_works() {
  assert_output "doctl compute --help" "droplet"
}

test_single_binary doctl 1.150.0 "doctl version" doctl_works

finish
