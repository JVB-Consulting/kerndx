// SPDX-License-Identifier: Apache-2.0
const {
	readQueueDepth, isDrained, jobsPerMinute, peakDepth, drainQueue, runningRunsQuery, run, DRAIN_THRESHOLDS, POLL_RETRY_ATTEMPTS
} = require('../scripts/consoles-at-volume/drain');

describe('readQueueDepth', () =>
{
	it('counts Holding apart from the live statuses', () =>
	{
		expect(readQueueDepth([{Status: 'Queued', jobCount: 4}, {Status: 'Processing', jobCount: 2}, {Status: 'Holding', jobCount: 30}])).toEqual({active: 6, holding: 30});
	});

	it('reads an empty answer as an empty queue', () =>
	{
		expect(readQueueDepth([])).toEqual({active: 0, holding: 0});
		expect(isDrained({active: 0, holding: 0})).toBe(true);
	});
});

describe('jobsPerMinute and peakDepth', () =>
{
	const samples = [{at: 0, active: 40, holding: 10, completed: 100}, {at: 120_000, active: 90, holding: 70, completed: 340}];

	it('is the completed delta over the elapsed minutes', () =>
	{
		expect(jobsPerMinute(samples)).toBe(120);
		expect(jobsPerMinute(samples.slice(0, 1))).toBeNull();
	});

	it('measures the busy window only: idle samples after the last live job (a deferred chain waiting its ten minutes) do not dilute it', () =>
	{
		const withIdleTail = [
			{at: 0, active: 40, holding: 0, completed: 0}, {at: 60_000, active: 10, holding: 0, completed: 200}, {at: 120_000, active: 3, holding: 0, completed: 240},
			{at: 600_000, active: 0, holding: 0, completed: 242}, {at: 660_000, active: 0, holding: 0, completed: 242}
		];
		expect(jobsPerMinute(withIdleTail)).toBe(120);
		expect(jobsPerMinute([{at: 0, active: 0, holding: 0, completed: 5}, {at: 60_000, active: 0, holding: 0, completed: 5}])).toBeNull();
	});

	it('keeps the highest of each count', () =>
	{
		expect(peakDepth(samples)).toEqual({active: 90, holding: 70});
	});
});

// An org door whose queue answers the given depths in turn (the last one repeating) and whose completed count grows by ten a sample.
function fakeSalesforce(depths)
{
	let turn = 0;
	return {
		query: jest.fn((soql) =>
		{
			if(soql.startsWith('SELECT COUNT()'))
			{
				return {records: [], totalSize: 10 * turn};
			}
			const depth = depths[Math.min(turn, depths.length - 1)];
			turn++;
			return {records: [{Status: 'Queued', jobCount: depth.active}, {Status: 'Holding', jobCount: depth.holding}], totalSize: 2};
		})
	};
}

