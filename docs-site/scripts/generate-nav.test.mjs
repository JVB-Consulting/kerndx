// SPDX-License-Identifier: BUSL-1.1
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { groupForPage, generateSidebar } from './generate-nav.mjs'

const page = (relPath, slug, fm = {}) => ({ relPath, slug, frontmatter: fm, title: relPath.replace(/\.md$/, '') })

test('reference path wins over frontmatter group', () => {
  const g = groupForPage(page('reference/apex/UTIL_SObject.md', 'reference/apex/util-sobject', { group: 'Utilities' }))
  assert.deepEqual(g, { group: 'API Reference', subgroup: 'apex' })
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

test('a reference area landing page groups under its area', () => {
  assert.deepEqual(groupForPage(page('reference/apex/index.md', 'reference/apex')), { group: 'API Reference', subgroup: 'apex' })
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

test('API Reference apex ordering: classes then interfaces then enums, then alpha', () => {
  const sidebar = generateSidebar([
    page('reference/apex/ZClass.md', 'reference/apex/zclass', { type: 'class' }),
    page('reference/apex/AnEnum.md', 'reference/apex/anenum', { type: 'enum' }),
    page('reference/apex/AnInterface.md', 'reference/apex/aninterface', { type: 'interface' }),
    page('reference/apex/AClass.md', 'reference/apex/aclass', { type: 'class' })
  ])
  const api = sidebar.find(s => s.text === 'API Reference')
  const apex = api.items.find(s => s.text === 'apex')
  assert.deepEqual(apex.items.map(i => i.link), [
    '/reference/apex/aclass', '/reference/apex/zclass',     // classes, alpha
    '/reference/apex/aninterface',                          // interfaces
    '/reference/apex/anenum'                                // enums
  ])
})

test('API Reference area index page leads its subgroup (the landing surfaces first)', () => {
  const sidebar = generateSidebar([
    page('reference/apex/ZClass.md', 'reference/apex/zclass', { type: 'class' }),
    page('reference/apex/index.md', 'reference/apex', { title: 'Apex Classes' }),
    page('reference/apex/AClass.md', 'reference/apex/aclass', { type: 'class' })
  ])
  const api = sidebar.find(s => s.text === 'API Reference')
  const apex = api.items.find(s => s.text === 'apex')
  // The landing page must lead the subgroup, not sink below the classes.
  assert.equal(apex.items[0].link, '/reference/apex')
  assert.equal(apex.items[0].text, 'Apex Classes')
})
