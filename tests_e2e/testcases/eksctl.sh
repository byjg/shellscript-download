#!/usr/bin/env bash
# eksctl.sh: the latest eksctl by default, one older version, remove and purge
source "$(dirname "${BASH_SOURCE[0]}")/../shared/lib.sh"

eksctl_works() {
  assert_output "eksctl create cluster --help" "nodegroup"
}

test_single_binary eksctl 0.220.0 "eksctl version" eksctl_works

finish
