#!/usr/bin/env bash
# yq.sh: the latest yq by default, one older version, remove and purge
source "$(dirname "${BASH_SOURCE[0]}")/../shared/lib.sh"

yq_works() {
  assert_output "printf 'a:\n  b: 7\n' | yq '.a.b'" "7"
}

test_single_binary yq 4.44.1 yq_works

finish
