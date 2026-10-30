// SPDX-License-Identifier: Apache-2.0
// The volume walk: every screen and control of both consoles, each step timed and its count checked against the
// oracle. Nothing is asserted; a disagreement is a finding and the walk goes on.
'use strict';

const path = require('path');
const {
	MONITOR_PAGE_SIZE, REPOSITORY_ROOT, OUTPUT_DIRECTORY, VOLUME_OUTPUT_DIRECTORY, ALL_LEVELS, ACTION_OPENING_LEVELS, RANGE_PRESETS, MINUTE_MILLISECONDS,
	ACTION_RANGE_MARGIN_MILLISECONDS, BROWSER_TIMEZONE, STATE_KEY_CHAIN, STATE_KEY_WINDOW_START, STATE_KEY_WINDOW_END, SESSION_VIEWPORT, MESSAGE_EXCERPT_LENGTH,
	labelValues
} = require('./constants');
const {monitorEntry, consoleEntry} = require('./model');
const {openMonitorTimed, openConsoleTimed, settleMonitor} = require('./moves');
const {poll, addressKeys} = require('./checks');
const {countRuns, countEntries, entryKeys, runsSpan, runKeys, sortValuesByKey, findRun, runName} = require('./manifest-oracle');
const {getInstanceUrl} = require('../helpers/sf-auth');
const {namespacePrefix} = require('../helpers/sf-namespace');
const {executeAnonymousApex} = require('../helpers/sf-cli');
const {isReleaseTarget} = require('../../runner/release-target');
const {renderTemplate} = require('../../scripts/consoles-at-volume/apex-templates');
const {mintVolumeId, KINDS} = require('../../scripts/consoles-at-volume/manifest');

const RELEASE_RESULTS_FOLDER = ['release-testing', 'results'];
const VOLUME_RESULTS_FOLDER = 'consoles-at-volume';
const NO_FAILED_CANDIDATE = 'no Failed candidate left to read';
const DRAWER_CLOSE_TIMEOUT_MILLISECONDS = 30_000;

/**
 * @description The exploration's output folder: the one given; else the release results for the version when
 *              the org is a release target and a manifest is set; else the run's own org folder for a manifest run;
 *              else where the explorer puts the shaped run.
 * @param {Object} choice The manifest path, the org's namespace prefix, the Kern version installed in the org and any folder given.
 * @returns {string} The folder.
 */
function resolveOutputDirectory({manifest, namespacePrefix: prefix, version, outputDirectory})
{
	if(outputDirectory)
	{
		return outputDirectory;
	}
	if(manifest && isReleaseTarget(prefix))
	{
		if(!version)
		{
			throw new Error('Could not read the Kern version installed in the org; pass --output-directory');
		}
		return path.join(REPOSITORY_ROOT, ...RELEASE_RESULTS_FOLDER, version, VOLUME_RESULTS_FOLDER);
	}
	return manifest ? VOLUME_OUTPUT_DIRECTORY : OUTPUT_DIRECTORY;
}

const STATUSES = ['Running', 'Completed', 'Failed', 'Aborted', 'Stalled'];
// The sortable columns by their header label, with the field the controller sorts on (chainMonitorList.js
// handleSort: recordUrl → ChainName, status → Status, startedAt → StartedAt, durationDisplay → DurationMs).
const SORT_COLUMNS = [
	{label: labelValues.ChainMonitor_ChainName, field: 'ChainName__c', informational: false},
	{label: labelValues.ChainMonitor_Status, field: 'Status__c', informational: false},
	{label: labelValues.ChainMonitor_Started, field: 'StartedAt__c', informational: false},
	{label: labelValues.ChainMonitor_Duration, field: 'DurationMs__c', informational: true}
];
// A page walk stops at the pages the oracle's count fills plus one, and never past this ceiling.
const PAGE_WALK_CEILING = 1000;
// Six opens in a row: the first is the cold one, the five after it are the warm samples the protocol asks for.
const OPEN_REPEATS = 6;
const STREAM_WATCH_MILLISECONDS = 60_000;
const STREAM_POLL_MILLISECONDS = 5000;
const PAGE_CHANGE_TIMEOUT_MILLISECONDS = 15_000;
const PAGE_CHANGE_POLL_MILLISECONDS = 250;
const LAUNCHER_EXTRA_READS_ALLOWED = 2;
const STEP_NAME_COLUMN = 34;
const RECONCILIATION_LEAF_DEPTH = 3;
const RECONCILIATION_REGION_DEPTH = 1;
const RECONCILIATION_LEDGER_DEPTH = 2;
// The live-stream batch: the wave template's orderSync kind under its own action, keyed like every harness row
// (operator-wave.js numbers the wave's actions from 900 by kind; orderSync is the sixth kind).
const LIVE_STREAM_KIND = 'orderSync';
const LIVE_STREAM_KIND_INDEX = 6;
// 950 sits clear of the operator wave's actions (900 + 1 to 6; the started-step rows are 906), so the live stream's
// batch count is its own and its kind index never collides with a row the wave laid.
const LIVE_STREAM_ACTION_INDEX = 950;
const LIVE_STREAM_LAUNCHES = 10;
// Each walk's batch takes a kind index of its own (6, 106, 206, ...) so its run ids never collide with an earlier
// walk's batch under the same action: the correlation id is an external id.
const LIVE_STREAM_BATCH_STRIDE = 100;
const IDEMPOTENT_FAILED_CHAIN = 'Volume_RecoverableImport';
// The console half: the page sizes it offers, its pager's width, the cap a body search returns under, the
// timeline's trace cap, the origins walked and the message the reconciliation's narrating step writes.
const CONSOLE_PAGE_SIZES = [25, 50, 100];
const CONSOLE_PAGE_BUTTONS_MAXIMUM = 7;
const CONSOLE_PAGES_PAST_THE_PAGER = 7;
const SEARCH_RESULT_CAP = 2000;
const TIMELINE_ENTRY_CAP = 300;
const DRAWER_OPEN_SAMPLES = 5;
const ORIGINS_WALKED = ['APEX', 'FRAMEWORK'];
const NARRATED_MESSAGE_START = 'Validated account batch';
const DAY_PRESET_MINUTES = 1440;
const DAY_PRESET_LABEL = 'Last 24 hours';
const CHIPS_MAXIMUM = 5;
const BANNER_SENTENCE = /It ran ([\d,]+) chains?, ([\d,]+) of them failed/;
const MORE_CHAINS = /and ([\d,]+) more/;

