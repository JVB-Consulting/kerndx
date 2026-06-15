// SPDX-License-Identifier: BUSL-1.1

/**
 * Usage-metrics gap-finder — verifies every `data-spec-id` in the validated usage-metrics
 * prototype exists in the deployed Streaming Event Monitor DOM.
 *
 * The prototype HTML is the design contract: each `data-spec-id` it declares must be present
 * (or reachable) in the live org. Statically-rendered ids are asserted directly; conditional
 * states are driven live and self-recover:
 *  - empty state (`usage-empty-state`, `usage-clear-filters`) — toggles every legend chip off,
 *    then restores via the Reset filters action;
 *  - error state (`usage-error-state`, `usage-error-retry`) — aborts Aura XHRs around a Refresh
 *    click to force a fetch failure, then lifts the block and recovers via Retry.
 *
 * Screenshots of the default chart and the table view are written to tmp/gapfinder/.
 *
 * Usage:
 *   node release-testing/scripts/usage-metrics-gapfinder.mjs \
 *     [--org=YourDevOrgAlias] [--tab=StreamingEventMonitor] [--prototype=<path>] [--headed]
 *
 * Exits 1 when any prototype data-spec-id is missing or a conditional state cannot be driven.
 */

import {chromium} from '@playwright/test';
import {execFileSync} from 'node:child_process';
import {readFileSync, mkdirSync} from 'node:fs';
import path from 'node:path';

const DEFAULT_ORG_ALIAS = 'YourDevOrgAlias';
const DEFAULT_TAB_NAME = 'StreamingEventMonitor';
const DEFAULT_PROTOTYPE_PATH = '';
const SCREENSHOT_DIR = 'tmp/gapfinder';
const SIDEBAR_ITEM_LABEL = 'Event usage metrics';
const ELEMENT_TIMEOUT_MS = 20_000;
const NAVIGATION_TIMEOUT_MS = 60_000;

const STATUS_FOUND_STATIC = 'FOUND (static)';
const STATUS_FOUND_DRIVEN = 'FOUND (driven)';
const STATUS_VERIFIED_ABSENT = 'VERIFIED ABSENT (enhanced org — legacy render covered by Jest)';
const STATUS_UNEXPECTED = 'UNEXPECTED (notice rendered in an enhanced org)';
const STATUS_MISSING = 'MISSING';

// Conditional ids and the live state that reveals them; everything else must be statically present.
const EMPTY_STATE_IDS = [
	'usage-empty-state',
	'usage-clear-filters'
];
const ERROR_STATE_IDS = [
	'usage-error-state',
	'usage-error-retry'
];
// Renders only when the org LACKS Enhanced Usage Metrics; org capability decides the assertion.
const ENHANCED_NOTICE_ID = 'usage-enhanced-notice';

/**
 * Parses a `--name=value` (or boolean `--name`) CLI flag.
 * @param {string} name - Flag name without the leading dashes.
 * @param {string|boolean} fallback - Value when the flag is absent.
 * @returns {string|boolean}
 */
function readFlag(name, fallback)
{
	const match = process.argv.find((arg) => arg === `--${name}` || arg.startsWith(`--${name}=`));
	if(match === undefined)
	{
		return fallback;
	}
	return match.includes('=') ? match.split('=').slice(1).join('=') : true;
}

/**
 * Strips ANSI escape sequences from sf CLI output.
 * @param {string} text - Raw CLI output.
 * @returns {string}
 */
