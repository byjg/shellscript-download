---
# Auto-generated from public/scripts/byjg-repo.sh — Do not edit.
description: "Add the ByJG package repository (APT or RPM) to install ByJG tools"
---

# byjg-repo

Add the ByJG package repository (APT or RPM) to install ByJG tools

```bash
load.sh byjg-repo
```

## Usage

```text
load.sh byjg-repo -- [options]

Adds the ByJG package repository to the system (uses sudo), with its signing key:
the APT one on Debian and Ubuntu, the RPM one on Fedora and RHEL. Its packages are
then installed and updated by the system package manager.
More: https://opensource.byjg.com/docs/packages

Options:
  -h, --help           Show this help and exit
  --install <package>  Also install a package of the repository (can be repeated)
  --list               List the packages of the repository and exit
  --dry-run            Print actions without executing them
  --manifest           Print installation manifest and exit

Examples:
  load.sh byjg-repo
  load.sh byjg-repo -- --list
  load.sh byjg-repo -- --install parolsh
  load.sh remove -- byjg-repo
```

[Script page](https://shellscript.download/scripts/byjg-repo) · [Source](https://github.com/byjg/shellscript-download/blob/main/public/scripts/byjg-repo.sh)
