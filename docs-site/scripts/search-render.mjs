// SPDX-License-Identifier: Apache-2.0
// What the site's search box indexes, and how it ranks the pages it finds.
//
// config.mjs takes its local search options from localSearchOptions(): every page goes through
// indexableSource() before VitePress renders it for the search index, and the latest site passes
// boostForDocument(), tokenizeForSearch(), processSearchTerm() and canMatchLoosely() to MiniSearch.
//
// A page can also give a section extra search words in its frontmatter, `searchTerms`: a JSON
// object of heading id to words, on one line, such as
//   searchTerms: {"partial-success": ["allOrNone"]}
// The words go into that section's search document only (VitePress splits each page into one
// search document per heading); they are never shown on the page. They are for words a reader
// types that the section answers but never says in its prose, such as a word that appears only
// in its code. prepare.mjs runs checkSearchTerms() over every page and stops the build when a
// word is misplaced.
import { createRequire } from 'node:module'
import { fileURLToPath } from 'node:url'
import {slugifyHeading} from './anchor-normalizer.mjs'
import {parseFrontmatter} from './frontmatter.mjs'

// The most search words one section may have, and one page.
export const SEARCH_TERMS_PER_SECTION = 8
export const SEARCH_TERMS_PER_PAGE = 24

// A fenced code block. The closing fence uses the same character as the opener and is at least
// as long (CommonMark): group 2 is the fence character, so the close is the opener (\1) followed
// by zero or more of that character (\2*). A bare \1 (exact length) would leave a block closed by
// a longer fence in the index.
const FENCED_CODE = /^ {0,3}(([`~])\2{2,})[\s\S]*?^ {0,3}\1\2*\s*$/gm
const FRONTMATTER = /^---\n[\s\S]*?\n---\n/
const FIRST_SECTION = /^## /m
const SECTION_HEADING = /^#{2,6} /

// The label that opens a "Plain Apex" sample: the familiar code a page shows before the KernDX
// version of it.
const PLAIN_APEX_LABEL = '// Plain Apex'

// Removes the frontmatter and every fenced code block. The corpus is code-heavy, and indexing
// the code made the search index several times larger without helping anyone find a page.
// Outside a frozen build, a block whose first line is exactly "// Plain Apex" stays: it is a few
// lines of the Apex a reader already writes ("System.debug", "insert account"), so its words are
// the words that reader types into the search box.
function withoutCode(markdown, { keepPlainApex = false } = {}) {
  const keep = (block) => (keepPlainApex && isPlainApexSample(block) ? block : '')
  return markdown.replace(FRONTMATTER, '').replace(FENCED_CODE, keep)
}

function isPlainApexSample(block) {
  return (block.split('\n')[1] ?? '').trim() === PLAIN_APEX_LABEL
}

// The part of a generated API reference page that goes into the search index: the text above the
// first "## " section (the class heading, its kind and its summary), then every "##" to "######"
// heading below it, and nothing else. A member heading such as "### withSystemMode" is how a
// reader finds a method by name. The member's own text, its parameter tables and its code stay
// out: the reference pages are most of the corpus, and their full text would make the index about
// 1 MB larger. Every heading is kept, in page order and word for word, so each one gets the same
// anchor as on the page (a repeated heading such as an overloaded method is numbered by its place,
// and an overload heading such as "### Builder(SObjectType sObjectType)" keeps its brackets).
// A page with no "## " section, such as a trigger's, is small and stays whole.
export function indexableReferenceSource(markdown) {
  const source = withoutCode(markdown)
  const match = FIRST_SECTION.exec(source)
  if (!match) {
    return source
  }
  const summary = source.slice(0, match.index)
  const headings = source.slice(match.index).split('\n').filter((line) => SECTION_HEADING.test(line))
  return `${summary}${headings.join('\n\n')}\n`
}

// The text indexed for one page: code and frontmatter removed from every page (except a
// "// Plain Apex" sample), and a reference page (under reference/) cut down to its summary and
// headings. In a frozen build (an older version of the site, such as /1.10/) every code block goes,
// and a reference page keeps only the text above its first "## " section and no headings, so the
// older versions' search stays as it was.
// Outside a frozen build, a link in a heading is replaced by its text. VitePress's search takes a
// section's title from the heading text before the first link in it, so "## [Invocable Methods](…)
// for Flows" had no title and its section was left out of the index, and "## Apex Logging
// ([`LOG_Builder`](…))" was indexed as "Apex Logging (". The heading's id does not change: it is made
// from the link's text, never from its address.
export function indexableSource(markdown, relativePath, { frozen = false } = {}) {
  if (!(relativePath ?? '').startsWith('reference/')) {
    const source = withoutCode(markdown, { keepPlainApex: !frozen })
    return frozen ? source : withoutHeadingLinks(source)
  }
  return frozen ? withoutCode(markdown).split(FIRST_SECTION)[0] : indexableReferenceSource(markdown)
}

const HEADING_LINE = /^ {0,3}#{1,6}\s.*$/gm
// A link that is not an image: "[text](address)", where the address may hold one pair of brackets
// ("limits_(apex)"), or a reference-style link, "[text][name]" or "[text][]".
const INLINE_LINK = /(?<!!)\[([^\]]*)\](?:\((?:[^()]|\([^()]*\))*\)|\[[^\]]*\])/g

function withoutHeadingLinks(source) {
  return source.replace(HEADING_LINE, (line) => line.replace(INLINE_LINK, '$1'))
}

// Reads a page's searchTerms frontmatter (see the top of this file) from its raw source, as a map
// of heading id to words. A page without it gives an empty map. Throws when the value is not a
// JSON object of lists of words, or when a section has more than SEARCH_TERMS_PER_SECTION words or
// the page more than SEARCH_TERMS_PER_PAGE.
export function searchTermsOf(source) {
  const value = parseFrontmatter(source ?? '').data.searchTerms
  if (value == null || value === '') {
    return new Map()
  }
  let parsed = null
  try {
    parsed = JSON.parse(value)
  } catch {
    parsed = null
  }
  const isWordList = (words) => Array.isArray(words) && words.every((word) => typeof word === 'string' && word.trim() !== '')
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed) || !Object.values(parsed).every(isWordList)) {
    throw new Error(`searchTerms is not a JSON object of "heading-id": ["word", ...] pairs: ${value}`)
  }
  const terms = new Map(Object.entries(parsed))
  for (const [id, words] of terms) {
    if (words.length > SEARCH_TERMS_PER_SECTION) {
      throw new Error(`searchTerms gives the heading "${id}" ${words.length} words, more than ${SEARCH_TERMS_PER_SECTION}`)
    }
  }
  const total = [...terms.values()].reduce((sum, words) => sum + words.length, 0)
  if (total > SEARCH_TERMS_PER_PAGE) {
    throw new Error(`searchTerms gives the page ${total} words, more than ${SEARCH_TERMS_PER_PAGE}`)
  }
  return terms
}

const RENDERED_HEADING = /<h([1-6]) id="([^"]*)"[^>]*>[\s\S]*?<\/h\1>/g

// Adds each section's search words to the HTML that VitePress indexes, as a paragraph right after
// the section's heading, so they land in that section's search document. Throws when a heading id
// in `terms` is not on the page.
export function withSearchTerms(html, terms) {
  if (!terms.size) {
    return html
  }
  const placed = new Set()
  const result = html.replace(RENDERED_HEADING, (heading, level, id) => {
    const words = terms.get(id)
    if (!words) {
      return heading
    }
    placed.add(id)
    return `${heading}\n<p>${words.map(escapeHtml).join(' ')}</p>\n`
  })
  const missing = [...terms.keys()].filter((id) => !placed.has(id))
  if (missing.length) {
    throw new Error(`searchTerms names a heading id that is not on the page: ${missing.join(', ')}`)
  }
  return result
}

function escapeHtml(text) {
  return text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
}

// The ATX headings ("## Title") of a page outside its code, in page order, with the id VitePress
// gives each one (an explicit "{#id}" is kept; a repeated id gets "-1", "-2" as on the page) and the
// titles of the headings above it.
export function sectionHeadingsOf(markdown) {
  const headings = []
  const used = new Set()
  const path = []
  for (const line of withoutCode(markdown).split('\n')) {
    const match = line.match(/^ {0,3}(#{1,6})\s+(.*?)\s*$/)
    if (!match) {
      continue
    }
    const level = match[1].length
    const raw = match[2].replace(/\s+#+\s*$/, '')
    const explicit = raw.match(/\{#([^}]+)\}\s*$/)
    const text = raw.replace(/\{#[^}]+\}\s*$/, '').replace(INLINE_LINK, '$1').replace(/`+/g, '').replace(/\*+/g, '').trim()
    let id = explicit ? explicit[1] : slugifyHeading(text)
    if (!id) {
      continue
    }
    for (let suffix = 1, base = id; used.has(id); suffix++) {
      id = `${base}-${suffix}`
    }
    used.add(id)
    path.length = level - 1
    path[level - 1] = text
    headings.push({ level, text, id, titles: path.filter(Boolean) })
  }
  return headings
}

