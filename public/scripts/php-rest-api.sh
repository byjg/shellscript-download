#!/usr/bin/env bash
# php-rest-api.sh: Install byjg/rest-reference-architecture in unattended mode
#
# Usage (via loader):
#   load.sh php-rest-api -- <folder> --namespace=<name> --name=<name/name> \
#     [--mysql-uri=<uri>] [--install-examples=Y|n] [--version=<version>] \
#     [--php-version=<version>] [--timezone=<tz>] [--git-name=<name>] [--git-email=<email>]
#
# Examples:
#   # Minimal installation
#   load.sh php-rest-api -- myproject --namespace=MyApp --name=mycompany/myapp
#
#   # Full configuration
#   load.sh php-rest-api -- myproject --namespace=MyApp --name=mycompany/myapp \
#     --mysql-uri=mysql://root:secret@mysql-container/mydb \
#     --install-examples=n --version="^6.0" --php-version=8.4 \
#     --timezone=America/New_York
#
# Description:
# - Creates a setup.json file in the parent directory for unattended installation
# - Runs composer create-project with byjg/rest-reference-architecture
# - Automatically configures the project using the provided parameters
# - Cleans up the setup.json file after successful installation
# - Idempotent: safe to re-run, though it will recreate the project folder
#
# Required Arguments:
#   <folder>          Target folder name where the project will be created
#   --namespace       Project namespace (CamelCase, e.g., MyApp, Tutorial)
#   --name            Composer package name (vendor/package format, e.g., mycompany/myapp)
#
# Optional Arguments:
#   --mysql-uri       MySQL connection string (default: mysql://root:mysqlp455w0rd@mysql-container/mydb)
#   --install-examples Install example code (Y or n, default: Y)
#   --version         Composer version constraint (default: ^6.0)
#   --php-version     PHP version for Docker (8.1, 8.2, 8.3, 8.4, default: current PHP version)
#   --timezone        Server timezone (default: UTC)
#   --git-name        Git user name for the project (default: from git config or "Your Name")
#   --git-email       Git user email for the project (default: from git config or "your.email@example.com")
#   -h, --help        Show this help and exit
#
# Notes:
# - Requires composer installed on the system or use load.sh php-docker first
# - The setup.json file will be created in the parent directory of the target folder
# - The setup.json file is automatically removed after successful installation
# - If the target folder exists, the script will fail (safety measure)

set -euo pipefail

echo ">_ php-rest-api.sh"
echo

log()  { printf "[php-rest-api.sh] %s\n" "$*"; }
err()  { printf "[php-rest-api.sh][ERROR] %s\n" "$*" >&2; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || { err "Required command '$1' not found"; exit 1; }; }

print_usage() {
  cat <<'USAGE'
php-rest-api.sh <folder> --namespace=<name> --name=<name/name> [options]

Installs byjg/rest-reference-architecture in unattended mode.

Required Arguments:
  <folder>          Target folder name where the project will be created
  --namespace       Project namespace (CamelCase, e.g., MyApp, Tutorial)
  --name            Composer package name (vendor/package, e.g., mycompany/myapp)

Optional Arguments:
  --mysql-uri       MySQL connection string
                    (default: mysql://root:mysqlp455w0rd@mysql-container/mydb)
  --install-examples Install example code (Y or n, default: Y)
  --version         Composer version constraint (default: ^6.0)
  --php-version     PHP version for Docker (8.1-8.4, default: current)
  --timezone        Server timezone (default: UTC)
  --git-name        Git user name (default: from git config)
  --git-email       Git user email (default: from git config)
  -h, --help        Show this help and exit

Examples:
  # Minimal installation
  load.sh php-rest-api -- myproject --namespace=MyApp --name=mycompany/myapp

  # Full configuration
  load.sh php-rest-api -- myproject --namespace=MyApp --name=mycompany/myapp \
    --mysql-uri=mysql://root:secret@mysql-container/mydb \
    --install-examples=n --version="^6.0" --php-version=8.4

USAGE
}

# Default values
FOLDER=""
NAMESPACE=""
COMPOSER_NAME=""
MYSQL_URI="mysql://root:mysqlp455w0rd@mysql-container/mydb"
INSTALL_EXAMPLES="true"
VERSION="^6.0"
PHP_VERSION=""
TIMEZONE="UTC"
GIT_NAME=""
GIT_EMAIL=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "${1}" in
    -h|--help)
      print_usage
      exit 0
      ;;
    --namespace=*)
      NAMESPACE="${1#*=}"
      shift
      ;;
    --name=*)
      COMPOSER_NAME="${1#*=}"
      shift
      ;;
    --mysql-uri=*)
      MYSQL_URI="${1#*=}"
      shift
      ;;
    --install-examples=*)
      val="${1#*=}"
      if [[ "${val}" == "n" || "${val}" == "N" || "${val}" == "no" || "${val}" == "No" || "${val}" == "false" ]]; then
        INSTALL_EXAMPLES="false"
      else
        INSTALL_EXAMPLES="true"
      fi
      shift
      ;;
    --version=*)
      VERSION="${1#*=}"
      shift
      ;;
    --php-version=*)
      PHP_VERSION="${1#*=}"
      shift
      ;;
    --timezone=*)
      TIMEZONE="${1#*=}"
      shift
      ;;
    --git-name=*)
      GIT_NAME="${1#*=}"
      shift
      ;;
    --git-email=*)
      GIT_EMAIL="${1#*=}"
      shift
      ;;
    -*)
      err "Unknown option: $1"
      echo >&2
      print_usage >&2
      exit 2
      ;;
    *)
      if [[ -z "${FOLDER}" ]]; then
        FOLDER="$1"
        shift
      else
        err "Unexpected argument: $1"
        echo >&2
        print_usage >&2
        exit 2
      fi
      ;;
  esac
