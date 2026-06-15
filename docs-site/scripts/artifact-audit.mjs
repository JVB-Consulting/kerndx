// SPDX-License-Identifier: BUSL-1.1
// Post-build static audit of the generated site (.vitepress/dist). Catches classes of
// defect the VitePress strict build gate does not: in-page anchors that point at a
// heading id that does not exist on the target page, duplicate <meta name="description">
// tags (a search-engine hygiene defect at scale), and container/markup tokens leaking
// into rendered prose. Reads the built HTML only — no browser, no network. Exits non-zero
// on any failure so it can gate a release. Run after `npm run build`: `npm run test:artifact`.
import { readFile, readdir } from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const DIST = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../.vitepress/dist')

async function walk(dir) {
  const out = []
  for (const e of await readdir(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name)
    if (e.isDirectory()) { if (e.name === 'assets') continue; out.push(...await walk(p)) }
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

console.log(`artifact-audit: ${pages.length} pages, ${anchorChecked} in-page anchors checked, ${descGroups.size} distinct descriptions.`)
if (failures.length) {
  console.error(`\n✗ ${failures.length} failure(s):`)
  for (const f of failures) console.error('  ' + f)
  process.exit(1)
}
console.log('✓ anchors resolve, descriptions unique, no token leakage.')
