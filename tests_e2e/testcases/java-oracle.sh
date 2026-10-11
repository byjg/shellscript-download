#!/usr/bin/env bash
# java-oracle.sh: Oracle JDK 21 by default, then 25, remove and purge
# images: ubuntu fedora
source "$(dirname "${BASH_SOURCE[0]}")/../shared/lib.sh"

test_java_vendor oracle

finish
