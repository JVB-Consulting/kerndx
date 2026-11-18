// SPDX-License-Identifier: Apache-2.0
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync, readdirSync, mkdtempSync, symlinkSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { readonly } from 'vue'
import {
  groupForPage, generateSidebar, generateSidebars, generateSidebarAreas, expandSidebarAreas, sidebarForPath,
  areaForPage, referenceLinksFor, withExpandedSidebar, TOP_MENU, FROZEN_TOP_MENU, topMenuFor, activeMatchFor
} from './generate-nav.mjs'
import { buildSitePlan } from './prepare.mjs'
import { parseFrontmatter } from './frontmatter.mjs'
import { checkSiteData, SITE_DATA_CEILING_BYTES, checkSidebarMenus, isRunAsScript } from './artifact-audit.mjs'

const page = (relPath, slug, fm = {}) => ({ relPath, slug, frontmatter: fm, title: relPath.replace(/\.md$/, '') })
const DOCS = fileURLToPath(new URL('../../docs', import.meta.url))
const RELEASE_NOTES = fileURLToPath(new URL('../../release-notes', import.meta.url))

// A small site with one page of every kind, the way prepare.mjs hands pages over.
const SITE = [
  page('Installation.md', 'installation', { navOrder: 1 }),
  page('Strategic Guide - Glossary.md', 'strategic-guide-glossary', { navOrder: 60 }),
  page('Code Conventions - Guide.md', 'code-conventions-guide', { navOrder: 94 }),
  page('README.md', 'readme'),
  page('Strategic Guide - Overview.md', 'strategic-guide-overview', { navOrder: 10 }),
  page('Strategic Guide - Risks.md', 'strategic-guide-risks', { navOrder: 18 }),
  page('Fast Starts.md', 'fast-starts', { navOrder: 5 }),
  page('Fast Start - DML.md', 'fast-start-dml', { navOrder: 14 }),
  page('Selectors - Guide.md', 'selectors-guide', { navOrder: 12, navLabel: 'Selectors (queries and SOQL)' }),
  page('DML - Guide.md', 'dml-guide', { navOrder: 14, navLabel: 'DML (saving records)' }),
  page('Resilience - Guide.md', 'resilience-guide', { navOrder: 62 }),
  page('reference/index.md', 'reference', { title: 'API Reference' }),
  page('reference/apex/QRY_Builder.md', 'reference/apex/qry-builder', { type: 'class', title: 'QRY_Builder' }),
  page('release-notes/Release Notes - Kern 1.11.md', 'release-notes-kern-1-11', { title: 'Kern 1.11 Release Notes', group: 'Release Notes', order: -1011 })
]
const routeOf = p => '/' + (p.slug === '' ? 'index.md' : /(^|\/)index\.md$/i.test(p.relPath) ? `${p.slug}/index.md` : `${p.slug}.md`)
const sidebarOf = (sidebars, relPath) => sidebarForPath(sidebars, routeOf(SITE.find(p => p.relPath === relPath)))
const linksIn = items => JSON.stringify(items).match(/"link":"[^"]*"/g).map(s => s.slice(8, -1))

test('reference path wins over frontmatter group; apex pages group by prefix domain', () => {
  const g = groupForPage(page('reference/apex/UTIL_SObject.md', 'reference/apex/util-sobject', { group: 'Whatever' }))
  assert.deepEqual(g, { group: 'API Reference', subgroup: 'Utilities' })
})

test('apex class prefixes map to their domain folders', () => {
  assert.equal(groupForPage(page('reference/apex/SEL_Account.md', 'reference/apex/sel-account')).subgroup, 'Query & Selectors')
  assert.equal(groupForPage(page('reference/apex/QRY_Builder.md', 'reference/apex/qry-builder')).subgroup, 'Query & Selectors')
  assert.equal(groupForPage(page('reference/apex/TRG_Dispatcher.md', 'reference/apex/trg-dispatcher')).subgroup, 'Triggers')
  assert.equal(groupForPage(page('reference/apex/LOG_Logger.md', 'reference/apex/log-logger')).subgroup, 'Logging')
  assert.equal(groupForPage(page('reference/apex/IF_Thing.md', 'reference/apex/if-thing')).subgroup, 'Interfaces')
})

test('an apex class with an unknown prefix lands in Other', () => {
  assert.equal(groupForPage(page('reference/apex/ZZZ_Weird.md', 'reference/apex/zzz-weird')).subgroup, 'Other')
})

