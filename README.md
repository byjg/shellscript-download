# shellscript.download — Loader & Script Catalog

A small Vite + React site that lets users install a shell “loader” and browse/run curated scripts such as Docker, PHP Docker, Node.js-in-Docker, NVM, and more. The site exposes a single installation command that places a lightweight loader on the user’s machine; from there, users can fetch and run scripts by name.

Live concept in the UI:
- Copy the install command
- Run it once
- Use `load.sh <script>` to download and execute scripts on demand

## What’s inside
- Vite + React + TypeScript
- Tailwind CSS + shadcn-ui components
- React Router for pages
- Auto-generated “script pages” sourced from files in `public/scripts`

## TL;DR — Install the loader
Run this in a Linux shell:

```bash
/bin/bash -c "$(curl -fsSL https://shellscript.download/install/loader)"
```

Then use it like this:

```bash
# Downloads and runs the docker installer script
load.sh docker

# Other examples
load.sh php-docker
load.sh node-docker
load.sh nvm
```

How the loader works (behavior):
- If a script is missing locally at `$HOME/.shellscript/bin/<script>.sh` or `--update` is passed, it downloads from `https://shellscript.download/scripts/<script>.sh`.
- Saves to `$HOME/.shellscript/bin/<script>.sh`.
- Executes it unless `--dont-run` is given.
- Exits with the same status code as the script.

### Scripts that depend on another file

A script that defines a `postLoad()` function has it called by the loader once, right after the
script is downloaded or updated (`load.sh` runs `<script> --post-load`). It is the place to fetch
what the script depends on, such as a file it shares with other scripts. `php-docker` and
`node-docker` use it to download `lib/docker-wrapper.sh` next to themselves in
`$HOME/.shellscript/downloads`. The hook is not called when the cached copy of the script is used,
nor with `--developer`, where the shared file is read from the local folder.

## Available scripts (high level)
The UI lists these and more, with descriptions:
- docker — Install the Docker Engine and Docker Compose on Linux
- php-docker — Create Docker-backed `php` and `composer` launchers
- node-docker — Create Docker-backed `node`, `npm`, `npx`, `yarn` launchers
- nvm — Install Node Version Manager (NVM) and set up shell init snippet
- load — Download and optionally run scripts from shellscript.download

Check the “All Scripts” table on the homepage for the current catalog.

### php-docker: packages, volumes and a post-install script

`php-docker` builds a local `byjg/php:<version>-cli-load` image and remembers how to rebuild it:

```bash
# Alpine packages, saved to ~/.shellscript/php/packages.conf (shared by every PHP version)
load.sh php-docker -- 8.5 --add php85-gd,php85-intl

# Extra host directories to mount, saved to ~/.shellscript/php/volumes.conf
load.sh php-docker -- 8.5 --volume /home/user/projects

# A script for what apk cannot do (PECL builds, vendor clients)
load.sh php-docker -- 8.5 --postinstall ./install-oracle.sh
```

The post-install script is copied to `~/.shellscript/php/<version>/postinstall.sh`, so it belongs
to that PHP version only. It runs as root inside the image after the packages, on every install
or update of that version, and a failure aborts the install. Delete the file to remove it.
It receives `PHP_VERSION` (`8.5`) and `PHP_VARIANT` (`php85`), and a line `# ENV NAME=value` in
it sets that environment variable in the image.

Every run rebuilds the image, replaying the packages and the post-install script. To leave a step
out for one run, or to drop the saved script:

```bash
# Change a volume without recompiling what the post-install script builds
load.sh php-docker -- 8.5 --volume /home/user/other --skip postinstall

# Skip both steps: a plain byjg/php image
load.sh php-docker -- 8.5 --skip packages,postinstall

# Delete the saved post-install script of this version
load.sh php-docker -- 8.5 --no-postinstall
```

The `php` and `composer` wrappers forward your environment to the container, so
`MYSQL_HOST=db php script.php` works as it would without Docker. Variables that describe the host
are left out: the desktop session (`XDG_*`, `DISPLAY`, `GTK*`, `QT_*`, ...), systemd, the terminal
and IDE, host toolchains (`JAVA_HOME`, `NVM_*`, ...), `SSH_*` and agent variables. To forward one
of those anyway, list its name or a pattern in `~/.shellscript/php/env.conf`, one per line, or:

```bash
load.sh php-docker -- 8.5 --env 'JAVA_HOME,XDG_RUNTIME_DIR'
```

`node-docker` takes the same options (`--add`, `--volume`, `--env`, `--postinstall`,
`--no-postinstall`, `--skip`) and keeps its files under `~/.shellscript/node`:

```bash
load.sh node-docker -- 22 --add python3,make,g++ --volume /home/user/projects
```

Its wrappers (`node`, `npm`, `npx`, `yarn`) forward the environment with the same rule, so
`NODE_ENV=production node app.js` reaches Node, and `load.sh remove -- node-docker` works the same
way. All of this lives in one file both scripts share, `public/scripts/lib/docker-wrapper.sh`.

`load.sh remove -- php-docker` removes the wrappers of every installed PHP version. With `--purge`
it also removes `~/.shellscript/php`, which holds `packages.conf`, `volumes.conf` and the
post-install scripts. The `byjg/php:<version>-cli-load` Docker images are left in place.

## Local development
Prerequisites: Node.js 18+ and npm

```bash
# install deps
npm i

# start dev server
npm run dev

# typecheck/lint (optional)
npm run lint

# build for production
npm run build

# preview the production build locally
npm run preview
```

## How scripts and pages are generated
- Put raw shell scripts in `public/scripts/*.sh` (e.g., `docker.sh`, `php-docker.sh`).
- The first line of each script should be a concise description; it is surfaced in the UI list.
- A small generator (`scripts/generate-script-pages.mjs`) reads those files and auto-creates per-script React pages in `src/pages/scripts/` and the data for `src/components/List.tsx`.
- The generator runs automatically before build via `prebuild` (see `package.json`). You can run it manually with:

```bash
node scripts/generate-script-pages.mjs
```

After adding or editing scripts in `public/scripts`, run the generator (or just `npm run build`) to refresh the pages and list.

## Project structure (high level)
- public/scripts/ — source shell scripts served for download
- src/pages/Index.tsx — homepage with install command, featured scripts, and list
- src/pages/scripts/* — auto-generated detail pages per script
- src/components/List.tsx — auto-generated table of scripts
- scripts/generate-script-pages.mjs — page/list generator

## Deployment
This is a static site built by Vite; the `dist/` folder can be hosted on any static host (Cloudflare Pages, Netlify, Vercel, GitHub Pages, etc.).

Basic steps:
1) Build: `npm run build`
2) Deploy the contents of `dist/` to your static hosting provider.

A `wrangler.toml` is present for Cloudflare workflows if you choose that route.

## Contributing
- Keep script headers (first line) descriptive — the UI uses them.
- Update or add scripts under `public/scripts/` and regenerate pages.
- Keep changes minimal and focused; this repo aims to be simple and transparent.

## License
See the repository’s LICENSE file if present. If not specified, please consult the repository owner for licensing terms.