/**
 * @description A number the screen wrote with thousands separators.
 * @param {string} text The digits, with or without commas.
 * @returns {number} The number.
 */
function numberFrom(text)
{
	return Number(String(text).replace(/,/g, ''));
}

/**
 * @description The page number and the page count the monitor's label names ("Page 3 of 125"); the label
 *              carries no run total.
 * @param {string|null} label The page label's text.
 * @returns {Object} `page` and `pages`, null when the label is absent.
 */
function readPageLabel(label)
{
	const match = String(label || '').match(/Page\s+([\d,]+)\s+of\s+([\d,]+)/i);
	return match ? {page: numberFrom(match[1]), pages: numberFrom(match[2])} : {page: null, pages: null};
}

/**
 * @description How many pages a count fills at the monitor's page size.
 * @param {number} count The run count.
 * @returns {number} The page count.
 */
function pagesFor(count)
{
	return Math.ceil(count / MONITOR_PAGE_SIZE);
}

/**
 * @description The pages a walk may turn: the pages the count fills plus one, under the ceiling.
 * @param {number} count The rows the oracle expects.
 * @returns {number} The page cap.
 */
function pageCapFor(count)
{
	return Math.min(pagesFor(count) + 1, PAGE_WALK_CEILING);
}

/**
 * @description A value as the database orders it: text compared without regard to case, everything else as is.
 * @param {*} value The value.
 * @returns {*} The comparable value.
 */
function comparable(value)
{
	return typeof value === 'string' ? value.toLowerCase() : value;
}

/**
 * @description Whether the values run one way, ties allowed and a missing value passed over; text is compared
 *              without regard to case, the way SOQL orders it.
 * @param {Array} values The values in screen order.
 * @param {boolean} descending Whether the order should fall.
 * @returns {boolean} Whether they are ordered.
 */
function isOrdered(values, descending)
{
	let previous = null;
	for(const raw of values)
	{
		if(raw === null || raw === undefined)
		{
			continue;
		}
		const value = comparable(raw);
		if(previous !== null && (descending ? value > previous : value < previous))
		{
			return false;
		}
		previous = value;
	}
	return true;
}

/**
 * @description Puts the viewport back to the session's width: a walk that ran the width sweep first would
 *              otherwise walk the consoles at the sweep's last width.
 * @param {Object} context The run context.
 */
async function restoreViewport(context)
{
	await context.page.setViewportSize(SESSION_VIEWPORT);
}

/**
 * @description Waits until the list's first row is no longer the one it showed before Next was pressed: the
 *              replaced rows are the settle, so no spinner is waited for (one that never appears costs seconds).
 * @param {Object} list A page object with `getRowKeys()`.
 * @param {string} previousFirstKey The first row's key before the press.
 */
async function waitForPageChange(list, previousFirstKey)
{
	const deadline = Date.now() + PAGE_CHANGE_TIMEOUT_MILLISECONDS;
	let changed = false;
	while(!changed && Date.now() < deadline)
	{
		const keys = await list.getRowKeys();
		changed = keys.length > 0 && keys[0] !== previousFirstKey;
		if(!changed)
		{
			await new Promise((resolve) => setTimeout(resolve, PAGE_CHANGE_POLL_MILLISECONDS));
		}
	}
}

/**
 * @description Presses Next and waits for the page to change; when the page after the press is the very page
 *              before it (a press that did not take), presses once more. A partial overlap is left as it is: that
 *              is the tie-order instability the walk is there to find.
 * @param {Object} list A page object with `getRowKeys()` and `getNextPageButton()`.
 * @param {Array<string>} previousKeys The page's keys before the press.
 * @param {Function|undefined} settle A settle to run after each press, in place of the page-change wait.
 * @returns {Promise<Object>} The new page's `keys` and whether a `secondPress` was needed.
 */
async function turnPage(list, previousKeys, settle)
{
	const press = async() =>
	{
		await list.getNextPageButton().click();
		await (settle ? settle() : waitForPageChange(list, previousKeys[0]));
		return list.getRowKeys();
	};
	const firstKeys = await press();
	const samePage = firstKeys.length === previousKeys.length && firstKeys.every((key, index) => key === previousKeys[index]);
	if(!samePage)
	{
		return {keys: firstKeys, secondPress: false};
	}
	return {keys: await press(), secondPress: true};
}

/**
 * @description Walks Next until the paginator disables it (or the cap), keeping every page's row keys.
 * @param {Object} list A page object with `getRowKeys()` and `getNextPageButton()`.
 * @param {number} maximumPages The page cap.
 * @param {Object} options A `settle` to run after each press, in place of the page-change wait.
 * @returns {Promise<Object>} Every key in order, the page count and how many presses had to be repeated.
 */
async function collectPageKeys(list, maximumPages, {settle} = {})
{
	const keys = [];
	let pages = 0;
	let secondPresses = 0;
	let pageKeys = await list.getRowKeys();
	let more = true;
	while(more)
	{
		keys.push(...pageKeys);
		pages++;
		more = pages < maximumPages && !await list.getNextPageButton().isDisabled();
		if(more)
		{
			const turned = await turnPage(list, pageKeys, settle);
			pageKeys = turned.keys;
			secondPresses += turned.secondPress ? 1 : 0;
		}
	}
	return {keys, pages, secondPresses};
}

/**
 * @description The keys seen more than once, and the expected keys never seen.
 * @param {Array<string>} keys The keys the screen showed.
 * @param {Array<string>} expected The keys the oracle expects.
 * @returns {Object} `repeats` and `losses`.
 */
function findRepeatsAndLosses(keys, expected)
{
	const seen = new Set();
	const repeats = [];
	for(const key of keys)
	{
		if(seen.has(key))
		{
			repeats.push(key);
		}
		seen.add(key);
	}
	return {repeats, losses: expected.filter((key) => !seen.has(key))};
}

/**
 * @description The verdict of a paging walk against the oracle's keys.
 * @param {Object} walked The keys and the page count the walk collected.
 * @param {Array<string>} expected The oracle's keys.
 * @returns {Object} Expected and observed wordings.
 */
function pagingVerdict({keys, pages, secondPresses}, expected)
{
	const {repeats, losses} = findRepeatsAndLosses(keys, expected);
	const clean = repeats.length === 0 && losses.length === 0;
	const firstFew = [...repeats, ...losses].slice(0, 3).join(', ');
	if(clean && secondPresses > 0)
	{
		// The rows are all there once, but a press did not take the first time: recorded, not held against the run.
		return {expected: 'no row repeated or lost', observed: `no row repeated or lost, after ${secondPresses} second press(es) on Next`, informational: true};
	}
	return {
		expected: 'no row repeated or lost',
		observed: clean ? 'no row repeated or lost' : `${repeats.length} repeated, ${losses.length} lost over ${pages} pages (first ${firstFew})`
	};
}

