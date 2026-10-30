// SPDX-License-Identifier: Apache-2.0
// Part 1 of the exploration: the shaped seed, its teardown, and the row oracle read from the database.
'use strict';

const {runApexScript, soqlQuery} = require('../helpers/sf-cli');
const {namespacePrefix} = require('../helpers/sf-namespace');
const {runShapedSeed} = require('../helpers/log-console-seed');
const {TEARDOWN_SCRIPT, RUN_WINDOW_MARGIN_MILLISECONDS} = require('./constants');

// The shaped seed's fixtures, by the ids the seed script and part10's journeys use.
const ACTION_CHECKOUT = 'e2ee2ee2-0000-4000-8000-000000000a01';
const CHAIN_RESERVE = 'e2ee2ee2-0000-4000-8000-000000000a0a';
const CHAIN_NOTIFY = 'e2ee2ee2-0000-4000-8000-000000000a0b';
const CHAIN_LEDGER = 'e2ee2ee2-0000-4000-8000-000000000a0c';
const ACTION_NIGHTLY = 'e2ee2ee2-0000-4000-8000-000000000b01';
const CHAIN_NIGHTLY_RESTART = 'e2ee2ee2-0000-4000-8000-000000000b02';
const ACTION_LEGACY = 'e2ee2ee2-0000-4000-8000-000000000c01';
const UNKNOWN_ID = 'e2ee2ee2-0000-4000-8000-0000000000ff';
const NOTIFY_CHAIN_NAME = 'E2E Checkout Notify';

// The chain runs the seed lays down, by correlation id: what a named chain pill must read.
const CHAIN_NAMES = {
	[CHAIN_RESERVE]: 'E2E Checkout Reserve',
	[CHAIN_NOTIFY]: NOTIFY_CHAIN_NAME,
	[CHAIN_LEDGER]: 'E2E Checkout Ledger',
	[ACTION_NIGHTLY]: 'E2E Nightly Sync',
	[CHAIN_NIGHTLY_RESTART]: 'E2E Nightly Sync',
	[ACTION_LEGACY]: 'E2E Legacy Fulfilment'
};
// Which chains each seeded action lists as its chips, so a cross state the fixtures cannot produce
// is left unchecked rather than guessed at.
const ACTION_CHAINS = {
	[ACTION_CHECKOUT]: [CHAIN_RESERVE, CHAIN_NOTIFY, CHAIN_LEDGER],
	[ACTION_NIGHTLY]: [ACTION_NIGHTLY, CHAIN_NIGHTLY_RESTART],
	[ACTION_LEGACY]: [ACTION_LEGACY]
};
const SEEDED_ACTIONS = [ACTION_CHECKOUT, ACTION_NIGHTLY, ACTION_LEGACY];
// Every id the seed writes a row under: what the oracle reads, and what the teardown has to leave
// nothing behind for.
const FIXTURE_IDS = [ACTION_CHECKOUT, CHAIN_RESERVE, CHAIN_NOTIFY, CHAIN_LEDGER, ACTION_NIGHTLY, CHAIN_NIGHTLY_RESTART, ACTION_LEGACY];
const CHECKOUT_SENTENCE_FRAGMENT = 'It ran 3 chains, 1 of them failed.';
const LEGACY_SENTENCE = 'This action was recorded before chains were tracked by action.';
const EXPECTED_CHIP_COUNT = {[ACTION_CHECKOUT]: 3, [ACTION_NIGHTLY]: 2, [ACTION_LEGACY]: 1};
// What the seed script documents its whole-action rows as (seed-log-console-actions.apex, the actionRows
// list): the checkout click's own two entries plus its three chains' one each, the failed chain's
// single entry, the nightly job and its restart, and the legacy pair. Checked before the walk starts,
// so a seed that landed differently is a finding rather than a mystery under every row count.
const DOCUMENTED_ROW_TOTALS = [
	{name: 'the checkout action, whole', action: ACTION_CHECKOUT, chain: null, rows: 5},
	{name: 'the checkout action narrowed to its failed chain', action: ACTION_CHECKOUT, chain: CHAIN_NOTIFY, rows: 1},
	{name: 'the nightly action, whole', action: ACTION_NIGHTLY, chain: null, rows: 2},
	{name: 'the legacy action, whole', action: ACTION_LEGACY, chain: null, rows: 2}
];

function prefixed(apiName)
{
	return `${namespacePrefix()}${apiName}`;
}

function seedFixtures()
{
	// Throws, naming the script, when either part of the seed does not report its rows: there would be no fixtures to explore.
	return runShapedSeed();
}

function tearDownFixtures()
{
	runApexScript(TEARDOWN_SCRIPT, {timeout: 300_000});
}

