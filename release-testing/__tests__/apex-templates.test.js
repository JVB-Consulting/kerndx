// SPDX-License-Identifier: BUSL-1.1
const fs = require('fs');
const path = require('path');
const templates = require('../scripts/consoles-at-volume/apex-templates');
const {planSmallActions, SMALL_ACTION_SHAPES, WAVE_CHAIN_NAMES} = require('../scripts/consoles-at-volume/shapes');

const NO_NAMESPACE_LITERAL = /kern(__|\.)/;
const NAMESPACE_TOKENS = /__(APEX|FIELD)_NAMESPACE__/g;
const ANY_TOKEN = /__[A-Z][A-Z_]+__/;
const ACTION_ID = 'abcdefab-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const WATCHDOG_PREFIX = 'Consoles At Volume Watchdog';
// One sample value per token of every template; a new template must join this table or the first test names it.
const SAMPLE_VALUES = {
	'launch-reconciliation.apex': {
		__ACTION_ID__: ACTION_ID, __RUN_TOKEN__: 'abcdefab', __ROOT_START__: 13, __ROOT_COUNT__: 1, __TARGET_DEPTH__: 3, __BUSY_MILLISECONDS__: 1500, __STAGGER__: false
	},
	'launch-small-action.apex': {__ACTION_ID__: ACTION_ID, __RUN_TOKEN__: 'abcdefab', __ACTION_ORDINAL__: 3, __LAUNCH_PLAN__: JSON.stringify(planSmallActions(5)[3].launches)},
	'launch-wave.apex': {__ACTION_ID__: ACTION_ID, __RUN_TOKEN__: 'abcdefab', __KIND__: 'deferredDispatch', __KIND_INDEX__: 4, __COUNT__: 2, __BUSY_MILLISECONDS__: 1500},
	'abort-jobs.apex': {__JOB_IDS__: templates.apexStringList(['707a', '707b'])},
	'schedule-watchdog.apex': {__THRESHOLD_MINUTES__: 3, __JOB_NAME_PREFIX__: WATCHDOG_PREFIX},
	'unschedule-watchdog.apex': {__JOB_NAME_PREFIX__: WATCHDOG_PREFIX},
	'synthesize-stalled.apex': {__COUNT__: 2, __RUN_TOKEN__: 'abcdefab', __ACTION_ID__: ACTION_ID},
	'synthesize-stalled-started.apex': {__COUNT__: 2, __FIRST_ORDINAL__: 100, __RUN_TOKEN__: 'abcdefab', __ACTION_ID__: ACTION_ID},
	'assign-permission-sets.apex': {
		__PERMISSION_SET_NAMES__: templates.apexStringList(['AsyncChainRedrive']), __NAMESPACE_CLAUSE__: 'NamespacePrefix = NULL', __USER_ID__: '005000000000001'
	},
	'probe-entry.apex': {__TOKEN__: 'abcdefabxx'},
	'teardown.apex': {__ACTION_IDS__: templates.apexStringList(['act-a', 'act-b']), __RUN_TOKEN__: 'abcdefab', __WATCHED_ROW_IDS__: templates.apexStringList(['a0S1'])},
	'probe-fan-out.apex': {__RUN_TOKEN__: 'abcdefab', __TARGET_DEPTH__: 3, __BUSY_MILLISECONDS__: 1500},
	'probe-stalled.apex': {},
	'schedule-watchdog-once.apex': {__THRESHOLD_MINUTES__: 2, __JOB_NAME__: 'Consoles At Volume Probe Watchdog'},
	'probe-cleanup.apex': {}
};

describe('every template', () =>
{
	it.each(templates.listTemplates())('%s renders with every token filled and no namespace literal', (name) =>
	{
		expect(SAMPLE_VALUES).toHaveProperty([name]);
		const apex = templates.renderTemplate(name, SAMPLE_VALUES[name]);
		expect(apex.replace(NAMESPACE_TOKENS, '')).not.toMatch(ANY_TOKEN);
		expect(apex).not.toMatch(NO_NAMESPACE_LITERAL);
	});

	it('refuses a template with a token left unfilled, naming it', () =>
	{
		expect(() => templates.renderTemplate('teardown.apex', {__RUN_TOKEN__: 'abcdefab'})).toThrow(/__ACTION_IDS__/);
	});

	it('every sample names a template that exists', () =>
	{
		expect(Object.keys(SAMPLE_VALUES).sort()).toEqual(templates.listTemplates());
	});

	it('the teardown deletes fewer than ten thousand rows in one transaction, the platform DML-row limit', () =>
	{
		const source = fs.readFileSync(path.join(templates.TEMPLATES_DIRECTORY, 'teardown.apex'), 'utf8');
		const limits = (source.match(/delete \[[^\]]*\]/g) || []).map((statement) => Number((statement.match(/LIMIT (\d+)/) || [])[1]));
		expect(limits).toHaveLength(3);
		expect(limits.every((limit) => limit > 0)).toBe(true);
		expect(limits.reduce((sum, limit) => sum + limit, 0)).toBeLessThan(10_000);
	});
});