/**
 * @description Runs one step of the walk: the act on the screen, then the check against the oracle. A
 *              disagreement is a finding; a step that throws is one too. The step's wall time is printed.
 * @param {Object} context The run context.
 * @param {string} name The step's name, which names its check.
 * @param {Function} act Performs the step and returns what was observed.
 * @param {Function} check Turns the observation into `{expected, observed, informational}`, or null for none.
 * @param {Object} pins The pins a finding is recorded under: the monitor scoped to the reconciliation by default.
 */
async function step(context, name, act, check, pins = monitorEntry(context.load.reconciliation.id))
{
	const startedAt = Date.now();
	context.volumeStep = (context.volumeStep || 0) + 1;
	let line = 'ok';
	try
	{
		const observed = await act();
		const verdict = check ? await check(observed) : null;
		if(verdict && String(verdict.expected) !== String(verdict.observed))
		{
			line = `${verdict.informational ? 'note' : 'finding'} — expected ${verdict.expected}; on screen ${verdict.observed}`;
			await context.ledger.report(context, {
				session: 'VOLUME', step: context.volumeStep, move: name, check: name, expected: String(verdict.expected), observed: String(verdict.observed), pins,
				informational: Boolean(verdict.informational)
			});
		}
	}
	catch(failure)
	{
		// A command that failed carries its answer in stdout (the CLI prints the compile or run error there).
		const message = `${failure.message || failure} ${failure.stdout || ''}`.replace(/\s+/g, ' ').trim().slice(0, MESSAGE_EXCERPT_LENGTH);
		line = `threw — ${message}`;
		await context.ledger.report(context, {session: 'VOLUME', step: context.volumeStep, move: name, check: `${name}-threw`, expected: 'the step runs', observed: message, pins});
	}
	console.log(`  V/${String(context.volumeStep).padStart(2, '0')} ${name.padEnd(STEP_NAME_COLUMN)} ${line} (${Date.now() - startedAt} ms)`);
}

/**
 * @description The monitor opened from its tab five times in a row, so the warm open has its samples before
 *              any other read (the sample protocol).
 * @param {Object} context The run context.
 */
async function openRepeat(context)
{
	await step(context, 'monitor-open-repeat', async() =>
	{
		for(let repeat = 0; repeat < OPEN_REPEATS; repeat++)
		{
			await openMonitorTimed(context);
		}
	}, null);
}

/**
 * @description The page count the list names for the whole org, and the note that it names no run total.
 * @param {Object} context The run context.
 */
async function unscopedTotal(context)
{
	const {monitor} = context;
	await step(context, 'monitor-unscoped-total', async() =>
	{
		await openMonitorTimed(context);
		return readPageLabel(await monitor.getPageLabel());
	}, ({pages}) => ({expected: pagesFor(countRuns({})), observed: pages}));
	await step(context, 'monitor-no-run-total', () => monitor.getPageLabel(),
			(label) => ({expected: 'a run total on screen', observed: `the page label names pages only ("${label}")`, informational: true}));
}

/**
 * @description The page count with exactly one status on, for each status.
 * @param {Object} context The run context.
 */
async function statusFilters(context)
{
	const {monitor} = context;
	for(const status of STATUSES)
	{
		await step(context, `monitor-status-${status.toLowerCase()}`, async() =>
		{
			await openMonitorTimed(context);
			await monitor.setStatusFilter([status]);
			const {pages} = readPageLabel(await monitor.getPageLabel());
			return pages === null && await monitor.getListEmptyState().isVisible().catch(() => false) ? 0 : pages;
		}, (pages) => ({expected: pagesFor(countRuns({statuses: [status]})), observed: pages}));
	}
}

/**
 * @description The page count with the name filter on.
 * @param {Object} context The run context.
 */
async function nameFilter(context)
{
	const {monitor} = context;
	await step(context, 'monitor-name-filter', async() =>
	{
		await openMonitorTimed(context);
		await monitor.setNameSearch('Volume_AccountReconcile');
		return readPageLabel(await monitor.getPageLabel()).pages;
	}, (pages) => ({expected: pagesFor(countRuns({nameContains: 'Volume_AccountReconcile'})), observed: pages}));
}

/**
 * @description One press on a column header, tried again once when the header was not reachable the first time
 *              (the table re-renders under a sort and a header can detach for a moment).
 * @param {Object} monitor The monitor page object.
 * @param {string} label The column's header label.
 * @param {boolean} retry Whether to try a second time after a failure.
 */
async function pressHeader(monitor, label, retry = true)
{
	try
	{
		await monitor.clickColumnHeader(label);
	}
	catch(failure)
	{
		if(!retry)
		{
			throw failure;
		}
		await monitor.clickColumnHeader(label);
	}
}

/**
 * @description Each sortable column pressed twice: the first page's rows have to run one way, then the other,
 *              read through the oracle's value of each listed row (ties allowed, as the screen's tiebreak is
 *              unknown).
 * @param {Object} context The run context.
 */
async function sortColumns(context)
{
	const {monitor} = context;
	for(const column of SORT_COLUMNS)
	{
		await step(context, `monitor-sort-${column.field.replace('__c', '').toLowerCase()}`, async() =>
		{
			await openMonitorTimed(context);
			await pressHeader(monitor, column.label);
			const firstKeys = await monitor.getRowKeys();
			await pressHeader(monitor, column.label, false);
			const secondKeys = await monitor.getRowKeys();
			const values = sortValuesByKey(column.field, [...new Set([...firstKeys, ...secondKeys])]);
			return {first: firstKeys.map((key) => values.get(key)), second: secondKeys.map((key) => values.get(key))};
		}, ({first, second}) =>
		{
			const oneWayThenTheOther = (isOrdered(first, false) && isOrdered(second, true)) || (isOrdered(first, true) && isOrdered(second, false));
			const expected = 'ordered one way, then the other';
			return {expected, observed: oneWayThenTheOther ? expected : `not ordered (${column.field})`, informational: column.informational};
		});
	}
}

/**
 * @description Every page of the unscoped list, sorted by Started: no row repeated, none lost.
 * @param {Object} context The run context.
 */
