#!/usr/bin/env bash
# ssh-agent.sh: the shell init that starts ssh-agent and loads the keys, and remove
source "$(dirname "${BASH_SOURCE[0]}")/../shared/lib.sh"

shellrc="${SHELLSCRIPT_HOME}/shellrc/ssh-agent-init.sh"

step "ssh-agent: needs the OpenSSH client, and says so"
load_fails ssh-agent
assert_log "Required command 'ssh-agent' not found"
if on_image ubuntu; then package="openssh-client"; elif on_image fedora; then package="openssh-clients"; else package="openssh"; fi
if sys_install "$package"; then pass "installed ${package}"; else fail "could not install ${package}"; fi

step "ssh-agent: stops when there is no key"
load_fails ssh-agent
assert_log "No SSH private keys found"
assert_missing "$shellrc"

step "ssh-agent: install with the defaults takes every private key of ~/.ssh"
mkdir -p ~/.ssh && chmod 700 ~/.ssh
ssh-keygen -q -t ed25519 -N '' -f ~/.ssh/id_ed25519
ssh-keygen -q -t ed25519 -N '' -f ~/.ssh/work_key
touch ~/.ssh/known_hosts ~/.ssh/config
load ssh-agent
assert_output "cat '${shellrc}'" "ssh-add \"${HOME}/.ssh/id_ed25519\""
assert_output "cat '${shellrc}'" "ssh-add \"${HOME}/.ssh/work_key\""
assert_no_output "cat '${shellrc}'" ".pub"
assert_no_output "cat '${shellrc}'" "known_hosts"
assert_no_output "cat '${shellrc}'" "/config"

step "ssh-agent: a new shell gets an agent with the keys"
assert_output "unset SSH_AUTH_SOCK; . '${shellrc}'; ssh-add -l | wc -l; ssh-agent -k >/dev/null" "2"

step "ssh-agent: --dry-run changes nothing"
before="$(cat "$shellrc")"
load ssh-agent -- --dry-run --key ~/.ssh/work_key
if [[ "$(cat "$shellrc")" == "$before" ]]; then pass "the shell init is the same"; else fail "the dry run changed the shell init"; fi

step "ssh-agent: --key takes only that key"
load ssh-agent -- --key ~/.ssh/work_key
assert_output "cat '${shellrc}'" "ssh-add \"${HOME}/.ssh/work_key\""
assert_no_output "cat '${shellrc}'" "id_ed25519"
assert_output "unset SSH_AUTH_SOCK; . '${shellrc}'; ssh-add -l | wc -l; ssh-agent -k >/dev/null" "1"

step "ssh-agent: remove takes the shell init out"
load remove -- ssh-agent
assert_removed ssh-agent

finish
