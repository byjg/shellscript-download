#!/usr/bin/env bash
# sign-dist.sh: signs, in the build, every file the loader downloads from the site, before
# it is deployed. Run by the deploy job of .github/workflows/build.yml.
#
# Usage: GPG_PRIVATE_KEY=<key> scripts/sign-dist.sh [dist]
#
# GPG_PRIVATE_KEY is the key that also signs the APT and RPM repositories (add-pkg of
# byjg.github.io), base64 of the armored private key. Each file gets <file>.sig next to
# it, a detached signature. Each signature is then checked against the public key users
# trust, https://opensource.byjg.com/byjg.gpg: a secret that is not that key fails here,
# not on every machine that downloads.
#
# The signatures are in dist/ only, never in the repository.
set -euo pipefail

dist="${1:-dist}"
: "${GPG_PRIVATE_KEY:?GPG_PRIVATE_KEY is not set}"
[[ -f "${dist}/scripts/load.sh" ]] || { echo "Error: no ${dist}/scripts/load.sh: run 'npm run build' first" >&2; exit 1; }

# A keyring of its own, gone at the end: the key is never left on the machine
GNUPGHOME="$(mktemp -d)"
export GNUPGHOME
trap 'rm -rf "$GNUPGHOME"' EXIT

printf '%s' "$GPG_PRIVATE_KEY" | base64 -d | gpg --batch --quiet --import
curl -fsSL https://opensource.byjg.com/byjg.gpg -o "${GNUPGHOME}/published.gpg"

shopt -s nullglob
for file in "${dist}"/scripts/*.sh "${dist}"/scripts/lib/*.sh "${dist}/install/loader" "${dist}/install/load-completion.sh"; do
  gpg --batch --yes --quiet --detach-sign -o "${file}.sig" "$file"
  if ! gpgv --keyring "${GNUPGHOME}/published.gpg" "${file}.sig" "$file" 2>/dev/null; then
    echo "Error: the signature of ${file} does not match https://opensource.byjg.com/byjg.gpg" >&2
    exit 1
  fi
  echo "signed: ${file#"${dist}/"}"
done
