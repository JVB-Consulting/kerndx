// SPDX-License-Identifier: Apache-2.0
// The shape table of the consoles-at-volume load. The candidate shape is the spec's (section 2.1); what the platform
// measured is the probe's, read from probe-report.json beside this file and never guessed: the
// driver refuses to run without it. A remembered platform limit is not a measured one.
const fs = require('fs');
const path = require('path');

const PROBE_REPORT_PATH = path.join(__dirname, 'probe-report.json');
const STALL_STRATEGIES = [
	'engine',
	'synthesized'
];

/**
 * @description The probe's measured record: drain rate, peak queue depths, the stall answer, whether thirteen roots
 * fit one transaction. Throws when the file is absent or carries no measured rate.
 *
 * @param {string} [filePath] The report, default the committed one beside this file.
 *
 * @returns {object}
 */
function readProbeReport(filePath = PROBE_REPORT_PATH)
{
	if(!fs.existsSync(filePath))
	{
		throw new Error(
				`No probe report at ${filePath}. Run release-testing/scripts/consoles-at-volume-probe.js first; `
					+ 'the shape table carries no guessed number.');
	}
	const report = JSON.parse(fs.readFileSync(filePath, 'utf8'));
	const missing = [
		{name: 'jobsPerMinute above zero', present: report.jobsPerMinute > 0},
		{name: 'stallStrategy (engine or synthesized)', present: STALL_STRATEGIES.includes(report.stallStrategy)},
		{name: 'fitsInOneTransaction (true or false)', present: typeof report.fitsInOneTransaction === 'boolean'},
		{name: 'measuredAt', present: Boolean(report.measuredAt)}
	].filter((check) => !check.present).map((check) => check.name);
	if(missing.length > 0)
	{
		throw new Error(`The probe report at ${filePath} is incomplete: it needs ${missing.join(', ')}.`);
	}
	return report;
}

/**
 * @description The probe's answer on genuine Stalled rows: 'engine' when a step that spent the enqueue left one, else
 * 'synthesized' (the wave lays down fixture rows, classed as such).
 *
 * @param {object} [report] The probe report, default the committed one.
 *
 * @returns {string}
 */
function stallStrategy(report = readProbeReport())
{
	return report.stallStrategy;
}

// The candidate shape, ratified from the probe's measurement: rootsPerBatch and the stagger
// follow the report's fitsInOneTransaction.
const RECONCILIATION_SHAPE = {
	chainNames: [
		'Volume_Reconciliation',
		'Volume_RegionReconcile',
		'Volume_LedgerReconcile',
		'Volume_AccountReconcile'
	], roots: 13, fanOut: 5, targetDepth: 3, busyMilliseconds: 1500
};
const FAILING_LEAF_EVERY = 8;
const FAILING_KINDS = 3;
const OUTCOMES = {succeed: 'succeed', fail: 'fail', failPermanently: 'failPermanently', failAfterRetries: 'failAfterRetries'};