test('custom objects / events / metadata get their own domain folders', () => {
  assert.equal(groupForPage(page('reference/objects/Account.md', 'reference/objects/account')).subgroup, 'Custom Objects')
  assert.equal(groupForPage(page('reference/events/MyEvent.md', 'reference/events/myevent')).subgroup, 'Platform Events')
  assert.equal(groupForPage(page('reference/metadata/MyMdt.md', 'reference/metadata/mymdt')).subgroup, 'Custom Metadata Types')
})

test('frontmatter group is the escape hatch for non-reference pages', () => {
  const g = groupForPage(page('Whatever.md', 'whatever', { group: 'Operations' }))
  assert.deepEqual(g, { group: 'Operations', subgroup: null })
})

test('normalized prefix maps Fast Start variants to one group', () => {
  assert.equal(groupForPage(page('Fast Start - DML.md', 'fast-start-dml')).group, 'Fast Starts')
  assert.equal(groupForPage(page('Selectors - Guide.md', 'selectors-guide')).group, 'Guides')
  assert.equal(groupForPage(page('Strategic Guide - Overview.md', 'strategic-guide-overview')).group, 'Strategic Guides')
})

test('unrecognised file falls back to Getting Started', () => {
  assert.equal(groupForPage(page('Installation.md', 'installation')).group, 'Getting Started')
})

test('the bare reference landing page is a top-level API Reference item, not Getting Started', () => {
  // reference/index.md has no area segment; it must not leak into Getting Started.
  assert.deepEqual(groupForPage(page('reference/index.md', 'reference')), { group: 'API Reference', subgroup: null })
})

test('the apex landing is a top-level API Reference item (apex has no single folder)', () => {
  assert.deepEqual(groupForPage(page('reference/apex/index.md', 'reference/apex')), { group: 'API Reference', subgroup: null })
})

test('object/event/metadata area landings lead their own domain folder (no duplicate top-level link)', () => {
  assert.equal(groupForPage(page('reference/objects/index.md', 'reference/objects')).subgroup, 'Custom Objects')
  assert.equal(groupForPage(page('reference/events/index.md', 'reference/events')).subgroup, 'Platform Events')
  assert.equal(groupForPage(page('reference/metadata/index.md', 'reference/metadata')).subgroup, 'Custom Metadata Types')
})

test('an area landing leads its domain folder, above the record pages', () => {
  const sidebar = generateSidebar([
    page('reference/objects/ApiCall.md', 'reference/objects/apicall-c', { type: 'object' }),
    page('reference/objects/index.md', 'reference/objects', { title: 'Custom Objects' })
  ])
  const api = sidebar.find(s => s.text === 'API Reference')
  const objects = api.items.find(s => s.text === 'Custom Objects' && Array.isArray(s.items))
  assert.equal(objects.items[0].link, '/reference/objects')
})

test('section order: daily-driver first, Release Notes last', () => {
  const sidebar = generateSidebar([
    page('Installation.md', 'installation'),
    page('Release Notes - Kern 1.1.md', 'release-notes-kern-1-1', { group: 'Release Notes' }),
    page('Fast Start - DML.md', 'fast-start-dml')
  ])
  const names = sidebar.map(s => s.text)
  assert.equal(names[names.length - 1], 'Release Notes')
  assert.ok(names.indexOf('Getting Started') < names.indexOf('Fast Starts'))
})

test('domain folders follow the daily-driver order (Triggers before Utilities)', () => {
  const sidebar = generateSidebar([
    page('reference/apex/UTIL_A.md', 'reference/apex/util-a', { type: 'class' }),
    page('reference/apex/TRG_A.md', 'reference/apex/trg-a', { type: 'class' })
  ])
  const api = sidebar.find(s => s.text === 'API Reference')
  const folderNames = api.items.filter(i => i.items).map(i => i.text)
  assert.ok(folderNames.indexOf('Triggers') < folderNames.indexOf('Utilities'))
})

test('draft frontmatter excludes the page from the sidebar', () => {
  const sidebar = generateSidebar([
    page('Fast Start - DML.md', 'fast-start-dml'),
    page('Hidden.md', 'hidden', { draft: true })
  ])
  const flat = JSON.stringify(sidebar)
  assert.ok(flat.includes('/fast-start-dml'))
  assert.ok(!flat.includes('/hidden'))
})

