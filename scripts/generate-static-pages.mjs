// Generates the HTML page of each script route (for SEO and readers without JavaScript): the
// built app with the script's title, description and documentation written in
import { promises as fs } from 'fs'
import path from 'path'
import url from 'url'
import { extractDescription, extractHeaderComments, extractPrintUsage } from './generate-script-pages.mjs'

const __dirname = path.dirname(url.fileURLToPath(import.meta.url))

function htmlEscape(s) {
  return s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;')
}

// replaceOnce <html> <pattern> <replacement>: the template must have the pattern, or the page
// would silently keep the home page's title and description
function replaceOnce(html, pattern, replacement) {
  if (!pattern.test(html)) throw new Error(`dist/index.html has no ${pattern}`)
  return html.replace(pattern, () => replacement)
}

// The page of a script is the app itself (dist/index.html, with its scripts and styles), so a
// direct visit to /scripts/<name> loads the same interactive page as navigating to it. Its
// title, description and text are written in, for crawlers and readers without JavaScript;
// React replaces the text in #root when it starts.
function buildStaticHtml(template, { title, description, bodyText, scriptName }) {
  const pageTitle = `${title} - shellscript.download`
  const pageUrl = `https://shellscript.download/scripts/${scriptName}`
  let html = template
  html = replaceOnce(html, /<title>[^<]*<\/title>/, `<title>${htmlEscape(pageTitle)}</title>`)
  html = replaceOnce(html, /<meta name="description" content="[^"]*"\s*\/?>/,
    `<meta name="description" content="${htmlEscape(description)}" />`)
  html = replaceOnce(html, /<meta property="og:title" content="[^"]*"\s*\/?>/,
    `<meta property="og:title" content="${htmlEscape(pageTitle)}" />`)
  html = replaceOnce(html, /<meta property="og:description" content="[^"]*"\s*\/?>/,
    `<meta property="og:description" content="${htmlEscape(description)}" />\n    <meta property="og:url" content="${pageUrl}" />\n    <link rel="canonical" href="${pageUrl}" />`)
  html = replaceOnce(html, /<div id="root"><\/div>/, `<div id="root">
      <main style="max-width: 56rem; margin: 0 auto; padding: 2rem 1rem;">
        <a href="/">← Home</a>
        <h1>${htmlEscape(title)}</h1>
        <pre><code>load.sh ${htmlEscape(scriptName)}</code></pre>
        <pre>${htmlEscape(bodyText)}</pre>
      </main>
    </div>`)
  return html
}

// buildBadgeSvg <command>: the badge a project puts in its README to say it installs with
// shellscript.download. The mark and the colors of the logo (public/logo.png) on the left, the
// command on the right. Monospace, as the logo, at 6.6px a character: textLength holds the
// text to that width in whatever monospace font the reader has. No ids (a clipPath): two
// badges inlined in one page would share them.
function buildBadgeSvg(command) {
  const charWidth = 6.6
  const brand = 'shellscript.download'
  const brandWidth = brand.length * charWidth
  const commandWidth = command.length * charWidth
  const left = 24 + brandWidth + 6
  const right = 7 + commandWidth + 7
  const width = left + right
  const label = `${brand}: ${command}`
  const text = (x, value, length) =>
    `<text x="${x}" y="14" textLength="${length.toFixed(1)}" lengthAdjust="spacingAndGlyphs">${htmlEscape(value)}</text>`
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${width.toFixed(1)}" height="20" role="img" aria-label="${htmlEscape(label)}">
  <title>${htmlEscape(label)}</title>
  <rect width="${width.toFixed(1)}" height="20" rx="3" fill="#16a249"/>
  <path d="M3 0H${left.toFixed(1)}V20H3A3 3 0 0 1 0 17V3A3 3 0 0 1 3 0Z" fill="#0f1318"/>
  <rect x="0.5" y="0.5" width="${(width - 1).toFixed(1)}" height="19" rx="2.5" fill="none" stroke="#3d444d"/>
  <path d="M7 6l4 4-4 4M13 14.5h5" fill="none" stroke="#16a249" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
  <g fill="#f8fafc" font-family="DejaVu Sans Mono,Menlo,Consolas,monospace" font-size="11">
    ${text(24, brand, brandWidth)}
    ${text(left + 7, command, commandWidth)}
  </g>
</svg>
`
}

async function generate() {
  const repoRoot = path.resolve(__dirname, '..')
  const publicScriptsDir = path.join(repoRoot, 'public', 'scripts')
  const distScriptsDir = path.join(repoRoot, 'dist', 'scripts')
  const distDir = path.join(repoRoot, 'dist')

  // Ensure dist/scripts exists
  await fs.mkdir(distScriptsDir, { recursive: true })

  // The badges: /badge.svg for the site, /badge/<script>.svg for a script
  const distBadgeDir = path.join(distDir, 'badge')
  await fs.mkdir(distBadgeDir, { recursive: true })
  await fs.writeFile(path.join(distDir, 'badge.svg'), buildBadgeSvg('load.sh'), 'utf8')

  // The built app: vite build has written it before this postbuild step runs
  const template = await fs.readFile(path.join(distDir, 'index.html'), 'utf8')

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

    const usage = extractPrintUsage(content)
    const title = `${entry.name}`
    const html = buildStaticHtml(template, {
      title,
      description: extractDescription(header || '', entry.name),
      // The same text the app shows: the script's --help, or its header comments
      bodyText: usage || header || 'No documentation available.',
      scriptName: base
    })

    // Cloudflare Pages serves /scripts/<name>.html for /scripts/<name>
    const outHtmlPath = path.join(distScriptsDir, `${base}.html`)
    await fs.writeFile(outHtmlPath, html, 'utf8')
    await fs.writeFile(path.join(distBadgeDir, `${base}.svg`), buildBadgeSvg(`load.sh ${base}`), 'utf8')

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
      console.log(`[generate-static-pages] Generated ${count} static HTML page(s) in dist/scripts/ and their badges in dist/badge/`)
    })
    .catch((err) => {
      console.error('[generate-static-pages] Failed:', err)
      process.exit(1)
    })
}
