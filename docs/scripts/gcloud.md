---
# Auto-generated from public/scripts/gcloud.sh — Do not edit.
description: "Download and install the Google Cloud CLI (gcloud, gsutil, bq)"
---

# gcloud

Download and install the Google Cloud CLI (gcloud, gsutil, bq)

```bash
load.sh gcloud
```

## Usage

```text
load.sh gcloud -- [options]

Downloads the Google Cloud CLI for x86_64 and aarch64 Linux to
$HOME/.shellscript/gcloud and creates the 'gcloud', 'gsutil' and 'bq' commands.
Nothing needs root. Run it again to replace it with the latest version.

Options:
  -h, --help           Show this help and exit
  --version <version>  Version to install (default: latest), e.g. 540.0.0
  --dry-run            Print actions without executing them
  --manifest           Print installation manifest and exit

Examples:
  load.sh gcloud
  load.sh gcloud -- --version 540.0.0
  load.sh gcloud -- --dry-run
```

[Script page](https://shellscript.download/scripts/gcloud) · [Source](https://github.com/byjg/shellscript-download/blob/main/public/scripts/gcloud.sh)