async function unscopedPaging(context)
{
	const {monitor} = context;
	await step(context, 'monitor-paging-no-repeat-no-loss', async() =>
	{
		await openMonitorTimed(context);
		await monitor.clickColumnHeader(labelValues.ChainMonitor_Started);
		return collectPageKeys(monitor, pageCapFor(countRuns({})));
	}, (walked) => pagingVerdict(walked, runKeys({sortField: 'StartedAt__c', sortDescending: false})));
}

/**
 * @description The monitor scoped to the reconciliation action through the console's hand-off address: its
 *              page count, then every page.
 * @param {Object} context The run context.
 */
async function scopedList(context)
{
	const {monitor, page, load} = context;
	const actionId = load.reconciliation.id;
	await step(context, 'monitor-scoped-total', async() =>
	{
		const timer = context.timing.openTimer();
		const scopedUrl = `${getInstanceUrl()}/lightning/n/${namespacePrefix()}ChainMonitor?c__rootCorrelationId=${actionId}&c__viewLogsAt=${Date.now()}`;
		await page.goto(scopedUrl, {waitUntil: 'domcontentloaded'});
		await monitor.waitForListRendered();
		timer.stop('monitor (scoped)');
		await settleMonitor(context);
		return readPageLabel(await monitor.getPageLabel()).pages;
	}, (pages) => ({expected: pagesFor(countRuns({actionId})), observed: pages}));
	await step(context, 'monitor-scoped-paging', () => collectPageKeys(monitor, pageCapFor(countRuns({actionId}))),
			(walked) => pagingVerdict(walked, runKeys({actionId, sortField: 'StartedAt__c', sortDescending: true})));
}

/**
 * @description A run opened through its deep link under the open timer, then settled.
 * @param {Object} context The run context.
 * @param {string} correlationId The run's correlation id.
 */
async function openRunTimed(context, correlationId)
{
	const timer = context.timing.openTimer();
	await context.monitor.navigateToRunUntilRendered(correlationId);
	timer.stop('monitor (run)');
	await settleMonitor(context);
}

/**
 * @description The detail pane of a leaf, of a restart clone and of a run whose launcher is off page one.
 * @param {Object} context The run context.
 */
async function detailPanes(context)
{
	const {monitor, load} = context;
	const names = load.reconciliation.chainNames;
	await step(context, 'monitor-nested-detail', async() =>
	{
		// The oldest leaf under the action: engine-written, so its launcher resolves; its own row says how many
		// steps the timeline owes.
		const leaf = findRun({actionId: load.reconciliation.id, chainName: names[RECONCILIATION_LEAF_DEPTH]});
		await openRunTimed(context, leaf.correlationId);
		return {name: await monitor.getDetailChainName(), steps: await monitor.getStepRowCount(), under: await monitor.getDetailLaunchedUnderText(), totalSteps: leaf.totalSteps};
	}, ({name, steps, under, totalSteps}) =>
	{
		const expected = `${names[RECONCILIATION_LEAF_DEPTH]}, ${totalSteps} steps, launched under ${names[RECONCILIATION_LEDGER_DEPTH]}`;
		const asExpected = name === names[RECONCILIATION_LEAF_DEPTH] && steps === totalSteps && under.includes(names[RECONCILIATION_LEDGER_DEPTH]);
		return {expected, observed: asExpected ? expected : `${name}, ${steps} steps, launched under "${under}"`};
	});
	await step(context, 'monitor-restart-clone-detail', async() =>
	{
		const clone = load.restartClone();
		await openRunTimed(context, clone.correlationId);
		return {under: await monitor.getDetailLaunchedUnderText(), source: runName(clone.sourceExecutionId)};
	}, ({under, source}) =>
	{
		const namesSource = Boolean(source) && (under.includes(source) || /restart/i.test(under));
		return {expected: `the source run named (${source})`, observed: namesSource ? `the source run named (${source})` : `"${under}"`};
	});
	await step(context, 'monitor-off-page-launcher', async() =>
	{
		// The launcher's name comes from the detail read (getChainDetail resolves the launch origin), so the extra
		// reads counted are detail reads beyond the run's own.
		const before = context.apexCalls.get('getChainDetail') || 0;
		await openRunTimed(context, load.runByDepth(RECONCILIATION_REGION_DEPTH));
		return {under: await monitor.getDetailLaunchedUnderText(), reads: (context.apexCalls.get('getChainDetail') || 0) - before - 1};
	}, ({under, reads}) =>
	{
		const expected = `launched under ${names[0]} within ${LAUNCHER_EXTRA_READS_ALLOWED} extra detail reads`;
		const asExpected = under.includes(names[0]) && reads <= LAUNCHER_EXTRA_READS_ALLOWED;
		return {expected, observed: asExpected ? expected : `launched under "${under}" after ${reads} extra detail reads`};
	});
}

/**
 * @description The gates the rows warrant: a retry on the idempotent Failed run alone, and a restart wherever
 *              the row declares one (the chain sets AllowRestart__c at launch; the restartable run declares it by
 *              the filter that found it).
 * @param {Object|null} idempotent The idempotent Failed run, or null when none is left.
 * @param {Object|null} restartable The restartable Failed run, or null when none is left.
 * @returns {string} The expected gates, one clause per run, or the no-candidate sentence.
 */
function expectedGates(idempotent, restartable)
{
	const restartWord = (run) => (run.allowRestart ? 'enabled' : 'disabled');
	return [
		idempotent ? `idempotent ${idempotent.name}: retry enabled, restart ${restartWord(idempotent)}` : null,
		restartable ? `restartable ${restartable.name}: retry disabled, restart enabled` : null
	].filter((gate) => gate !== null).join('; ') || NO_FAILED_CANDIDATE;
}

/**
 * @description The two operator gates as the screen shows them, each read from the rendered button (a read on
 *              the lightning-button host always says enabled).
 * @param {Object} monitor The Chain Monitor page object.
 * @returns {Promise<string>} The gates, as "retry enabled, restart disabled".
 */
async function describeGates(monitor)
{
	const retry = await monitor.isActionDisabled(monitor.getRetryButton()) ? 'disabled' : 'enabled';
	const restart = await monitor.isActionDisabled(monitor.getRestartButton()) ? 'disabled' : 'enabled';
	return `retry ${retry}, restart ${restart}`;
}

/**
 * @description The operator buttons on a Failed idempotent run and on a Failed restartable one: each gate
 *              matches what the row warrants, and nothing is pressed.
 * @param {Object} context The run context.
 */
