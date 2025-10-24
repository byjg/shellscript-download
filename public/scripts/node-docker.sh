#!/usr/bin/env bash
# node-docker.sh: Create Docker-backed Node.js launchers (node, npm, npx, yarn)
# Usage (via loader):
#   load.sh node-docker -- [--tty] <node_version>
#
#   Options:
#     --tty    Enable TTY mode for wrappers (docker run will use -it instead of -i)
#
# Examples:
#   load.sh node-docker -- 22
#   load.sh node-docker -- --tty 22
#   load.sh node-docker -- 20
#
# Description:
# - Generates wrapper scripts in "$HOME/.shellscript/bin" for the selected Node version:
#     - node<ver> → runs Node inside node:<ver>-alpine
#     - npm<ver>  → runs npm inside node:<ver>-alpine (persisting ~/.npm and honoring ~/.npmrc)
#     - npx<ver>  → runs npx inside node:<ver>-alpine
#     - yarn<ver> → runs yarn inside node:<ver>-alpine (persisting ~/.cache/yarn)
# - Also updates convenience symlinks: node, npm, npx, yarn → their <ver> counterparts.
# - Pulls the specified Docker image and marks the wrappers executable.
# - Intended for environments where Node.js tooling is not installed natively.
#
# Notes:
# - Typical versions: 18, 20, 22 (any tag supported by docker hub node:<tag>-alpine)
# - Requires Docker installed and available on PATH. Install with `load.sh docker`
# - This script is idempotent and can be re-run to switch versions.

set -euo pipefail

echo ">_ node-docker.sh"
echo

print_usage() {
  cat <<'USAGE'
load.sh node-docker -- [--tty] <node_version>

Installs Docker-backed wrappers for Node.js tools (node, npm, npx, yarn)
under $HOME/.shellscript/bin using node:<version>-alpine Docker image.

Options:
  --tty    Enable TTY mode for wrappers (docker run will use -it instead of -i)

Examples:
  load.sh node-docker -- 22
  load.sh node-docker -- --tty 22
  load.sh node-docker -- 20

USAGE
}

# Help flag handling
if [[ "${1-}" == "-h" || "${1-}" == "--help" ]]; then
  print_usage
  exit 0
fi

# Parse optional flags
TTY_ARG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tty)
      TTY_ARG="-t"
      shift
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
  esac
done