test('API Reference apex ordering within a domain: classes then interfaces then enums, then alpha', () => {
  const sidebar = generateSidebar([
    page('reference/apex/UTIL_ZClass.md', 'reference/apex/util-zclass', { type: 'class' }),
    page('reference/apex/UTIL_AnEnum.md', 'reference/apex/util-anenum', { type: 'enum' }),
    page('reference/apex/UTIL_AnInterface.md', 'reference/apex/util-aninterface', { type: 'interface' }),
    page('reference/apex/UTIL_AClass.md', 'reference/apex/util-aclass', { type: 'class' })
  ])
  const api = sidebar.find(s => s.text === 'API Reference')
  const utils = api.items.find(s => s.text === 'Utilities')
  assert.deepEqual(utils.items.map(i => i.link), [
    '/reference/apex/util-aclass', '/reference/apex/util-zclass',  // classes, alpha
    '/reference/apex/util-aninterface',                            // interfaces
    '/reference/apex/util-anenum'                                  // enums
  ])
})

test('apex inner classes nest under their parent class, shown by their short name', () => {
  const sidebar = generateSidebar([
    page('reference/apex/UTIL_SObjectDescribe.md', 'reference/apex/util-sobjectdescribe', { type: 'class', title: 'UTIL_SObjectDescribe' }),
    page('reference/apex/UTIL_SObjectDescribe.FieldListBuilder.md', 'reference/apex/util-sobjectdescribe-fieldlistbuilder', { type: 'class', title: 'UTIL_SObjectDescribe.FieldListBuilder' }),
    page('reference/apex/UTIL_Plain.md', 'reference/apex/util-plain', { type: 'class', title: 'UTIL_Plain' })
  ])
  const utils = sidebar.find(s => s.text === 'API Reference').items.find(s => s.text === 'Utilities')
  // The inner class is not a flat sibling of its parent.
  assert.ok(!utils.items.map(i => i.link).includes('/reference/apex/util-sobjectdescribe-fieldlistbuilder'))
  // The parent is an expandable item with the inner class nested under it, by its short name.
  const parent = utils.items.find(i => i.link === '/reference/apex/util-sobjectdescribe')
  assert.ok(Array.isArray(parent.items), 'parent class has nested items')
  assert.deepEqual(parent.items, [{ text: 'FieldListBuilder', link: '/reference/apex/util-sobjectdescribe-fieldlistbuilder' }])
  // A class with no inner classes stays a plain link.
  const plain = utils.items.find(i => i.link === '/reference/apex/util-plain')
  assert.ok(plain && !plain.items, 'plain class is a leaf link')
})

test('an inner class whose parent class is undocumented stays a top-level sibling', () => {
  const sidebar = generateSidebar([
    page('reference/apex/UTIL_Orphan.Inner.md', 'reference/apex/util-orphan-inner', { type: 'class', title: 'UTIL_Orphan.Inner' })
  ])
  const utils = sidebar.find(s => s.text === 'API Reference').items.find(s => s.text === 'Utilities')
  assert.ok(utils.items.some(i => i.link === '/reference/apex/util-orphan-inner' && !i.items))
})

test('reference landing pages surface as top-level API Reference links, above the domain folders', () => {
  const sidebar = generateSidebar([
    page('reference/apex/UTIL_ZClass.md', 'reference/apex/util-zclass', { type: 'class' }),
    page('reference/apex/index.md', 'reference/apex', { title: 'Apex Classes' }),
    page('reference/index.md', 'reference', { title: 'API Reference' })
  ])
  const api = sidebar.find(s => s.text === 'API Reference')
  const topLinks = api.items.filter(i => i.link).map(i => i.link)
  assert.ok(topLinks.includes('/reference/apex'))
  assert.ok(topLinks.includes('/reference'))
  // The domain folder follows the top-level links.
  assert.ok(api.items.some(i => i.text === 'Utilities' && Array.isArray(i.items)))
})

// ── Areas: each part of the top menu has its own sidebar ──────────────────────

test('every page has an area', () => {
  const docs = readdirSync(DOCS).filter(f => f.endsWith('.md'))
  const notes = readdirSync(RELEASE_NOTES).filter(f => f.endsWith('.md')).map(f => `release-notes/${f}`)
  assert.ok(docs.length > 20, 'expected to find the docs pages')
  for (const relPath of [...docs, ...notes, 'AGENTS.md', 'reference/index.md', 'reference/apex/QRY_Builder.md']) {
    assert.doesNotThrow(() => areaForPage(page(relPath, 'x')), `Expected ${relPath} to belong to an area`)
  }
})

test('an unknown page throws', () => {
  assert.throws(() => areaForPage(page('Something New.md', 'something-new')), /Something New\.md/)
  assert.throws(() => generateSidebars([...SITE, page('Something New.md', 'something-new')]), /Something New\.md/)
})

test('the page that moves a reader from plain Apex to KernDX is in get-started', () => {
  // The page does not exist yet. A fake page object stands in for it.
  assert.equal(areaForPage(page('From Plain Apex to KernDX.md', 'from-plain-apex-to-kerndx')), 'get-started')
})