describe('drainQueue', () =>
{
	it('returns drained on the first quiet sample', async() =>
	{
		let clock = 0;
		const sleep = jest.fn(async(milliseconds) => { clock += milliseconds; });
		const salesforce = fakeSalesforce([{active: 50, holding: 0}, {active: 3, holding: 0}]);
		const result = await drainQueue({salesforce, sinceIso: '2026-09-24T12:00:00.000Z', sleep, now: () => clock});
		expect(result).toMatchObject({drained: true, timedOut: false});
		expect(result.samples).toHaveLength(2);
		expect(sleep).toHaveBeenCalledWith(DRAIN_THRESHOLDS.pollSeconds * 1000);
	});

	it('keeps polling a quiet queue until the caller says the run has settled', async() =>
	{
		let clock = 0;
		const sleep = async(milliseconds) => { clock += milliseconds; };
		let asked = 0;
		const until = jest.fn(() =>
		{
			asked += 1;
			return asked >= 3;
		});
		const result = await drainQueue({salesforce: fakeSalesforce([{active: 0, holding: 0}]), sinceIso: '2026-09-24T12:00:00.000Z', sleep, now: () => clock, until});
		expect(result).toMatchObject({drained: true, timedOut: false});
		expect(result.samples).toHaveLength(3);
		expect(until).toHaveBeenCalledTimes(3);
	});

	it('the drain stage holds a quiet queue until no run under the token is still Running, then records the rate', async() =>
	{
		let clock = 0;
		let runningAnswers = [3, 1, 0];
		const salesforce = {
			query: jest.fn((soql) =>
			{
				if(soql.startsWith('SELECT COUNT() FROM AsyncChainExecution__c'))
				{
					return {records: [], totalSize: runningAnswers.shift() ?? 0};
				}
				if(soql.startsWith('SELECT COUNT()'))
				{
					return {records: [], totalSize: Math.floor(clock / 1000)};
				}
				// One live job while runs are still Running, so the samples carry a busy window to rate.
				return {records: [{Status: 'Queued', jobCount: runningAnswers.length > 0 ? 1 : 0}], totalSize: 1};
			})
		};
		const manifest = {mode: 'staged', runToken: 'abcdefab', org: {namespacePrefix: ''}, startedAt: '2026-09-24T12:00:00.000Z', stages: {preflight: {ok: true}}};
		const sleep = async(milliseconds) => { clock += milliseconds; };
		const result = await run({manifest, salesforce, log: () => {}, sleep, now: () => clock});
		expect(runningRunsQuery(manifest)).toBe('SELECT COUNT() FROM AsyncChainExecution__c WHERE RootCorrelationId__c LIKE \'abcdefab-aaaa-%\' AND Status__c = \'Running\'');
		expect(result.stages.drain).toMatchObject({ok: true, drained: true, timedOut: false});
		expect(result.drainRate.samples).toBe(3);
		expect(result.drainRate.jobsPerMinute).toBeGreaterThan(0);
	});

	it('the drain stage keeps a rate measured earlier when its own wait sees a single sample', async() =>
	{
		const salesforce = {query: jest.fn(() => ({records: [], totalSize: 0}))};
		const earlier = {jobsPerMinute: 233.3, peak: {active: 39, holding: 0}, samples: 12, timedOut: false, measuredBy: 'launch'};
		const manifest = {
			mode: 'staged', runToken: 'abcdefab', org: {namespacePrefix: ''}, startedAt: '2026-09-24T12:00:00.000Z', stages: {preflight: {ok: true}}, drainRate: earlier
		};
		const result = await run({manifest, salesforce, log: () => {}, sleep: async() => {}, now: () => 0});
		expect(result.stages.drain).toMatchObject({ok: true, drained: true});
		expect(result.drainRate).toEqual(earlier);
	});

	it('a timed-out drain stage records a warning, prints one, and records no rate for the truncated window', async() =>
	{
		let clock = 0;
		const salesforce = {
			query: jest.fn((soql) =>
			{
				if(soql.startsWith('SELECT COUNT() FROM AsyncChainExecution__c'))
				{
					return {records: [], totalSize: 4};
				}
				// The four Running runs sit on live jobs the whole time, so the dead-job check never settles them.
				if(soql.startsWith('SELECT CurrentJobId__c FROM AsyncChainExecution__c'))
				{
					return {records: Array.from({length: 4}, () => ({CurrentJobId__c: '707a'})), totalSize: 4};
				}
				if(soql.startsWith('SELECT COUNT() FROM AsyncApexJob WHERE Id IN'))
				{
					return {records: [], totalSize: 4};
				}
				return {records: [], totalSize: soql.startsWith('SELECT COUNT()') ? Math.floor(clock / 1000) : 0};
			})
		};
		const manifest = {mode: 'staged', runToken: 'abcdefab', org: {namespacePrefix: ''}, startedAt: '2026-09-24T12:00:00.000Z', stages: {preflight: {ok: true}}};
		const log = jest.fn();
		const sleep = async(milliseconds) => { clock += milliseconds; };
		const result = await run({manifest, salesforce, log, sleep, now: () => clock});
		expect(result.stages.drain).toMatchObject({ok: true, drained: false, timedOut: true});
		expect(result.stages.drain.warning).toMatch(/did not settle/);
		expect(result.drainRate).toMatchObject({jobsPerMinute: null, timedOut: true});
		expect(log.mock.calls.some(([line]) => line.startsWith('drain: WARNING'))).toBe(true);
	});

	it('a timed-out drain says so and keeps its samples', async() =>
	{
		let clock = 0;
		const sleep = async(milliseconds) => { clock += milliseconds; };
		const thresholds = {...DRAIN_THRESHOLDS, timeoutSeconds: 30};
		const result = await drainQueue({salesforce: fakeSalesforce([{active: 50, holding: 0}]), sinceIso: '2026-09-24T12:00:00.000Z', thresholds, sleep, now: () => clock});
		expect(result).toMatchObject({drained: false, timedOut: true});
		expect(result.samples.length).toBeGreaterThanOrEqual(3);
	});
});

