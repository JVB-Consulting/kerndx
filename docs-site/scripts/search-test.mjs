// SPDX-License-Identifier: Apache-2.0
// Search test. Serves the built site (.vitepress/dist) with `vitepress preview`, types each search
// from search-cases.json into the site's search box with @playwright/test's chromium, and checks the
// top results.
//
// A result is named by its page title and headings, joined by ' > ', the way the search box labels
// it ('Selectors - Guide > Aggregate Functions'). A case string names a page, then optionally
// headings on that page. It matches a result when the page is the same and each heading appears
// in the result in the same order, at any depth. Names are compared as whole words, ignoring case:
// 'QRY_Builder' does not match 'QRY_Builder.Builder', but 'Transactional DML Pattern' matches
// 'Transactional DML Pattern (DML_Builder)'.
//
// An exact case (a class or method name) passes when an expected result is first. A vocabulary case
// (a word a developer would type) passes when an expected result is first, or when an accepted
// result is in the top three.
//
// A case may name a `page` (such as "/web-services-guide"). The test then opens that page before it
// searches, because the search box ranks results on the reader's current page higher. A case with
// no page searches from the home page.
//
// Usage, after `npm run build`:
//   node scripts/search-test.mjs                  exits 1 if any case fails, and prints the top
//                                                 four results of each failing case with their scores
//   node scripts/search-test.mjs --report <file>  writes every case's top three to <file>, exits 0
//
// The browser does not show scores, so they come from the built search index, loaded with
// MiniSearch (the copy VitePress installs) and searched with the same options as the search box.
import {spawn} from 'node:child_process';
import {readdir, readFile, writeFile} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';
import {setTimeout as sleep} from 'node:timers/promises';
import MiniSearch from 'minisearch';
import {localSearchOptions} from './search-render.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const TOP = 3;
const POSITION_WORDS = ['first', 'second', 'third'];
const SCORED_RESULTS_SHOWN = 4;

// What VitePress 1.6.4's search box (VPLocalSearchBox.vue) passes to MiniSearch before the site's own
// options are added on top.
const SEARCH_BOX_FIELDS = {fields: ['title', 'titles', 'text'], storeFields: ['title', 'titles']};
const SEARCH_BOX_SEARCH_OPTIONS = {fuzzy: 0.2, prefix: true, boost: {title: 4, text: 2, titles: 1}};

/**
 * Builds the MiniSearch options the latest site's search box uses.
 * @returns {object} options for MiniSearch.loadJSON, with the search options inside
 */
export function searchBoxOptions()
{
	const site = localSearchOptions().miniSearch ?? {};
	return {...SEARCH_BOX_FIELDS, searchOptions: {...SEARCH_BOX_SEARCH_OPTIONS, ...site.searchOptions}, ...site.options};
}

/**
 * Names the page a case searches from. A case with no `page` searches from the home page.
 * @param {{page?: string}} searchCase - one case from search-cases.json
 * @returns {string} the page's path without the site base, such as '/' or '/web-services-guide'
 */
export function pageOf(searchCase)
{
	return searchCase.page ?? '/';
}

/**
 * Searches an index and names the first results the way the search box does, with their scores.
 * The search box ranks results on the reader's current page higher, and finds that page in the
 * browser's address bar. Give `pathname` to search as if the reader were on that page: a stand-in
 * address bar is set for the search and removed again after it.
 * @param {MiniSearch} index - an index whose documents store `title` and `titles`
 * @param {string} query - the words to search for
 * @param {number} count - how many results to return
 * @param {string} [pathname] - the address of the page the reader searches from, base included
 * @returns {Array<{label: string, score: number}>} the best results first
 */
export function scoredResults(index, query, count, pathname)
{
	const hadWindow = 'window' in globalThis;
	if(pathname !== undefined && !hadWindow)
	{
		globalThis.window = {location: {pathname}};
	}
	try
	{
		return index.search(query).slice(0, count).map(result => ({label: [...(result.titles ?? []), result.title].join(' > '), score: result.score}));
	}
	finally
	{
		if(pathname !== undefined && !hadWindow)
		{
			delete globalThis.window;
		}
	}
}

/**
 * Writes scored results as indented lines, one result per line, for a failing case's log.
 * @param {Array<{label: string, score: number}>} results - the best results first
 * @returns {string} lines such as '    1. 58.5  DML - Guide > Insert Operations'
 */
export function formatScoredResults(results)
{
	return results.map((result, position) => `    ${position + 1}. ${result.score.toFixed(1)}  ${result.label}`).join('\n');
}

async function loadBuiltIndex()
{
	const chunks = path.join(ROOT, '.vitepress', 'dist', 'assets', 'chunks');
	const file = (await readdir(chunks)).find(name => name.startsWith('@localSearchIndexroot.'));
	if(!file)
	{
		throw new Error(`no search index in ${chunks}`);
	}
	const {default: json} = await import(pathToFileURL(path.join(chunks, file)).href);
	return MiniSearch.loadJSON(json, searchBoxOptions());
}