test('a frontmatter area places a page that matches no rule', () => {
  assert.equal(areaForPage(page('Something New.md', 'something-new', { area: 'guides' })), 'guides')
  assert.throws(() => areaForPage(page('Something New.md', 'something-new', { area: 'nowhere' })), /nowhere/)
})

test('strategic guides are in why', () => {
  assert.equal(areaForPage(page('Strategic Guide - Overview.md', 'strategic-guide-overview')), 'why')
  assert.equal(areaForPage(page('Strategic Guide - Risks.md', 'strategic-guide-risks')), 'why')
  const why = sidebarOf(generateSidebars(SITE), 'Strategic Guide - Risks.md')
  assert.deepEqual(linksIn(why), ['/strategic-guide-overview', '/strategic-guide-risks', '/'])
})

test('the home page shows the Why KernDX menu', () => {
  const sidebars = generateSidebars(SITE)
  assert.deepEqual(linksIn(sidebarForPath(sidebars, '/index.md')), ['/strategic-guide-overview', '/strategic-guide-risks', '/'])
})

test('release notes are in reference', () => {
  assert.equal(areaForPage(page('release-notes/Release Notes - Kern 1.11.md', 'release-notes-kern-1-11')), 'reference')
  const sidebar = sidebarOf(generateSidebars(SITE), 'release-notes/Release Notes - Kern 1.11.md')
  assert.deepEqual(sidebar.map(g => g.text), ['API Reference', 'Release Notes'])
})

test('Glossary and Conventions are in get-started', () => {
  assert.equal(areaForPage(page('Strategic Guide - Glossary.md', 'strategic-guide-glossary')), 'get-started')
  assert.equal(areaForPage(page('Code Conventions - Guide.md', 'code-conventions-guide')), 'get-started')
  const sidebar = sidebarOf(generateSidebars(SITE), 'Strategic Guide - Glossary.md')
  assert.deepEqual(linksIn(sidebar), ['/installation', '/strategic-guide-glossary', '/code-conventions-guide', '/readme'])
})

test('the Administration Tools guide is in guides', () => {
  // It is a developer guide, so it sits with the other guides, whatever its old menu group says.
  const adminTools = page('Administration Tools - Guide.md', 'administration-tools-guide', { group: 'Getting Started', navOrder: 3 })
  assert.equal(areaForPage(adminTools), 'guides')
  assert.ok(linksIn(sidebarOf(generateSidebars([...SITE, adminTools]), 'Selectors - Guide.md')).includes('/administration-tools-guide'))
})

test('the setup and agent pages stay in get-started', () => {
  for (const relPath of ['Set Up Your Computer.md', 'README.md', 'AGENTS.md', 'AI Agent Instructions.md']) {
    assert.equal(areaForPage(page(relPath, 'x')), 'get-started', relPath)
  }
})

// ── The theme expands the compact menus into the sidebar VitePress reads ─────

const compactSiteData = () => ({ title: 'KernDX', themeConfig: { nav: TOP_MENU, sidebarAreas: generateSidebarAreas(SITE) } })

test('the sidebar is expanded into a new copy, so read-only site data works', () => {
  // The dev server hands the theme site data wrapped by Vue's readonly(): a write to it is dropped.
  const given = readonly(compactSiteData())
  const expanded = withExpandedSidebar(given)
  assert.notEqual(expanded, given)
  assert.deepEqual(expanded.themeConfig.sidebar, generateSidebars(SITE))
  assert.equal(expanded.title, 'KernDX')
  assert.deepEqual(expanded.themeConfig.nav, TOP_MENU)
  assert.equal(given.themeConfig.sidebar, undefined)
})

test('expanding twice changes nothing', () => {
  const expanded = withExpandedSidebar(compactSiteData())
  assert.equal(withExpandedSidebar(expanded), expanded)
})

test('a frozen tree keeps its flat sidebar as it is', () => {
  const frozen = { themeConfig: { sidebar: generateSidebar(SITE) } }
  assert.equal(withExpandedSidebar(frozen), frozen)
})

test('a guide sidebar lists all guides', () => {
  const sidebars = generateSidebars(SITE)
  for (const relPath of ['Selectors - Guide.md', 'DML - Guide.md', 'Resilience - Guide.md']) {
    assert.deepEqual(linksIn(sidebarOf(sidebars, relPath)), ['/selectors-guide', '/dml-guide', '/resilience-guide'], relPath)
  }
})

