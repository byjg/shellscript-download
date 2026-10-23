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
#   tests_e2e/shared/lib.sh        the tests that use what changed in it: a function, a
#                                  variable, or what calls them
#   tests_e2e/shared/container.sh  every test: each one runs in what it prepares
#   tests_e2e/run.sh               all-scripts alone, as a smoke test of the runner
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
# which a test needs to run containers inside its own. A test that needs what a
# container does not have (systemd, services, AppArmor, a login) runs in a VM of the
# same system instead, booted with the qemu.sh of the working copy, when it has a line
#   # vm: yes
# and, in that VM, with a running Docker its user may use when it also has
#   # needs: docker
# The VMs need /dev/kvm. They are reached with a key made for the run, held by an
# ssh-agent of the run alone, whose keys qemu.sh puts in the VMs it creates: nothing is
# written to ~/.ssh, and the ssh-agent of the user is left alone. Both go away with the
# run. What the tests share is in tests_e2e/shared.
set -euo pipefail

# The images every test is run on. One place, so that all tests see the same systems.
declare -A IMAGES=(
  [ubuntu]="ubuntu:24.04"
  [fedora]="fedora:42"
  [alpine]="alpine:3.22"
)
IMAGE_ORDER=(ubuntu fedora alpine)
# The same systems, as the cloud images qemu.sh boots, for the tests with '# vm: yes'
declare -A VM_IMAGES=(
  [ubuntu]="ubuntu-24.04"
  [fedora]="fedora-42"
  [alpine]="alpine-3.22"
)

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PUBLIC_DIR="$(cd "${TESTS_DIR}/../public" && pwd)"

only_image=""
verbose=""
changed=""
list_only=""
tests=()

SHARED_LIB="${TESTS_DIR}/shared/lib.sh"

# The qemu.sh of the working copy, as a developer runs it
QEMU=(bash "${PUBLIC_DIR}/scripts/load.sh" --developer "${PUBLIC_DIR}/scripts" qemu --)
VM_PORT=""

# The user qemu.sh creates in the VM, and the key of the run (start_vm_agent)
VM_USER="shellscript"
VM_KEY_DIR=""
VM_KEY=""

# start_vm_agent: the key of the run, in an ssh-agent of its own that qemu.sh reads
start_vm_agent() {
  [[ -z "$VM_KEY" ]] || return 0
  VM_KEY_DIR="$(mktemp -d)"
  VM_KEY="${VM_KEY_DIR}/key"
  ssh-keygen -q -t ed25519 -N '' -C shellscript-e2e -f "$VM_KEY"
  eval "$(ssh-agent -s)" >/dev/null
  trap 'ssh-agent -k >/dev/null 2>&1; rm -rf "$VM_KEY_DIR"' EXIT
  ssh-add -q "$VM_KEY"
}

# vm_ssh <user> "<command>": runs it in the VM of VM_PORT
vm_ssh() {
  ssh -p "$VM_PORT" -i "$VM_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o BatchMode=yes -o ConnectTimeout=10 \
    "$1@127.0.0.1" "$2"
}

