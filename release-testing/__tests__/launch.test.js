// SPDX-License-Identifier: BUSL-1.1
const fs = require('fs');
const os = require('os');
const path = require('path');
const {run} = require('../scripts/consoles-at-volume/launch');
const {scaleShape, planBatches} = require('../scripts/consoles-at-volume/shapes');
const {createManifest, recordStage, mintVolumeId, KINDS} = require('../scripts/consoles-at-volume/manifest');
const {exemplarTree} = require('./fixtures/exemplar-tree');

// An org door whose launch scripts answer with one minted id per launch the script asked for, whose exemplar reads
// answer with the fixture tree, and whose Bulk imports accept every row.
function fakeSalesforce()
{
	let launches = 0;
	const exemplar = exemplarTree();
	return {
		query: jest.fn((soql) =>
		{
			if(soql.startsWith('SELECT COUNT()'))
			{
				return {records: [], totalSize: 0};
			}
			// The read-back of a batch before a rerun's first send: nothing landed on a fresh token.
			if(soql.includes('LaunchCorrelationId__c = \''))
			{
				return {records: [], totalSize: 0};
			}
			return {records: soql.includes('LogEntry__c') ? exemplar.entries : exemplar.rows, totalSize: 0};
		}),
		importCsv: jest.fn(() => ({jobId: 'j', processed: 1, succeeded: 1, failed: 0, completed: true})),
		runApex: jest.fn((apex) =>
		{
			launches++;
			const rootBatch = apex.match(/root < (\d+) \+ (\d+); root\+\+/);
			const stage = rootBatch ? 'reconciliation' : 'small';
			const action = apex.match(/setCorrelationId\('([^']+)'\)/)[1];
			const plan = rootBatch ? null : JSON.parse(apex.match(/JSON\.deserializeUntyped\('([^']+)'\)/)[1]);
			const count = rootBatch ? Number(rootBatch[2]) : plan.reduce((sum, launch) => sum + launch.count, 0);
			const ids = Array.from({length: count}, (unused, index) => `run${launches}x${index}`);
			const line = `VOLUME_LAUNCH stage=${stage} action=${action} ordinal=${launches} ids=${ids.join(',')} launched=${ids.length} dml=1/150 enqueued=1/50`;
			return {logs: '', debugLines: [line]};
		})
	};
}

function context(mode)
{
	const shape = scaleShape(mode, 1);
	const created = createManifest({mode, size: 1, runToken: 'abcdefab', org: {alias: 'Dev', namespacePrefix: ''}, startedAt: '2026-09-24T12:00:00.000Z', shape});
	const manifest = recordStage(created, 'preflight', {ok: true});
	const outputDirectory = fs.mkdtempSync(path.join(os.tmpdir(), 'launch-'));
	return {
		options: {mode, size: 1, manifestPath: '/dev/null/manifest.json', outputDirectory}, salesforce: fakeSalesforce(), shape, manifest, log: () => {}, sleep: async() => {},
		drain: jest.fn(async() => ({drained: true, timedOut: false, samples: []}))
	};
}

// A launch whose CLI call failed in transit, as the org door reports it.
function transportFailure(label)
{
	return Object.assign(new Error(`${label}: Unexpected error while executing anonymous apex. fetch failed`), {transient: true});
}

// Makes the org door's launch of one label fail the given number of times before the fake answers as usual.
function failLaunches(stageContext, label, times, failure = transportFailure)
{
	const real = stageContext.salesforce.runApex;
	let failed = 0;
	stageContext.salesforce.runApex = jest.fn((apex, calledLabel) =>
	{
		if(calledLabel === label && failed < times)
		{
			failed++;
			throw failure(label);
		}
		return real(apex, calledLabel);
	});
}

// Answers the read-back of one action's batch (the rows under the action whose launch correlation is the action) with the
// given ids, and every other action's read-back with nothing; an empty answer needs no action.
function answerLanded(stageContext, ids, actionId)
{
	const real = stageContext.salesforce.query;
	stageContext.salesforce.query = jest.fn((soql) =>
	{
		if(!soql.includes('LaunchCorrelationId__c = \''))
		{
			return real(soql);
		}
		const landed = actionId && soql.includes(actionId) ? ids : [];
		return {records: landed.map((id) => ({Id: id})), totalSize: landed.length};
	});
}

function smallActionIdOf(stageContext, ordinal)
{
	return mintVolumeId(KINDS.action, stageContext.manifest.runToken, ordinal + 1, 0, 0);
}

function launchesOf(stageContext, ordinal)
{
	return stageContext.shape.expected.smallActions.find((action) => action.ordinal === ordinal).launches.reduce((sum, launch) => sum + launch.count, 0);
}

function smallAction(manifest, ordinal)
{
	return manifest.actions.find((action) => action.ordinal === ordinal && action.kind !== 'reconciliation' && !action.synthesized);
}

function launchLabels(stageContext)
{
	return stageContext.salesforce.runApex.mock.calls.map(([, label]) => label);
}

describe('launch', () =>
{
	it('launches the engine share of a staged run: one root, twelve actions, drained between batches, then fills the rest with clones', async() =>
	{
		const stageContext = context('staged');
		const manifest = await run(stageContext);
		expect(manifest.stages.launch.ok).toBe(true);
		const reconciliation = manifest.actions.find((action) => action.kind === 'reconciliation');
		expect(reconciliation).toMatchObject({id: 'abcdefab-aaaa-aaaa-aaaa-aaaaaaaaaaaa', engineRoots: 1, roots: 13, synthesizedRoots: 12, expected: {runs: 2028}});
		expect(manifest.actions.every((action) => /^abcdefab-aaaa-/.test(action.id))).toBe(true);
		expect(manifest.roots).toHaveLength(1);
		const engineActions = manifest.actions.filter((action) => action.kind !== 'reconciliation' && !action.synthesized);
		expect(engineActions).toHaveLength(12);
		expect(manifest.actions.filter((action) => action.synthesized)).toHaveLength(188);
		expect(manifest.synthesized.chainRows).toBe(12 * 7);
		expect(stageContext.salesforce.importCsv).toHaveBeenCalled();
		expect(stageContext.drain).toHaveBeenCalled();
	});

	it('waits for every run under the token to end before it reads the exemplars for the clones, and records that wait as the drain rate', async() =>
	{
		const stageContext = context('staged');
		const runningAnswers = [4, 0];
		const {query} = stageContext.salesforce;
		let completed = 0;
		stageContext.salesforce.query = jest.fn((soql) =>
		{
			// The settle rule's dead-job check: one Running row read back against the count of four keeps the wait, as a live job would.
			if(soql.startsWith('SELECT CurrentJobId__c FROM AsyncChainExecution__c'))
			{
				return {records: [{CurrentJobId__c: '707a'}], totalSize: 1};
			}
			if(soql.startsWith('SELECT COUNT() FROM AsyncApexJob WHERE Id IN'))
			{
				return {records: [], totalSize: 1};
			}
			if(soql.includes('Status__c = \'Running\''))
			{
				return {records: [], totalSize: runningAnswers.shift() ?? 0};
			}
			if(soql.startsWith('SELECT COUNT() FROM AsyncApexJob'))
			{
				completed += 120;
				return {records: [], totalSize: completed};
			}
			if(soql.startsWith('SELECT Status, COUNT(Id)'))
			{
				return {records: [{Status: 'Queued', jobCount: runningAnswers.length > 0 ? 1 : 0}], totalSize: 1};
			}
			return query(soql);
		});
		stageContext.drain = undefined;
		let clock = 0;
		stageContext.sleep = async(milliseconds) => { clock += milliseconds; };
		stageContext.now = () => clock;
		const manifest = await run(stageContext);
		expect(manifest.drainRate).toMatchObject({measuredBy: 'launch', samples: 2});
		expect(manifest.drainRate.jobsPerMinute).toBeGreaterThan(0);
		const runningQueries = stageContext.salesforce.query.mock.calls.filter(([soql]) => soql.includes('Status__c = \'Running\''));
		expect(runningQueries.length).toBeGreaterThanOrEqual(2);
		const firstExemplarRead = stageContext.salesforce.query.mock.calls.findIndex(([soql]) => soql.includes('FROM AsyncChainExecution__c WHERE RootCorrelationId__c IN'));
		const lastRunningQuery = stageContext.salesforce.query.mock.calls.map(([soql]) => soql.includes('Status__c = \'Running\'')).lastIndexOf(true);
		expect(lastRunningQuery).toBeLessThan(firstExemplarRead);
	});

	it('launches every root in one transaction in full mode when the shape says thirteen per batch', async() =>
	{
		const stageContext = context('full');
		const manifest = await run(stageContext);
		expect(manifest.roots).toHaveLength(13);
		expect(stageContext.salesforce.runApex.mock.calls[0][0]).toContain('root < 0 + 13');
		expect(manifest.pressure).toEqual({peakActive: 0, peakHolding: 0, samplesAboveFifty: 0});
		expect(manifest.actions.filter((action) => action.kind !== 'reconciliation')).toHaveLength(200);
		expect(manifest.batches.length).toBeGreaterThan(20);
	});

	it('does not clone after a settle that timed out, and says so on the stage', async() =>
	{
		const stageContext = context('staged');
		stageContext.drain = jest.fn(async() => ({drained: false, timedOut: true, samples: [{at: 0, active: 3, holding: 0, completed: 1}]}));
		const manifest = await run(stageContext);
		expect(manifest.stages.launch).toMatchObject({ok: false});
		expect(manifest.stages.launch.reason).toMatch(/still Running/);
		expect(stageContext.salesforce.importCsv).not.toHaveBeenCalled();
	});

	it('does nothing on a reused load', async() =>
	{
		const stageContext = context('staged');
		stageContext.manifest.stages.preflight.reused = true;
		const manifest = await run(stageContext);
		expect(manifest.stages.launch).toMatchObject({ok: true, reused: true});
		expect(stageContext.salesforce.runApex).not.toHaveBeenCalled();
	});

	it('reads a batch back from the org when its launch call failed in transit after the script ran', async() =>
	{
		const stageContext = context('staged');
		stageContext.log = jest.fn();
		stageContext.sleep = jest.fn(async() =>
		{
		});
		failLaunches(stageContext, 'small-3', 1);
		const landed = Array.from({length: launchesOf(stageContext, 3)}, (unused, index) => `landed${index}`);
		answerLanded(stageContext, landed, smallActionIdOf(stageContext, 3));
		const manifest = await run(stageContext);
		expect(manifest.stages.launch.ok).toBe(true);
		expect(smallAction(manifest, 3).executionIds).toEqual(landed);
		expect(launchLabels(stageContext).filter((label) => label === 'small-3')).toHaveLength(1);
		// One wait before the read-back, for a transaction the org may still be committing; no relaunch.
		expect(stageContext.sleep).toHaveBeenCalledTimes(1);
		expect(stageContext.log.mock.calls.some(([line]) => /WARNING small-3: the call failed in transit .*read back from the org/.test(line))).toBe(true);
	});

	it('launches a batch again when its call failed in transit and the org holds nothing for it', async() =>
	{
		const stageContext = context('staged');
		stageContext.sleep = jest.fn(async() =>
		{
		});
		failLaunches(stageContext, 'small-3', 1);
		answerLanded(stageContext, []);
		const manifest = await run(stageContext);
		expect(manifest.stages.launch.ok).toBe(true);
		expect(launchLabels(stageContext).filter((label) => label === 'small-3')).toHaveLength(2);
		expect(stageContext.sleep.mock.calls.filter(([milliseconds]) => milliseconds === 15_000)).toHaveLength(1);
		expect(smallAction(manifest, 3).executionIds).toHaveLength(launchesOf(stageContext, 3));
	});

	it('stops when a launch call keeps failing in transit and nothing lands', async() =>
	{
		const stageContext = context('staged');
		stageContext.sleep = jest.fn(async() =>
		{
		});
		failLaunches(stageContext, 'small-3', Number.POSITIVE_INFINITY);
		answerLanded(stageContext, []);
		await expect(run(stageContext)).rejects.toThrow(/small-3: .*fetch failed/);
		expect(launchLabels(stageContext).filter((label) => label === 'small-3')).toHaveLength(3);
	});

	it('stops loudly when the org holds part of a batch whose call failed in transit', async() =>
	{
		const stageContext = context('staged');
		stageContext.sleep = jest.fn(async() =>
		{
		});
		failLaunches(stageContext, 'small-3', 1);
		answerLanded(stageContext, ['landed0', 'landed1'], smallActionIdOf(stageContext, 3));
		await expect(run(stageContext)).rejects.toThrow(new RegExp(`small-3: .*holds 2 of its ${launchesOf(stageContext, 3)} runs`));
		expect(launchLabels(stageContext).filter((label) => label === 'small-3')).toHaveLength(1);
	});

	it('stops on a launch failure that is not a transport failure without asking the org', async() =>
	{
		const stageContext = context('staged');
		failLaunches(stageContext, 'small-3', 1, (label) => new Error(`${label}: System.LimitException: Too many DML statements: 151`));
		answerLanded(stageContext, []);
		await expect(run(stageContext)).rejects.toThrow(/Too many DML statements/);
		const batchActionId = smallActionIdOf(stageContext, 3);
		const readBacksOfTheBatch = stageContext.salesforce.query.mock.calls.filter(([soql]) => soql.includes('LaunchCorrelationId__c') && soql.includes(batchActionId));
		expect(readBacksOfTheBatch).toHaveLength(0);
		expect(launchLabels(stageContext).filter((label) => label === 'small-3')).toHaveLength(1);
	});

	it('writes the manifest after every batch, and a rerun continues past the batches already recorded', async() =>
	{
		const stageContext = context('staged');
		stageContext.persist = jest.fn();
		failLaunches(stageContext, 'small-5', 1, (label) => new Error(`${label}: the org is closed`));
		await expect(run(stageContext)).rejects.toThrow(/the org is closed/);
		// The root batch, the reconciliation's action record, then small-0 to small-4.
		expect(stageContext.persist).toHaveBeenCalledTimes(7);
		expect(stageContext.manifest.actions.filter((action) => action.kind !== 'reconciliation')).toHaveLength(5);
		expect(stageContext.manifest.launchedAt).toBeUndefined();

		// The rerun asks the org about the batch that failed before it launches it; nothing landed here.
		answerLanded(stageContext, []);
		stageContext.salesforce.runApex.mockClear();
		stageContext.drain.mockClear();
		const manifest = await run(stageContext);
		expect(manifest.stages.launch.ok).toBe(true);
		expect(launchLabels(stageContext)).toEqual([
			'small-5',
			'small-6',
			'small-7',
			'small-8',
			'small-9',
			'small-10',
			'small-11'
		]);
		expect(manifest.actions.filter((action) => action.kind !== 'reconciliation' && !action.synthesized)).toHaveLength(12);
		expect(new Set(manifest.actions.map((action) => action.id)).size).toBe(manifest.actions.length);
		expect(manifest.roots).toHaveLength(1);
		// A batch of small actions skipped whole on the rerun drains nothing, so no recorded peak is overwritten: one
		// drain per batch with a launch in it, plus the staged settle wait before the clones.
		const engineActions = stageContext.shape.expected.smallActions.slice(0, stageContext.shape.smallActions.engineCount);
		const batchesLaunched = planBatches(engineActions, stageContext.shape.smallActions.perBatch).filter((batch) => batch.some((action) => action.ordinal >= 5));
		expect(stageContext.drain).toHaveBeenCalledTimes(batchesLaunched.length + 1);
	});

	it('reads the next batch back before launching it on a rerun, and takes it when it had landed', async() =>
	{
		const stageContext = context('staged');
		failLaunches(stageContext, 'small-5', 1, (label) => new Error(`${label}: the org is closed`));
		await expect(run(stageContext)).rejects.toThrow(/the org is closed/);
		const landed = Array.from({length: launchesOf(stageContext, 5)}, (unused, index) => `landed${index}`);
		answerLanded(stageContext, landed, smallActionIdOf(stageContext, 5));
		stageContext.salesforce.runApex.mockClear();
		const manifest = await run(stageContext);
		expect(manifest.stages.launch.ok).toBe(true);
		expect(smallAction(manifest, 5).executionIds).toEqual(landed);
		expect(launchLabels(stageContext)).toEqual([
			'small-6',
			'small-7',
			'small-8',
			'small-9',
			'small-10',
			'small-11'
		]);
	});

	it('reads the first batch back on a rerun whose earlier run stopped before recording anything', async() =>
	{
		const stageContext = context('staged');
		failLaunches(stageContext, 'reconciliation-0', 1, (label) => new Error(`${label}: the org is closed`));
		await expect(run(stageContext)).rejects.toThrow(/the org is closed/);
		expect(stageContext.manifest.roots).toHaveLength(0);
		// The earlier run's script had landed its one root; a blind relaunch would collide on the minted ids.
		const reconciliationActionId = mintVolumeId(KINDS.action, stageContext.manifest.runToken, 0, 0, 0);
		answerLanded(stageContext, ['landedRoot'], reconciliationActionId);
		stageContext.salesforce.runApex.mockClear();
		const manifest = await run(stageContext);
		expect(manifest.stages.launch.ok).toBe(true);
		expect(manifest.roots).toEqual([{actionId: reconciliationActionId, ordinal: 0, executionId: 'landedRoot'}]);
		expect(launchLabels(stageContext)).not.toContain('reconciliation-0');
		expect(launchLabels(stageContext)).toHaveLength(12);
	});

	it('waits with its own clock when the context brings no sleep', async() =>
	{
		jest.useFakeTimers();
		try
		{
			const stageContext = context('staged');
			delete stageContext.sleep;
			failLaunches(stageContext, 'small-3', 1);
			answerLanded(stageContext, []);
			const running = run(stageContext);
			await jest.advanceTimersByTimeAsync(15_000);
			const manifest = await running;
			expect(manifest.stages.launch.ok).toBe(true);
			expect(launchLabels(stageContext).filter((label) => label === 'small-3')).toHaveLength(2);
		}
		finally
		{
			jest.useRealTimers();
		}
	});

	it('retries the read-back when its own query fails in transit', async() =>
	{
		const stageContext = context('staged');
		stageContext.sleep = jest.fn(async() =>
		{
		});
		failLaunches(stageContext, 'small-3', 1);
		const landed = Array.from({length: launchesOf(stageContext, 3)}, (unused, index) => `landed${index}`);
		answerLanded(stageContext, landed, smallActionIdOf(stageContext, 3));
		const answering = stageContext.salesforce.query;
		let readBacks = 0;
		stageContext.salesforce.query = jest.fn((soql) =>
		{
			if(soql.includes('LaunchCorrelationId__c = \'') && readBacks++ === 0)
			{
				throw new Error('The query failed: fetch failed');
			}
			return answering(soql);
		});
		const manifest = await run(stageContext);
		expect(manifest.stages.launch.ok).toBe(true);
		expect(smallAction(manifest, 3).executionIds).toEqual(landed);
		expect(launchLabels(stageContext).filter((label) => label === 'small-3')).toHaveLength(1);
	});

	it('stops loudly when the org holds more runs under the action than the batch launches', async() =>
	{
		const stageContext = context('staged');
		stageContext.sleep = jest.fn(async() =>
		{
		});
		failLaunches(stageContext, 'small-3', 1);
		answerLanded(stageContext, Array.from({length: launchesOf(stageContext, 3) + 2}, (unused, index) => `landed${index}`), smallActionIdOf(stageContext, 3));
		await expect(run(stageContext)).rejects.toThrow(new RegExp(`small-3: .*holds ${launchesOf(stageContext, 3) + 2} runs .*${launchesOf(stageContext, 3)} were launched`));
	});
});
