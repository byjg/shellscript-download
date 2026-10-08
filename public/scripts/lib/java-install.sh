#!/usr/bin/env bash
# java-install.sh: code shared by the java-<vendor>.sh installers. Sourced, never run.
#
# The installer defines print_usage, sets
#   JAVA_VENDOR        "temurin" installs to $HOME/.shellscript/java-temurin/<version>
#   JAVA_LABEL         name used in the messages ("Eclipse Temurin Java")
#   JAVA_LTS_VERSIONS  versions installed without asking ("8 11 17 21 25")
#   JAVA_NON_LTS_NOTE  optional extra line of the non-LTS warning
# defines
#   java_download_url  prints the archive URL for JAVA_VERSION and JAVA_ARCH (x64 or
#                      aarch64), or nothing when there is none
# and calls: java_install "$@"

java_print_manifest() {
  local version="/$1"

  if [[ "$version" == "/all" ]]; then
    version=""
  fi

  cat <<MANIFEST
FOLDERS=\$HOME/.shellscript/java-${JAVA_VENDOR}${version}
SHELLRC_FILE=\$HOME/.shellscript/shellrc/java-${JAVA_VENDOR}-init.sh
MANIFEST
}

java_install() {
  local name="java-${JAVA_VENDOR}"

  # Parse flags
  DRY_RUN=0
  JAVA_VERSION="21"
  local manifest_mode=0 manifest_version="all" yes=0 force=0

  while [[ ${1-} ]]; do
    case "$1" in
      -h|--help) print_usage; exit 0 ;;
      --manifest) manifest_mode=1 ;;
      --dry-run) DRY_RUN=1 ;;
      -y|--yes) yes=1 ;;
      --force) force=1 ;;
      --version)
        shift || { err "--version requires a value"; exit 2; }
        JAVA_VERSION="$1"
        if [[ "$manifest_mode" == "1" ]]; then
          manifest_version="$1"
        fi
        ;;
      *) err "Unknown option: $1"; print_usage; exit 2 ;;
    esac
    shift || true
  done

  # Handle manifest mode
  if [[ "$manifest_mode" == "1" ]]; then
    java_print_manifest "$manifest_version"
    exit 0
  fi

  # Warn for non-LTS versions
  if ! echo " $JAVA_LTS_VERSIONS " | grep -q " $JAVA_VERSION "; then
    if [[ "$yes" == "1" ]]; then
      log "WARNING: Java ${JAVA_VERSION} is not an LTS version (--yes passed, skipping confirmation)."
    else
      log "WARNING: Java ${JAVA_VERSION} is not an LTS version and may be EOL or unsupported."
      if [[ -n "${JAVA_NON_LTS_NOTE:-}" ]]; then
        log "$JAVA_NON_LTS_NOTE"
      fi
      printf "[%s.sh] Are you sure you want to install it? [y/N] " "$name"
      local confirm
      read -r confirm
      if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log "Aborted."
        exit 0
      fi
    fi
  fi

  # Preconditions
  require_downloader
  require_cmd tar

  # Detect CPU architecture
  case "$(uname -m)" in
    x86_64|amd64)  JAVA_ARCH="x64" ;;
    aarch64|arm64) JAVA_ARCH="aarch64" ;;
    *) err "Unsupported architecture: $(uname -m) (supported: x86_64, aarch64)"; exit 1 ;;
  esac

  # Configuration
  local home_base="${SHELLSCRIPT_HOME}/${name}"
  local install_dir="${home_base}/${JAVA_VERSION}"
  local shellrc_file="${SHELLSCRIPT_SHELLRC}/${name}-init.sh"
  local temp_archive="/tmp/${name}.tar.gz"

  # shellcheck disable=SC2064  # expanded now on purpose: temp_archive is local
  trap "rm -f '${temp_archive}'" EXIT

  log "Installing ${JAVA_LABEL} ${JAVA_VERSION}"

  if [[ -d "$install_dir" && "$force" != "1" ]]; then
    log "Java ${JAVA_VERSION} is already installed at ${install_dir}. Skipping download (use --force to re-download)."
  else
    local download_url
    download_url="$(java_download_url)" || true
    if [[ -z "$download_url" ]]; then
      err "Could not resolve download URL for ${JAVA_LABEL} ${JAVA_VERSION}."
      exit 1
    fi

    # Download Java
    log "Downloading Java from ${download_url}"
    run "download \"${download_url}\" \"${temp_archive}\""

    # Extract Java
    log "Extracting Java to ${install_dir}"
    run "mkdir -p \"${home_base}\""

    if [[ "$DRY_RUN" != "1" ]]; then
      # The archive holds one directory whose name changes with every release
      local temp_extract_dir extracted_dir
      temp_extract_dir=$(mktemp -d)
      tar -xzf "${temp_archive}" -C "${temp_extract_dir}"
      extracted_dir=$(ls -1 "${temp_extract_dir}" | head -1)

      if [[ -z "$extracted_dir" ]]; then
        err "Failed to find extracted JDK directory"
        rm -rf "${temp_extract_dir}"
        exit 1
      fi

      rm -rf "${install_dir}"
      mv "${temp_extract_dir}/${extracted_dir}" "${install_dir}"
      rm -rf "${temp_extract_dir}"
      log "Extracted to ${install_dir}"
    else
      log "[dry-run] Would extract to ${install_dir}"
    fi
  fi

  # Write shell init snippet
  log "Writing environment variables to ${shellrc_file}"
  run "mkdir -p \"${SHELLSCRIPT_SHELLRC}\""
  if [[ "$DRY_RUN" != "1" ]]; then
    cat >"${shellrc_file}" <<WRAP
export JAVA_HOME="\$HOME/.shellscript/${name}/${JAVA_VERSION}"
export JDK_HOME="\$HOME/.shellscript/${name}/${JAVA_VERSION}"
export PATH="\$HOME/.shellscript/${name}/${JAVA_VERSION}/bin:\$PATH"
WRAP
  else
    log "[dry-run] Would write to ${shellrc_file}"
  fi

  log "Done. ${JAVA_LABEL} ${JAVA_VERSION} installed to ${install_dir}"
  log "Source ${shellrc_file} from your shell rc for JAVA_HOME environment variable"
}
