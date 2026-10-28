// SPDX-License-Identifier: BUSL-1.1
// Post-build static audit of the generated site (.vitepress/dist). Catches classes of
// defect the VitePress strict build gate does not: in-page anchors that point at a
// heading id that does not exist on the target page, duplicate <meta name="description">
// tags (a search-engine hygiene defect at scale), and container/markup tokens leaking
// into rendered prose. Reads the built HTML only — no browser, no network. Exits non-zero
// on any failure so it can gate a release. Run after `npm run build`: `npm run test:artifact`.
import { readFile, readdir, stat } from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const DIST = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../.vitepress/dist')

async function walk(dir) {
  const out = []
  for (const e of await readdir(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name)
    // Skip assets and frozen version subtrees (/1.x/): the site-wide duplicate-description
    // and cross-tree anchor checks are latest-only — a frozen page legitimately repeats its
    // latest counterpart's description.
    if (e.isDirectory()) { if (e.name === 'assets' || /^\d+\.\d+$/.test(e.name)) continue; out.push(...await walk(p)) }
    else if (e.name.endsWith('.html')) out.push(p)
  }
  return out
}

const attrContent = tag => (tag.match(/content=["']([^"']*)["']/i) || [])[1] ?? null

function visibleText(html) {
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
}

function slugFromFile(file) {
  const rel = path.relative(DIST, file).replace(/\\/g, '/').replace(/\.html$/, '')
  // a directory index resolves to the directory slug (cleanUrls)
  return rel.replace(/(^|\/)index$/, '') || ''
}