# run_in_vm <test> <image>: boots a VM of the image, prepares it as a container is
# (container.sh, as root), and runs the test in a login of the user it prepared, over
# SSH. The VM is removed after.
run_in_vm() {
  local test="$1" image="$2" name="e2e-$1-$2" code=0
  # Root is sudo, or doas on Alpine: expanded in the VM, not here
  # shellcheck disable=SC2016
  local as_root='$(command -v sudo || command -v doas)'
  if [[ ! -w /dev/kvm ]]; then
    echo "run.sh: '${test}' runs in a VM, which needs /dev/kvm (writable by you)" >&2
    return 1
  fi
  start_vm_agent
  "${QEMU[@]}" remove "$name" --force >/dev/null 2>&1 || true
  # Small enough for a GitHub runner, where the jobs run side by side
  if ! "${QEMU[@]}" start --image "${VM_IMAGES[$image]}" --name "$name" \
      --memory 2G --cpus 1 --disk 10G >"${TMPDIR:-/tmp}/${name}.log" 2>&1; then
    echo "run.sh: could not start the VM ${name}:" >&2
    cat "${TMPDIR:-/tmp}/${name}.log" >&2
    return 1
  fi
  VM_PORT="$(sed -n 's/^VM_SSH_PORT=//p' "${HOME}/.shellscript/qemu/vms/${name}/vm.conf" | tr -d '"')"
  for _ in $(seq 1 100); do vm_ssh "$VM_USER" true 2>/dev/null && break; sleep 3; done
  vm_ssh "$VM_USER" 'cloud-init status --wait >/dev/null 2>&1' || true

  # Where container.sh expects the repository, as a container mounts it
  if ! tar -C "$PUBLIC_DIR" -czf - . | vm_ssh "$VM_USER" "${as_root} mkdir -p /repo && ${as_root} tar -xzf - -C /repo" \
      || ! tar -C "$TESTS_DIR" -czf - . | vm_ssh "$VM_USER" "${as_root} mkdir -p /tests && ${as_root} tar -xzf - -C /tests"; then
    echo "run.sh: could not reach the VM ${name} over SSH" >&2
    code=1
  elif ! vm_ssh "$VM_USER" "${as_root} env E2E_VM=${VM_USER} sh /tests/shared/container.sh ${test}"; then
    code=1
  else
    # GITHUB_TOKEN through stdin, never on a command line of the host
    printf '%s\n' "${GITHUB_TOKEN:-}" | vm_ssh tester "read -r token; if [ -n \"\$token\" ]; then export GITHUB_TOKEN=\"\$token\"; fi; E2E_VERBOSE=${verbose} bash /tests/testcases/${test}.sh" || code=$?
  fi
  "${QEMU[@]}" remove "$name" --force >/dev/null 2>&1 || true
  rm -f "${TMPDIR:-/tmp}/${name}.log"
  return "$code"
}

# changed_shared_symbols <range>: the functions and variables of shared/lib.sh that the
# range changed, one per line, or '*' for a change that is in none of them. A comment or
# an empty line outside a function changes nothing.
changed_shared_symbols() {
  local lines end="${1##*..}"
  # "@@ -a,b +c,d @@": d lines changed from line c of the new file (d is 1 when left
  # out, and 0 for lines that were only taken out, just after line c)
  lines="$(git -C "${TESTS_DIR}/.." diff -U0 "$1" -- tests_e2e/shared/lib.sh \
    | sed -n 's/^@@ -[0-9,]* +\([0-9]*\),\{0,1\}\([0-9]*\) @@.*/\1 \2/p' \
    | while read -r start count; do
        count="${count:-1}"
        if [[ "$count" == "0" ]]; then echo "$start"; else seq "$start" "$((start + count - 1))"; fi
      done | tr '\n' ' ')"
  [[ -n "$lines" ]] || return 0
  # The line numbers are the ones of the file at the end of the range, which may not be
  # the one of the working tree (the merge that a pull request is tested on)
  git -C "${TESTS_DIR}/.." show "${end:-HEAD}:tests_e2e/shared/lib.sh" | awk -v lines=" ${lines}" '
    function changed(symbol) { if (index(lines, " " NR " ")) print symbol }
    /^[a-z_][a-z_0-9]*\(\) *\{/ {
      name = $0; sub(/\(\).*/, "", name); changed(name)
      # A function written on one line closes on it
      inside = ($0 ~ /\}[ \t]*$/) ? "" : name
      next
    }
    inside != "" { changed(inside); if ($0 ~ /^\}/) inside = ""; next }
    /^[ \t]*(#|$)/ { next }
    /^[A-Z_][A-Z_0-9]*=/ { name = $0; sub(/=.*/, "", name); changed(name); next }
    { changed("*") }
  ' | sort -u
}

