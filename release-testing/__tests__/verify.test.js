// SPDX-License-Identifier: Apache-2.0
const fs = require('fs');
const path = require('path');
const {buildClaims, evaluateClaim, evidenceClasses, readAggregates, run} = require('../scripts/consoles-at-volume/verify');

function manifest()
{
	return {
		mode: 'staged', runToken: 'abcdefab', org: {namespacePrefix: ''}, startedAt: '2026-09-24T12:00:00.000Z',
		actions: [
			{
				id: 'act', kind: 'reconciliation', roots: 13, engineRoots: 1, expected: {runs: 2028, leaves: 1625, byStatus: {Completed: 1820, Failed: 208}},
				chainNames: ['Volume_Reconciliation', 'Volume_RegionReconcile', 'Volume_LedgerReconcile', 'Volume_AccountReconcile']
			},
			{id: 'small1', kind: 'orders', synthesized: false, expected: {runs: 5, byStatus: {Completed: 3, Failed: 2}}},
			{id: 'stalled', kind: 'stalledArchive', synthesized: true, expected: {runs: 2, byStatus: {Stalled: 2}}}
		],
		operatorWave: {
			retries: [{executionId: 'r1'}], restarts: [{executionId: 's1'}], aborts: [{executionId: 'a1'}], killSwitch: {actionId: 'ks', launched: 5},
			deadJobStalls: [{executionId: 'd1', jobId: 'j1', runKey: 'k1', idempotent: true}, {executionId: 'd2', jobId: 'j2', runKey: 'k2', idempotent: false}],
			stallProbes: []
		},
		synthesized: {stalledRows: ['x', 'y']}, drainRate: {jobsPerMinute: 42}
	};
}

