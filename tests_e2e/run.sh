#!/usr/bin/env bash
# run.sh: runs the end-to-end tests, each one in a fresh container of each image.
#
# Usage:
#   tests_e2e/run.sh                     every test, on every image
#   tests_e2e/run.sh jq yq               these tests, on every image
#   tests_e2e/run.sh --image alpine jq   this test, on one image
#   tests_e2e/run.sh --verbose jq        also show the output of every load.sh
#
# A test is tests_e2e/testcases/<name>.sh. It runs on every image below, unless it has
# a line
#   # images: ubuntu fedora
# naming the ones it applies to, and in a privileged container when it has a line
#   # privileged: yes
# which a test needs to run containers inside its own. What the tests share is in
# tests_e2e/shared.
set -euo pipefail

# The images every test is run on. One place, so that all tests see the same systems.
declare -A IMAGES=(
  [ubuntu]="ubuntu:24.04"
  [fedora]="fedora:42"
  [alpine]="alpine:3.22"
)
IMAGE_ORDER=(ubuntu fedora alpine)

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "${TESTS_DIR}/../public/scripts" && pwd)"

only_image=""
verbose=""
tests=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --image) only_image="${2:?--image requires a name}"; shift ;;
    --verbose) verbose=1 ;;
    -h|--help) sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) tests+=("$1") ;;
  esac
  shift
done

if [[ -n "$only_image" && -z "${IMAGES[$only_image]:-}" ]]; then
  echo "Unknown image '${only_image}'. Available: ${IMAGE_ORDER[*]}" >&2
  exit 2
fi

if [[ ${#tests[@]} -eq 0 ]]; then
  for file in "${TESTS_DIR}"/testcases/*.sh; do
    tests+=("$(basename "$file" .sh)")
  done
fi

results=()
failed=0
for test in "${tests[@]}"; do
  file="${TESTS_DIR}/testcases/${test}.sh"
  [[ -f "$file" ]] || { echo "No such test: ${test}" >&2; exit 2; }
  applies="$(sed -n 's/^# images: *//p' "$file")"
  docker_options=()
  # A container engine inside a container cannot keep its data on the overlay
  # filesystem of the container: /var/lib/docker goes to a volume, gone with it.
  if grep -q '^# privileged: yes' "$file"; then docker_options+=(--privileged -v /var/lib/docker); fi
  for image in "${IMAGE_ORDER[@]}"; do
    [[ -z "$only_image" || "$only_image" == "$image" ]] || continue
    [[ -z "$applies" || " ${applies} " == *" ${image} "* ]] || continue

    printf '\n######## %s on %s (%s)\n' "$test" "$image" "${IMAGES[$image]}"
    if docker run --rm -e "E2E_VERBOSE=${verbose}" ${docker_options[@]+"${docker_options[@]}"} \
        -v "${SCRIPTS_DIR}:/repo:ro" -v "${TESTS_DIR}:/tests:ro" \
        "${IMAGES[$image]}" sh /tests/shared/container.sh "$test"; then
      results+=("PASS  ${test} on ${image}")
    else
      results+=("FAIL  ${test} on ${image}")
      failed=1
    fi
  done
done

printf '\n######## Summary\n'
printf '%s\n' "${results[@]}"
exit "$failed"
