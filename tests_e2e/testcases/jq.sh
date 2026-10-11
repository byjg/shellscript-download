#!/usr/bin/env bash
# jq.sh: the latest jq by default, one older version, remove and purge
source "$(dirname "${BASH_SOURCE[0]}")/../shared/lib.sh"

jq_works() {
  assert_output "echo '{\"a\":[1,2]}' | jq -c '.a | add'" "3"
}

test_single_binary jq 1.7.1 "jq --version" jq_works

finish