// One launch each; `runs` counts every row the launch produces, `status` the row's end state after the drain.
const SMALL_ACTION_SHAPES = {
	OrderSync: {chainName: 'Volume_OrderSync', runs: 1, status: 'Completed'},
	InvoiceExport: {chainName: 'Volume_InvoiceExport', runs: 1, status: 'Failed', category: 'StepException'},
	PartialSync: {chainName: 'Volume_PartialSync', runs: 1, status: 'Completed'},
	RecoverableImport: {chainName: 'Volume_RecoverableImport', runs: 1, status: 'Failed', category: 'StepException', retryCandidate: true},
	RestartableLoad: {chainName: 'Volume_RestartableLoad', runs: 1, status: 'Failed', category: 'StepException', restartCandidate: true},
	NightlyReconciliation: {chainName: 'Volume_NightlyReconciliation', runs: 1, status: 'Completed'},
	DeferredNotification: {chainName: 'Volume_DeferredNotification', runs: 1, status: 'Completed', holding: true},
	// Seven runs: the root, its fanning child and five leaves; the leaf with ordinal 0 fails by the fan-out rule (every eighth leaf, from 0).
	NestedImport: {chainName: 'Volume_NestedImport', runs: 7, status: 'Completed', byStatus: {Completed: 6, Failed: 1}},
	OrderSyncNotified: {chainName: 'Volume_OrderSyncNotified', runs: 2, status: 'Completed'}
};
// A launch that alternates between a deferred chain and an order sync, action by action of its kind.
const DEFERRED_OR_ORDER_SYNC = 'DeferredOrOrderSync';
const SMALL_ACTION_KINDS = [
	{
		kind: 'orders',
		launches: [
			{shape: 'OrderSync', count: 3},
			{shape: 'InvoiceExport', count: 2}
		]
	},
	{
		kind: 'imports',
		launches: [
			{shape: 'PartialSync', count: 2},
			{shape: 'RecoverableImport', count: 2},
			{shape: 'RestartableLoad', count: 1}
		]
	},
	{
		kind: 'nightly',
		launches: [
			{shape: 'NightlyReconciliation', count: 1},
			{shape: 'OrderSync', count: 2},
			{shape: 'InvoiceExport', count: 1},
			{shape: DEFERRED_OR_ORDER_SYNC, count: 1}
		]
	},
	{
		kind: 'nested',
		launches: [
			{shape: 'NestedImport', count: 1},
			{shape: 'OrderSync', count: 2},
			{shape: 'RecoverableImport', count: 1},
			{shape: 'RestartableLoad', count: 1}
		]
	},
	{
		kind: 'handlers',
		launches: [
			{shape: 'OrderSyncNotified', count: 2},
			{shape: 'InvoiceExport', count: 2},
			{shape: 'RestartableLoad', count: 1}
		]
	}
];
const SMALL_ACTIONS = {count: 200, perBatch: 7};
const OPERATOR_WAVE = {retries: 20, restarts: 20, aborts: 10, killSwitchBatch: 50, deadJobStalls: 20, synthesizedStalled: 10};
const STAGED_ENGINE_SHARE = {roots: 1, smallActions: 12, wave: {retries: 3, restarts: 3, aborts: 2, killSwitchBatch: 5, deadJobStalls: 2, synthesizedStalled: 2}};
const WAVE_CHAIN_NAMES = {
	slowExport: 'Volume_SlowExport',
	switchedOff: 'Volume_SwitchedOff',
	deferredDispatch: 'Volume_DeferredDispatch',
	stallProbe: 'Volume_StallProbe',
	stalledArchive: 'Volume_StalledArchive'
};

/**
 * @description Runs one root produces: the root plus every level below it.
 *
 * @param {number} fanOut Children per fanning chain.
 * @param {number} targetDepth Levels below the root.
 *
 * @returns {number}
 */
function runsPerRoot(fanOut, targetDepth)
{
	let runs = 0;
	for(let depth = 0; depth <= targetDepth; depth++)
	{
		runs += fanOut ** depth;
	}
	return runs;
}

/**
 * @description The Apex rule (SubscriberChainSteps.leafOutcome), repeated so expectations are computed here.
 *
 * @param {number} leafOrdinal The leaf's ordinal within its level under its root.
 *
 * @returns {string} One of OUTCOMES.
 */
function leafOutcome(leafOrdinal)
{
	if(leafOrdinal % FAILING_LEAF_EVERY !== 0)
	{
		return OUTCOMES.succeed;
	}
	const kind = Math.floor(leafOrdinal / FAILING_LEAF_EVERY) % FAILING_KINDS;
	if(kind === 1)
	{
		return OUTCOMES.failPermanently;
	}
	return kind === 2 ? OUTCOMES.failAfterRetries : OUTCOMES.fail;
}

/**
 * @description What the database holds once every root has drained.
 *
 * @param {number} roots How many roots.
 * @param {number} fanOut Children per fanning chain.
 * @param {number} targetDepth Levels below the root.
 *
 * @returns {{runs: number, leaves: number, byStatus: object, byCategory: object}}
 */
function expectedReconciliation(roots, fanOut, targetDepth)
{
	const leavesPerRoot = fanOut ** targetDepth;
	let failedPerRoot = 0;
	let retriesPerRoot = 0;
	for(let ordinal = 0; ordinal < leavesPerRoot; ordinal++)
	{
		const outcome = leafOutcome(ordinal);
		if(outcome !== OUTCOMES.succeed)
		{
			failedPerRoot++;
		}
		if(outcome === OUTCOMES.failAfterRetries)
		{
			retriesPerRoot++;
		}
	}
	const runs = roots * runsPerRoot(fanOut, targetDepth);
	const failed = roots * failedPerRoot;
	const retriesExhausted = roots * retriesPerRoot;
	return {
		runs,
		leaves: roots * leavesPerRoot,
		byStatus: {Completed: runs - failed, Failed: failed},
		byCategory: {StepException: failed - retriesExhausted, RetriesExhausted: retriesExhausted}
	};
}

/**
 * @description The shape a launch names, with the alternating one resolved for the action's turn.
 *
 * @param {string} shapeName The launch's shape name.
 * @param {object} action The action being planned.
 *
 * @returns {string}
 */
function resolveShape(shapeName, action)
{
	if(shapeName !== DEFERRED_OR_ORDER_SYNC)
	{
		return shapeName;
	}
	return Math.floor(action.ordinal / SMALL_ACTION_KINDS.length) % 2 === 0 ? 'DeferredNotification' : 'OrderSync';
}

