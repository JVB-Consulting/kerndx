// SPDX-License-Identifier: BUSL-1.1
// Presses the operator actions on real rows through the Chain Monitor, flips the kill switch for one batch, makes
// the dead-job stalls, schedules the watchdog for the run and lays down the stall rows the probe's answer allows.
const fs = require('fs');
const ChainMonitorPage = require('../../e2e/pages/chain-monitor.page');
const {waitForToastMessage} = require('../../e2e/helpers/wait-helpers');
const {fillNamespaceTokens} = require('../../e2e/helpers/sf-namespace');
const {recordStage, mintVolumeId, KINDS} = require('./manifest');
const {stallStrategy, WAVE_CHAIN_NAMES} = require('./shapes');
const {renderTemplate, apexStringList, readLaunchLine} = require('./apex-templates');
const {ELEMENT_WAIT_MILLISECONDS} = require('../../e2e/helpers/wait-times');
const {authPathsFor} = require('../../e2e/helpers/auth-paths');

// The wave's actions are keyed from 900 by kind, clear of the small actions; the synthesized Stalled rows' at 905.
const WAVE_ACTION_OFFSET = 900;
const WAVE_KIND_INDEX = {slowExport: 1, switchedOff: 2, stallProbe: 3, deferredDispatch: 4, idempotentDeferredDispatch: 7};
// A launch spends three DML statements (the insert, the job-id stamp, the announcement), so fifty in one transaction is
// one over the limit of 150: a batch goes in chunks of this many, each its own transaction under the same action, with
// the kind index strided a chunk so no two chunks mint the same run ids (the exploration's live-stream batches stride the same way).
const WAVE_LAUNCH_CHUNK = 25;
const WAVE_CHUNK_KIND_STRIDE = 100;
const STALLED_ACTION_INDEX = 5;
// The started-step Stalled rows' action is keyed at 906, beside the screen-fixture rows' at 905.
const STARTED_STEP_ACTION_INDEX = 6;
// The started-step rows go in slices of this many, each its own script, so no one launch line grows past what a debug
// log line holds comfortably.
const STARTED_STEP_SLICE = 100;

const AUTH_STATE_PATH = authPathsFor().statePath;
const VIEWPORT = {width: 1440, height: 900};
const TIMEZONE = 'America/Los_Angeles';
const POLL_MILLISECONDS = 5000;
const KILL_SWITCH_TIMEOUT_MILLISECONDS = 180_000;
const PRESSED_RUNS_TIMEOUT_MILLISECONDS = 180_000;
const SLOW_EXPORT_BUSY_MILLISECONDS = 5000;
const ASSISTIVE_PREFIX = /^\s*(Success|Error|Warning|Info)(?=[A-Z])/;
const KEYBOARD_HINT = /Press Command \+ F6.*$/;
const DEFERRED_BUSY_MILLISECONDS = 1500;
const WATCHDOG_CADENCE_MINUTES = 5;
const BUTTONS = {
	retry: {button: 'getRetryButton', confirmText: 'Retry chain'},
	restart: {button: 'getRestartButton', confirmText: 'Restart chain'},
	abort: {button: 'getAbortButton', confirmText: 'Abort chain'},
	suspend: {button: 'getSuspendButton', confirmText: 'Suspend chains'},
	resume: {button: 'getResumeButton', confirmText: 'Resume chains'}
};
const WAVES = [
	[
		'retries',
		'retry',
		'Volume_RecoverableImport'
	],
	[
		'restarts',
		'restart',
		'Volume_RestartableLoad'
	]
];

/**
 * @description The failed runs of a chain under the engine actions, oldest first, up to a limit.
 *
 * @param {string} fieldPrefix The org's field prefix.
 * @param {string} chainName The chain name.
 * @param {string[]} actionIds The engine actions' ids.
 * @param {number} limit How many.
 *
 * @returns {string}
 */
function candidateQuery(fieldPrefix, chainName, actionIds, limit)
{
	const field = (name) => `${fieldPrefix}${name}`;
	const ids = actionIds.map((id) => `'${id}'`).join(', ');
	return `SELECT Id, ${field('CorrelationId__c')}, ${field('ChainName__c')}, ${field('RootCorrelationId__c')} FROM ${field('AsyncChainExecution__c')} `
			+ `WHERE ${field('ChainName__c')} = '${chainName}' AND ${field('Status__c')} = 'Failed' AND ${field('RootCorrelationId__c')} IN (${ids}) `
			+ `ORDER BY CreatedDate LIMIT ${limit}`;
}

