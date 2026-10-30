// SPDX-License-Identifier: Apache-2.0
const {
	candidateQuery, waitForStatuses, waitUntilNoneRunning, pressOnRun, flipKillSwitch, run, launchWave, layDownStartedStepStalls, makeDeadJobStalls
} = require('../scripts/consoles-at-volume/operator-wave');
const {mintVolumeId, KINDS} = require('../scripts/consoles-at-volume/manifest');

describe('launchWave', () =>
{
	it('launches a batch in chunks one transaction can hold, under one action with the kind index strided a chunk, and merges the ids', () =>
	{
		// Three DML statements a launch: fifty in one transaction is one over the limit of 150, so the batch goes in two.
		const scripts = [];
		const salesforce = {
			runApex: jest.fn((apex) =>
			{
				scripts.push(apex);
				const count = Number(apex.match(/launch < (\d+);/)[1]);
				const action = apex.match(/String actionId = '([^']+)'/)[1];
				const ids = Array.from({length: count}, (unused, index) => `a03${scripts.length}x${index}`);
				return {debugLines: [`VOLUME_LAUNCH stage=switchedOff action=${action} ordinal=0 ids=${ids.join(',')} launched=${count} dml=75/150`]};
			})
		};
		const context = {manifest: {runToken: 'abcdefab', org: {namespacePrefix: ''}}, salesforce};
		const line = launchWave(context, 'switchedOff', 50, 0);
		expect(salesforce.runApex).toHaveBeenCalledTimes(2);
		expect(scripts[0]).toContain('launch < 25;');
		expect(scripts[1]).toContain('launch < 25;');
		expect(scripts[0]).toContain('KIND_WAVE_RUN, 2, 0, launch)');
		expect(scripts[1]).toContain('KIND_WAVE_RUN, 102, 0, launch)');
		expect(line).toMatchObject({action: mintVolumeId(KINDS.action, 'abcdefab', 902, 0, 0), launched: 50});
		expect(new Set(line.ids).size).toBe(50);
	});

	it('gives a batch one over a chunk its own last transaction of one, and an empty batch no transaction', () =>
	{
		const counts = [];
		const salesforce = {
			runApex: jest.fn((apex) =>
			{
				const count = Number(apex.match(/launch < (\d+);/)[1]);
				counts.push(count);
				const action = apex.match(/String actionId = '([^']+)'/)[1];
				const ids = Array.from({length: count}, (unused, index) => `a03${counts.length}x${index}`);
				return {debugLines: [`VOLUME_LAUNCH stage=switchedOff action=${action} ordinal=0 ids=${ids.join(',')} launched=${count} dml=3/150`]};
			})
		};
		const context = {manifest: {runToken: 'abcdefab', org: {namespacePrefix: ''}}, salesforce};
		expect(launchWave(context, 'switchedOff', 26, 0)).toMatchObject({launched: 26});
		expect(counts).toEqual([25, 1]);
		expect(launchWave(context, 'switchedOff', 0, 0)).toMatchObject({ids: [], launched: 0});
		expect(salesforce.runApex).toHaveBeenCalledTimes(2);
	});

	it('launches a small batch in one transaction, as before', () =>
	{
		const salesforce = {
			runApex: jest.fn((apex) =>
			{
				const action = apex.match(/String actionId = '([^']+)'/)[1];
				return {debugLines: [`VOLUME_LAUNCH stage=slowExport action=${action} ordinal=0 ids=a,b launched=2 dml=6/150`]};
			})
		};
		const line = launchWave({manifest: {runToken: 'abcdefab', org: {namespacePrefix: ''}}, salesforce}, 'slowExport', 2, 5000);
		expect(salesforce.runApex).toHaveBeenCalledTimes(1);
		expect(line).toMatchObject({ids: ['a', 'b'], launched: 2});
	});
});

// A page object whose every button clicks into a list, so a test can read what was pressed in order.
function fakeMonitor(clicks, {launchThrows = false} = {})
{
	const locator = (name) => ({click: async() => clicks.push(name), waitFor: async() => {}, textContent: async() => name});
	return {
		navigate: jest.fn(async() => {}), navigateToRun: jest.fn(async() => {}), getSuspendButton: () => locator('suspend'), getResumeButton: () => locator('resume'),
		getConfirmButton: () => locator('confirm'), launchThrows
	};
}