/**
 * @description One small action: its kind by ordinal, what it launches and what to expect once drained.
 *
 * @param {number} ordinal The action's ordinal in launch order.
 *
 * @returns {object}
 */
function planSmallAction(ordinal)
{
	const kind = SMALL_ACTION_KINDS[ordinal % SMALL_ACTION_KINDS.length];
	const action = {ordinal, kind: kind.kind, launches: [], expected: {runs: 0, byStatus: {Completed: 0, Failed: 0}}, retryCandidates: 0, restartCandidates: 0};
	for(const launch of kind.launches)
	{
		const shapeName = resolveShape(launch.shape, action);
		const shape = SMALL_ACTION_SHAPES[shapeName];
		action.launches.push({shape: shapeName, count: launch.count});
		action.expected.runs += shape.runs * launch.count;
		for(const [status, runs] of Object.entries(shape.byStatus || {[shape.status]: shape.runs}))
		{
			action.expected.byStatus[status] += runs * launch.count;
		}
		action.retryCandidates += shape.retryCandidate ? launch.count : 0;
		action.restartCandidates += shape.restartCandidate ? launch.count : 0;
	}
	return action;
}

/**
 * @description The small actions in launch order, each with what it launches and what to expect.
 *
 * @param {number} count How many actions.
 *
 * @returns {object[]}
 */
function planSmallActions(count)
{
	return Array.from({length: count}, (unused, ordinal) => planSmallAction(ordinal));
}

/**
 * @description Items in batches of a size, the last one shorter.
 *
 * @param {Array} items The items.
 * @param {number} perBatch The batch size.
 *
 * @returns {Array[]}
 */
function planBatches(items, perBatch)
{
	const batches = [];
	for(let start = 0; start < items.length; start += perBatch)
	{
		batches.push(items.slice(start, start + perBatch));
	}
	return batches;
}

/**
 * @description A count scaled by the size factor, never below one.
 *
 * @param {number} count The count at size one.
 * @param {number} size The size factor.
 *
 * @returns {number}
 */
function scaleCount(count, size)
{
	return Math.max(1, Math.round(count * size));
}

/**
 * @description The load a mode and size factor ask for: the same shape either way, the engine's share differing,
 * the roots-per-batch and stagger from the probe's report.
 *
 * @param {string} mode `staged` or `full`.
 * @param {number} size The size factor.
 * @param {object} [report] The probe report, default the committed one.
 *
 * @returns {object}
 */
function scaleShape(mode, size, report = readProbeReport())
{
	const roots = scaleCount(RECONCILIATION_SHAPE.roots, size);
	const smallCount = scaleCount(SMALL_ACTIONS.count, size);
	const staged = mode === 'staged';
	const wave = {};
	for(const [key, value] of Object.entries(OPERATOR_WAVE))
	{
		wave[key] = staged ? Math.min(STAGED_ENGINE_SHARE.wave[key], scaleCount(value, size)) : scaleCount(value, size);
	}
	return {
		mode,
		size,
		probe: {measuredAt: report.measuredAt, jobsPerMinute: report.jobsPerMinute, peakHolding: report.peakHolding},
		reconciliation: {
			...RECONCILIATION_SHAPE,
			roots,
			engineRoots: staged ? Math.min(STAGED_ENGINE_SHARE.roots, roots) : roots,
			rootsPerBatch: report.fitsInOneTransaction ? RECONCILIATION_SHAPE.roots : 1,
			staggerRootsByMinutes: report.fitsInOneTransaction
		},
		smallActions: {count: smallCount, engineCount: staged ? Math.min(STAGED_ENGINE_SHARE.smallActions, smallCount) : smallCount, perBatch: SMALL_ACTIONS.perBatch},
		wave,
		expected: {reconciliation: expectedReconciliation(roots, RECONCILIATION_SHAPE.fanOut, RECONCILIATION_SHAPE.targetDepth), smallActions: planSmallActions(smallCount)}
	};
}

module.exports = {
	PROBE_REPORT_PATH,
	readProbeReport,
	stallStrategy,
	RECONCILIATION_SHAPE,
	FAILING_LEAF_EVERY,
	OUTCOMES,
	SMALL_ACTION_SHAPES,
	SMALL_ACTION_KINDS,
	SMALL_ACTIONS,
	OPERATOR_WAVE,
	STAGED_ENGINE_SHARE,
	WAVE_CHAIN_NAMES,
	runsPerRoot,
	leafOutcome,
	expectedReconciliation,
	planSmallActions,
	planBatches,
	scaleShape
};
