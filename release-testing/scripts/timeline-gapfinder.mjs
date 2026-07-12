// SPDX-License-Identifier: BUSL-1.1

/**
 * Timeline gap-finder — verifies every `data-spec-id` in the validated streamingTimeline
 * before/after mockup exists in the deployed Streaming Event Monitor timeline view.
 *
 * The mockup HTML is the design contract: each `data-spec-id` it declares must be present
 * (or reachable) in the live org. The timeline only renders once at least one event arrives,
 * and the tooltip only on hover, so both ids are driven live:
 *  - `timeline-chart` — subscribe to LogEntryEvent through the sidebar, publish a probe log
 *    entry via anonymous Apex, and wait for the chart + its first dot;
 *  - `timeline-tooltip` — hover the first `data-testid="timeline-dot"` circle.
 *
 * A screenshot of the populated timeline is written to tmp/gapfinder/.
 *
 * Usage:
 *   node release-testing/scripts/timeline-gapfinder.mjs \
 *     [--org=YourDevOrgAlias] [--tab=StreamingEventMonitor] [--prototype=<path>] [--headed]
 *
 * Exits 1 when any mockup data-spec-id is missing or a driven state cannot be reached.
 */

import {chromium} from '@playwright/test';
import {execFileSync} from 'node:child_process';
import {mkdirSync, readFileSync, rmSync, writeFileSync} from 'node:fs';
import path from 'node:path';
import os from 'node:os';

const DEFAULT_ORG_ALIAS = 'YourDevOrgAlias';
const DEFAULT_TAB_NAME = 'StreamingEventMonitor';
const DEFAULT_PROTOTYPE_PATH = '';
const SCREENSHOT_DIR = 'tmp/gapfinder';
const ELEMENT_TIMEOUT_MS = 20_000;
const NAVIGATION_TIMEOUT_MS = 60_000;
const EVENT_DELIVERY_TIMEOUT_MS = 30_000;

const STATUS_FOUND_DRIVEN = 'FOUND (driven)';
const STATUS_MISSING = 'MISSING';

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
 * Publishes a probe LogEntryEvent via anonymous Apex so the timeline has a dot to render.
 * Namespace-robust: the development org and Path-2 installs expose the bare class name, managed
 * subscriber orgs the kern-prefixed one.
 * @param {string} orgAlias - Target org alias.
 */
function publishProbeEvent(orgAlias)
{
	const probeBodies = [
		'LOG_Builder.build().info(\'Timeline gap-finder probe\').emitAt(\'E2E.timelineGapfinder\');\n',
		'kern.LOG_Builder.build().info(\'Timeline gap-finder probe\').emitAt(\'E2E.timelineGapfinder\');\n'
	];
	const apexPath = path.join(os.tmpdir(), `timeline-gapfinder-probe-${process.pid}.apex`);
	let lastError;
	try
	{
		for(const body of probeBodies)
		{
			writeFileSync(apexPath, body);
			try
			{
				execFileSync('sf', [
					'apex',
					'run',
					'-o',
					orgAlias,
					'--file',
					apexPath
				], {encoding: 'utf8', timeout: 60_000, env: {...process.env, FORCE_COLOR: '0', NO_COLOR: '1'}});
				return;
			}
			catch(error)
			{
				lastError = error;
			}
		}
	}
	finally
	{
		rmSync(apexPath, {force: true});
	}
	throw lastError;
}

/**
 * Extracts the unique `data-spec-id` inventory from the mockup HTML.
 * @param {string} prototypePath - Path to the mockup file.
 * @returns {Array<string>}
 */