function normalise(text)
{
	return text.replace(/\s+/g, ' ').trim().toLowerCase();
}

function segmentsOf(label)
{
	return label.split(' > ').map(normalise).filter(Boolean);
}

// True when the result name equals the wanted name, or starts with it followed by a space.
function segmentMatches(wanted, actual)
{
	return actual === wanted || actual.startsWith(`${wanted} `);
}

/**
 * Checks whether one case string names a search result.
 * @param {string} wanted - a page title, optionally followed by headings, joined by ' > '
 * @param {string} result - the result's page title and headings, joined by ' > '
 * @returns {boolean} true when the page is the same and every heading appears in order
 */
export function matchesResult(wanted, result)
{
	const [wantedPage, ...wantedHeadings] = segmentsOf(wanted);
	const [resultPage, ...resultHeadings] = segmentsOf(result);
	if(!wantedPage || !resultPage || !segmentMatches(wantedPage, resultPage))
	{
		return false;
	}
	let next = 0;
	for(const heading of resultHeadings)
	{
		if(next < wantedHeadings.length && segmentMatches(wantedHeadings[next], heading))
		{
			next++;
		}
	}
	return next === wantedHeadings.length;
}

/**
 * Decides whether one search case passes, given the results in the order the search box shows them.
 * @param {{query: string, kind: 'exact'|'vocabulary', expected: string[], accepted: string[]}} searchCase
 * @param {string[]} topResults - result labels, first result first
 * @returns {{passed: boolean, reason: string}}
 */
export function evaluateCase(searchCase, topResults)
{
	const expected = searchCase.expected ?? [];
	const accepted = searchCase.accepted ?? [];
	if(topResults.length === 0)
	{
		return {passed: false, reason: 'no results'};
	}
	const first = topResults[0];
	const expectedFirst = expected.find(wanted => matchesResult(wanted, first));
	if(expectedFirst)
	{
		return {passed: true, reason: `expected "${expectedFirst}" is first`};
	}
	if(searchCase.kind === 'vocabulary')
	{
		for(let position = 0; position < Math.min(TOP, topResults.length); position++)
		{
			const acceptedHere = accepted.find(wanted => matchesResult(wanted, topResults[position]));
			if(acceptedHere)
			{
				return {passed: true, reason: `accepted "${acceptedHere}" is ${POSITION_WORDS[position]}`};
			}
		}
		return {passed: false, reason: `first is "${first}"; no expected result first and no accepted result in the top ${TOP}`};
	}
	return {passed: false, reason: `first is "${first}", not ${expected.map(wanted => `"${wanted}"`).join(' or ')}`};
}

/**
 * Counts the results of a run and decides the exit code. A case marked knownFailing is listed apart and
 * does not fail the run while it fails. If it passes, the run fails so the mark gets removed.
 * @param {Array<{searchCase: object, outcome: {passed: boolean, reason: string}}>} rows - one row per case
 * @returns {{exitCode: number, lines: string[]}} the summary lines and 0 or 1
 */
export function summariseResults(rows)
{
	const known = rows.filter(row => row.searchCase.knownFailing);
	const normal = rows.filter(row => !row.searchCase.knownFailing);
	const failures = normal.filter(row => !row.outcome.passed);
	const nowPassing = known.filter(row => row.outcome.passed);
	const stillFailing = known.filter(row => !row.outcome.passed);
	const passing = normal.length - failures.length + nowPassing.length;
	const lines = [`search test: ${passing} of ${rows.length} cases pass, ${stillFailing.length} known failing`];
	for(const {searchCase, outcome} of stillFailing)
	{
		lines.push(`  known failing "${searchCase.query}": ${searchCase.knownFailing} (${outcome.reason})`);
	}
	for(const {searchCase} of nowPassing)
	{
		lines.push(`"${searchCase.query}" now passes: remove knownFailing`);
	}
	return {exitCode: failures.length > 0 || nowPassing.length > 0 ? 1 : 0, lines};
}

function escapeCell(text)
{
	return String(text).replace(/\|/g, '\\|');
}

