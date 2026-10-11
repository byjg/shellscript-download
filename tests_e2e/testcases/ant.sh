#!/usr/bin/env bash
# ant.sh: the latest Ant by default, one older version, remove and purge
# images: ubuntu fedora
source "$(dirname "${BASH_SOURCE[0]}")/../shared/lib.sh"

test_java_build_tool ant 1.10.14 "ant -version" "Apache Ant" "version 1.10.14"

finish
