#!/usr/bin/env bash
# binary-install.sh: code shared by the scripts that install a tool released as one
# binary (jq.sh, yq.sh, kubectl.sh, helm.sh, kustomize.sh, doctl.sh, eksctl.sh). Sourced,
# never run.
#
# The installer defines print_usage, sets
#   BINARY_NAME   the command, and its folder: $HOME/.shellscript/<name>/<version>
#   BINARY_LABEL  name used in the messages ("jq")
# defines
#   binary_latest_version  prints the latest version, as --version takes it
#   binary_download_url    prints the URL for BINARY_VERSION and BINARY_ARCH (amd64 or
#                          arm64): the binary itself, or a .tar.gz that holds it
# and calls: binary_install "$@"

# github_latest_tag <owner/repo>: tag of the latest release
github_latest_tag() {
  fetch "https://api.github.com/repos/$1/releases/latest" \
    | grep '"tag_name"' | sed 's/.*"tag_name": *"\(.*\)".*/\1/'
}

binary_print_manifest() {
  cat <<MANIFEST
BIN_FILES=${BINARY_NAME}
FOLDERS=\$HOME/.shellscript/${BINARY_NAME}
SHELLRC_FILE=
MANIFEST
}

binary_install() {
  # Parse flags
  DRY_RUN=0
  BINARY_VERSION=""
  local force=0

  while [[ ${1-} ]]; do
    case "$1" in
      -h|--help) print_usage; exit 0 ;;
      --manifest) binary_print_manifest; exit 0 ;;
      --dry-run) DRY_RUN=1 ;;
      --force) force=1 ;;
      --version)
        shift || { err "--version requires a value"; exit 2; }
        BINARY_VERSION="$1"
        ;;
      *) err "Unknown option: $1"; print_usage; exit 2 ;;
    esac
    shift || true
  done

  # Preconditions
  require_downloader

  # Detect CPU architecture
  case "$(uname -m)" in
    x86_64|amd64)  BINARY_ARCH="amd64" ;;
    aarch64|arm64) BINARY_ARCH="arm64" ;;
    *) err "Unsupported architecture: $(uname -m) (supported: x86_64, aarch64)"; exit 1 ;;
  esac

  if [[ -z "$BINARY_VERSION" ]]; then
    BINARY_VERSION="$(binary_latest_version)" || true
    if [[ -z "$BINARY_VERSION" ]]; then
      err "Could not find the latest ${BINARY_LABEL} version. Pass it with --version."
      exit 1
    fi
    log "Latest ${BINARY_LABEL} version: ${BINARY_VERSION}"
  fi

  # Configuration
  local home="${SHELLSCRIPT_HOME}/${BINARY_NAME}"
  local install_dir="${home}/${BINARY_VERSION}"
  local wrapper="${SHELLSCRIPT_BIN}/${BINARY_NAME}"

  log "Installing ${BINARY_LABEL} ${BINARY_VERSION}"

  if [[ -x "${install_dir}/${BINARY_NAME}" && "$force" != "1" ]]; then
    log "${BINARY_LABEL} ${BINARY_VERSION} is already installed at ${install_dir}. Skipping download (use --force to re-download)."
  else
    local url temp_dir downloaded
    url="$(binary_download_url)"
    case "$url" in *.tar.gz|*.tgz) require_cmd tar ;; esac

    temp_dir=$(mktemp -d)
    # shellcheck disable=SC2064  # expanded now on purpose: temp_dir is local
    trap "rm -rf '${temp_dir}'" EXIT
    downloaded="${temp_dir}/download"

    log "Downloading ${url}"
    run "download \"${url}\" \"${downloaded}\"" || {
      err "Could not download ${BINARY_LABEL} ${BINARY_VERSION} for ${BINARY_ARCH}: check the version."
      exit 1
    }

    if [[ "$DRY_RUN" == "1" ]]; then
      log "[dry-run] Would install to ${install_dir}"
    else
      local binary="$downloaded"
      case "$url" in
        *.tar.gz|*.tgz)
          mkdir -p "${temp_dir}/extracted"
          tar -xzf "$downloaded" -C "${temp_dir}/extracted"
          binary=$(find "${temp_dir}/extracted" -type f -name "$BINARY_NAME" | head -1)
          if [[ -z "$binary" ]]; then
            err "'${BINARY_NAME}' was not found in the downloaded archive"
            exit 1
          fi
          ;;
      esac
      mkdir -p "$install_dir"
      mv "$binary" "${install_dir}/${BINARY_NAME}"
      chmod +x "${install_dir}/${BINARY_NAME}"
    fi
  fi

  # Make it the active version. The link is relative, so it holds whatever the home
  # directory is called.
  run "mkdir -p \"${home}\" \"${SHELLSCRIPT_BIN}\""
  run "ln -sfn \"${BINARY_VERSION}\" \"${home}/current\""

  if [[ "$DRY_RUN" == "1" ]]; then
    log "[dry-run] Writing ${wrapper}"
  else
    cat >"$wrapper" <<WRAP
#!/usr/bin/env bash
exec "\${HOME}/.shellscript/${BINARY_NAME}/current/${BINARY_NAME}" "\$@"
WRAP
    chmod +x "$wrapper"
  fi

  log "Done. ${BINARY_LABEL} ${BINARY_VERSION} installed to ${install_dir}"
}
