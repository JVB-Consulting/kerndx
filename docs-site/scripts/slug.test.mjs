// SPDX-License-Identifier: BUSL-1.1
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { slugifySegment, slugForPath, buildSlugMap } from './slug.mjs'

test('slugifySegment lowercases and collapses non-alphanumerics', () => {
  assert.equal(slugifySegment('Fast Start - Selectors'), 'fast-start-selectors')
  assert.equal(slugifySegment('Objects & Metadata - Guide'), 'objects-metadata-guide')
  assert.equal(slugifySegment('UTIL_SObject'), 'util-sobject')
  assert.equal(slugifySegment('ScheduledJob__c'), 'scheduledjob-c')
})

test('slugForPath drops .md, slugs each segment, preserves directories', () => {
  assert.equal(slugForPath('Fast Start - Selectors.md'), 'fast-start-selectors')
  assert.equal(slugForPath('reference/apex/UTIL_SObject.md'), 'reference/apex/util-sobject')
  assert.equal(slugForPath('reference/objects/ScheduledJob__c.md'), 'reference/objects/scheduledjob-c')
})

test('slugForPath collapses an index file to its directory', () => {
  assert.equal(slugForPath('reference/index.md'), 'reference')
  assert.equal(slugForPath('reference/apex/index.md'), 'reference/apex')
})

test('buildSlugMap returns a per-path slug map', () => {
  const m = buildSlugMap(['Fast Start - DML.md', 'reference/apex/UTIL_SObject.md'])
  assert.equal(m.get('Fast Start - DML.md'), 'fast-start-dml')
  assert.equal(m.get('reference/apex/UTIL_SObject.md'), 'reference/apex/util-sobject')
})

test('buildSlugMap throws on a slug collision', () => {
  assert.throws(
    () => buildSlugMap(['Foo Bar.md', 'Foo-Bar.md']),
    /Slug collision/
  )
})