describe('buildClaims', () =>
{
	it('names one claim per count the manifest promises', () =>
	{
		const names = buildClaims(manifest(), '').map((claim) => claim.name);
		expect(names).toEqual(expect.arrayContaining([
			'action act holds 2028 runs', 'action act holds 1820 Completed', 'action act holds 208 Failed', 'action act has 1625 leaves',
			'action act has no run left Running or Stalled', 'action small1 holds 5 runs', 'retried run r1 is Completed with its retry stamped',
			'restarted run s1 has a clone', 'aborted run a1 is Aborted by the operator', 'kill switch action ks holds 5 Aborted under KillSwitch',
			'dead-job run d1 was re-driven', 'dead-job run d1\'s killed job j1 is dead', 'dead-job run d2\'s killed job j2 is dead', 'watchdog re-drives number 1',
			'no re-drive outside the dead-job slice', 'dead-job runs number 1 on a step not safe to repeat ended Failed at the started step',
			'dead-job runs on a step not safe to repeat have one ERROR entry each (1)',
			'synthesized Stalled rows number 2', 'engine action small1 has a launch entry', 'drain rate is known'
		]));
	});

	it('counts the engine re-drive entries by the record they were written for, and any other since the run started as a finding', () =>
	{
		const claims = buildClaims(manifest(), '');
		const counted = claims.find((claim) => claim.name === 'watchdog re-drives number 1');
		expect(counted.soql).toContain('RecordId__c IN (\'d1\')');
		expect(counted.soql).toContain('ShortMessage__c LIKE \'Chain re-driven by watchdog after a stall%\'');
		const outside = claims.find((claim) => claim.name === 'no re-drive outside the dead-job slice');
		expect(outside).toMatchObject({expected: 0, compare: 'equals'});
		expect(outside.note).toMatch(/healthy chain/);
		// The claim reads in two steps, so an entry the watchdog wrote for another load's stale row on the shared org never counts.
		const quiet = {query: jest.fn(() => ({records: [], totalSize: 0}))};
		expect(outside.observe(quiet)).toBe(0);
		expect(quiet.query).toHaveBeenCalledTimes(1);
		expect(quiet.query.mock.calls[0][0]).toContain('CreatedDate >= 2026-09-24T12:00:00.000Z');
		expect(quiet.query.mock.calls[0][0]).toContain('RecordId__c NOT IN (\'d1\')');
		const redrivesElsewhere = {records: [{RecordId__c: 'other'}, {RecordId__c: 'mine'}], totalSize: 2};
		const noisy = {query: jest.fn((soql) => (soql.startsWith('SELECT RecordId__c') ? redrivesElsewhere : {records: [], totalSize: 1}))};
		expect(outside.observe(noisy)).toBe(1);
		expect(noisy.query.mock.calls[1][0]).toContain('Id IN (\'other\', \'mine\') AND RootCorrelationId__c LIKE \'abcdefab-aaaa-%\'');
	});

	it('answers every per-action count from three grouped reads, not one query per claim', async() =>
	{
		const grouped = {
			chains: [
				{root: 'act', status: 'Completed', n: 1820}, {root: 'act', status: 'Failed', n: 208}, {root: 'small1', status: 'Completed', n: 3},
				{root: 'small1', status: 'Failed', n: 2}, {root: 'stalled', status: 'Stalled', category: 'Stalled', n: 2},
				{root: 'ks', status: 'Aborted', category: 'KillSwitch', n: 5}
			],
			leaves: [{root: 'act', n: 1625}], entries: [{root: 'act', n: 14}, {root: 'small1', n: 2}]
		};
		const salesforce = {
			query: jest.fn((soql) =>
			{
				if(soql.includes('GROUP BY RootCorrelationId__c, Status__c'))
				{
					return {records: grouped.chains, totalSize: grouped.chains.length};
				}
				if(soql.includes('Volume_AccountReconcile') && soql.includes('GROUP BY'))
				{
					return {records: grouped.leaves, totalSize: 1};
				}
				if(soql.includes('FROM LogEntry__c') && soql.includes('GROUP BY'))
				{
					return {records: grouped.entries, totalSize: 2};
				}
				return {records: [], totalSize: soql.includes('Id IN (\'x\', \'y\')') ? 2 : 1};
			})
		};
		const aggregates = readAggregates(salesforce, '', manifest());
		expect(aggregates.runs.get('act')).toBe(2028);
		expect(aggregates.byStatus.get('act').get('Failed')).toBe(208);
		expect(aggregates.leaves.get('act')).toBe(1625);
		expect(aggregates.launchEntries.get('small1')).toBe(2);
		expect(aggregates.runs.get('missing')).toBeUndefined();
		const withStall = {...manifest(), synthesized: {stalledRows: ['x', 'y'], chainRows: 0}, stages: {}};
		withStall.operatorWave.deadJobStalls = [];
		salesforce.query.mockClear();
		const result = await run({manifest: withStall, salesforce, log: () => {}, sleep: async() => {}, now: () => 0});
		expect(result.stages.verify.failed).toBe(0);
		// Three grouped reads answer the eleven action claims; only the wave's per-run claims query on their own.
		const groupedReads = salesforce.query.mock.calls.filter(([soql]) => soql.includes('GROUP BY')).length;
		expect(groupedReads).toBe(3);
		expect(salesforce.query.mock.calls.length - groupedReads).toBeLessThanOrEqual(6);
	});

	it('counts as engine evidence only the roots the engine ran, never the cloned ones', () =>
	{
		const evidence = evidenceClasses({...manifest(), synthesized: {stalledRows: [], chainRows: 1872}});
		expect(evidence.engine).toMatch(/^161 runs the engine wrote/);
		expect(evidence.clone).toMatch(/^1872 rows/);
	});

	it('expects a re-drive only for a dead-job run whose step is safe to repeat, and the started-step end for the others', () =>
	{
		const claims = buildClaims(manifest(), '');
		const names = claims.map((claim) => claim.name);
		expect(names).not.toContain('dead-job run d2 was re-driven');
		const ended = claims.find((claim) => claim.name === 'dead-job runs number 1 on a step not safe to repeat ended Failed at the started step');
		const answer = {records: [{Id: 'd2', ErrorMessage__c: 'Recovery stopped at step SubscriberChainSteps.NarratingStep. The step had started.'}], totalSize: 1};
		const salesforce = {query: jest.fn(() => answer)};
		expect(ended.observe(salesforce)).toBe(1);
		expect(salesforce.query.mock.calls[0][0]).toContain('Id IN (\'d2\') AND Status__c = \'Failed\' AND CompletedAt__c != null AND FailureCategory__c = \'Stalled\'');
		const entries = claims.find((claim) => claim.name === 'dead-job runs on a step not safe to repeat have one ERROR entry each (1)');
		expect(entries.soql).toContain('LogLevel__c = \'ERROR\' AND RecordId__c IN (\'d2\') AND ShortMessage__c LIKE \'Recovery stopped at step%\'');
		// A re-drive of a run whose step is not safe to repeat counts as one outside the slice: the slice holds only the safe runs.
		const outside = claims.find((claim) => claim.name === 'no re-drive outside the dead-job slice');
		const quiet = {query: jest.fn(() => ({records: [], totalSize: 0}))};
		outside.observe(quiet);
		expect(quiet.query.mock.calls[0][0]).toContain('RecordId__c NOT IN (\'d1\')');
	});

	it('expects no launch entry under either dead-job action, because the wave launches carry no live correlation', () =>
	{
		const withWave = manifest();
		withWave.actions.push({id: 'safe', kind: 'idempotentDeferredDispatch', expected: {runs: 1, byStatus: {Completed: 1}}});
		withWave.actions.push({id: 'unsafe', kind: 'deferredDispatch', expected: {runs: 1, byStatus: {Failed: 1}}});
		const names = buildClaims(withWave, '').map((claim) => claim.name);
		expect(names).toEqual(expect.arrayContaining(['action safe holds 1 Completed', 'action unsafe holds 1 Failed']));
		expect(names).not.toContain('engine action safe has a launch entry');
		expect(names).not.toContain('engine action unsafe has a launch entry');
	});

	it('names both dead-job outcomes on the operator evidence line', () =>
	{
		expect(evidenceClasses({...manifest(), synthesized: {stalledRows: [], chainRows: 0}}).operator)
			.toMatch(/1 dead-job re-drives by the watchdog, 1 dead-job runs the watchdog ended Failed at the started step$/);
	});

	it('adjusts an action\'s expected counts by the retries and restarts the wave pressed under it', () =>
	{
		const adjusted = manifest();
		adjusted.operatorWave.retries = [{executionId: 'r1', actionId: 'small1'}];
		adjusted.operatorWave.restarts = [{executionId: 's1', actionId: 'small1'}, {executionId: 's2', actionId: 'elsewhere'}];
		const names = buildClaims(adjusted, '').map((claim) => claim.name);
		expect(names).toEqual(expect.arrayContaining(['action small1 holds 6 runs', 'action small1 holds 4 Completed', 'action small1 holds 2 Failed']));
		expect(names).not.toContain('action small1 holds 5 runs');
	});

	it('a run count above the expected total is reported as an unexpected re-drive', () =>
	{
		const claim = buildClaims(manifest(), '').find((candidate) => candidate.name === 'action act holds 2028 runs');
		const result = evaluateClaim(claim, 2031);
		expect(result.pass).toBe(false);
		expect(result.note).toMatch(/re-drive/);
	});

	it('compares as the claim says', () =>
	{
		expect(evaluateClaim({name: 'x', expected: 1, compare: 'atLeast'}, 4).pass).toBe(true);
		expect(evaluateClaim({name: 'x', expected: 1, compare: 'equals'}, 4).pass).toBe(false);
		expect(evaluateClaim({name: 'x', expected: 0, compare: 'atMost'}, 0).pass).toBe(true);
	});

	it('prints one PERF_ROW line per measure, never one row bundling every field', async() =>
	{
		const withPressure = {
			...manifest(), synthesized: {stalledRows: ['x', 'y'], chainRows: 0}, stages: {},
			pressure: {peakActive: 9, peakHolding: 3, samplesAboveFifty: 1}
		};
		withPressure.operatorWave.deadJobStalls = [];
		const salesforce = {query: jest.fn(() => ({records: [], totalSize: 0}))};
		const lines = [];
		await run({manifest: withPressure, salesforce, log: (line) => lines.push(line), sleep: async() => {}, now: () => 0});
		const performanceRows = lines.filter((line) => line.startsWith('PERF_ROW:')).map((line) => JSON.parse(line.slice('PERF_ROW: '.length)));
		expect(performanceRows.map((row) => row.metric)).toEqual(['runs', 'jobsPerMinute', 'peakActive', 'peakHolding', 'samplesAboveFifty', 'backstopRefusals', 'lockRefusals']);
		expect(performanceRows.every((row) => row.section === 83)).toBe(true);
		const byMetric = Object.fromEntries(performanceRows.map((row) => [row.metric, row.value]));
		expect(byMetric).toEqual({runs: 2035, jobsPerMinute: 42, peakActive: 9, peakHolding: 3, samplesAboveFifty: 1, backstopRefusals: 0, lockRefusals: 0});
	});

	it('never emits a PERF_ROW for a measure with no value, so a missing pressure or drain reading cannot drag the baseline to zero', async() =>
	{
		const withoutPressure = {...manifest(), synthesized: {stalledRows: ['x', 'y'], chainRows: 0}, stages: {}, drainRate: undefined};
		withoutPressure.operatorWave.deadJobStalls = [];
		const withEmptyPressure = {...manifest(), synthesized: {stalledRows: ['x', 'y'], chainRows: 0}, stages: {}, drainRate: undefined, pressure: {}};
		withEmptyPressure.operatorWave.deadJobStalls = [];
		/**
		 * @description Runs verify over a manifest and returns the PERF_ROW lines it printed, parsed.
		 *
		 * @param {object} withNoReading The manifest, missing one or more readings.
		 *
		 * @returns {Promise<object[]>} The parsed PERF_ROW payloads.
		 */
		const performanceRowsOf = async(withNoReading) =>
		{
			const salesforce = {query: jest.fn(() => ({records: [], totalSize: 0}))};
			const lines = [];
			await run({manifest: withNoReading, salesforce, log: (line) => lines.push(line), sleep: async() => {}, now: () => 0});
			return lines.filter((line) => line.startsWith('PERF_ROW:')).map((line) => JSON.parse(line.slice('PERF_ROW: '.length)));
		};
		for(const performanceRows of await Promise.all([performanceRowsOf(withoutPressure), performanceRowsOf(withEmptyPressure)]))
		{
			expect(performanceRows.map((row) => row.metric)).toEqual(['runs', 'backstopRefusals', 'lockRefusals']);
			expect(performanceRows.every((row) => typeof row.value === 'number')).toBe(true);
		}
	});
});