test('every page gets the sidebar of its own area', () => {
  const sidebars = generateSidebars(SITE)
  const { menus } = generateSidebarAreas(SITE)
  for (const p of SITE) {
    assert.deepEqual(sidebarOf(sidebars, p.relPath), menus[areaForPage(p)], p.relPath)
  }
})

test('each area menu is written once, and the page paths only name the area', () => {
  const { menus, paths } = generateSidebarAreas(SITE)
  assert.deepEqual(Object.keys(menus).sort(), ['fast-starts', 'get-started', 'guides', 'reference', 'why'])
  assert.ok(Object.values(paths).every(area => typeof area === 'string' && menus[area]))
  // The API tree is large, so it must not be repeated once per path.
  assert.equal(JSON.stringify({ menus, paths }).split('"/reference/apex/qry-builder"').length - 1, 1)
  assert.deepEqual(expandSidebarAreas({ menus, paths }), generateSidebars(SITE))
})

test('an API tree appears only on reference pages', () => {
  const sidebars = generateSidebars(SITE)
  for (const p of SITE) {
    const hasTree = JSON.stringify(sidebarOf(sidebars, p.relPath)).includes('/reference/apex/qry-builder')
    assert.equal(hasTree, areaForPage(p) === 'reference', p.relPath)
  }
})

test('a guide label shows its plain words', () => {
  const guides = sidebarOf(generateSidebars(SITE), 'DML - Guide.md')
  const texts = guides[0].items.map(i => i.text)
  assert.ok(texts.includes('Selectors (queries and SOQL)'))
  assert.ok(texts.includes('DML (saving records)'))
  // A guide with no label keeps its title.
  assert.ok(texts.includes('Resilience - Guide'))
})

test('frozen trees keep the four-item top menu; the latest menu has five', () => {
  assert.deepEqual(TOP_MENU.map(i => i.text), ['Why KernDX', 'Get Started', 'Fast Starts', 'Guides', 'Reference'])
  assert.deepEqual(FROZEN_TOP_MENU.map(i => i.text), ['Why KernDX', 'Get Started', 'Fast Starts', 'Reference'])
  assert.equal(TOP_MENU.find(i => i.text === 'Guides').link, '/triggers-guide')
})

// ── The top menu is lit on every page of its area ────────────────────────────

// The tabs VitePress lights on a path, the way its isActive() does: the path tested against each
// tab's activeMatch, or else its link.
const litTabsAt = (nav, current) =>
  nav.filter(tab => tab.activeMatch ? new RegExp(tab.activeMatch).test(current) : tab.link === current).map(tab => tab.text)
// The tabs lit on a page: its source path with a final "index.md" or ".md" dropped.
const litTabs = (nav, p) => litTabsAt(nav, routeOf(p).replace(/(?:(^|\/)index)?\.md$/, '$1'))
const TAB_FOR_AREA = { why: 'Why KernDX', 'get-started': 'Get Started', 'fast-starts': 'Fast Starts', guides: 'Guides', reference: 'Reference' }

test('the Why KernDX tab opens the Strategic Overview, the first page of its menu', () => {
  const why = TOP_MENU.find(i => i.text === 'Why KernDX')
  assert.equal(why.link, '/strategic-guide-overview')
  assert.equal(FROZEN_TOP_MENU.find(i => i.text === 'Why KernDX').link, '/strategic-guide-overview')
  const menu = sidebarOf(generateSidebars(SITE), 'Strategic Guide - Overview.md')
  assert.equal(linksIn(menu)[0], why.link)
})

test('the Why KernDX menu ends with a link to the front page', () => {
  const items = sidebarOf(generateSidebars(SITE), 'Strategic Guide - Risks.md')[0].items
  assert.deepEqual(items.at(-1), { text: 'Front page', link: '/' })
})

test('every page lights only the tab of its own area', () => {
  const nav = topMenuFor(generateSidebarAreas(SITE))
  assert.deepEqual(nav.map(({ text, link }) => ({ text, link })), TOP_MENU)
  for (const p of SITE) {
    assert.deepEqual(litTabs(nav, p), [TAB_FOR_AREA[areaForPage(p)]], p.relPath)
  }
})

test('no tab is lit on the front page or on a page that does not exist', () => {
  const areas = generateSidebarAreas(SITE)
  const nav = topMenuFor(areas)
  assert.deepEqual(litTabs(nav, page('index.md', '')), [], 'Expected no tab lit on the front page')
  assert.deepEqual(litTabsAt(nav, '/'), [], 'Expected no tab lit on /')
  assert.deepEqual(litTabsAt(nav, '/no-such-page'), [], 'Expected no tab lit on the not-found page')
  // The front page still shows the Why KernDX menu's routing, though its tab is not lit.
  const sidebars = expandSidebarAreas(areas)
  assert.equal(sidebarForPath(sidebars, '/index.md'), sidebarForPath(sidebars, '/strategic-guide-risks.md'))
})

