#!/usr/bin/env bash
# php-docker.sh: Create Docker-backed php and composer launchers
# - This script is idempotent and can be re-run to switch versions.
# - Packages are installed via Alpine's apk package manager in the Docker image.

set -euo pipefail


print_usage() {
  cat <<'USAGE'
php-docker.sh <php_version> [--add package1,package2,...] [--volume /path1,/path2,...] [--manifest]

Installs Docker-backed wrappers for php and composer under $HOME/.shellscript/bin
using the byjg/php:<version>-cli image.

Options:
  --add <packages>      Install additional Alpine packages (comma-separated list).
                        Saved to $HOME/.shellscript/php/packages.conf and re-applied
                        on every install/update, with phpNN- prefixes rewritten to
                        the target version (php83-gd becomes php85-gd on 8.5).
                        Example: --add php83-gd,php83-intl,git,bash
  --volume <paths>      Extra host directories to mount inside the container as
                        <path>:<path> (comma-separated list). Saved to
                        $HOME/.shellscript/php/volumes.conf so they persist across
                        installs/updates. The wrappers read this file at runtime,
                        so you can also edit it directly without reinstalling.
                        Example: --volume /home/user/projects
  --manifest            Print installation manifest and exit

Examples:
  load.sh php-docker -- 8.3
  load.sh php-docker -- 7.4
  load.sh php-docker -- 8.3 --add php83-gd,php83-intl,git
  load.sh php-docker -- 8.3 --volume /home/user/projects
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
VOLUMES=""
SHOW_MANIFEST=0
PHP_VERSION=""
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
    "--volume")
      shift
      if [[ $# -eq 0 ]]; then
        echo "Error: --volume requires a path list" >&2
        exit 1
      fi
      VOLUMES="${VOLUMES:+$VOLUMES,}$1"
      shift
      ;;
    "--manifest")
      SHOW_MANIFEST=1
      shift
      ;;
    *)
      echo "Error: Invalid argument '$1'. Supported versions are: 5.6, 7.0, 7.1, 7.2, 7.3, 7.4, 8.0, 8.1, 8.2, 8.3, 8.4, 8.5" >&2
      exit 1
      ;;
  esac
done

# If manifest requested, print and exit
if [[ $SHOW_MANIFEST -eq 1 ]]; then
  if [[ -z "$PHP_VERSION" ]]; then
    echo "Error: <php_version> is required for manifest" >&2
    exit 2
  fi
  print_manifest "$PHP_VERSION"
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

# Persist extra volumes so they survive future installs/updates.
# The wrappers read this file at runtime (one absolute path per line).
VOLUMES_CONF="$BASE_FOLDER/php/volumes.conf"
if [[ -n "$VOLUMES" ]]; then
  touch "$VOLUMES_CONF"
  IFS=',' read -ra VOL_ARRAY <<< "$VOLUMES"
  for vol_path in "${VOL_ARRAY[@]}"; do
    vol_path="${vol_path%/}"
    if [[ ! -d "$vol_path" ]]; then
      echo "Warning: volume path does not exist: $vol_path" >&2
    fi
    if ! grep -qxF "$vol_path" "$VOLUMES_CONF"; then
      echo "$vol_path" >> "$VOLUMES_CONF"
      echo "Added volume to ${VOLUMES_CONF}: $vol_path"
    fi
  done
fi

# Persist extra packages so they survive future installs/updates.
# phpNN- prefixes are rewritten to the target version at install time
# (e.g. a saved php83-gd installs as php85-gd when installing 8.5).
PACKAGES_CONF="$BASE_FOLDER/php/packages.conf"
if [[ -n "$PACKAGES" ]]; then
  touch "$PACKAGES_CONF"
  IFS=',' read -ra PKG_ARRAY <<< "$PACKAGES"
  for pkg in "${PKG_ARRAY[@]}"; do
    if ! grep -qxF "$pkg" "$PACKAGES_CONF"; then
      echo "$pkg" >> "$PACKAGES_CONF"
      echo "Added package to ${PACKAGES_CONF}: $pkg"
    fi
  done
fi

# Build the effective package list from the saved config, rewriting version
# prefixes and de-duplicating (php83-gd and php85-gd collapse into one).
INSTALL_PACKAGES=()
if [[ -f "$PACKAGES_CONF" ]]; then
  while IFS= read -r pkg; do
    [[ -z "$pkg" || "$pkg" == \#* ]] && continue
    pkg="$(echo "$pkg" | sed -E "s/^php[0-9]+-/php${PHP_VERSION//./}-/")"
    if [[ ! " ${INSTALL_PACKAGES[*]-} " == *" $pkg "* ]]; then
      INSTALL_PACKAGES+=("$pkg")
    fi
  done < "$PACKAGES_CONF"
fi

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

if [[ ${#INSTALL_PACKAGES[@]} -gt 0 ]]; then
  echo "Installing Alpine packages: ${INSTALL_PACKAGES[*]}"
  docker rm temp 2>/dev/null || true
  docker run -it --user root --name temp "$PHP_IMAGE" apk add --no-cache "${INSTALL_PACKAGES[@]}"
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

# Extra volumes from volumes.conf (one absolute path per line, mounted as path:path)
EXTRA_VOLUME_ARGS=()
VOLUMES_CONF="$BASE_FOLDER/php/volumes.conf"
if [[ -f "\$VOLUMES_CONF" ]]; then
  while IFS= read -r vol_path; do
    [[ -z "\$vol_path" || "\$vol_path" == \\#* ]] && continue
    if [[ -d "\$vol_path" ]]; then
      EXTRA_VOLUME_ARGS+=(-v "\$vol_path":"\$vol_path")
    fi
  done < "\$VOLUMES_CONF"
fi

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

# Extra volumes from volumes.conf (one absolute path per line, mounted as path:path)
EXTRA_VOLUME_ARGS=()
VOLUMES_CONF="$BASE_FOLDER/php/volumes.conf"
if [[ -f "\$VOLUMES_CONF" ]]; then
  while IFS= read -r vol_path; do
    [[ -z "\$vol_path" || "\$vol_path" == \\#* ]] && continue
    if [[ -d "\$vol_path" ]]; then
      EXTRA_VOLUME_ARGS+=(-v "\$vol_path":"\$vol_path")
    fi
  done < "\$VOLUMES_CONF"
fi

# Mount the project at its real host path (not /workdir) so that relative
# path repositories and symlinks resolve identically on host and container.
docker run \${TTY_ARG} --rm \
  -v "\${PWD}":"\${PWD}" \
  -v "${PHP_HOME}:/tmp/.composer" \
  -v "${COMPOSER_CACHE}:${HOME}/.cache/composer" \
  -v "$PHP_INI":"/etc/php${PHP_VERSION//./}/conf.d/99-php.ini" \
  -w "\${PWD}" \
  -e "HOME=${HOME}" \
  -u $(id -u):$(id -g) \
  "\${ENV_ARGS[@]}" \
  "\${DOCKER_SSH_ARGS[@]}" \
  "\${EXTRA_VOLUME_ARGS[@]}" \
  --network host \
  $PHP_IMAGE \
  composer "\$@"
WRAP

chmod a+x "${DEST_FOLDER}/php${PHP_VERSION}" "${DEST_FOLDER}/composer${PHP_VERSION}"
ln -sf "${DEST_FOLDER}/php${PHP_VERSION}" "${DEST_FOLDER}/php"
ln -sf "${DEST_FOLDER}/composer${PHP_VERSION}" "${DEST_FOLDER}/composer"