describe('the settle rule against a dead job, and the poll retry', () =>
{
	const manifest = {mode: 'full', runToken: 'abcdefab', org: {namespacePrefix: ''}, startedAt: '2026-09-24T12:00:00.000Z', stages: {preflight: {ok: true}}};

	// An org door with one run still Running on the job given, that job live as often as the answers say, and a queue as
	// deep as the depths say (empty once they run out).
	function fakeOrgWithOneRunningRun(jobStatusAnswers, clockRef, queueDepths = [])
	{
		return {
			query: jest.fn((soql) =>
			{
				if(soql.startsWith('SELECT Status, COUNT(Id)'))
				{
					const depth = queueDepths.shift() ?? {active: 0, holding: 0};
					return {records: [{Status: 'Queued', jobCount: depth.active}, {Status: 'Holding', jobCount: depth.holding}], totalSize: 2};
				}
				if(soql.startsWith('SELECT COUNT() FROM AsyncChainExecution__c'))
				{
					return {records: [], totalSize: 1};
				}
				if(soql.startsWith('SELECT CurrentJobId__c FROM AsyncChainExecution__c'))
				{
					return {records: [{CurrentJobId__c: '707x'}], totalSize: 1};
				}
				if(soql.startsWith('SELECT COUNT() FROM AsyncApexJob WHERE Id IN'))
				{
					return {records: [], totalSize: jobStatusAnswers.shift() ?? 0};
				}
				if(soql.startsWith('SELECT COUNT()'))
				{
					return {records: [], totalSize: Math.floor(clockRef.clock / 1000)};
				}
				return {records: [], totalSize: 0};
			})
		};
	}

	it('the drain stage settles when every run still Running sits on a dead job, and says so', async() =>
	{
		const clockRef = {clock: 0};
		const log = jest.fn();
		const salesforce = fakeOrgWithOneRunningRun([0], clockRef);
		const result = await run({manifest, salesforce, log, sleep: async(milliseconds) => { clockRef.clock += milliseconds; }, now: () => clockRef.clock});
		expect(result.stages.drain).toMatchObject({ok: true, drained: true, timedOut: false});
		expect(log.mock.calls.some(([line]) => /drain: 1 run\(s\) still Running on a dead job/.test(line))).toBe(true);
		expect(salesforce.query.mock.calls.some(([soql]) => soql.includes('FROM AsyncApexJob WHERE Id IN (\'707x\')') && soql.includes('Status IN'))).toBe(true);
	});

	it('the drain stage keeps waiting while a Running run still has a live job', async() =>
	{
		const clockRef = {clock: 0};
		const salesforce = fakeOrgWithOneRunningRun([1, 1, 0], clockRef);
		const result = await run({manifest, salesforce, log: () => {}, sleep: async(milliseconds) => { clockRef.clock += milliseconds; }, now: () => clockRef.clock});
		expect(result.stages.drain).toMatchObject({ok: true, drained: true});
		expect(result.drainRate.samples).toBe(3);
	});

	it('a run whose stamped job has ended keeps the wait while any job is still queued: the stamp trails the live executor by one step', async() =>
	{
		const clockRef = {clock: 0};
		const log = jest.fn();
		const salesforce = fakeOrgWithOneRunningRun([0, 0], clockRef, [{active: 1, holding: 0}, {active: 0, holding: 0}]);
		const result = await run({manifest, salesforce, log, sleep: async(milliseconds) => { clockRef.clock += milliseconds; }, now: () => clockRef.clock});
		expect(result.stages.drain).toMatchObject({ok: true, drained: true});
		expect(result.drainRate.samples).toBe(2);
		expect(salesforce.query.mock.calls.filter(([soql]) => soql.startsWith('SELECT COUNT() FROM AsyncApexJob WHERE Id IN'))).toHaveLength(1);
		expect(log.mock.calls.filter(([line]) => /still Running on a dead job/.test(line))).toHaveLength(1);
	});

	it('a poll query that fails once is retried after a wait, and the sample goes on', async() =>
	{
		let clock = 0;
		let calls = 0;
		const log = jest.fn();
		const salesforce = {
			query: jest.fn(() =>
			{
				calls += 1;
				if(calls === 1)
				{
					throw new Error('The query failed: fetch failed');
				}
				return {records: [], totalSize: 0};
			})
		};
		const sleep = jest.fn(async(milliseconds) => { clock += milliseconds; });
		const result = await drainQueue({salesforce, sinceIso: '2026-09-24T12:00:00.000Z', sleep, now: () => clock, log});
		expect(result).toMatchObject({drained: true, timedOut: false});
		expect(result.samples).toHaveLength(1);
		expect(log.mock.calls.some(([line]) => /drain: WARNING.*fetch failed.*retry/.test(line))).toBe(true);
		expect(sleep).toHaveBeenCalledTimes(1);
	});

	it('a poll query that keeps failing ends the drain with its failure after the last attempt', async() =>
	{
		let clock = 0;
		const salesforce = {query: jest.fn(() => { throw new Error('The query failed: fetch failed'); })};
		await expect(drainQueue({salesforce, sinceIso: '2026-09-24T12:00:00.000Z', sleep: async(milliseconds) => { clock += milliseconds; }, now: () => clock, log: () => {}}))
		.rejects.toThrow('fetch failed');
		expect(salesforce.query).toHaveBeenCalledTimes(POLL_RETRY_ATTEMPTS);
	});
});
