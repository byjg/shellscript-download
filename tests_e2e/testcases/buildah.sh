#!/usr/bin/env bash
# buildah.sh: install, build an image, remove and purge
# vm: yes
source "$(dirname "${BASH_SOURCE[0]}")/../shared/lib.sh"

buildah_works() {
  assert_output "buildah --version" "buildah version"
  assert_subuid_hint
  mkdir -p /tmp/buildah-sample
  echo "hello" > /tmp/buildah-sample/hello.txt
  # A RUN step runs a container: network, cgroups, user namespace
  printf 'FROM alpine\nCOPY hello.txt /hello.txt\nRUN apk add -q --no-cache curl && cat /hello.txt\n' > /tmp/buildah-sample/Containerfile
  assert_output "buildah build -t e2e-sample /tmp/buildah-sample >/dev/null 2>&1 && buildah images" "e2e-sample"
}

test_system_package buildah buildah buildah_works

finish