describe('the lock refusal count', () =>
{
	const COMMIT_CLASS_METHOD = 'DML_Transaction.commitWork';
	const LOCK_CLAIM = 'lock refusals counted';

	it('reads the namespaced fields and both spellings of the save\'s class name on an org where the package has a namespace', () =>
	{
		const claim = buildClaims(manifest(), 'kern__').find((candidate) => candidate.name === LOCK_CLAIM);
		expect(claim.soql).toContain('FROM kern__LogEntry__c');
		expect(claim.soql).toContain('kern__ClassMethod__c IN (\'DML_Transaction.commitWork\', \'kern.DML_Transaction.commitWork\')');
		expect(claim.soql).toContain('kern__ExceptionType__c = \'System.DmlException\'');
		expect(claim.soql).toContain('kern__ShortMessage__c LIKE \'%UNABLE_TO_LOCK_ROW%\'');
		expect(claim).toMatchObject({expected: 0, compare: 'atLeast'});
	});

	it('reads only the class name with no namespace on an org where the package has none', () =>
	{
		const claim = buildClaims(manifest(), '').find((candidate) => candidate.name === LOCK_CLAIM);
		expect(claim.soql).toContain(`ClassMethod__c IN ('${COMMIT_CLASS_METHOD}') AND ExceptionType__c = 'System.DmlException'`);
		expect(claim.soql).not.toContain('kern');
	});

	it('prints the backstop and lock refusal counts the org answered on one verify line', async() =>
	{
		const withoutWave = {...manifest(), synthesized: {stalledRows: ['x', 'y'], chainRows: 0}, stages: {}};
		withoutWave.operatorWave.deadJobStalls = [];
		const backstopRefusals = 3;
		const lockRefusals = 7;
		const salesforce = {
			query: jest.fn((soql) =>
			{
				if(soql.includes('UNABLE_TO_LOCK_ROW'))
				{
					return {records: [], totalSize: lockRefusals};
				}
				if(soql.includes('LIKE \'Chain run transition refused by the backstop%\''))
				{
					return {records: [], totalSize: backstopRefusals};
				}
				return {records: [], totalSize: 0};
			})
		};
		const lines = [];
		const result = await run({manifest: withoutWave, salesforce, log: (line) => lines.push(line), sleep: async() => {}, now: () => 0});
		expect(lines).toContain(`verify: ${backstopRefusals} backstop refusals, ${lockRefusals} lock refusals`);
		expect(result.stages.verify.counts).toEqual({backstopRefusals, lockRefusals});
	});
});

