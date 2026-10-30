// SPDX-License-Identifier: Apache-2.0
const fs = require('fs');
const os = require('os');
const path = require('path');
const {cloneReconciliationRoot, cloneSmallAction, buildIdMap, renderChainCsv, escapeCsvField, chunk, synthesize, ENGINE_MINTED_SECOND} = require(
		'../scripts/consoles-at-volume/synthesized-rows');
const {SMALL_ACTION_KINDS} = require('../scripts/consoles-at-volume/shapes');
const {mintVolumeId, KINDS, VOLUME_ID_SHAPE, createManifest} = require('../scripts/consoles-at-volume/manifest');
const {scaleShape, planSmallActions} = require('../scripts/consoles-at-volume/shapes');
const {TOKEN, ACTION, MINUTE, exemplarTree} = require('./fixtures/exemplar-tree');

describe('cloneReconciliationRoot', () =>
{
	const exemplar = exemplarTree();
	const clone = cloneReconciliationRoot({exemplar, runToken: TOKEN, fromRootOrdinal: 0, toRootOrdinal: 5, actionId: ACTION, timeShiftMilliseconds: -50 * MINUTE});

	it('re-keys every row under root ordinal five and keeps the tree launched under itself', () =>
	{
		expect(clone.chainRows).toHaveLength(7);
		const ids = new Set(clone.chainRows.map((row) => row.CorrelationId__c));
		expect(ids.size).toBe(7);
		expect([...ids].every((id) => VOLUME_ID_SHAPE.test(id) && id.startsWith(`${TOKEN}-bbbb-aaaf-`))).toBe(true);
		expect(exemplar.rows.some((row) => ids.has(row.CorrelationId__c))).toBe(false);
		const root = clone.chainRows.find((row) => row.ChainName__c === 'Volume_Reconciliation');
		expect(root.LaunchCorrelationId__c).toBe(ACTION);
		expect(clone.chainRows.filter((row) => row.LaunchCorrelationId__c === root.CorrelationId__c)).toHaveLength(2);
		expect(clone.chainRows.every((row) => row.RootCorrelationId__c === ACTION)).toBe(true);
	});

	it('keeps what the engine wrote, shifts every time, keeps durations and ties siblings to a second', () =>
	{
		const failed = clone.chainRows.find((row) => row.Status__c === 'Failed');
		expect(failed.ErrorMessage__c).toBe('Account batch 3 did not balance; posting held');
		expect(failed.StepLog__c).toBe(exemplar.rows[0].StepLog__c);
		expect(Date.parse(clone.chainRows[0].StartedAt__c)).toBe(Date.parse(exemplar.rows[0].StartedAt__c) - 50 * MINUTE);
		expect(clone.chainRows.every((row) => row.DurationMs__c === MINUTE)).toBe(true);
		const siblings = clone.chainRows.filter((row) => row.ChainName__c === 'Volume_RegionReconcile');
		expect(new Set(siblings.map((row) => row.StartedAt__c)).size).toBe(1);
		expect(siblings[0].CreatedDate).toBe(siblings[0].StartedAt__c);
		expect(clone.chainRows.every((row) => row.CurrentJobId__c === undefined && row.RunKey__c === undefined)).toBe(true);
	});

	it('re-keys the entries, rewrites ids inside their text and gives them their own transactions', () =>
	{
		expect(clone.logRows).toHaveLength(8);
		const ids = new Set(clone.chainRows.map((row) => row.CorrelationId__c));
		const launchEntries = clone.logRows.filter((row) => row.ShortMessage__c.startsWith('Chain ') && row.ShortMessage__c.includes(' launched under '));
		expect(launchEntries).toHaveLength(3);
		expect(launchEntries.every((row) => row.CorrelationId__c === ACTION || ids.has(row.CorrelationId__c))).toBe(true);
		// The engine's launch line ends in a period after the run id, so the id is found inside the text, never at its end.
		expect(launchEntries.every((row) => [...ids].some((id) => row.ShortMessage__c.includes(id)))).toBe(true);
		const rootLaunch = launchEntries.find((row) => row.CorrelationId__c === ACTION);
		expect(rootLaunch.ShortMessage__c).toContain(clone.chainRows.find((row) => row.ChainName__c === 'Volume_Reconciliation').CorrelationId__c);
		expect(clone.logRows.every((row) => row.RootCorrelationId__c === ACTION && row.TransactionId__c.startsWith(`synth-${TOKEN}-`))).toBe(true);
		expect(new Set(clone.logRows.map((row) => row.TransactionId__c)).size).toBe(3);
	});

	it('maps a cloned entry\'s parent transaction to the clone\'s own transactions, never to the exemplar\'s', () =>
	{
		const transactions = new Set(clone.logRows.map((row) => row.TransactionId__c));
		const parents = clone.logRows.map((row) => row.ParentTransactionId__c);
		expect(parents.every((parent) => parent === '' || transactions.has(parent))).toBe(true);
		expect(parents.filter((parent) => parent !== '')).toHaveLength(7);
		expect(parents.some((parent) => parent.startsWith('tx-'))).toBe(false);
	});

	it('two clones never share an id', () =>
	{
		const other = cloneReconciliationRoot({exemplar, runToken: TOKEN, fromRootOrdinal: 0, toRootOrdinal: 6, actionId: ACTION, timeShiftMilliseconds: -60 * MINUTE});
		const ids = new Set([...clone.chainRows, ...other.chainRows].map((row) => row.CorrelationId__c));
		expect(ids.size).toBe(14);
	});
});

