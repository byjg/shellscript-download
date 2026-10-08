#!/usr/bin/env bash
# node-docker.sh: Create Docker-backed Node.js launchers (node, npm, npx, yarn)

set -euo pipefail


print_usage() {
  cat <<'USAGE'
node-docker.sh <node_version> [--add package1,package2,...] [--volume /path1,/path2,...] [--env NAME1,NAME2,...] [--postinstall /path/to/script] [--no-postinstall] [--skip packages,postinstall] [--manifest]

Installs Docker-backed wrappers for Node.js tools (node, npm, npx, yarn)
under $HOME/.shellscript/bin using node:<version>-alpine Docker image.

Options:
  --add <packages>      Install additional Alpine packages (comma-separated list),
                        besides bash and git. Saved to
                        $HOME/.shellscript/node/packages.conf and re-applied on
                        every install/update.
                        Example: --add python3,make,g++
  --volume <paths>      Extra host directories to mount inside the container
                        (comma-separated list), next to the current directory, so
                        a dependency such as "file:../other-package" resolves.
                        Saved to $HOME/.shellscript/node/volumes.conf, which the
                        wrappers read at runtime, so you can also edit it directly.
                        Example: --volume /home/user/projects
  --env <names>         The wrappers forward the host environment to the container,
                        except the variables that describe the host itself (desktop
                        session, systemd, terminal and IDE, host toolchains such as
                        JAVA_HOME or NVM_*, SSH_* and agents). Use --env to forward
                        some of those anyway (comma-separated names or patterns).
                        Saved to $HOME/.shellscript/node/env.conf, which the wrappers
                        read at runtime, so you can also edit it directly.
                        Example: --env JAVA_HOME,XDG_RUNTIME_DIR
  --postinstall <script>
                        Script to run as root inside the image after the packages
                        are installed, for what apk cannot do. Copied to
                        $HOME/.shellscript/node/<version>/postinstall.sh so it
                        belongs to that Node version only and runs again on every
                        install/update of it. The script receives NODE_VERSION.
                        A line "# ENV NAME=value" in the script sets that environment
                        variable in the image.
                        Example: --postinstall ./install-tools.sh
  --no-postinstall      Delete the saved post-install script of this Node version.
  --skip <steps>        Leave out steps for this run only, without changing what
                        is saved (comma-separated list): "packages" (the Alpine
                        packages) and/or "postinstall" (the post-install script).
                        Example: --skip postinstall
  --manifest            Print installation manifest and exit. Without a version it
                        covers every installed version and the saved configuration,
                        which is what "load.sh remove -- node-docker" uses.

Examples:
  load.sh node-docker -- 22
  load.sh node-docker -- 20
  load.sh node-docker -- 22 --add python3,make,g++
  load.sh node-docker -- 22 --volume /home/user/projects
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
# Code shared with the other Docker-backed wrappers. load.sh calls postLoad once,
# right after it downloads or updates this script; a loader older than that hook
# never does, so the file is also fetched here when it is missing.
SHARED_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/docker-wrapper.sh"

postLoad() {
  mkdir -p "$(dirname "$SHARED_LIB")"
  if ! download "https://shellscript.download/scripts/lib/docker-wrapper.sh" "$SHARED_LIB"; then
    echo "Error: could not download lib/docker-wrapper.sh, which this script needs" >&2
    exit 3
  fi
}

if [[ "${1-}" == "--post-load" ]]; then
  postLoad
  exit 0
fi

if [[ "${1-}" == "-h" || "${1-}" == "--help" ]]; then
  print_usage
  exit 0
fi

[[ -f "$SHARED_LIB" ]] || postLoad
# shellcheck source=lib/docker-wrapper.sh
source "$SHARED_LIB"

SHOW_MANIFEST=0
NODE_VERSION=""
while [[ $# -gt 0 ]]; do
  if docker_wrapper_option "$@"; then
    shift "$DOCKER_OPT_SHIFT"
    continue
  fi
  case "$1" in
    --manifest)
      SHOW_MANIFEST=1
      shift
      ;;
    --)
      shift
      ;;
    -*)
      echo "Error: Invalid option '$1'." >&2
      echo >&2
      print_usage >&2
      exit 1
      ;;
    *)
      NODE_VERSION="$1"
      shift
      ;;
  esac
done

