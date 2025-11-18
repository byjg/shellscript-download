#!/usr/bin/env bash
# php-docker.sh: Create Docker-backed php and composer launchers
# Usage (via loader):
#   load.sh php-docker -- <php_version> [--add package1,package2,...]
#
# Examples:
#   load.sh php-docker -- 8.3
#   load.sh php-docker -- 7.4
#   load.sh php-docker -- 8.3 --add php83-gd,php83-intl,php83-pdo_mysql
#
# Description:
# - Generates two wrapper scripts in "$HOME/.shellscript/bin":
#     - php<ver>      → runs PHP inside the byjg/php:<version>-cli Docker image
#     - composer<ver> → runs Composer inside the same image, persisting your
#                       ~/.composer dir
# - Also updates convenience symlinks: php, composer → their <ver> counterparts.
# - Intended for environments where PHP/Composer are not installed natively.
#
# Options:
# - --add <packages>    Install additional Alpine packages (comma-separated list)
#                       Example: --add php83-gd,php83-intl,git,bash
#
# Notes:
# - Supported versions: 5.6, 7.0–7.4, 8.0–8.5
# - Requires Docker installed and available on PATH. Install with `load.sh docker`
# - This script is idempotent and can be re-run to switch versions.
# - Packages are installed via Alpine's apk package manager in the Docker image.

set -euo pipefail

echo ">_ php-docker.sh"
echo

print_usage() {
  cat <<'USAGE'
php-docker.sh <php_version> [--add package1,package2,...]

Installs Docker-backed wrappers for php and composer under $HOME/.shellscript/bin
using the byjg/php:<version>-cli image.

Options:
  --add <packages>      Install additional Alpine packages (comma-separated list)
                        Example: --add php83-gd,php83-intl,git,bash

Examples:
  load.sh php-docker -- 8.3
  load.sh php-docker -- 7.4
  load.sh php-docker -- 8.3 --add php83-gd,php83-intl,git

USAGE
}

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

PACKAGES=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    "5.6"|"7.0"|"7.1"|"7.2"|"7.3"|"7.4"|"8.0"|"8.1"|"8.2"|"8.3"|"8.4"|"8.5")
      PHP_VERSION="$1"
      shift
      ;;
    "--add")
      shift
      if [[ $# -eq 0 ]]; then
        echo "Error: --add requires a package list" >&2
        exit 1
      fi
      PACKAGES="$1"
      shift
      ;;
    *)
      echo "Error: Invalid argument '$1'. Supported versions are: 5.6, 7.0, 7.1, 7.2, 7.3, 7.4, 8.0, 8.1, 8.2, 8.3, 8.4, 8.5" >&2
      exit 1
      ;;
  esac
done

# Pre-flight: docker availability
if ! command -v docker >/dev/null 2>&1; then
  echo "Error: Docker is required but was not found on PATH." >&2
  exit 3
fi

echo "[Debug] Create Folders"
BASE_FOLDER="$HOME/.shellscript"
SHELLRC_FOLDER="$BASE_FOLDER/shellrc"
DEST_FOLDER="$BASE_FOLDER/bin"
PHP_HOME="$BASE_FOLDER/php/${PHP_VERSION}"
PHP_BIN="${PHP_HOME}/vendor/bin"
PHP_INI="${PHP_HOME}/php.ini"
COMPOSER_CACHE="${PHP_HOME}/cache"
mkdir -p "${DEST_FOLDER}"
mkdir -p "${PHP_HOME}"
mkdir -p "${PHP_BIN}"
mkdir -p "${COMPOSER_CACHE}"
touch "$PHP_INI"

echo "[Debug] Update Path"
cat >"${SHELLRC_FOLDER}/php-init.sh" <<WRAP
export PATH="\$PATH:$PHP_BIN"
WRAP

# Pull base image and build a customized one with updated composer
# shellcheck disable=SC2154  # PHP_VERSION is set via case above
PHP_BASE_IMAGE="byjg/php:${PHP_VERSION}-cli"
if ! docker pull "$PHP_BASE_IMAGE"; then
  echo "Error: Failed to pull Docker image ${PHP_BASE_IMAGE}" >&2
  exit 4
fi

# Use the custom image for the wrappers
PHP_IMAGE="${PHP_BASE_IMAGE}-load"
docker image rm "$PHP_IMAGE" 2>/dev/null || true
docker tag "$PHP_BASE_IMAGE" "$PHP_IMAGE"

if [[ -n "$PACKAGES" ]]; then
  echo "Installing Alpine packages: $PACKAGES"
  docker rm temp 2>/dev/null || true
  IFS=',' read -ra PKG_ARRAY <<< "$PACKAGES"
  docker run -it --user root --name temp "$PHP_IMAGE" apk add --no-cache "${PKG_ARRAY[@]}"
  docker commit temp "$PHP_IMAGE"
  docker rm temp
fi



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

# Prepare environment variables (exclude host-specific vars)
ENV_ARGS=()
while IFS='=' read -r -d '' name value; do
  # Skip environment variables that should not be passed to the container
  case "\$name" in
    PATH|HOME|USER|LOGNAME|HOSTNAME|PWD|OLDPWD|SHELL|TERM|SHLVL|_)
      continue
      ;;
  esac
  ENV_ARGS+=(-e "\${name}=\${value}")
done < <(env -0)

docker run \${TTY_ARG} --rm \
  -v "\${PWD}":"\${PWD}" \
  -v "${HOME}/.cache:${HOME}/.cache" \
  -v "/tmp:/tmp" \
  -v "$PHP_INI":"/etc/php${PHP_VERSION//./}/conf.d/99-php.ini" \
  -w "\${PWD}" \
  -u $(id -u):$(id -g) \
  -v "/etc/passwd:/etc/passwd:ro" \
  -v "/etc/group:/etc/group:ro" \
  "\${ENV_ARGS[@]}" \
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

# Prepare environment variables (exclude host-specific vars)
ENV_ARGS=()
while IFS='=' read -r -d '' name value; do
  # Skip environment variables that should not be passed to the container
  case "\$name" in
    PATH|HOME|USER|LOGNAME|HOSTNAME|PWD|OLDPWD|SHELL|TERM|SHLVL|_)
      continue
      ;;
  esac
  ENV_ARGS+=(-e "\${name}=\${value}")
done < <(env -0)

docker run \${TTY_ARG} --rm \
  -v "\${PWD}":/workdir \
  -v "${PHP_HOME}:/tmp/.composer" \
  -v "${COMPOSER_CACHE}:${HOME}/.cache/composer" \
  -v "$PHP_INI":"/etc/php${PHP_VERSION//./}/conf.d/99-php.ini" \
  -w /workdir \
  -e "HOME=${HOME}" \
  -u $(id -u):$(id -g) \
  "\${ENV_ARGS[@]}" \
  "\${DOCKER_SSH_ARGS[@]}" \
  --network host \
  $PHP_IMAGE \
  composer "\$@"
WRAP

chmod a+x "${DEST_FOLDER}/php${PHP_VERSION}" "${DEST_FOLDER}/composer${PHP_VERSION}"
ln -sf "${DEST_FOLDER}/php${PHP_VERSION}" "${DEST_FOLDER}/php"
ln -sf "${DEST_FOLDER}/composer${PHP_VERSION}" "${DEST_FOLDER}/composer"