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

## Available scripts (high level)
The UI lists these and more, with descriptions:
- docker — Install the Docker Engine and Docker Compose on Linux
- php-docker — Create Docker-backed `php` and `composer` launchers
- node-docker — Create Docker-backed `node`, `npm`, `npx`, `yarn` launchers
- nvm — Install Node Version Manager (NVM) and set up shell init snippet
- load — Download and optionally run scripts from shellscript.download

Check the “All Scripts” table on the homepage for the current catalog.

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
