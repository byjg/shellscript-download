---
# Auto-generated from public/scripts/node-docker.sh — Do not edit.
description: "Create Docker-backed Node.js launchers (node, npm, npx, yarn)"
---

# node-docker

Create Docker-backed Node.js launchers (node, npm, npx, yarn)

```bash
load.sh node-docker
```

## Usage

```text
node-docker.sh <node_version> [--add package1,package2,...] [--volume /path1,/path2,...] [--env NAME1,NAME2,...] [--postinstall /path/to/script] [--no-postinstall] [--skip packages,postinstall] [--manifest]

Installs Docker-backed wrappers for Node.js tools (node, npm, npx, yarn)
under $HOME/.shellscript/bin using node:<version>-alpine Docker image.

Options:
  --add <packages>      Install additional Alpine packages (comma-separated list),
                        besides bash and git. Saved to
                        $HOME/.shellscript/node/packages.conf and re-applied on
                        every install/update.
                        Example: --add python3,make,g++
  --volume <paths>      Extra host directories to mount inside the container
                        (comma-separated list), next to the current directory, so
                        a dependency such as "file:../other-package" resolves.
                        Saved to $HOME/.shellscript/node/volumes.conf, which the
                        wrappers read at runtime, so you can also edit it directly.
                        Example: --volume /home/user/projects
  --env <names>         The wrappers forward the host environment to the container,
                        except the variables that describe the host itself (desktop
                        session, systemd, terminal and IDE, host toolchains such as
                        JAVA_HOME or NVM_*, SSH_* and agents). Use --env to forward
                        some of those anyway (comma-separated names or patterns).
                        Saved to $HOME/.shellscript/node/env.conf, which the wrappers
                        read at runtime, so you can also edit it directly.
                        Example: --env JAVA_HOME,XDG_RUNTIME_DIR
  --postinstall <script>
                        Script to run as root inside the image after the packages
                        are installed, for what apk cannot do. Copied to
                        $HOME/.shellscript/node/<version>/postinstall.sh so it
                        belongs to that Node version only and runs again on every
                        install/update of it. The script receives NODE_VERSION.
                        A line "# ENV NAME=value" in the script sets that environment
                        variable in the image.
                        Example: --postinstall ./install-tools.sh
  --no-postinstall      Delete the saved post-install script of this Node version.
  --skip <steps>        Leave out steps for this run only, without changing what
                        is saved (comma-separated list): "packages" (the Alpine
                        packages) and/or "postinstall" (the post-install script).
                        Example: --skip postinstall
  --manifest            Print installation manifest and exit. Without a version it
                        covers every installed version and the saved configuration,
                        which is what "load.sh remove -- node-docker" uses.

Examples:
  load.sh node-docker -- 22
  load.sh node-docker -- 20
  load.sh node-docker -- 22 --add python3,make,g++
  load.sh node-docker -- 22 --volume /home/user/projects
  load.sh node-docker -- 22 --manifest

```

[Script page](https://shellscript.download/scripts/node-docker) · [Source](https://github.com/byjg/shellscript-download/blob/main/public/scripts/node-docker.sh)
