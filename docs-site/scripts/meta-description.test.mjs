// SPDX-License-Identifier: BUSL-1.1
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { cleanMetaDescription } from './meta-description.mjs'

test('keeps a clean first sentence', () => {
  const out = cleanMetaDescription('SObject runtime operations for filtering and field extraction. More detail follows.')
  assert.equal(out, 'SObject runtime operations for filtering and field extraction.')
})

test('strips ApexDoc {@link} and HTML and markdown tokens', () => {
  const out = cleanMetaDescription('Uses {@link UTIL_SObject} with `code` and <b>bold</b> to **extract** fields from records.')
  assert.ok(!out.includes('{@link'))
  assert.ok(!out.includes('<b>'))
  assert.ok(!out.includes('`'))
  assert.ok(!out.includes('**'))
  assert.ok(out.includes('UTIL_SObject'))
})

test('returns null when the cleaned result is too short', () => {
  assert.equal(cleanMetaDescription('Short.'), null)
  assert.equal(cleanMetaDescription(''), null)
  assert.equal(cleanMetaDescription(null), null)
})

test('caps at 155 characters', () => {
  const long = 'A'.repeat(300) + '.'
  const out = cleanMetaDescription(long)
  assert.ok(out.length <= 155)
})

test('falls back to the whole string when there is no sentence terminator', () => {
  const out = cleanMetaDescription('A fluent SOQL query builder for Apex with type-safe field references and bind variables')
  assert.ok(out.startsWith('A fluent SOQL query builder'))
})

test('does not break the first sentence at the "e.g." abbreviation', () => {
  const out = cleanMetaDescription('Configure the retry policy, e.g. exponential backoff with jitter, to handle transient callout failures gracefully.')
  assert.equal(out, 'Configure the retry policy, e.g. exponential backoff with jitter, to handle transient callout failures gracefully.')
})

test('does not break the first sentence at the "i.e." abbreviation', () => {
  const out = cleanMetaDescription('Use the selector pattern, i.e. a dedicated query class, to keep SOQL out of business logic across the codebase.')
  assert.equal(out, 'Use the selector pattern, i.e. a dedicated query class, to keep SOQL out of business logic across the codebase.')
})

test('does not break the first sentence at a trailing-period abbreviation like "Inc." or "vs."', () => {
  const inc = cleanMetaDescription('Built by Acme Inc. for Salesforce administrators who need a reliable governance framework for their org.')
  assert.equal(inc, 'Built by Acme Inc. for Salesforce administrators who need a reliable governance framework for their org.')
  const vs = cleanMetaDescription('Compares triggers vs. flows for bulk data processing and explains when each approach is the right fit.')
  assert.equal(vs, 'Compares triggers vs. flows for bulk data processing and explains when each approach is the right fit.')
})

test('does not break the first sentence at a single-letter initial', () => {
  const out = cleanMetaDescription('Authored by J. Smith and reviewed by the platform team before the managed package release shipped.')
  assert.equal(out, 'Authored by J. Smith and reviewed by the platform team before the managed package release shipped.')
})

test('does not break the first sentence inside a version or decimal number', () => {
  const out = cleanMetaDescription('Targets v2.0 of the framework which adds a fluent query builder that simplifies SOQL construction.')
  assert.equal(out, 'Targets v2.0 of the framework which adds a fluent query builder that simplifies SOQL construction.')
})

test('still ends the first sentence at a genuine sentence terminator', () => {
  const out = cleanMetaDescription('SObject runtime operations for filtering and field extraction from records. The rest is dropped here.')
  assert.equal(out, 'SObject runtime operations for filtering and field extraction from records.')
})

test('does not split an astral character when capping length', () => {
  const long = 'A'.repeat(151) + '😀😀😀😀😀'
  const out = cleanMetaDescription(long)
  assert.ok(out.length <= 155)
  const body = out.slice(0, -1) // drop the trailing ellipsis
  assert.ok(body.isWellFormed(), 'capped description must not contain a lone surrogate')
})