const files = (await walk(DIST)).sort()
const pages = []
for (const file of files) {
  const html = await readFile(file, 'utf8')
  const slug = slugFromFile(file)
  if (slug === '404') continue
  const descTag = (html.match(/<meta[^>]+name=["']description["'][^>]*>/i) || [])[0]
  const ids = new Set()
  for (const m of html.matchAll(/\sid=["']([^"']+)["']/g)) ids.add(m[1])
  pages.push({ slug, html, desc: descTag ? attrContent(descTag) : null, ids })
}
const bySlug = new Map(pages.map(p => [p.slug, p]))

const failures = []

// 1. In-page anchor integrity
let anchorChecked = 0
for (const p of pages) {
  for (const m of p.html.matchAll(/href=["'](\/[^"'#]*#[^"']+)["']/g)) {
    const href = m[1]
    const hashIdx = href.indexOf('#')
    const target = href.slice(0, hashIdx).replace(/\.html$/, '').replace(/\/$/, '')
    const frag = decodeURIComponent(href.slice(hashIdx + 1))
    const targetSlug = target.replace(/^\//, '')
    const tp = bySlug.get(targetSlug)
    if (!tp) continue
    anchorChecked++
    if (!tp.ids.has(frag)) failures.push(`ANCHOR  /${p.slug} → ${href} (no #${frag} on target)`)
  }
}

// 2. Duplicate meta descriptions (site-wide; reference pages especially)
const descGroups = new Map()
for (const p of pages) {
  const d = (p.desc || '').trim()
  if (!d) { failures.push(`DESC    /${p.slug || '(home)'} has no <meta name=description>`); continue }
  if (!descGroups.has(d)) descGroups.set(d, [])
  descGroups.get(d).push(p.slug || '(home)')
}
for (const [d, slugs] of descGroups) {
  if (slugs.length > 1) failures.push(`DUPDESC ${slugs.length} pages share "${d.slice(0, 60)}…": ${slugs.slice(0, 8).join(', ')}`)
}

// 3. Token leakage in rendered prose (container markers / object stringification).
// Note: literal {{ }} is intentional documentation (escaped to entities so Vue never
// interpolates it) — not a leak — so it is deliberately not checked here.
for (const p of pages) {
  const text = visibleText(p.html)
  if (/(^|\n)\s*:::/.test(text)) failures.push(`LEAK    /${p.slug || '(home)'}: raw ::: container marker`)
  if (text.includes('[object Object]')) failures.push(`LEAK    /${p.slug || '(home)'}: [object Object]`)
}

// 4. Preload budget. A page may only <link rel=modulepreload> the chunks it actually needs: the
// framework and theme chunks, plus its own .lean.js. Everything else reachable from the app's
// dynamic-import graph would otherwise be fetched and parsed on EVERY page — the corpus has one
// mermaid diagram in it, and was preloading two of mermaid's layout engines site-wide because the
// old deny-list matched chunk names that had since been renamed. An allow-list cannot fail that
// way: a chunk nobody listed is simply not preloaded, which costs a fetch, never correctness
// (modulepreload is a hint; the module still loads through the import graph when the entry runs).
// Aggregated by distinct href because a leak hits every page, and 326 identical lines is a wall.
const KEEP_PRELOAD = /\/assets\/(?:chunks\/(?:framework|theme)\.[^/"]+\.js|[^/"]+\.lean\.js)$/
const strayPreloads = new Map()
for (const p of pages) {
  for (const m of p.html.matchAll(/<link rel="modulepreload" href="([^"]+)"/g)) {
    if (KEEP_PRELOAD.test(m[1])) continue
    const key = m[1].replace(/\.[A-Za-z0-9_-]{8}\.js$/, '.<hash>.js')
    strayPreloads.set(key, (strayPreloads.get(key) ?? 0) + 1)
  }
}
for (const [href, count] of [...strayPreloads].sort((a, b) => b[1] - a[1])) {
  failures.push(`PRELOAD ${count} page(s) preload ${href} — not framework, theme, or the page's own chunk`)
}

// 5. Entry-chunk budget. app.*.js is fetched, parsed and compiled on every page, so anything welded
// into it is paid on all 326. It should carry the VitePress client runtime and this theme's own
// registrations, nothing more: heavy optional machinery belongs behind a dynamic import so only the
// pages that use it pay. The ceiling exists because a single static import in the wrong place is
// invisible in review and enormous on the wire — mermaid reached 638 KB here that way.
const ENTRY_CEILING_BYTES = 60 * 1024
const assetsDir = path.join(DIST, 'assets')
const entry = (await readdir(assetsDir)).find(f => /^app\.[A-Za-z0-9_-]+\.js$/.test(f))
if (!entry) {
  failures.push('ENTRY   no app.*.js found in dist/assets — has the build layout changed?')
} else {
  const bytes = (await stat(path.join(assetsDir, entry))).size
  if (bytes > ENTRY_CEILING_BYTES) {
    failures.push(`ENTRY   ${entry} is ${Math.round(bytes / 1024)} KB raw, over the ${ENTRY_CEILING_BYTES / 1024} KB budget — something heavy is statically imported into the client entry`)
  }
}

// 6. Sized images. Every <img> in page HTML must declare width and height so the browser reserves
// its box before the bytes arrive: without them a lazy-loaded screenshot renders as a 2 px placeholder
// until it loads, the layout jumps when it does, and a below-the-fold still cannot be sized for the
// LCP calculation. Lighthouse reports this as unsized-images; the tour page's screenshots tripped it.
let imgChecked = 0
for (const p of pages) {
  for (const m of p.html.matchAll(/<img\b[^>]*>/g)) {
    imgChecked++
    const tag = m[0]
    if (!/\swidth="\d+"/.test(tag) || !/\sheight="\d+"/.test(tag)) {
      const src = (tag.match(/\ssrc="([^"]*)"/) || [])[1] || '(no src)'
      failures.push(`UNSIZED /${p.slug || '(home)'}: <img src="${src}"> lacks width/height attributes`)
    }
  }
}

// 7. Local-search index budget. The search box downloads @localSearchIndexroot.*.js the first time
// a reader uses it, so every page's indexed text is paid on that first search. The corpus is the
// generated API reference pages (268 under src/reference on 2026-08-30) plus the guides. With the
// reference pages indexed in full the chunk was 3.4 MB raw; config.mjs's search._render strips
// fenced code from every page and indexes only the text above a reference page's first member
// section, which brought it to 2.4 MB raw (0.56 MB compressed) on 2026-08-30. What remains is the
// guides' own prose, spread evenly over them, so a smaller index would mean dropping guides from
// search. The ceiling sits ~18% above the measured level: room for new guide pages, and a hard stop
// for the regressions that matter (the reference pages indexed in full again is +1 MB; a bulk page
// dumped into docs/ shows the same way). Ordinary guide and release-note growth reached 2,823 KB on
// 2026-10-06, past the first ceiling (2,816 KB); the ceiling was re-set to ~18% above that and still
// fails the +1 MB regression.
const SEARCH_INDEX_CEILING_BYTES = 3328 * 1024
const chunksDir = path.join(assetsDir, 'chunks')
const searchIndex = (await readdir(chunksDir)).find(f => /^@localSearchIndexroot\.[A-Za-z0-9_-]+\.js$/.test(f))
let searchIndexBytes = null
if (!searchIndex) {
  failures.push('SEARCH  no @localSearchIndexroot.*.js found in dist/assets/chunks — has the local search provider or the build layout changed?')
} else {
  searchIndexBytes = (await stat(path.join(chunksDir, searchIndex))).size
  if (searchIndexBytes > SEARCH_INDEX_CEILING_BYTES) {
    failures.push(`SEARCH  ${searchIndex} is ${Math.round(searchIndexBytes / 1024)} KB raw, over the ${SEARCH_INDEX_CEILING_BYTES / 1024} KB budget — index less text per page in config.mjs search._render`)
  }
}

console.log(`artifact-audit: ${pages.length} pages, ${anchorChecked} in-page anchors checked, ${descGroups.size} distinct descriptions, ${strayPreloads.size} stray preload target(s), ${imgChecked} <img> sized, entry ${entry ? Math.round((await stat(path.join(assetsDir, entry))).size / 1024) + ' KB' : 'missing'}, search index ${searchIndexBytes === null ? 'missing' : Math.round(searchIndexBytes / 1024) + ' KB'}.`)
if (failures.length) {
  console.error(`\n✗ ${failures.length} failure(s):`)
  for (const f of failures) console.error('  ' + f)
  process.exit(1)
}
console.log('✓ anchors resolve, descriptions unique, no token leakage.')