function collectPrototypeSpecIds(prototypePath)
{
	const html = readFileSync(prototypePath, 'utf8');
	return [...new Set([...html.matchAll(/data-spec-id="([^"]+)"/g)].map((match) => match[1]))].sort();
}

/**
 * Subscribes the monitor session to LogEntryEvent through the sidebar (subscriptions are
 * per-browser-session, so a fresh gap-finder page always starts with none).
 * @param {import('@playwright/test').Page} page - The live page.
 */
async function subscribeToLogEntryEvent(page)
{
	await page.getByText('Subscribe to a channel', {exact: true}).click({timeout: ELEMENT_TIMEOUT_MS});
	await page.waitForTimeout(1000);

	const typeCombobox = page.locator('[data-testid="event-type"]').first();
	await typeCombobox.locator('input, button').first().click();
	await page.waitForTimeout(500);
	await page.getByRole('option', {name: 'Custom Platform event'}).first().click();
	await page.waitForTimeout(500);
	await page.keyboard.press('Escape');
	await page.waitForTimeout(1000);

	const nameCombobox = page.locator('[data-testid="event-name"]').first();
	await nameCombobox.waitFor({state: 'visible', timeout: ELEMENT_TIMEOUT_MS});
	await nameCombobox.locator('input, button').first().click();
	await page.waitForTimeout(1000);
	await page.getByRole('option', {name: 'Log Entry Event'}).first().click();
	await page.waitForTimeout(500);

	await page.locator('[data-testid="subscribe-button"]').first().evaluate((element) => element.click());
	await page.waitForTimeout(3000);
}

/**
 * Records a presence check for a spec id scoped to the timeline component.
 * @param {Map<string, string>} results - Accumulated id → status map.
 * @param {import('@playwright/test').Page} page - The live page.
 * @param {string} specId - The id under test.
 */
async function checkSpecId(results, page, specId)
{
	const count = await page.locator(`c-streaming-timeline [data-spec-id="${specId}"]`).count();
	results.set(specId, count > 0 ? STATUS_FOUND_DRIVEN : STATUS_MISSING);
}

const orgAlias = String(readFlag('org', DEFAULT_ORG_ALIAS));
const tabName = String(readFlag('tab', DEFAULT_TAB_NAME));
const prototypePath = String(readFlag('prototype', DEFAULT_PROTOTYPE_PATH));
const headed = Boolean(readFlag('headed', false));

if(!prototypePath)
{
	console.error('No prototype path available — pass --prototype=<path to the validated before/after mockup HTML>.');
	process.exit(1);
}

const specIds = collectPrototypeSpecIds(prototypePath);
console.log(`Mockup ${prototypePath} declares ${specIds.length} data-spec-id(s): ${specIds.join(', ')}`);

const browser = await chromium.launch({headless: !headed});
const context = await browser.newContext({viewport: {width: 1920, height: 1080}, timezoneId: 'America/Los_Angeles'});
const page = await context.newPage();
const results = new Map();
let exitCode = 0;

try
{
	console.log(`Logging in to ${orgAlias}…`);
	await page.goto(getFrontdoorUrl(orgAlias), {waitUntil: 'domcontentloaded', timeout: NAVIGATION_TIMEOUT_MS});
	await page.waitForURL((url) => !url.pathname.includes('/secur/frontdoor.jsp'), {timeout: NAVIGATION_TIMEOUT_MS});
	await page.waitForTimeout(2000);

	console.log(`Opening the ${tabName} tab…`);
	await page.goto(`${getInstanceUrl(orgAlias)}/lightning/n/${tabName}`, {waitUntil: 'domcontentloaded', timeout: NAVIGATION_TIMEOUT_MS});
	await page.waitForTimeout(5000);

	console.log('Subscribing to LogEntryEvent…');
	await subscribeToLogEntryEvent(page);
	// With replay -1, an event published before the CometD handshake completes is never delivered —
	// give the fresh subscription time to go live before the probe (V23 precedent).
	await page.waitForTimeout(4000);

	console.log('Publishing a probe event…');
	publishProbeEvent(orgAlias);

	console.log('Waiting for the timeline chart and its first dot…');
	await page.locator('c-streaming-timeline [data-spec-id="timeline-chart"]').waitFor({state: 'visible', timeout: EVENT_DELIVERY_TIMEOUT_MS});
	const firstDot = page.locator('c-streaming-timeline [data-testid="timeline-dot"]').first();
	await firstDot.waitFor({state: 'visible', timeout: ELEMENT_TIMEOUT_MS});
	await checkSpecId(results, page, 'timeline-chart');
	results.set('timeline-dot (data-testid)', STATUS_FOUND_DRIVEN);

	mkdirSync(SCREENSHOT_DIR, {recursive: true});
	const screenshotPath = path.join(SCREENSHOT_DIR, 'timeline-populated.png');
	await page.screenshot({path: screenshotPath, fullPage: false});
	console.log(`Screenshot written to ${screenshotPath}`);

	console.log('Hovering the first dot to drive the detail tooltip…');
	await firstDot.hover();
	// Pin the DOT tooltip variant (.tooltip.data): the crosshair variant shares the same
	// data-spec-id node, so a presence-only check would certify a dead dot tooltip.
	const dotTooltip = page.locator('c-streaming-timeline [data-spec-id="timeline-tooltip"].data');
	await dotTooltip.waitFor({state: 'visible', timeout: ELEMENT_TIMEOUT_MS}).catch(() =>
	{
	});
	results.set('timeline-tooltip', await dotTooltip.count() > 0 ? STATUS_FOUND_DRIVEN : STATUS_MISSING);
}
catch(error)
{
	console.error(`Gap-finder drive failed: ${error.message}`);
	exitCode = 1;
}
finally
{
	await browser.close();
}

console.log('\nSpec-id contract:');
for(const specId of [...new Set([...specIds, ...results.keys()])])
{
	const status = results.get(specId) ?? STATUS_MISSING;
	console.log(`  ${specId}: ${status}`);
	if(status === STATUS_MISSING)
	{
		exitCode = 1;
	}
}

process.exit(exitCode);