/**
 * @description Waits for a toast and returns its text.
 *
 * @param {object} page The Playwright page.
 *
 * @returns {Promise<string>}
 */
async function readToastText(page)
{
	await waitForToastMessage(page, null);
	const text = await page.locator('div.toastContainer span.toastMessage, div.toastContainer .slds-notify__content').first().textContent();
	// The toast's content carries the assistive-text variant prefix and the keyboard hint; the message is what a person reads.
	return text.replace(ASSISTIVE_PREFIX, '').replace(KEYBOARD_HINT, '').trim();
}

/**
 * @description Opens the monitor on one run, presses an action, confirms it, and returns what the toast said.
 *
 * @param {object} monitor The Chain Monitor page object.
 * @param {object} page The Playwright page.
 * @param {object} press `correlationId`, `button` (the page object's getter name), `readToast` (default the toast reader).
 *
 * @returns {Promise<{pressed: boolean, toast: string}>}
 */
async function pressOnRun(monitor, page, {correlationId, button, readToast = readToastText})
{
	await monitor.navigateToRun(correlationId);
	await monitor[button]().click();
	const confirm = monitor.getConfirmButton();
	await confirm.waitFor({state: 'visible', timeout: ELEMENT_WAIT_MILLISECONDS});
	await confirm.click();
	return {pressed: true, toast: await readToast(page)};
}

/**
 * @description Polls until every run reads the status, or the timeout passes.
 *
 * @param {object} salesforce The org door.
 * @param {string} fieldPrefix The org's field prefix.
 * @param {string[]} executionIds The runs.
 * @param {string} status The status waited for.
 * @param {object} options `sleep`, `now`, `timeoutMilliseconds`.
 *
 * @returns {Promise<{reached: boolean, waitedMilliseconds: number, statuses?: string[]}>}
 */
async function waitForStatuses(salesforce, fieldPrefix, executionIds, status, {sleep, now = Date.now, timeoutMilliseconds})
{
	const startedAt = now();
	const field = (name) => `${fieldPrefix}${name}`;
	const soql = `SELECT Id, ${field('Status__c')} FROM ${field('AsyncChainExecution__c')} WHERE Id IN (${executionIds.map((id) => `'${id}'`).join(', ')})`;
	// eslint-disable-next-line no-constant-condition
	while(true)
	{
		const rows = salesforce.query(soql).records;
		if(rows.length === executionIds.length && rows.every((row) => row[field('Status__c')] === status))
		{
			return {reached: true, waitedMilliseconds: now() - startedAt};
		}
		if(now() - startedAt >= timeoutMilliseconds)
		{
			return {reached: false, waitedMilliseconds: now() - startedAt, statuses: rows.map((row) => row[field('Status__c')])};
		}
		await sleep(POLL_MILLISECONDS);
	}
}

/**
 * @description Polls until none of the runs is still Running, or the timeout passes.
 *
 * @param {object} salesforce The org door.
 * @param {string} fieldPrefix The org's field prefix.
 * @param {string[]} executionIds The runs.
 * @param {object} options `sleep`, `now`, `timeoutMilliseconds`.
 *
 * @returns {Promise<{ended: boolean, waitedMilliseconds: number}>}
 */
async function waitUntilNoneRunning(salesforce, fieldPrefix, executionIds, {sleep, now = Date.now, timeoutMilliseconds})
{
	const startedAt = now();
	const field = (name) => `${fieldPrefix}${name}`;
	const soql = `SELECT COUNT() FROM ${field('AsyncChainExecution__c')} WHERE Id IN (${executionIds.map((id) => `'${id}'`).join(', ')}) AND ${field('Status__c')} = 'Running'`;
	while(executionIds.length > 0)
	{
		if(salesforce.query(soql).totalSize === 0)
		{
			return {ended: true, waitedMilliseconds: now() - startedAt};
		}
		if(now() - startedAt >= timeoutMilliseconds)
		{
			return {ended: false, waitedMilliseconds: now() - startedAt};
		}
		await sleep(POLL_MILLISECONDS);
	}
	return {ended: true, waitedMilliseconds: 0};
}

/**
 * @description Waits for the runs the wave pressed to end before the kill switch, so no retried or restarted hop
 * still queued is aborted under it.
 *
 * @param {object} context The stage context.
 * @param {Function} sleep The wait between polls.
 */
