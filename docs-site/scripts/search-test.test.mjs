// SPDX-License-Identifier: Apache-2.0
import { test } from 'node:test'
import assert from 'node:assert/strict'
import MiniSearch from 'minisearch'
import { summariseResults, evaluateCase, matchesResult, scoredResults, formatScoredResults, searchBoxOptions, pageOf } from './search-test.mjs'
import { boostForDocument, browserSourceOf } from './search-render.mjs'

const OTHER = 'Utilities - Guide > Caching'

test('exact case fails when the match is second', () => {
  const searchCase = { query: 'QRY_Builder', kind: 'exact', expected: ['QRY_Builder'], accepted: [] }
  const outcome = evaluateCase(searchCase, ['QRY_Builder.Builder', 'QRY_Builder', OTHER])
  assert.equal(outcome.passed, false)
  assert.match(outcome.reason, /QRY_Builder\.Builder/)
})

test('exact case passes when the match is first', () => {
  const searchCase = { query: 'QRY_Builder', kind: 'exact', expected: ['QRY_Builder'], accepted: [] }
  assert.equal(evaluateCase(searchCase, ['QRY_Builder', OTHER]).passed, true)
})

test('vocabulary case passes on an accepted result third', () => {
  const searchCase = { query: 'soql', kind: 'vocabulary', expected: ['From Plain Apex to KernDX > Reading records'], accepted: ['Fast Start - Selectors'] }
  const outcome = evaluateCase(searchCase, [OTHER, OTHER, 'Fast Start - Selectors > How It Works'])
  assert.equal(outcome.passed, true)
  assert.match(outcome.reason, /third|3/)
})

test('vocabulary case fails on an accepted result fourth', () => {
  const searchCase = { query: 'soql', kind: 'vocabulary', expected: ['From Plain Apex to KernDX > Reading records'], accepted: ['Fast Start - Selectors'] }
  const outcome = evaluateCase(searchCase, [OTHER, OTHER, OTHER, 'Fast Start - Selectors'])
  assert.equal(outcome.passed, false)
})

test('vocabulary case passes when the expected result is first', () => {
  const searchCase = { query: 'aggregate', kind: 'vocabulary', expected: ['Selectors - Guide > Aggregate Functions'], accepted: [] }
  assert.equal(evaluateCase(searchCase, ['Selectors - Guide > Aggregate Functions', OTHER]).passed, true)
})

test('shared method passes when either owning class is first', () => {
  const searchCase = { query: 'withSystemMode', kind: 'exact', expected: ['QRY_Builder.Builder', 'DML_Builder'], accepted: [] }
  assert.equal(evaluateCase(searchCase, ['QRY_Builder.Builder > withSystemMode', 'DML_Builder > withSystemMode']).passed, true)
  assert.equal(evaluateCase(searchCase, ['DML_Builder > withSystemMode', 'QRY_Builder.Builder > withSystemMode']).passed, true)
  assert.equal(evaluateCase(searchCase, [OTHER, 'DML_Builder > withSystemMode']).passed, false)
})

test('a case with no results fails', () => {
  const searchCase = { query: 'nothing', kind: 'vocabulary', expected: ['DML - Guide'], accepted: ['Fast Start - DML'] }
  const outcome = evaluateCase(searchCase, [])
  assert.equal(outcome.passed, false)
  assert.match(outcome.reason, /no results/)
})

test('matchesResult anchors the page and finds headings in order at any depth', () => {
  assert.equal(matchesResult('Selectors - Guide > GROUP BY', 'Selectors - Guide > Query Builder > GROUP BY'), true)
  assert.equal(matchesResult('Selectors - Guide > GROUP BY', 'Selectors - Guide > GROUP BY > Date Functions in GROUP BY'), true)
  assert.equal(matchesResult('Selectors - Guide > GROUP BY', 'DML - Guide > GROUP BY'), false)
  assert.equal(matchesResult('Selectors - Guide', 'Selectors - Guide > Aggregate Functions'), true)
})

test('matchesResult compares whole words, so a class does not match a longer class name', () => {
  assert.equal(matchesResult('QRY_Builder', 'QRY_Builder.Builder'), false)
  assert.equal(matchesResult('qry_builder', 'QRY_Builder'), true)
  assert.equal(matchesResult('DML - Guide > Transactional DML Pattern', 'DML - Guide > Transactional DML Pattern (DML_Builder)'), true)
})

