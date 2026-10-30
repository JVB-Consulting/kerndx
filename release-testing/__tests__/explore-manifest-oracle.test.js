// SPDX-License-Identifier: Apache-2.0
const mockSoql = jest.fn();
jest.mock('../e2e/helpers/sf-cli', () => ({soqlQuery: (...args) => mockSoql(...args), runApexScript: jest.fn(), executeAnonymousApex: jest.fn()}));
const soql = mockSoql;
jest.mock('../e2e/helpers/sf-namespace', () => ({namespacePrefix: () => 'kern__', apexNamespacePrefix: () => 'kern.', fillNamespaceTokens: (source) => source}));
const fs = require('fs');
const os = require('os');
const path = require('path');
const {readManifestOracle, countRuns, countEntries, runKeys, sortValuesByKey, entryKeys, runsSpan, findRun} = require('../e2e/explore/manifest-oracle');

describe('the manifest oracle', () =>
{
	beforeEach(() => soql.mockReset());

	it('reads the manifest and asks the database at check time', () =>
	{
		const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'oracle-'));
		const manifestPath = path.join(directory, 'manifest.json');
		fs.writeFileSync(manifestPath, JSON.stringify({
			runToken: 'abcdefab',
			actions: [
				{
					id: 'act', kind: 'reconciliation', synthesized: false,
					chainNames: ['Volume_Reconciliation', 'Volume_RegionReconcile', 'Volume_LedgerReconcile', 'Volume_AccountReconcile']
				},
				{id: 'small', kind: 'orders', synthesized: false}
			],
			operatorWave: {restarts: [{executionId: 's1'}]}
		}));
		const oracle = readManifestOracle(manifestPath);
		expect(oracle.reconciliation.id).toBe('act');
		expect(oracle.searchableAction.id).toBe('small');
		expect(oracle.runToken).toBe('abcdefab');
		soql.mockReturnValueOnce([{expr0: 42}]);
		expect(countRuns({actionId: 'act', statuses: ['Failed']})).toBe(42);
		expect(soql.mock.calls[0][0]).toBe('SELECT COUNT(Id) FROM kern__AsyncChainExecution__c WHERE kern__RootCorrelationId__c = \'act\' AND kern__Status__c IN (\'Failed\')');
		soql.mockReturnValueOnce([{expr0: 5}]);
		expect(countRuns({nameContains: 'Volume_AccountReconcile'})).toBe(5);
		expect(soql.mock.calls[1][0]).toContain('kern__ChainName__c LIKE \'%Volume\\_AccountReconcile%\'');
		soql.mockReset();
		soql.mockReturnValueOnce([{Id: 'a03002'}, {Id: 'a03001'}]);
		expect(runKeys({sortField: 'StartedAt__c', sortDescending: true})).toEqual(['a03002', 'a03001']);
		expect(soql.mock.calls[0][0]).toContain('ORDER BY kern__StartedAt__c DESC, Name DESC');
		soql.mockReturnValueOnce([{kern__CorrelationId__c: 'leaf-id'}]);
		expect(oracle.runByDepth(3)).toBe('leaf-id');
		expect(soql.mock.calls[1][0]).toContain('kern__ChainName__c = \'Volume_AccountReconcile\'');
		soql.mockReturnValueOnce([{kern__CorrelationId__c: 'clone-id', kern__SourceExecution__c: 'a03source'}]);
		expect(oracle.restartClone()).toEqual({correlationId: 'clone-id', sourceExecutionId: 'a03source'});
		expect(soql.mock.calls[2][0]).toContain('LIKE \'abcdefab-%\'');
		fs.rmSync(directory, {recursive: true, force: true});
	});

	it('keys the runs under a token whose names contain a fragment, the underscore escaped', () =>
	{
		soql.mockReturnValueOnce([{Id: 'a03001'}]);
		expect(runKeys({token: 'abcdefab', nameContains: 'Volume_', sortField: 'StartedAt__c', sortDescending: false})).toEqual(['a03001']);
		expect(soql.mock.calls[0][0]).toBe('SELECT Id FROM kern__AsyncChainExecution__c WHERE kern__RootCorrelationId__c LIKE \'abcdefab-%\''
				+ ' AND kern__ChainName__c LIKE \'%Volume\\_%\' ORDER BY kern__StartedAt__c ASC, Name ASC');
	});

	it('counts entries narrowed by the pins, the levels, the origins and the window', () =>
	{
		soql.mockReturnValueOnce([{expr0: 7}]);
		expect(countEntries({actionId: 'act', levels: ['ERROR', 'WARN'], origins: ['APEX'], windowStart: Date.UTC(2026, 8, 24), windowEnd: Date.UTC(2026, 8, 25)})).toBe(7);
		expect(soql.mock.calls[0][0]).toBe('SELECT COUNT(Id) FROM kern__LogEntry__c WHERE (kern__RootCorrelationId__c = \'act\' OR kern__CorrelationId__c = \'act\')'
				+ ' AND kern__OccurrenceCount__c = null AND kern__LogLevel__c IN (\'ERROR\', \'WARN\') AND kern__Origin__c IN (\'APEX\')'
				+ ' AND CreatedDate >= 2026-09-24T00:00:00.000Z AND CreatedDate <= 2026-09-25T00:00:00.000Z');
		soql.mockReturnValueOnce([{expr0: 2}]);
		expect(countEntries({chainId: 'run', rolledUp: true})).toBe(2);
		expect(soql.mock.calls[1][0]).toBe('SELECT COUNT(Id) FROM kern__LogEntry__c WHERE kern__CorrelationId__c = \'run\' AND kern__OccurrenceCount__c != null');
	});

	it('counts entries by the start of their message, lists entry keys in the console\'s order, reads the runs\' span and finds a run with its id', () =>
	{
		soql.mockReturnValueOnce([{expr0: 3}]);
		expect(countEntries({actionId: 'act', messageStartsWith: 'Validated account batch'})).toBe(3);
		expect(soql.mock.calls[0][0]).toContain('kern__ShortMessage__c LIKE \'Validated account batch%\'');
		soql.mockReturnValueOnce([{Id: 'a0B002'}, {Id: 'a0B001'}]);
		expect(entryKeys({actionId: 'act', levels: ['ERROR']})).toEqual(['a0B002', 'a0B001']);
		expect(soql.mock.calls[1][0]).toBe('SELECT Id FROM kern__LogEntry__c WHERE (kern__RootCorrelationId__c = \'act\' OR kern__CorrelationId__c = \'act\')'
				+ ' AND kern__OccurrenceCount__c = null AND kern__LogLevel__c IN (\'ERROR\') ORDER BY CreatedDate DESC, Name DESC');
		soql.mockReturnValueOnce([{expr0: '2026-09-24T22:03:00.000+0000', expr1: '2026-09-24T22:40:00.000+0000'}]);
		expect(runsSpan('act')).toEqual({first: '2026-09-24T22:03:00.000+0000', last: '2026-09-24T22:40:00.000+0000'});
		expect(soql.mock.calls[2][0])
		.toBe('SELECT MIN(kern__StartedAt__c), MAX(kern__CompletedAt__c) FROM kern__AsyncChainExecution__c WHERE kern__RootCorrelationId__c = \'act\'');
		soql.mockReturnValueOnce([{Id: 'a03x', Name: 'CHAIN-7', kern__CorrelationId__c: 'run-7', kern__TotalSteps__c: 10, kern__AllowRestart__c: true}]);
		expect(findRun({token: 'abcdefab', statuses: ['Failed']})).toEqual({id: 'a03x', name: 'CHAIN-7', correlationId: 'run-7', totalSteps: 10, allowRestart: true});
		expect(soql.mock.calls[3][0]).toContain('SELECT Id, Name, kern__CorrelationId__c, kern__TotalSteps__c, kern__AllowRestart__c FROM');
		soql.mockReturnValueOnce([]);
		expect(findRun({token: 'abcdefab', statuses: ['Stalled']})).toBeNull();
	});

	it('reads the sort value of every listed row so a screen order can be checked with ties allowed', () =>
	{
		soql.mockReturnValueOnce([{Id: 'a', kern__StartedAt__c: '2026-09-24T10:00:00.000Z'}, {Id: 'b', kern__StartedAt__c: '2026-09-24T11:00:00.000Z'}]);
		const values = sortValuesByKey('StartedAt__c', ['a', 'b']);
		expect(values.get('a')).toBe('2026-09-24T10:00:00.000Z');
		expect(soql.mock.calls[0][0]).toBe('SELECT Id, kern__StartedAt__c FROM kern__AsyncChainExecution__c WHERE Id IN (\'a\', \'b\')');
	});
});