describe('candidateQuery', () =>
{
	it('asks for failed runs of the chain under the engine actions only', () =>
	{
		const soql = candidateQuery('kern__', 'Volume_RecoverableImport', ['a', 'b'], 20);
		expect(soql).toBe('SELECT Id, kern__CorrelationId__c, kern__ChainName__c, kern__RootCorrelationId__c FROM kern__AsyncChainExecution__c '
				+ 'WHERE kern__ChainName__c = \'Volume_RecoverableImport\' AND kern__Status__c = \'Failed\' AND kern__RootCorrelationId__c IN (\'a\', \'b\') '
				+ 'ORDER BY CreatedDate LIMIT 20');
	});
});

describe('waitForStatuses', () =>
{
	it('returns when every run reads the status and times out otherwise', async() =>
	{
		const statuses = ['Running', 'Aborted'];
		const salesforce = {query: jest.fn(() => ({records: [{Id: 'x', Status__c: statuses.length > 1 ? statuses.shift() : statuses[0]}], totalSize: 1}))};
		const clock = {now: 0};
		const sleep = async(milliseconds) => { clock.now += milliseconds; };
		const options = {sleep, now: () => clock.now, timeoutMilliseconds: 60_000};
		await expect(waitForStatuses(salesforce, '', ['x'], 'Aborted', options)).resolves.toEqual({reached: true, waitedMilliseconds: 5000});
		const stuck = {query: jest.fn(() => ({records: [{Id: 'x', Status__c: 'Running'}], totalSize: 1}))};
		clock.now = 0;
		await expect(waitForStatuses(stuck, '', ['x'], 'Aborted', {...options, timeoutMilliseconds: 12_000})).resolves.toMatchObject({reached: false});
	});
});

describe('waitUntilNoneRunning', () =>
{
	it('returns once no pressed run is still Running, and times out otherwise', async() =>
	{
		const running = [2, 0];
		const salesforce = {query: jest.fn(() => ({records: [], totalSize: running.length > 1 ? running.shift() : running[0]}))};
		const clock = {now: 0};
		const sleep = async(milliseconds) => { clock.now += milliseconds; };
		const options = {sleep, now: () => clock.now, timeoutMilliseconds: 60_000};
		await expect(waitUntilNoneRunning(salesforce, '', ['x', 'y'], options)).resolves.toEqual({ended: true, waitedMilliseconds: 5000});
		expect(salesforce.query.mock.calls[0][0]).toContain('Id IN (\'x\', \'y\') AND Status__c = \'Running\'');
		const stuck = {query: jest.fn(() => ({records: [], totalSize: 1}))};
		clock.now = 0;
		await expect(waitUntilNoneRunning(stuck, '', ['x'], {...options, timeoutMilliseconds: 12_000})).resolves.toMatchObject({ended: false});
	});
});

describe('the kill switch', () =>
{
	it('resumes the chains even when the batch launched while off cannot be read', async() =>
	{
		const clicks = [];
		const monitor = fakeMonitor(clicks);
		const salesforce = {runApex: jest.fn(() => { throw new Error('the launch script failed'); }), query: jest.fn(() => ({records: [], totalSize: 0}))};
		const manifest = {runToken: 'abcdefab', org: {namespacePrefix: ''}, actions: [], operatorWave: {retries: [], restarts: [], aborts: [], deadJobStalls: []}};
		const context = {manifest, shape: {wave: {killSwitchBatch: 5}}, salesforce, log: () => {}, readToast: async() => 'ok'};
		await expect(flipKillSwitch(context, monitor, {}, async() => {})).rejects.toThrow('the launch script failed');
		expect(clicks).toEqual(['suspend', 'confirm', 'resume', 'confirm']);
	});
});