test('the Glossary lights Get Started, and the catch-all Guides tab lights no other area', () => {
  const nav = topMenuFor(generateSidebarAreas(SITE))
  assert.deepEqual(litTabs(nav, SITE.find(p => p.relPath === 'Strategic Guide - Glossary.md')), ['Get Started'])
  // Resilience starts like the release notes, which are in Reference, and README starts like them too.
  assert.deepEqual(litTabs(nav, SITE.find(p => p.relPath === 'Resilience - Guide.md')), ['Guides'])
  assert.deepEqual(litTabs(nav, SITE.find(p => p.relPath === 'README.md')), ['Get Started'])
  assert.deepEqual(litTabs(nav, SITE.find(p => p.relPath === 'reference/apex/QRY_Builder.md')), ['Reference'])
})

test('an area with no sidebar key gets no activeMatch, and a frozen menu has none', () => {
  const nav = topMenuFor({ menus: {}, paths: { '/strategic-guide-': 'why', '/': 'guides' } })
  assert.equal(nav.find(tab => tab.text === 'Reference').activeMatch, undefined)
  assert.equal(activeMatchFor({ menus: {}, paths: { '/': 'guides' } }, 'reference'), undefined)
  assert.ok(FROZEN_TOP_MENU.every(tab => tab.activeMatch === undefined))
})

// ── Reference for this page ──────────────────────────────────────────────────

const APEX_TITLES = new Map([
  ['reference/apex/qry-builder', 'QRY_Builder'],
  ['reference/apex/sel-base', 'SEL_Base'],
  ['reference/apex/qry-condition', 'QRY_Condition'],
  ['reference/apex/tst-mock', 'TST_Mock'],
  ['reference/apex/tst-builder', 'TST_Builder'],
  ['reference/apex/dml-builder', 'DML_Builder']
])

test('selectors guide lists QRY_Builder first in Reference for this page', () => {
  const apexFiles = readdirSync(`${DOCS}/reference/apex`).filter(f => f.endsWith('.md'))
  const docInputs = [
    { relPath: 'Selectors - Guide.md', raw: readFileSync(`${DOCS}/Selectors - Guide.md`, 'utf8') },
    ...apexFiles.map(f => ({ relPath: `reference/apex/${f}`, raw: readFileSync(`${DOCS}/reference/apex/${f}`, 'utf8') }))
  ]
  const plan = buildSitePlan({ docInputs, readme: null, agents: null, mirrorExcluded: new Set(), locked: [], redirects: {}, searchCases: [] })
  const write = plan.writes.find(w => w.outRel === 'selectors-guide.md')
  const links = parseFrontmatterJson(write.content).referenceForPage
  assert.ok(links.length > 0 && links.length <= 5)
  assert.deepEqual(links[0], { text: 'QRY_Builder', link: '/reference/apex/qry-builder' })
})

// The generated frontmatter holds the links as a JSON list, which YAML reads as a list.
function parseFrontmatterJson(content) {
  const block = content.match(/^---\n([\s\S]*?)\n---\n/)[1]
  const line = block.split('\n').find(l => l.startsWith('referenceForPage: '))
  return { ...parseFrontmatter(content).data, referenceForPage: line ? JSON.parse(line.slice('referenceForPage: '.length)) : undefined }
}

test('the five most linked classes are listed, the most linked first', () => {
  const body = [
    ...Array(3).fill('[a](/reference/apex/sel-base)'),
    ...Array(5).fill('[b](/reference/apex/qry-builder#builder)'),
    '[c](/reference/apex/qry-condition)', '[d](/reference/apex/tst-mock)', '[e](/reference/apex/tst-builder)',
    '[f](/reference/apex/dml-builder)', '[g](/reference/apex/not-a-page)', '[h](/selectors-guide)'
  ].join('\n')
  const links = referenceLinksFor({ ...page('Selectors - Guide.md', 'selectors-guide'), body }, APEX_TITLES)
  assert.deepEqual(links.map(l => l.text), ['QRY_Builder', 'SEL_Base', 'QRY_Condition', 'TST_Mock', 'TST_Builder'])
  assert.equal(links[0].link, '/reference/apex/qry-builder')
})