async function operatorButtons(context)
{
	const {monitor, load} = context;
	const token = load.runToken;
	await step(context, 'monitor-operator-buttons', async() =>
	{
		const idempotent = findRun({token, chainName: IDEMPOTENT_FAILED_CHAIN, statuses: ['Failed']});
		const restartableFound = findRun({token, restartable: true, statuses: ['Failed']});
		// The restartable candidate counts only when it is another run than the idempotent one.
		const restartable = restartableFound && (!idempotent || restartableFound.id !== idempotent.id) ? restartableFound : null;
		const gates = [];
		const readGates = async(label, run) =>
		{
			await openRunTimed(context, run.correlationId);
			gates.push(`${label} ${run.name}: ${await describeGates(monitor)}`);
		};
		if(idempotent)
		{
			await readGates('idempotent', idempotent);
		}
		if(restartable)
		{
			await readGates('restartable', restartable);
		}
		return {idempotent, restartable, gates};
	}, ({idempotent, restartable, gates}) =>
	{
		const none = gates.length === 0;
		return {expected: expectedGates(idempotent, restartable), observed: none ? NO_FAILED_CANDIDATE : gates.join('; '), informational: none};
	});
}

/**
 * @description Ten runs launched while a fresh one's stream is on screen: entries have to arrive, and how
 *              often the list reloaded over the minute is recorded (the reload storm the spec names).
 * @param {Object} context The run context.
 */
async function liveStream(context)
{
	const {monitor, page, load} = context;
	await step(context, 'monitor-live-stream', async() =>
	{
		const actionId = mintVolumeId(KINDS.action, load.runToken, LIVE_STREAM_ACTION_INDEX, 0, 0);
		const earlierBatches = Math.ceil(countRuns({actionId}) / LIVE_STREAM_LAUNCHES);
		const kindIndex = LIVE_STREAM_KIND_INDEX + (earlierBatches * LIVE_STREAM_BATCH_STRIDE);
		executeAnonymousApex(renderTemplate('launch-wave.apex', {
			__ACTION_ID__: actionId, __RUN_TOKEN__: load.runToken, __KIND__: LIVE_STREAM_KIND, __KIND_INDEX__: kindIndex, __COUNT__: LIVE_STREAM_LAUNCHES,
			__BUSY_MILLISECONDS__: 0
		}));
		await openRunTimed(context, mintVolumeId(KINDS.waveRun, load.runToken, kindIndex, 0, 0));
		const before = context.apexCalls.get('getChainExecutions') || 0;
		let entries = 0;
		const deadline = Date.now() + STREAM_WATCH_MILLISECONDS;
		while(Date.now() < deadline)
		{
			await page.waitForTimeout(STREAM_POLL_MILLISECONDS);
			entries = Math.max(entries, await monitor.getStreamEntries().count());
		}
		return {entries, reloads: (context.apexCalls.get('getChainExecutions') || 0) - before};
	}, ({entries, reloads}) =>
	{
		const arrival = entries > 0 ? `entries arrive (${entries})` : 'no entry arrived';
		return {expected: 'entries arrive', observed: `${arrival}; the list reloaded ${reloads} times in a minute`, informational: entries > 0};
	});
}

/**
 * @description The Chain Monitor walked at volume, step by step.
 * @param {Object} context The run context.
 */
async function walkMonitor(context)
{
	console.log('\nV: the Chain Monitor at volume');
	await restoreViewport(context);
	await openRepeat(context);
	await unscopedTotal(context);
	await statusFilters(context);
	await nameFilter(context);
	await sortColumns(context);
	await unscopedPaging(context);
	await scopedList(context);
	await detailPanes(context);
	await operatorButtons(context);
	await liveStream(context);
}

// ---------------------------------------------------------------------------------------------------
// The console half
// ---------------------------------------------------------------------------------------------------

/**
 * @description The total the console's position line names ("Rows 1 to 50 of 3,116"); zero when the list shows
 *              its empty state instead, null when neither is on screen.
 * @param {Object} logConsole The console page object.
 * @returns {Promise<Object>} `first`, `last` and `total`.
 */
async function readPosition(logConsole)
{
	const text = await logConsole.positionLine().innerText().catch(() => '');
	const match = text.replace(/\s+/g, ' ').match(/Rows\s+([\d,]+)\s+to\s+([\d,]+)\s+of\s+([\d,]+)/i);
	if(match)
	{
		return {first: numberFrom(match[1]), last: numberFrom(match[2]), total: numberFrom(match[3])};
	}
	const empty = await logConsole.emptyState().isVisible().catch(() => false);
	return empty ? {first: 0, last: 0, total: 0} : {first: null, last: null, total: null};
}

/**
 * @description The console opened on an action through the monitor's hand-off address, under the open timer.
 * @param {Object} context The run context.
 * @param {string} actionId The action id.
 */
async function openConsoleOnAction(context, actionId)
{
	const {page, logConsole} = context;
	const timer = context.timing.openTimer();
	await page.goto(`${getInstanceUrl()}/lightning/n/${logConsole.tabApiName()}?c__rootCorrelationId=${actionId}&c__viewLogsAt=${Date.now()}`, {waitUntil: 'domcontentloaded'});
	await logConsole.waitForListRendered();
	timer.stop('console (action)');
	await logConsole.waitForListSettled();
}

/**
 * @description A step of the console half: the same runner, its findings pinned to the action on the console.
 * @param {Object} context The run context.
 * @param {string} name The step's name.
 * @param {Function} act The act.
 * @param {Function} check The check.
 */
function consoleStep(context, name, act, check)
{
	return step(context, name, act, check, consoleEntry(context.load.reconciliation.id));
}

/**
 * @description A verdict on the position line's total against the oracle's count.
 * @param {number|null} total The total on screen.
 * @param {number} expected The oracle's count.
 * @param {boolean} informational Whether the verdict is a note.
 * @returns {Object} The verdict.
 */
function totalVerdict(total, expected, informational = false)
{
	return {expected, observed: total, informational};
}

/**
 * @description The instant a local date and time the console was given means, and the words it was given as.
 * @param {number} instant The instant in milliseconds.
 * @param {boolean} roundUp Whether to take the next whole minute rather than the previous one.
 * @returns {Object} The `date` (YYYY-MM-DD), the `time` (HH:mm) in the browser's clock, and the whole-minute `instant`.
 */
function localMinute(instant, roundUp)
{
	const wholeMinute = (roundUp ? Math.ceil(instant / MINUTE_MILLISECONDS) : Math.floor(instant / MINUTE_MILLISECONDS)) * MINUTE_MILLISECONDS;
	const parts = Object.fromEntries(new Intl.DateTimeFormat('en-CA', {
		timeZone: BROWSER_TIMEZONE, hourCycle: 'h23', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit'
	}).formatToParts(new Date(wholeMinute)).map((part) => [part.type, part.value]));
	return {date: `${parts.year}-${parts.month}-${parts.day}`, time: `${parts.hour}:${parts.minute}`, instant: wholeMinute};
}