describe('the launch templates', () =>
{
	it('the reconciliation batch adopts the action id, keys every root by the token and staggers when told', () =>
	{
		const values = {...SAMPLE_VALUES['launch-reconciliation.apex'], __ROOT_START__: 0, __ROOT_COUNT__: 13, __STAGGER__: true};
		const apex = templates.renderTemplate('launch-reconciliation.apex', values);
		expect(apex).toContain(`__APEX_NAMESPACE__LOG_Builder.setCorrelationId('${ACTION_ID}')`);
		expect(apex).toContain('for(Integer root = 0; root < 0 + 13; root++)');
		expect(apex).toContain('Boolean stagger = true;');
		expect(apex).toContain('chain.execute(SubscriberChainSteps.volumeRunId(runToken, SubscriberChainSteps.KIND_RECONCILIATION_RUN, root, 0, 0))');
	});

	it('the two dead-job kinds start on a step not safe to repeat and on one that is, which carries on past its own failure', () =>
	{
		const values = {...SAMPLE_VALUES['launch-wave.apex'], __KIND__: 'idempotentDeferredDispatch'};
		const apex = templates.renderTemplate('launch-wave.apex', values);
		const branch = (kind) => apex.slice(apex.indexOf(`kind == '${kind}'`), apex.indexOf('execute(runId)', apex.indexOf(`kind == '${kind}'`)));
		expect(branch('deferredDispatch')).toContain('.then(new SubscriberChainSteps.NarratingStep())');
		expect(branch('deferredDispatch')).toContain('.withDelayMinutes(10)');
		// RecoveringStep declares itself safe to repeat; the true lets the chain carry on past the failure its first run makes.
		expect(branch('idempotentDeferredDispatch')).toContain('.then(new SubscriberChainSteps.RecoveringStep(), true)');
		expect(branch('idempotentDeferredDispatch')).toContain('.withDelayMinutes(10)');
	});

	it('the small action carries its launch plan as JSON and names every shape the shape table knows', () =>
	{
		const apex = templates.renderTemplate('launch-small-action.apex', SAMPLE_VALUES['launch-small-action.apex']);
		expect(apex).toContain('JSON.deserializeUntyped(\'[{"shape":"NestedImport","count":1}');
		expect(apex).toContain('Integer actionOrdinal = 3;');
		const source = fs.readFileSync(path.join(templates.TEMPLATES_DIRECTORY, 'launch-small-action.apex'), 'utf8');
		for(const [shapeName, shape] of Object.entries(SMALL_ACTION_SHAPES))
		{
			expect(source).toContain(`shape == '${shapeName}'`);
			expect(source).toContain(`'${shape.chainName}'`);
		}
	});

	it('the wave names every kind and its chain', () =>
	{
		const source = fs.readFileSync(path.join(templates.TEMPLATES_DIRECTORY, 'launch-wave.apex'), 'utf8');
		for(const [kind, chainName] of Object.entries(WAVE_CHAIN_NAMES).filter(([waveKind]) => waveKind !== 'stalledArchive'))
		{
			expect(source).toContain(`kind == '${kind}'`);
			expect(source).toContain(`'${chainName}'`);
		}
		expect(source).toContain('kind == \'orderSync\'');
		expect(templates.renderTemplate('launch-wave.apex', SAMPLE_VALUES['launch-wave.apex'])).toContain('String kind = \'deferredDispatch\';');
	});

	it('the slow exports get three busy steps an abort and never fewer than five, so every abort is pressed while its chain still runs', () =>
	{
		// Five seconds of CPU a step is the fixture's cap and a press through the screen takes about ten seconds, so three steps an abort outlive the presses.
		const rendered = templates.renderTemplate('launch-wave.apex', {...SAMPLE_VALUES['launch-wave.apex'], __KIND__: 'slowExport', __KIND_INDEX__: 1, __COUNT__: 10});
		expect(rendered).toContain('for(Integer step = 0; step < Math.min(50, Math.max(5, 10 * 3)); step++)');
		expect(rendered).not.toMatch(/then\(new SubscriberChainSteps\.BusyStep\(\)\)\s*\.then\(new SubscriberChainSteps\.BusyStep\(\)\)/);
	});
});

describe('readLaunchLine', () =>
{
	it('reads the action, the ordinal and the ids', () =>
	{
		expect(templates.readLaunchLine(['VOLUME_LAUNCH stage=reconciliation action=abc ordinal=0 ids=a1,a2 launched=2 dml=8/150']))
		.toEqual({stage: 'reconciliation', action: 'abc', ordinal: 0, ids: ['a1', 'a2'], launched: 2});
		expect(() => templates.readLaunchLine(['nothing'])).toThrow(/VOLUME_LAUNCH/);
	});
});
