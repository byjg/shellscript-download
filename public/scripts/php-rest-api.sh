#!/usr/bin/env bash
# php-rest-api.sh: Install byjg/rest-reference-architecture in unattended mode
# Required Arguments:
#   <folder>          Target folder name where the project will be created
#   --namespace       Project namespace (CamelCase, e.g., MyApp, Tutorial)
#   --name            Composer package name (vendor/package format, e.g., mycompany/myapp)
#
# Optional Arguments:
#   --mysql-uri       MySQL connection string (default values: schema=mysql, host=mysql-container,
#                     user=root, password=mysqlp455w0rd, dev db=localdev, test db=localtest)
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
                    (default values: schema=mysql, host=mysql-container,
                     user=root, password=mysqlp455w0rd, dev db=localdev, test db=localtest)
  --install-examples Install example code (Y or n, default: Y)
  --version         Composer version constraint (default: ^6.0)
  --php-version     PHP version for Docker (8.1-8.4, default: current)
  --timezone        Server timezone (default: UTC)
  --git-name        Git user name (default: from git config)
  --git-email       Git user email (default: from git config)
  --manifest        Print installation manifest and exit
  -h, --help        Show this help and exit

Examples:
  # Minimal installation
  load.sh php-rest-api -- myproject --namespace=MyApp --name=mycompany/myapp

  # Full configuration
  load.sh php-rest-api -- myproject --namespace=MyApp --name=mycompany/myapp \
    --mysql-uri=mysql://root:secret@mysql-container/mydb \
    --install-examples=n --version="^6.0" --php-version=8.4

  # Show manifest
  load.sh php-rest-api -- myproject --namespace=MyApp --name=mycompany/myapp --manifest

USAGE
}

print_manifest() {
  local folder="$1"
  # Convert to absolute path if relative
  if [[ "${folder}" != /* ]]; then
    folder="$(pwd)/${folder}"
  fi
  cat <<MANIFEST
BIN_FILES=
FOLDERS=${folder}
SHELLRC_FILE=
MANIFEST
}

# Default values
FOLDER=""
NAMESPACE=""
COMPOSER_NAME=""
MYSQL_URI=""
INSTALL_EXAMPLES="true"
VERSION="^6.0"
PHP_VERSION=""
TIMEZONE="UTC"
GIT_NAME=""
GIT_EMAIL=""
DB_SCHEMA="mysql"
DB_HOST="mysql-container"
DB_USER="root"
DB_PASSWORD="mysqlp455w0rd"
DB_NAME_DEV="localdev"
DB_NAME_TEST="localtest"
SHOW_MANIFEST=0

parse_mysql_uri() {
  local uri="$1"
  local schema rest creds host_db user pass host db

  if [[ "${uri}" != *"://"* || "${uri}" != *@* || "${uri}" != */* ]]; then
    err "Invalid --mysql-uri format. Expected mysql://user:password@host/database"
    exit 2
  fi

  schema="${uri%%://*}"
  rest="${uri#*://}"
  creds="${rest%%@*}"
  host_db="${rest#*@}"
  host="${host_db%%/*}"
  db="${host_db#*/}"

  if [[ -z "${schema}" || -z "${creds}" || -z "${host}" || -z "${db}" ]]; then
    err "Invalid --mysql-uri format. Expected mysql://user:password@host/database"
    exit 2
  fi

  if [[ "${creds}" == *:* ]]; then
    user="${creds%%:*}"
    pass="${creds#*:}"
  else
    user="${creds}"
    pass=""
  fi

  # Strip query/fragment from database name if present
  db="${db%%\?*}"
  db="${db%%#*}"

  if [[ -z "${user}" || -z "${db}" ]]; then
    err "Invalid --mysql-uri format. Expected mysql://user:password@host/database"
    exit 2
  fi

  DB_SCHEMA="${schema}"
  DB_USER="${user}"
  DB_PASSWORD="${pass}"
  DB_HOST="${host}"
  DB_NAME_DEV="${db}"
  DB_NAME_TEST="${db}_test"
}

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
    --manifest)
      SHOW_MANIFEST=1
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

# If manifest requested, print and exit
if [[ $SHOW_MANIFEST -eq 1 ]]; then
  print_manifest "$FOLDER"
  exit 0
fi

# Override DB defaults if a mysql uri is provided
if [[ -n "${MYSQL_URI}" ]]; then
  parse_mysql_uri "${MYSQL_URI}"
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
  "db_schema": "${DB_SCHEMA}",
  "db_host": "${DB_HOST}",
  "db_user": "${DB_USER}",
  "db_password": "${DB_PASSWORD}",
  "db_name_dev": "${DB_NAME_DEV}",
  "db_name_test": "${DB_NAME_TEST}",
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
