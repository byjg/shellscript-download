#!/usr/bin/env bash
# php-docker.sh: Create Docker-backed php and composer launchers
# - This script is idempotent and can be re-run to switch versions.
# - Packages are installed via Alpine's apk package manager in the Docker image.

set -euo pipefail


print_usage() {
  cat <<'USAGE'
php-docker.sh <php_version> [--add package1,package2,...] [--volume /path1,/path2,...] [--env NAME1,NAME2,...] [--postinstall /path/to/script] [--no-postinstall] [--skip packages,postinstall] [--manifest]

Installs Docker-backed wrappers for php and composer under $HOME/.shellscript/bin
using the byjg/php:<version>-cli image.

Options:
  --add <packages>      Install additional Alpine packages (comma-separated list).
                        Saved to $HOME/.shellscript/php/packages.conf and 
                        re-applied on every install/update, with phpNN- prefixes 
                        rewritten to the target version (php83-gd becomes php86-gd
                        on 8.6).
                        Example: --add php83-gd,php83-intl,git,bash
  --volume <paths>      Extra host directories to mount inside the container as
                        <path>:<path> (comma-separated list). Saved to
                        $HOME/.shellscript/php/volumes.conf so they persist across
                        installs/updates. The wrappers read this file at runtime,
                        so you can also edit it directly without reinstalling.
                        Example: --volume /home/user/projects
  --env <names>         The wrappers forward the host environment to the container,
                        except the variables that describe the host itself (desktop
                        session, systemd, terminal and IDE, host toolchains such as
                        JAVA_HOME or NVM_*, SSH_* and agents). Use --env to forward
                        some of those anyway (comma-separated names or patterns).
                        Saved to $HOME/.shellscript/php/env.conf, which the wrappers
                        read at runtime, so you can also edit it directly.
                        Example: --env JAVA_HOME,XDG_RUNTIME_DIR
  --postinstall <script>
                        Script to run as root inside the image after the packages
                        are installed, for what apk cannot do (PECL builds, vendor
                        clients). Copied to $HOME/.shellscript/php/<version>/postinstall.sh
                        so it belongs to that PHP version only and runs again on
                        every install/update of it. Delete that file to remove it.
                        The script receives PHP_VERSION (8.5) and PHP_VARIANT (php85).
                        A line "# ENV NAME=value" in the script sets that environment
                        variable in the image.
                        Example: --postinstall ./install-oracle.sh
  --no-postinstall      Delete the saved post-install script of this PHP version.
  --skip <steps>        Leave out steps for this run only, without changing what
                        is saved (comma-separated list): "packages" (the Alpine
                        packages) and/or "postinstall" (the post-install script).
                        Example: --skip postinstall
  --manifest            Print installation manifest and exit. Without a version it
                        covers every installed version and the saved configuration,
                        which is what "load.sh remove -- php-docker" uses.

Examples:
  load.sh php-docker -- 8.3
  load.sh php-docker -- 7.4
  load.sh php-docker -- 8.3 --add php83-gd,php83-intl,git
  load.sh php-docker -- 8.3 --volume /home/user/projects
  load.sh php-docker -- 8.5 --postinstall ./install-oracle.sh
  load.sh php-docker -- 8.5 --volume /home/user/projects --skip postinstall
  load.sh php-docker -- 8.5 --no-postinstall
  load.sh php-docker -- 8.3 --manifest

USAGE
}

print_manifest() {
  local version="${1:-VERSION}"
  cat <<MANIFEST
BIN_FILES=php${version} composer${version} php composer
FOLDERS=\$HOME/.shellscript/php/${version}
SHELLRC_FILE=\$HOME/.shellscript/shellrc/php-init.sh
MANIFEST
}

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

# Help flag handling
if [[ "${1-}" == "-h" || "${1-}" == "--help" ]]; then
  print_usage
  exit 0
fi

