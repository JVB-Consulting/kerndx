// SPDX-License-Identifier: Apache-2.0
// Part 12: the consoles at volume. Seeded by the volume driver in staged mode; the seed is
// reused when its manifest and rows are present. Every journey reads thousands of rows, never one, and every count
// it asserts is read from the database as it runs.
const {test, expect} = require('@playwright/test');
const {execFileSync} = require('child_process');
const path = require('path');
const ChainMonitorPage = require('../pages/chain-monitor.page');
const LogConsolePage = require('../pages/log-console.page');
const {soqlQuery, waitForFrameworkBatchesToFinish} = require('../helpers/sf-cli');
const {namespacePrefix} = require('../helpers/sf-namespace');
const {getInstanceUrl} = require('../helpers/sf-auth');
const {waitForSpinnerGone, waitForToastMessage} = require('../helpers/wait-helpers');
const {readManifest, writeManifest, describeForeignManifest} = require('../../scripts/consoles-at-volume/manifest');
const {getSubscriberOrgAlias} = require('../../runner/subscriber-config');
const {outputDirectoryFor} = require('../../scripts/consoles-at-volume/command-line');
const {countRuns, countEntries, runKeys, findRun, field} = require('../explore/manifest-oracle');
const {collectPageKeys, findRepeatsAndLosses, readPageLabel, pagesFor} = require('../explore/coverage');
const {addressKeys} = require('../explore/checks');
const {labelValues, STATE_KEY_CHAIN, STATE_KEY_WINDOW_START, STATE_KEY_WINDOW_END} = require('../explore/constants');

const DRIVER = path.join(__dirname, '..', '..', 'scripts', 'consoles-at-volume.js');
// The load folder of the org this run signed in to, so a run against another org never reads or tears down this load.
const OUTPUT_DIRECTORY = outputDirectoryFor(getSubscriberOrgAlias());
const MANIFEST_PATH = path.join(OUTPUT_DIRECTORY, 'manifest.json');
const SEED_TIMEOUT_MILLISECONDS = 25 * 60_000;
// The walk turns every page of the load's runs, about 170 at the monitor's page size.
const LOAD_WALK_TIMEOUT_MILLISECONDS = 15 * 60_000;
// The retry is polled for up to 150 seconds after the monitor has opened and the modal has been confirmed.
const RETRY_JOURNEY_TIMEOUT_MILLISECONDS = 240_000;
const RETRY_COMPLETION_TIMEOUT_MILLISECONDS = 150_000;
const RETRY_POLL_MILLISECONDS = 5000;
const DEEP_LINK_TIMEOUT_MILLISECONDS = 30_000;
const DETAIL_OPEN_TIMEOUT_MILLISECONDS = 30_000;
const LIST_SETTLE_MILLISECONDS = 5000;
const MAXIMUM_PAGES = 200;
const PAGE_SIZE_LARGE = 100;
const PAGES_SHOWN = 7;
const CHIPS_SHOWN = 5;
const ACTION_RUNS_FLOOR = 1000;
const NUMBER_LOCALE = 'en-US';
const RECONCILIATION_LEAF_DEPTH = 3;
const RECONCILIATION_LEDGER_DEPTH = 2;
const STARTED_HEADER = labelValues.ChainMonitor_Started;
// V147 walks the load's chains only: parallel specs launch chains of their own while it walks.
const LOAD_CHAIN_NAME_PREFIX = 'Volume_';
const LEAF_STEP_COUNT = 5;
const RECOVERABLE_CHAIN = 'Volume_RecoverableImport';
const RETRY_CONFIRM_TEXT = 'Retry chain';
const RETRY_TOAST = 'Retry started';
const RETRY_PRESSED_BY = 'V151';
const STATUS_FAILED = 'Failed';
const STATUS_COMPLETED = 'Completed';
const SOURCE_RUN_STATUS = /Failed|Aborted/;
const RESTART_WORDING = /restart/i;
const DRIVER_STATUS_HINT = 'read `node release-testing/scripts/consoles-at-volume.js status` for the stage that failed';
const FIRST_NUMBER = /\d[\d,]*/;
const DIGIT_GROUPING = /,/g;