async function waitForPressedRunsToEnd(context, sleep)
{
	const {manifest, salesforce, log} = context;
	const prefix = manifest.org.namespacePrefix;
	const restarted = manifest.operatorWave.restarts.map((press) => `'${press.executionId}'`).join(', ');
	const clonesQuery = `SELECT Id FROM ${prefix}AsyncChainExecution__c WHERE ${prefix}SourceExecution__c IN (${restarted})`;
	const clones = restarted ? salesforce.query(clonesQuery).records.map((row) => row.Id) : [];
	const pressed = [...manifest.operatorWave.retries.map((press) => press.executionId), ...clones];
	const ended = await waitUntilNoneRunning(salesforce, prefix, pressed, {sleep, timeoutMilliseconds: PRESSED_RUNS_TIMEOUT_MILLISECONDS});
	log(`operate: the pressed runs ${ended.ended ? 'ended' : 'did not all end'} after ${ended.waitedMilliseconds} ms`);
}

/**
 * @description Launches one wave kind under its own action and returns the launch line.
 *
 * @param {object} context The stage context.
 * @param {string} kind The wave kind.
 * @param {number} count How many chains.
 * @param {number} busyMilliseconds The busy budget the chains carry.
 *
 * @returns {object} The parsed launch line.
 */
function launchWave(context, kind, count, busyMilliseconds)
{
	const kindIndex = WAVE_KIND_INDEX[kind];
	const actionId = mintVolumeId(KINDS.action, context.manifest.runToken, WAVE_ACTION_OFFSET + kindIndex, 0, 0);
	const merged = {stage: kind, action: actionId, ordinal: 0, ids: [], launched: 0};
	for(let chunk = 0; chunk * WAVE_LAUNCH_CHUNK < count; chunk++)
	{
		const values = {
			__ACTION_ID__: actionId, __RUN_TOKEN__: context.manifest.runToken, __KIND__: kind, __KIND_INDEX__: kindIndex + chunk * WAVE_CHUNK_KIND_STRIDE,
			__COUNT__: Math.min(WAVE_LAUNCH_CHUNK, count - chunk * WAVE_LAUNCH_CHUNK), __BUSY_MILLISECONDS__: busyMilliseconds
		};
		const apex = fillNamespaceTokens(renderTemplate('launch-wave.apex', values), context.manifest.org.namespacePrefix);
		const line = readLaunchLine(context.salesforce.runApex(apex, `wave-${kind}-${chunk}`).debugLines);
		merged.ids.push(...line.ids);
		merged.launched += line.launched;
	}
	return merged;
}

/**
 * @description A wave action's manifest record.
 *
 * @param {string} kind The wave kind.
 * @param {object} line The launch line.
 * @param {string} status The status every run of it should end in.
 * @param {boolean} [synthesized] Whether the rows are a fixture.
 *
 * @returns {object}
 */
function waveAction(kind, line, status, synthesized = false)
{
	return {id: line.action, kind, ordinal: 0, expected: {runs: line.ids.length, byStatus: {[status]: line.ids.length}}, synthesized, executionIds: line.ids};
}

/**
 * @description Runs a script through the org's namespace.
 *
 * @param {object} context The stage context.
 * @param {string} name The template.
 * @param {object} values Its tokens.
 * @param {string} label The script's label.
 *
 * @returns {object} The run's result.
 */
function runTemplate(context, name, values, label)
{
	return context.salesforce.runApex(fillNamespaceTokens(renderTemplate(name, values), context.manifest.org.namespacePrefix), label);
}

/**
 * @description The retries and restarts: one press per candidate row of each chain, through the screen.
 *
 * @param {object} context The stage context.
 * @param {object} monitor The Chain Monitor page object.
 * @param {object} page The Playwright page.
 * @param {string[]} engineActionIds The engine actions' ids.
 */
async function pressRetriesAndRestarts(context, monitor, page, engineActionIds)
{
	const {manifest, shape, salesforce, log} = context;
	const prefix = manifest.org.namespacePrefix;
	for(const [wave, buttonKey, chainName] of WAVES)
	{
		const rows = salesforce.query(candidateQuery(prefix, chainName, engineActionIds, shape.wave[wave])).records;
		for(const row of rows)
		{
			const correlationId = row[`${prefix}CorrelationId__c`];
			const result = await pressOnRun(monitor, page, {correlationId, ...BUTTONS[buttonKey]});
			// The action the run belongs to, so verify can adjust that action's expected counts by what was pressed.
			manifest.operatorWave[wave].push({executionId: row.Id, correlationId, chainName, actionId: row[`${prefix}RootCorrelationId__c`], ...result});
			log(`operate: ${wave} ${row.Id}: ${result.toast}`);
		}
	}
}

