#!/usr/bin/env bash
# maven.sh: the latest Maven by default, one older version, remove and purge
# images: ubuntu fedora
source "$(dirname "${BASH_SOURCE[0]}")/../shared/lib.sh"

test_java_build_tool maven 3.8.8 "mvn --version" "Apache Maven" "Apache Maven 3.8.8"

finish
