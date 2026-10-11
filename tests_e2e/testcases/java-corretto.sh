#!/usr/bin/env bash
# java-corretto.sh: Amazon Corretto 21 by default, then 25, remove and purge
# images: ubuntu fedora
source "$(dirname "${BASH_SOURCE[0]}")/../shared/lib.sh"

test_java_vendor corretto

finish