# Validate argument
if [[ $# -lt 1 ]]; then
  echo "Error: <php_version> is required." >&2
  echo >&2
  print_usage >&2
  exit 2
fi

[[ -f "$SHARED_LIB" ]] || postLoad
# shellcheck source=lib/docker-wrapper.sh
source "$SHARED_LIB"

SHOW_MANIFEST=0
PHP_VERSION=""
while [[ $# -gt 0 ]]; do
  if docker_wrapper_option "$@"; then
    shift "$DOCKER_OPT_SHIFT"
    continue
  fi
  case "$1" in
    "5.6"|"7.0"|"7.1"|"7.2"|"7.3"|"7.4"|"8.0"|"8.1"|"8.2"|"8.3"|"8.4"|"8.5"|"8.6")
      PHP_VERSION="$1"
      shift
      ;;
    "--manifest")
      SHOW_MANIFEST=1
      shift
      ;;
    *)
      echo "Error: Invalid argument '$1'. Supported versions are: 5.6, 7.0, 7.1, 7.2, 7.3, 7.4, 8.0, 8.1, 8.2, 8.3, 8.4, 8.5, 8.6" >&2
      exit 1
      ;;
  esac
done

# If manifest requested, print and exit
if [[ $SHOW_MANIFEST -eq 1 ]]; then
  if [[ -z "$PHP_VERSION" ]]; then
    docker_manifest_all php php composer
  else
    print_manifest "$PHP_VERSION"
  fi
  exit 0
fi

# Validate PHP version was provided for normal installation
if [[ -z "$PHP_VERSION" ]]; then
  echo "Error: <php_version> is required." >&2
  echo >&2
  print_usage >&2
  exit 2
fi

# Pre-flight: docker availability
if ! command -v docker >/dev/null 2>&1; then
  echo "Error: Docker is required but was not found on PATH." >&2
  exit 3
fi

echo "[Debug] Create Folders"
BASE_FOLDER="${SHELLSCRIPT_HOME}"
SHELLRC_FOLDER="$BASE_FOLDER/shellrc"
DEST_FOLDER="$BASE_FOLDER/bin"
PHP_HOME="$BASE_FOLDER/php/${PHP_VERSION}"
PHP_INI="${PHP_HOME}/php.ini"
# Composer uses the host's own directories, the ones a native Composer would use
COMPOSER_HOME_DIR="${COMPOSER_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/composer}"
COMPOSER_CACHE="${COMPOSER_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/composer}"
PHP_BIN="${COMPOSER_HOME_DIR}/vendor/bin"
mkdir -p "${DEST_FOLDER}"
mkdir -p "${PHP_HOME}"
touch "$PHP_INI"

echo "[Debug] Update Path"
cat >"${SHELLRC_FOLDER}/php-init.sh" <<WRAP
export PATH="\$PATH:$PHP_BIN"
WRAP

# Save packages.conf, volumes.conf, env.conf and the post-install script
docker_wrapper_configure "$BASE_FOLDER/php" "$PHP_HOME"

# Runtime code of the php and composer wrappers: mount the extra volumes at their
# own path, and forward the environment without what only makes sense on the host.
VOLUME_ARGS="$(docker_volume_args "$DOCKER_VOLUMES_CONF")"
ENV_FILTER="$(docker_env_filter "$DOCKER_ENV_CONF")"

# Build the package list from the saved config. packages.conf is shared by every
# PHP version, so phpNN- prefixes are rewritten to the target version (a saved
# php83-gd installs as php86-gd on 8.6) and de-duplicated (php83-gd and php85-gd
# collapse into one). An entry may not exist for the target version (php85-sodium
# has no php86-sodium counterpart); it is reported and the others still install.
INSTALL_PACKAGES=()
while IFS= read -r pkg; do
  [[ -n "$pkg" ]] || continue
  pkg="$(echo "$pkg" | sed -E "s/^php[0-9]+-/php${PHP_VERSION//./}-/")"
  if [[ ! " ${INSTALL_PACKAGES[*]-} " == *" $pkg "* ]]; then
    INSTALL_PACKAGES+=("$pkg")
  fi
done < <(docker_conf_list "$DOCKER_PACKAGES_CONF")

# Pull base image and build a customized one with updated composer
PHP_BASE_IMAGE="byjg/php:${PHP_VERSION}-cli"
if ! docker pull "$PHP_BASE_IMAGE"; then
  echo "Error: Failed to pull Docker image ${PHP_BASE_IMAGE}" >&2
  exit 4
fi

# Use the custom image for the wrappers
PHP_IMAGE="${PHP_BASE_IMAGE}-load"
docker image rm "$PHP_IMAGE" 2>/dev/null || true
docker tag "$PHP_BASE_IMAGE" "$PHP_IMAGE"

docker_image_packages "$PHP_IMAGE" ${INSTALL_PACKAGES[@]+"${INSTALL_PACKAGES[@]}"}
docker_image_postinstall "$PHP_IMAGE" -e "PHP_VERSION=${PHP_VERSION}"

# Create php wrapper
cat >"${DEST_FOLDER}/php${PHP_VERSION}" <<WRAP
#!/usr/bin/env bash
set -euo pipefail
# Wrapper for php via Docker (byjg/php:<version>-cli)
# Pass-through all args to php inside the container, mounting current dir.
ARGS=()
for arg in "\$@"; do
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

TTY_ARG=""
if [ -t 0 ]; then
    TTY_ARG="-i"
fi
if [ -t 1 ]; then
    TTY_ARG="\${TTY_ARG} -t"
fi

${ENV_FILTER}

${VOLUME_ARGS}

# Docker creates a folder it mounts when it is missing, and as root: on an account
# that has no ~/.cache yet, nothing could write to it afterwards
mkdir -p "${HOME}/.cache"

docker run \${TTY_ARG} --rm \
  -v "\${PWD}":"\${PWD}" \
  -v "${HOME}/.cache:${HOME}/.cache" \
  -v "/tmp:/tmp" \
  -v "$PHP_INI":"/etc/php${PHP_VERSION//./}/conf.d/99-php.ini" \
  -w "\${PWD}" \
  -u "\$(id -u):\$(id -g)" \
  -v "/etc/passwd:/etc/passwd:ro" \
  -v "/etc/group:/etc/group:ro" \
  "\${ENV_ARGS[@]}" \
  "\${EXTRA_VOLUME_ARGS[@]}" \
  --network host \
  $PHP_IMAGE \
  php "\${ARGS[@]}"
WRAP


# Create composer wrapper
cat >"${DEST_FOLDER}/composer${PHP_VERSION}" <<WRAP
#!/usr/bin/env bash
set -euo pipefail
# Wrapper for composer via Docker (byjg/php:<version>-cli)
# Mount current dir and persist Composer home between runs. Forward SSH agent if available.

# Prepare optional SSH agent forwarding
DOCKER_SSH_ARGS=()
if [[ -n "\${SSH_AUTH_SOCK:-}" && -S "\${SSH_AUTH_SOCK}" ]]; then
  DOCKER_SSH_ARGS=(
    -v "$HOME/.ssh:$HOME/.ssh:ro"
    -v "/etc/passwd:/etc/passwd:ro"
    -v "/etc/group:/etc/group:ro"
    -v "\${SSH_AUTH_SOCK}:\${SSH_AUTH_SOCK}"
    -e SSH_AUTH_SOCK=\${SSH_AUTH_SOCK}
  )
fi

TTY_ARG=""
if [ -t 0 ]; then
    TTY_ARG="-i"
fi
if [ -t 1 ]; then
    TTY_ARG="\${TTY_ARG} -t"
fi

${ENV_FILTER}

${VOLUME_ARGS}

# Mount the project at its real host path (not /workdir) so that relative
# path repositories and symlinks resolve identically on host and container.
# Composer's home and cache are the host's, mounted at their own path and named
# explicitly: without that Composer guesses them from XDG_* variables, which the
# environment filter leaves out. They are created here, and the container runs as
# the calling user, so Docker never creates them (or anything in them) as root.
mkdir -p "${COMPOSER_HOME_DIR}" "${COMPOSER_CACHE}"
docker run \${TTY_ARG} --rm \
  -v "\${PWD}":"\${PWD}" \
  -v "${COMPOSER_HOME_DIR}:${COMPOSER_HOME_DIR}" \
  -v "${COMPOSER_CACHE}:${COMPOSER_CACHE}" \
  -v "$PHP_INI":"/etc/php${PHP_VERSION//./}/conf.d/99-php.ini" \
  -w "\${PWD}" \
  -u "\$(id -u):\$(id -g)" \
  "\${ENV_ARGS[@]}" \
  -e "HOME=${HOME}" \
  -e "COMPOSER_HOME=${COMPOSER_HOME_DIR}" \
  -e "COMPOSER_CACHE_DIR=${COMPOSER_CACHE}" \
  "\${DOCKER_SSH_ARGS[@]}" \
  "\${EXTRA_VOLUME_ARGS[@]}" \
  --network host \
  $PHP_IMAGE \
  composer "\$@"
WRAP

chmod a+x "${DEST_FOLDER}/php${PHP_VERSION}" "${DEST_FOLDER}/composer${PHP_VERSION}"
ln -sf "${DEST_FOLDER}/php${PHP_VERSION}" "${DEST_FOLDER}/php"
ln -sf "${DEST_FOLDER}/composer${PHP_VERSION}" "${DEST_FOLDER}/composer"
