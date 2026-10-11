#!/usr/bin/env bash
# run.sh: runs the end-to-end tests, each one in a fresh container of each image.
#
# Usage:
#   tests_e2e/run.sh                     every test, on every image
#   tests_e2e/run.sh jq yq               these tests, on every image
#   tests_e2e/run.sh --image alpine jq   this test, on one image
#   tests_e2e/run.sh --verbose jq        also show the output of every load.sh
#   tests_e2e/run.sh --changed main      the tests of what changed since main
#   tests_e2e/run.sh --changed main --list   name them, and run nothing
#
# --changed <ref> takes what this branch changed since <ref> (or a range, a..b):
#   public/scripts/<name>.sh       the test of that script
#   public/scripts/lib/<file>.sh   the tests of the scripts that use that file
#   public/install/*               the test of the loader
#   tests_e2e/testcases/<name>.sh  that test
#   tests_e2e/run.sh, shared/*     every test
# and adds all-scripts, which checks what every script must do. With nothing of that
# changed, there is nothing to run.
#
# The scripts look up the latest version of the tools in the GitHub API, which answers
# 60 requests an hour to who does not identify itself: less than a full run makes. Run
# with GITHUB_TOKEN set and the containers get it:
#   GITHUB_TOKEN=$(gh auth token) tests_e2e/run.sh
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
PUBLIC_DIR="$(cd "${TESTS_DIR}/../public" && pwd)"

only_image=""
verbose=""
changed=""
list_only=""
tests=()

# tests_for_changes <ref or range>: prints the tests of what changed, one per line
tests_for_changes() {
  local range="$1" file name user all="" names=""
  [[ "$range" == *..* ]] || range="${range}...HEAD"
  while IFS= read -r file; do
    case "$file" in
      public/scripts/lib/*.sh)
        for user in "${PUBLIC_DIR}"/scripts/*.sh; do
          if grep -q "lib/$(basename "$file")" "$user"; then names+=" $(basename "$user" .sh)"; fi
        done
        ;;
      public/scripts/*.sh)       names+=" $(basename "$file" .sh)" ;;
      public/install/*)          names+=" load" ;;
      tests_e2e/testcases/*.sh)  names+=" $(basename "$file" .sh)" ;;
      tests_e2e/*)               all=yes ;;
    esac
  done < <(git -C "${TESTS_DIR}/.." diff --name-only "$range")

  if [[ -n "$all" ]]; then
    for file in "${TESTS_DIR}"/testcases/*.sh; do basename "$file" .sh; done
    return 0
  fi
  [[ -n "$names" ]] || return 0
  # Only what has a test: a script that was deleted has none
  for name in $names all-scripts; do
    if [[ -f "${TESTS_DIR}/testcases/${name}.sh" ]]; then echo "$name"; fi
  done | sort -u
}
while [[ $# -gt 0 ]]; do
  case "$1" in
    --image) only_image="${2:?--image requires a name}"; shift ;;
    --verbose) verbose=1 ;;
    --changed) changed="${2:?--changed requires a git ref or a range}"; shift ;;
    --list) list_only=1 ;;
    -h|--help) sed -n '2,33p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) tests+=("$1") ;;
  esac
  shift
done

if [[ -n "$only_image" && -z "${IMAGES[$only_image]:-}" ]]; then
  echo "Unknown image '${only_image}'. Available: ${IMAGE_ORDER[*]}" >&2
  exit 2
fi

if [[ -n "$changed" ]]; then
  mapfile -t tests < <(tests_for_changes "$changed")
  if [[ ${#tests[@]} -eq 0 ]]; then
    echo "Nothing that has a test changed since ${changed}." >&2
    exit 0
  fi
elif [[ ${#tests[@]} -eq 0 ]]; then
  for file in "${TESTS_DIR}"/testcases/*.sh; do
    tests+=("$(basename "$file" .sh)")
  done
fi

if [[ -n "$list_only" ]]; then
  printf '%s\n' "${tests[@]}"
  exit 0
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
    # -e GITHUB_TOKEN, by name: its value comes from the environment, not the command line
    if docker run --rm -e "E2E_VERBOSE=${verbose}" ${GITHUB_TOKEN:+-e GITHUB_TOKEN} ${docker_options[@]+"${docker_options[@]}"} \
        -v "${PUBLIC_DIR}:/repo:ro" -v "${TESTS_DIR}:/tests:ro" \
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
