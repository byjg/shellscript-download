#!/usr/bin/env bash
# byjg-repo.sh: add the repository, list and install a package, remove and purge
source "$(dirname "${BASH_SOURCE[0]}")/../shared/lib.sh"

tool_home="${SHELLSCRIPT_HOME}/byjg-repo"

# On Alpine the key says the repository is set up: the repository itself is a line of
# /etc/apk/repositories
if command -v apt-get >/dev/null 2>&1; then
  repo_file="/etc/apt/sources.list.d/byjg.sources"
elif command -v apk >/dev/null 2>&1; then
  repo_file="/etc/apk/keys/byjg.rsa.pub"
else
  repo_file="/etc/yum.repos.d/byjg.repo"
fi

step "byjg-repo: --list before the repository is set up"
load_fails byjg-repo -- --list

step "byjg-repo: install with the defaults adds the repository"
load byjg-repo
assert_exists "$repo_file"
assert_exists "${tool_home}/repository-added"

step "byjg-repo: --list shows the packages"
assert_output "${LOADER} byjg-repo -- --list 2>/dev/null" "static-httpserver"

step "byjg-repo: install again changes nothing, --install adds a package"
load byjg-repo -- --install static-httpserver
assert_output "cat '$LOG_FILE'" "already set up"
assert_command static-httpserver
assert_output "cat '${tool_home}/installed-packages.conf'" "static-httpserver"

step "byjg-repo: remove takes out the package and the repository, keeps the folder"
load remove -- byjg-repo
assert_no_command static-httpserver
assert_missing "$repo_file"
assert_exists "$tool_home"

step "byjg-repo: purge removes the folder"
load remove -- byjg-repo --purge
assert_missing "$tool_home"

finish
