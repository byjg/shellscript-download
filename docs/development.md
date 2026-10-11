---
sidebar_position: 2
description: "Run a script from a working copy with load.sh --developer, before it is published"
---

# Testing scripts before publishing

`load.sh` normally downloads a script from shellscript.download and keeps a copy in
`$HOME/.shellscript/downloads`. While you change a script, you want it to run your working
copy instead, with the same helpers and environment the loader gives a published script. That
is what `--developer` does.

## Run a working copy with `--developer`

`--developer <path>` makes `load.sh` run `<path>/<script>.sh` from a local folder. Nothing is
downloaded, and the cached copy in `$HOME/.shellscript/downloads` is neither used nor changed.

```bash
# From a clone of the repository: run maven.sh from the working tree
load.sh --developer ./public/scripts maven

# Options of the script go after "--", as usual
load.sh --developer ./public/scripts maven -- --dry-run --version 3.9.6

# Check that the script is found and prepared, without running it
load.sh --developer ./public/scripts --dont-run maven
```

`load.sh` errors if `<path>/<script>.sh` does not exist. A script that shares a file from
`public/scripts/lib/` reads it from the local folder too: the post-load hook that downloads it
is not called in this mode.

The same works from another project. A test suite can be pointed at your working copy before
anything is published, for example:

```bash
load.sh --developer ~/src/shellscript-download/public/scripts qemu -- start --image ubuntu-24.04 --bridge virbr0
```

## Test a change to `load.sh` itself

The loader you have installed is `$HOME/.shellscript/bin/load.sh`, and it only changes when you
reinstall it. To try a change to the loader, run the copy in the repository, with
`--developer` so that the scripts come from the working tree as well:

```bash
bash ./public/scripts/load.sh --developer ./public/scripts qemu -- list
```

## Capture a script's output

The loader writes its own messages to stderr, and stdout carries only what the script prints,
so a script's output can be captured:

```bash
ip=$(load.sh qemu -- address node1)
```

Loaders installed before this change print their banner on stdout. A caller that has to work
with them keeps only the lines it expects.

## Before opening a pull request

```bash
bash -n public/scripts/<name>.sh     # syntax
npm run build                        # regenerates the script pages, docs/scripts and completion
```

Then run its test.

## Run the end-to-end tests

Every script has a test in `tests_e2e/testcases/`. `tests_e2e/run.sh` runs each one in a fresh
Docker container of each standard image (Ubuntu, Fedora, Alpine), as a regular user, on a
machine where the loader is installed from your working copy. The tests call
`load.sh <script> -- <options>`, as a user does, and nothing is installed on your machine.

```bash
tests_e2e/run.sh maven                  # one test, on every image
tests_e2e/run.sh --image alpine maven   # on one image
tests_e2e/run.sh --verbose maven        # also show the output of every load.sh
tests_e2e/run.sh                        # every test: about 40 minutes
tests_e2e/run.sh --changed main         # the tests of what your branch changed since main
```

A pull request runs that last one by itself: for each script of `public/scripts` it changes,
the test of that script, and `all-scripts`, which checks what every script must do
(`.github/workflows/e2e.yml`).

A new script comes with its test. `tests_e2e/shared/lib.sh` has the assertions and the tests
that scripts of the same kind share, so that most tests are a few lines: see
`tests_e2e/testcases/jq.sh`.

The scripts look up the latest version of some tools in the GitHub API, which answers 60
requests an hour to who does not identify itself. If a run is refused, give it a token:

```bash
GITHUB_TOKEN=$(gh auth token) tests_e2e/run.sh
```

## Test by hand in a clean environment

To try a script by hand, use a clean, non-root Linux. The simplest is a Docker container with
the working tree mounted:

```bash
docker run -it --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$(pwd)/public/scripts":/scripts:ro \
  -v "$(pwd)/public/install":/install:ro \
  ubuntu:24.04 bash
```

Inside the container, create an unprivileged user, since scripts refuse to run as root:

```bash
apt update && apt install -y curl sudo

useradd -m -s /bin/bash user
echo 'user ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

su - user
```

Then install the loader from the mounted folder and run your script, with no network needed
for either:

```bash
bash /install/loader --developer

load.sh --developer /scripts <name> -- --dry-run
```