describe('operate', () =>
{
	it('refuses to run after a drain that did not settle, naming the drain stage', async() =>
	{
		const manifest = {
			stages: {preflight: {ok: true}, drain: {ok: true, timedOut: true}}, actions: [], operatorWave: {retries: [], restarts: [], aborts: [], deadJobStalls: []}
		};
		const result = await run({manifest, salesforce: {}, shape: {}, log: () => {}});
		expect(result.stages.operate).toMatchObject({ok: false});
		expect(result.stages.operate.reason).toMatch(/drain/);
	});

	it('records the stage failed with the reason and returns the manifest when a wave step throws', async() =>
	{
		const manifest = {
			runToken: 'abcdefab', org: {namespacePrefix: ''}, stages: {preflight: {ok: true}, drain: {ok: true}}, actions: [{id: 'a', synthesized: false}],
			operatorWave: {retries: [], restarts: [], aborts: [], deadJobStalls: []}, watchdog: {thresholdMinutes: 3, jobNamePrefix: 'x'}
		};
		const salesforce = {query: jest.fn(() => { throw new Error('the org went away'); })};
		const page = {};
		const browser = {newContext: async() => ({newPage: async() => page, close: async() => {}}), close: async() => {}};
		const result = await run({manifest, salesforce, shape: {wave: {retries: 1, restarts: 1}}, log: () => {}, browser, monitor: fakeMonitor([]), globalSetup: async() => {}});
		expect(result.stages.operate).toMatchObject({ok: false});
		expect(result.stages.operate.reason).toMatch(/the org went away/);
	});
});

describe('the started-step Stalled rows', () =>
{
	/**
	 * @description An org door whose script runs answer with one launch line each, ids made from the slice's first ordinal.
	 *
	 * @param {string[]} scripts Receives every script sent, in order.
	 *
	 * @returns {object}
	 */
	function launchingOrg(scripts)
	{
		return {
			runApex: jest.fn((apex) =>
			{
				scripts.push(apex);
				const first = Number(apex.match(/ordinal = (\d+);/)[1]);
				const count = Number(apex.match(/ordinal < \d+ \+ (\d+);/)[1]);
				const action = apex.match(/String actionId = '([^']+)'/)[1];
				const ids = Array.from({length: count}, (unused, index) => `a0S${first + index}`);
				return {debugLines: [`VOLUME_LAUNCH stage=stalledStarted action=${action} ordinal=${first} ids=${ids.join(',')} launched=${count} dml=1/150`]};
			})
		};
	}

	it('lays the rows asked for in slices under their own action, and records them apart from the screen-fixture rows', () =>
	{
		const scripts = [];
		const manifest = {runToken: 'abcdefab', org: {namespacePrefix: ''}, actions: [], synthesized: {stalledRows: ['fixture'], startedStepRows: []}};
		layDownStartedStepStalls({manifest, options: {stalledStarted: 250}, salesforce: launchingOrg(scripts), log: () => {}});
		expect(scripts.map((apex) => apex.match(/ordinal = (\d+);/)[1])).toEqual(['0', '100', '200']);
		expect(scripts.every((apex) => apex.includes('CurrentJobId__c') && apex.includes('\'started\' => true}'))).toBe(true);
		expect(manifest.synthesized.startedStepRows).toHaveLength(250);
		expect(new Set(manifest.synthesized.startedStepRows).size).toBe(250);
		expect(manifest.synthesized.stalledRows).toEqual(['fixture']);
		const action = manifest.actions[0];
		expect(action).toMatchObject({id: mintVolumeId(KINDS.action, 'abcdefab', 906, 0, 0), kind: 'stalledStarted', synthesized: true});
		expect(action.expected).toEqual({runs: 250, byStatus: {Failed: 250}});
	});

	it('lays nothing and sends no script when no rows are asked for', () =>
	{
		const scripts = [];
		const manifest = {runToken: 'abcdefab', org: {namespacePrefix: ''}, actions: [], synthesized: {stalledRows: [], startedStepRows: []}};
		layDownStartedStepStalls({manifest, options: {stalledStarted: 0}, salesforce: launchingOrg(scripts), log: () => {}});
		layDownStartedStepStalls({manifest, options: {}, salesforce: launchingOrg(scripts), log: () => {}});
		expect(scripts).toHaveLength(0);
		expect(manifest.actions).toHaveLength(0);
	});
});