/**
 * @description How many log rows still carry any of the seed's ids. Run after the teardown: on a
 *              shared org a fixture left behind is the next run's mystery, so the count is proved
 *              rather than assumed.
 * @returns {number|null} The surviving row count, or null when the query itself could not answer.
 */
function countSurvivingFixtureRows()
{
	const quoted = FIXTURE_IDS.map((id) => `'${id}'`).join(', ');
	const rows = soqlQuery(`SELECT COUNT(Id) total FROM ${prefixed('LogEntry__c')}`
			+ ` WHERE ${prefixed('CorrelationId__c')} IN (${quoted}) OR ${prefixed('RootCorrelationId__c')} IN (${quoted})`);
	return rows[0] && rows[0].total !== undefined ? Number(rows[0].total) : null;
}

/**
 * @description Every seeded log row the exploration can pin, read from the database: its level, the
 *              run it belongs to, the action above it and when it was written. The expected row count
 *              for a pinned state is computed from these rather than from a hardcoded number, so a
 *              seed that lands differently than the fixtures describe is visible as a disagreement
 *              with the design rather than as a mystery. The failed chain's own recorded bounds come
 *              with them, widened by the monitor's margin: that is the window a View logs hand-off
 *              owes the address, worked out without reading the address it will be checked against.
 * @returns {Object} The rows, each action's entry span, and the failed run's expected log window.
 */
function readOracle()
{
	const quoted = FIXTURE_IDS.map((id) => `'${id}'`).join(', ');
	const records = soqlQuery(`SELECT ${prefixed('LogLevel__c')}, ${prefixed('CorrelationId__c')}, ${prefixed('RootCorrelationId__c')}, CreatedDate`
			+ ` FROM ${prefixed('LogEntry__c')} WHERE ${prefixed('CorrelationId__c')} IN (${quoted})`
			+ ` OR ${prefixed('RootCorrelationId__c')} IN (${quoted})`);
	const rows = records.map((record) => ({
		level: record[prefixed('LogLevel__c')],
		correlation: record[prefixed('CorrelationId__c')],
		root: record[prefixed('RootCorrelationId__c')],
		createdAt: new Date(record.CreatedDate).getTime()
	}));
	const actionSpans = {};
	for(const action of SEEDED_ACTIONS)
	{
		const stamps = rows.filter((row) => row.root === action || row.correlation === action).map((row) => row.createdAt);
		actionSpans[action] = stamps.length ? {first: Math.min(...stamps), last: Math.max(...stamps)} : null;
	}
	return {rows, actionSpans, notifyRunWindow: readRunWindow(CHAIN_NOTIFY)};
}

/**
 * @description The log window the Chain Monitor's View logs owes for one run: its recorded start and
 *              finish, each moved out by the monitor's margin, read from the run row itself.
 * @param {string} correlationId The run's correlation id.
 * @returns {Object|null} The window as two ISO instants, or null when the run has no recorded start.
 */
function readRunWindow(correlationId)
{
	const runs = soqlQuery(`SELECT ${prefixed('StartedAt__c')}, ${prefixed('CompletedAt__c')} FROM ${prefixed('AsyncChainExecution__c')}`
			+ ` WHERE ${prefixed('CorrelationId__c')} = '${correlationId}' ORDER BY CreatedDate DESC LIMIT 1`);
	const startedAt = runs[0] ? runs[0][prefixed('StartedAt__c')] : null;
	if(!startedAt)
	{
		return null;
	}
	const completedAt = runs[0][prefixed('CompletedAt__c')];
	const shift = (instant, offset) => new Date(Date.parse(instant) + offset).toISOString();
	return {
		start: shift(startedAt, -RUN_WINDOW_MARGIN_MILLISECONDS),
		end: completedAt ? shift(completedAt, RUN_WINDOW_MARGIN_MILLISECONDS) : null
	};
}

module.exports = {
	ACTION_CHECKOUT,
	CHAIN_RESERVE,
	CHAIN_NOTIFY,
	CHAIN_LEDGER,
	ACTION_NIGHTLY,
	CHAIN_NIGHTLY_RESTART,
	ACTION_LEGACY,
	UNKNOWN_ID,
	NOTIFY_CHAIN_NAME,
	CHAIN_NAMES,
	ACTION_CHAINS,
	SEEDED_ACTIONS,
	FIXTURE_IDS,
	CHECKOUT_SENTENCE_FRAGMENT,
	LEGACY_SENTENCE,
	EXPECTED_CHIP_COUNT,
	DOCUMENTED_ROW_TOTALS,
	prefixed,
	seedFixtures,
	tearDownFixtures,
	countSurvivingFixtureRows,
	readOracle,
	readRunWindow
};
