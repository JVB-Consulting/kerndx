// SPDX-License-Identifier: Apache-2.0
// Sends the engine share of the load to the org, batch by batch, draining between batches, recording every id.
const {fillNamespaceTokens} = require('../../e2e/helpers/sf-namespace');
const {recordStage, mintVolumeId, KINDS} = require('./manifest');
const {planBatches} = require('./shapes');
const {renderTemplate, readLaunchLine} = require('./apex-templates');
const {drainQueue, peakDepth, waitForRunToSettle, drainRateRecord, runningRunsQuery, readWithRetry, defaultSleep} = require('./drain');
const {synthesize} = require('./synthesized-rows');

// Small actions are keyed from ordinal one; the reconciliation action is ordinal zero.
const SMALL_ACTION_OFFSET = 1;
// A sample with this many live jobs or more counts as pressure in the manifest.
const PRESSURE_ACTIVE_JOBS = 50;
// A launch call that failed in transit (the CLI's "fetch failed") is attempted this many times in all; before each retry the
// batch is read back from the org, since the script may have run without its answer arriving.
const LAUNCH_ATTEMPTS = 3;
const LAUNCH_RETRY_WAIT_MILLISECONDS = 15_000;

/**
 * @description One action's record in the manifest.
 *
 * @param {string} kind The action kind.
 * @param {string} id The action's token-keyed id.
 * @param {number} ordinal The action's ordinal.
 * @param {object} expected What the database should hold for it.
 * @param {object} [extra] More fields for the record.
 *
 * @returns {object}
 */
function actionRecord(kind, id, ordinal, expected, extra = {})
{
	return {id, kind, ordinal, expected, synthesized: false, ...extra};
}

/**
 * @description Writes the manifest as it stands, when the entry gave the stage a way to: a failure later in the stage
 * then keeps every batch recorded so far, and a rerun continues past them.
 *
 * @param {object} context The stage context.
 */
function persistManifest(context)
{
	if(context.persist)
	{
		context.persist(context.manifest);
	}
}

/**
 * @description The runs a batch launched, read back from the org: the rows under the action whose launch correlation is
 * the action itself (the runs the script inserted; a fan-out child carries its parent run's correlation instead), minus
 * the ids an earlier batch under the same action already recorded. The read is retried like a drain poll, since the
 * blip that broke the launch call may still be on the line.
 *
 * @param {object} context The stage context.
 * @param {object} batch `actionId`, `knownIds` (the ids already recorded under the action).
 *
 * @returns {Promise<string[]>} The ids, in the launch line's order: the minted run correlation carries the launch index.
 */
async function readLandedBatch(context, {actionId, knownIds = []})
{
	const field = (name) => `${context.manifest.org.namespacePrefix}${name}`;
	const launchedByTheAction = `${field('RootCorrelationId__c')} = '${actionId}' AND ${field('LaunchCorrelationId__c')} = '${actionId}'`;
	const soql = `SELECT Id FROM ${field('AsyncChainExecution__c')} WHERE ${launchedByTheAction} ORDER BY ${field('CorrelationId__c')}`;
	const known = new Set(knownIds);
	const read = () => context.salesforce.query(soql);
	const retry = {sleep: context.sleep || defaultSleep, waitMilliseconds: LAUNCH_RETRY_WAIT_MILLISECONDS, log: context.log, what: 'launch: WARNING the read-back query failed'};
	const {records} = await readWithRetry(read, retry);
	return records.map((row) => row.Id).filter((id) => !known.has(id));
}

/**
 * @description Reads a batch back from the org and says what landed: the whole batch, taken as its launch line; nothing,
 * so the launch is sent (again); or a count no single transaction explains, which stops the stage.
 *
 * @param {object} context The stage context.
 * @param {string} label The batch's name.
 * @param {object} batch `stage`, `actionId`, `ordinal`, `expectedCount`, `knownIds`.
 * @param {string} reason Why the batch is being read back, for the log.
 *
 * @returns {Promise<object|null>} The launch line, or null when nothing landed.
 */
async function landedLaunchLine(context, label, batch, reason)
{
	const landed = await readLandedBatch(context, batch);
	if(landed.length === batch.expectedCount)
	{
		context.log(`launch: WARNING ${label}: ${reason}; its ${landed.length} runs read back from the org`);
		return {stage: batch.stage, action: batch.actionId, ordinal: batch.ordinal, ids: landed, launched: landed.length};
	}
	if(landed.length > batch.expectedCount)
	{
		throw new Error(`${label}: the org holds ${landed.length} runs under the action where ${batch.expectedCount} were launched; `
				+ 'the read-back matched runs that are not the batch, or another launch shares the action');
	}
	if(landed.length > 0)
	{
		throw new Error(`${label}: ${reason} and the org holds ${landed.length} of its ${batch.expectedCount} runs; `
				+ 'one transaction cannot land part of a batch, so something else is wrong');
	}
	return null;
}