let manifest;
let reconciliation;

/**
 * @description Runs one volume driver subcommand and rethrows a hinted error naming the failed stage when it exits
 * non-zero, so a teardown failure carries the same remedy a run failure already does.
 *
 * @param {string} command The subcommand the driver is invoked with (`run` or `teardown`), named in the thrown message.
 * @param {string[]} argumentsAfterCommand The arguments that follow the subcommand on the driver's command line.
 *
 * @returns {void}
 */
function runDriver(command, argumentsAfterCommand)
{
	try
	{
		execFileSync(process.execPath, [DRIVER, command, ...argumentsAfterCommand], {stdio: 'inherit', timeout: SEED_TIMEOUT_MILLISECONDS});
	}
	catch(failure)
	{
		// The driver exits non-zero when a stage failed or a verify claim did not hold.
		throw new Error(`the volume driver's ${command} did not finish clean (${failure.message}); ${DRIVER_STATUS_HINT}`);
	}
}

/**
 * @description The instant a window key on the console's address means: epoch milliseconds when it is all
 *              digits, else the text as written (an ISO date), which the oracle's window clause parses either way.
 * @param {string|undefined} value The key's value.
 * @returns {number|string|undefined} The instant.
 */
function windowInstant(value)
{
	return /^\d+$/.test(String(value)) ? Number(value) : value;
}

/**
 * @description The Log Console opened on an action through the monitor's hand-off address, settled.
 * @param {Object} page The Playwright page.
 * @param {Object} logConsole The console page object.
 * @param {string} actionId The action id.
 */
async function openConsoleOnAction(page, logConsole, actionId)
{
	await page.goto(`${getInstanceUrl()}/lightning/n/${logConsole.tabApiName()}?c__rootCorrelationId=${actionId}&c__viewLogsAt=${Date.now()}`, {waitUntil: 'domcontentloaded'});
	await logConsole.waitForListSettled();
}

/**
 * @description Whether the manifest on disk describes a verified load the org no longer holds whole: it has no chain
 *              row or no log entry under the manifest's token. Part 1's beforeAll purges every log entry in the org,
 *              and an org purge takes the chain rows too, while the manifest stays on disk. (A recreated org under the
 *              same alias never gets here: the driver refuses its manifest as another org's.) `run`
 *              skips the stages a manifest records as done and only verifies again, which would fail and never heal,
 *              so such a load is torn down first (teardown moves its manifest aside even with nothing to delete) and
 *              `run` then lays a new one. No manifest, or one not yet verified clean, is left to `run`.
 * @param {Object|null} existing The manifest on disk, or null when there is none.
 * @returns {boolean} Whether the load has to be torn down before `run`.
 */
function verifiedLoadMissingRows(existing)
{
	const verify = existing?.stages?.verify;
	if(!verify?.ok || verify.failed !== 0)
	{
		return false;
	}
	const underToken = `WHERE ${field('RootCorrelationId__c')} LIKE '${existing.runToken}-%' LIMIT 1`;
	const chainRows = soqlQuery(`SELECT Id FROM ${field('AsyncChainExecution__c')} ${underToken}`).length;
	return chainRows === 0 || soqlQuery(`SELECT Id FROM ${field('LogEntry__c')} ${underToken}`).length === 0;
}

/**
 * @description The number a position line opens with, the first row on the page, with its digit grouping removed.
 * @param {string|null} position The position line's text.
 * @returns {number} The first row's number, or NaN when the line carries no number.
 */
function firstRowNumber(position)
{
	const match = FIRST_NUMBER.exec(position ?? '');
	return match ? Number(match[0].replace(DIGIT_GROUPING, '')) : Number.NaN;
}