if [[ $SHOW_MANIFEST -eq 1 ]]; then
  if [[ -z "$NODE_VERSION" ]]; then
    docker_manifest_all node node npm npx yarn
  else
    print_manifest "$NODE_VERSION"
  fi
  exit 0
fi

if [[ -z "$NODE_VERSION" ]]; then
  echo "Error: <node_version> is required." >&2
  echo >&2
  print_usage >&2
  exit 2
fi

# Save packages.conf, volumes.conf, env.conf and the post-install script
docker_wrapper_configure "${SHELLSCRIPT_HOME}/node" "${SHELLSCRIPT_HOME}/node/${NODE_VERSION}"

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

# Extra packages and the post-install script of this Node version, on top of it
NODE_PACKAGES=()
while IFS= read -r pkg; do
  [[ -n "$pkg" ]] && NODE_PACKAGES+=("$pkg")
done < <(docker_conf_list "$DOCKER_PACKAGES_CONF")
docker_image_packages "$NODE_IMAGE" ${NODE_PACKAGES[@]+"${NODE_PACKAGES[@]}"}
docker_image_postinstall "$NODE_IMAGE" -e "NODE_VERSION=${NODE_VERSION}"

BASE_FOLDER="${SHELLSCRIPT_HOME}"
DEST_FOLDER="$BASE_FOLDER/bin"
SHELLRC_FOLDER="$BASE_FOLDER/shellrc"
NODE_NPM="$BASE_FOLDER/node/${NODE_VERSION}"
NODE_BIN="$NODE_NPM/.npm-global/bin"
NODE_NPMRC="$HOME/.npmrc"
CONTAINER_HOME="${HOME}"
REGULAR_USER="-u \"\$(id -u):\$(id -g)\""
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
# The yarn wrapper mounts its cache here, inside the folder mounted as the home.
# Docker would create a missing mount point as root, and "remove --purge" could
# then not delete it.
mkdir -p "$NODE_NPM/.cache/yarn"
mkdir -p "$NODE_BIN"
touch "$NODE_NPMRC"
cp "$NODE_NPMRC" "$NODE_NPM/.npmrc"

# Runtime code of the wrappers: mount the extra volumes under /c, like the current
# directory, so relative paths between them still resolve, and forward the
# environment without what only makes sense on the host.
VOLUME_ARGS="$(docker_volume_args "$DOCKER_VOLUMES_CONF" "/c/")"
ENV_FILTER="$(docker_env_filter "$DOCKER_ENV_CONF")"

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
    # printf, not echo: echo would swallow an argument such as -e or -n as its own option
    arg=\$(printf '%s\\n' "\$arg" | sed "s|${NODE_BIN}|${CONTAINER_HOME}/.npm-global/bin|g")

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

${VOLUME_ARGS}

${ENV_FILTER}

DOCKER_ARGS=(
  \${TTY_ARG} --rm
  "\${ENV_ARGS[@]}"
  "\${EXTRA_VOLUME_ARGS[@]}"
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

${VOLUME_ARGS}

${ENV_FILTER}

DOCKER_ARGS=(
  \${TTY_ARG} --rm
  "\${ENV_ARGS[@]}"
  "\${EXTRA_VOLUME_ARGS[@]}"
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

${VOLUME_ARGS}

${ENV_FILTER}

DOCKER_ARGS=(
  \${TTY_ARG} --rm
  "\${ENV_ARGS[@]}"
  "\${EXTRA_VOLUME_ARGS[@]}"
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

${VOLUME_ARGS}

${ENV_FILTER}

DOCKER_ARGS=(
  \${TTY_ARG} --rm
  "\${ENV_ARGS[@]}"
  "\${EXTRA_VOLUME_ARGS[@]}"
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

exec docker run "\${DOCKER_ARGS[@]}" "$NODE_IMAGE" "\$YARN_PATH" "\$@"
WRAP
chmod +x "${DEST_FOLDER}/yarn${NODE_VERSION}"

ln -sf "${DEST_FOLDER}/node${NODE_VERSION}" "${DEST_FOLDER}/node"
ln -sf "${DEST_FOLDER}/npm${NODE_VERSION}" "${DEST_FOLDER}/npm"
ln -sf "${DEST_FOLDER}/npx${NODE_VERSION}" "${DEST_FOLDER}/npx"
ln -sf "${DEST_FOLDER}/yarn${NODE_VERSION}" "${DEST_FOLDER}/yarn"