test('frontmatter referenceLinks overrides links', () => {
  const body = '[a](/reference/apex/qry-builder) [a](/reference/apex/qry-builder)'
  const links = referenceLinksFor({ ...page('DML - Guide.md', 'dml-guide', { referenceLinks: 'DML_Builder, SEL_Base' }), body }, APEX_TITLES)
  assert.deepEqual(links, [{ text: 'DML_Builder', link: '/reference/apex/dml-builder' }, { text: 'SEL_Base', link: '/reference/apex/sel-base' }])
  assert.throws(() => referenceLinksFor({ ...page('DML - Guide.md', 'dml-guide', { referenceLinks: 'NO_Such' }), body }, APEX_TITLES), /NO_Such/)
  assert.deepEqual(referenceLinksFor({ ...page('DML - Guide.md', 'dml-guide', { referenceLinks: '' }), body }, APEX_TITLES), [])
})

test('a guide with no links has no group', () => {
  const plan = buildSitePlan({
    docInputs: [
      { relPath: 'DML - Guide.md', raw: '# DML\n\nNo class links here.\n' },
      { relPath: 'Selectors - Guide.md', raw: '# Selectors\n\nSee [QRY_Builder](reference/apex/QRY_Builder.md).\n' },
      { relPath: 'reference/apex/QRY_Builder.md', raw: '---\ntitle: "QRY_Builder"\n---\n# QRY_Builder\n' }
    ],
    readme: null, agents: null, mirrorExcluded: new Set(), locked: [], redirects: {}, searchCases: []
  })
  assert.ok(!plan.writes.find(w => w.outRel === 'dml-guide.md').content.includes('referenceForPage'))
  assert.deepEqual(parseFrontmatterJson(plan.writes.find(w => w.outRel === 'selectors-guide.md').content).referenceForPage,
    [{ text: 'QRY_Builder', link: '/reference/apex/qry-builder' }])
})

test('reference links are written to page frontmatter, not to the sidebar map', () => {
  const input = {
    docInputs: [
      { relPath: 'Selectors - Guide.md', raw: '# Selectors\n\nSee [QRY_Builder](reference/apex/QRY_Builder.md).\n' },
      { relPath: 'Fast Start - Selectors.md', raw: '# Fast\n\nSee [QRY_Builder](reference/apex/QRY_Builder.md).\n' },
      { relPath: 'reference/apex/QRY_Builder.md', raw: '---\ntitle: "QRY_Builder"\n---\n# QRY_Builder\n' }
    ],
    readme: null, agents: null, mirrorExcluded: new Set(), locked: [], redirects: {}, searchCases: []
  }
  const plan = buildSitePlan(input)
  assert.ok(plan.writes.find(w => w.outRel === 'selectors-guide.md').content.includes('referenceForPage'))
  // Only guides get the group: a Fast Start links to its guide instead.
  assert.ok(!plan.writes.find(w => w.outRel === 'fast-start-selectors.md').content.includes('referenceForPage'))
  assert.ok(!JSON.stringify(generateSidebarAreas(plan.pages)).includes('referenceForPage'))
  // A frozen tree gets no reference links.
  const frozen = buildSitePlan({ ...input, frozen: true })
  assert.ok(!frozen.writes.some(w => w.content.includes('referenceForPage')))
})

// ── Inline site data budget (artifact audit check 9) ─────────────────────────

// A page whose inline site data, as written in the HTML, is exactly `bytes` long.
const htmlWithSiteData = bytes => {
  const literal = JSON.stringify(JSON.stringify({ t: 'x'.repeat(bytes - 14) }))
  assert.equal(literal.length, bytes)
  return `<script>window.__VP_HASH_MAP__=JSON.parse("{}");window.__VP_SITE_DATA__=JSON.parse(${literal});</script>`
}

test('the audit fails above 35 KB of inline site data', () => {
  const result = checkSiteData([{ slug: 'a', html: htmlWithSiteData(SITE_DATA_CEILING_BYTES + 50) }])
  assert.equal(SITE_DATA_CEILING_BYTES, 35 * 1024)
  assert.equal(result.failures.length, 1)
  assert.match(result.failures[0], /\/a/)
})

test('the audit passes at or under it', () => {
  const pages = [{ slug: 'a', html: htmlWithSiteData(1000) }, { slug: 'b', html: htmlWithSiteData(SITE_DATA_CEILING_BYTES) }]
  const result = checkSiteData(pages)
  assert.deepEqual(result.failures, [])
  assert.equal(result.maximum, SITE_DATA_CEILING_BYTES)
})

