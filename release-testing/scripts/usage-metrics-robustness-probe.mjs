// SPDX-License-Identifier: BUSL-1.1

/**
 * Usage-metrics robustness probe — drives hostile interaction patterns against the deployed
 * Streaming Event Monitor "Event usage metrics" view and records every anomaly: console errors,
 * uncaught page errors, unexpected error states, stuck spinners, and renders that fall outside
 * the component's stated contract (count-badge text, chip pressed-state, selection retention).
 *
 * Ten scenarios, each self-recovering so a crash in one does not poison the next:
 *  - A refresh-spam            — 10 rapid Refresh clicks; latest-wins guard must hold.
 *  - B granularity-storm       — 15 rapid granularity switches; final selection must stick.
 *  - C chips-during-fetch      — legend chips toggled mid-fetch; even toggle count must restore all.
 *  - D error-retry-race        — Aura XHRs aborted to force the error state, then Retry raced
 *                                against granularity switches.
 *  - E error-while-in-table    — fetch failure surfaced while the table view is active.
 *  - F resize-storm            — viewport thrash from 375px to 1900px; chart must keep rendering.
 *  - G tooltip-sweep           — hover every bar then leave; tooltip must not stick.
 *  - H preset-rapid-cycling    — date-range presets cycled with minimal settle time.
 *  - I custom-range-hostile    — inverted ranges, cleared inputs, and sub-bucket spans through the
 *                                real date/time pickers; every rejection must stay inline (never a
 *                                raw server error). Matchers use /Custom range/ to stay immune to
 *                                combobox label ellipsis.
 *  - J stale-error-on-switch   — granularity switch must clear a stale custom-range error.
 *
 * Screenshots of any anomaly are written to tmp/robustness-probe/.
 *
 * Usage:
 *   node release-testing/scripts/usage-metrics-robustness-probe.mjs \
 *     [--org=YourDevOrgAlias] [--tab=StreamingEventMonitor] [--only=A,B] [--headed]
 *
 * Exits 1 when any HIGH-severity finding is recorded.
 */

import {chromium} from '@playwright/test';
import {execFileSync} from 'node:child_process';
import {mkdirSync} from 'node:fs';
import path from 'node:path';

const ORG_ALIAS = readFlag('org', 'YourDevOrgAlias');
const TAB_NAME = readFlag('tab', 'StreamingEventMonitor');
const HEADED = Boolean(readFlag('headed', false));
const SCREENSHOT_DIR = 'tmp/robustness-probe';
const ELEMENT_TIMEOUT_MS = 20_000;

