#!/usr/bin/env bash
# node-docker.sh: Create Docker-backed Node.js launchers (node, npm, npx, yarn)

set -euo pipefail

echo ">_ node-docker.sh"
echo

print_usage() {
  cat <<'USAGE'
load.sh node-docker -- <node_version> [--manifest]

Installs Docker-backed wrappers for Node.js tools (node, npm, npx, yarn)
under $HOME/.shellscript/bin using node:<version>-alpine Docker image.

Options:
  --manifest    Print installation manifest and exit

Examples:
  load.sh node-docker -- 22
  load.sh node-docker -- 20
  load.sh node-docker -- 22 --manifest

USAGE
}

print_manifest() {
  local version="${1:-VERSION}"
  cat <<MANIFEST
BIN_FILES=node${version} npm${version} npx${version} yarn${version} node npm npx yarn
FOLDERS=\$HOME/.shellscript/node/${version}
SHELLRC_FILE=\$HOME/.shellscript/shellrc/node-init.sh
MANIFEST
}

# Help flag handling
if [[ "${1-}" == "-h" || "${1-}" == "--help" ]]; then
  print_usage
  exit 0
fi

# Parse optional flags
SHOW_MANIFEST=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      print_usage
      exit 0
      ;;
    --manifest)
      SHOW_MANIFEST=1
      shift
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

# If manifest requested, print and exit
if [[ $SHOW_MANIFEST -eq 1 ]]; then
  print_manifest "$NODE_VERSION"
  exit 0
fi
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

# Pull base image and build a customized one with git + bash, and set SHELL
# shellcheck disable=SC2154  # PHP_VERSION is set via case above
if ! docker pull "$NODE_IMAGE"; then
  echo "Error: Failed to pull Docker image ${NODE_IMAGE}" >&2
  exit 4
fi

# Create a derived image that has bash and git installed and SHELL set to /bin/bash
CUSTOM_IMAGE="node:${NODE_VERSION}-alpine-git-bash"

# Always rebuild the custom image: remove existing one if present
if docker image inspect "$CUSTOM_IMAGE" >/dev/null 2>&1; then
  echo "[Debug] Removing existing image ${CUSTOM_IMAGE} before rebuild"
  docker rmi -f "$CUSTOM_IMAGE" >/dev/null 2>&1 || true
fi

echo "[Debug] Creating custom image ${CUSTOM_IMAGE} from ${NODE_IMAGE} (installing git and bash)"
TEMP_CONT="node-setup-${NODE_VERSION}-$$"
CLEANUP() {
  # best-effort remove temp container
  docker rm -f "$TEMP_CONT" >/dev/null 2>&1 || true
}
trap CLEANUP EXIT

# Ensure no leftover container with the same name
docker rm -f "$TEMP_CONT" >/dev/null 2>&1 || true

# Start a long-running container
if ! docker run -d --name "$TEMP_CONT" "$NODE_IMAGE" sh -c "sleep infinity"; then
  echo "Error: Failed to start temporary container from ${NODE_IMAGE}" >&2
  exit 4
fi

# Install bash and git inside the container
if ! docker exec "$TEMP_CONT" sh -lc "apk update && apk add --no-cache bash git"; then
  echo "Error: Failed to install bash and git inside temporary container" >&2
  exit 4
fi

# Commit the container as a new image with SHELL env set
if ! docker commit \
    --change 'ENV SHELL=/bin/bash' \
    "$TEMP_CONT" "$CUSTOM_IMAGE" >/dev/null; then
  echo "Error: Failed to commit custom image ${CUSTOM_IMAGE}" >&2
  exit 4
fi

# Stop and remove temp container (trap will also try)
docker rm -f "$TEMP_CONT" >/dev/null 2>&1 || true
trap - EXIT

# Use the custom image for the wrappers
NODE_IMAGE="$CUSTOM_IMAGE"