/**
 * @description The aborts: slow chains launched under their own action, each aborted through the screen while running.
 *
 * @param {object} context The stage context.
 * @param {object} monitor The Chain Monitor page object.
 * @param {object} page The Playwright page.
 */
async function pressAborts(context, monitor, page)
{
	const {manifest, shape, salesforce} = context;
	const prefix = manifest.org.namespacePrefix;
	const slow = launchWave(context, 'slowExport', shape.wave.aborts, SLOW_EXPORT_BUSY_MILLISECONDS);
	manifest.actions.push(waveAction('slowExport', slow, 'Aborted'));
	for(const executionId of slow.ids)
	{
		const row = salesforce.query(`SELECT ${prefix}CorrelationId__c FROM ${prefix}AsyncChainExecution__c WHERE Id = '${executionId}'`).records[0];
		const correlationId = row[`${prefix}CorrelationId__c`];
		const result = await pressOnRun(monitor, page, {correlationId, ...BUTTONS.abort});
		manifest.operatorWave.aborts.push({executionId, correlationId, chainName: WAVE_CHAIN_NAMES.slowExport, ...result});
	}
}

/**
 * @description The kill switch: chains suspended through the screen, a batch launched while off, resumed after.
 *
 * @param {object} context The stage context.
 * @param {object} monitor The Chain Monitor page object.
 * @param {object} page The Playwright page.
 * @param {Function} sleep The wait between polls.
 */
async function flipKillSwitch(context, monitor, page, sleep)
{
	const {manifest, shape, salesforce} = context;
	const press = (button) => pressOnRun(monitor, page, {correlationId: '', ...BUTTONS[button], readToast: context.readToast});
	await monitor.navigate();
	const suspended = await press('suspend');
	let switchedOff;
	let aborted;
	let resumed;
	try
	{
		switchedOff = launchWave(context, 'switchedOff', shape.wave.killSwitchBatch, 0);
		aborted = await waitForStatuses(salesforce, manifest.org.namespacePrefix, switchedOff.ids, 'Aborted', {sleep, timeoutMilliseconds: KILL_SWITCH_TIMEOUT_MILLISECONDS});
	}
	finally
	{
		// Whatever happened while the switch was off, the org's chains are resumed: a switch left engaged aborts every later chain.
		await monitor.navigate();
		resumed = await press('resume');
	}
	manifest.actions.push(waveAction('switchedOff', switchedOff, 'Aborted'));
	manifest.operatorWave.killSwitch = {
		actionId: switchedOff.action,
		launched: switchedOff.ids.length,
		suspendToast: suspended.toast,
		resumeToast: resumed.toast,
		allAborted: aborted.reached,
		waitedMilliseconds: aborted.waitedMilliseconds
	};
}

/**
 * @description The Stalled rows: engine-written when the probe found the cause, else synthesized fixture rows.
 *
 * @param {object} context The stage context.
 */
function layDownStalls(context)
{
	const {manifest, shape} = context;
	if(stallStrategy() === 'engine')
	{
		const probes = launchWave(context, 'stallProbe', shape.wave.synthesizedStalled, 0);
		manifest.actions.push(waveAction('stallProbe', probes, 'Stalled'));
		manifest.operatorWave.stallProbes = probes.ids;
		return;
	}
	if(shape.wave.synthesizedStalled > 0)
	{
		const stalledActionId = mintVolumeId(KINDS.action, manifest.runToken, WAVE_ACTION_OFFSET + STALLED_ACTION_INDEX, 0, 0);
		const values = {__COUNT__: shape.wave.synthesizedStalled, __RUN_TOKEN__: manifest.runToken, __ACTION_ID__: stalledActionId};
		const stalled = readLaunchLine(runTemplate(context, 'synthesize-stalled.apex', values, 'wave-stalled').debugLines);
		manifest.actions.push(waveAction('stalledArchive', stalled, 'Stalled', true));
		manifest.synthesized.stalledRows = stalled.ids;
	}
}