done

# Validate required arguments
if [[ -z "${FOLDER}" ]]; then
  err "<folder> is required."
  echo >&2
  print_usage >&2
  exit 2
fi

if [[ -z "${NAMESPACE}" ]]; then
  err "--namespace is required."
  echo >&2
  print_usage >&2
  exit 2
fi

if [[ -z "${COMPOSER_NAME}" ]]; then
  err "--name is required."
  echo >&2
  print_usage >&2
  exit 2
fi

# Validate namespace format (should be CamelCase)
if ! [[ "${NAMESPACE}" =~ ^[A-Z][a-zA-Z0-9]*$ ]]; then
  err "Namespace must be in CamelCase format (e.g., MyApp, Tutorial)"
  exit 2
fi

# Validate composer name format (should be vendor/package)
if ! [[ "${COMPOSER_NAME}" =~ ^[a-z0-9_-]+/[a-z0-9_-]+$ ]]; then
  err "Composer name must be in vendor/package format (e.g., mycompany/myapp)"
  exit 2
fi

# Validate PHP version if provided
if [[ -n "${PHP_VERSION}" ]]; then
  case "${PHP_VERSION}" in
    "8.1"|"8.2"|"8.3"|"8.4")
      ;;
    *)
      err "Invalid PHP version. Supported versions are: 8.1, 8.2, 8.3, 8.4"
      exit 2
      ;;
  esac
fi

# Check if composer is available
require_cmd composer

# Get git config defaults if not provided
if [[ -z "${GIT_NAME}" ]]; then
  GIT_NAME=$(git config --global user.name 2>/dev/null || echo "Your Name")
fi

if [[ -z "${GIT_EMAIL}" ]]; then
  GIT_EMAIL=$(git config --global user.email 2>/dev/null || echo "your.email@example.com")
fi

# Get current PHP version if not provided
if [[ -z "${PHP_VERSION}" ]]; then
  if command -v php >/dev/null 2>&1; then
    PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;')
    log "Detected PHP version: ${PHP_VERSION}"
  else
    PHP_VERSION="8.4"
    log "PHP not found, using default version: ${PHP_VERSION}"
  fi
fi

# Determine the parent directory (where we'll place setup.json)
# Convert folder to absolute path if it's relative
if [[ "${FOLDER}" = /* ]]; then
  PARENT_DIR=$(dirname "${FOLDER}")
  FOLDER_NAME=$(basename "${FOLDER}")
else
  PARENT_DIR="$(pwd)"
  FOLDER_NAME="${FOLDER}"
  FOLDER="${PARENT_DIR}/${FOLDER_NAME}"
fi

# Check if folder already exists
if [[ -d "${FOLDER}" ]]; then
  err "Folder '${FOLDER}' already exists. Please remove it first or choose a different name."
  exit 3
fi

# Create parent directory if it doesn't exist
mkdir -p "${PARENT_DIR}"

# Create setup.json in the parent directory
SETUP_JSON="${PARENT_DIR}/setup.json"
log "Creating setup.json in parent directory: ${SETUP_JSON}"

cat > "${SETUP_JSON}" <<EOF
{
  "git_user_name": "${GIT_NAME}",
  "git_user_email": "${GIT_EMAIL}",
  "php_version": "${PHP_VERSION}",
  "namespace": "${NAMESPACE}",
  "composer_name": "${COMPOSER_NAME}",
  "mysql_connection": "${MYSQL_URI}",
  "timezone": "${TIMEZONE}",
  "install_examples": ${INSTALL_EXAMPLES}
}
EOF

log "Setup configuration:"
cat "${SETUP_JSON}"

# Change to parent directory to run composer create-project
cd "${PARENT_DIR}"

# Run composer create-project
log "Running composer create-project in ${PARENT_DIR}..."
log "Command: composer -sdev create-project byjg/rest-reference-architecture ${FOLDER_NAME} ${VERSION}"

if ! composer -sdev create-project byjg/rest-reference-architecture "${FOLDER_NAME}" "${VERSION}"; then
  err "Failed to create project"
  rm -f "${SETUP_JSON}"
  exit 4
fi

# Clean up setup.json
log "Cleaning up ${SETUP_JSON}..."
rm -f "${SETUP_JSON}"

log "Project successfully created in: ${FOLDER}"
log ""
log "Next steps:"
log "  1. cd ${FOLDER}"
log "  2. docker compose -f docker-compose-dev.yml up -d"
log "  3. APP_ENV=dev composer run migrate -- reset --yes"
log "  4. Visit http://localhost:8080/docs for API documentation"
log ""
log "Done."