// The words of a phrase as the search index splits them, in lower case, joined by single spaces.
function wordsOf(text) {
  return tokenizeForSearch(String(text)).filter(Boolean).map((word) => word.toLowerCase()).join(' ')
}

function containsPhrase(text, phrase) {
  return ` ${text} `.includes(` ${phrase} `)
}

// True when a search case string ("Page > Heading", headings optional and at any depth) names the
// section whose page title and headings are `titles`, by the rule search-test.mjs uses.
function namesSection(wanted, titles) {
  const normalise = (text) => text.replace(/\s+/g, ' ').trim().toLowerCase()
  const matches = (want, actual) => actual === want || actual.startsWith(`${want} `)
  const [wantedPage, ...wantedHeadings] = wanted.split(' > ').map(normalise).filter(Boolean)
  const [page, ...headings] = titles.map(normalise)
  if (!wantedPage || !page || !matches(wantedPage, page)) {
    return false
  }
  let next = 0
  for (const heading of headings) {
    if (next < wantedHeadings.length && matches(wantedHeadings[next], heading)) {
      next++
    }
  }
  return next === wantedHeadings.length
}

// Checks every page's searchTerms against the whole site and the search cases, and returns one
// line for each problem (none when all is well). A search word must be on a heading the page has,
// must not already be in any heading on the site (that section is found by its title already, and a
// hidden word in a short section can outrank a long section that uses the word in its prose), and
// must have a search case: a case whose search contains the word and which names the section, as
// expected or accepted. A word on more than one section needs one case that names them all.
// `pages` is a list of {name, source}, the page's file name and its raw text; `cases` is the list in
// search-cases.json.
export function checkSearchTerms(pages, cases) {
  const problems = []
  const headingsByPage = pages.map((page) => ({ page, headings: sectionHeadingsOf(page.source) }))
  const siteHeadings = headingsByPage.flatMap(({ headings }) => headings.map((heading) => ({ words: wordsOf(heading.text), label: heading.titles.join(' > ') })))
  const sectionsByTerm = new Map()
  for (const { page, headings } of headingsByPage) {
    let terms
    try {
      terms = searchTermsOf(page.source)
    } catch (error) {
      problems.push(`${page.name}: ${error.message}`)
      continue
    }
    for (const [id, words] of terms) {
      const heading = headings.find((candidate) => candidate.id === id)
      if (!heading) {
        problems.push(`${page.name}: searchTerms names the heading id "${id}", which is not on the page`)
        continue
      }
      for (const word of words) {
        const phrase = wordsOf(word)
        const inHeading = siteHeadings.find((candidate) => containsPhrase(candidate.words, phrase))
        if (inHeading) {
          problems.push(`${page.name}: the search word "${word}" is already in the heading ${inHeading.label}`)
          continue
        }
        const sections = sectionsByTerm.get(phrase) ?? { word, places: [] }
        sections.places.push({ name: page.name, titles: heading.titles })
        sectionsByTerm.set(phrase, sections)
      }
    }
  }
  for (const [phrase, { word, places }] of sectionsByTerm) {
    const pairs = cases.filter((searchCase) => containsPhrase(wordsOf(searchCase.query), phrase))
    // A case that names only the page ("DML - Guide") accepts any section of it, so it does not show
    // that the word finds the one section it was given to. It covers a word on the page title only.
    const namesPlace = (wanted, titles) => namesSection(wanted, titles) && (titles.length === 1 || wanted.includes(' > '))
    const covers = (searchCase) => places.every(({ titles }) => [...(searchCase.expected ?? []), ...(searchCase.accepted ?? [])].some((wanted) => namesPlace(wanted, titles)))
    if (!pairs.some(covers)) {
      const where = places.map(({ name, titles }) => `${name} (${titles.join(' > ')})`).join(' and ')
      problems.push(`the search word "${word}" on ${where} has no search case that searches for it and names ${places.length > 1 ? 'every one of those sections' : 'that section'}`)
    }
  }
  return problems
}