/**
 * @description Sends one launch script. A call that failed in transit is not simply repeated, since the script may have
 * run without its answer arriving and a launch is never repeated once its runs exist: after a wait (the org may still be
 * committing what the call sent) the batch is read back from the org, taken as the launch line when it is whole, sent
 * again when nothing landed, up to a bounded number of attempts. A rerun's first unrecorded batch is read back before it
 * is sent at all, since the earlier run may have stopped between launching it and recording it.
 *
 * @param {object} context The stage context.
 * @param {string} apex The rendered script, namespace tokens still in it.
 * @param {string} label The batch's name.
 * @param {object} batch `stage`, `actionId`, `ordinal`, `expectedCount`, `knownIds`.
 *
 * @returns {Promise<object>} The launch line.
 */
async function sendLaunch(context, apex, label, batch)
{
	const sleep = context.sleep || defaultSleep;
	if(context.readBackNextBatch)
	{
		context.readBackNextBatch = false;
		const landedBefore = await landedLaunchLine(context, label, batch, 'the earlier run stopped before recording it');
		if(landedBefore)
		{
			return landedBefore;
		}
	}
	for(let attempt = 1; ; attempt++)
	{
		try
		{
			const result = context.salesforce.runApex(fillNamespaceTokens(apex, context.manifest.org.namespacePrefix), label);
			return readLaunchLine(result.debugLines);
		}
		catch(failure)
		{
			if(!failure.transient)
			{
				throw failure;
			}
			const reason = String(failure.message).split('\n')[0];
			await sleep(LAUNCH_RETRY_WAIT_MILLISECONDS);
			const landed = await landedLaunchLine(context, label, batch, `the call failed in transit (${reason}) after the script ran`);
			if(landed)
			{
				return landed;
			}
			if(attempt >= LAUNCH_ATTEMPTS)
			{
				throw failure;
			}
			context.log(`launch: WARNING ${label}: the call failed in transit (${reason}) and nothing landed; attempt ${attempt + 1} of ${LAUNCH_ATTEMPTS}`);
		}
	}
}

/**
 * @description Sends one launch script and records the batch.
 *
 * @param {object} context The stage context.
 * @param {string} apex The rendered script, namespace tokens still in it.
 * @param {string} label The batch's name.
 * @param {object} batch What the script launches, for a read-back after a call that failed in transit (see sendLaunch).
 *
 * @returns {Promise<object>} The parsed launch line.
 */
async function launchBatch(context, apex, label, batch)
{
	const startedAt = new Date().toISOString();
	const line = await sendLaunch(context, apex, label, batch);
	context.manifest.batches.push({label, startedAt, finishedAt: new Date().toISOString(), launched: line.launched});
	context.log(`launch: ${label} launched ${line.launched} under ${line.action}`);
	return line;
}

/**
 * @description Waits for the queue between batches and records its pressure. The pressure is measured and reported,
 * never shaped: the gate only spaces top-level batches, the fan-out inside a root queues what it queues, and the peak
 * of every drain's samples goes into the manifest.
 *
 * @param {object} context The stage context.
 *
 * @returns {Promise<object>} The drain's result.
 */
async function drainBetween(context)
{
	const drain = context.drain || drainQueue;
	const result = await drain({salesforce: context.salesforce, sinceIso: context.manifest.startedAt, sleep: context.sleep});
	const peak = peakDepth(result.samples);
	const {manifest} = context;
	manifest.batches[manifest.batches.length - 1].peak = peak;
	manifest.pressure = manifest.pressure || {peakActive: 0, peakHolding: 0, samplesAboveFifty: 0};
	manifest.pressure.peakActive = Math.max(manifest.pressure.peakActive, peak.active);
	manifest.pressure.peakHolding = Math.max(manifest.pressure.peakHolding, peak.holding);
	manifest.pressure.samplesAboveFifty += result.samples.filter((sample) => sample.active >= PRESSURE_ACTIVE_JOBS).length;
	if(result.timedOut)
	{
		context.log('launch: the queue did not drain inside the timeout; going on, recorded');
		manifest.batches.push({label: 'drain-timeout', at: new Date().toISOString()});
	}
	return result;
}

/**
 * @description Launches the reconciliation's engine roots, batch by batch, under one action id.
 *
 * @param {object} context The stage context.
 * @param {string} actionId The reconciliation action's id.
 */
