#!/usr/bin/env bash
# aws-cli.sh: the latest AWS CLI by default, one older version, remove and purge
# images: ubuntu fedora
source "$(dirname "${BASH_SOURCE[0]}")/../shared/lib.sh"

tool_home="${SHELLSCRIPT_HOME}/aws-cli"
shellrc="${SHELLSCRIPT_HOME}/shellrc/aws-cli-init.sh"

step "aws-cli: needs unzip, and says so"
load_fails aws-cli
assert_output "cat '$LOG_FILE'" "unzip"
if sys_install unzip; then pass "installed unzip"; else fail "could not install unzip"; fi

step "aws-cli: install with the defaults (latest version)"
load aws-cli
assert_output "aws --version" "aws-cli/2."
assert_exists "${SHELLSCRIPT_HOME}/bin/aws_completer"
assert_output ". /usr/share/bash-completion/bash_completion; . '${shellrc}'; complete -p aws" "aws_completer"

step "aws-cli: install again changes nothing"
load aws-cli
assert_output "cat '$LOG_FILE'" "Skipping install"

step "aws-cli: install an older version (--version 2.31.0)"
load aws-cli -- --version 2.31.0
assert_output "aws --version" "aws-cli/2.31.0"

step "aws-cli: a version that does not exist stops and changes nothing"
load_fails aws-cli -- --version 0.0.0
assert_output "aws --version" "aws-cli/2.31.0"

step "aws-cli: the command does not depend on HOME"
assert_output "HOME=/tmp/another-home aws --version" "aws-cli/2.31.0"

step "aws-cli: remove keeps the folder"
load remove -- aws-cli
assert_removed aws-cli
assert_exists "$tool_home"

step "aws-cli: purge removes the folder"
load aws-cli -- --version 2.31.0
load remove -- aws-cli --purge
assert_removed aws-cli
assert_purged "$tool_home"

finish
