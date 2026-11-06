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

```

[Script page](https://shellscript.download/scripts/byjg-gluo) · [Source](https://github.com/byjg/shellscript-download/blob/main/public/scripts/byjg-gluo.sh)