const INDEXED_SECTIONS = [
  { id: '/dml-guide#insert-operations', title: 'Insert Operations', titles: ['DML - Guide'], text: 'Insert records in bulk.' },
  { id: '/release-notes-kern-1-9#insert', title: 'Insert', titles: ['Release Notes'], text: 'Insert records in bulk.' },
  { id: '/fast-start-logging#log', title: 'Log at every level', titles: ['Fast Start - Logging'], text: 'Write a log.' }
]

function builtIndex() {
  const options = searchBoxOptions()
  const index = new MiniSearch(options)
  index.addAll(INDEXED_SECTIONS)
  return MiniSearch.loadJSON(JSON.stringify(index), options)
}

test('the search box options carry the site ranking on top of the search box defaults', () => {
  const { fields, searchOptions } = searchBoxOptions()
  assert.deepEqual(fields, ['title', 'titles', 'text'])
  assert.deepEqual(searchOptions.boost, { title: 4, text: 2, titles: 1 })
  assert.equal(String(searchOptions.boostDocument), browserSourceOf(boostForDocument))
})

test('scoredResults names results as the search box does, best first, with their scores', () => {
  const results = scoredResults(builtIndex(), 'insert', 4)
  assert.deepEqual(results.map((result) => result.label), ['DML - Guide > Insert Operations', 'Release Notes > Insert'])
  assert.ok(results[0].score > results[1].score, 'Expected the release note, ranked lower, to score less')
})

test('scoredResults returns no more than the count asked for', () => {
  assert.equal(scoredResults(builtIndex(), 'insert', 1).length, 1)
})

function twoPageIndex() {
  const options = searchBoxOptions()
  const index = new MiniSearch(options)
  index.addAll([
    { id: '/async-processing-guide#monitoring', title: 'Monitoring', titles: ['Async Processing - Guide'], text: 'Monitoring in production.' },
    { id: '/web-services-guide#monitoring', title: 'Monitoring', titles: ['Web Services - Guide'], text: 'Monitoring in production.' }
  ])
  return MiniSearch.loadJSON(JSON.stringify(index), options)
}

test('scoredResults ranks the page the reader searches from first, then removes the stand-in address bar', () => {
  for (const pathname of ['/web-services-guide', '/async-processing-guide']) {
    const results = scoredResults(twoPageIndex(), 'monitoring', 2, pathname)
    assert.ok(results[0].label.startsWith(pathname === '/web-services-guide' ? 'Web Services' : 'Async Processing'), `Expected the section on ${pathname} first`)
    assert.ok(results[0].score > results[1].score, 'Expected the current page to score more')
    assert.equal(typeof globalThis.window, 'undefined', 'Expected the stand-in address bar to be removed')
  }
  const withoutPage = scoredResults(twoPageIndex(), 'monitoring', 2)
  assert.equal(withoutPage[0].score, withoutPage[1].score, 'Expected no page to rank higher without an address')
})

test('pageOf gives the page a case names, or the home page', () => {
  assert.equal(pageOf({ query: 'monitoring', page: '/web-services-guide' }), '/web-services-guide')
  assert.equal(pageOf({ query: 'monitoring' }), '/')
})

test('formatScoredResults writes one numbered line per result with its score', () => {
  const lines = formatScoredResults([{ label: 'DML - Guide > Insert Operations', score: 58.46 }, { label: 'Release Notes > Insert', score: 7 }])
  assert.equal(lines, '    1. 58.5  DML - Guide > Insert Operations\n    2. 7.0  Release Notes > Insert')
})

function row(query, passed, knownFailing) {
  return { searchCase: { query, ...(knownFailing ? { knownFailing } : {}) }, outcome: { passed, reason: "r" } }
}

test("a known-failing case that fails does not fail the run", () => {
  const summary = summariseResults([row("a", true), row("b", false, "another page wins")])
  assert.equal(summary.exitCode, 0)
})

test("a known-failing case that passes fails the run", () => {
  const summary = summariseResults([row("b", true, "another page wins")])
  assert.equal(summary.exitCode, 1)
  assert.ok(summary.lines.includes("\"b\" now passes: remove knownFailing"))
})

test("a failing case without knownFailing fails the run", () => {
  const summary = summariseResults([row("a", false)])
  assert.equal(summary.exitCode, 1)
})

test("known-failing cases are listed apart in the summary", () => {
  const summary = summariseResults([row("a", true), row("b", false, "another page wins")])
  assert.ok(summary.lines.includes("search test: 1 of 2 cases pass, 1 known failing"))
  assert.ok(summary.lines.some((line) => line.includes("\"b\"") && line.includes("another page wins")))
})
