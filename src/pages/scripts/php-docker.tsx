// ------------------------------------------------------------------------------------
// Auto-generated from public/scripts/php-docker.sh — Do not edit.
// ------------------------------------------------------------------------------------

import { Link } from "react-router-dom";
import { InstallCommand } from "@/components/InstallCommand.tsx";
import { Terminal } from "lucide-react";

export default function Script_php_docker() {
  return (
    <div className="min-h-screen bg-[var(--gradient-hero)]">
      <div style={{maxWidth: 900, margin: "0 auto", padding: "2rem"}}>
        <header className="mb-4 text-center">
          <div className="inline-flex items-center gap-3 rounded-full border border-border bg-card/50 px-6 py-2 backdrop-blur-sm">
            <Terminal className="h-5 w-5 text-accent" />
            <span className="font-mono text-sm font-medium text-foreground">shellscript.download</span>
          </div>
        </header>
        <Link to="/" className="text-accent hover:text-accent/80 transition-colors">← Home</Link>
        <h1 className="text-foreground" style={{fontSize: "1.5rem", margin: "1rem 0"}}>php-docker.sh</h1>
        <InstallCommand command="load.sh php-docker" spec={{"prefix":"load.sh php-docker","dashes":true,"items":[{"kind":"arg","name":"php_version","required":true,"description":""},{"kind":"option","name":"--add","value":"packages","equals":false,"required":false,"description":"Install additional Alpine packages (comma-separated list)."},{"kind":"option","name":"--volume","value":"paths","equals":false,"required":false,"description":"Extra host directories to mount inside the container as"},{"kind":"option","name":"--env","value":"names","equals":false,"required":false,"description":"The wrappers forward the host environment to the container,"},{"kind":"option","name":"--postinstall","value":"script","equals":false,"required":false,"description":"Script to run as root inside the image after the packages"},{"kind":"option","name":"--no-postinstall","value":null,"equals":false,"required":false,"description":"Delete the saved post-install script of this PHP version."},{"kind":"option","name":"--skip","value":"steps","equals":false,"required":false,"description":"Leave out steps for this run only, without changing what"},{"kind":"option","name":"--manifest","value":null,"equals":false,"required":false,"description":"Print installation manifest and exit. Without a version it"}]}} />
        <pre style={{whiteSpace: 'pre-wrap', fontFamily: 'ui-monospace, monospace', background: '#0b1020', color: '#e5e7eb', padding: '1rem', borderRadius: '.5rem', marginTop: '1rem'}}>{`php-docker.sh <php_version> [--add package1,package2,...] [--volume /path1,/path2,...] [--env NAME1,NAME2,...] [--postinstall /path/to/script] [--no-postinstall] [--skip packages,postinstall] [--manifest]

Installs Docker-backed wrappers for php and composer under $HOME/.shellscript/bin
using the byjg/php:<version>-cli image.

Options:
  --add <packages>      Install additional Alpine packages (comma-separated list).
                        Saved to $HOME/.shellscript/php/packages.conf and 
                        re-applied on every install/update, with phpNN- prefixes 
                        rewritten to the target version (php83-gd becomes php86-gd
                        on 8.6).
                        Example: --add php83-gd,php83-intl,git,bash
  --volume <paths>      Extra host directories to mount inside the container as
                        <path>:<path> (comma-separated list). Saved to
                        $HOME/.shellscript/php/volumes.conf so they persist across
                        installs/updates. The wrappers read this file at runtime,
                        so you can also edit it directly without reinstalling.
                        Example: --volume /home/user/projects
  --env <names>         The wrappers forward the host environment to the container,
                        except the variables that describe the host itself (desktop
                        session, systemd, terminal and IDE, host toolchains such as
                        JAVA_HOME or NVM_*, SSH_* and agents). Use --env to forward
                        some of those anyway (comma-separated names or patterns).
                        Saved to $HOME/.shellscript/php/env.conf, which the wrappers
                        read at runtime, so you can also edit it directly.
                        Example: --env JAVA_HOME,XDG_RUNTIME_DIR
  --postinstall <script>
                        Script to run as root inside the image after the packages
                        are installed, for what apk cannot do (PECL builds, vendor
                        clients). Copied to $HOME/.shellscript/php/<version>/postinstall.sh
                        so it belongs to that PHP version only and runs again on
                        every install/update of it. Delete that file to remove it.
                        The script receives PHP_VERSION (8.5) and PHP_VARIANT (php85).
                        A line "# ENV NAME=value" in the script sets that environment
                        variable in the image.
                        Example: --postinstall ./install-oracle.sh
  --no-postinstall      Delete the saved post-install script of this PHP version.
  --skip <steps>        Leave out steps for this run only, without changing what
                        is saved (comma-separated list): "packages" (the Alpine
                        packages) and/or "postinstall" (the post-install script).
                        Example: --skip postinstall
  --manifest            Print installation manifest and exit. Without a version it
                        covers every installed version and the saved configuration,
                        which is what "load.sh remove -- php-docker" uses.

Examples:
  load.sh php-docker -- 8.3
  load.sh php-docker -- 7.4
  load.sh php-docker -- 8.3 --add php83-gd,php83-intl,git
  load.sh php-docker -- 8.3 --volume /home/user/projects
  load.sh php-docker -- 8.5 --postinstall ./install-oracle.sh
  load.sh php-docker -- 8.5 --volume /home/user/projects --skip postinstall
  load.sh php-docker -- 8.5 --no-postinstall
  load.sh php-docker -- 8.3 --manifest
`}</pre>
        <br/>
      </div>
    </div>
  );
}
