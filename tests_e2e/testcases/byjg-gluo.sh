#!/usr/bin/env bash
# byjg-gluo.sh: create a Gluo project, with the composer of php-docker, and the
# arguments it refuses
# vm: yes
# needs: docker
source "$(dirname "${BASH_SOURCE[0]}")/../shared/lib.sh"

workdir="/tmp/e2e-gluo"
project="${workdir}/myproject"
mkdir -p "$workdir"
cd "$workdir"
required="--namespace=E2eApp --name=e2e/app"

step "byjg-gluo: the arguments it requires, and the ones it refuses"
assert_exit 2 "${LOADER} byjg-gluo"
assert_log "<folder> is required"
assert_exit 2 "${LOADER} byjg-gluo -- myproject --name=e2e/app"
assert_log "--namespace is required"
assert_exit 2 "${LOADER} byjg-gluo -- myproject --namespace=E2eApp"
assert_log "--name is required"
assert_exit 2 "${LOADER} byjg-gluo -- myproject --namespace=e2eapp --name=e2e/app"
assert_log "Namespace must be in CamelCase"
assert_exit 2 "${LOADER} byjg-gluo -- myproject --namespace=E2eApp --name=NotAPackage"
assert_log "vendor/package format"
assert_exit 2 "${LOADER} byjg-gluo -- myproject ${required} --php-version=7.4"
assert_log "Invalid PHP version"
assert_exit 2 "${LOADER} byjg-gluo -- myproject ${required} --mysql-uri=not-a-uri"
assert_log "Invalid --mysql-uri format"
assert_exit 2 "${LOADER} byjg-gluo -- myproject ${required} --no-such-option"
assert_exit 2 "${LOADER} byjg-gluo -- myproject another ${required}"

step "byjg-gluo: the database options it refuses"
assert_exit 2 "${LOADER} byjg-gluo -- myproject ${required} --db=oracle"
assert_log "Invalid --db"
assert_exit 2 "${LOADER} byjg-gluo -- myproject ${required} --db=sqlite --db-uri=mysql://u:p@h/d"
assert_log "--db=sqlite needs no server"
assert_exit 2 "${LOADER} byjg-gluo -- myproject ${required} --db=postgres --db-uri=mysql://u:p@h/d"
assert_log "does not match the scheme of --db-uri"
assert_exit 2 "${LOADER} byjg-gluo -- myproject ${required} --db-uri=sqlite://u@h/d"
assert_log "Invalid --db-uri scheme"

step "byjg-gluo: installs nothing on the machine: nothing to remove, nothing to upgrade"
assert_output "${LOADER} byjg-gluo -- --manifest 2>/dev/null" "UPGRADE=no"
load remove -- byjg-gluo
assert_log "Nothing to remove for byjg-gluo"
assert_exit 1 "${LOADER} --upgrade byjg-gluo"
assert_log "cannot be upgraded this way"

step "byjg-gluo: the manifest names the folder of the project"
assert_output "${LOADER} byjg-gluo -- myproject ${required} --manifest 2>/dev/null" "FOLDERS=${project}"

step "byjg-gluo: --git-name and --git-email are still accepted, and ignored"
assert_output "${LOADER} byjg-gluo -- myproject ${required} --git-name=E2E --git-email=e2e@example.com --manifest 2>/dev/null" "FOLDERS=${project}"

step "byjg-gluo: needs composer, and says so"
assert_exit 1 "${LOADER} byjg-gluo -- myproject ${required}"
assert_log "Required command 'composer' not found"
assert_missing "$project"
assert_missing "${workdir}/setup.json"

step "byjg-gluo: composer comes from php-docker"
load php-docker -- 8.4
assert_output "composer --version" "Composer version"

step "byjg-gluo: creates the project"
load byjg-gluo -- myproject ${required} --install-examples=n --php-version=8.4 \
  --mysql-uri=mysql://e2euser:e2epass@e2e-db/e2edb
assert_log "Project successfully created in: ${project}"
assert_exists "${project}/composer.json"
assert_exists "${project}/vendor/autoload.php"
assert_output "cat ${project}/composer.json" '"name": "e2e/app"'
# The files of the project itself, without what composer installed
own_files="find ${project} -path ${project}/vendor -prune -o -type f -print"
assert_output "${own_files} | xargs grep -l 'E2eApp' | sed -n 1p" "$project"
assert_output "${own_files} | xargs grep -h 'e2e-db' | sed -n 1p" "e2e-db"
# Gluo 7 does not create a git repository inside the project
assert_missing "${project}/.git"

step "byjg-gluo: the project has its compiled routes, the frontend by default, and the next steps"
assert_exists "${project}/generated/routes.php"
assert_exists "${project}/generated/openapi.php"
assert_exists "${project}/frontend"
assert_log "php gluo --env=dev migrate:reset"

step "byjg-gluo: a pure API on SQLite: no frontend, no database server"
api="${workdir}/apiproject"
load byjg-gluo -- apiproject ${required} --db=sqlite --install-frontend=n --install-examples=n --php-version=8.4
assert_log "Project successfully created in: ${api}"
assert_missing "${api}/frontend"
assert_output "grep '^DBDRIVER_CONNECTION=' ${api}/config/dev/credentials.env" "sqlite://"
assert_exists "${api}/generated/routes.php"

step "byjg-gluo: the answers file does not stay behind"
assert_missing "${workdir}/setup.json"

step "byjg-gluo: an existing folder is not overwritten"
assert_exit 3 "${LOADER} byjg-gluo -- myproject ${required}"
assert_log "already exists"
assert_exists "${project}/composer.json"

finish
