// Generates static HTML pages AND React component pages + routes from comment headers of scripts in public/scripts
// Runs automatically in npm prebuild
import { promises as fs } from 'fs'
import path from 'path'
import url from 'url'

const __dirname = path.dirname(url.fileURLToPath(import.meta.url))

async function readDirSafe(dir) {
  try {
    return await fs.readdir(dir, { withFileTypes: true })
  } catch (e) {
    return []
  }
}

async function ensureDir(dir) {
  await fs.mkdir(dir, { recursive: true })
}

function extractHeaderComments(content) {
  const lines = content.split(/\r?\n/)
  const result = []
  let started = false
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i]
    if (i === 0 && line.startsWith('#!')) {
      // shebang, ignore and continue
      continue
    }
    if (line.trim().startsWith('#')) {
      // collect consecutive comment lines only at the top
      const cleaned = line.replace(/^\s*#\s?/, '')
      result.push(cleaned)
      started = true
      continue
    }
    // stop when we leave the initial comment block (if it started)
    if (started) break
    // if not started yet and encounter blank line, keep skipping
    if (line.trim() === '') continue
    // non-comment content before any comments: stop
    break
  }
  // Trim trailing empty lines
  while (result.length && result[result.length - 1].trim() === '') result.pop()
  return result.join('\n')
}

function htmlEscape(s) {
  return s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
}

// function buildHtml({ title, bodyText }) {
//   const pre = `<pre style="white-space: pre-wrap; font-family: ui-monospace, monospace; background:#0b1020; color:#e5e7eb; padding:1rem; border-radius:.5rem;">${htmlEscape(bodyText)}</pre>`
//   return `<!doctype html>
// <html lang="en">
// <head>
//   <meta charset="utf-8" />
//   <meta name="viewport" content="width=device-width, initial-scale=1" />
//   <title>${title}</title>
//   <meta name="description" content="${htmlEscape(title)}" />
//   <style>
//     body{margin:0; padding:2rem; font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Ubuntu, Cantarell, Noto Sans, Helvetica Neue, Arial, \"Apple Color Emoji\", \"Segoe UI Emoji\"; background:#0a0a0a; color:#fafafa}
//     a{color:#60a5fa}
//     .container{max-width: 900px; margin: 0 auto}
//     h1{font-size: 1.5rem; margin: 0 0 1rem}
//   </style>
// </head>
// <body>
//   <div class="container">
//     <a href="/">← Home</a>
//     <h1>${title}</h1>
//     ${pre}
//   </div>
// </body>
// </html>`
// }

function makeComponentName(base) {
  const safe = base.replace(/[^a-zA-Z0-9_$]/g, '_')
  return `Script_${safe}`
}

function buildComponentTsx({ title, bodyText, base }) {
  const compName = makeComponentName(base)
  const escaped = bodyText || 'No header comments found.'
  return `// ------------------------------------------------------------------------------------
// Auto-generated from public/scripts/${base}.sh — Do not edit.
// ------------------------------------------------------------------------------------

import { Link } from "react-router-dom";
import { InstallCommand } from "@/components/InstallCommand.tsx";
import { Terminal } from "lucide-react";

export default function ${compName}() {
  return (
    <div style={{maxWidth: 900, margin: "0 auto", padding: "2rem"}}>
      <header className="mb-4 text-center">
        <div className="inline-flex items-center gap-3 rounded-full border border-border bg-card/50 px-6 py-2 backdrop-blur-sm">
          <Terminal className="h-5 w-5 text-accent" />
          <span className="font-mono text-sm font-medium text-foreground">shellscript.download</span>
        </div>
      </header>
      <Link to="/">← Home</Link>
      <h1 style={{fontSize: "1.5rem", margin: "0 0 1rem"}}>${title}</h1>
      <InstallCommand command="load.sh ${base}" />
      <pre style={{whiteSpace: 'pre-wrap', fontFamily: 'ui-monospace, monospace', background: '#0b1020', color: '#e5e7eb', padding: '1rem', borderRadius: '.5rem'}}>{` + "`" + escaped.replace(/`/g, '\\`') + "`" + `}</pre>
      <br/>
    </div>
  );
}
`
}

async function generate() {
  const repoRoot = path.resolve(__dirname, '..')
  const publicScriptsDir = path.join(repoRoot, 'public', 'scripts')
  const srcPagesDir = path.join(repoRoot, 'src', 'pages')
  const srcPagesScriptsDir = path.join(srcPagesDir, 'scripts')
  const srcGeneratedDir = path.join(repoRoot, 'src', 'generated')

  await ensureDir(srcPagesScriptsDir)
  await ensureDir(srcGeneratedDir)

  const entries = await readDirSafe(publicScriptsDir)
  const routeItems = [
    { base: `List`, importName: `List`, path: `/list`, source: "" },
  ]
  const listItems = []
  let count = 0
  for (const entry of entries) {
    if (!entry.isFile()) continue
    const ext = path.extname(entry.name).toLowerCase()
    // Limit to typical script extensions; include .sh by default
    if (!['.sh', '.bash', '.zsh'].includes(ext)) continue
    const filePath = path.join(publicScriptsDir, entry.name)
    const content = await fs.readFile(filePath, 'utf8')
    const header = extractHeaderComments(content)
    const base = path.basename(entry.name, ext)

    // 1) Write simple static HTML (kept for backward-compatibility)
    const title = `${entry.name}`
    // const html = buildHtml({ title, bodyText: header || 'No header comments found.' })
    // const outHtmlPath = path.join(publicScriptsDir, `${base}.html`)
    // await fs.writeFile(outHtmlPath, html, 'utf8')

    // 2) Write a React component page
    const componentTsx = buildComponentTsx({ title, bodyText: header, base })
    const outCompPath = path.join(srcPagesScriptsDir, `${base}.tsx`)
    await fs.writeFile(outCompPath, componentTsx, 'utf8')

    // 3) Collect route info
    routeItems.push({ base, importName: makeComponentName(base), path: `/scripts/${base}`, source: "/scripts" })

    // 4) Collect list info: first non-empty line of header, or fallback
    const firstLine = (header || '')
      .split(/\r?\n/)
      .map((s) => s.trim())
      .find((s) => s.length > 0) || `${base}.sh`
    listItems.push({ base, firstLine })

    count++
  }

  // Sort list items alphabetically by base
  listItems.sort((a, b) => a.base.localeCompare(b.base))

  // Generate routes file
  const imports = routeItems
    .map(({ base, importName , source}) => `import ${importName} from "../pages${source}/${base}";`)
    .join('\n')

  const routesArray = `export const scriptRoutes = [\n${routeItems
    .map(({ path: p, importName }) => `  { path: "${p}", element: <${importName} /> },`)
    .join('\n')}\n];\n`

  const routesFile = `// ------------------------------------------------------------------------------------