# Validate argument
if [[ $# -lt 1 ]]; then
  echo "Error: <node_version> is required." >&2
  echo >&2
  print_usage >&2
  exit 2
fi

NODE_VERSION=$1
NODE_IMAGE="node:${NODE_VERSION}-alpine"

#case "$1" in
#  "5.6"|"7.0"|"7.1"|"7.2"|"7.3"|"7.4"|"8.0"|"8.1"|"8.2"|"8.3"|"8.4"|"8.5")
#    PHP_VERSION="$1"
#    ;;
#  *)
#    echo "Error: Invalid PHP version. Supported versions are: 5.6, 7.0, 7.1, 7.2, 7.3, 7.4, 8.0, 8.1, 8.2, 8.3, 8.4, 8.5" >&2
#    exit 1
#    ;;
#esac

# Pre-flight: docker availability
if ! command -v docker >/dev/null 2>&1; then
  echo "Error: Docker is required but was not found on PATH." >&2
  exit 3
fi

# Pull image and make wrappers executable
# shellcheck disable=SC2154  # PHP_VERSION is set via case above
if ! docker pull "$NODE_IMAGE"; then
  echo "Error: Failed to pull Docker image ${NODE_IMAGE}" >&2
  exit 4
fi

BASE_FOLDER="$HOME/.shellscript"
DEST_FOLDER="$BASE_FOLDER/bin"
NODE_NPM="$BASE_FOLDER/node/${NODE_VERSION}/.npm"
NODE_MODULES="$BASE_FOLDER/node/${NODE_VERSION}/node_modules"
NODE_BIN="$BASE_FOLDER/node/${NODE_VERSION}/bin"
NODE_NPMRC="$HOME/.npmrc"
CONTAINER_HOME="/tmp/home"
REGULAR_USER="-u \"$(id -u)\":\"$(id -g)\""
mkdir -p "${DEST_FOLDER}"
mkdir -p "$NODE_NPM"
mkdir -p "$NODE_BIN"

if [ ! -f "$NODE_MODULES" ]; then
  docker run -i ${TTY_ARG} --rm  \
    -v $NODE_MODULES:/tmp/xyz10 \
    ${NODE_IMAGE} sh -c "cp -R /usr/local/lib/node_modules/* /tmp/xyz10"
fi

if [[ $EUID -eq 0 ]]; then
  echo "Error: This script should not be run as root/sudo." >&2
  echo "Please run as a regular user." >&2
  exit 5
fi

cat >"${DEST_FOLDER}/node${NODE_VERSION}" <<WRAP
#!/usr/bin/env bash
set -euo pipefail
# Wrapper to run Node inside Docker, similar to your PHP wrapper.
# Usage:
#   node app.js
#   NODE_INSPECT=1 ./node app.js
#
# Env:
#   NODE_VERSION=22          # default if unset
#   NODE_INSPECT=1           # enable inspector (maps port 9229)
#   NODE_INSPECT_PORT=9229   # optional custom port on host/container

NODE_INSPECT=1
NODE_INSPECT_PORT=9229

DOCKER_ARGS=(
  -i ${TTY_ARG} --rm
  -v "\${PWD}":/workdir
  -w /workdir
  ${REGULAR_USER}
  --network host
  -e "HOME=${CONTAINER_HOME}"
  -v "${NODE_MODULES}:/usr/local/lib/node_modules"
  -v "${NODE_NPM}:${CONTAINER_HOME}/.npm"
)

# Pass read-only .npmrc if present
if [[ -f "${NODE_NPMRC}" ]]; then
  DOCKER_ARGS+=( -v "${NODE_NPMRC}:${CONTAINER_HOME}/.npmrc:ro" )
fi

# Enable inspector if requested
if [[ "${NODE_INSPECT:-}" != "" ]]; then
  HOST_PORT="${NODE_INSPECT_PORT:-9229}"
  DOCKER_ARGS+=( -e "NODE_OPTIONS=--inspect=0.0.0.0:9229" )
fi

exec docker run "\${DOCKER_ARGS[@]}" "$NODE_IMAGE" node "\$@"
WRAP
chmod +x "${DEST_FOLDER}/node${NODE_VERSION}"

cat >"${DEST_FOLDER}/npm${NODE_VERSION}" <<WRAP
#!/usr/bin/env bash
set -euo pipefail

# Check if this is a global operation that requires root privileges
RUN_AS_USER="${REGULAR_USER}"
IS_GLOBAL=false
for arg in "\$@"; do
  case "\$arg" in
    -g|--global)
      # Global operations need root access, remove user restriction
      RUN_AS_USER=""
      IS_GLOBAL=true
      break
      ;;
  esac
done

DOCKER_ARGS=(
  -i ${TTY_ARG} --rm
  -v "\${PWD}":/workdir
  -w /workdir
  \${RUN_AS_USER}
  -e "HOME=${CONTAINER_HOME}"
  --network host
  -v "${NODE_MODULES}:/usr/local/lib/node_modules"
  -v "${NODE_NPM}:${CONTAINER_HOME}/.npm"
)

# Mount host bin folder for global installs
if [[ "\${IS_GLOBAL}" == "true" ]]; then
  DOCKER_ARGS+=( -v "${NODE_BIN}:/host-bin" )
fi

if [[ -f "${NODE_NPMRC}" ]]; then
  DOCKER_ARGS+=( -v "${NODE_NPMRC}:${CONTAINER_HOME}/.npmrc:ro" )

  # If you use a custom per-user global prefix, mount it
  if grep -q '^prefix=' "${NODE_NPMRC}" 2>/dev/null; then
    PREFIX_DIR="\$(awk -F= '/^prefix=/{print \$2}' "${NODE_NPMRC}")"
    mkdir -p "\${PREFIX_DIR}"
    DOCKER_ARGS+=( -v "\${PREFIX_DIR}:\${PREFIX_DIR}" )
  fi
fi

# For global installs, wrap the command to capture new files
if [[ "\${IS_GLOBAL}" == "true" ]]; then
  exec docker run "\${DOCKER_ARGS[@]}" "$NODE_IMAGE" sh -c '
    # Capture files before npm install
    ls -1 /usr/local/bin > /tmp/before.txt 2>/dev/null || touch /tmp/before.txt

    # Run npm command
    npm "\$@"
    NPM_EXIT=\$?

    # If npm succeeded, copy new files to host
    if [ \$NPM_EXIT -eq 0 ]; then
      ls -1 /usr/local/bin > /tmp/after.txt 2>/dev/null || touch /tmp/after.txt

      # Find new files (in after but not in before)
      for file in \$(comm -13 /tmp/before.txt /tmp/after.txt); do
        if [ -f "/usr/local/bin/\$file" ]; then
          cp -p "/usr/local/bin/\$file" "/host-bin/\$file"
          echo "Copied new file to host: \$file"
        fi
      done
    fi

    exit \$NPM_EXIT
  ' -- "\$@"
else
  exec docker run "\${DOCKER_ARGS[@]}" "$NODE_IMAGE" npm "\$@"
fi
WRAP
chmod +x "${DEST_FOLDER}/npm${NODE_VERSION}"

# create: ${DEST_FOLDER}/npx
cat >"${DEST_FOLDER}/npx${NODE_VERSION}" <<WRAP
#!/usr/bin/env bash
set -euo pipefail
# Wrapper to run npx inside Docker with persistent cache/config.

IMAGE="node:${NODE_VERSION}-alpine"

DOCKER_ARGS=(
  -i ${TTY_ARG} --rm
  -v "\${PWD}":/workdir
  -w /workdir
  ${REGULAR_USER}
  -e "HOME=${CONTAINER_HOME}"
  --network host
  -v "${NODE_MODULES}:/usr/local/lib/node_modules"
  -v "${NODE_NPM}:${CONTAINER_HOME}/.npm"
)

if [[ -f "${NODE_NPMRC}" ]]; then
  DOCKER_ARGS+=( -v "${NODE_NPMRC}:${CONTAINER_HOME}/.npmrc:ro" )
fi

exec docker run "\${DOCKER_ARGS[@]}" "$NODE_IMAGE" npx "\$@"
WRAP
chmod +x "${DEST_FOLDER}/npx${NODE_VERSION}"

# create: ${DEST_FOLDER}/yarn
YARN_CACHE_DIR="${HOME}/.cache/yarn"
mkdir -p "$YARN_CACHE_DIR"
cat >"${DEST_FOLDER}/yarn${NODE_VERSION}" <<WRAP
#!/usr/bin/env bash
set -euo pipefail
# Wrapper to run Yarn inside Docker.
# Mirrors the behavior of npm/node wrappers.
#
# Usage:
#   ./yarn install
#   ./yarn run dev
#   NODE_VERSION=22 ./yarn build
#
# Environment Variables:
#   NODE_VERSION=22        # Node image tag (default 22)
#   YARN_CACHE_DIR         # Override cache dir (default ~/.cache/yarn)

DOCKER_ARGS=(
  -i ${TTY_ARG} --rm
  -v "\${PWD}":/workdir
  -w /workdir
  ${REGULAR_USER}
  -e "HOME=${CONTAINER_HOME}"
  --network host
  -v "${NODE_MODULES}:/usr/local/lib/node_modules"
  -v "${NODE_NPM}:${CONTAINER_HOME}/.npm"          # npm cache (some Yarn uses npm)
  -v "${YARN_CACHE_DIR}:${CONTAINER_HOME}/.cache/yarn"
)

# Mount .yarnrc or .yarnrc.yml if present
if [[ -f "${HOME}/.yarnrc" ]]; then
  DOCKER_ARGS+=( -v "${HOME}/.yarnrc:${CONTAINER_HOME}/.yarnrc:ro" )
elif [[ -f "${HOME}/.yarnrc.yml" ]]; then
  DOCKER_ARGS+=( -v "${HOME}/.yarnrc.yml:${CONTAINER_HOME}/.yarnrc.yml:ro" )
fi

exec docker run "\${DOCKER_ARGS[@]}" "$NODE_IMAGE" yarn "\$@"
WRAP
chmod +x "${DEST_FOLDER}/yarn${NODE_VERSION}"

ln -sf "${DEST_FOLDER}/node${NODE_VERSION}" "${DEST_FOLDER}/node"
ln -sf "${DEST_FOLDER}/npm${NODE_VERSION}" "${DEST_FOLDER}/npm"
ln -sf "${DEST_FOLDER}/npx${NODE_VERSION}" "${DEST_FOLDER}/npx"
ln -sf "${DEST_FOLDER}/yarn${NODE_VERSION}" "${DEST_FOLDER}/yarn"
