// SPDX-License-Identifier: BUSL-1.1
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { parseFrontmatter } from './frontmatter.mjs'

test('parses a YAML frontmatter block', () => {
  const md = '---\ntitle: "UTIL_SObject"\ntype: class\ngroup: "Utilities"\norder: 3\ndraft: false\n---\n# Body\ntext'
  const { data, content } = parseFrontmatter(md)
  assert.equal(data.title, 'UTIL_SObject')
  assert.equal(data.type, 'class')
  assert.equal(data.group, 'Utilities')
  assert.equal(data.order, 3)
  assert.equal(data.draft, false)
  assert.ok(content.startsWith('# Body'))
})

test('returns empty data when there is no frontmatter', () => {
  const { data, content } = parseFrontmatter('# Just body')
  assert.deepEqual(data, {})
  assert.equal(content, '# Just body')
})

test('strips a leading UTF-8 BOM before parsing frontmatter', () => {
  const md = '﻿---\ntitle: "UTIL_SObject"\norder: 2\n---\n# Body\ntext'
  const { data, content } = parseFrontmatter(md)
  assert.equal(data.title, 'UTIL_SObject')
  assert.equal(data.order, 2)
  assert.ok(content.startsWith('# Body'))
  assert.ok(!content.includes('---'))
  assert.ok(!content.includes('title:'))
})

test('does not treat a leading thematic break as frontmatter', () => {
  const md = '---\n\nIntro paragraph that must survive.\n\n---\n\nSecond section.'
  const { data, content } = parseFrontmatter(md)
  assert.deepEqual(data, {})
  assert.equal(content, md)
  assert.ok(content.includes('Intro paragraph that must survive.'))
})

test('keeps version-looking scalars as strings', () => {
  const md = '---\nsince: 1.0\nuntil: 1.10\nrange: 1.2.3\n---\nbody'
  const { data } = parseFrontmatter(md)
  assert.equal(data.since, '1.0')
  assert.equal(data.until, '1.10')
  assert.equal(data.range, '1.2.3')
  assert.equal(typeof data.since, 'string')
  assert.equal(typeof data.until, 'string')
})

test('keeps leading-zero scalars as strings', () => {
  const md = '---\ncode: 007\nflag: 0\n---\nbody'
  const { data } = parseFrontmatter(md)
  assert.equal(data.code, '007')
  assert.equal(typeof data.code, 'string')
  assert.equal(data.flag, 0)
})

test('still coerces plain integer and decimal scalars to Number', () => {
  const md = '---\norder: 5\nweight: 3.5\n---\nbody'
  const { data } = parseFrontmatter(md)
  assert.equal(data.order, 5)
  assert.equal(typeof data.order, 'number')
  assert.equal(data.weight, 3.5)
  assert.equal(typeof data.weight, 'number')
})