// Auto-generated — routes for /scripts/* pages derived from public/scripts/*.sh
// ------------------------------------------------------------------------------------

${imports}

${routesArray}
`
  await fs.writeFile(path.join(srcGeneratedDir, 'scriptRoutes.tsx'), routesFile, 'utf8')

  // Generate /list page component with search and table
  const listRows = JSON.stringify(listItems)
  const listComponent = `// ------------------------------------------------------------------------------------
// Auto-generated — /list page built from public/scripts headers. Do not edit.
// ------------------------------------------------------------------------------------

import { useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { Terminal } from "lucide-react";

export default function List() {
  const data = ${listRows} as { base: string; firstLine: string }[];
  const [q, setQ] = useState("");
  const filtered = useMemo(() => {
    const query = q.toLowerCase().trim();
    if (!query) return data;
    return data.filter((item) => {
      return (
        item.base.toLowerCase().includes(query) ||
        item.firstLine.toLowerCase().includes(query)
      );
    });
  }, [q, data]);

  return (
    <div style={{maxWidth: 900, margin: "0 auto", padding: "2rem"}}>
      <header className="mb-4 text-center">
        <div className="inline-flex items-center gap-3 rounded-full border border-border bg-card/50 px-6 py-2 backdrop-blur-sm">
          <Terminal className="h-5 w-5 text-accent" />
          <span className="font-mono text-sm font-medium text-foreground">shellscript.download</span>
        </div>
      </header>
      <Link to="/">← Home</Link>
      <h1 style={{fontSize: "1.5rem", margin: "0 0 1rem"}}>Available Scripts</h1>
      <div style={{margin: "0 0 1rem"}}>
        <input
          aria-label="Search scripts"
          placeholder="Search by script or description..."
          value={q}
          onChange={(e) => setQ(e.target.value)}
          style={{
            width: "100%",
            padding: ".5rem .75rem",
            borderRadius: ".375rem",
            border: "1px solid #334155",
            background: "#0b1020",
            color: "#e5e7eb",
            outline: "none"
          }}
        />
      </div>
      <div style={{overflowX: 'auto'}}>
        <table style={{width: '100%', borderCollapse: 'collapse'}}>
          <thead>
            <tr>
              <th style={{textAlign: 'left', padding: '.5rem', borderBottom: '1px solid #334155'}}>Script</th>
              <th style={{textAlign: 'left', padding: '.5rem', borderBottom: '1px solid #334155'}}>Description</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map(({ base, firstLine }) => (
              <tr key={base}>
                <td style={{verticalAlign: 'top', padding: '.5rem', borderBottom: '1px solid #1f2937'}}>
                  <Link to={"/scripts/" + base}>{base}.sh</Link>
                </td>
                <td style={{verticalAlign: 'top', padding: '.5rem', borderBottom: '1px solid #1f2937'}}>
                  {firstLine}
                </td>
              </tr>
            ))}
            {filtered.length === 0 && (
              <tr>
                <td colSpan={2} style={{padding: '.75rem', color: '#94a3b8'}}>No matches.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
`
  await fs.writeFile(path.join(srcPagesDir, 'List.tsx'), listComponent, 'utf8')

  return { count, routes: routeItems.length }
}

if (import.meta.url === url.pathToFileURL(process.argv[1]).href) {
  generate()
    .then(({ count, routes }) => {
      console.log(`[generate-script-pages] Generated ${count} HTML page(s) and ${routes} React route(s) from public/scripts/*`)
    })
    .catch((err) => {
      console.error('[generate-script-pages] Failed:', err)
      process.exit(1)
    })
}
