#!/usr/bin/env bash
# buildah.sh: install, build an image, remove and purge
# privileged: yes
source "$(dirname "${BASH_SOURCE[0]}")/../shared/lib.sh"

# Rootless Buildah inside a Docker container builds an image as it is on Ubuntu only:
# see podman.sh
buildah_works() {
  assert_output "buildah --version" "buildah version"
  if ! on_image ubuntu; then
    skip "buildah build: not in a container of this image"
    return
  fi
  mkdir -p /tmp/buildah-sample
  echo "hello" > /tmp/buildah-sample/hello.txt
  printf 'FROM scratch\nCOPY hello.txt /hello.txt\n' > /tmp/buildah-sample/Containerfile
  assert_output "buildah build -t e2e-sample /tmp/buildah-sample >/dev/null 2>&1 && buildah images" "e2e-sample"
}

test_system_package buildah buildah buildah_works

finish