function buildReport(rows)
{
	const lines = [
		'| Group | Search | Kind | Expected first | Also accepted in top three | 1st | 2nd | 3rd | Result |',
		'|---|---|---|---|---|---|---|---|---|'
	];
	for(const {searchCase, results, outcome} of rows)
	{
		const top = [0, 1, 2].map(index => results[index] ?? '(none)');
		lines.push(`| ${[
			searchCase.group ?? '',
			`\`${searchCase.query}\`${searchCase.page ? ` on ${searchCase.page}` : ''}`,
			searchCase.kind,
			searchCase.expected.join('; '),
			searchCase.accepted.join('; ') || 'None',
			...top,
			outcome.passed ? 'pass' : (searchCase.knownFailing ? 'known failing' : 'FAIL')
		].map(escapeCell).join(' | ')} |`);
	}
	const summary = [];
	for(const group of [...new Set(rows.map(row => row.searchCase.group ?? 'all'))])
	{
		const inGroup = rows.filter(row => (row.searchCase.group ?? 'all') === group);
		summary.push(`${group}: ${inGroup.filter(row => !row.outcome.passed).length} of ${inGroup.length} fail`);
	}
	return `${lines.join('\n')}\n\n${summary.join('; ')}\n`;
}

async function waitForServer(base, timeoutMs = 30000)
{
	const start = Date.now();
	while(Date.now() - start < timeoutMs)
	{
		try
		{
			const response = await fetch(base);
			if(response.ok)
			{
				return;
			}
		}
		catch
		{
		}
		await sleep(500);
	}
	throw new Error('preview server did not start');
}

// Types one search and reads the result labels once the list has stopped changing (the search
// box waits 200 ms after the last key, then may still be loading the index on the first search).
async function search(page, query)
{
	const input = page.locator('.VPLocalSearchBox input.search-input');
	await input.fill(query);
	let previous = null;
	let stableReads = 0;
	const start = Date.now();
	while(Date.now() - start < 15000)
	{
		await sleep(300);
		const labels = await page.evaluate(() => [...document.querySelectorAll('.VPLocalSearchBox .results a.result')]
		.map(result => [...result.querySelectorAll('.titles .title .text')].map(title => title.textContent.trim()).join(' > ')));
		const hasNoResults = await page.locator('.VPLocalSearchBox .no-results').count() > 0;
		const snapshot = JSON.stringify(labels);
		if((labels.length > 0 || hasNoResults) && snapshot === previous)
		{
			if(++stableReads >= 2)
			{
				return labels;
			}
		}
		else
		{
			stableReads = 0;
		}
		previous = snapshot;
	}
	throw new Error(`search results for "${query}" did not settle`);
}

async function main()
{
	const {chromium} = await import('@playwright/test');
	const reportIndex = process.argv.indexOf('--report');
	const reportFile = reportIndex === -1 ? null : process.argv[reportIndex + 1];
	if(reportIndex !== -1 && !reportFile)
	{
		throw new Error('--report needs a file name');
	}
	const cases = JSON.parse(await readFile(path.join(ROOT, 'scripts', 'search-cases.json'), 'utf8'));
	const port = process.env.SEARCH_TEST_PORT ?? '4174';
	const docsBase = (process.env.DOCS_BASE ?? '/').replace(/\/$/, '');
	const base = `http://localhost:${port}${docsBase}`;

	// `detached` so teardown can kill the process group; see render-smoke.test.mjs for why.
	const server = spawn('npx', ['vitepress', 'preview', '--port', port], {cwd: ROOT, stdio: 'ignore', detached: true});
	let browser;
	const rows = [];
	try
	{
		await waitForServer(base);
		browser = await chromium.launch();
		const page = await browser.newPage({viewport: {width: 1280, height: 800}});
		let openPage = null;
		for(const searchCase of cases)
		{
			if(pageOf(searchCase) !== openPage)
			{
				openPage = pageOf(searchCase);
				await page.goto(`${base}${openPage}`, {waitUntil: 'networkidle'});
				await page.locator('.VPNavBarSearch button.DocSearch-Button').click();
				await page.locator('.VPLocalSearchBox input.search-input').waitFor();
			}
			const results = await search(page, searchCase.query);
			const outcome = evaluateCase(searchCase, results);
			rows.push({searchCase, results, outcome});
			console.log(`${outcome.passed ? 'ok' : 'FAIL'}: "${searchCase.query}"${searchCase.page ? ` on ${searchCase.page}` : ''} (${searchCase.kind}) ${outcome.reason}`);
		}
	}
	finally
	{
		if(browser)
		{
			await browser.close();
		}
		try
		{
			process.kill(-server.pid, 'SIGTERM');
		}
		catch
		{
			server.kill('SIGTERM');
		}
	}

	const summary = summariseResults(rows);
	console.log(summary.lines.join('\n'));
	if(reportFile)
	{
		await writeFile(reportFile, buildReport(rows));
		console.log(`report written to ${reportFile}`);
		process.exitCode = summary.exitCode;
		return;
	}
	const unexpected = rows.filter(row => !row.outcome.passed && !row.searchCase.knownFailing);
	if(unexpected.length > 0)
	{
		const index = await loadBuiltIndex();
		for(const {searchCase} of unexpected)
		{
			console.log(`\nFAIL "${searchCase.query}"${searchCase.page ? ` on ${searchCase.page}` : ''}: top ${SCORED_RESULTS_SHOWN} results in the built index, with their scores`);
			console.log(formatScoredResults(scoredResults(index, searchCase.query, SCORED_RESULTS_SHOWN, `${docsBase}${pageOf(searchCase)}`)));
		}
	}
	process.exitCode = summary.exitCode;
}

if(process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href)
{
	await main();
}
