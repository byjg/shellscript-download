#!/usr/bin/env bash
# gh.sh: the latest GitHub CLI by default, one older version, remove and purge
source "$(dirname "${BASH_SOURCE[0]}")/../shared/lib.sh"

gh_works() {
  assert_output "gh pr --help" "checkout"
}

test_single_binary gh 2.80.0 "gh --version" gh_works

finish
