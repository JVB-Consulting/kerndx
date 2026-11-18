// SPDX-License-Identifier: Apache-2.0
// Post-build static audit of the generated site (.vitepress/dist). Catches classes of
// defect the VitePress strict build gate does not: in-page anchors that point at a
// heading id that does not exist on the target page, duplicate <meta name="description">
// tags (a search-engine hygiene defect at scale), container/markup tokens leaking
// into rendered prose, and page-weight budgets (preloads, entry chunk, images, search index,
// sidebar items, inline site data). Reads the built HTML only — no browser, no network. Exits
// non-zero on any failure so it can gate a release. Run after `npm run build`: `npm run test:artifact`.
// The site-data check is exported so its unit tests can run it without a build.
import { realpathSync } from 'node:fs'
import { readFile, readdir, stat } from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { searchTermsOf } from './search-render.mjs'

const DIST = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../.vitepress/dist')

// 9. Inline site data budget. VitePress writes the whole site data (the top menu, the sidebar
// menus and the rest of the theme settings) into a script on every page, as
// window.__VP_SITE_DATA__=JSON.parse("…"). Every page downloads and parses it before it can show
// anything, so it is paid on all of them. It measured 31 KB on 2026-10-31, 27 KB of it the single
// sidebar. The area menus are written once each (scripts/generate-nav.mjs, generateSidebarAreas)
// and "Reference for this page" lives in each guide's own page data, which keeps it under this
// ceiling. Do not raise it: a list repeated per page key, or per-page data moved into the sidebar,
// is what it is there to catch.
export const SITE_DATA_CEILING_BYTES = 35 * 1024

