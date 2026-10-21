---
sidebar_position: 3
description: "How what load.sh downloads is signed and checked, with which key, and what to do when a check fails"
---

# Signed downloads

Everything `load.sh` downloads from shellscript.download is signed, and the loader uses a file
only when its signature is the one of the ByJG key. A site that was changed by someone else, or
a file that changed on its way, is refused, and the loader keeps what it had.

## What is signed

Every file the loader downloads from the site, each with its signature next to it as
`<file>.sig`:

| File | Downloaded by |
|---|---|
| `scripts/<script>.sh` | `load.sh <script>`, `load.sh --update` |
| `scripts/lib/<file>.sh`, the code a script shares with others | `load.sh`, with the script that needs it |
| `scripts/load.sh`, the loader itself | the installer, `load.sh --update` |
| `install/load-completion.sh` | the installer, `load.sh --completion`, `load.sh --update` |
| `install/loader`, the installer | you, when you check it by hand (below) |

The signatures are detached GPG signatures. They are made when the site is deployed, and exist
only on the site: they are not in the git repository.

## The key

It is the key that also signs the [ByJG APT and RPM repositories](https://opensource.byjg.com/docs/opensource/guidelines/linux-packages):

- **ByJG Opensource &lt;info@byjg.com.br&gt;**
- Fingerprint `DB84 6CC3 C109 29D3 43B6 B6DC 4BCC 9780 596C 4BCF`
- Published at `https://opensource.byjg.com/byjg.gpg` (binary) and `byjg.asc` (armored)

The files come from shellscript.download, hosted on Cloudflare. The key comes from
opensource.byjg.com, hosted on GitHub, and is written inside `load.sh` itself. Whoever changes
the files on the site cannot change the key with them: what they put there would not be signed
by it.

## How the loader checks

`load.sh` downloads the file and its `.sig` next to where the file goes, under a temporary name,
and runs `gpgv` with the key written in `load.sh`:

- the signature is the one of the key: the file is moved into place;
- it is not, there is no `.sig`, or a download fails: the file is not used, and what was there
  before stays as it was.

The installer (`install/loader`) does the same for `load.sh` and its completion, with the key it
downloads from `https://opensource.byjg.com/byjg.gpg`. It checks that `gpgv` is there before it
changes anything on the machine.

Nothing is checked, and nothing is downloaded, for a script already in the cache
(`$HOME/.shellscript/downloads`), or with `--developer`, which runs a local folder.

### gpgv

Checking needs `gpgv`. Ubuntu and Debian have it, as apt uses it. Otherwise:

```bash
sudo dnf install gnupg2    # Fedora
sudo apk add gpgv          # Alpine
```

## The first install

The one-line install runs what the site serves:

```bash
/bin/bash -c "$(curl -fsSL https://shellscript.download/install/loader)"
```

The installer then checks what it downloads, but nothing checked the installer itself. To check
it first, with the key from opensource.byjg.com:

```bash
curl -fsSLO https://shellscript.download/install/loader
curl -fsSLO https://shellscript.download/install/loader.sig
curl -fsSL https://opensource.byjg.com/byjg.gpg -o byjg.gpg
gpgv --keyring ./byjg.gpg loader.sig loader && sh loader
```

From then on, every download is checked against the key written in `load.sh`.

Any file of the site can be checked the same way:

```bash
curl -fsSLO https://shellscript.download/scripts/jq.sh
curl -fsSLO https://shellscript.download/scripts/jq.sh.sig
gpgv --keyring ./byjg.gpg jq.sh.sig jq.sh
```

## When a check fails

| Message | What it means | What to do |
|---|---|---|
| `gpgv is needed to check the signature of what comes from shellscript.download` | `gpgv` is not installed | install it ([above](#gpgv)) |
| `<url> is not signed by the key of shellscript.download: not used` | the file is not the one that was signed: changed on the site or on its way | do not work around it: try again later, and if it stays, [open an issue](https://github.com/byjg/shellscript-download/issues) |
| `Failed to download <url>` | the file or its `.sig` could not be downloaded: no network, or no such script | check the name with `load.sh --list`, and the network |
| `Failed to download <url>, or it is not signed by https://opensource.byjg.com/byjg.gpg` | the installer could not download, or check, `load.sh` or its completion | as the two lines above |
| `lib/<file>.sh, which this script needs, is missing: run 'load.sh --update'` | the loader that downloaded the script is older than signed downloads | `load.sh --update`, which replaces the loader first |

In each case the loader stops with exit code 3, and what was installed before is left as it was.

## What is not signed

- `list.json`, the catalog that `load.sh --list` shows: it is only displayed.
- What the scripts download from the vendor of a tool (the `jq` binary, a JDK, Docker packages).
  That comes from the vendor, over HTTPS, and is not checked against this key.

## When the key changes

A loader knows the key written in it, and refuses what is signed by another one. After the key
is replaced, the site is signed with the new key, and an installed loader refuses its updates.
Install the loader again, with the one-line install (or checking it first, as above): the
installer takes the new key from opensource.byjg.com, and the new `load.sh` carries it.

## For contributors

- A script names the shared file it needs in its `SHARED_LIB` line, and `load.sh` downloads and
  checks it: see [Contributing](https://github.com/byjg/shellscript-download/blob/main/CONTRIBUTING.md#scripts-that-depend-on-another-file).
- Everything under `public/scripts/` and `public/install/` is signed by the deploy job
  (`scripts/sign-dist.sh`), which runs on `main` after the end-to-end tests. Nothing is signed by
  hand, and no `.sig` goes into the repository.
- The end-to-end test of the loader (`tests_e2e/testcases/load.sh`) serves a copy of the site
  signed by a key of the test, and checks what is refused: a file changed after it was signed, one
  with no signature, one signed by another key.