BASE_FOLDER="$HOME/.shellscript"
DEST_FOLDER="$BASE_FOLDER/bin"
SHELLRC_FOLDER="$BASE_FOLDER/shellrc"
NODE_NPM="$BASE_FOLDER/node/${NODE_VERSION}"
NODE_BIN="$NODE_NPM/.npm-global/bin"
NODE_NPMRC="$HOME/.npmrc"
CONTAINER_HOME="${HOME}"
REGULAR_USER="-u \"$(id -u)\":\"$(id -g)\""
WORKDIR="/c/\${PWD}"

if [[ $EUID -eq 0 ]]; then
  echo "Error: This script should not be run as root/sudo." >&2
  echo "Please run as a regular user." >&2
  exit 5
fi

echo "[Debug] Creating $BASE_FOLDER/node/${NODE_VERSION} folder"
mkdir -p "${DEST_FOLDER}"
mkdir -p "${SHELLRC_FOLDER}"
mkdir -p "$NODE_NPM"
mkdir -p "$NODE_NPM/.npm"
mkdir -p "$NODE_BIN"
touch "$NODE_NPMRC"
cp "$NODE_NPMRC" "$NODE_NPM/.npmrc"

# Configure npm to use custom prefix for global installs
sed -i '/^prefix=/d' "$NODE_NPM/.npmrc"
echo "prefix=${CONTAINER_HOME}/.npm-global" >> "$NODE_NPM/.npmrc"

echo "[Debug] Update Path"
cat >"${SHELLRC_FOLDER}/node-init.sh" <<WRAP
export PATH="\$PATH:$NODE_BIN"
WRAP


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

TTY_ARG=""
if [ -t 0 ]; then
    TTY_ARG="-i"
fi
if [ -t 1 ]; then
    TTY_ARG="\${TTY_ARG} -t"
fi