const findings = [];
const consoleNoise = [
	/Aura Cmp/i,
	/deprecat/i,
	/\[LWC warn/i,
	/favicon/i,
	/third-party cookie/i,
	/Refused to (frame|connect)/i,
	/net::ERR_ABORTED/i,
	/aura.*static resource/i
];

/**
 * Reads a `--name=value` (or bare `--name`) CLI flag.
 *
 * @param {string} name - The flag name without dashes.
 * @param {string|boolean} fallback - Value when the flag is absent.
 * @returns {string|boolean} The flag value, `true` for a bare flag, or the fallback.
 */
function readFlag(name, fallback)
{
	const match = process.argv.find((argument) => argument === `--${name}` || argument.startsWith(`--${name}=`));
	if(match === undefined)
	{
		return fallback;
	}
	return match.includes('=') ? match.split('=').slice(1).join('=') : true;
}

/**
 * Strips ANSI colour codes from CLI output.
 *
 * @param {string} text - The raw CLI output.
 * @returns {string} The output without ANSI escape sequences.
 */
function stripAnsi(text)
{
	// eslint-disable-next-line no-control-regex
	return text.replace(/\x1B\[[0-9;]*[a-zA-Z]/g, '');
}

/**
 * Runs an `sf` CLI command and returns its colour-free stdout.
 *
 * @param {Array<string>} args - The `sf` CLI arguments.
 * @returns {string} The command output.
 */
function sfOutput(args)
{
	return stripAnsi(execFileSync('sf', args, {encoding: 'utf8', timeout: 30_000, env: {...process.env, FORCE_COLOR: '0', NO_COLOR: '1'}}));
}

/**
 * Resolves the org's single-use frontdoor login URL.
 *
 * @returns {string} The frontdoor URL.
 */
function getFrontdoorUrl()
{
	const output = sfOutput([
		'org',
		'open',
		'-o',
		ORG_ALIAS,
		'--url-only',
		'-r'
	]);
	const match = output.match(/https?:\/\/\S+/);
	if(!match)
	{
		throw new Error(`No frontdoor URL in sf output: ${output}`);
	}
	return match[0].trim();
}

/**
 * Resolves the org's instance URL.
 *
 * @returns {string} The instance URL.
 */
function getInstanceUrl()
{
	return JSON.parse(sfOutput([
		'org',
		'display',
		'-o',
		ORG_ALIAS,
		'--json'
	])).result.instanceUrl;
}

/**
 * Records a finding and echoes it to the console.
 *
 * @param {string} scenario - The scenario that produced the finding.
 * @param {string} severity - HIGH, MED, or LOW.
 * @param {string} detail - Human-readable description of the anomaly.
 */
function record(scenario, severity, detail)
{
	findings.push({scenario, severity, detail});
	console.log(`  !! ${severity} [${scenario}] ${detail}`);
}

/**
 * Waits a fixed settle period for in-flight fetches and renders to complete.
 *
 * @param {Object} page - The Playwright page.
 * @param {number} [ms] - Settle duration in milliseconds.
 */
async function settle(page, ms = 1500)
{
	await page.waitForTimeout(ms);
}

/**
 * Navigates to the Streaming Event Monitor tab and opens the usage-metrics view.
 *
 * @param {Object} page - The Playwright page.
 */
async function openUsageMetrics(page)
{
	await page.goto(`${getInstanceUrl()}/lightning/n/${TAB_NAME}`, {waitUntil: 'domcontentloaded', timeout: 60_000});
	await page.getByText('Event usage metrics', {exact: true}).first().click({timeout: ELEMENT_TIMEOUT_MS});
	await page.locator('[data-spec-id="usage-card-title"]').waitFor({state: 'visible', timeout: ELEMENT_TIMEOUT_MS});
	await settle(page, 2500);
}

/**
 * Asserts the screen is in a healthy state: error visibility matches expectation, no stuck
 * spinner, and the count badge stays inside its text contract.
 *
 * @param {Object} page - The Playwright page.
 * @param {string} scenario - The scenario name for findings.
 * @param {{expectError?: boolean}} [options] - Whether the error state is expected to be visible.
 * @returns {Promise<boolean>} Whether the screen passed the health check.
 */
async function assertScreenHealthy(page, scenario, {expectError = false} = {})
{
	const errorVisible = await page.locator('[data-spec-id="usage-error-state"]').isVisible().catch(() => false);
	if(errorVisible !== expectError)
	{
		record(scenario, 'HIGH', `error-state visible=${errorVisible}, expected=${expectError}`);
		await page.screenshot({path: path.join(SCREENSHOT_DIR, `${scenario}.png`)}).catch(() =>
		{
		});
		return false;
	}
	const spinnerStuck = await page.locator('lightning-spinner').first().isVisible().catch(() => false);
	if(spinnerStuck)
	{
		await settle(page, 5000);
		if(await page.locator('lightning-spinner').first().isVisible().catch(() => false))
		{
			record(scenario, 'HIGH', 'spinner still visible 5s after interactions stopped');
			return false;
		}
	}
	const badgeText = ((await page.locator('[data-spec-id="usage-count-badge"]').textContent().catch(() => '')) || '').trim();
	if(!/^(No data to display|Showing [\d,]+( of [\d,]+)? data points)$/.test(badgeText))
	{
		record(scenario, 'MED', `badge text outside contract: "${badgeText}"`);
	}
	return true;
}

const ONLY = readFlag('only', '');

/**
 * Runs a named scenario with crash isolation: a throwing scenario records a HIGH finding,
 * captures a screenshot, and recovers to the usage-metrics view for the next scenario.
 *
 * @param {string} name - The scenario name (its prefix letter selects it via `--only`).
 * @param {Object} page - The Playwright page.
 * @param {Function} body - The scenario body.
 */
async function scenario(name, page, body)
{
	if(ONLY && !ONLY.split(',').some((prefix) => name.startsWith(prefix)))
	{
		return;
	}
	console.log(`\n== ${name}`);
	try
	{
		await body();
		console.log(`   done`);
	}
	catch(error)
	{
		record(name, 'HIGH', `scenario crashed: ${error.message.slice(0, 200)}`);
		await page.screenshot({path: path.join(SCREENSHOT_DIR, `${name}-crash.png`)}).catch(() =>
		{
		});
		// Recover to a known state for the next scenario.
		await openUsageMetrics(page).catch(() =>
		{
		});
	}
}

/**
 * Logs in, runs every selected scenario, and reports the findings.
 */
async function main()
{
	mkdirSync(SCREENSHOT_DIR, {recursive: true});
	const browser = await chromium.launch({headless: !HEADED});
	const context = await browser.newContext({ignoreHTTPSErrors: true, viewport: {width: 1480, height: 980}});
	const page = await context.newPage();

	page.on('console', (message) =>
	{
		if(message.type() !== 'error')
		{
			return;
		}
		const text = message.text();
		if(consoleNoise.some((pattern) => pattern.test(text)))
		{
			return;
		}
		record('console', 'MED', `console.error: ${text.slice(0, 300)}`);
	});
	page.on('pageerror', (error) => record('pageerror', 'HIGH', `uncaught page error: ${String(error).slice(0, 300)}`));

	console.log(`Logging into ${ORG_ALIAS}…`);
	await page.goto(getFrontdoorUrl(), {waitUntil: 'domcontentloaded', timeout: 60_000});
	await page.waitForURL((url) => !url.pathname.includes('/secur/frontdoor.jsp'), {timeout: 60_000});
	await openUsageMetrics(page);

	const granularity = (key) => page.locator(`[data-spec-id="usage-granularity-${key}"]`);
	const refresh = page.locator('[data-spec-id="usage-refresh"]');

	await scenario('A-refresh-spam', page, async() =>
	{
		for(let index = 0; index < 10; index++)
		{
			await refresh.click({delay: 20});
		}
		await settle(page, 5000);
		await assertScreenHealthy(page, 'A-refresh-spam');
	});

	await scenario('B-granularity-storm', page, async() =>
	{
		for(let round = 0; round < 5; round++)
		{
			await granularity('hourly').click();
			await granularity('fifteen').click();
			await granularity('daily').click();
		}
		await settle(page, 6000);
		const dailyPressed = await granularity('daily').getAttribute('aria-pressed');
		if(dailyPressed !== 'true')
		{
			record('B-granularity-storm', 'HIGH', `final selection lost: daily aria-pressed=${dailyPressed}`);
		}
		await assertScreenHealthy(page, 'B-granularity-storm');
	});

	await scenario('C-chips-during-fetch', page, async() =>
	{
		const chips = page.locator('[data-spec-id="usage-legend-chip"]');
		const chipCount = await chips.count();
		for(let round = 0; round < 4; round++)
		{
			await refresh.click();
			for(let index = 0; index < chipCount; index++)
			{
				await chips.nth(index).click({delay: 10});
			}
			for(let index = 0; index < chipCount; index++)
			{
				await chips.nth(index).click({delay: 10});
			}
		}
		await settle(page, 5000);
		const pressedCount = await page.locator('[data-spec-id="usage-legend-chip"][aria-pressed="true"]').count();
		if(pressedCount !== chipCount)
		{
			record('C-chips-during-fetch', 'MED', `chip pressed-state drifted: ${pressedCount}/${chipCount} pressed after even toggles`);
		}
		await assertScreenHealthy(page, 'C-chips-during-fetch');
	});

	await scenario('D-error-retry-race', page, async() =>
	{
		await page.route('**/aura*', (route) => route.abort());
		await refresh.click();
		await page.locator('[data-spec-id="usage-error-state"]').waitFor({state: 'visible', timeout: ELEMENT_TIMEOUT_MS});
		await page.unroute('**/aura*');
		// Retry then IMMEDIATELY switch granularity — racing the recovery fetch.
		await page.locator('[data-spec-id="usage-error-retry"]').click();
		await granularity('hourly').click();
		await granularity('daily').click();
		await settle(page, 6000);
		await assertScreenHealthy(page, 'D-error-retry-race');
	});

	await scenario('E-error-while-in-table-view', page, async() =>
	{
		await page.locator('[data-spec-id="usage-view-table"]').click();
		await page.locator('[data-spec-id="usage-table"]').waitFor({state: 'visible', timeout: ELEMENT_TIMEOUT_MS});
		await page.route('**/aura*', (route) => route.abort());
		await refresh.click();
		const errorAppeared = await page.locator('[data-spec-id="usage-error-state"]').waitFor({state: 'visible', timeout: 10_000}).then(() => true).catch(() => false);
		await page.unroute('**/aura*');
		if(!errorAppeared)
		{
			record('E-error-while-in-table-view', 'MED', 'error state did not surface while in table view');
		}
		else
		{
			await page.locator('[data-spec-id="usage-error-retry"]').click();
			await settle(page, 4000);
		}
		await page.locator('[data-spec-id="usage-view-chart"]').click();
		await settle(page, 1000);
		await assertScreenHealthy(page, 'E-error-while-in-table-view');
	});

	await scenario('F-resize-storm', page, async() =>
	{
		for(const width of [
			375,
			1900,
			500,
			1480
		])
		{
			await page.setViewportSize({width, height: 980});
			await settle(page, 800);
		}
		await assertScreenHealthy(page, 'F-resize-storm');
		const chartBox = await page.locator('svg.chart, [data-spec-id="usage-view-chart"]').first().boundingBox().catch(() => null);
		if(chartBox === null)
		{
			record('F-resize-storm', 'LOW', 'could not measure chart after resizes');
		}
	});

	await scenario('G-tooltip-sweep', page, async() =>
	{
		const bars = page.locator('[data-testid="usage-bar"]:visible');
		const barCount = await bars.count();
		for(let index = 0; index < Math.min(barCount, 12); index++)
		{
			await bars.nth(index).hover();
			await page.waitForTimeout(120);
		}
		if(barCount > 0)
		{
			await page.mouse.move(5, 5);
			await settle(page, 800);
			const tooltipStuck = await page.locator('[data-spec-id="usage-tooltip"]').isVisible().catch(() => false);
			if(tooltipStuck)
			{
				record('G-tooltip-sweep', 'MED', 'tooltip remained visible after mouse left the chart');
			}
		}
		await assertScreenHealthy(page, 'G-tooltip-sweep');
	});

	await scenario('H-preset-rapid-cycling', page, async() =>
	{
		const preset = page.locator('[data-spec-id="usage-range-preset"]');
		for(const value of [
			'Last 7 days',
			'Last 24 hours',
			'Last 30 days',
			'Last 24 hours',
			'Last 30 days'
		])
		{
			await preset.locator('input, button').first().click();
			const option = preset.getByRole('option', {name: value}).first();
			await option.waitFor({state: 'visible', timeout: 5000});
			await option.click();
			await page.waitForTimeout(150);
		}
		await settle(page, 6000);
		await assertScreenHealthy(page, 'H-preset-rapid-cycling');
	});

	await scenario('I-custom-range-hostile-inputs', page, async() =>
	{
		const preset = page.locator('[data-spec-id="usage-range-preset"]');
		await preset.locator('input, button').first().click();
		const customOption = preset.getByRole('option', {name: /Custom range/}).first();
		await customOption.waitFor({state: 'visible', timeout: 5000});
		await customOption.click();
		await settle(page, 1000);

		const fromDateInput = page.locator('[data-spec-id="usage-range-from"] input').first();
		const toDateInput = page.locator('[data-spec-id="usage-range-to"] input').first();

		// I1: inverted range via the date sub-input (real keyboard entry, real change events).
		await fromDateInput.fill('');
		await fromDateInput.type('12/31/2031');
		await fromDateInput.press('Tab');
		await settle(page, 1200);
		const errorAfterInvert = ((await page.locator('[data-spec-id="usage-range-error"]').textContent().catch(() => '')) || '').trim();
		if(errorAfterInvert === '')
		{
			record('I-custom-hostile', 'HIGH', 'future From (after To) produced no inline error');
		}

		// I2: clear the From date entirely — NaN path must stay inline, never fetch/crash.
		await fromDateInput.fill('');
		await fromDateInput.press('Tab');
		await settle(page, 1200);
		const errorAfterClear = ((await page.locator('[data-spec-id="usage-range-error"]').textContent().catch(() => '')) || '').trim();
		if(errorAfterClear === '')
		{
			record('I-custom-hostile', 'MED', 'cleared From produced no inline error (empty value accepted?)');
		}

		// I3: 30-minute hourly range — must be the inline too-narrow error, not a server error.
		await granularity('hourly').click();
		await settle(page, 2500);
		await preset.locator('input, button').first().click();
		const customAgain = preset.getByRole('option', {name: /Custom range/}).first();
		await customAgain.waitFor({state: 'visible', timeout: 5000});
		await customAgain.click();
		await settle(page, 800);
		const fromTimeInput = page.locator('[data-spec-id="usage-range-from"] input').nth(1);
		const toTimeInput = page.locator('[data-spec-id="usage-range-to"] input').nth(1);
		const toDateValue = await toDateInput.inputValue();
		await fromDateInput.fill(toDateValue);
		await fromTimeInput.fill('');
		await fromTimeInput.type('1:00 PM');
		await fromTimeInput.press('Tab');
		await toTimeInput.fill('');
		await toTimeInput.type('1:30 PM');
		await toTimeInput.press('Tab');
		await settle(page, 1500);
		const narrowError = ((await page.locator('[data-spec-id="usage-range-error"]').textContent().catch(() => '')) || '').trim();
		const serverError = await page.locator('[data-spec-id="usage-error-state"]').isVisible().catch(() => false);
		if(serverError)
		{
			record('I-custom-hostile', 'HIGH', '30-minute hourly custom range reached the server and errored (inline guard missed)');
		}
		else if(!/too narrow|minimum/i.test(narrowError))
		{
			record('I-custom-hostile', 'MED', `30-minute hourly range inline error unexpected: "${narrowError}"`);
		}

		await granularity('daily').click();
		await settle(page, 3000);
		await assertScreenHealthy(page, 'I-custom-hostile');
	});

	await scenario('J-segment-switch-clears-stale-error', page, async() =>
	{
		// Leave a custom-range error showing, then switch granularity — the preset re-snaps;
		// a stale inline error or stale custom values must not survive into the new state.
		const preset = page.locator('[data-spec-id="usage-range-preset"]');
		await preset.locator('input, button').first().click();
		const customOption = preset.getByRole('option', {name: /Custom range/}).first();
		await customOption.waitFor({state: 'visible', timeout: 5000});
		await customOption.click();
		await settle(page, 800);
		const fromDateInput = page.locator('[data-spec-id="usage-range-from"] input').first();
		await fromDateInput.fill('');
		await fromDateInput.type('12/31/2031');
		await fromDateInput.press('Tab');
		await settle(page, 1000);
		await granularity('hourly').click();
		await settle(page, 2500);
		const staleError = await page.locator('[data-spec-id="usage-range-error"]').isVisible().catch(() => false);
		if(staleError)
		{
			record('J-stale-error', 'MED', 'inline range error survived a granularity switch that reset the preset');
		}
		await granularity('daily').click();
		await settle(page, 3000);
		await assertScreenHealthy(page, 'J-stale-error');
	});

	await browser.close();

	console.log('\n==== ROBUSTNESS PROBE RESULT ====');
	if(findings.length === 0)
	{
		console.log('No findings — all scenarios held.');
	}
	for(const finding of findings)
	{
		console.log(`${finding.severity} | ${finding.scenario} | ${finding.detail}`);
	}
	process.exitCode = findings.some((finding) => finding.severity === 'HIGH') ? 1 : 0;
}

try
{
	await main();
}
catch(error)
{
	console.error(`Probe aborted: ${error.message}`);
	process.exitCode = 1;
}
