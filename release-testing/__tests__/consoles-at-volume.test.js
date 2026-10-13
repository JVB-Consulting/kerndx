// SPDX-License-Identifier: BUSL-1.1
const fs = require('fs');
const os = require('os');
const path = require('path');
const {STAGE_ORDER, loadStage, exitCodeFor, runStage, pinOrgAlias} = require('../scripts/consoles-at-volume');
const verify = require('../scripts/consoles-at-volume/verify');

const BACKSTOP_PHRASE = 'Chain run transition refused by the backstop';
const LOCK_TOKEN = 'UNABLE_TO_LOCK_ROW';
const BACKSTOP_REFUSALS = 3;
const LOCK_REFUSALS = 1;

/**
 * @description The smallest manifest the verify stage can read: no action, an empty operator wave, nothing synthesized.
 *
 * @returns {object}
 */
function emptyManifest()
{
	return {
		runToken: 'abcdefab', mode: 'live', startedAt: '2026-10-10T10:00:00.000Z', org: {namespacePrefix: ''}, actions: [], stages: {},
		operatorWave: {retries: [], restarts: [], aborts: [], deadJobStalls: [], stallProbes: []},
		synthesized: {stalledRows: [], chainRows: 0}, drainRate: {jobsPerMinute: 10}
	};
}

describe('the driver entry', () =>
{
	it('moves a cleanly torn-down manifest aside, so the next run starts fresh instead of reusing its stages', async() =>
	{
		const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'entry-'));
		const manifestPath = path.join(directory, 'manifest.json');
		const manifest = {runToken: 'abcdefab', org: {namespacePrefix: ''}, actions: [{id: 'a'}], watchdog: {jobNamePrefix: 'x'}, stages: {verify: {ok: true, failed: 0}}};
		fs.writeFileSync(manifestPath, JSON.stringify(manifest));
		const debugLineFor = (apex) => (apex.includes('CronTrigger') ? 'VOLUME_WATCHDOG aborted=0' : 'VOLUME_TEARDOWN chainRows=0 logRows=0');
		const salesforce = {runApex: jest.fn((apex) => ({logs: '', debugLines: [debugLineFor(apex)]}))};
		const context = {options: {manifestPath, command: 'teardown'}, salesforce, manifest, log: () => {}};
		await runStage('teardown', context);
		expect(fs.existsSync(manifestPath)).toBe(false);
		const kept = JSON.parse(fs.readFileSync(path.join(directory, 'manifest-abcdefab-torn-down.json'), 'utf8'));
		expect(kept.tornDownAt).toBeDefined();
		fs.rmSync(directory, {recursive: true, force: true});
	});

	it('points the browser sign-in and the class deploy at the --org org, by setting the variable they read before any stage loads', () =>
	{
		const environment = {SF_SUBSCRIBER_ORG_ALIAS: 'MySubscriberOrg'};
		pinOrgAlias({alias: 'MyDevelopmentOrg'}, environment);
		expect(environment.SF_SUBSCRIBER_ORG_ALIAS).toBe('MyDevelopmentOrg');
		// With no --org the alias is the variable's own value already, so nothing changes.
		const unset = {};
		pinOrgAlias({alias: undefined}, unset);
		expect(unset).toEqual({});
	});

	it('resolves every stage and teardown to a module with a run function', () =>
	{
		for(const name of [...STAGE_ORDER, 'teardown'])
		{
			expect(typeof loadStage(name).run).toBe('function');
		}
	});

	it('exits on what the command itself did: a clean teardown is 0 even after a red verify, a red verify is 1', () =>
	{
		const afterRedVerify = {stages: {verify: {ok: true, failed: 26}}};
		expect(exitCodeFor('teardown', afterRedVerify)).toBe(0);
		expect(exitCodeFor('teardown', {stages: {...afterRedVerify.stages, teardown: {ok: false, reason: 'rows survived'}}})).toBe(1);
		expect(exitCodeFor('verify', afterRedVerify)).toBe(1);
		expect(exitCodeFor('run', afterRedVerify)).toBe(1);
		expect(exitCodeFor('run', {stages: {verify: {ok: true, failed: 0}}})).toBe(0);
		expect(exitCodeFor('launch', {stages: {launch: {ok: true}}})).toBe(0);
	});
});

describe('the two refusal counts', () =>
{
	it('asks the log for backstop refusals by their opening words and for lock refusals by the lock error code', () =>
	{
		const claims = verify.buildClaims(emptyManifest(), '');
		const backstop = claims.find((claim) => claim.name === 'backstop refusals counted');
		const lock = claims.find((claim) => claim.name === 'lock refusals counted');
		expect(backstop.soql).toContain(`ShortMessage__c LIKE '${BACKSTOP_PHRASE}%'`);
		expect(backstop.soql).toContain('FROM LogEntry__c');
		expect(lock.soql).toContain(`ShortMessage__c LIKE '%${LOCK_TOKEN}%'`);
		expect(lock.soql).toContain('ClassMethod__c IN (\'DML_Transaction.commitWork\')');
		expect(lock.soql).toContain('ExceptionType__c = \'System.DmlException\'');
		for(const claim of [backstop, lock])
		{
			expect(claim.soql).toContain('CreatedDate >= 2026-10-10T10:00:00.000Z');
			expect(claim.compare).toBe('atLeast');
			expect(claim.expected).toBe(0);
		}
	});

	it('reads both spellings of the save\'s class name and the namespaced field names on a namespaced org', () =>
	{
		const claims = verify.buildClaims(emptyManifest(), 'kern__');
		const backstop = claims.find((claim) => claim.name === 'backstop refusals counted');
		const lock = claims.find((claim) => claim.name === 'lock refusals counted');
		expect(backstop.soql).toContain('FROM kern__LogEntry__c');
		expect(backstop.soql).toContain(`kern__ShortMessage__c LIKE '${BACKSTOP_PHRASE}%'`);
		expect(lock.soql).toContain('FROM kern__LogEntry__c');
		expect(lock.soql).toContain('kern__ClassMethod__c IN (\'DML_Transaction.commitWork\', \'kern.DML_Transaction.commitWork\')');
		expect(lock.soql).toContain('kern__ExceptionType__c = \'System.DmlException\'');
		expect(lock.soql).toContain(`kern__ShortMessage__c LIKE '%${LOCK_TOKEN}%'`);
	});

	it('records both counts by name in the verify record, so the manifest carries them', async() =>
	{
		const query = jest.fn((soql) =>
		{
			if(soql.includes(BACKSTOP_PHRASE))
			{
				return {totalSize: BACKSTOP_REFUSALS, records: []};
			}
			return {totalSize: soql.includes(LOCK_TOKEN) ? LOCK_REFUSALS : 0, records: []};
		});
		const log = jest.fn();
		const manifest = await verify.run({manifest: emptyManifest(), salesforce: {query}, log});
		expect(manifest.stages.verify.counts).toEqual({backstopRefusals: BACKSTOP_REFUSALS, lockRefusals: LOCK_REFUSALS});
		expect(manifest.stages.verify.failed).toBe(0);
		expect(log).toHaveBeenCalledWith(`verify: ${BACKSTOP_REFUSALS} backstop refusals, ${LOCK_REFUSALS} lock refusals`);
	});
});
