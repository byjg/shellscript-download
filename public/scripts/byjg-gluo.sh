#!/usr/bin/env bash
# byjg-gluo.sh: Create a new Gluo project (composer create-project byjg/gluo) in unattended mode
# Required Arguments:
#   <folder>          Target folder name where the project will be created
#   --namespace       Project namespace (CamelCase, e.g., MyApp, Tutorial)
#   --name            Composer package name (vendor/package format, e.g., mycompany/myapp)
#
# Optional Arguments:
#   --db              Database: mysql, postgres or sqlite (default: mysql)
#   --db-uri          Connection string of a MySQL or PostgreSQL server (scheme://user:password@host/database);
#                     without it, the template's defaults: host gluo-database (the compose service), user root
#                     (postgres for PostgreSQL), password mysqlp455w0rd, dev db localdev, test db localtest.
#                     --mysql-uri is the same option, kept for existing calls
#   --install-examples Install example code (Y or n, default: Y)
#   --install-frontend Install the frontend (Y or n, default: Y)
#   --version         Composer version constraint (default: ^7.0)
#   --php-version     PHP version for Docker (8.3, 8.4, 8.5, 8.6, default: current PHP version)
#   --timezone        Server timezone (default: UTC)
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
byjg-gluo.sh <folder> --namespace=<name> --name=<name/name> [options]

Creates a new Gluo project (composer create-project byjg/gluo) in unattended mode.
Gluo is the byjg production-ready PHP REST API starter; the framework core
(byjg/gluo-core) stays updatable in vendor/.

Required Arguments:
  <folder>                  Target folder name where the project will be created
  --namespace=<name>        Project namespace (CamelCase, e.g., MyApp, Tutorial)
  --name=<vendor/package>   Composer package name (e.g., mycompany/myapp)

Optional Arguments:
  --db=<mysql|postgres|sqlite>
                            Database (default: mysql). sqlite needs no server: the
                            databases are files under db/
  --db-uri=<uri>            Connection string of a MySQL or PostgreSQL server
                            (scheme://user:password@host/database). Without it, the
                            template's defaults: host gluo-database (the compose
                            service), user root (postgres for PostgreSQL), password
                            mysqlp455w0rd, databases localdev and localtest.
                            --mysql-uri is the same option, kept for existing calls
  --install-examples=<Y|n>  Install example code (default: Y)
  --install-frontend=<Y|n>  Install the frontend (default: Y)
  --version=<constraint>    Composer version constraint (default: ^7.0)
  --php-version=<version>   PHP version for Docker (8.3-8.6, default: current)
  --timezone=<tz>           Server timezone (default: UTC)
  --manifest                Print installation manifest and exit
  -h, --help                Show this help and exit

Examples:
  # Minimal installation
  load.sh byjg-gluo -- myproject --namespace=MyApp --name=mycompany/myapp

  # Full configuration
  load.sh byjg-gluo -- myproject --namespace=MyApp --name=mycompany/myapp \
    --db-uri=mysql://root:secret@db-server/mydb \
    --install-examples=n --install-frontend=n --version="^7.0" --php-version=8.4

  # A pure API on SQLite (no database server)
  load.sh byjg-gluo -- myproject --namespace=MyApp --name=mycompany/myapp \
    --db=sqlite --install-frontend=n

  # Show manifest
  load.sh byjg-gluo -- myproject --namespace=MyApp --name=mycompany/myapp --manifest

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
DB_URI=""
DB_URI_OPTION="--db-uri"   # the option it was given with, for the messages
DB=""
INSTALL_EXAMPLES="true"
INSTALL_FRONTEND="true"
VERSION="^7.0"
PHP_VERSION=""
TIMEZONE="UTC"
# The database: the schema always, the server only when --db-uri gives one (the template
# has the defaults of the server its docker compose runs)
DB_SCHEMA="mysql"
DB_HOST=""
DB_USER=""
DB_PASSWORD=""
DB_NAME_DEV=""
DB_NAME_TEST=""
SHOW_MANIFEST=0

# The schema as the template names it: mysql, postgres or sqlite; empty when unknown
normalize_schema() {
  case "${1,,}" in
    mysql) echo "mysql" ;;
    postgres|postgresql|pgsql) echo "postgres" ;;
    sqlite) echo "sqlite" ;;
    *) echo "" ;;
  esac
}

# Yes unless the value says no
is_yes() {
  case "$1" in
    n|N|no|No|NO|false) return 1 ;;
    *) return 0 ;;
  esac
}