// The options for VitePress's local search. The latest site indexes member headings and
// "// Plain Apex" samples, ranks release notes and strategic guides lower and From Plain Apex to
// KernDX higher, ranks results on the reader's current page higher, counts a repeated title word once, and adds the pages' words for a few search
// words (processSearchTerm), looked for exactly (canMatchLoosely). A frozen build (an older version of the site) gets none of these, so
// its search works as it did before.
export function localSearchOptions({ frozen = false } = {}) {
  const options = {
    _render(source, env, md) {
      const html = md.render(indexableSource(source, env?.relativePath, { frozen }), env)
      return frozen ? html : withSearchTerms(html, searchTermsOf(source))
    }
  }
  if (!frozen) {
    options.miniSearch = {
      options: { tokenize: inBrowserForm(tokenizeForSearch) },
      searchOptions: {
        tokenize: inBrowserForm(tokenizeSearchWords),
        boostDocument: inBrowserForm(boostForDocument),
        processTerm: inBrowserForm(processSearchTerm),
        fuzzy: inBrowserForm(canMatchLoosely),
        prefix: inBrowserForm(canMatchLoosely)
      }
    }
  }
  return options
}

// VitePress sends each search function to the browser as its source text: it writes the text
// (the function's toString()) into the site data on every page, and every page downloads it
// before it can show anything (scripts/artifact-audit.mjs keeps that data under a budget). The
// source, with its indents, long names and the same word list in three functions, cost about
// 3.7 KB per page. browserSourceOf() gives the same function minified by esbuild (the tool Vite
// itself uses, so it is always installed with VitePress): about 2.2 KB, and the same answers.
// The text is made once per function.
const browserSources = new Map()
const BROWSER_SOURCE_PREFIX = 'globalThis.searchFunction='

