#!/usr/bin/env bash
# nvm.sh: install NVM, install Node with it, remove and purge
source "$(dirname "${BASH_SOURCE[0]}")/../shared/lib.sh"

nvm_home="${HOME}/.nvm"
shellrc="${SHELLSCRIPT_HOME}/shellrc/nvm-init.sh"

step "nvm: install with the defaults"
load nvm
assert_exists "${nvm_home}/nvm.sh"
assert_output ". '${shellrc}'; nvm --version" "0."

step "nvm: the installer of NVM leaves nothing in the shell rc files"
assert_output "grep -qs NVM_DIR ~/.bashrc ~/.bash_profile ~/.profile && echo found || echo clean" "clean"

# The Node that NVM downloads is built for glibc
if on_image alpine; then
  skip "nvm install: no Node for the C library of this image"
else
  step "nvm: installs Node"
  assert_output ". '${shellrc}'; nvm install --lts >/dev/null 2>&1; node --version" "v"
fi

step "nvm: install again works"
load nvm
assert_output ". '${shellrc}'; nvm --version" "0."

step "nvm: remove keeps the folder"
load remove -- nvm
assert_removed nvm
assert_exists "$nvm_home"

step "nvm: purge removes the folder"
load nvm
load remove -- nvm --purge
assert_removed nvm
assert_purged "$nvm_home"

finish
