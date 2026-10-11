#!/usr/bin/env bash
# gcloud.sh: the latest Google Cloud CLI by default, one older version, remove and purge
# images: ubuntu fedora
source "$(dirname "${BASH_SOURCE[0]}")/../shared/lib.sh"

tool_home="${SHELLSCRIPT_HOME}/gcloud"
shellrc="${SHELLSCRIPT_HOME}/shellrc/gcloud-init.sh"

step "gcloud: install with the defaults (latest version)"
load gcloud
assert_output "gcloud --version" "Google Cloud SDK"
assert_output "gsutil version" "gsutil version"
assert_output "bq version" "BigQuery CLI"
assert_output ". /usr/share/bash-completion/bash_completion; . '${shellrc}'; complete -p gcloud" "gcloud"

step "gcloud: install an older version (--version 540.0.0)"
load gcloud -- --version 540.0.0
assert_output "gcloud --version" "Google Cloud SDK 540.0.0"

step "gcloud: a version that does not exist stops and changes nothing"
load_fails gcloud -- --version 0.0.0
assert_output "gcloud --version" "Google Cloud SDK 540.0.0"

step "gcloud: the wrappers do not depend on HOME"
assert_output "HOME=/tmp/another-home gcloud --version" "Google Cloud SDK 540.0.0"

step "gcloud: remove keeps the folder"
load remove -- gcloud
assert_removed gcloud
assert_exists "$tool_home"

step "gcloud: purge removes the folder"
load gcloud -- --version 540.0.0
load remove -- gcloud --purge
assert_removed gcloud
assert_purged "$tool_home"

finish
