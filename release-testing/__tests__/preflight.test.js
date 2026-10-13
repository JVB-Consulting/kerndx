// SPDX-License-Identifier: BUSL-1.1
jest.mock('../e2e/helpers/subscriber-deploy', () => ({deployStrippedSubscriberClasses: jest.fn(() => ({result: {status: 'Succeeded'}}))}));
const {run, projectStorageMegabytes} = require('../scripts/consoles-at-volume/preflight');
const {scaleShape} = require('../scripts/consoles-at-volume/shapes');

const EVERY_PERMISSION_SET = ['AsyncChainRedrive', 'AsyncChainAbort', 'AsyncChainKillSwitch', 'KernE2EAuditFieldAccess'];

// An org door answering preflight's queries from the given state.
function fakeSalesforce({namespace = '', hasSteps = true, remainingMegabytes = 500, earlierRows = 0, infoPersists = true, assigned = EVERY_PERMISSION_SET} = {})
{
	return {
		alias: 'Dev',
		query: jest.fn((soql) =>
		{
			if(soql.includes('FROM ApexClass WHERE Name = \'UTIL_AsyncChain\''))
			{
				return {records: [{NamespacePrefix: namespace || null}], totalSize: 1};
			}
			if(soql.includes('FROM ApexClass WHERE Name = \'SubscriberChainSteps\''))
			{
				return {records: hasSteps ? [{Body: 'class FanOutStep extends'}] : [], totalSize: hasSteps ? 1 : 0};
			}
			if(soql.includes('FROM PermissionSetAssignment'))
			{
				return {records: assigned.map((name) => ({PermissionSet: {Name: name}})), totalSize: assigned.length};
			}
			if(soql.includes('FROM User WHERE'))
			{
				return {records: [{Id: '005'}], totalSize: 1};
			}
			if(soql.includes('LIKE \'Volume\\_%\''))
			{
				return {records: [], totalSize: earlierRows};
			}
			if(soql.includes('ShortMessage__c LIKE'))
			{
				return {records: [], totalSize: infoPersists ? 1 : 0};
			}
			throw new Error(`unexpected query ${soql}`);
		}),
		runApex: jest.fn(() => ({logs: '', debugLines: ['VOLUME_PREFLIGHT emitted=x']})),
		listLimits: jest.fn(() => ({dataStorageMegabytes: {maximum: 1000, remaining: remainingMegabytes}})),
		orgDisplay: jest.fn(() => ({username: 'dev@example.com', instanceUrl: 'https://x'})),
		runUserId: jest.fn(() => '005')
	};
}

function context(overrides = {}, salesforceOptions = {})
{
	return {
		options: {mode: 'staged', size: 1, manifestPath: '/dev/null/manifest.json', reuse: false, alias: 'Dev'}, salesforce: fakeSalesforce(salesforceOptions),
		shape: scaleShape('staged', 1), manifest: null, log: () => {}, sleep: async() => {}, ...overrides
	};
}

describe('preflight', () =>
{
	it('creates the manifest and passes every check on a ready development org', async() =>
	{
		const manifest = await run(context());
		expect(manifest.stages.preflight.ok).toBe(true);
		expect(manifest.runToken).toMatch(/^[a-f]{8}$/);
		expect(manifest.org).toEqual({alias: 'Dev', namespacePrefix: '', userId: '005'});
		expect(manifest.watchdog).toEqual({thresholdMinutes: 3, jobNamePrefix: 'Consoles At Volume Watchdog', scheduledBy: 'operate', scheduled: false});
	});

	it('deploys the stripped step classes on a development org that lacks them', async() =>
	{
		const {deployStrippedSubscriberClasses} = require('../e2e/helpers/subscriber-deploy');
		await run(context({}, {hasSteps: false}));
		// To the org the command line named, never to the one the environment variable names.
		expect(deployStrippedSubscriberClasses).toHaveBeenCalledWith(['SubscriberChainSteps', 'SubscriberChainSteps_TEST'], {alias: 'Dev'});
	});

	it('refuses a subscriber org that lacks the step classes, naming Phase 1.4', async() =>
	{
		const manifest = await run(context({}, {namespace: 'kern', hasSteps: false}));
		expect(manifest.stages.preflight.ok).toBe(false);
		expect(manifest.stages.preflight.reason).toMatch(/Phase 1\.4/);
	});

	it('refuses when the projected rows will not fit the remaining storage', async() =>
	{
		const manifest = await run(context({}, {remainingMegabytes: 5}));
		expect(manifest.stages.preflight.ok).toBe(false);
		expect(manifest.stages.preflight.reason).toMatch(/storage/);
		expect(projectStorageMegabytes(scaleShape('full', 1))).toBeGreaterThan(20);
	});

	it('refuses an earlier load with no manifest to reuse', async() =>
	{
		const manifest = await run(context({}, {earlierRows: 40}));
		expect(manifest.stages.preflight.ok).toBe(false);
		expect(manifest.stages.preflight.reason).toMatch(/teardown/);
	});

	it('reuses a verified load that is still in the org', async() =>
	{
		const existing = {
			mode: 'staged', size: 1, runToken: 'abcdefab', org: {alias: 'Dev', namespacePrefix: ''}, actions: [{id: 'a'}], stages: {verify: {ok: true, failed: 0, finishedAt: 'x'}},
			watchdog: null
		};
		const manifest = await run(context({manifest: existing}, {earlierRows: 40}));
		expect(manifest.stages.preflight).toMatchObject({ok: true, reused: true});
	});

	it('refuses when an INFO entry does not persist', async() =>
	{
		const manifest = await run(context({}, {infoPersists: false}));
		expect(manifest.stages.preflight.ok).toBe(false);
		expect(manifest.stages.preflight.reason).toMatch(/INFO/);
	});
});
