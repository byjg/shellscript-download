#!/usr/bin/env bash
# kubectl.sh: the latest stable kubectl by default, one older version, remove and purge
source "$(dirname "${BASH_SOURCE[0]}")/../shared/lib.sh"

kubectl_works() {
  assert_output "kubectl create configmap sample --from-literal=a=b --dry-run=client -o yaml" "kind: ConfigMap"
}

test_single_binary kubectl 1.34.0 "kubectl version --client" kubectl_works

finish
