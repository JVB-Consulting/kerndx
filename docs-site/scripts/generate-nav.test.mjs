// SPDX-License-Identifier: BUSL-1.1
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { groupForPage, generateSidebar } from './generate-nav.mjs'

const page = (relPath, slug, fm = {}) => ({ relPath, slug, frontmatter: fm, title: relPath.replace(/\.md$/, '') })

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