describe('cloneSmallAction', () =>
{
	it('re-keys the action and its rows, and gives an engine-minted child a harness id under the same action', () =>
	{
		const actionId = mintVolumeId(KINDS.action, TOKEN, 3, 0, 0);
		const own = mintVolumeId(KINDS.smallActionRun, TOKEN, 3, 0, 0);
		const child = '0f1e2d3c-4b5a-4968-8776-655443322110';
		const completed = {
			Status__c: 'Completed', RootCorrelationId__c: actionId, TotalSteps__c: 2, CompletedSteps__c: 2, StepLog__c: '[]', ContextData__c: '{}', InitialContextData__c: '{}',
			FailureCategory__c: '', ErrorMessage__c: '', AllowRestart__c: false
		};
		const rows = [
			{
				...completed, ChainName__c: 'Volume_OrderSyncNotified', CorrelationId__c: own, LaunchCorrelationId__c: actionId, StartedAt__c: '2026-09-24T12:00:00.000Z',
				CompletedAt__c: '2026-09-24T12:00:09.000Z', DurationMs__c: 9000, CreatedDate: '2026-09-24T12:00:00.000Z', LastModifiedDate: '2026-09-24T12:00:09.000Z'
			},
			{
				...completed, ChainName__c: 'SubscriberNestedChild', CorrelationId__c: child, LaunchCorrelationId__c: own, StartedAt__c: '2026-09-24T12:00:05.000Z',
				CompletedAt__c: '2026-09-24T12:00:08.000Z', DurationMs__c: 3000, CreatedDate: '2026-09-24T12:00:05.000Z', LastModifiedDate: '2026-09-24T12:00:08.000Z'
			}
		];
		const action = {
			id: actionId, kind: 'handlers', ordinal: 2, launches: [{shape: 'OrderSyncNotified', count: 1}], expected: {runs: 2, byStatus: {Completed: 2, Failed: 0}},
			retryCandidates: 0, restartCandidates: 0
		};
		const clone = cloneSmallAction({exemplar: {action, rows, entries: []}, runToken: TOKEN, toOrdinal: 20, timeShiftMilliseconds: -MINUTE});
		const expectedAction = {id: mintVolumeId(KINDS.action, TOKEN, 21, 0, 0), kind: 'handlers', ordinal: 20, synthesized: true, clonedFrom: actionId, expected: {runs: 2}};
		expect(clone.action).toMatchObject(expectedAction);
		expect(clone.chainRows[0].CorrelationId__c).toBe(mintVolumeId(KINDS.smallActionRun, TOKEN, 21, 0, 0));
		expect(clone.chainRows[1].CorrelationId__c).toBe(mintVolumeId(KINDS.smallActionRun, TOKEN, 21, ENGINE_MINTED_SECOND, 0));
		expect(clone.chainRows[1].LaunchCorrelationId__c).toBe(clone.chainRows[0].CorrelationId__c);
		expect(clone.chainRows.every((row) => row.RootCorrelationId__c === clone.action.id)).toBe(true);
	});

	it('marks an engine-minted child with a second segment no launch index of any kind can reach', () =>
	{
		// The eight rejects of 2026-09-24: with the marker at 3, a cloned nested child collided with the clone's own launch index 3.
		const widestKind = Math.max(...SMALL_ACTION_KINDS.map((kind) => kind.launches.reduce((sum, launch) => sum + launch.count, 0)));
		expect(ENGINE_MINTED_SECOND).toBeGreaterThan(widestKind);
		expect(mintVolumeId(KINDS.smallActionRun, TOKEN, 21, ENGINE_MINTED_SECOND, 0)).toBe('abcdefab-cccc-aadd-ffff-aaaaaaaaaaaa');
	});

	it('buildIdMap names every harness id and engine id it will replace', () =>
	{
		const engineMinted = 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d';
		const row = {
			CorrelationId__c: mintVolumeId(KINDS.smallActionRun, TOKEN, 3, 1, 0), LaunchCorrelationId__c: engineMinted,
			RootCorrelationId__c: mintVolumeId(KINDS.action, TOKEN, 3, 0, 0)
		};
		const map = buildIdMap([row], [], {runToken: TOKEN, first: 21});
		expect(map.get(mintVolumeId(KINDS.smallActionRun, TOKEN, 3, 1, 0))).toBe(mintVolumeId(KINDS.smallActionRun, TOKEN, 21, 1, 0));
		expect(map.get(mintVolumeId(KINDS.action, TOKEN, 3, 0, 0))).toBe(mintVolumeId(KINDS.action, TOKEN, 21, 0, 0));
		expect(map.get(engineMinted)).toBe(mintVolumeId(KINDS.smallActionRun, TOKEN, 21, ENGINE_MINTED_SECOND, 0));
	});
});

