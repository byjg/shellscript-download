#!/bin/sh
# container.sh: prepares a container, or a VM, and runs one test case in it. Started by
# run.sh, as root. Usage: container.sh <testcase>
#
# load.sh never runs as root: the test runs as 'tester', a regular user with sudo.
# The container is left as a machine where the loader was installed, with the working
# copy of the repository (/repo is its public folder) in place of what is published:
#   - the installer puts load.sh in ~/.shellscript/bin, as it does for a user
#   - the scripts are in ~/.shellscript/downloads, the cache of the loader, where it
#     finds them and downloads nothing
# The tests then call 'load.sh <script> -- <options>', as the documentation says.
set -eu

setup() {
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq bash bash-completion curl ca-certificates sudo
    useradd --create-home --shell /bin/bash tester
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y -q bash bash-completion curl sudo shadow-utils util-linux tar gzip
    useradd --create-home --shell /bin/bash tester
  elif command -v apk >/dev/null 2>&1; then
    apk add -q bash bash-completion curl ca-certificates sudo
    adduser -D -s /bin/bash tester
  else
    echo "no supported package manager in this image"
    return 2
  fi
}

# Quiet unless it fails
if ! setup >/tmp/setup.log 2>&1; then
  echo "container.sh: could not prepare the container:" >&2
  cat /tmp/setup.log >&2
  exit 2
fi
echo 'tester ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/tester

# Fedora keeps /etc/shadow with no permission at all, and its sudo reads it through a
# helper (unix_chkpwd) that then needs a capability to do so. In a privileged container,
# the AppArmor of an Ubuntu 24.04 host (a GitHub runner) applies its own profile to that
# helper, which denies the capability: sudo fails with "PAM account management error".
# Readable by its owner, root, the file needs no capability.
chmod u+r /etc/shadow

if ! su tester -c 'sh /repo/install/loader --developer \
    && mkdir -p ~/.shellscript/downloads \
    && cp -r /repo/scripts/. ~/.shellscript/downloads/' >/tmp/install.log 2>&1; then
  echo "container.sh: could not install the loader:" >&2
  cat /tmp/install.log >&2
  exit 2
fi

# '# needs: docker': a running Docker, and the user in its group before the session of
# the test starts. Only in a VM (# vm: yes), which has an init system to run it.
prepare_docker() {
  if command -v apk >/dev/null 2>&1; then
    # The installer of Docker has no packages for Alpine
    apk add -q docker && addgroup tester docker \
      && rc-update add docker default && rc-service docker start
  else
    su tester -c '~/.shellscript/bin/load.sh docker'
  fi
  for _ in $(seq 1 60); do docker info >/dev/null 2>&1 && return 0; sleep 1; done
  echo "Docker did not start"
  return 1
}
if grep -q '^# needs: docker' "/tests/testcases/$1.sh" && ! prepare_docker >/tmp/docker.log 2>&1; then
  echo "container.sh: could not prepare Docker:" >&2
  cat /tmp/docker.log >&2
  exit 2
fi

# In a VM the test runs in a login of its own, over SSH (run.sh), as a user's session:
# tester takes the key of the user of the VM
if [ -n "${E2E_VM:-}" ]; then
  mkdir -p /home/tester/.ssh
  cp "/home/${E2E_VM}/.ssh/authorized_keys" /home/tester/.ssh/
  chown -R tester:tester /home/tester/.ssh
  chmod 700 /home/tester/.ssh
  # Without a password, and not locked (Alpine creates it locked): sshd lets it in
  echo 'tester:*' | chpasswd -e
  exit 0
fi

exec su tester -c "E2E_VERBOSE=${E2E_VERBOSE:-} bash /tests/testcases/$1.sh"
