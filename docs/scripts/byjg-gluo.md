---
# Auto-generated from public/scripts/byjg-gluo.sh — Do not edit.
description: "Create a new Gluo project (composer create-project byjg/gluo) in unattended mode"
---

# byjg-gluo

Create a new Gluo project (composer create-project byjg/gluo) in unattended mode

```bash
load.sh byjg-gluo
```

## Usage

```text
byjg-gluo.sh <folder> --namespace=<name> --name=<name/name> [options]

Creates a new Gluo project (composer create-project byjg/gluo) in unattended mode.
Gluo is the byjg production-ready PHP REST API starter; the framework core
(byjg/gluo-core) stays updatable in vendor/.

Required Arguments:
  <folder>                  Target folder name where the project will be created
  --namespace=<name>        Project namespace (CamelCase, e.g., MyApp, Tutorial)
  --name=<vendor/package>   Composer package name (e.g., mycompany/myapp)

Optional Arguments:
  --mysql-uri=<uri>         MySQL connection string
                            (default values: schema=mysql, host=mysql-container,
                             user=root, password=mysqlp455w0rd, dev db=localdev, test db=localtest)
  --install-examples=<Y|n>  Install example code (default: Y)
  --version=<constraint>    Composer version constraint (default: ^7.0)
  --php-version=<version>   PHP version for Docker (8.3-8.6, default: current)
  --timezone=<tz>           Server timezone (default: UTC)
  --git-name=<name>         Git user name (default: from git config)
  --git-email=<email>       Git user email (default: from git config)
  --manifest                Print installation manifest and exit
  -h, --help                Show this help and exit

Examples:
  # Minimal installation
  load.sh byjg-gluo -- myproject --namespace=MyApp --name=mycompany/myapp

  # Full configuration
  load.sh byjg-gluo -- myproject --namespace=MyApp --name=mycompany/myapp \
    --mysql-uri=mysql://root:secret@mysql-container/mydb \
    --install-examples=n --version="^7.0" --php-version=8.4

  # Show manifest
  load.sh byjg-gluo -- myproject --namespace=MyApp --name=mycompany/myapp --manifest

```

[Script page](https://shellscript.download/scripts/byjg-gluo) · [Source](https://github.com/byjg/shellscript-download/blob/main/public/scripts/byjg-gluo.sh)