# shared_function_body <name>: the lines of a function of shared/lib.sh
shared_function_body() {
  awk -v name="$1" '
    index($0, name "() {") == 1 { inside = 1 }
    inside { print; if ($0 ~ /^\}/ || $0 ~ /\}[ \t]*$/ && index($0, name "() {") == 1) exit }
  ' "$SHARED_LIB"
}

# tests_using_shared <range>: the tests that use what the range changed in shared/lib.sh.
# A function that calls a changed one has changed too, and so on.
tests_using_shared() {
  local symbols symbol function file grown=yes
  symbols="$(changed_shared_symbols "$1")"
  [[ -n "$symbols" ]] || return 0
  if grep -qx '\*' <<<"$symbols"; then
    for file in "${TESTS_DIR}"/testcases/*.sh; do basename "$file" .sh; done
    return 0
  fi
  while [[ -n "$grown" ]]; do
    grown=""
    for function in $(sed -n 's/^\([a-z_][a-z_0-9]*\)() *{.*/\1/p' "$SHARED_LIB"); do
      grep -qx "$function" <<<"$symbols" && continue
      for symbol in $symbols; do
        if shared_function_body "$function" | sed 1d | grep -qw -- "$symbol"; then
          symbols+=$'\n'"$function"; grown=yes; break
        fi
      done
    done
  done
  for file in "${TESTS_DIR}"/testcases/*.sh; do
    for symbol in $symbols; do
      if grep -qw -- "$symbol" "$file"; then basename "$file" .sh; break; fi
    done
  done
}

# tests_for_changes <ref or range>: prints the tests of what changed, one per line
tests_for_changes() {
  local range="$1" file name user names="" all=""
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
      tests_e2e/shared/lib.sh)   names+=" $(tests_using_shared "$range" | tr '\n' ' ')" ;;
      tests_e2e/shared/*)        all=yes ;;
      tests_e2e/run.sh)          names+=" all-scripts" ;;
    esac
  done < <(git -C "${TESTS_DIR}/.." diff --name-only "$range")

  if [[ -n "$all" ]]; then
    for file in "${TESTS_DIR}"/testcases/*.sh; do basename "$file" .sh; done
    return 0
  fi
  [[ -n "${names// /}" ]] || return 0
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
    -h|--help) sed -n '2,43p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
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

# run_in_container <test> <image>: runs the test in a fresh container of the image
run_in_container() {
  # -e GITHUB_TOKEN, by name: its value comes from the environment, not the command line
  docker run --rm -e "E2E_VERBOSE=${verbose}" ${GITHUB_TOKEN:+-e GITHUB_TOKEN} ${docker_options[@]+"${docker_options[@]}"} \
    -v "${PUBLIC_DIR}:/repo:ro" -v "${TESTS_DIR}:/tests:ro" \
    "${IMAGES[$2]}" sh /tests/shared/container.sh "$1"
}

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

    started=$SECONDS
    status="PASS"
    if grep -q '^# vm: yes' "$file"; then
      printf '\n######## %s on %s (VM %s)\n' "$test" "$image" "${VM_IMAGES[$image]}"
      run_in_vm "$test" "$image" || status="FAIL"
    else
      printf '\n######## %s on %s (%s)\n' "$test" "$image" "${IMAGES[$image]}"
      run_in_container "$test" "$image" || status="FAIL"
    fi
    [[ "$status" == "PASS" ]] || failed=1
    elapsed=$((SECONDS - started))
    results+=("$(printf '%s  %-28s %dm%02ds' "$status" "${test} on ${image}" $((elapsed / 60)) $((elapsed % 60)))")
  done
done

printf '\n######## Summary\n'
printf '%s\n' "${results[@]}"
printf 'Total: %dm%02ds\n' $((SECONDS / 60)) $((SECONDS % 60))
exit "$failed"