/**
 * @description The console opened from its tab five times in a row, then on the reconciliation action: the
 *              banner's counts and chips against the oracle.
 * @param {Object} context The run context.
 */
async function consoleOpens(context)
{
	const {logConsole, load} = context;
	const actionId = load.reconciliation.id;
	await consoleStep(context, 'console-open-repeat', async() =>
	{
		for(let repeat = 0; repeat < OPEN_REPEATS; repeat++)
		{
			await openConsoleTimed(context);
		}
	}, null);
	await consoleStep(context, 'console-open-action', async() =>
	{
		await openConsoleOnAction(context, actionId);
		const sentence = (await logConsole.actionBannerSentence().innerText().catch(() => '')).replace(/\s+/g, ' ');
		const banner = sentence.match(BANNER_SENTENCE);
		const more = (await logConsole.actionMoreChains().innerText().catch(() => '')).match(MORE_CHAINS);
		return {
			chains: banner ? numberFrom(banner[1]) : null, failed: banner ? numberFrom(banner[2]) : null, chips: await logConsole.actionChips().count(),
			more: more ? numberFrom(more[1]) : 0, sentence
		};
	}, ({chains, failed, chips, more, sentence}) =>
	{
		const runs = countRuns({actionId});
		const failedRuns = countRuns({actionId, statuses: ['Failed']});
		const expected = `${runs} chains, ${failedRuns} failed, at most ${CHIPS_MAXIMUM} chips and ${runs - Math.min(chips, CHIPS_MAXIMUM)} more`;
		const asExpected = chains === runs && failed === failedRuns && chips <= CHIPS_MAXIMUM && more === runs - chips;
		return {expected, observed: asExpected ? expected : `${chains} chains, ${failed} failed, ${chips} chips and ${more} more ("${sentence}")`};
	});
}

/**
 * @description The entries total under the pinned action, as opened (ERROR, WARN and INFO), then with INFO
 *              off, then with every level on. The banner counts runs with no window while the entries keep
 *              the action's lifetime: a disagreement is reported with the count inside the runs' span.
 * @param {Object} context The run context.
 */
async function consoleTotalsAndLevels(context)
{
	const {logConsole, load} = context;
	const actionId = load.reconciliation.id;
	await consoleStep(context, 'console-entries-total', () => readPosition(logConsole), async({total}) =>
	{
		const expected = countEntries({actionId, levels: ACTION_OPENING_LEVELS});
		if(total === expected)
		{
			return totalVerdict(total, expected);
		}
		const span = runsSpan(actionId);
		const windowStart = Date.parse(span.first) - ACTION_RANGE_MARGIN_MILLISECONDS;
		const windowEnd = Date.parse(span.last) + ACTION_RANGE_MARGIN_MILLISECONDS;
		const inSpan = countEntries({actionId, levels: ACTION_OPENING_LEVELS, windowStart, windowEnd});
		return {expected: `${expected} (${inSpan} inside the runs' span)`, observed: `${total}`};
	});
	await consoleStep(context, 'console-levels-without-info', async() =>
	{
		await logConsole.setLevel('INFO', false);
		return readPosition(logConsole);
	}, ({total}) => totalVerdict(total, countEntries({actionId, levels: ['ERROR', 'WARN']})));
	await consoleStep(context, 'console-levels-all', async() =>
	{
		await logConsole.enableAllLevels();
		return readPosition(logConsole);
	}, ({total}) => totalVerdict(total, countEntries({actionId, levels: ALL_LEVELS})));
}

/**
 * @description The origin filter narrowed to each origin walked, then widened back to all.
 * @param {Object} context The run context.
 */
async function consoleOrigins(context)
{
	const {logConsole, load} = context;
	const actionId = load.reconciliation.id;
	for(const origin of [...ORIGINS_WALKED, '']) // '' is the "all origins" choice
	{
		await consoleStep(context, `console-origin-${origin ? origin.toLowerCase() : 'all'}`, async() =>
		{
			await logConsole.selectOrigin(origin);
			await logConsole.waitForListSettled();
			return readPosition(logConsole);
		}, ({total}) => totalVerdict(total, countEntries({actionId, levels: ALL_LEVELS, origins: origin ? [origin] : []})));
	}
}

/**
 * @description Each rolling preset, then a custom range over the reconciliation's runs.
 * @param {Object} context The run context.
 */
async function consoleRanges(context)
{
	const {logConsole, load} = context;
	const actionId = load.reconciliation.id;
	for(const preset of RANGE_PRESETS)
	{
		await consoleStep(context, `console-range-${preset.label.toLowerCase().replace(/\s+/g, '-')}`, async() =>
		{
			// The window's edge is taken before the console runs its query, not after the list was read.
			const at = Date.now();
			await logConsole.selectDateRange(preset.label);
			await logConsole.waitForListSettled();
			return {position: await readPosition(logConsole), at};
		}, ({position, at}) => totalVerdict(position.total, countEntries({actionId, levels: ALL_LEVELS, windowStart: at - (preset.minutes * MINUTE_MILLISECONDS)})));
	}
	await consoleStep(context, 'console-custom-range', async() =>
	{
		const span = runsSpan(actionId);
		const from = localMinute(Date.parse(span.first), false);
		const to = localMinute(Date.parse(span.last), true);
		await logConsole.selectDateRange(labelValues.LogConsole_RangeCustom);
		await logConsole.setCustomRange({fromDate: from.date, fromTime: from.time, toDate: to.date, toTime: to.time});
		await logConsole.waitForListSettled();
		return {position: await readPosition(logConsole), from, to};
	}, ({position, from, to}) => totalVerdict(position.total, countEntries({actionId, levels: ALL_LEVELS, windowStart: from.instant, windowEnd: to.instant})));
}

/**
 * @description The search box: a run's id pins the run, an action's id pins the action, words search the
 *              messages under the pinned action, and closing the pills returns the list to the org's window.
 * @param {Object} context The run context.
 */
