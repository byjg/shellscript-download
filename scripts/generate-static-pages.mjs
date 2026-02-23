// Generates static HTML pages for each route (for SEO and curl-friendly access)
import { promises as fs } from 'fs'
import path from 'path'
import url from 'url'

const __dirname = path.dirname(url.fileURLToPath(import.meta.url))

function extractHeaderComments(content) {
  const lines = content.split(/\r?\n/)
  const result = []
  let started = false
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i]
    if (i === 0 && line.startsWith('#!')) {
      continue
    }
    if (line.trim().startsWith('#')) {
      const cleaned = line.replace(/^\s*#\s?/, '')
      result.push(cleaned)
      started = true
      continue
    }
    if (started) break
    if (line.trim() === '') continue
    break
  }
  while (result.length && result[result.length - 1].trim() === '') result.pop()
  return result.join('\n')
}

function htmlEscape(s) {
  return s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;')
}

function buildStaticHtml({ title, description, bodyText, scriptName }) {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${htmlEscape(title)} - shellscript.download</title>
  <meta name="description" content="${htmlEscape(description)}">
  <meta property="og:title" content="${htmlEscape(title)} - shellscript.download">
  <meta property="og:description" content="${htmlEscape(description)}">
  <meta property="og:type" content="website">
  <link rel="canonical" href="https://shellscript.download/scripts/${htmlEscape(scriptName)}">
  <style>
    body {
      margin: 0;
      padding: 2rem;
      font-family: ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      background: linear-gradient(135deg, hsl(220 25% 6%), hsl(220 30% 10%), hsl(142 50% 15%));
      color: hsl(210 40% 98%);
      min-height: 100vh;
    }
    .container {
      max-width: 900px;
      margin: 0 auto;
    }
    .header {
      text-align: center;
      margin-bottom: 2rem;
    }
    .badge {
      display: inline-flex;
      align-items: center;
      gap: 0.75rem;
      padding: 0.5rem 1.5rem;
      border-radius: 9999px;
      border: 1px solid hsl(220 20% 18%);
      background: hsl(220 20% 10% / 0.5);
      backdrop-filter: blur(8px);
      font-family: ui-monospace, monospace;
      font-size: 0.875rem;
      margin-bottom: 1rem;
    }
    .terminal-icon {
      color: hsl(142 76% 36%);
    }
    a {
      color: hsl(142 76% 36%);
      text-decoration: none;
      transition: opacity 0.2s;
    }
    a:hover {
      opacity: 0.8;
    }
    h1 {
      font-size: 1.5rem;
      margin: 1rem 0;
      color: hsl(210 40% 98%);
    }
    .install-command {
      background: hsl(220 20% 10%);
      border: 1px solid hsl(220 20% 18%);
      border-radius: 0.5rem;
      padding: 1rem;
      margin: 1rem 0;
      font-family: ui-monospace, monospace;
      font-size: 0.875rem;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    pre {
      white-space: pre-wrap;
      font-family: ui-monospace, monospace;
      background: #0b1020;
      color: #e5e7eb;
      padding: 1rem;
      border-radius: 0.5rem;
      margin-top: 1rem;
      overflow-x: auto;
    }
    .back-link {
      display: inline-block;
      margin-bottom: 1rem;
    }
  </style>
</head>
<body>
  <div class="container">
    <header class="header">
      <div class="badge">
        <span class="terminal-icon">▶</span>
        <span>shellscript.download</span>
      </div>
    </header>
    <div style="background: hsl(142 76% 36% / 0.1); border: 1px solid hsl(142 76% 36% / 0.3); border-radius: 0.5rem; padding: 1rem; margin-bottom: 1.5rem; text-align: center;">
      <p style="margin: 0; color: hsl(210 40% 98%);">
        📱 For the full interactive experience, visit <a href="/" style="color: hsl(142 76% 36%); font-weight: 600;">shellscript.download</a>
      </p>
    </div>
    <a href="/" class="back-link">← Home</a>
    <h1>${htmlEscape(title)}</h1>
    <div class="install-command">
      <code>load.sh ${htmlEscape(scriptName)}</code>
    </div>
    <pre>${htmlEscape(bodyText)}</pre>
    <br>
    <p style="margin-top: 2rem; text-align: center;">
      <a href="/">Return to Home</a>
    </p>
  </div>
</body>
</html>`
}

async function generate() {
  const repoRoot = path.resolve(__dirname, '..')
  const publicScriptsDir = path.join(repoRoot, 'public', 'scripts')
  const distScriptsDir = path.join(repoRoot, 'dist', 'scripts')
  const distDir = path.join(repoRoot, 'dist')

  // Ensure dist/scripts exists
  await fs.mkdir(distScriptsDir, { recursive: true })

  // Read all script files
  const entries = await fs.readdir(publicScriptsDir, { withFileTypes: true })
  let count = 0
  const redirects = []
  const listItems = []

  for (const entry of entries) {
    if (!entry.isFile()) continue
    const ext = path.extname(entry.name).toLowerCase()
    if (!['.sh', '.bash', '.zsh'].includes(ext)) continue

    const filePath = path.join(publicScriptsDir, entry.name)
    const content = await fs.readFile(filePath, 'utf8')
    const header = extractHeaderComments(content)
    const base = path.basename(entry.name, ext)

    // Extract first line for description
    const firstLine = (header || '')
      .split(/\r?\n/)
      .map((s) => s.trim())
      .find((s) => s.length > 0) || `${base}.sh script`

    listItems.push({ name: base, description: firstLine })

    const title = `${entry.name}`
    const html = buildStaticHtml({
      title,
      description: firstLine,
      bodyText: header || 'No documentation available.',
      scriptName: base
    })

    // Save static HTML - crawlers will find these, and they're accessible at /scripts/docker.html
    const outHtmlPath = path.join(distScriptsDir, `${base}.html`)
    await fs.writeFile(outHtmlPath, html, 'utf8')

    count++
  }

  // Generate list.json
  listItems.sort((a, b) => a.name.localeCompare(b.name))
  await fs.writeFile(path.join(distDir, 'list.json'), JSON.stringify(listItems, null, 2) + '\n', 'utf8')

  // Generate sitemap.xml for SEO
  const sitemapUrls = []

  // Add home page
  sitemapUrls.push({
    loc: 'https://shellscript.download/',
    priority: '1.0',
    changefreq: 'weekly'
  })

  // Add all script pages
  for (const entry of entries) {
    if (!entry.isFile()) continue
    const ext = path.extname(entry.name).toLowerCase()
    if (!['.sh', '.bash', '.zsh'].includes(ext)) continue

    const base = path.basename(entry.name, ext)
    sitemapUrls.push({
      loc: `https://shellscript.download/scripts/${base}`,
      priority: '0.8',
      changefreq: 'monthly'
    })
  }

  const sitemap = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${sitemapUrls.map(({ loc, priority, changefreq }) => `  <url>
    <loc>${loc}</loc>
    <changefreq>${changefreq}</changefreq>
    <priority>${priority}</priority>
  </url>`).join('\n')}
</urlset>
`
  await fs.writeFile(path.join(distDir, 'sitemap.xml'), sitemap, 'utf8')

  // Note: We don't create a _redirects file here because:
  // 1. Cloudflare Pages automatically serves .html files for extensionless URLs
  //    (e.g., /scripts/docker will serve /scripts/docker.html)
  // 2. For missing routes, we rely on the 404.html redirect mechanism
  //    which is already set up to redirect to index.html for React Router

  return { count }
}

if (import.meta.url === url.pathToFileURL(process.argv[1]).href) {
  generate()
    .then(({ count }) => {
      console.log(`[generate-static-pages] Generated ${count} static HTML page(s) in dist/scripts/`)
    })
    .catch((err) => {
      console.error('[generate-static-pages] Failed:', err)
      process.exit(1)
    })
}
