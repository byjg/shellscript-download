# docker-wrapper.sh: code shared by the scripts that create Docker-backed wrappers
# (php-docker, node-docker). It is not a script to run: they source it, after
# their postLoad() downloaded it next to them.
#
# What is shared: the --add/--volume/--env/--postinstall/--no-postinstall/--skip
# options, the files they are saved to, the steps that apply them to the image,
# the code the wrappers run to mount the volumes and forward the environment, and
# the manifest "load.sh remove" uses.

DOCKER_PACKAGES=""
DOCKER_VOLUMES=""
DOCKER_ENV_NAMES=""
DOCKER_POSTINSTALL=""
DOCKER_NO_POSTINSTALL=0
DOCKER_SKIP_PACKAGES=0
DOCKER_SKIP_POSTINSTALL=0
DOCKER_OPT_SHIFT=0

# Handles the options every Docker-backed wrapper has. Call it with the arguments
# still to parse: it returns 1 when "$1" is not one of them; otherwise it stores
# the value and sets DOCKER_OPT_SHIFT to how many arguments it consumed.
docker_wrapper_option() {
  local step
  case "$1" in
    --add|--volume|--env|--postinstall|--skip)
      if [[ $# -lt 2 ]]; then
        echo "Error: $1 requires a value" >&2
        exit 1
      fi
      ;;
  esac

  DOCKER_OPT_SHIFT=2
  case "$1" in
    --add) DOCKER_PACKAGES="${DOCKER_PACKAGES:+$DOCKER_PACKAGES,}$2" ;;
    --volume) DOCKER_VOLUMES="${DOCKER_VOLUMES:+$DOCKER_VOLUMES,}$2" ;;
    --env) DOCKER_ENV_NAMES="${DOCKER_ENV_NAMES:+$DOCKER_ENV_NAMES,}$2" ;;
    --postinstall) DOCKER_POSTINSTALL="$2" ;;
    --no-postinstall)
      DOCKER_NO_POSTINSTALL=1
      DOCKER_OPT_SHIFT=1
      ;;
    --skip)
      IFS=',' read -ra DOCKER_SKIP_STEPS <<< "$2"
      for step in "${DOCKER_SKIP_STEPS[@]}"; do
        case "$step" in
          packages) DOCKER_SKIP_PACKAGES=1 ;;
          postinstall) DOCKER_SKIP_POSTINSTALL=1 ;;
          *)
            echo "Error: Invalid --skip step '$step'. Supported steps are: packages, postinstall" >&2
            exit 1
            ;;
        esac
      done
      ;;
    *) return 1 ;;
  esac
}

# Appends an entry to a .conf file unless it is already there.
docker_conf_add() {
  local file="$1" label="$2" entry="$3"
  touch "$file"
  if ! grep -qxF -- "$entry" "$file"; then
    echo "$entry" >> "$file"
    echo "Added ${label} to ${file}: ${entry}"
  fi
}

# Prints the entries of a .conf file, without blank lines and comments.
docker_conf_list() {
  [[ -f "$1" ]] || return 0
  grep -v -E '^[[:space:]]*(#|$)' "$1" || true
}

# Saves what the options asked for, so it survives the next install/update.
#   $1 folder of the tool (php, node): packages.conf, volumes.conf and env.conf,
#      shared by every version of it
#   $2 folder of the version being installed: postinstall.sh, tied to that version
docker_wrapper_configure() {
  local tool_dir="$1" version_dir="$2" entry
  local -a entries

  DOCKER_PACKAGES_CONF="$tool_dir/packages.conf"
  DOCKER_VOLUMES_CONF="$tool_dir/volumes.conf"
  DOCKER_ENV_CONF="$tool_dir/env.conf"
  DOCKER_POSTINSTALL_SCRIPT="$version_dir/postinstall.sh"

  if [[ -n "$DOCKER_POSTINSTALL" && $DOCKER_NO_POSTINSTALL -eq 1 ]]; then
    echo "Error: --postinstall and --no-postinstall cannot be used together" >&2
    exit 1
  fi
  if [[ -n "$DOCKER_POSTINSTALL" && ! -f "$DOCKER_POSTINSTALL" ]]; then
    echo "Error: post-install script not found: $DOCKER_POSTINSTALL" >&2
    exit 1
  fi

  mkdir -p "$version_dir"

  IFS=',' read -ra entries <<< "$DOCKER_PACKAGES"
  for entry in ${entries[@]+"${entries[@]}"}; do
    docker_conf_add "$DOCKER_PACKAGES_CONF" "package" "$entry"
  done

  # The wrappers read volumes.conf and env.conf at runtime
  IFS=',' read -ra entries <<< "$DOCKER_VOLUMES"
  for entry in ${entries[@]+"${entries[@]}"}; do
    entry="${entry%/}"
    if [[ ! -d "$entry" ]]; then
      echo "Warning: volume path does not exist: $entry" >&2
    fi
    docker_conf_add "$DOCKER_VOLUMES_CONF" "volume" "$entry"
  done

  IFS=',' read -ra entries <<< "$DOCKER_ENV_NAMES"
  for entry in ${entries[@]+"${entries[@]}"}; do
    docker_conf_add "$DOCKER_ENV_CONF" "variable" "$entry"
  done

  if [[ -n "$DOCKER_POSTINSTALL" ]]; then
    cp "$DOCKER_POSTINSTALL" "$DOCKER_POSTINSTALL_SCRIPT"
    echo "Saved post-install script to ${DOCKER_POSTINSTALL_SCRIPT}"
  fi
  if [[ $DOCKER_NO_POSTINSTALL -eq 1 && -f "$DOCKER_POSTINSTALL_SCRIPT" ]]; then
    rm -f "$DOCKER_POSTINSTALL_SCRIPT"
    echo "Removed post-install script ${DOCKER_POSTINSTALL_SCRIPT}"
  fi
}