parse_db_uri() {
  local uri="$1"
  local schema rest creds host_db user pass host db

  if [[ "${uri}" != *"://"* || "${uri}" != *@* || "${uri}" != */* ]]; then
    err "Invalid ${DB_URI_OPTION} format. Expected mysql://user:password@host/database"
    exit 2
  fi

  schema="${uri%%://*}"
  rest="${uri#*://}"
  creds="${rest%%@*}"
  host_db="${rest#*@}"
  host="${host_db%%/*}"
  db="${host_db#*/}"

  if [[ -z "${schema}" || -z "${creds}" || -z "${host}" || -z "${db}" ]]; then
    err "Invalid ${DB_URI_OPTION} format. Expected mysql://user:password@host/database"
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
    err "Invalid ${DB_URI_OPTION} format. Expected mysql://user:password@host/database"
    exit 2
  fi

  schema="$(normalize_schema "${schema}")"
  if [[ "${schema}" != "mysql" && "${schema}" != "postgres" ]]; then
    err "Invalid ${DB_URI_OPTION} scheme. Expected mysql:// or postgres:// (sqlite needs no server: use --db=sqlite)"
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
    --db=*)
      DB="${1#*=}"
      shift
      ;;
    --db-uri=*|--mysql-uri=*)
      DB_URI="${1#*=}"
      DB_URI_OPTION="${1%%=*}"
      shift
      ;;
    --install-examples=*)
      if is_yes "${1#*=}"; then INSTALL_EXAMPLES="true"; else INSTALL_EXAMPLES="false"; fi
      shift
      ;;
    --install-frontend=*)
      if is_yes "${1#*=}"; then INSTALL_FRONTEND="true"; else INSTALL_FRONTEND="false"; fi
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
    --git-name=*|--git-email=*)
      # Gluo 7 no longer creates a git repository: accepted so existing calls keep working
      log "Ignoring ${1%%=*}: the project is created without a git repository"
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

# Without a folder, the manifest of the script itself: it installs nothing on this
# machine, and a project is not something 'load.sh --upgrade' can install again
if [[ $SHOW_MANIFEST -eq 1 && -z "${FOLDER}" ]]; then
  printf 'BIN_FILES=\nFOLDERS=\nSHELLRC_FILE=\nUPGRADE=no\n'
  exit 0
fi

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

# The database: --db, and the server of --db-uri (its scheme must be the same database)
if [[ -n "${DB}" ]]; then
  DB_SCHEMA="$(normalize_schema "${DB}")"
  if [[ -z "${DB_SCHEMA}" ]]; then
    err "Invalid --db. Expected mysql, postgres or sqlite"
    exit 2
  fi
fi
if [[ -n "${DB_URI}" ]]; then
  if [[ "${DB_SCHEMA}" == "sqlite" ]]; then
    err "--db=sqlite needs no server: do not pass ${DB_URI_OPTION}"
    exit 2
  fi
  requested_schema="${DB_SCHEMA}"
  parse_db_uri "${DB_URI}"
  if [[ -n "${DB}" && "${DB_SCHEMA}" != "${requested_schema}" ]]; then
    err "--db=${requested_schema} does not match the scheme of ${DB_URI_OPTION} (${DB_SCHEMA})"
    exit 2
  fi
fi

# Validate PHP version if provided
if [[ -n "${PHP_VERSION}" ]]; then
  case "${PHP_VERSION}" in
    "8.3"|"8.4"|"8.5"|"8.6")
      ;;
    *)
      err "Invalid PHP version. Supported versions are: 8.3, 8.4, 8.5, 8.6"
      exit 2
      ;;
  esac
fi

# Check if composer is available
require_cmd composer

# Get current PHP version if not provided
if [[ -z "${PHP_VERSION}" ]]; then
  if command -v php >/dev/null 2>&1; then
    PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;')
    log "Detected PHP version: ${PHP_VERSION}"
  else
    PHP_VERSION="8.5"
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

# The server only when --db-uri gave one: otherwise the template's defaults apply
DB_SERVER_JSON=""
if [[ -n "${DB_HOST}" ]]; then
  DB_SERVER_JSON="  \"db_host\": \"${DB_HOST}\",
  \"db_user\": \"${DB_USER}\",
  \"db_password\": \"${DB_PASSWORD}\",
  \"db_name_dev\": \"${DB_NAME_DEV}\",
  \"db_name_test\": \"${DB_NAME_TEST}\",
"
fi

cat > "${SETUP_JSON}" <<EOF
{
  "php_version": "${PHP_VERSION}",
  "namespace": "${NAMESPACE}",
  "composer_name": "${COMPOSER_NAME}",
  "db_schema": "${DB_SCHEMA}",
${DB_SERVER_JSON}  "timezone": "${TIMEZONE}",
  "install_examples": ${INSTALL_EXAMPLES},
  "install_frontend": ${INSTALL_FRONTEND}
}
EOF

log "Setup configuration:"
cat "${SETUP_JSON}"

# Change to parent directory to run composer create-project
cd "${PARENT_DIR}"

# Run composer create-project
log "Running composer create-project in ${PARENT_DIR}..."
log "Command: composer -sdev create-project byjg/gluo ${FOLDER_NAME} ${VERSION}"

if ! composer -sdev create-project byjg/gluo "${FOLDER_NAME}" "${VERSION}"; then
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
log "  2. docker compose up -d"
log "  3. php gluo --env=dev migrate:reset"
if [[ "${INSTALL_EXAMPLES}" == "true" ]]; then
  log "  4. curl http://localhost:8080/sample/ping"
  log "  5. Visit http://localhost:8080/docs for API documentation"
else
  log "  4. Visit http://localhost:8080/docs for API documentation"
fi
log ""
log "Done."