test.describe.serial('Part 12: the consoles at volume', () =>
{
	test.beforeAll(async() =>
	{
		test.setTimeout(SEED_TIMEOUT_MILLISECONDS);
		await waitForFrameworkBatchesToFinish();
		const existing = readManifest(MANIFEST_PATH);
		// A manifest left by another org (often a deleted one) is never torn down here: teardown would run its ids against
		// this org. The journeys stop at once with the remedy instead; the driver itself refuses the same manifest.
		const foreign = describeForeignManifest(existing, {alias: getSubscriberOrgAlias(), manifestPath: MANIFEST_PATH});
		if(foreign)
		{
			throw new Error(foreign);
		}
		if(verifiedLoadMissingRows(existing))
		{
			runDriver('teardown', ['--mode', existing.mode, '--size', String(existing.size), '--output-directory', OUTPUT_DIRECTORY]);
		}
		// With no manifest on disk `run` lays a load; with a whole verified one it skips the done stages and verifies again.
		runDriver('run', ['--mode', 'staged', '--output-directory', OUTPUT_DIRECTORY]);
		manifest = readManifest(MANIFEST_PATH);
		expect(manifest, 'the driver wrote its manifest').not.toBeNull();
		reconciliation = manifest.actions.find((action) => action.kind === 'reconciliation');
	});

	test('V147: A page turn on the monitor loses and repeats no row when many chains started in the same second', async({page}) =>
	{
		test.setTimeout(LOAD_WALK_TIMEOUT_MILLISECONDS);
		const monitor = new ChainMonitorPage(page);
		await monitor.navigate();
		await monitor.setNameSearch(LOAD_CHAIN_NAME_PREFIX);
		await monitor.clickColumnHeader(STARTED_HEADER);
		const {keys, pages} = await collectPageKeys(monitor, MAXIMUM_PAGES);
		// One press on Started shows the oldest first, as the exploration's unscoped paging walk found. The name narrows the
		// oracle as the search narrows the screen: the engine's SubscriberNestedChild runs sit under the token too.
		const expected = runKeys({token: manifest.runToken, nameContains: LOAD_CHAIN_NAME_PREFIX, sortField: 'StartedAt__c', sortDescending: false});
		const {repeats, losses} = findRepeatsAndLosses(keys, expected);
		expect(pages, 'the walk covered more than one page').toBeGreaterThan(1);
		expect(repeats, 'no row repeated across page turns').toEqual([]);
		expect(losses, 'no row lost across page turns').toEqual([]);
	});

	test('V148: The scoped list, the banner and the database agree on the 2,000-run action', async({page}) =>
	{
		const runs = countRuns({actionId: reconciliation.id});
		const failed = countRuns({actionId: reconciliation.id, statuses: [STATUS_FAILED]});
		expect(runs).toBeGreaterThan(ACTION_RUNS_FLOOR);
		const monitor = new ChainMonitorPage(page);
		const scopedUrl = `${getInstanceUrl()}/lightning/n/${namespacePrefix()}ChainMonitor?c__rootCorrelationId=${reconciliation.id}&c__viewLogsAt=${Date.now()}`;
		await page.goto(scopedUrl, {waitUntil: 'domcontentloaded'});
		await page.waitForTimeout(LIST_SETTLE_MILLISECONDS);
		await waitForSpinnerGone(page);
		// Rehearsal finding 1: the monitor's label names pages only ("Page 1 of 170"), so its page count is what agrees.
		expect(readPageLabel(await monitor.getPageLabel()).pages, 'the scoped list pages every run of the action').toBe(pagesFor(runs));
		const logConsole = new LogConsolePage(page);
		await openConsoleOnAction(page, logConsole, reconciliation.id);
		await expect(logConsole.actionBannerSentence()).toContainText(`${runs.toLocaleString(NUMBER_LOCALE)} chains`);
		await expect(logConsole.actionBannerSentence()).toContainText(`${failed.toLocaleString(NUMBER_LOCALE)} of them failed`);
		expect(await logConsole.actionChips().count(), 'five chips whatever the size').toBe(CHIPS_SHOWN);
		await expect(logConsole.actionMoreChains()).toContainText(`${(runs - CHIPS_SHOWN).toLocaleString(NUMBER_LOCALE)} more`);
	});

	test('V149: A run three levels down reads its parent in Launched under and its five steps in the timeline', async({page}) =>
	{
		// The oldest leaf: the engine wrote it before the staged fill cloned it, so its launcher resolves.
		const leaf = findRun({actionId: reconciliation.id, chainName: reconciliation.chainNames[RECONCILIATION_LEAF_DEPTH]});
		expect(leaf.totalSteps, 'the leaf declares five steps').toBe(LEAF_STEP_COUNT);
		const monitor = new ChainMonitorPage(page);
		await monitor.navigateToRun(leaf.correlationId);
		expect(await monitor.getDetailChainName()).toContain(reconciliation.chainNames[RECONCILIATION_LEAF_DEPTH]);
		expect(await monitor.getStepRowCount()).toBe(leaf.totalSteps);
		expect(await monitor.getDetailLaunchedUnderText()).toContain(reconciliation.chainNames[RECONCILIATION_LEDGER_DEPTH]);
	});

	test('V150: A restart clone names its source, and the source keeps its own run', async({page}) =>
	{
		const restart = manifest.operatorWave.restarts[0];
		expect(restart, 'the wave recorded a restart').toBeDefined();
		const clones = soqlQuery(`SELECT ${field('CorrelationId__c')} FROM ${field('AsyncChainExecution__c')}`
				+ ` WHERE ${field('SourceExecution__c')} = '${restart.executionId}' LIMIT 1`);
		expect(clones.length, `a run names the restarted execution ${restart.executionId} as its source`).toBeGreaterThan(0);
		const clone = clones[0][field('CorrelationId__c')];
		const monitor = new ChainMonitorPage(page);
		await monitor.navigateToRun(clone);
		expect(await monitor.getDetailChainName()).toContain(restart.chainName);
		await expect(monitor.getLaunchedUnderRow()).toBeVisible();
		expect(await monitor.getDetailLaunchedUnderText()).toMatch(RESTART_WORDING);
		await monitor.navigateToRun(restart.correlationId);
		expect(await monitor.getDetailStatus()).toMatch(SOURCE_RUN_STATUS);
	});

	test('V151: A retry pressed on the monitor acts on a real failed run at volume', async({page}) =>
	{
		test.setTimeout(RETRY_JOURNEY_TIMEOUT_MILLISECONDS);
		// An engine-written candidate: a cloned RecoverableImport has no recovery marker, so its retry would fail again.
		const engineActions = manifest.actions.filter((action) => !action.synthesized).map((action) => `'${action.id}'`).join(', ');
		const candidate = soqlQuery(`SELECT ${field('CorrelationId__c')}, ${field('RootCorrelationId__c')}, Id FROM ${field('AsyncChainExecution__c')}`
				+ ` WHERE ${field('ChainName__c')} = '${RECOVERABLE_CHAIN}' AND ${field('Status__c')} = '${STATUS_FAILED}' AND ${field('LastManualRetryAt__c')} = null`
				+ ` AND ${field('RootCorrelationId__c')} IN (${engineActions}) ORDER BY CreatedDate LIMIT 1`)[0];
		test.skip(!candidate, 'every engine-written recoverable run was already retried by the wave; teardown and reseed to run this journey');
		const monitor = new ChainMonitorPage(page);
		await monitor.navigateToRun(candidate[field('CorrelationId__c')]);
		await monitor.getRetryButton().click();
		await expect(monitor.getConfirmButton()).toHaveText(RETRY_CONFIRM_TEXT);
		await monitor.getConfirmButton().click();
		await waitForToastMessage(page, RETRY_TOAST);
		// Recorded as the wave records its own presses, the moment the org carries the press, so verify expects this run
		// Completed and the load stays reusable even when the poll below times out.
		manifest.operatorWave.retries.push({
			executionId: candidate.Id, correlationId: candidate[field('CorrelationId__c')], chainName: RECOVERABLE_CHAIN, actionId: candidate[field('RootCorrelationId__c')],
			pressed: true, toast: RETRY_TOAST, pressedBy: RETRY_PRESSED_BY
		});
		writeManifest(MANIFEST_PATH, manifest);
		await expect.poll(() => soqlQuery(`SELECT ${field('Status__c')} FROM ${field('AsyncChainExecution__c')} WHERE Id = '${candidate.Id}'`)[0][field('Status__c')],
				{timeout: RETRY_COMPLETION_TIMEOUT_MILLISECONDS, intervals: [RETRY_POLL_MILLISECONDS]}).toBe(STATUS_COMPLETED);
	});

	test('V152: The console pager reaches past page 7 at page size 100', async({page}) =>
	{
		const logConsole = new LogConsolePage(page);
		await openConsoleOnAction(page, logConsole, reconciliation.id);
		await logConsole.selectPageSize(PAGE_SIZE_LARGE);
		for(let turn = 0; turn < PAGES_SHOWN; turn++)
		{
			await logConsole.clickNextPage();
		}
		// After seven presses of Next the eighth page is on screen: its first row is 701 at page size 100.
		await expect.poll(async() => firstRowNumber(await logConsole.positionLine().textContent()), {message: 'the position line opens on page eight'})
				.toBe(PAGES_SHOWN * PAGE_SIZE_LARGE + 1);
		expect(await logConsole.getRowCount(), 'page eight shows a full page').toBe(PAGE_SIZE_LARGE);
	});

	test('V153: Both deep links carry their scope at volume', async({page}) =>
	{
		const failedLeaf = findRun({actionId: reconciliation.id, statuses: [STATUS_FAILED]});
		const monitor = new ChainMonitorPage(page);
		await monitor.navigateToRun(failedLeaf.correlationId);
		await monitor.getViewLogsButton().click();
		await page.waitForURL((url) => url.search.includes(STATE_KEY_CHAIN), {timeout: DEEP_LINK_TIMEOUT_MILLISECONDS});
		const logConsole = new LogConsolePage(page);
		await logConsole.waitForListSettled();
		await expect(logConsole.correlationPill()).toBeVisible();
		await expect.poll(() => addressKeys(page)[STATE_KEY_WINDOW_START], {timeout: DEEP_LINK_TIMEOUT_MILLISECONDS}).toBeTruthy();
		const keys = addressKeys(page);
		const expected = countEntries({
			chainId: failedLeaf.correlationId, windowStart: windowInstant(keys[STATE_KEY_WINDOW_START]), windowEnd: windowInstant(keys[STATE_KEY_WINDOW_END])
		});
		await expect(logConsole.positionLine()).toContainText(`of ${expected.toLocaleString(NUMBER_LOCALE)}`);
		// The chain button lives in the entry's drawer, so a row is opened first.
		await logConsole.selectRow(0);
		await logConsole.detailPanel().waitFor({state: 'visible', timeout: DETAIL_OPEN_TIMEOUT_MILLISECONDS});
		await logConsole.chainButton().click();
		await page.waitForURL((url) => url.pathname.includes('ChainMonitor'), {timeout: DEEP_LINK_TIMEOUT_MILLISECONDS});
		await page.waitForTimeout(LIST_SETTLE_MILLISECONDS);
		await waitForSpinnerGone(page);
		// The run may sit off page one, so the detail pane is what says which run opened (the exploration's walkDeepLinks rule).
		expect(await monitor.getDetailCorrelationId(), 'the monitor opened on the run').toBe(failedLeaf.correlationId);
	});
});