# Installs Alpine packages into an image and commits the result to the same tag.
#   $1 image, $2... packages
docker_image_packages() {
  local image="$1"
  shift
  local container="shellscript-setup-$$"

  if [[ $DOCKER_SKIP_PACKAGES -eq 1 ]]; then
    echo "Skipping Alpine packages (--skip packages)"
    return 0
  fi
  [[ $# -gt 0 ]] || return 0

  echo "Installing Alpine packages: $*"
  docker rm -f "$container" >/dev/null 2>&1 || true

  # One package at a time: "apk add pkg1 pkg2" resolves the whole set upfront and
  # installs nothing if a single name is unknown, so one missing package would
  # block all the others. The loop isolates each failure and reports it, and exits
  # 0 when at least one package installed, so what did succeed is still committed.
  # No -it here: apk add is non-interactive, and a TTY breaks piped/CI runs.
  if docker run --user root --name "$container" "$image" sh -c '
      installed=0
      failed=""
      for pkg in "$@"; do
        if apk add --no-cache "$pkg"; then
          installed=$((installed + 1))
        else
          failed="$failed $pkg"
        fi
      done
      [ -n "$failed" ] && echo "Warning: package not found:$failed" >&2
      [ "$installed" -gt 0 ]
    ' _ "$@"; then
    docker commit "$container" "$image"
  else
    echo "Warning: no package could be installed, continuing without them." >&2
  fi
  docker rm -f "$container" >/dev/null 2>&1 || true
}

# Runs the saved post-install script as root in an image and commits the result
# to the same tag. A "# ENV NAME=value" line in the script sets that environment
# variable in the image. Unlike a missing package, a failing script aborts the
# install: the image would silently lack what the script was meant to add.
#   $1 image, $2... extra "docker run" options (for example -e NAME=value)
docker_image_postinstall() {
  local image="$1"
  shift
  local script="$DOCKER_POSTINSTALL_SCRIPT"
  local container="shellscript-setup-$$"
  local env_line
  local -a commit_args=()

  if [[ $DOCKER_SKIP_POSTINSTALL -eq 1 ]]; then
    echo "Skipping post-install script (--skip postinstall)"
    return 0
  fi
  [[ -f "$script" ]] || return 0

  echo "Running post-install script: ${script}"
  docker rm -f "$container" >/dev/null 2>&1 || true

  while IFS= read -r env_line; do
    commit_args+=(--change "ENV ${env_line}")
  done < <(sed -n -E 's/^#[[:space:]]*ENV[[:space:]]+//p' "$script")

  chmod a+rx "$script"
  if docker run --user root --name "$container" "$@" \
      -v "$script":/tmp/postinstall.sh:ro \
      "$image" /tmp/postinstall.sh; then
    docker commit ${commit_args[@]+"${commit_args[@]}"} "$container" "$image"
  else
    echo "Error: post-install script failed: ${script}" >&2
    docker rm -f "$container" >/dev/null 2>&1 || true
    exit 5
  fi
  docker rm -f "$container" >/dev/null 2>&1 || true
}

# Prints the code a wrapper uses to mount the extra volumes. It fills
# EXTRA_VOLUME_ARGS from volumes.conf, read at runtime.
#   $1 volumes.conf, $2 optional prefix of the path inside the container
docker_volume_args() {
  local code
  read -r -d '' code <<'CODE' || true
# Extra volumes from volumes.conf (one absolute path per line)
EXTRA_VOLUME_ARGS=()
VOLUMES_CONF="__VOLUMES_CONF__"
if [[ -f "$VOLUMES_CONF" ]]; then
  while IFS= read -r vol_path; do
    [[ -z "$vol_path" || "$vol_path" == \#* ]] && continue
    if [[ -d "$vol_path" ]]; then
      EXTRA_VOLUME_ARGS+=(-v "$vol_path":"__PREFIX__$vol_path")
    fi
  done < "$VOLUMES_CONF"
fi
CODE
  code="${code//__VOLUMES_CONF__/$1}"
  printf '%s\n' "${code//__PREFIX__/${2-}}"
}

# Prints the manifest "load.sh remove" uses when no version is given: the wrappers
# of every installed version, found in the bin folder, and the whole folder of the
# tool, so the .conf files and the post-install scripts go with --purge.
#   $1 tool (php, node), $2... commands it creates wrappers for
docker_manifest_all() {
  local tool="$1"
  shift
  local base="${SHELLSCRIPT_HOME:-$HOME/.shellscript}"
  local bin_files="$*"
  local names file name
  names="$(IFS='|'; echo "$*")"
  for file in "$base"/bin/*; do
    name="$(basename "$file")"
    [[ "$name" =~ ^(${names})[0-9]+(\.[0-9]+)?$ ]] || continue
    bin_files+=" $name"
  done
  cat <<MANIFEST
BIN_FILES=${bin_files}
FOLDERS=${base}/${tool}
SHELLRC_FILE=${base}/shellrc/${tool}-init.sh
MANIFEST
}

# Prints the code a wrapper uses to forward the environment to the container. It
# fills ENV_ARGS with "-e NAME=value" pairs, leaving out what only makes sense on
# the host: a desktop session easily exports 70+ such variables, none of which a
# container can use. $1 is the env.conf of the tool: the names or patterns listed
# there (one per line) are forwarded anyway.
docker_env_filter() {
  local filter
  read -r -d '' filter <<'FILTER' || true
# Host variables to forward anyway, from env.conf (one name or pattern per line)
ENV_KEEP=()
ENV_CONF="__ENV_CONF__"
if [[ -f "$ENV_CONF" ]]; then
  while IFS= read -r env_pattern; do
    [[ -z "$env_pattern" || "$env_pattern" == \#* ]] && continue
    ENV_KEEP+=("$env_pattern")
  done < "$ENV_CONF"
fi

# Prepare environment variables (exclude host-specific vars)
ENV_ARGS=()
while IFS='=' read -r -d '' name value; do
  # Never forwarded: they would break the container
  case "$name" in
    PATH|HOME|USER|LOGNAME|HOSTNAME|PWD|OLDPWD|SHELL|TERM|SHLVL|_)
      continue
      ;;
  esac

  env_keep=0
  for env_pattern in ${ENV_KEEP[@]+"${ENV_KEEP[@]}"}; do
    # shellcheck disable=SC2053  # the right side is a pattern on purpose
    if [[ "$name" == $env_pattern ]]; then
      env_keep=1
      break
    fi
  done

  if [[ $env_keep -eq 0 ]]; then
    case "$name" in
      # Desktop session (X11/Wayland, GNOME, KDE, GTK, Qt, D-Bus)
      XDG_*|DBUS_*|DISPLAY|WAYLAND_DISPLAY|XAUTHORITY|SESSION_MANAGER|DESKTOP_*|GDMSESSION|GDM_*|\
      GNOME_*|GTK*|QT_*|QTWEBENGINE_*|GIO_*|GJS_*|KDE_*|XMODIFIERS|WINDOWPATH|WINDOWID|UBUNTU_*|\
      CLUTTER_*|GSM_*|GPG_*|XCURSOR_*|*_IM_MODULE)
        continue
        ;;
      # systemd
      INVOCATION_ID|JOURNAL_STREAM|MANAGERPID|SYSTEMD_*|MEMORY_PRESSURE_*|NOTIFY_SOCKET)
        continue
        ;;
      # Terminal, prompt and IDE
      TERM_*|TERMINAL_*|COLORTERM|LS_COLORS|LESSOPEN|LESSCLOSE|STARSHIP_*|FIG_*|TMUX*|VTE_*|\
      KONSOLE_*|INTELLIJ_*|VSCODE_*|PROCESS_LAUNCHED_BY_*|BASH_FUNC_*)
        continue
        ;;
      # Host toolchains whose paths do not exist in the container
      JAVA_HOME|JDK_HOME|M2_HOME|MAVEN_*|NVM_*|BUN_*|COREPACK_*|SDKMAN_*|PYENV_*|VIRTUAL_ENV|\
      CONDA_*|GOPATH|GOROOT|CARGO_HOME|RUSTUP_HOME|DEBUGINFOD_URLS)
        continue
        ;;
      # Host session and agents (composer forwards SSH_AUTH_SOCK with its socket)
      CLAUDE*|AI_AGENT|SSH_*|USERNAME|MAIL)
        continue
        ;;
    esac
  fi

  ENV_ARGS+=(-e "${name}=${value}")
done < <(env -0)
FILTER
  printf '%s\n' "${filter//__ENV_CONF__/$1}"
}