describe('the dead-job stalls', () =>
{
	it('lays half on a step safe to repeat, which the watchdog re-drives, and half on one that is not, which it ends Failed', () =>
	{
		const scripts = [];
		const salesforce = {
			runApex: jest.fn((apex, label) =>
			{
				scripts.push({apex, label});
				if(label === 'wave-abort-jobs')
				{
					return {debugLines: ['VOLUME_ABORT aborted=20']};
				}
				const count = Number(apex.match(/launch < (\d+);/)[1]);
				const kind = apex.match(/String kind = '([^']+)'/)[1];
				const action = apex.match(/String actionId = '([^']+)'/)[1];
				const ids = Array.from({length: count}, (unused, index) => `${kind}-${index}`);
				return {debugLines: [`VOLUME_LAUNCH stage=${kind} action=${action} ordinal=0 ids=${ids.join(',')} launched=${count} dml=1/150`]};
			}),
			query: jest.fn((soql) => ({
				records: [...soql.matchAll(/'([^']+)'/g)].map(([, id]) => ({Id: id, CurrentJobId__c: `707${id}`, RunKey__c: `key-${id}`, LastModifiedDate: 'x'})),
				totalSize: 0
			}))
		};
		const manifest = {runToken: 'abcdefab', org: {namespacePrefix: ''}, actions: [], operatorWave: {deadJobStalls: []}, watchdog: {thresholdMinutes: 3}};
		makeDeadJobStalls({manifest, shape: {wave: {deadJobStalls: 20}}, salesforce, log: () => {}});
		const stalls = manifest.operatorWave.deadJobStalls;
		expect(stalls).toHaveLength(20);
		expect(stalls.filter((stall) => stall.idempotent === true).map((stall) => stall.executionId)).toEqual(
			Array.from({length: 10}, (unused, index) => `idempotentDeferredDispatch-${index}`)
		);
		expect(stalls.filter((stall) => stall.idempotent === false)).toHaveLength(10);
		const byKind = Object.fromEntries(manifest.actions.map((action) => [action.kind, action.expected]));
		expect(byKind).toEqual({deferredDispatch: {runs: 10, byStatus: {Failed: 10}}, idempotentDeferredDispatch: {runs: 10, byStatus: {Completed: 10}}});
		const aborts = scripts.find((script) => script.label === 'wave-abort-jobs').apex;
		expect(stalls.every((stall) => aborts.includes(`'${stall.jobId}'`))).toBe(true);
	});

	it('gives the odd stall to the re-driven half, so a staged run of two proves both outcomes with one each', () =>
	{
		const launched = [];
		const salesforce = {
			runApex: jest.fn((apex, label) =>
			{
				if(label === 'wave-abort-jobs')
				{
					return {debugLines: []};
				}
				const count = Number(apex.match(/launch < (\d+);/)[1]);
				const kind = apex.match(/String kind = '([^']+)'/)[1];
				launched.push([kind, count]);
				const ids = Array.from({length: count}, (unused, index) => `${kind}-${index}`);
				return {debugLines: [`VOLUME_LAUNCH stage=${kind} action=a ordinal=0 ids=${ids.join(',')} launched=${count} dml=1/150`]};
			}),
			query: jest.fn((soql) => ({records: [...soql.matchAll(/'([^']+)'/g)].map(([, id]) => ({Id: id, CurrentJobId__c: `707${id}`})), totalSize: 0}))
		};
		const manifest = {runToken: 'abcdefab', org: {namespacePrefix: ''}, actions: [], operatorWave: {deadJobStalls: []}, watchdog: {thresholdMinutes: 3}};
		makeDeadJobStalls({manifest, shape: {wave: {deadJobStalls: 3}}, salesforce, log: () => {}});
		expect(launched).toEqual([['idempotentDeferredDispatch', 2], ['deferredDispatch', 1]]);
	});
});

describe('pressOnRun', () =>
{
	it('navigates to the run, presses the button, confirms and reads the toast', async() =>
	{
		const clicks = [];
		const locator = (name) => ({click: async() => clicks.push(name), waitFor: async() => {}, textContent: async() => name});
		const monitor = {navigateToRun: jest.fn(async() => {}), getRetryButton: () => locator('retry'), getConfirmButton: () => locator('confirm')};
		const page = {};
		const readToast = jest.fn(async() => 'Retry started.');
		const result = await pressOnRun(monitor, page, {correlationId: 'c', button: 'getRetryButton', readToast});
		expect(monitor.navigateToRun).toHaveBeenCalledWith('c');
		expect(clicks).toEqual(['retry', 'confirm']);
		expect(result).toEqual({pressed: true, toast: 'Retry started.'});
	});
});