function stripAnsi(text)
{
	// eslint-disable-next-line no-control-regex
	return text.replace(/\x1B\[[0-9;]*[a-zA-Z]/g, '');
}

/**
 * Resolves the org's single-use frontdoor login URL via the sf CLI.
 * @param {string} orgAlias - Target org alias.
 * @returns {string}
 */
function getFrontdoorUrl(orgAlias)
{
	const output = execFileSync('sf', [
		'org',
		'open',
		'-o',
		orgAlias,
		'--url-only',
		'-r'
	], {encoding: 'utf8', timeout: 30_000, env: {...process.env, FORCE_COLOR: '0', NO_COLOR: '1'}});
	const match = stripAnsi(output).match(/https?:\/\/\S+/);
	if(!match)
	{
		throw new Error(`Could not extract frontdoor URL from sf output: ${output}`);
	}
	return match[0].trim();
}

/**
 * Resolves the org's instance URL via the sf CLI.
 * @param {string} orgAlias - Target org alias.
 * @returns {string}
 */
function getInstanceUrl(orgAlias)
{
	const output = execFileSync('sf', [
		'org',
		'display',
		'-o',
		orgAlias,
		'--json'
	], {encoding: 'utf8', timeout: 30_000, env: {...process.env, FORCE_COLOR: '0', NO_COLOR: '1'}});
	return JSON.parse(stripAnsi(output)).result.instanceUrl;
}

/**
 * Extracts the unique `data-spec-id` inventory from the prototype HTML.
 * @param {string} prototypePath - Path to the prototype file.
 * @returns {Array<string>}
 */
function collectPrototypeSpecIds(prototypePath)
{
	const html = readFileSync(prototypePath, 'utf8');
	return [...new Set([...html.matchAll(/data-spec-id="([^"]+)"/g)].map((match) => match[1]))].sort();
}

/**
 * Records a presence check for a spec id.
 * @param {Map<string, string>} results - Accumulated id → status map.
 * @param {import('@playwright/test').Page} page - The live page.
 * @param {string} specId - The id under test.
 * @param {string} foundStatus - Status to record when present.
 */
async function checkSpecId(results, page, specId, foundStatus)
{
	const count = await page.locator(`[data-spec-id="${specId}"]`).count();
	results.set(specId, count > 0 ? foundStatus : STATUS_MISSING);
}

/**
 * Asserts the enhanced-usage notice against the org's live capability: a legacy org must render
 * it; an org with Enhanced Usage Metrics enabled must NOT (its legacy render is asserted by the
 * streamingUsageFilters Jest suite, which this script cannot reproduce without a legacy org).
 * The Hourly granularity button's disabled state is the capability witness — the same probe
 * drives both behaviours.
 * @param {Map<string, string>} results - Accumulated id → status map.
 * @param {import('@playwright/test').Page} page - The live page.
 */
async function checkEnhancedNotice(results, page)
{
	const hourlyDisabled = await page.locator('[data-spec-id="usage-granularity-hourly"]').isDisabled();
	const noticeCount = await page.locator(`[data-spec-id="${ENHANCED_NOTICE_ID}"]`).count();
	if(hourlyDisabled)
	{
		results.set(ENHANCED_NOTICE_ID, noticeCount > 0 ? STATUS_FOUND_STATIC : STATUS_MISSING);
		return;
	}
	results.set(ENHANCED_NOTICE_ID, noticeCount === 0 ? STATUS_VERIFIED_ABSENT : STATUS_UNEXPECTED);
}

/**
 * Drives the empty state by hiding every legend series, then restores via Reset filters.
 * @param {Map<string, string>} results - Accumulated id → status map.
 * @param {import('@playwright/test').Page} page - The live page.
 */
async function driveEmptyState(results, page)
{
	const chips = page.locator('[data-spec-id="usage-legend-chip"]');
	const chipCount = await chips.count();
	for(let index = 0; index < chipCount; index++)
	{
		await chips.nth(index).click();
	}
	await page.locator('[data-spec-id="usage-empty-state"]').waitFor({state: 'visible', timeout: ELEMENT_TIMEOUT_MS});
	for(const specId of EMPTY_STATE_IDS)
	{
		await checkSpecId(results, page, specId, STATUS_FOUND_DRIVEN);
	}
	await page.locator('[data-spec-id="usage-clear-filters"]').click();
	await page.locator('[data-spec-id="usage-legend-chip"]').first().waitFor({state: 'visible', timeout: ELEMENT_TIMEOUT_MS});
}

/**
 * Drives the error state by aborting Aura traffic around a Refresh, then recovers via Retry.
 * @param {Map<string, string>} results - Accumulated id → status map.
 * @param {import('@playwright/test').Page} page - The live page.
 */
async function driveErrorState(results, page)
{
	await page.route('**/aura*', (route) => route.abort());
	try
	{
		await page.locator('[data-spec-id="usage-refresh"]').click();
		await page.locator('[data-spec-id="usage-error-state"]').waitFor({state: 'visible', timeout: ELEMENT_TIMEOUT_MS});
		for(const specId of ERROR_STATE_IDS)
		{
			await checkSpecId(results, page, specId, STATUS_FOUND_DRIVEN);
		}
	}
	finally
	{
		// Always lift the Aura block, even when the drive fails, so later page activity recovers.
		await page.unroute('**/aura*');
	}
	await page.locator('[data-spec-id="usage-error-retry"]').click();
	await page.locator('[data-spec-id="usage-error-state"]').waitFor({state: 'hidden', timeout: ELEMENT_TIMEOUT_MS});
}

/**
 * Entry point.
 */
async function main()
{
	const orgAlias = readFlag('org', DEFAULT_ORG_ALIAS);
	const tabName = readFlag('tab', DEFAULT_TAB_NAME);
	const prototypePath = readFlag('prototype', DEFAULT_PROTOTYPE_PATH);
	const headed = Boolean(readFlag('headed', false));

	if(!prototypePath)
	{
		console.error('A prototype HTML file is required: pass --prototype=<path>.');
		process.exitCode = 1;
		return;
	}

	const specIds = collectPrototypeSpecIds(prototypePath);
	console.log(`Prototype contract: ${specIds.length} data-spec-ids from ${prototypePath}`);

	mkdirSync(SCREENSHOT_DIR, {recursive: true});

	const conditionalIds = new Set([
		...EMPTY_STATE_IDS,
		...ERROR_STATE_IDS,
		ENHANCED_NOTICE_ID
	]);
	const results = new Map(specIds.map((specId) => [
		specId,
		STATUS_MISSING
	]));

	const browser = await chromium.launch({headless: !headed});
	try
	{
		const context = await browser.newContext({ignoreHTTPSErrors: true, viewport: {width: 1480, height: 980}});
		const page = await context.newPage();

		console.log(`Logging into ${orgAlias}…`);
		await page.goto(getFrontdoorUrl(orgAlias), {waitUntil: 'domcontentloaded', timeout: NAVIGATION_TIMEOUT_MS});
		await page.waitForURL((url) => !url.pathname.includes('/secur/frontdoor.jsp'), {timeout: NAVIGATION_TIMEOUT_MS});

		console.log(`Opening /lightning/n/${tabName} → "${SIDEBAR_ITEM_LABEL}"…`);
		await page.goto(`${getInstanceUrl(orgAlias)}/lightning/n/${tabName}`, {waitUntil: 'domcontentloaded', timeout: NAVIGATION_TIMEOUT_MS});
		await page.getByText(SIDEBAR_ITEM_LABEL, {exact: true}).first().click({timeout: ELEMENT_TIMEOUT_MS});
		await page.locator('[data-spec-id="usage-card-title"]').waitFor({state: 'visible', timeout: ELEMENT_TIMEOUT_MS});
		// Let the initial fetch settle so legend chips/bars are rendered before the static sweep.
		await page.locator('[data-spec-id="usage-legend-chip"]').first().waitFor({state: 'visible', timeout: ELEMENT_TIMEOUT_MS});

		await page.screenshot({path: path.join(SCREENSHOT_DIR, 'usage-default-chart.png'), fullPage: false});

		for(const specId of specIds.filter((id) => !conditionalIds.has(id)))
		{
			await checkSpecId(results, page, specId, STATUS_FOUND_STATIC);
		}

		await checkEnhancedNotice(results, page);

		await page.locator('[data-spec-id="usage-view-table"]').click();
		await page.locator('[data-spec-id="usage-table"]').waitFor({state: 'visible', timeout: ELEMENT_TIMEOUT_MS});
		await page.screenshot({path: path.join(SCREENSHOT_DIR, 'usage-table-view.png'), fullPage: false});
		await page.locator('[data-spec-id="usage-view-chart"]').click();

		try
		{
			await driveEmptyState(results, page);
		}
		catch(error)
		{
			console.error(`Empty-state drive failed: ${error.message}`);
		}

		try
		{
			await driveErrorState(results, page);
		}
		catch(error)
		{
			console.error(`Error-state drive failed: ${error.message}`);
		}
	}
	finally
	{
		await browser.close();
	}

	console.log('\nGap-finder results:');
	let failures = 0;
	for(const [specId, status] of results)
	{
		const failed = status === STATUS_MISSING || status === STATUS_UNEXPECTED;
		if(failed)
		{
			failures++;
		}
		console.log(`  ${failed ? '✗' : '✓'} ${specId.padEnd(28)} ${status}`);
	}
	console.log(`\n${specIds.length - failures}/${specIds.length} prototype spec-ids verified; screenshots in ${SCREENSHOT_DIR}/`);

	if(failures > 0)
	{
		process.exitCode = 1;
	}
}

try
{
	await main();
}
catch(error)
{
	console.error(`Gap-finder aborted: ${error.message}`);
	process.exitCode = 1;
}