ARGS=()
for arg in "\$@"; do
    arg=\$(echo "\$arg" | sed "s|${NODE_BIN}|${CONTAINER_HOME}/.npm-global/bin|g")

    # Check if argument is an absolute path (starts with /)
    if [[ "\$arg" = /* ]]; then
        # Convert absolute path to relative path from PWD
        RELATIVE_PATH="\${arg#\$PWD/}"
        # If the path is actually under PWD, use the relative path
        if [[ "\$RELATIVE_PATH" != "\$arg" ]]; then
            ARGS+=("\$RELATIVE_PATH")
        else
            # Path is outside PWD, keep it as is (will likely fail in container)
            ARGS+=("\$arg")
        fi
    else
        # Not an absolute path, keep as is
        ARGS+=("\$arg")
    fi
done

DOCKER_ARGS=(
  \${TTY_ARG} --rm
  -v "\${PWD}":"${WORKDIR}"
  -w "${WORKDIR}"
  ${REGULAR_USER}
  --network host
  -e "HOME=${CONTAINER_HOME}"
  -v "${NODE_NPM}:${CONTAINER_HOME}"
)

# Enable inspector if requested
if [[ "${NODE_INSPECT:-}" != "" ]]; then
  HOST_PORT="${NODE_INSPECT_PORT:-9229}"
  DOCKER_ARGS+=( -e "NODE_OPTIONS=--inspect=0.0.0.0:9229" )
fi

exec docker run "\${DOCKER_ARGS[@]}" "$NODE_IMAGE" /usr/local/bin/node "\${ARGS[@]}"
WRAP
chmod +x "${DEST_FOLDER}/node${NODE_VERSION}"

cat >"${DEST_FOLDER}/npm${NODE_VERSION}" <<WRAP
#!/usr/bin/env bash
set -euo pipefail

TTY_ARG=""
if [ -t 0 ]; then
    TTY_ARG="-i"
fi
if [ -t 1 ]; then
    TTY_ARG="\${TTY_ARG} -t"
fi

DOCKER_ARGS=(
  \${TTY_ARG} --rm
  -v "\${PWD}":"${WORKDIR}"
  -w "${WORKDIR}"
  ${REGULAR_USER}
  -e "HOME=${CONTAINER_HOME}"
  --network host
  -v "${NODE_NPM}:${CONTAINER_HOME}"
)

if [ -f "$NODE_BIN/npm" ]; then
  NPM_PATH="$CONTAINER_HOME/.npm-global/bin/npm"
else
  NPM_PATH="/usr/local/bin/npm"
fi


exec docker run "\${DOCKER_ARGS[@]}" "$NODE_IMAGE" "\$NPM_PATH" "\$@"
WRAP
chmod +x "${DEST_FOLDER}/npm${NODE_VERSION}"

# create: ${DEST_FOLDER}/npx
cat >"${DEST_FOLDER}/npx${NODE_VERSION}" <<WRAP
#!/usr/bin/env bash
set -euo pipefail
# Wrapper to run npx inside Docker with persistent cache/config.

TTY_ARG=""
if [ -t 0 ]; then
    TTY_ARG="-i"
fi
if [ -t 1 ]; then
    TTY_ARG="\${TTY_ARG} -t"
fi

DOCKER_ARGS=(
  \${TTY_ARG} --rm
  -v "\${PWD}":"${WORKDIR}"
  -w "${WORKDIR}"
  ${REGULAR_USER}
  -e "HOME=${CONTAINER_HOME}"
  --network host
  -v "${NODE_NPM}:${CONTAINER_HOME}"
)

if [ -f "$NODE_BIN/npx" ]; then
  NPX_PATH="$CONTAINER_HOME/.npm-global/bin/npx"
else
  NPX_PATH="/usr/local/bin/npx"
fi

exec docker run "\${DOCKER_ARGS[@]}" "$NODE_IMAGE" "\$NPX_PATH" "\$@"
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

TTY_ARG=""
if [ -t 0 ]; then
    TTY_ARG="-i"
fi
if [ -t 1 ]; then
    TTY_ARG="\${TTY_ARG} -t"
fi

DOCKER_ARGS=(
  \${TTY_ARG} --rm
  -v "\${PWD}":"${WORKDIR}"
  -w "${WORKDIR}"
  ${REGULAR_USER}
  -e "HOME=${CONTAINER_HOME}"
  --network host
  -v "${NODE_NPM}:${CONTAINER_HOME}"
  -v "${YARN_CACHE_DIR}:${CONTAINER_HOME}/.cache/yarn"
)

if [ -f "$NODE_BIN/yarn" ]; then
  YARN_PATH="$CONTAINER_HOME/.npm-global/bin/yarn"
else
  YARN_PATH="/usr/local/bin/yarn"
fi

# Mount .yarnrc or .yarnrc.yml if present
if [[ -f "${HOME}/.yarnrc" ]]; then
  DOCKER_ARGS+=( -v "${HOME}/.yarnrc:${CONTAINER_HOME}/.yarnrc:ro" )
elif [[ -f "${HOME}/.yarnrc.yml" ]]; then
  DOCKER_ARGS+=( -v "${HOME}/.yarnrc.yml:${CONTAINER_HOME}/.yarnrc.yml:ro" )
fi

exec docker run "\${DOCKER_ARGS[@]}" "$NODE_IMAGE" "\$YARN_PATH "\$@"
WRAP
chmod +x "${DEST_FOLDER}/yarn${NODE_VERSION}"

ln -sf "${DEST_FOLDER}/node${NODE_VERSION}" "${DEST_FOLDER}/node"
ln -sf "${DEST_FOLDER}/npm${NODE_VERSION}" "${DEST_FOLDER}/npm"
ln -sf "${DEST_FOLDER}/npx${NODE_VERSION}" "${DEST_FOLDER}/npx"
ln -sf "${DEST_FOLDER}/yarn${NODE_VERSION}" "${DEST_FOLDER}/yarn"