async function launchReconciliation(context, actionId)
{
	const {manifest, shape} = context;
	const reconciliation = shape.reconciliation;
	// A rerun continues past the root batches already recorded.
	const recordedRoots = () => manifest.roots.filter((root) => root.actionId === actionId);
	let launchedRoots = recordedRoots().length;
	while(launchedRoots < reconciliation.engineRoots)
	{
		const rootCount = Math.min(reconciliation.rootsPerBatch, reconciliation.engineRoots - launchedRoots);
		const values = {
			__ACTION_ID__: actionId,
			__RUN_TOKEN__: manifest.runToken,
			__ROOT_START__: launchedRoots,
			__ROOT_COUNT__: rootCount,
			__TARGET_DEPTH__: reconciliation.targetDepth,
			__BUSY_MILLISECONDS__: reconciliation.busyMilliseconds,
			__STAGGER__: reconciliation.staggerRootsByMinutes && rootCount > 1
		};
		const batch = {stage: 'reconciliation', actionId, ordinal: launchedRoots, expectedCount: rootCount, knownIds: recordedRoots().map((root) => root.executionId)};
		const line = await launchBatch(context, renderTemplate('launch-reconciliation.apex', values), `reconciliation-${launchedRoots}`, batch);
		if(line.action !== actionId)
		{
			throw new Error(`The launch script answered under action ${line.action}, not the minted ${actionId}`);
		}
		const firstOrdinal = launchedRoots;
		line.ids.forEach((executionId, index) => manifest.roots.push({actionId, ordinal: firstOrdinal + index, executionId}));
		launchedRoots += rootCount;
		persistManifest(context);
		await drainBetween(context);
	}
	if(!manifest.actions.some((action) => action.id === actionId))
	{
		const extra = {engineRoots: reconciliation.engineRoots, roots: reconciliation.roots, chainNames: reconciliation.chainNames};
		manifest.actions.push(actionRecord('reconciliation', actionId, 0, shape.expected.reconciliation, extra));
		persistManifest(context);
	}
}

/**
 * @description Launches the engine share of the small actions, one transaction each, draining after each batch.
 *
 * @param {object} context The stage context.
 */
async function launchSmallActions(context)
{
	const {manifest, shape} = context;
	const engineActions = shape.expected.smallActions.slice(0, shape.smallActions.engineCount);
	for(const batch of planBatches(engineActions, shape.smallActions.perBatch))
	{
		let launchedInBatch = false;
		for(const action of batch)
		{
			const smallActionId = mintVolumeId(KINDS.action, manifest.runToken, action.ordinal + SMALL_ACTION_OFFSET, 0, 0);
			// A rerun continues past the actions already recorded.
			if(!manifest.actions.some((recorded) => recorded.id === smallActionId))
			{
				launchedInBatch = true;
				const values = {
					__ACTION_ID__: smallActionId, __RUN_TOKEN__: manifest.runToken, __ACTION_ORDINAL__: action.ordinal, __LAUNCH_PLAN__: JSON.stringify(action.launches)
				};
				const expectedCount = action.launches.reduce((sum, launch) => sum + launch.count, 0);
				const launching = {stage: 'small', actionId: smallActionId, ordinal: action.ordinal, expectedCount};
				const line = await launchBatch(context, renderTemplate('launch-small-action.apex', values), `small-${action.ordinal}`, launching);
				const extra = {launches: action.launches, executionIds: line.ids, retryCandidates: action.retryCandidates, restartCandidates: action.restartCandidates};
				manifest.actions.push(actionRecord(action.kind, smallActionId, action.ordinal, action.expected, extra));
				persistManifest(context);
			}
		}
		// A batch skipped whole on a rerun launched nothing to drain, and a drain here would overwrite a recorded peak.
		if(launchedInBatch)
		{
			await drainBetween(context);
		}
	}
}

/**
 * @description The launch stage: the engine share of the reconciliation and of the small actions.
 *
 * @param {object} context `{options, salesforce, shape, manifest, log, sleep, drain}`.
 *
 * @returns {Promise<object>} The manifest with the stage recorded.
 */
async function run(context)
{
	const {manifest} = context;
	if(manifest.stages.preflight && manifest.stages.preflight.reused)
	{
		return recordStage(manifest, 'launch', {ok: true, reused: true});
	}
	// A rerun after a settle that timed out picks up here: the launches were sent once and are never repeated.
	if(!manifest.launchedAt)
	{
		// A rerun after a failure mid-launch continues past the recorded batches; the first unrecorded one is read back
		// from the org before it is sent, since the earlier run may have launched it and stopped before recording it.
		// That holds for the very first batch too, where nothing is recorded yet; a fresh token costs one empty read.
		context.readBackNextBatch = true;
		await launchReconciliation(context, mintVolumeId(KINDS.action, manifest.runToken, 0, 0, 0));
		await launchSmallActions(context);
		manifest.launchedAt = new Date().toISOString();
	}
	if(manifest.mode === 'staged')
	{
		// The clones copy what the engine wrote, so the engine share must have ended: every retry spent, every deferred chain run.
		// That wait spans the engine share's whole run, so it is the run's drain rate; the drain stage keeps it.
		const settled = await waitForRunToSettle(context);
		manifest.drainRate = drainRateRecord(settled, 'launch');
		if(settled.timedOut)
		{
			const running = context.salesforce.query(runningRunsQuery(manifest)).totalSize;
			const reason = `the engine share did not settle inside its box: ${running} runs still Running, so nothing was cloned. Wait for them to end, then run launch again `
					+ '(the launches are not repeated).';
			return recordStage(manifest, 'launch', {ok: false, reason});
		}
		const filled = await synthesize(context);
		if(filled.stages.launch && filled.stages.launch.ok === false)
		{
			return filled;
		}
	}
	return recordStage(manifest, 'launch', {ok: true, reused: false, roots: manifest.roots.length, actions: manifest.actions.length});
}

module.exports = {run};
