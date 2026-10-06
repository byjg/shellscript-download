#!/usr/bin/env bash
# php-docker.sh: Create Docker-backed php and composer launchers
# - This script is idempotent and can be re-run to switch versions.
# - Packages are installed via Alpine's apk package manager in the Docker image.

set -euo pipefail


print_usage() {
  cat <<'USAGE'
php-docker.sh <php_version> [--add package1,package2,...] [--volume /path1,/path2,...] [--postinstall /path/to/script] [--no-postinstall] [--skip packages,postinstall] [--manifest]

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

# Without a version: everything php-docker installed, for "load.sh remove".
# The versioned wrappers are read from the bin folder, and the whole php folder
# is listed so packages.conf, volumes.conf and the post-install scripts go with
# --purge.
print_manifest_all() {
  local base="${SHELLSCRIPT_HOME:-$HOME/.shellscript}"
  local bin_files="php composer"
  local file name
  for file in "$base"/bin/php* "$base"/bin/composer*; do
    name="$(basename "$file")"
    [[ "$name" =~ ^(php|composer)[0-9]+\.[0-9]+$ ]] || continue
    bin_files+=" $name"
  done
  cat <<MANIFEST
BIN_FILES=${bin_files}
FOLDERS=${base}/php
SHELLRC_FILE=${base}/shellrc/php-init.sh
MANIFEST
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
POSTINSTALL=""
NO_POSTINSTALL=0
SKIP_PACKAGES=0
SKIP_POSTINSTALL=0
SHOW_MANIFEST=0
PHP_VERSION=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    "5.6"|"7.0"|"7.1"|"7.2"|"7.3"|"7.4"|"8.0"|"8.1"|"8.2"|"8.3"|"8.4"|"8.5"|"8.6")
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
    "--postinstall")
      shift
      if [[ $# -eq 0 ]]; then
        echo "Error: --postinstall requires a script path" >&2
        exit 1
      fi
      POSTINSTALL="$1"
      shift
      ;;
    "--no-postinstall")
      NO_POSTINSTALL=1
      shift
      ;;
    "--skip")
      shift
      if [[ $# -eq 0 ]]; then
        echo "Error: --skip requires a step list (packages,postinstall)" >&2
        exit 1
      fi
      IFS=',' read -ra SKIP_ARRAY <<< "$1"
      for step in "${SKIP_ARRAY[@]}"; do
        case "$step" in
          packages) SKIP_PACKAGES=1 ;;
          postinstall) SKIP_POSTINSTALL=1 ;;
          *)
            echo "Error: Invalid --skip step '$step'. Supported steps are: packages, postinstall" >&2
            exit 1
            ;;
        esac
      done
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
    print_manifest_all
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

if [[ -n "$POSTINSTALL" && $NO_POSTINSTALL -eq 1 ]]; then
  echo "Error: --postinstall and --no-postinstall cannot be used together" >&2
  exit 1
fi

if [[ -n "$POSTINSTALL" && ! -f "$POSTINSTALL" ]]; then
  echo "Error: post-install script not found: $POSTINSTALL" >&2
  exit 1
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
# (e.g. a saved php83-gd installs as php86-gd when installing 8.6).
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

# Persist the post-install script next to the other files of this PHP version,
# so it is tied to it and runs again on every install/update.
POSTINSTALL_SCRIPT="${PHP_HOME}/postinstall.sh"
if [[ -n "$POSTINSTALL" ]]; then
  cp "$POSTINSTALL" "$POSTINSTALL_SCRIPT"
  echo "Saved post-install script to ${POSTINSTALL_SCRIPT}"
fi
if [[ $NO_POSTINSTALL -eq 1 && -f "$POSTINSTALL_SCRIPT" ]]; then
  rm -f "$POSTINSTALL_SCRIPT"
  echo "Removed post-install script ${POSTINSTALL_SCRIPT}"
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

if [[ $SKIP_PACKAGES -eq 1 ]]; then
  echo "Skipping Alpine packages (--skip packages)"
elif [[ ${#INSTALL_PACKAGES[@]} -gt 0 ]]; then
  echo "Installing Alpine packages: ${INSTALL_PACKAGES[*]}"
  docker rm temp 2>/dev/null || true

  # Install one package at a time. packages.conf is shared by every PHP version
  # and its phpNN- prefix is rewritten to the target version, so an entry saved
  # for 8.5 may not exist for 8.6 (php85-sodium has no php86-sodium counterpart).
  # "apk add pkg1 pkg2" resolves the whole set upfront and installs nothing if a
  # single name is unknown, so one missing package would block all the others.
  # The loop isolates each failure and reports the ones that could not install.
  # It exits 0 when at least one package installed, so whatever did succeed is
  # still committed to the image below.
  # No -it here: apk add is non-interactive, and a TTY breaks piped/CI runs.
  if docker run --user root --name temp "$PHP_IMAGE" sh -c '
      installed=0
      failed=""
      for pkg in "$@"; do
        if apk add --no-cache "$pkg"; then
          installed=$((installed + 1))
        else
          failed="$failed $pkg"
        fi
      done
      [ -n "$failed" ] && echo "Warning: no package for this PHP version:$failed" >&2
      [ "$installed" -gt 0 ]
    ' _ "${INSTALL_PACKAGES[@]}"; then
    docker commit temp "$PHP_IMAGE"
  else
    echo "Warning: no package could be installed, continuing with the base image." >&2
  fi
  docker rm temp 2>/dev/null || true
fi

# Run the post-install script of this PHP version on top of the packages.
# Unlike a missing package, a failing script aborts the install: the image
# would silently lack what the script was meant to add.
if [[ $SKIP_POSTINSTALL -eq 1 ]]; then
  echo "Skipping post-install script (--skip postinstall)"
elif [[ -f "$POSTINSTALL_SCRIPT" ]]; then
  echo "Running post-install script: ${POSTINSTALL_SCRIPT}"
  docker rm temp 2>/dev/null || true

  # "# ENV NAME=value" lines become environment variables of the image.
  COMMIT_ARGS=()
  while IFS= read -r env_line; do
    COMMIT_ARGS+=(--change "ENV ${env_line}")
  done < <(sed -n -E 's/^#[[:space:]]*ENV[[:space:]]+//p' "$POSTINSTALL_SCRIPT")

  chmod a+rx "$POSTINSTALL_SCRIPT"
  if docker run --user root --name temp \
      -e "PHP_VERSION=${PHP_VERSION}" \
      -v "$POSTINSTALL_SCRIPT":/tmp/postinstall.sh:ro \
      "$PHP_IMAGE" /tmp/postinstall.sh; then
    docker commit ${COMMIT_ARGS[@]+"${COMMIT_ARGS[@]}"} temp "$PHP_IMAGE"
  else
    echo "Error: post-install script failed: ${POSTINSTALL_SCRIPT}" >&2
    docker rm temp 2>/dev/null || true
    exit 5
  fi
  docker rm temp 2>/dev/null || true
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