export function browserSourceOf(fn) {
  if (!browserSources.has(fn)) {
    const requireFromHere = createRequire(import.meta.url)
    const requireFromVite = createRequire(requireFromHere.resolve('vite', { paths: [fileURLToPath(import.meta.resolve('vitepress'))] }))
    // esbuild is reached through Vite (pinned by docs-site/package-lock.json), so a VitePress or Vite upgrade that drops it fails the build loudly.
    const { transformSync } = requireFromVite('esbuild')
    const code = transformSync(`${BROWSER_SOURCE_PREFIX}(${fn.toString()})`, { minify: true, loader: 'js', target: 'es2020' }).code.trim().replace(/;$/, '')
    if (!code.startsWith(BROWSER_SOURCE_PREFIX)) {
      throw new Error(`esbuild did not keep ${fn.name} as one assignment, so its browser text cannot be cut out: ${code.slice(0, 80)}`)
    }
    browserSources.set(fn, code.slice(BROWSER_SOURCE_PREFIX.length))
  }
  return browserSources.get(fn)
}

// A copy of a search function for the search options: in Node it runs the function itself, and
// its text (what VitePress sends to the browser) is browserSourceOf(fn).
function inBrowserForm(fn) {
  const copy = (...args) => fn(...args)
  const source = browserSourceOf(fn)
  copy.toString = () => source
  return copy
}