/**
 * @description The started-step Stalled rows the command line asked for (`--stalled-started`, none by default). Each row
 * carries the id of a job that does not exist and a current step that started and saved no result, without saying it is
 * safe to run twice. The watchdog cannot prove such a step never ran, so it must end each row Failed instead of running
 * the step again. The rows sit under their own action, and the manifest keeps their ids apart from the screen-fixture
 * rows, so verify and teardown find them by kind.
 *
 * @param {object} context The stage context.
 */
function layDownStartedStepStalls(context)
{
	const {manifest} = context;
	const count = context.options?.stalledStarted || 0;
	if(count === 0)
	{
		return;
	}
	const actionId = mintVolumeId(KINDS.action, manifest.runToken, WAVE_ACTION_OFFSET + STARTED_STEP_ACTION_INDEX, 0, 0);
	const merged = {stage: 'stalledStarted', action: actionId, ordinal: 0, ids: [], launched: 0};
	for(let first = 0; first < count; first += STARTED_STEP_SLICE)
	{
		const values = {__COUNT__: Math.min(STARTED_STEP_SLICE, count - first), __FIRST_ORDINAL__: first, __RUN_TOKEN__: manifest.runToken, __ACTION_ID__: actionId};
		const line = readLaunchLine(runTemplate(context, 'synthesize-stalled-started.apex', values, `wave-stalled-started-${first}`).debugLines);
		merged.ids.push(...line.ids);
		merged.launched += line.launched;
	}
	manifest.actions.push(waveAction('stalledStarted', merged, 'Failed', true));
	manifest.synthesized.startedStepRows = merged.ids;
	context.log(`operate: laid ${merged.ids.length} started-step Stalled rows; the watchdog must end each one Failed`);
}

/**
 * @description The dead-job stalls: deferred chains whose queued first hop the driver aborts, recorded in full so
 * verify can prove what the watchdog did with each dead job and nothing else: the job killed, when, and the run key a
 * re-drive must rotate. The first step is marked started before its job is queued, and an aborted job reads the same
 * whether it died in the queue or mid-work, so the watchdog re-drives only a run whose step says it is safe to repeat.
 * Half the chains (the odd one included) start on such a step, and the watchdog must re-drive them to Completed. The
 * other half start on a step that is not safe to repeat, and the watchdog must end them Failed at the started step.
 *
 * @param {object} context The stage context.
 */
function makeDeadJobStalls(context)
{
	const {manifest, shape, salesforce, log} = context;
	const prefix = manifest.org.namespacePrefix;
	const field = (name) => `${prefix}${name}`;
	const redrivableCount = Math.ceil(shape.wave.deadJobStalls / 2);
	const idempotent = launchWave(context, 'idempotentDeferredDispatch', redrivableCount, DEFERRED_BUSY_MILLISECONDS);
	const deferred = launchWave(context, 'deferredDispatch', shape.wave.deadJobStalls - redrivableCount, DEFERRED_BUSY_MILLISECONDS);
	const redrivable = new Set(idempotent.ids);
	const ids = [...idempotent.ids, ...deferred.ids].map((id) => `'${id}'`).join(', ');
	const soql = `SELECT Id, ${field('CurrentJobId__c')}, ${field('RunKey__c')}, LastModifiedDate FROM ${field('AsyncChainExecution__c')} WHERE Id IN (${ids})`;
	const jobs = salesforce.query(soql).records;
	const abortedAt = new Date().toISOString();
	runTemplate(context, 'abort-jobs.apex', {__JOB_IDS__: apexStringList(jobs.map((row) => row[field('CurrentJobId__c')]))}, 'wave-abort-jobs');
	manifest.actions.push(waveAction('idempotentDeferredDispatch', idempotent, 'Completed'));
	manifest.actions.push(waveAction('deferredDispatch', deferred, 'Failed'));
	manifest.operatorWave.deadJobStalls = jobs.map((row) => ({
		executionId: row.Id, jobId: row[field('CurrentJobId__c')], runKey: row[field('RunKey__c')], staleFrom: row.LastModifiedDate, abortedAt, platformAction: 'abortJob',
		idempotent: redrivable.has(row.Id)
	}));
	log(`operate: aborted ${jobs.length} delayed first hops; within ${manifest.watchdog.thresholdMinutes + WATCHDOG_CADENCE_MINUTES} minutes the watchdog re-drives the `
			+ `${idempotent.ids.length} whose step is safe to repeat and ends the other ${deferred.ids.length} Failed`);
}