async function consoleSearches(context)
{
	const {logConsole, load} = context;
	const actionId = load.reconciliation.id;
	await consoleStep(context, 'console-search-id', async() =>
	{
		const chainId = load.searchableRun();
		await logConsole.search(chainId);
		await logConsole.waitForListSettled();
		return {chainId, pills: await logConsole.correlationPill().count(), position: await readPosition(logConsole)};
	}, ({chainId, pills, position}) =>
	{
		const expected = `the run pinned, ${countEntries({chainId, levels: ALL_LEVELS})} entries`;
		const observed = `${pills > 0 ? 'the run pinned' : 'no run pill'}, ${position.total} entries`;
		return {expected, observed};
	});
	await consoleStep(context, 'console-search-action', async() =>
	{
		await logConsole.search(load.searchableAction.id);
		await logConsole.waitForListSettled();
		return await logConsole.actionPill().count() > 0 ? 'the action pinned' : 'no action pill';
	}, (observed) => ({expected: 'the action pinned', observed}));
	await consoleStep(context, 'console-search-body', async() =>
	{
		await logConsole.search(actionId);
		await logConsole.waitForListSettled();
		await logConsole.search(NARRATED_MESSAGE_START);
		await logConsole.waitForListSettled();
		return readPosition(logConsole);
	}, ({total}) =>
	{
		const narrated = countEntries({actionId, levels: ALL_LEVELS, messageStartsWith: NARRATED_MESSAGE_START});
		const floor = Math.min(narrated, SEARCH_RESULT_CAP);
		const expected = `at least ${floor}${narrated > SEARCH_RESULT_CAP ? ` (${narrated} narrated rows, capped at ${SEARCH_RESULT_CAP})` : ''}`;
		return {expected, observed: total !== null && total >= floor ? expected : `${total}`};
	});
	await consoleStep(context, 'console-pills-close', async() =>
	{
		// The pills' own close controls, then the search box emptied; the range and the levels are set by hand
		// because the model cannot say what closing a pill leaves them at.
		if(await logConsole.correlationPill().count() > 0)
		{
			await logConsole.removeCorrelation();
		}
		if(await logConsole.actionPill().count() > 0)
		{
			await logConsole.removeAction();
		}
		await logConsole.search('');
		await logConsole.waitForListSettled();
		const at = Date.now();
		await logConsole.selectDateRange(DAY_PRESET_LABEL);
		await logConsole.enableAllLevels();
		await logConsole.waitForListSettled();
		return {position: await readPosition(logConsole), at, approximate: await logConsole.approximateBadge().isVisible().catch(() => false)};
	}, ({position, at, approximate}) =>
	{
		const expected = countEntries({levels: ALL_LEVELS, windowStart: at - (DAY_PRESET_MINUTES * MINUTE_MILLISECONDS)});
		return totalVerdict(position.total, expected, approximate);
	});
}

/**
 * @description The page sizes under the pinned action: the rows a page holds, the pager's width, and the
 *              position past the pager; then every page at the widest size, no row repeated or lost.
 * @param {Object} context The run context.
 */
async function consolePaging(context)
{
	const {logConsole, load} = context;
	const actionId = load.reconciliation.id;
	await consoleStep(context, 'console-paging-setup', async() =>
	{
		await logConsole.search(actionId);
		await logConsole.waitForListSettled();
		await logConsole.enableAllLevels();
		await logConsole.waitForListSettled();
		return readPosition(logConsole);
	}, ({total}) => ({expected: 'rows under the action to page through', observed: total > 0 ? 'rows under the action to page through' : `${total} rows`}));
	for(const size of CONSOLE_PAGE_SIZES)
	{
		await consoleStep(context, `console-page-size-${size}`, async() =>
		{
			await logConsole.selectPageSize(size);
			await logConsole.waitForListSettled();
			return {rows: await logConsole.getRowCount(), buttons: await logConsole.pageNumberButtons().count(), position: await readPosition(logConsole)};
		}, ({rows, buttons, position}) =>
		{
			const expected = `${Math.min(size, position.total || 0)} rows, at most ${CONSOLE_PAGE_BUTTONS_MAXIMUM} page buttons`;
			const asExpected = rows === Math.min(size, position.total || 0) && buttons <= CONSOLE_PAGE_BUTTONS_MAXIMUM;
			return {expected, observed: asExpected ? expected : `${rows} rows, ${buttons} page buttons`};
		});
	}
	const widest = CONSOLE_PAGE_SIZES[CONSOLE_PAGE_SIZES.length - 1];
	await consoleStep(context, 'console-page-past-the-pager', async() =>
	{
		for(let press = 0; press < CONSOLE_PAGES_PAST_THE_PAGER; press++)
		{
			await logConsole.clickNextPage();
		}
		return readPosition(logConsole);
	}, ({first}) => ({expected: 1 + (CONSOLE_PAGES_PAST_THE_PAGER * widest), observed: first}));
	await consoleStep(context, 'console-paging-no-repeat-no-loss', async() =>
	{
		await logConsole.search(actionId);
		await logConsole.waitForListSettled();
		const {total} = await readPosition(logConsole);
		return collectPageKeys(logConsole, Math.min(Math.ceil((total || 0) / widest) + 1, PAGE_WALK_CEILING));
	}, (walked) => pagingVerdict(walked, entryKeys({actionId, levels: ALL_LEVELS})));
}

/**
 * @description One drawer-open sample: the drawer closed first when the last sample left it open (a row selected
 *              while it is open costs nothing to time), the timer stopped when the drawer is on screen with no fixed
 *              wait inside the sample, then the usual settle, untimed.
 * @param {Object} context The run context.
 * @param {number} row The row's index on the page.
 */
async function timeDrawerOpen(context, row)
{
	const {logConsole, timing} = context;
	if(await logConsole.detailPanel().isVisible().catch(() => false))
	{
		await logConsole.closeDetail();
		await logConsole.detailPanel().waitFor({state: 'hidden', timeout: DRAWER_CLOSE_TIMEOUT_MILLISECONDS});
	}
	const startedAt = Date.now();
	await logConsole.selectRowUntilDetail(row);
	timing.markRead('drawer-open', Date.now() - startedAt);
	await logConsole.waitForListSettled();
}

/**
 * @description The drawer on the first row, timed as a read, its timeline under the trace cap; then the
 *              problems view's total under the action.
 * @param {Object} context The run context.
 */
