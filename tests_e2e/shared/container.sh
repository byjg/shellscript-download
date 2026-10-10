#!/bin/sh
# container.sh: prepares a container and runs one test case in it. Started by run.sh,
# as root. Usage: container.sh <testcase>
#
# load.sh never runs as root: the test runs as 'tester', a regular user with sudo.
set -eu

setup() {
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq bash curl ca-certificates sudo
    useradd --create-home --shell /bin/bash tester
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y -q bash curl sudo shadow-utils util-linux tar gzip
    useradd --create-home --shell /bin/bash tester
  elif command -v apk >/dev/null 2>&1; then
    apk add -q bash curl ca-certificates sudo
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

exec su tester -c "bash /tests/testcases/$1.sh"