// Splits a field into the words MiniSearch indexes. It splits as MiniSearch does by default (on
// spaces and punctuation, so "QRY_Builder" is "QRY" and "Builder"), except that a word repeated in a
// result's title counts once. Without that, "QRY_Builder.Builder" has "Builder" twice and ranks
// above "QRY_Builder" for the search "QRY_Builder", only because the inner class repeats the name.
//
// VitePress sends this function to the browser as its source text and rebuilds it there, so it
// must not use anything defined outside its own body. In the browser it splits only the search
// words, which it is never given a field name for.
export function tokenizeForSearch(text, fieldName) {
  const words = text.split(/[\n\r\p{Z}\p{P}]+/u)
  if (fieldName !== 'title') {
    return words
  }
  const seen = new Set()
  return words.filter((word) => {
    const key = word.toLowerCase()
    if (seen.has(key)) {
      return false
    }
    seen.add(key)
    return true
  })
}

// Splits the words typed into the search box, as tokenizeForSearch() does. First it turns the
// phrase "end-to-end" (or "end to end") into "e2e", the word the end-to-end testing pages use in
// their titles. Only the whole phrase changes: "end date" and "front end" still search for "end".
// The index is not changed; this runs only on what the reader types.
//
// VitePress sends this function to the browser as its source text and rebuilds it there, so it
// must not use anything defined outside its own body.
export function tokenizeSearchWords(text) {
  return String(text).replace(/\bend[-\s]+to[-\s]+end\b/giu, 'e2e').split(/[\n\r\p{Z}\p{P}]+/u)
}

// Turns one word typed into the search box into the words to look for. Every word is looked for
// in lower case, as MiniSearch does by default. A few words that developers type as one word but
// the pages write as two get the pages' words as well: "rollback" also finds "roll back" and
// "rolled back". Two common misspellings of "queueable" ("queable" and "queuable") also find
// "queueable": the search box's loose match does not find it for "queable" (two letters short),
// and finds it for "queuable" only among other loose matches. A few words also find the form the
// page titles use: "flag" finds "flags", "validation" finds "validations" and "architect" finds "architecture" ("end-to-end" is
// handled before this, by tokenizeSearchWords()). The list is short on purpose: a word joins it
// only when a search for it found nothing useful, and only with words that mean the same thing. A general rule that every word
// also finds its plural made other searches worse, so each pair is listed by hand.
//
// VitePress sends this function to the browser as its source text and rebuilds it there, so it
// must not use anything defined outside its own body. canMatchLoosely() below keeps the same list.
export function processSearchTerm(term) {
  const word = term.toLowerCase()
  const sameMeaning = {
    rollback: ['roll', 'rolled'],
    queable: ['queueable'],
    queuable: ['queueable'],
    flag: ['flags'],
    validation: ['validations'],
    architect: ['architecture']
  }
  return [word, ...(sameMeaning[word] ?? [])]
}

// Decides whether one search word may also find words that start with it or are spelled a little
// differently, as VitePress allows for every word by default. A word that processSearchTerm() added
// for another word may not: "roll", added for "rollback", must find "roll" and not "role", "rollup"
// or "rollout". MiniSearch asks this for each word, with the list of all the words it looks for, and
// a true answer keeps VitePress's default (one wrong letter in five, and any ending).
//
// A word of one or two letters ("a", "to", "on") is looked for exactly too, unless it is the last
// word typed. "a" would otherwise find every word that starts with "a", and a long section with
// many such words ("aggregate", "asMap") would outrank the short section the reader wants, as
// "add a field to one query" did. The last word keeps the default because the reader may still be
// typing it.
//
// VitePress sends this function to the browser as its source text and rebuilds it there, so it
// must not use anything defined outside its own body. Its list is the one in processSearchTerm().
export function canMatchLoosely(term, index, terms) {
  const sameMeaning = {
    rollback: ['roll', 'rolled'],
    queable: ['queueable'],
    queuable: ['queueable'],
    flag: ['flags'],
    validation: ['validations'],
    architect: ['architecture']
  }
  if (term.length <= 2 && index < terms.length - 1) {
    return false
  }
  return !terms.slice(0, index).some((earlier) => (sameMeaning[earlier] ?? []).includes(term))
}

