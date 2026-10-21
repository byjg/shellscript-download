#!/usr/bin/env bash
# java-oracle.sh: Oracle JDK 25 by default, then 21, remove and purge
# images: ubuntu fedora
source "$(dirname "${BASH_SOURCE[0]}")/../shared/lib.sh"

test_java_vendor oracle 25 21

step "java-oracle: 17 and 21 are their last public build, and it says so"
load java-oracle -- --version 21 --dry-run
assert_log "21.0.12 is the last public build of Oracle JDK 21"
assert_log "https://download.oracle.com/java/21/archive/jdk-21.0.12_linux-"
load java-oracle -- --version 17 --dry-run
assert_log "https://download.oracle.com/java/17/archive/jdk-17.0.12_linux-"

finish