/**
 * @description Schedules the run's watchdog jobs and records it.
 *
 * @param {object} context The stage context.
 */
function scheduleWatchdog(context)
{
	const {manifest} = context;
	const values = {__THRESHOLD_MINUTES__: manifest.watchdog.thresholdMinutes, __JOB_NAME_PREFIX__: manifest.watchdog.jobNamePrefix};
	runTemplate(context, 'schedule-watchdog.apex', values, 'wave-watchdog');
	manifest.watchdog = {...manifest.watchdog, scheduled: true, scheduledAt: new Date().toISOString()};
}

/**
 * @description Waits for a number of milliseconds.
 *
 * @param {number} milliseconds How long.
 *
 * @returns {Promise<void>}
 */
function defaultSleep(milliseconds)
{
	return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

/**
 * @description Logs the run user in through the e2e global setup and proves the session file exists.
 */
async function freshSession()
{
	await require('../../e2e/global-setup')();
	if(!fs.existsSync(AUTH_STATE_PATH))
	{
		throw new Error(`The global setup left no session at ${AUTH_STATE_PATH}`);
	}
}

/**
 * @description A headless browser. Lazy: Playwright loads only when a browser is launched, so the pure parts import under jest.
 *
 * @returns {Promise<object>}
 */
function launchBrowser()
{
	const {chromium} = require('@playwright/test');
	return chromium.launch({headless: true});
}

/**
 * @description The operate stage: the operator wave through the screens, the kill switch, the stalls, the watchdog.
 *
 * @param {object} context `{options, salesforce, shape, manifest, log, sleep, browser, monitor}`.
 *
 * @returns {Promise<object>} The manifest with the stage recorded.
 */
async function run(context)
{
	const {manifest} = context;
	const sleep = context.sleep || defaultSleep;
	if(manifest.stages.preflight && manifest.stages.preflight.reused)
	{
		return recordStage(manifest, 'operate', {ok: true, reused: true});
	}
	if(manifest.stages.drain && manifest.stages.drain.timedOut)
	{
		// D3: the watchdog is scheduled only after the drain has settled, or its sweep re-drives healthy hops still queued.
		const reason = 'the drain stage did not settle; wait for the runs to end, run drain again, then operate (the watchdog must not sweep a queue with healthy hops waiting)';
		return recordStage(manifest, 'operate', {ok: false, reason});
	}
	const engineActionIds = manifest.actions.filter((action) => !action.synthesized).map((action) => action.id);
	// A fresh session every time: a stored one outlives the org's session timeout and lands the wave on the login page.
	await (context.globalSetup || freshSession)();
	const browser = context.browser || await launchBrowser();
	const browserContext = await browser.newContext({viewport: VIEWPORT, timezoneId: TIMEZONE, storageState: AUTH_STATE_PATH});
	const page = await browserContext.newPage();
	const monitor = context.monitor || new ChainMonitorPage(page);
	let failure;
	try
	{
		await pressRetriesAndRestarts(context, monitor, page, engineActionIds);
		await pressAborts(context, monitor, page);
		await waitForPressedRunsToEnd(context, sleep);
		await flipKillSwitch(context, monitor, page, sleep);
		layDownStalls(context);
		layDownStartedStepStalls(context);
		scheduleWatchdog(context);
		makeDeadJobStalls(context);
	}
	catch(thrown)
	{
		failure = thrown;
	}
	finally
	{
		await browserContext.close().catch(() => undefined);
		if(!context.browser)
		{
			await browser.close().catch(() => undefined);
		}
	}
	if(failure)
	{
		// The presses so far stay on record; the wave is not resumable, so a rerun starts from teardown.
		const reason = `${failure.message}; the presses made so far are recorded. Run teardown, then run again: the wave cannot resume half-way.`;
		return recordStage(manifest, 'operate', {ok: false, reason});
	}
	const {operatorWave} = manifest;
	return recordStage(manifest, 'operate', {
		ok: true, retries: operatorWave.retries.length, restarts: operatorWave.restarts.length, aborts: operatorWave.aborts.length, deadJobStalls: operatorWave.deadJobStalls.length
	});
}

module.exports = {run, candidateQuery, pressOnRun, waitForStatuses, waitUntilNoneRunning, flipKillSwitch, launchWave, layDownStartedStepStalls, makeDeadJobStalls, BUTTONS};
