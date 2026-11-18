// SPDX-License-Identifier: Apache-2.0
import { test } from 'node:test'
import assert from 'node:assert/strict'
import MiniSearch from 'minisearch'
import {
  indexableReferenceSource, indexableSource, boostForDocument, tokenizeForSearch, tokenizeSearchWords, localSearchOptions, processSearchTerm, canMatchLoosely,
  searchTermsOf, withSearchTerms, checkSearchTerms, sectionHeadingsOf, SEARCH_TERMS_PER_SECTION, SEARCH_TERMS_PER_PAGE, browserSourceOf
} from './search-render.mjs'

const REFERENCE_PAGE = [
  '# QRY_Builder.Builder',
  '',
  '**Class**',
  '',
  '```apex',
  'global virtual inherited sharing class QRY_Builder.Builder',
  '```',
  '',
  'Extensible query builder class.',
  '',
  '## Methods',
  '',
  '| Method | Description |',
  '|--------|-------------|',
  '| global Builder [withSystemMode](#withsystemmode)() | Runs the query in system mode. |',
  '',
  '### withSystemMode',
  '',
  '<div class="apex-member">',
  '',
  '```apex',
  'global QRY_Builder.Builder withSystemMode()',
  '```',
  '',
  'Runs the query in system mode, without the running user\'s field and object checks.',
  '',
  '**Parameters**',
  '',
  '| Name | Type | Description |',
  '|------|------|-------------|',
  '| fieldName | String | The field to add. |',
  '',
  '</div>',
  '',
  '### addField',
  '',
  'Adds a single field.',
  '',
  '### addField',
  '',
  'Adds a single field by name.',
  '',
  '## Constructors',
  '',
  '### Builder(SObjectType sObjectType)',
  '',
  'Starts a query on one object type.',
  ''
].join('\n')