async function consoleDrawerAndProblems(context)
{
	const {logConsole, load} = context;
	const actionId = load.reconciliation.id;
	await consoleStep(context, 'console-drawer', async() =>
	{
		// Back on the action's first page (the paging walk left the list on its last), then five rows in turn, so
		// the drawer's read has the samples the protocol asks for; the timeline is read on the last.
		await logConsole.search(actionId);
		await logConsole.waitForListSettled();
		for(let row = 0; row < DRAWER_OPEN_SAMPLES; row++)
		{
			await timeDrawerOpen(context, row);
		}
		await logConsole.openDrawerTab('Timeline');
		return {entries: await logConsole.timelineEntries().count()};
	}, ({entries}) =>
	{
		const expected = `at most ${TIMELINE_ENTRY_CAP} timeline entries`;
		return {expected, observed: entries <= TIMELINE_ENTRY_CAP ? expected : `${entries} timeline entries`};
	});
	await consoleStep(context, 'console-problems-view', async() =>
	{
		await logConsole.switchView('problems');
		return readPosition(logConsole);
	}, ({total}) =>
	{
		// The problems view folds the rolled-up rows by their base fingerprint AND groups the plain forensic rows by
		// signature at read time (CTRL_LogConsole, the derived leg), a fold the oracle does not model; the count is
		// recorded beside the rolled-up rows for the rehearsal to read, never held against the console.
		const rolledUp = countEntries({actionId, levels: ALL_LEVELS, rolledUp: true});
		return {expected: `${rolledUp} rolled-up rows plus the derived groups of the plain rows`, observed: `${total} problems`, informational: true};
	});
}

/**
 * @description The Log Console walked at volume, step by step.
 * @param {Object} context The run context.
 */
async function walkConsole(context)
{
	console.log('\nV: the Log Console at volume');
	await restoreViewport(context);
	await consoleOpens(context);
	await consoleTotalsAndLevels(context);
	await consoleOrigins(context);
	await consoleRanges(context);
	await consoleSearches(context);
	await consolePaging(context);
	await consoleDrawerAndProblems(context);
}

// ---------------------------------------------------------------------------------------------------
// The deep links between the two consoles
// ---------------------------------------------------------------------------------------------------

/**
 * @description The three hand-offs: View logs from a Failed leaf to the console, the chain button from the
 *              console back to the monitor on that run, and Open the chains from the pinned action to the
 *              scoped monitor.
 * @param {Object} context The run context.
 */
async function walkDeepLinks(context)
{
	console.log('\nV: the deep links between the consoles');
	await restoreViewport(context);
	const {logConsole, monitor, page, load} = context;
	const names = load.reconciliation.chainNames;
	const actionId = load.reconciliation.id;
	let leaf = null;
	await consoleStep(context, 'deeplink-failed-leaf', async() =>
	{
		leaf = findRun({token: load.runToken, chainName: names[RECONCILIATION_LEAF_DEPTH], statuses: ['Failed']});
		return leaf ? 'a Failed leaf to follow' : 'no Failed leaf under the load';
	}, (observed) => ({expected: 'a Failed leaf to follow', observed}));
	const requireLeaf = () =>
	{
		if(!leaf)
		{
			throw new Error('no Failed leaf to follow');
		}
	};
	await consoleStep(context, 'deeplink-monitor-to-console', async() =>
	{
		requireLeaf();
		await openRunTimed(context, leaf.correlationId);
		const timer = context.timing.openTimer();
		await monitor.getViewLogsButton().click();
		await logConsole.waitForListRendered();
		timer.stop('console (view logs)');
		await logConsole.waitForListSettled();
		const address = await poll(() => addressKeys(page), (keys) => keys[STATE_KEY_CHAIN] === leaf.correlationId && Boolean(keys[STATE_KEY_WINDOW_START]));
		return {keys: address.value, position: await readPosition(logConsole)};
	}, ({keys, position}) =>
	{
		const windowStart = keys[STATE_KEY_WINDOW_START];
		const windowEnd = keys[STATE_KEY_WINDOW_END];
		if(keys[STATE_KEY_CHAIN] !== leaf.correlationId || !windowStart)
		{
			return {expected: `the run ${leaf.name} pinned with its window`, observed: `keys ${JSON.stringify(keys)}`};
		}
		return totalVerdict(position.total, countEntries({chainId: leaf.correlationId, levels: ALL_LEVELS, windowStart, windowEnd}));
	});
	await consoleStep(context, 'deeplink-console-to-monitor', async() =>
	{
		requireLeaf();
		await logConsole.search(leaf.correlationId);
		await logConsole.waitForListSettled();
		await logConsole.selectRow(0);
		await logConsole.detailPanel().waitFor({state: 'visible', timeout: 30_000});
		const timer = context.timing.openTimer();
		await logConsole.chainButton().click();
		await monitor.waitForListRendered();
		await monitor.getDetailPanel().waitFor({state: 'visible', timeout: 60_000});
		timer.stop('monitor (from console)');
		await settleMonitor(context);
		// The run may sit off page one, so the detail pane is what says which run opened; whether a list row is
		// checked is recorded beside it.
		const checkedRow = await monitor.getDatatable().locator('tr:has(input:checked)').first().getAttribute('data-row-key-value', {timeout: 2000}).catch(() => null);
		return {correlationId: await monitor.getDetailCorrelationId(), checkedRow};
	}, ({correlationId, checkedRow}) =>
	{
		const expected = `the run ${leaf.name} in the detail`;
		let rowNote = 'no list row checked';
		if(checkedRow === leaf.id)
		{
			rowNote = 'its list row checked';
		}
		else if(checkedRow)
		{
			rowNote = `another row checked (${checkedRow})`;
		}
		return {expected, observed: correlationId === leaf.correlationId ? expected : `the detail on ${correlationId || 'nothing'}, ${rowNote}`};
	});
	await consoleStep(context, 'deeplink-console-action-to-monitor', async() =>
	{
		await openConsoleOnAction(context, actionId);
		const timer = context.timing.openTimer();
		await logConsole.openChainsButton().click();
		await monitor.waitForListRendered();
		timer.stop('monitor (scoped)');
		await settleMonitor(context);
		return {pill: await monitor.getActionPill().count(), pages: readPageLabel(await monitor.getPageLabel()).pages};
	}, ({pill, pages}) =>
	{
		const expected = `the scope pill on, ${pagesFor(countRuns({actionId}))} pages`;
		return {expected, observed: `${pill > 0 ? 'the scope pill on' : 'no scope pill'}, ${pages} pages`};
	});
}

module.exports = {
	walkConsole,
	walkDeepLinks,
	walkMonitor,
	collectPageKeys,
	describeGates,
	expectedGates,
	findRepeatsAndLosses,
	isOrdered,
	readPageLabel,
	pagesFor,
	pageCapFor,
	restoreViewport,
	timeDrawerOpen,
	resolveOutputDirectory,
	STATUSES,
	SORT_COLUMNS
};