describe('the synthesized Stalled rows', () =>
{
	const STALLED_TEMPLATE = path.join(__dirname, '..', 'scripts', 'consoles-at-volume', 'templates', 'synthesize-stalled.apex');

	it('expects every row still Stalled after the watchdog, and says on a failure why a row should not have moved', () =>
	{
		const claim = buildClaims(manifest(), '').find((candidate) => candidate.name === 'synthesized Stalled rows number 2');
		expect(claim).toMatchObject({expected: 2, compare: 'equals'});
		expect(claim.soql).toContain('Status__c = \'Stalled\'');
		expect(evaluateClaim(claim, 1).note).toMatch(/no job id/);
		// Only a job id can move such a row: the watchdog skips a row with an end time, and a Stalled row may not have one.
		expect(evaluateClaim(claim, 1).note).toMatch(/a row that moved was given a job id, or was changed by something other than the watchdog/);
		expect(evaluateClaim(claim, 1).note).not.toMatch(/end time/);
		expect(evaluateClaim(claim, 2).note).toBeUndefined();
	});

	it('are written with no job id, the one field that would let the watchdog move them, and with no end time or duration, which a Stalled row may not have', () =>
	{
		const template = fs.readFileSync(STALLED_TEMPLATE, 'utf8');
		expect(template).toContain('Status__c\', \'Stalled\'');
		expect(template).not.toContain('CurrentJobId__c');
		for(const fieldAStalledRowMayNotHave of ['CompletedAt__c', 'DurationMs__c'])
		{
			expect(template).not.toContain(fieldAStalledRowMayNotHave);
		}
	});
});

