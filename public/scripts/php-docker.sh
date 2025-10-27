#!/usr/bin/env bash
# php-docker.sh: Create Docker-backed php and composer launchers
# Usage (via loader):
#   load.sh php-docker -- <php_version>
#
# Examples:
#   load.sh php-docker -- 8.3
#   load.sh php-docker -- 7.4
#
# Description:
# - Generates two wrapper scripts in "$HOME/.shellscript/bin":
#     - php<ver>      → runs PHP inside the byjg/php:<version>-cli Docker image
#     - composer<ver> → runs Composer inside the same image, persisting your
#                       ~/.composer dir
# - Also updates convenience symlinks: php, composer → their <ver> counterparts.
# - Intended for environments where PHP/Composer are not installed natively.
#
# Notes:
# - Supported versions: 5.6, 7.0–7.4, 8.0–8.5
# - Requires Docker installed and available on PATH. Install with `load.sh docker`
# - This script is idempotent and can be re-run to switch versions.

set -euo pipefail

echo ">_ php-docker.sh"
echo

print_usage() {
  cat <<'USAGE'
php-docker.sh <php_version>

Installs Docker-backed wrappers for php and composer under $HOME/.shellscript/bin
using the byjg/php:<version>-cli image.

Examples:
  load.sh php-docker -- 8.3
  load.sh php-docker -- 7.4

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

case "$1" in
  "5.6"|"7.0"|"7.1"|"7.2"|"7.3"|"7.4"|"8.0"|"8.1"|"8.2"|"8.3"|"8.4"|"8.5")
    PHP_VERSION="$1"
    ;;
  *)
    echo "Error: Invalid PHP version. Supported versions are: 5.6, 7.0, 7.1, 7.2, 7.3, 7.4, 8.0, 8.1, 8.2, 8.3, 8.4, 8.5" >&2
    exit 1
    ;;
esac

# Pre-flight: docker availability
if ! command -v docker >/dev/null 2>&1; then
  echo "Error: Docker is required but was not found on PATH." >&2
  exit 3
fi

DEST_FOLDER="$HOME/.shellscript/bin"
mkdir -p "${DEST_FOLDER}"

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

docker run \${TTY_ARG} --rm \
  -v "\${PWD}":/workdir \
  -w /workdir \
  -u $(id -u):$(id -g) \
  -e XDEBUG_CLIENT_PORT=9003 \
  --network host \
  byjg/php:${PHP_VERSION}-cli \
  php "\${ARGS[@]}"
WRAP

COMPOSER_CACHE="${HOME}/.cache/composer.${PHP_VERSION}.sh"
mkdir -p ${COMPOSER_CACHE}
chown -R $(id -u):$(id -g) ${COMPOSER_CACHE}

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

docker run \${TTY_ARG} --rm \
  -v "\${PWD}":/workdir \
  -v "${COMPOSER_CACHE}:/tmp/.composer" \
  -e COMPOSER_HOME=/tmp/.composer \
  -w /workdir \
  -u $(id -u):$(id -g) \
  "\${DOCKER_SSH_ARGS[@]}" \
  byjg/php:${PHP_VERSION}-cli \
  composer "\$@"
WRAP

# Pull image and make wrappers executable
# shellcheck disable=SC2154  # PHP_VERSION is set via case above
if ! docker pull "byjg/php:${PHP_VERSION}-cli"; then
  echo "Error: Failed to pull Docker image byjg/php:${PHP_VERSION}-cli" >&2
  exit 4
fi
chmod a+x "${DEST_FOLDER}/php${PHP_VERSION}" "${DEST_FOLDER}/composer${PHP_VERSION}"
ln -sf "${DEST_FOLDER}/php${PHP_VERSION}" "${DEST_FOLDER}/php"
ln -sf "${DEST_FOLDER}/composer${PHP_VERSION}" "${DEST_FOLDER}/composer"