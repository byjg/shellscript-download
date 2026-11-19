#!/usr/bin/env bash
# ssh-agent.sh: the shell init that starts ssh-agent and loads the keys, and remove
source "$(dirname "${BASH_SOURCE[0]}")/../shared/lib.sh"

shellrc="${SHELLSCRIPT_HOME}/shellrc/ssh-agent-init.sh"

# The running agents, from /proc: the images do not all have pgrep. A killed agent stays
# a zombie, since nothing in the container reaps it, and is not counted.
running_agents() {
  local p
  for p in /proc/[0-9]*; do
    [[ "$(cat "$p/comm" 2>/dev/null)" == "ssh-agent" ]] || continue
    grep -q '^State:.*Z' "$p/status" 2>/dev/null || echo "${p#/proc/}"
  done
}
export -f running_agents
kill_agents() { running_agents | xargs -r kill; }

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

step "ssh-agent: a --key that does not exist stops, and keeps the shell init"
before="$(cat "$shellrc")"
load_fails ssh-agent -- --key ~/.ssh/no_such_key
assert_log "Key not found: ${HOME}/.ssh/no_such_key"
if [[ "$(cat "$shellrc")" == "$before" ]]; then pass "the shell init is the same"; else fail "the shell init changed"; fi

step "ssh-agent: new shells share one agent, and add the key once"
new_shell="bash -c 'unset SSH_AUTH_SOCK SSH_AGENT_PID; . ${shellrc}' 2>&1"
assert_output "$new_shell" "Identity added: ${HOME}/.ssh/work_key"
assert_no_output "$new_shell" "Identity added"
assert_output "running_agents | wc -l" "1"
assert_output "SSH_AUTH_SOCK=${HOME}/.ssh/agent.sock ssh-add -l | wc -l" "1"

step "ssh-agent: a key that is gone is warned about, and starts no other agent"
mv ~/.ssh/work_key ~/.ssh/work_key.bak
kill_agents
assert_output "$new_shell" "ssh-agent-init: key not found: ${HOME}/.ssh/work_key"
assert_output "$new_shell" "ssh-agent-init: key not found"
assert_output "running_agents | wc -l" "1"
kill_agents
mv ~/.ssh/work_key.bak ~/.ssh/work_key

step "ssh-agent: remove takes the shell init out"
load remove -- ssh-agent
assert_removed ssh-agent

finish