// How much MiniSearch raises or lowers a search result, chosen by the page it belongs to. The id
// is the result's path, with the site's base and an optional "#anchor" (for example
// "/release-notes-kern-1-10#mock-an-aggregate-query"). Guides, Fast Starts and reference pages,
// the pages that show how to do something, keep their score; strategic guides, which explain why,
// and release notes, which record what changed, rank lower, so a word that appears in both finds
// the how-to page first. From Plain Apex to KernDX ranks higher: it is where a reader who types
// plain Apex words ("system.debug", "insert records", "aggregate") should start, and each of its
// sections links on to the Fast Start and the guide.
//
// The pages written for AI coding assistants (AI Agent Instructions and the code conventions)
// rank as low as a strategic guide: they name every class too, and a person searching wants the
// guide. So do the LWC guide's lists of its components ("Internal Components Reference",
// "Complete Component Inventory" and every section under them): they name each component, and the
// reader wants the section that shows how to use it. The top of a reference page for a class, object or metadata type ranks higher for a search
// word that is part of its name, so a search for its exact name ("DML_Builder") finds its own page
// before a guide section with the same heading, and other searches ("unit of work") are not
// changed. An inner class ("TST_Builder.Builder", whose title has a dot) is left as it is, so it does
// not outrank its outer class. The top of any guide-style page (outside the reference pages) ranks
// higher in the same way for a word of its title, so a search for "feature flag" finds the Feature
// Flags guide before a short "Feature Flags" section of another guide. MiniSearch calls this once for
// each search word, with the word and the result's stored fields; the title is the page or heading
// title the search box shows.
//
// A result on the page the reader is searching from ranks 1.3 times higher, on top of the weights
// above. A search for "monitoring" on the Web Services guide then lists that guide's own sections
// first. A section of the current page still needs about three quarters of the best result's score
// to pass it, so a much better match on another page stays first. In the browser the current page
// comes from the address bar; the address and the result's path both carry the site's base, and
// both lose a trailing "/", ".html" or "/index" before they are compared. Without a browser
// window (in Node) nothing changes.
//
// VitePress sends this function to the browser as its source text and rebuilds it there, so it
// must not use anything defined outside its own body (a constant above would be undefined).
export function boostForDocument(id, term, storedFields) {
  const [path, anchor] = String(id).split('#')
  const page = path.split('/').pop()
  const pathOf = (address) => String(address).replace(/\.html$/, '').replace(/\/+$/, '').replace(/\/index$/, '')
  const isCurrentPage = typeof window !== 'undefined' && pathOf(window.location?.pathname ?? '') === pathOf(path)
  const currentPageFactor = isCurrentPage ? 1.3 : 1
  if (page === 'from-plain-apex-to-kerndx') {
    return 1.5 * currentPageFactor
  }
  if (page.startsWith('release-notes-')) {
    return 0.4 * currentPageFactor
  }
  if (page.startsWith('strategic-guide-') || page === 'ai-agent-instructions' || page === 'code-conventions-guide') {
    return 0.5 * currentPageFactor
  }
  const title = String(storedFields?.title ?? '')
  const headings = [title, ...(storedFields?.titles ?? [])]
  if (page === 'lwc-guide' && headings.some((heading) => heading === 'Internal Components Reference' || heading === 'Complete Component Inventory')) {
    return 0.5 * currentPageFactor
  }
  const isTitleWord = title.toLowerCase().split(/[^a-z0-9]+/).includes(String(term).toLowerCase())
  if (path.includes('/reference/') && anchor === page && !title.includes('.') && isTitleWord) {
    return 1.25 * currentPageFactor
  }
  if (!path.includes('/reference/') && anchor === page && isTitleWord) {
    return 1.25 * currentPageFactor
  }
  return currentPageFactor
}
