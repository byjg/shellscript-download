#!/bin/sh
# container.sh: prepares a container and runs one test case in it. Started by run.sh,
# as root. Usage: container.sh <testcase>
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

if ! su tester -c 'sh /repo/install/loader --developer \
    && mkdir -p ~/.shellscript/downloads \
    && cp -r /repo/scripts/. ~/.shellscript/downloads/' >/tmp/install.log 2>&1; then
  echo "container.sh: could not install the loader:" >&2
  cat /tmp/install.log >&2
  exit 2
fi

exec su tester -c "E2E_VERBOSE=${E2E_VERBOSE:-} bash /tests/testcases/$1.sh"
