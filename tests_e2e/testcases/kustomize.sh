#!/usr/bin/env bash
# kustomize.sh: the latest Kustomize by default, one older version, remove and purge
source "$(dirname "${BASH_SOURCE[0]}")/../shared/lib.sh"

kustomize_works() {
  mkdir -p /tmp/kustomize-sample
  printf 'apiVersion: v1\nkind: ConfigMap\nmetadata:\n  name: a\n' > /tmp/kustomize-sample/cm.yaml
  printf 'resources:\n- cm.yaml\nnamePrefix: x-\n' > /tmp/kustomize-sample/kustomization.yaml
  assert_output "kustomize build /tmp/kustomize-sample" "name: x-a"
}

test_single_binary kustomize 5.6.0 "kustomize version" kustomize_works

finish