test('the audit measures site data that holds functions', () => {
  // VitePress wraps the parse when the config holds functions, as the search options do.
  const html = htmlWithSiteData(2000).replace('__VP_SITE_DATA__=JSON.parse(', '__VP_SITE_DATA__=deserializeFunctions(JSON.parse(').replace(/;<\/script>$/, ');</script>')
  assert.deepEqual(checkSiteData([{ slug: 'a', html }]), { failures: [], maximum: 2000, median: 2000 })
})

test('the audit fails a page that has no inline site data', () => {
  assert.equal(checkSiteData([{ slug: 'a', html: '<html></html>' }]).failures.length, 1)
})

// ── The menus are in the server-rendered pages (artifact audit check 10) ──────

// A built page whose sidebar has these top groups, each holding these links, as VitePress writes it.
const htmlWithSidebar = groups => '<div class="VPContent"><aside class="VPSidebar" data-v-1><nav class="nav">'
  + groups.map(([title, links]) => `<section class="VPSidebarItem level-0"><div class="item"><h2 class="text" data-v-2>${title}</h2></div>`
    + links.map(link => `<a class="VPLink link" href="${link}" data-v-2><p class="text">x</p></a>`).join('') + '</section>').join('')
  + '<section class="reference-for-page"><h2 id="x">Reference for this page</h2><a href="/reference/apex/qry-builder">QRY_Builder</a></section>'
  + '</nav></aside></div>'
const GUIDE_HTML = htmlWithSidebar([['Guides', ['/selectors-guide', '/dml-guide']]])
const REFERENCE_HTML = htmlWithSidebar([['API Reference', ['/reference/apex', '/reference/apex/qry-builder']], ['Release Notes', ['/release-notes-kern-1-11']]])
const FROZEN_HTML = htmlWithSidebar([['Getting Started', ['/1.10/installation']], ['Guides', ['/1.10/dml-guide']], ['API Reference', ['/1.10/reference/apex']]])

test('the menu check passes when each page shows its own menu', () => {
  assert.deepEqual(checkSidebarMenus({ guide: GUIDE_HTML, reference: REFERENCE_HTML, frozen: FROZEN_HTML, frozenLine: '1.10' }), [])
})

test('the menu check fails a guide page with no Guides menu', () => {
  const failures = checkSidebarMenus({ guide: '<div class="VPContent"></div>', reference: REFERENCE_HTML, frozen: null })
  assert.equal(failures.length, 1)
  assert.match(failures[0], /selectors-guide/)
})

test('the menu check fails a guide page that shows the API tree', () => {
  const guide = htmlWithSidebar([['Guides', ['/dml-guide']], ['API Reference', ['/reference/apex']]])
  assert.equal(checkSidebarMenus({ guide, reference: REFERENCE_HTML, frozen: null }).length, 1)
})

test('the menu check fails a reference page with no API tree', () => {
  const failures = checkSidebarMenus({ guide: GUIDE_HTML, reference: GUIDE_HTML, frozen: null })
  assert.equal(failures.length, 1)
  assert.match(failures[0], /reference\/apex/)
})

test('the menu check fails an older version that lost its single menu', () => {
  const frozen = htmlWithSidebar([['Guides', ['/1.10/dml-guide']]])
  const failures = checkSidebarMenus({ guide: GUIDE_HTML, reference: REFERENCE_HTML, frozen, frozenLine: '1.10' })
  assert.equal(failures.length, 1)
  assert.match(failures[0], /1\.10/)
})

test('the menu check fails when a page it needs was not built', () => {
  assert.equal(checkSidebarMenus({ guide: null, reference: null, frozen: null }).length, 2)
})

// ── The audit runs when started as a script ───────────────────────────────────

test('the audit knows it was started as a script, even through a linked folder', () => {
  // On macOS /tmp is a link to /private/tmp, so the path node was given and the module's own path differ.
  const auditUrl = new URL('./artifact-audit.mjs', import.meta.url).href
  const linkParent = mkdtempSync(path.join(tmpdir(), 'audit-link-'))
  try {
    const linked = path.join(linkParent, 'scripts')
    symlinkSync(path.dirname(fileURLToPath(auditUrl)), linked, 'dir')
    assert.equal(isRunAsScript(path.join(linked, 'artifact-audit.mjs'), auditUrl), true)
    assert.equal(isRunAsScript(fileURLToPath(auditUrl), auditUrl), true)
    assert.equal(isRunAsScript(path.join(linked, 'generate-nav.mjs'), auditUrl), false)
    assert.equal(isRunAsScript(path.join(linked, 'no-such-file.mjs'), auditUrl), false)
    assert.equal(isRunAsScript(undefined, auditUrl), false)
  } finally {
    rmSync(linkParent, { recursive: true, force: true })
  }
})