describe('the started-step Stalled rows', () =>
{
	const STARTED_TEMPLATE = path.join(__dirname, '..', 'scripts', 'consoles-at-volume', 'templates', 'synthesize-stalled-started.apex');
	const REASON = 'Recovery stopped at step Create Foobar. The step had started when the chain stalled and no result was saved, so it may already have done its work.';

	/**
	 * @description The test manifest with two started-step rows laid and the watchdog scheduled.
	 *
	 * @returns {object}
	 */
	function startedManifest()
	{
		const withStarted = {...manifest(), stages: {}, watchdog: {scheduled: true}};
		withStarted.synthesized = {stalledRows: ['x', 'y'], startedStepRows: ['p1', 'p2'], chainRows: 0};
		withStarted.operatorWave.deadJobStalls = [];
		return withStarted;
	}

	it('are written with the dead job id, a started step with no result, and no end time or duration', () =>
	{
		// The header comment names the fields the rows leave out, so only the script's own lines are read.
		const code = fs.readFileSync(STARTED_TEMPLATE, 'utf8').split('\n').filter((line) => !line.trim().startsWith('//')).join('\n');
		expect(code).toContain('Status__c\', \'Stalled\'');
		expect(code).toContain('CurrentJobId__c\', deadJobId');
		expect(code).toContain('\'stepName\' => \'Create Foobar\', \'started\' => true}');
		// A step marked idempotent would be run again; an end time or a duration is refused on a Stalled row.
		for(const fieldTheRowsLeaveOut of ['isIdempotent', 'CompletedAt__c', 'DurationMs__c'])
		{
			expect(code).not.toContain(fieldTheRowsLeaveOut);
		}
	});

	it('claim every row ended Failed with the started-step reason and an end time, one ERROR entry each, no backstop refusal and no watchdog failure logged', () =>
	{
		const claims = buildClaims(startedManifest(), '');
		const names = claims.map((claim) => claim.name);
		expect(names).toEqual(expect.arrayContaining([
			'started-step rows number 2 ended Failed at the started step', 'started-step rows have one ERROR entry each (2)',
			'no backstop refusal on a started-step row', 'no watchdog failure logged since the load started'
		]));
		expect(names).not.toContain('no watchdog job failed since the load started');
		const ended = claims.find((claim) => claim.name === 'started-step rows number 2 ended Failed at the started step');
		const answer = {records: [{Id: 'p1', ErrorMessage__c: REASON}, {Id: 'p2', ErrorMessage__c: 'Watchdog re-drive abandoned'}], totalSize: 2};
		const salesforce = {query: jest.fn(() => answer)};
		expect(ended.observe(salesforce)).toBe(1);
		const asked = salesforce.query.mock.calls[0][0];
		expect(asked).toContain('Id IN (\'p1\', \'p2\') AND Status__c = \'Failed\' AND CompletedAt__c != null AND FailureCategory__c = \'Stalled\'');
		const entries = claims.find((claim) => claim.name === 'started-step rows have one ERROR entry each (2)');
		expect(entries).toMatchObject({expected: 2, compare: 'equals'});
		expect(entries.soql).toContain('LogLevel__c = \'ERROR\' AND RecordId__c IN (\'p1\', \'p2\') AND ShortMessage__c LIKE \'Recovery stopped at step%\'');
		const refusals = claims.find((claim) => claim.name === 'no backstop refusal on a started-step row');
		expect(refusals).toMatchObject({expected: 0, compare: 'equals'});
		expect(refusals.soql).toContain('ShortMessage__c LIKE \'Chain run % refused by the backstop%\' AND RecordId__c IN (\'p1\', \'p2\')');
		// The watchdog logs an ERROR when a re-drive or a stall write fails for one row; the schedule's own job row never shows a failed sweep.
		const failures = claims.find((claim) => claim.name === 'no watchdog failure logged since the load started');
		expect(failures).toMatchObject({expected: 0, compare: 'equals'});
		expect(failures.soql).toBe('SELECT COUNT() FROM LogEntry__c WHERE CreatedDate >= 2026-09-24T12:00:00.000Z AND LogLevel__c = \'ERROR\' '
				+ 'AND (ShortMessage__c LIKE \'Watchdog re-drive failed%\' OR ShortMessage__c LIKE \'Watchdog stall DML failed%\')');
		expect(evaluateClaim(failures, 1).pass).toBe(false);
	});

	it('make no started-step claim when no rows were laid', () =>
	{
		const names = buildClaims(manifest(), '').map((claim) => claim.name);
		expect(names.some((name) => name.startsWith('started-step rows'))).toBe(false);
	});

	it('waits past the twenty minutes the dead-job re-drives get, one sweep interval more for every twenty-five rows', async() =>
	{
		// Sixty rows: twenty minutes and three sweep intervals of five, so rows that end at minute thirty still pass.
		const startedRows = Array.from({length: 60}, (unused, index) => `p${index}`);
		const withSixty = startedManifest();
		withSixty.synthesized.startedStepRows = startedRows;
		const clock = {now: 0};
		const thirtyMinutes = 30 * 60_000;
		const salesforce = {
			query: jest.fn((soql) =>
			{
				const done = clock.now >= thirtyMinutes;
				if(soql.startsWith('SELECT Id, ErrorMessage__c'))
				{
					return {records: done ? startedRows.map((Id) => ({Id, ErrorMessage__c: REASON})) : [], totalSize: done ? startedRows.length : 0};
				}
				if(soql.includes('Recovery stopped at step') && soql.startsWith('SELECT COUNT()'))
				{
					return {records: [], totalSize: done ? startedRows.length : 0};
				}
				return {records: [], totalSize: soql.includes('Id IN (\'x\', \'y\')') ? 2 : 0};
			})
		};
		const result = await run({manifest: withSixty, salesforce, log: () => {}, sleep: async(milliseconds) => { clock.now += milliseconds; }, now: () => clock.now});
		const startedClaims = result.stages.verify.claims.filter((claim) => claim.name.startsWith('started-step rows'));
		expect(startedClaims).toHaveLength(2);
		expect(startedClaims.every((claim) => claim.pass)).toBe(true);
	});

	it('prints the rows one sweep ended and the two refusal counts as PERF_ROW lines, and no wall-time measure', async() =>
	{
		const limits = (queries) => `\nQueries: ${queries} of 100\nDML Statements: ${queries + 10} of 150\nCpu Time: ${queries * 40} of 60000`;
		const entries = [
			{TransactionId__c: 't1', Limits__c: limits(40)}, {TransactionId__c: 't1', Limits__c: limits(97)}, {TransactionId__c: 't1', Limits__c: limits(70)},
			{TransactionId__c: 't2', Limits__c: limits(10)}
		];
		const salesforce = {
			query: jest.fn((soql) =>
			{
				if(soql.startsWith('SELECT TransactionId__c, Limits__c'))
				{
					return {records: entries, totalSize: entries.length};
				}
				return {records: [], totalSize: 0};
			})
		};
		const lines = [];
		const clock = {now: 0};
		await run({manifest: startedManifest(), salesforce, log: (line) => lines.push(line), sleep: async(milliseconds) => { clock.now += milliseconds; }, now: () => clock.now});
		const performanceRows = lines.filter((line) => line.startsWith('PERF_ROW:')).map((line) => JSON.parse(line.slice('PERF_ROW: '.length)));
		const byMetric = Object.fromEntries(performanceRows.map((row) => [row.metric, row.value]));
		expect(byMetric).toMatchObject({watchdogRowsPerSweep: 3, backstopRefusals: 0, lockRefusals: 0});
		expect(byMetric).not.toHaveProperty('sweepWallMs');
		expect(salesforce.query.mock.calls.some(([soql]) => soql.includes('FROM AsyncApexJob WHERE ApexClass.Name'))).toBe(false);
		expect(lines).toContain('verify: the watchdog ended the started-step rows in 2 sweeps, at most 3 in one; that sweep used at most Queries 97 of 100, '
				+ 'DML Statements 107 of 150, Cpu Time 3880 of 60000');
	});
});