test('keeps each ### member heading', () => {
  const indexed = indexableReferenceSource(REFERENCE_PAGE)
  assert.match(indexed, /^### withSystemMode$/m)
  assert.equal(indexed.match(/^### addField$/gm).length, 2, 'Expected both addField headings, so the repeated anchors stay numbered as on the page')
  assert.match(indexed, /^## Methods$/m)
  assert.match(indexed, /^## Constructors$/m)
})

test('drops the member\'s first sentence', () => {
  const indexed = indexableReferenceSource(REFERENCE_PAGE)
  assert.doesNotMatch(indexed, /Runs the query in system mode, without/)
  assert.doesNotMatch(indexed, /Adds a single field/)
  assert.doesNotMatch(indexed, /Starts a query on one object type/)
})

test('drops parameter tables and fences', () => {
  const indexed = indexableReferenceSource(REFERENCE_PAGE)
  assert.doesNotMatch(indexed, /```/)
  assert.doesNotMatch(indexed, /global virtual inherited sharing class/)
  assert.doesNotMatch(indexed, /\| fieldName \|/)
  assert.doesNotMatch(indexed, /\| Method \| Description \|/)
  assert.doesNotMatch(indexed, /\*\*Parameters\*\*/)
})

test('keeps the text above the first ## section', () => {
  const indexed = indexableReferenceSource(REFERENCE_PAGE)
  assert.match(indexed, /^# QRY_Builder\.Builder$/m)
  assert.match(indexed, /^\*\*Class\*\*$/m)
  assert.match(indexed, /^Extensible query builder class\.$/m)
})

test('a heading with overload brackets keeps its anchor', () => {
  const indexed = indexableReferenceSource(REFERENCE_PAGE)
  assert.match(indexed, /^### Builder\(SObjectType sObjectType\)$/m, 'Expected the heading kept whole, so it gets the same anchor as on the page')
})

test('a page with no member sections stays whole', () => {
  const page = '# MyTrigger\n\nRuns the account trigger actions.\n'
  assert.equal(indexableReferenceSource(page).trim(), page.trim())
})

test('a heading inside a fence is not taken as a member heading', () => {
  const page = '# Page\n\n## Methods\n\n```markdown\n### notAHeading\n```\n\n### realMember\n'
  const indexed = indexableReferenceSource(page)
  assert.doesNotMatch(indexed, /notAHeading/)
  assert.match(indexed, /^### realMember$/m)
})

test('indexableSource drops frontmatter and fences from every page', () => {
  const page = '---\ntitle: "Guide"\n---\n# Guide\n\nSome prose.\n\n````apex\nInteger x = 1;\n```\nstill code\n`````\n\nMore prose.\n'
  const indexed = indexableSource(page, 'dml-guide.md')
  assert.doesNotMatch(indexed, /title:/)
  assert.doesNotMatch(indexed, /Integer x|still code/)
  assert.match(indexed, /Some prose\./)
  assert.match(indexed, /More prose\./)
})

const PLAIN_APEX_PAGE = [
  '# From Plain Apex',
  '',
  '```apex',
  '// Plain Apex',
  'System.debug(\'Payment processed\');',
  '```',
  '',
  '```apex',
  '// KernDX',
  'kern.LOG_Builder.build().info(\'Payment processed\').emitAt(\'SVC.charge\');',
  '```',
  '',
  '```apex',
  '// Plain Apex: one fat trigger',
  'trigger AccountTrigger on Account (before insert) {}',
  '```',
  ''
].join('\n')

test('keeps a sample labelled // Plain Apex and drops every other block', () => {
  const indexed = indexableSource(PLAIN_APEX_PAGE, 'from-plain-apex-to-kerndx.md')
  assert.match(indexed, /System\.debug\('Payment processed'\);/)
  assert.doesNotMatch(indexed, /LOG_Builder/, 'Expected the KernDX sample to stay out of the index')
  assert.doesNotMatch(indexed, /AccountTrigger/, 'Expected a block whose label only starts with "// Plain Apex" to stay out')
})

test('a frozen build drops a // Plain Apex sample too', () => {
  assert.doesNotMatch(indexableSource(PLAIN_APEX_PAGE, 'from-plain-apex-to-kerndx.md', { frozen: true }), /System\.debug/)
})

test('a reference page drops a // Plain Apex sample', () => {
  assert.doesNotMatch(indexableSource(`${PLAIN_APEX_PAGE}\n## Methods\n`, 'reference/apex/log-builder.md'), /System\.debug/)
})

test('indexableSource keeps a guide whole and trims a reference page', () => {
  assert.match(indexableSource(REFERENCE_PAGE, 'dml-guide.md'), /Adds a single field/)
  assert.doesNotMatch(indexableSource(REFERENCE_PAGE, 'reference/apex/qry-builder-builder.md'), /Adds a single field/)
})

// Stands in for the markdown renderer VitePress passes to _render: it returns the text it was given.
const ECHO_RENDERER = { render: (source) => source }

test('a frozen build indexes a reference page only above its first ## section', () => {
  const indexed = indexableSource(REFERENCE_PAGE, 'reference/apex/qry-builder-builder.md', { frozen: true })
  assert.match(indexed, /^# QRY_Builder\.Builder$/m)
  assert.match(indexed, /^Extensible query builder class\.$/m)
  assert.doesNotMatch(indexed, /^##/m, 'Expected no section or member heading in a frozen reference page')
  const rendered = localSearchOptions({ frozen: true })._render(REFERENCE_PAGE, { relativePath: 'reference/apex/qry-builder-builder.md' }, ECHO_RENDERER)
  assert.equal(rendered, indexed)
})

test('a frozen build keeps a reference page with no ## section whole', () => {
  const page = '# MyTrigger\n\nRuns the account trigger actions.\n'
  assert.equal(indexableSource(page, 'reference/apex/my-trigger.md', { frozen: true }), page)
})

test('a frozen build has no boost and no custom tokenizer', () => {
  const options = localSearchOptions({ frozen: true })
  assert.equal(options.miniSearch, undefined, 'Expected the default MiniSearch options in a frozen build')
  assert.deepEqual(Object.keys(options), ['_render'])
})

test('the latest build keeps member headings, the boost and the tokenizer', () => {
  const options = localSearchOptions({ frozen: false })
  const rendered = options._render(REFERENCE_PAGE, { relativePath: 'reference/apex/qry-builder-builder.md' }, ECHO_RENDERER)
  assert.match(rendered, /^### withSystemMode$/m)
  assert.equal(String(options.miniSearch.options.tokenize), browserSourceOf(tokenizeForSearch))
  assert.equal(String(options.miniSearch.searchOptions.boostDocument), browserSourceOf(boostForDocument))
})

// VitePress writes the search options into every page as text (each function's toString()), so
// every page pays for that text before it can show anything. The options the latest build passes
// are copies whose text is the short browser form; in Node they run the original function.
const SEARCH_OPTION_SAMPLES = {
  tokenize: [['End-to-end test'], ['with  system mode']],
  boostDocument: [['/release-notes-kern-1-10#x', 'log', {}], ['/reference/apex/dml-builder#dml-builder', 'dml', { title: 'DML_Builder' }],
    ['/feature-flags-guide#feature-flags-guide', 'feature', { title: 'Feature Flags - Guide' }]],
  processTerm: [['Rollback'], ['Upsert']],
  fuzzy: [['roll', 1, ['rollback', 'roll', 'rolled']], ['a', 1, ['add', 'a', 'field']], ['upsert', 0, ['upsert']]],
  prefix: [['rolled', 2, ['rollback', 'roll', 'rolled']], ['qu', 1, ['soql', 'qu']]]
}
const SEARCH_OPTION_ORIGINALS = {
  tokenize: tokenizeSearchWords, boostDocument: boostForDocument, processTerm: processSearchTerm, fuzzy: canMatchLoosely, prefix: canMatchLoosely
}

test('the search functions go to the browser in a short form that gives the same answers', () => {
  const { miniSearch } = localSearchOptions()
  const indexTokenize = miniSearch.options.tokenize
  const rebuiltIndexTokenize = new Function(`return ${String(indexTokenize)}`)()
  assert.deepEqual(rebuiltIndexTokenize('QRY_Builder.Builder', 'title'), tokenizeForSearch('QRY_Builder.Builder', 'title'))
  assert.deepEqual(indexTokenize('QRY_Builder.Builder', 'title'), ['QRY', 'Builder'])
  for (const [name, samples] of Object.entries(SEARCH_OPTION_SAMPLES)) {
    const option = miniSearch.searchOptions[name]
    const original = SEARCH_OPTION_ORIGINALS[name]
    const text = String(option)
    assert.ok(!text.includes('\n'), `Expected the browser text of ${name} to be on one line`)
    assert.ok(text.length < original.toString().length, `Expected the browser text of ${name} to be shorter than its source`)
    const rebuilt = new Function(`return ${text}`)()
    for (const sample of samples) {
      assert.deepEqual(rebuilt(...sample), original(...sample), `Expected the browser form of ${name} to answer as the source does`)
      assert.deepEqual(option(...sample), original(...sample), `Expected the option ${name} to run the source in Node`)
    }
    if (name === 'boostDocument') {
      const currentPageSample = ['/web-services-guide#monitoring-api-health', 'monitoring', { title: 'Monitoring API Health' }]
      onPage('/web-services-guide', () => {
        assert.equal(rebuilt(...currentPageSample), 1.3, 'Expected the browser form to boost the current page')
        assert.equal(rebuilt(...currentPageSample), original(...currentPageSample))
      })
    }
  }
})

test('the text of the search functions stays well inside the site data budget', () => {
  const { miniSearch } = localSearchOptions()
  const texts = [miniSearch.options.tokenize, ...Object.values(miniSearch.searchOptions)].map(String)
  const bytes = Buffer.byteLength(JSON.stringify(JSON.stringify(texts)), 'utf8')
  assert.ok(bytes < 2600, `Expected the search functions to add under 2600 bytes to every page, got ${bytes}`)
})

test('a word repeated in a title counts once', () => {
  assert.deepEqual(tokenizeForSearch('QRY_Builder.Builder', 'title'), ['QRY', 'Builder'])
  assert.deepEqual(tokenizeForSearch('QRY_Builder', 'title'), ['QRY', 'Builder'])
})

test('a word repeated in the text or the search words is kept', () => {
  assert.deepEqual(tokenizeForSearch('builder Builder, builder', 'text'), ['builder', 'Builder', 'builder'])
  assert.deepEqual(tokenizeForSearch('QRY_Builder.Builder'), ['QRY', 'Builder', 'Builder'])
})

test('tokenizeForSearch still works after the site turns it into text for the browser', () => {
  const rebuilt = new Function(`return ${tokenizeForSearch.toString()}`)()
  assert.deepEqual(rebuilt('QRY_Builder.Builder', 'title'), ['QRY', 'Builder'])
  assert.deepEqual(rebuilt('with  system mode'), ['with', 'system', 'mode'])
})

test('boosts a guide over a release note', () => {
  assert.ok(boostForDocument('/dml-guide#upsert-operations') > boostForDocument('/release-notes-kern-1-10#mock-an-aggregate-query'))
})

test('boosts a Fast Start over a strategic guide', () => {
  assert.ok(boostForDocument('/fast-start-dml#insert-a-record') > boostForDocument('/strategic-guide-operations#migration-checklists'))
})

test('a strategic guide and a release note rank below a guide under a version base', () => {
  const guide = boostForDocument('/1.10/selectors-guide#aggregate-functions')
  assert.ok(guide > boostForDocument('/1.10/strategic-guide-overview'))
  assert.ok(guide > boostForDocument('/1.10/release-notes-kern-1-8'))
})

test('boostForDocument still works after the site turns it into text for the browser', () => {
  // The site sends this function to the browser as its source text and rebuilds it there,
  // so it must not use anything defined outside its own body.
  const rebuilt = new Function(`return ${browserSourceOf(boostForDocument)}`)()
  const ids = ['/dml-guide', '/fast-start-dml#x', '/strategic-guide-risks#y', '/release-notes-kern-1-9#z', '/reference/apex/dml-builder#withsystemmode']
  for (const id of [...ids, '/from-plain-apex-to-kerndx#logging']) {
    assert.equal(rebuilt(id), boostForDocument(id), `Expected the same weight for ${id}`)
  }
})

// Runs a check with a browser address bar on the given page, then removes it again.
function onPage(pathname, check) {
  globalThis.window = { location: { pathname } }
  try {
    check()
  } finally {
    delete globalThis.window
  }
}

test('a result on the page the reader searches from ranks higher than one on another page', () => {
  onPage('/web-services-guide', () => {
    assert.equal(boostForDocument('/web-services-guide#monitoring-api-health', 'monitoring', { title: 'Monitoring API Health' }), 1.3)
    assert.equal(boostForDocument('/async-processing-guide#monitoring', 'monitoring', { title: 'Monitoring' }), 1, 'Expected another page to keep its score')
    assert.equal(boostForDocument('/web-services-guide', 'monitoring', { title: 'Web Services - Guide' }), 1.3, 'Expected the top of the page to rank higher too')
  })
})

test('the current page multiplies the page weights instead of replacing them', () => {
  onPage('/release-notes-kern-1-10', () => {
    assert.equal(boostForDocument('/release-notes-kern-1-10#mock-an-aggregate-query'), 0.4 * 1.3)
  })
  onPage('/reference/apex/dml-builder', () => {
    assert.equal(boostForDocument('/reference/apex/dml-builder#dml-builder', 'dml', { title: 'DML_Builder' }), 1.25 * 1.3)
  })
})

test('the current page is found with a trailing slash, ".html", the site base and the home page', () => {
  onPage('/web-services-guide/', () => assert.equal(boostForDocument('/web-services-guide#monitoring-api-health'), 1.3, 'Expected a trailing slash to be ignored'))
  onPage('/web-services-guide.html', () => assert.equal(boostForDocument('/web-services-guide#monitoring-api-health'), 1.3, 'Expected ".html" to be ignored'))
  onPage('/kern/web-services-guide', () => {
    assert.equal(boostForDocument('/kern/web-services-guide#monitoring-api-health'), 1.3, 'Expected the same page under a site base')
    assert.equal(boostForDocument('/web-services-guide#monitoring-api-health'), 1, 'Expected a path without the base to be another page')
  })
  onPage('/', () => {
    assert.equal(boostForDocument('/#what-is-kerndx'), 1.3, 'Expected the home page to match itself')
    assert.equal(boostForDocument('/index#what-is-kerndx'), 1.3, 'Expected "/index" to be the home page')
    assert.equal(boostForDocument('/dml-guide#upsert-operations'), 1, 'Expected the home page not to match every page')
  })
})

test('without a browser window the weights do not change', () => {
  assert.equal(typeof globalThis.window, 'undefined')
  assert.equal(boostForDocument('/web-services-guide#monitoring-api-health', 'monitoring', { title: 'Monitoring API Health' }), 1)
  assert.equal(boostForDocument('/release-notes-kern-1-10#mock-an-aggregate-query'), 0.4)
})

test('the current page check still works after the site turns the function into text for the browser', () => {
  const rebuilt = new Function(`return ${browserSourceOf(boostForDocument)}`)()
  onPage('/web-services-guide/', () => {
    assert.equal(rebuilt('/web-services-guide#monitoring-api-health'), 1.3)
    assert.equal(rebuilt('/async-processing-guide#monitoring'), 1)
  })
  assert.equal(rebuilt('/web-services-guide#monitoring-api-health'), 1, 'Expected no change without a browser window')
})

test('boosts From Plain Apex to KernDX over a guide and a Fast Start', () => {
  const plainApex = boostForDocument('/from-plain-apex-to-kerndx#logging')
  assert.ok(plainApex > boostForDocument('/logging-guide#what-problem-does-this-solve'))
  assert.ok(plainApex > boostForDocument('/fast-start-logging'))
  assert.ok(boostForDocument('/1.10/from-plain-apex-to-kerndx') > boostForDocument('/1.10/dml-guide'), 'Expected the same order under a version base')
})

test('the top of a class\'s reference page ranks above a guide section, and an inner class does not', () => {
  const classPage = boostForDocument('/reference/apex/dml-builder#dml-builder', 'dml', { title: 'DML_Builder' })
  assert.ok(classPage > boostForDocument('/security-guide#dml-builder', 'dml', { title: 'DML_Builder' }))
  assert.equal(boostForDocument('/reference/apex/tst-builder-builder#tst-builder-builder', 'tst', { title: 'TST_Builder.Builder' }), 1)
  assert.equal(boostForDocument('/reference/apex/dml-builder#withsystemmode', 'with', { title: 'withSystemMode' }), 1, 'Expected a member section to keep its score')
  assert.equal(boostForDocument('/reference/apex/dml-transaction#dml-transaction', 'unit', { title: 'DML_Transaction' }), 1, 'Expected a word that is not in the name to keep its score')
  assert.ok(boostForDocument('/reference/metadata/maskingrule-mdt#maskingrule-mdt', 'maskingrule', { title: 'MaskingRule__mdt' }) > 1)
  const rebuilt = new Function(`return ${browserSourceOf(boostForDocument)}`)()
  assert.equal(rebuilt('/reference/apex/dml-builder#dml-builder', 'dml', { title: 'DML_Builder' }), classPage)
})

test('the top of a guide or a Fast Start ranks above a section on another page named after its topic', () => {
  const guideTop = boostForDocument('/feature-flags-guide#feature-flags-guide', 'feature', { title: 'Feature Flags - Guide' })
  assert.equal(guideTop, 1.25)
  assert.ok(guideTop > boostForDocument('/utilities-guide#feature-flags', 'feature', { title: 'Feature Flags', titles: ['Utilities - Guide', 'Best Practices'] }))
  assert.equal(boostForDocument('/fast-start-feature-flags#fast-start-feature-flags', 'flags', { title: 'Fast Start - Feature Flags' }), 1.25)
  assert.equal(boostForDocument('/feature-flags-guide#feature-flags-guide', 'toggle', { title: 'Feature Flags - Guide' }), 1, 'Expected a word that is not in the title to keep its score')
  assert.equal(boostForDocument('/feature-flags-guide#framework-owned-flags', 'flags', { title: 'Framework-Owned Flags', titles: ['Feature Flags - Guide'] }), 1, 'Expected a section of the page to keep its score')
  const rebuilt = new Function(`return ${browserSourceOf(boostForDocument)}`)()
  assert.equal(rebuilt('/1.11/feature-flags-guide#feature-flags-guide', 'feature', { title: 'Feature Flags - Guide' }), 1.25, 'Expected the same weight under a version base')
})

test('the pages for AI coding assistants rank below a guide', () => {
  for (const id of ['/ai-agent-instructions#trigger-framework', '/code-conventions-guide#testing']) {
    assert.ok(boostForDocument(id) < boostForDocument('/triggers-guide#quick-start'), `Expected ${id} below a guide`)
  }
})

test('an LWC component inventory section ranks below a how-to section for the same words', () => {
  const howTo = boostForDocument('/lwc-guide#flow-screen-components', 'log', { title: 'Flow Screen Components', titles: ['LWC - Guide'] })
  const inventories = [
    ['/lwc-guide#internal-components-reference', { title: 'Internal Components Reference', titles: ['LWC - Guide'] }],
    ['/lwc-guide#log-console-components', { title: 'Log Console Components', titles: ['LWC - Guide', 'Internal Components Reference'] }],
    ['/1.11/lwc-guide#complete-component-inventory', { title: 'Complete Component Inventory', titles: ['LWC - Guide', 'Appendix: Droppable Components Quick Reference'] }]
  ]
  for (const [id, storedFields] of inventories) {
    assert.equal(boostForDocument(id, 'log', storedFields), 0.5, `Expected ${id} to rank as low as a page for AI coding assistants`)
    assert.ok(boostForDocument(id, 'log', storedFields) < howTo, `Expected ${id} below a how-to section`)
  }
  const sameNameElsewhere = { title: 'Internal Components Reference', titles: ['Triggers - Guide'] }
  assert.equal(boostForDocument('/triggers-guide#internal-components-reference', 'log', sameNameElsewhere), 1, 'Expected only the LWC guide to change')
  const rebuilt = new Function(`return ${browserSourceOf(boostForDocument)}`)()
  const [inventoryId, inventoryFields] = inventories[1]
  assert.equal(rebuilt(inventoryId, 'log', inventoryFields), 0.5)
})

test('the latest build passes the search words through processSearchTerm', () => {
  assert.equal(String(localSearchOptions().miniSearch.searchOptions.processTerm), browserSourceOf(processSearchTerm))
})

test('a search word is looked for in lower case', () => {
  assert.deepEqual(processSearchTerm('QRY_Builder'), ['qry_builder'])
})

test('rollback also looks for the words the pages use, roll back and rolled back', () => {
  assert.deepEqual(processSearchTerm('Rollback'), ['rollback', 'roll', 'rolled'])
})

test('processSearchTerm still works after the site turns it into text for the browser', () => {
  const rebuilt = new Function(`return ${processSearchTerm.toString()}`)()
  assert.deepEqual(rebuilt('rollback'), ['rollback', 'roll', 'rolled'])
  assert.deepEqual(rebuilt('Upsert'), ['upsert'])
})

// A small index searched the way the site's search box searches it: VitePress's own options first,
// then the latest site's options on top.
function searchLikeTheSite(texts, query) {
  const index = new MiniSearch({ fields: ['text'], storeFields: ['text'], ...localSearchOptions().miniSearch.options })
  index.addAll(texts.map((text, id) => ({ id, text })))
  const searchOptions = { fuzzy: 0.2, prefix: true, ...localSearchOptions().miniSearch.searchOptions }
  return index.search(query, searchOptions).map((result) => result.text)
}

const ROLL_PAGES = ['Every save is rolled back.', 'The changes roll back.', 'Assign the role first.', 'A rollup field.', 'The rollout plan.']

test('the words added for rollback find only themselves, not words that start like them', () => {
  const found = searchLikeTheSite(ROLL_PAGES, 'rollback')
  assert.deepEqual([...found].sort(), ['Every save is rolled back.', 'The changes roll back.'])
})

test('a word someone types still finds words that start like it or are spelled a little differently', () => {
  assert.deepEqual([...searchLikeTheSite(ROLL_PAGES, 'roll')].sort(), [...ROLL_PAGES].sort())
  assert.ok(searchLikeTheSite(['Assign the role first.'], 'rple').length === 1, 'Expected one wrong letter to still find "role"')
})

test('the latest build looks for the added words exactly and keeps the default for typed words', () => {
  const { searchOptions } = localSearchOptions().miniSearch
  assert.equal(String(searchOptions.fuzzy), browserSourceOf(canMatchLoosely))
  assert.equal(String(searchOptions.prefix), browserSourceOf(canMatchLoosely))
  assert.equal(canMatchLoosely('rollback', 0, ['rollback', 'roll', 'rolled']), true)
  assert.equal(canMatchLoosely('roll', 1, ['rollback', 'roll', 'rolled']), false)
  assert.equal(canMatchLoosely('roll', 0, ['roll']), true)
})

test('every word processSearchTerm adds is looked for exactly', () => {
  for (const typed of ['rollback', 'queable', 'queuable', 'flag', 'validation']) {
    const terms = processSearchTerm(typed)
    assert.ok(terms.length > 1, `Expected processSearchTerm to add words for "${typed}"`)
    terms.forEach((term, index) => assert.equal(canMatchLoosely(term, index, terms), index === 0, `Expected the right match for "${term}"`))
  }
})

test('canMatchLoosely still works after the site turns it into text for the browser', () => {
  const rebuilt = new Function(`return ${canMatchLoosely.toString()}`)()
  assert.equal(rebuilt('rolled', 2, ['rollback', 'roll', 'rolled']), false)
  assert.equal(rebuilt('upsert', 0, ['upsert']), true)
  assert.equal(rebuilt('a', 1, ['add', 'a', 'field']), false)
})

test('a word of one or two letters is looked for exactly, unless it is the last word typed', () => {
  const terms = ['add', 'a', 'field', 'to', 'one', 'query']
  assert.equal(canMatchLoosely('a', 1, terms), false)
  assert.equal(canMatchLoosely('to', 3, terms), false)
  assert.equal(canMatchLoosely('add', 0, terms), true, 'Expected a word of three letters to keep the default')
  assert.equal(canMatchLoosely('qu', 1, ['soql', 'qu']), true, 'Expected the last word to keep the default: the reader may still be typing it')
  const pages = ['Add a field to one query.', 'Aggregate and async answers, all at once, as an asMap.']
  assert.deepEqual(searchLikeTheSite(pages, 'a field'), ['Add a field to one query.'], 'Expected "a" not to find every word that starts with "a"')
  assert.deepEqual([...searchLikeTheSite(pages, 'field a')].sort(), [...pages].sort(), 'Expected a last word "a" to still find words that start with it')
})

test('a misspelling finds the word it stands for', () => {
  for (const typed of ['queable', 'queuable']) {
    const found = searchLikeTheSite(['Chain queueable jobs.', 'A table of values.'], typed)
    assert.deepEqual(found, ['Chain queueable jobs.'], `Expected "${typed}" to find "queueable"`)
    assert.deepEqual(processSearchTerm(typed), [typed, 'queueable'])
  }
  const rebuilt = new Function(`return ${processSearchTerm.toString()}`)()
  assert.deepEqual(rebuilt('Queable'), ['queable', 'queueable'])
})

test('"flag" also finds "flags"', () => {
  assert.deepEqual(processSearchTerm('Flag'), ['flag', 'flags'])
  const found = searchLikeTheSite(['Feature Flags', 'A table of values.'], 'flag')
  assert.deepEqual(found, ['Feature Flags'])
})

test('"validation" also finds "validations"', () => {
  assert.deepEqual(processSearchTerm('Validation'), ['validation', 'validations'])
  const found = searchLikeTheSite(['Custom Validations', 'A table of values.'], 'validation')
  assert.deepEqual(found, ['Custom Validations'])
})

test('"architect" also finds "architecture"', () => {
  assert.deepEqual(processSearchTerm('Architect'), ['architect', 'architecture'])
  const found = searchLikeTheSite(['Inbound API Architecture', 'A table of values.'], 'architect')
  assert.deepEqual(found, ['Inbound API Architecture'])
})

const END_PAGES = ['E2E Testing', 'The end date of a run.', 'A front end form.', 'A table of values.']

test('the latest build splits the search words with tokenizeSearchWords', () => {
  assert.equal(String(localSearchOptions().miniSearch.searchOptions.tokenize), browserSourceOf(tokenizeSearchWords))
})

test('"end-to-end test" searches for e2e', () => {
  assert.deepEqual(tokenizeSearchWords('End-to-end test'), ['e2e', 'test'])
  assert.deepEqual(searchLikeTheSite(END_PAGES, 'end-to-end test'), ['E2E Testing'])
  const rebuilt = new Function(`return ${tokenizeSearchWords.toString()}`)()
  assert.deepEqual(rebuilt('end-to-end test'), ['e2e', 'test'])
})

test('"end to end" searches for e2e', () => {
  assert.deepEqual(tokenizeSearchWords('end to  end'), ['e2e'])
  assert.deepEqual(searchLikeTheSite(END_PAGES, 'end to end'), ['E2E Testing'])
})

test('"end date" does not search for e2e', () => {
  assert.deepEqual(tokenizeSearchWords('end date'), ['end', 'date'])
  assert.deepEqual(processSearchTerm('end'), ['end'])
  assert.ok(!searchLikeTheSite(END_PAGES, 'end date').includes('E2E Testing'), 'Expected "end date" not to find the E2E page')
})

test('"front end" does not search for e2e', () => {
  assert.deepEqual(tokenizeSearchWords('front end'), ['front', 'end'])
  assert.ok(!searchLikeTheSite(END_PAGES, 'front end').includes('E2E Testing'), 'Expected "front end" not to find the E2E page')
})

// The markdown renderer VitePress uses, so a page's headings get the same ids as on the site.
const vitepressRenderer = await (await import('vitepress')).createMarkdownRenderer('src', {}, '/')

// Splits rendered HTML into one search document per heading, as VitePress's local search does
// (vitepress 1.6.4, splitPageIntoSections): the heading's anchor and the text below it.
function sectionsOf(html) {
  const headingPattern = /<h(\d*).*?>(.*?<a.*? href="#.*?".*?>.*?<\/a>)<\/h\1>/gi
  const parts = html.split(headingPattern)
  parts.shift()
  const sections = []
  for (let i = 0; i < parts.length; i += 3) {
    const heading = /(.*?)<a.*? href="#(.*?)".*?>.*?<\/a>/i.exec(parts[i + 1])
    const title = (heading?.[1] ?? '').replace(/<[^>]*>/g, '').trim()
    if (title && parts[i + 2]) {
      sections.push({ anchor: heading[2], title, text: parts[i + 2].replace(/<[^>]*>/g, '') })
    }
  }
  return sections
}

function indexedSections(source, relativePath = 'dml-guide.md', frozen = false) {
  return sectionsOf(localSearchOptions({ frozen })._render(source, { relativePath }, vitepressRenderer))
}

const TERMS_PAGE = [
  '---',
  'title: "DML - Guide"',
  'searchTerms: {"partial-success": ["allOrNone"]}',
  '---',
  '# DML - Guide',
  '',
  'Save records.',
  '',
  '## Partial Success',
  '',
  'Save the good rows and report the bad ones.',
  '',
  '## Upsert',
  '',
  'Insert or update.',
  ''
].join('\n')

test('a section\'s searchTerms words are indexed in that section', () => {
  const sections = indexedSections(TERMS_PAGE)
  const partial = sections.find((section) => section.anchor === 'partial-success')
  assert.match(partial.text, /\ballOrNone\b/, 'Expected the word in the section it was given to')
  for (const other of sections.filter((section) => section.anchor !== 'partial-success')) {
    assert.doesNotMatch(other.text, /allOrNone/, `Expected the word only in its own section, not in "${other.title}"`)
  }
})

test('searchTerms words are not rendered on the page', () => {
  const page = vitepressRenderer.render(TERMS_PAGE, { relativePath: 'dml-guide.md' })
  assert.doesNotMatch(page, /allOrNone/)
})

test('a page without searchTerms is unchanged', () => {
  const page = TERMS_PAGE.replace(/^searchTerms: .*\n/m, '')
  const rendered = localSearchOptions()._render(page, { relativePath: 'dml-guide.md' }, vitepressRenderer)
  assert.equal(rendered, vitepressRenderer.render(indexableSource(page, 'dml-guide.md'), { relativePath: 'dml-guide.md' }))
  assert.deepEqual(searchTermsOf(page), new Map())
})

test('a frozen page ignores searchTerms', () => {
  for (const section of indexedSections(TERMS_PAGE, 'dml-guide.md', true)) {
    assert.doesNotMatch(section.text, /allOrNone/)
  }
})

test('searchTermsOf reads the words for each heading id', () => {
  assert.deepEqual(searchTermsOf(TERMS_PAGE), new Map([['partial-success', ['allOrNone']]]))
  assert.throws(() => searchTermsOf('---\nsearchTerms: ["allOrNone"]\n---\n# Page\n'), /searchTerms/)
})

test('a heading that holds a link stays in the index with its whole text', () => {
  const page = '# Utilities - Guide\n\n## [Invocable Methods](https://example.com/invocable) for Flows\n\nCall Apex from a flow.\n\n## Apex Logging ([`LOG_Builder`](reference/apex/LOG_Builder.md))\n\nLog an error.\n'
  const titles = indexedSections(page, 'utilities-guide.md').map((section) => section.title)
  assert.ok(titles.includes('Invocable Methods for Flows'), `Expected the heading that starts with a link to be indexed, got ${JSON.stringify(titles)}`)
  assert.ok(titles.includes('Apex Logging (LOG_Builder)'), `Expected the whole heading text, got ${JSON.stringify(titles)}`)
  const ids = indexedSections(page, 'utilities-guide.md').map((section) => section.anchor)
  assert.deepEqual(ids, sectionHeadingsOf(page).map((heading) => heading.id), 'Expected the same anchors as on the page')
})

// One page as checkSearchTerms reads it, and the search cases it checks the words against.
function checkedPages(searchTerms) {
  const source = TERMS_PAGE.replace(/^searchTerms: .*$/m, `searchTerms: ${JSON.stringify(searchTerms)}`)
  return [
    { name: 'dml-guide.md', source },
    { name: 'selectors-guide.md', source: '# Selectors - Guide\n\n## Bulk Insert\n\nText.\n' }
  ]
}

const ALL_OR_NONE_CASE = { query: 'allOrNone', kind: 'vocabulary', expected: ['DML - Guide > Partial Success'], accepted: [] }

test('words that name their section and have a search case pass the check', () => {
  assert.deepEqual(checkSearchTerms(checkedPages({ 'partial-success': ['allOrNone'] }), [ALL_OR_NONE_CASE]), [])
})

test('a key that matches no heading fails the build', () => {
  const problems = checkSearchTerms(checkedPages({ 'no-such-heading': ['allOrNone'] }), [ALL_OR_NONE_CASE])
  assert.equal(problems.length, 1)
  assert.match(problems[0], /no-such-heading/)
  assert.throws(() => withSearchTerms('<h2 id="upsert" tabindex="-1">Upsert</h2>', new Map([['partial-success', ['allOrNone']]])), /partial-success/)
})

test('a term already in a heading on the site fails the build', () => {
  const problems = checkSearchTerms(checkedPages({ 'partial-success': ['bulk insert'] }), [{ ...ALL_OR_NONE_CASE, query: 'bulk insert' }])
  assert.equal(problems.length, 1)
  assert.match(problems[0], /"bulk insert".*Selectors - Guide > Bulk Insert/)
})

test('a term with no search case fails the build', () => {
  const problems = checkSearchTerms(checkedPages({ 'partial-success': ['allOrNone'] }), [{ ...ALL_OR_NONE_CASE, expected: ['DML - Guide > Upsert'] }])
  assert.equal(problems.length, 1)
  assert.match(problems[0], /"allOrNone".*no search case/)
  assert.equal(checkSearchTerms(checkedPages({ 'partial-success': ['allOrNone'] }), []).length, 1)
})

test('the same term on two sections fails the build unless its case accepts both', () => {
  const both = { 'partial-success': ['allOrNone'], upsert: ['allOrNone'] }
  assert.equal(checkSearchTerms(checkedPages(both), [ALL_OR_NONE_CASE]).length, 1)
  assert.deepEqual(checkSearchTerms(checkedPages(both), [{ ...ALL_OR_NONE_CASE, accepted: ['DML - Guide > Upsert'] }]), [])
})

test('more than eight terms on a section or 24 on a page fails the build', () => {
  assert.equal(SEARCH_TERMS_PER_SECTION, 8)
  assert.equal(SEARCH_TERMS_PER_PAGE, 24)
  const words = (count, prefix) => Array.from({ length: count }, (_, index) => `${prefix}${index}`)
  const page = (terms) => `---\nsearchTerms: ${JSON.stringify(terms)}\n---\n# Page\n`
  assert.equal(searchTermsOf(page({ a: words(8, 'a') })).get('a').length, 8)
  assert.throws(() => searchTermsOf(page({ a: words(9, 'a') })), /more than 8/)
  assert.equal(searchTermsOf(page({ a: words(8, 'a'), b: words(8, 'b'), c: words(8, 'c') })).size, 3)
  assert.throws(() => searchTermsOf(page({ a: words(8, 'a'), b: words(8, 'b'), c: words(8, 'c'), d: ['d'] })), /more than 24/)
})

test('a case that names only the page does not cover a word given to one section of it', () => {
  const problems = checkSearchTerms(checkedPages({ 'partial-success': ['allOrNone'] }), [{ ...ALL_OR_NONE_CASE, expected: [], accepted: ['DML - Guide'] }])
  assert.equal(problems.length, 1, `Expected the page-only case not to name the section, got ${JSON.stringify(problems)}`)
  assert.match(problems[0], /"allOrNone".*no search case/)
})

test('a case that names only the page covers a word given to the page title', () => {
  const problems = checkSearchTerms(checkedPages({ 'dml-guide': ['allOrNone'] }), [{ ...ALL_OR_NONE_CASE, expected: ['DML - Guide'] }])
  assert.deepEqual(problems, [])
})

test('a heading link whose address holds brackets, or a reference-style link, keeps only its text', () => {
  const page = '# Guide\n\n## Read [the limits](https://example.com/limits_(apex)) first\n\nText.\n\n## See [Selectors][selectors] and [Triggers][]\n\nText.\n\n[selectors]: selectors-guide.md\n[Triggers]: triggers-guide.md\n'
  const headings = sectionHeadingsOf(page).map((heading) => heading.text)
  assert.deepEqual(headings, ['Guide', 'Read the limits first', 'See Selectors and Triggers'])
  const titles = indexedSections(page, 'guide.md').map((section) => section.title)
  assert.ok(titles.includes('Read the limits first'), `Expected the whole heading text, got ${JSON.stringify(titles)}`)
})

// The site also finds a word that starts like the one typed, so a search for "flag" finds "Flags"
// with no pair at all. These searches turn that off for the typed word, so only the pair can find it.
function searchExactly(texts, query) {
  const index = new MiniSearch({ fields: ['text'], storeFields: ['text'], ...localSearchOptions().miniSearch.options })
  index.addAll(texts.map((text, id) => ({ id, text })))
  const { processTerm, tokenize } = localSearchOptions().miniSearch.searchOptions
  return index.search(query, { processTerm, tokenize, prefix: false, fuzzy: false }).map((result) => result.text)
}

test('the "flag", "validation" and "architect" pairs find the longer word on their own', () => {
  const pairs = [['flag', 'Feature Flags'], ['validation', 'Custom Validations'], ['architect', 'Inbound API Architecture']]
  for (const [typed, title] of pairs) {
    assert.deepEqual(searchExactly([title, 'A table of values.'], typed), [title], `Expected the pair for "${typed}" to find "${title}"`)
  }
})