// The bytes of a page's inline site data, as written in its HTML (the quoted JSON.parse argument),
// or null when the page has none. When the config holds functions (the search options do),
// VitePress wraps the parse as deserializeFunctions(JSON.parse("…")) and the functions' source is
// inside the quoted text, so it is counted too.
export function siteDataBytes(html) {
  const m = html.match(/window\.__VP_SITE_DATA__=(?:\w+\()?JSON\.parse\(("(?:[^"\\]|\\.)*")\)/)
  return m ? Buffer.byteLength(m[1], 'utf8') : null
}

// Checks every page's inline site data against the ceiling. Returns the failures and the largest
// and median sizes seen, for the summary line.
export function checkSiteData(pages) {
  const failures = []
  const sizes = []
  for (const p of pages) {
    const bytes = siteDataBytes(p.html)
    if (bytes === null) {
      failures.push(`SITEDATA /${p.slug || '(home)'} has no inline window.__VP_SITE_DATA__ — has the build layout changed?`)
      continue
    }
    sizes.push(bytes)
    if (bytes > SITE_DATA_CEILING_BYTES) {
      failures.push(`SITEDATA /${p.slug || '(home)'} inlines ${(bytes / 1024).toFixed(1)} KB of site data, over the ${SITE_DATA_CEILING_BYTES / 1024} KB budget — is a sidebar menu repeated per key, or page data in the sidebar?`)
    }
  }
  sizes.sort((a, b) => a - b)
  const median = sizes.length ? sizes[Math.floor((sizes.length - 1) / 2)] : 0
  return { failures, maximum: sizes.length ? sizes[sizes.length - 1] : 0, median }
}

// 10. The menus are in the server-rendered pages. The latest tree's area menus reach VitePress only
// because the theme expands them while the app starts (theme/index.mjs explains how). If that ever
// stops working the pages build and pass every check above, with no menu at all, so this checks
// three pages: a guide shows the Guides menu and not the API tree, a reference page shows the API
// tree, and the newest older version still shows its single menu. `frozen` is null when the build
// has no older versions (a plain `npm run build`); that part is then skipped.
const SIDEBAR_PATTERN = /<aside class="VPSidebar"[\s\S]*?<\/aside>/
export const SIDEBAR_CHECK_PAGES = { guide: 'selectors-guide', reference: 'reference/apex/qry-builder' }

function sidebarMenu(html) {
  const aside = (html ?? '').match(SIDEBAR_PATTERN)?.[0] ?? ''
  return {
    groups: [...aside.matchAll(/<h2 class="text"[^>]*>([^<]*)<\/h2>/g)].map(m => m[1].trim()),
    links: [...aside.matchAll(/\shref="([^"]*)"/g)].map(m => m[1])
  }
}

const hasLink = (menu, ending) => menu.links.some(link => link.endsWith(ending))

// Returns one failure line for each page that does not show the menu it should.
export function checkSidebarMenus({ guide, reference, frozen, frozenLine }) {
  const failures = []
  const guideMenu = sidebarMenu(guide)
  if (!guideMenu.groups.includes('Guides') || guideMenu.groups.includes('API Reference') || !hasLink(guideMenu, '/dml-guide')) {
    failures.push(`MENU    /${SIDEBAR_CHECK_PAGES.guide} should show the Guides menu (with /dml-guide) and not the API tree; it shows [${guideMenu.groups.join(', ')}]. Is theme/index.mjs still expanding sidebarAreas?`)
  }
  const referenceMenu = sidebarMenu(reference)
  if (!referenceMenu.groups.includes('API Reference') || !hasLink(referenceMenu, '/reference/apex')) {
    failures.push(`MENU    /${SIDEBAR_CHECK_PAGES.reference} should show the API tree (with /reference/apex); it shows [${referenceMenu.groups.join(', ')}]. Is theme/index.mjs still expanding sidebarAreas?`)
  }
  if (frozen !== null && frozen !== undefined) {
    const frozenMenu = sidebarMenu(frozen)
    if (!frozenMenu.groups.includes('Getting Started') || !frozenMenu.groups.includes('API Reference') || !hasLink(frozenMenu, `/${frozenLine}/dml-guide`)) {
      failures.push(`MENU    /${frozenLine}/${SIDEBAR_CHECK_PAGES.guide} should show its single menu (Getting Started to API Reference, with /${frozenLine}/dml-guide); it shows [${frozenMenu.groups.join(', ')}]`)
    }
  }
  return failures
}

async function readIfPresent(file) {
  return readFile(file, 'utf8').catch(() => null)
}

async function walk(dir) {
  const out = []
  for (const e of await readdir(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name)
    // Skip assets and frozen version subtrees (/1.x/): the site-wide duplicate-description
    // and cross-tree anchor checks are latest-only — a frozen page legitimately repeats its
    // latest counterpart's description. The per-page budgets are latest-only with them.
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

async function main() {
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
  // fails the +1 MB regression. On 2026-10-31 the reference pages began to index every member heading
  // (so a method name finds its section), which measured 3,458 KB; the ceiling was re-set to ~18%
  // above that, and the reference pages indexed in full (+1 MB) still fail it.
  const SEARCH_INDEX_CEILING_BYTES = 4096 * 1024
  const chunksDir = path.join(assetsDir, 'chunks')
  const searchIndex = (await readdir(chunksDir)).find(f => /^@localSearchIndexroot\.[A-Za-z0-9_-]+\.js$/.test(f))
  let searchIndexBytes = null
  if (!searchIndex) {
    failures.push('SEARCH  no @localSearchIndexroot.*.js found in dist/assets/chunks — has the local search provider or the build layout changed?')
  } else {
    searchIndexBytes = (await stat(path.join(chunksDir, searchIndex))).size
    if (searchIndexBytes > SEARCH_INDEX_CEILING_BYTES) {
      failures.push(`SEARCH  ${searchIndex} is ${Math.round(searchIndexBytes / 1024)} KB raw, over the ${SEARCH_INDEX_CEILING_BYTES / 1024} KB budget — index less text per page in scripts/search-render.mjs`)
    }
  }
  // The extra search words the pages give their sections (searchTerms frontmatter), counted from the
  // prepared pages the build indexed. They are in the index above, so the ceiling covers them; the
  // count is printed so their growth is visible.
  const searchTermCount = await countSearchTerms(path.join(DIST, '..', '..', 'src'))

  // 8. Sidebar budget. Every sidebar item is a Vue component that every page must hydrate, so the count
  // decides how long a phone's main thread is blocked. theme/overrides/VPSidebarItem.vue renders only
  // the items of open groups: 71 on 2026-10-31, against 361 when collapsed groups rendered too, which
  // blocked the main thread for 550 ms and failed Total Blocking Time. Since each area has its own
  // menu and the group holding the current page is open in the server-rendered HTML too, the largest
  // page renders 69 (a reference page in the largest API group, measured 2026-10-31). The ceiling is
  // about twice that: it leaves room for new pages in an area and still fails if a page renders
  // another area's menu, or the children of a collapsed group, again. It counts the server-rendered
  // HTML, which is what the browser hydrates first.
  const SIDEBAR_ITEM_CEILING = 138
  let sidebarItemsMaximum = 0
  for (const p of pages) {
    const count = (p.html.match(/class="VPSidebarItem\b/g) || []).length
    sidebarItemsMaximum = Math.max(sidebarItemsMaximum, count)
    if (count > SIDEBAR_ITEM_CEILING) failures.push(`SIDEBAR /${p.slug || '(home)'} renders ${count} sidebar items, over the ${SIDEBAR_ITEM_CEILING} budget — are collapsed groups rendering their children?`)
  }

  // 9. Inline site data budget: see SITE_DATA_CEILING_BYTES above.
  const siteData = checkSiteData(pages)
  failures.push(...siteData.failures)

  // 10. The menus are in the server-rendered pages: see checkSidebarMenus above.
  const frozenLine = (await readdir(DIST).catch(() => []))
    .filter(name => /^\d+\.\d+$/.test(name))
    .sort((a, b) => a.localeCompare(b, undefined, { numeric: true }))
    .at(-1)
  const menuFailures = checkSidebarMenus({
    guide: bySlug.get(SIDEBAR_CHECK_PAGES.guide)?.html ?? null,
    reference: bySlug.get(SIDEBAR_CHECK_PAGES.reference)?.html ?? null,
    frozen: frozenLine ? await readIfPresent(path.join(DIST, frozenLine, `${SIDEBAR_CHECK_PAGES.guide}.html`)) ?? '' : null,
    frozenLine
  })
  failures.push(...menuFailures)
  const menuSummary = `menus present on /${SIDEBAR_CHECK_PAGES.guide} and /${SIDEBAR_CHECK_PAGES.reference}${frozenLine ? ` and /${frozenLine}/${SIDEBAR_CHECK_PAGES.guide}` : ' (no older version built, so none checked)'}`

  console.log(`artifact-audit: ${pages.length} pages, ${anchorChecked} in-page anchors checked, ${descGroups.size} distinct descriptions, ${strayPreloads.size} stray preload target(s), ${imgChecked} <img> sized, entry ${entry ? Math.round((await stat(path.join(assetsDir, entry))).size / 1024) + ' KB' : 'missing'}, search index ${searchIndexBytes === null ? 'missing' : Math.round(searchIndexBytes / 1024) + ' KB'} (${searchTermCount} searchTerms words), at most ${sidebarItemsMaximum} sidebar items, inline site data at most ${(siteData.maximum / 1024).toFixed(1)} KB (median ${(siteData.median / 1024).toFixed(1)} KB), ${menuFailures.length ? 'menus MISSING' : menuSummary}.`)
  if (failures.length) {
    console.error(`\n✗ ${failures.length} failure(s):`)
    for (const f of failures) console.error('  ' + f)
    process.exit(1)
  }
  console.log('✓ anchors resolve, descriptions unique, no token leakage.')
}

// The number of searchTerms words on the prepared pages under `srcDir` (every .md file below it,
// except the Markdown copies under public/).
export async function countSearchTerms(srcDir) {
  const entries = await readdir(srcDir, { recursive: true, withFileTypes: true }).catch(() => [])
  let count = 0
  for (const entry of entries) {
    const dir = entry.parentPath ?? entry.path
    if (!entry.isFile() || !entry.name.endsWith('.md') || path.relative(srcDir, dir).split(path.sep)[0] === 'public') continue
    for (const words of searchTermsOf(await readFile(path.join(dir, entry.name), 'utf8')).values()) count += words.length
  }
  return count
}

// True when `scriptPath` (the path node was started with) is this module. Both sides are turned into
// real paths first: through a linked folder (on macOS /tmp is a link to /private/tmp) the two spellings
// differ, and a plain comparison would skip every check and still exit 0.
export function isRunAsScript(scriptPath, moduleUrl) {
  if (!scriptPath) return false
  try {
    return realpathSync(path.resolve(scriptPath)) === realpathSync(fileURLToPath(moduleUrl))
  } catch {
    return false
  }
}

// Run only as a script, not when imported by tests.
if (isRunAsScript(process.argv[1], import.meta.url)) {
  await main()
}
