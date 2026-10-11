#!/usr/bin/env bash
# helm.sh: the latest Helm by default, one older version, remove and purge
source "$(dirname "${BASH_SOURCE[0]}")/../shared/lib.sh"

helm_works() {
  assert_output "rm -rf /tmp/chart && helm create /tmp/chart >/dev/null && helm template /tmp/chart" "kind: Deployment"
}

test_single_binary helm 3.19.0 "helm version --short" helm_works

finish