describe('the CSV', () =>
{
	it('quotes fields with commas, quotes and newlines and prefixes the custom columns', () =>
	{
		expect(escapeCsvField('a,"b"\nc')).toBe('"a,""b""\nc"');
		const row = {
			ChainName__c: 'X', Status__c: 'Completed', CorrelationId__c: 'c', LaunchCorrelationId__c: 'l', RootCorrelationId__c: 'r', CurrentStepName__c: '', TotalSteps__c: 5,
			CompletedSteps__c: 5, StartedAt__c: '2026-09-24T12:00:00.000Z', CompletedAt__c: '2026-09-24T12:00:05.000Z', DurationMs__c: 5000, StepLog__c: '[]', ContextData__c: '{}',
			InitialContextData__c: '{}', FailureCategory__c: '', ErrorMessage__c: '', AllowRestart__c: false, CreatedDate: '2026-09-24T12:00:00.000Z',
			LastModifiedDate: '2026-09-24T12:00:05.000Z'
		};
		const csv = renderChainCsv([row], 'acme__');
		const header = 'acme__ChainName__c,acme__Status__c,acme__CorrelationId__c,acme__LaunchCorrelationId__c,acme__RootCorrelationId__c,acme__CurrentStepName__c,'
				+ 'acme__TotalSteps__c,acme__CompletedSteps__c,acme__StartedAt__c,acme__CompletedAt__c,acme__DurationMs__c,acme__StepLog__c,acme__ContextData__c,'
				+ 'acme__InitialContextData__c,acme__FailureCategory__c,acme__ErrorMessage__c,acme__AllowRestart__c,CreatedDate,LastModifiedDate';
		expect(csv.split('\n')[0]).toBe(header);
		expect(chunk([1, 2, 3], 2)).toEqual([[1, 2], [3]]);
	});
});

describe('synthesize', () =>
{
	it('an import with failed rows leaves the stage undone and names the job id', async() =>
	{
		const outputDirectory = fs.mkdtempSync(path.join(os.tmpdir(), 'synth-'));
		// Two roots, one from the engine; every small action from the engine, so only the root clone is written.
		const shape = {...scaleShape('staged', 0.25), smallActions: {count: 12, engineCount: 12, perBatch: 7}};
		shape.expected.smallActions = planSmallActions(12);
		const org = {alias: 'Dev', namespacePrefix: '', userId: '005'};
		const manifest = createManifest({mode: 'staged', size: 0.25, runToken: TOKEN, org, startedAt: '2026-09-24T12:00:00.000Z', shape});
		manifest.actions.push({id: ACTION, kind: 'reconciliation', ordinal: 0, engineRoots: 1, roots: 2, expected: shape.expected.reconciliation});
		const exemplar = exemplarTree();
		const salesforce = {
			query: jest.fn((soql) => ({records: soql.includes('LogEntry__c') ? exemplar.entries : exemplar.rows, totalSize: 0})),
			importCsv: jest.fn(() => ({jobId: '750x', processed: 10, succeeded: 8, failed: 2, completed: true}))
		};
		const result = await synthesize({options: {outputDirectory}, salesforce, shape, manifest, log: () => {}});
		expect(result.stages.launch).toMatchObject({ok: false});
		expect(result.stages.launch.reason).toContain('750x');
		expect(result.synthesized.chainRows).toBe(7);
		fs.rmSync(outputDirectory, {recursive: true, force: true});
	});

	it('keeps the synthesized Stalled rows already on record, of both kinds, when it records the clones', async() =>
	{
		const outputDirectory = fs.mkdtempSync(path.join(os.tmpdir(), 'synth-'));
		const shape = {...scaleShape('staged', 0.25), smallActions: {count: 12, engineCount: 12, perBatch: 7}};
		shape.expected.smallActions = planSmallActions(12);
		const org = {alias: 'Dev', namespacePrefix: '', userId: '005'};
		const manifest = createManifest({mode: 'staged', size: 0.25, runToken: TOKEN, org, startedAt: '2026-09-24T12:00:00.000Z', shape});
		manifest.actions.push({id: ACTION, kind: 'reconciliation', ordinal: 0, engineRoots: 1, roots: 2, expected: shape.expected.reconciliation});
		manifest.synthesized.stalledRows = ['fixture1'];
		manifest.synthesized.startedStepRows = ['started1', 'started2'];
		const exemplar = exemplarTree();
		const salesforce = {
			query: jest.fn((soql) => ({records: soql.includes('LogEntry__c') ? exemplar.entries : exemplar.rows, totalSize: 0})),
			importCsv: jest.fn(() => ({jobId: '750y', processed: 7, succeeded: 7, failed: 0, completed: true}))
		};
		const result = await synthesize({options: {outputDirectory}, salesforce, shape, manifest, log: () => {}});
		expect(result.synthesized).toMatchObject({stalledRows: ['fixture1'], startedStepRows: ['started1', 'started2']});
		fs.rmSync(outputDirectory, {recursive: true, force: true});
	});
});
