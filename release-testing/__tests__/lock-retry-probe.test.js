// SPDX-License-Identifier: Apache-2.0
/**
 * @description The lock-retry probe drives a real org, so nothing here lets it: the CLI and the file system are
 * both mocked. The tests pin what the probe reads from its command line, which script it hands the org, and the
 * query it uses to find the warning the retried commit wrote.
 */
jest.mock('child_process', () => ({execFileSync: jest.fn()}));
jest.mock('fs');

const fs = require('fs');
const {execFileSync} = require('child_process');
const {parseArguments, runJson, waitForHolderToRun, prepareCallerScript, readLatestRetryWarning} = require('../runner/lock-retry-probe');

// Taken the moment the module finished loading: the probe must not have started against an org merely by being required.
const CLI_CALLS_AT_LOAD = execFileSync.mock.calls.length;

const ORG = 'SubscriberOrg';

// The whole query, so a reformat that drops a filter or the ordering is caught rather than tolerated.
const NAMESPACED_WARNING_QUERY = 'SELECT kern__ContextData__c FROM kern__LogEntry__c'
		+ ' WHERE kern__LogLevel__c = \'WARN\' AND kern__ClassMethod__c LIKE \'%DML_Transaction.commitWork\''
		+ ' ORDER BY CreatedDate DESC LIMIT 1';
const UNMANAGED_WARNING_QUERY = 'SELECT ContextData__c FROM LogEntry__c'
	+ ' WHERE LogLevel__c = \'WARN\' AND ClassMethod__c LIKE \'%DML_Transaction.commitWork\''
		+ ' ORDER BY CreatedDate DESC LIMIT 1';
const HOLDER_JOB_QUERY = 'SELECT Status FROM AsyncApexJob'
	+ ' WHERE ApexClass.Name = \'LockRetryProbeHolder\''
	+ ' ORDER BY CreatedDate DESC LIMIT 1';

function cliAnswers(records)
{
	execFileSync.mockReturnValue(JSON.stringify({status: 0, result: {records}}));
}

describe('loading the module', () =>
{
	it('does not run the probe, so the tool can be required without an org', () =>
	{
		expect(CLI_CALLS_AT_LOAD).toBe(0);
	});
});

describe('parseArguments', () =>
{
	const realArguments = process.argv;

	beforeEach(() =>
	{
		jest.spyOn(console, 'error').mockImplementation(() => undefined);
		jest.spyOn(process, 'exit').mockImplementation(() => undefined);
	});

	afterEach(() =>
	{
		process.argv = realArguments;
		jest.restoreAllMocks();
	});

	it('reads the org alias, and reports a namespaced org when the no-namespace flag is absent', () =>
	{
		process.argv = [
			'node',
			'lock-retry-probe.js',
			'--org',
			ORG
		];

		expect(parseArguments()).toEqual({org: ORG, noNamespace: false});
	});

	it('reports an unmanaged deploy when the no-namespace flag is there', () =>
	{
		process.argv = [
			'node',
			'lock-retry-probe.js',
			'--org',
			ORG,
			'--no-namespace'
		];

		expect(parseArguments()).toEqual({org: ORG, noNamespace: true});
	});

	it('prints how to call it and ends the run when no org is named', () =>
	{
		process.argv = [
			'node',
			'lock-retry-probe.js',
			'--no-namespace'
		];

		parseArguments();

		expect(console.error).toHaveBeenCalledWith('Usage: node release-testing/runner/lock-retry-probe.js --org <alias> [--no-namespace]');
		expect(process.exit).toHaveBeenCalledWith(1);
	});
});

describe('runJson', () =>
{
	beforeEach(() =>
	{
		jest.resetAllMocks();
	});

	it('reports output it cannot read as a failure that carries the start of that output', () =>
	{
		execFileSync.mockReturnValue('sf: command not found');

		const result = runJson([
			'data',
			'query'
		]);

		expect(result.status).toBe(1);
		expect(result.message).toContain('Unparseable CLI output');
		expect(result.message).toContain('sf: command not found');
	});
});

describe('waitForHolderToRun', () =>
{
	beforeEach(() =>
	{
		jest.resetAllMocks();
	});

	it('asks the org for the holder job and returns once it is running', () =>
	{
		cliAnswers([{Status: 'Processing'}]);

		expect(waitForHolderToRun(ORG)).toBe(true);
		expect(execFileSync).toHaveBeenCalledTimes(1);
		expect(execFileSync.mock.calls[0][1]).toContain(HOLDER_JOB_QUERY);
	});
});

describe('prepareCallerScript', () =>
{
	beforeEach(() =>
	{
		jest.resetAllMocks();
	});

	it('hands a namespaced org the shipped script untouched', () =>
	{
		expect(prepareCallerScript(false)).toMatch(/scripts[/\\]lock-retry-caller\.apex$/);
		expect(fs.writeFileSync).not.toHaveBeenCalled();
	});

	it('writes a copy without the kern prefix for an unmanaged deploy', () =>
	{
		fs.readFileSync.mockReturnValue('kern.DML_Builder.newInstance().withRetryOnLock(2);');

		const scriptPath = prepareCallerScript(true);

		expect(scriptPath).toMatch(/tmp[/\\]lock-retry-caller\.apex$/);
		expect(fs.writeFileSync).toHaveBeenCalledWith(scriptPath, 'DML_Builder.newInstance().withRetryOnLock(2);');
	});
});

describe('readLatestRetryWarning', () =>
{
	beforeEach(() =>
	{
		jest.resetAllMocks();
	});

	it('asks a namespaced org for the packaged fields and returns the context of the newest warning', () =>
	{
		cliAnswers([{kern__ContextData__c: '{"retriesUsed":2}'}]);

		expect(readLatestRetryWarning(ORG, false)).toBe('{"retriesUsed":2}');
		expect(execFileSync.mock.calls[0][1]).toContain(NAMESPACED_WARNING_QUERY);
	});

	it('asks an unmanaged deploy for the same fields without the prefix', () =>
	{
		cliAnswers([{ContextData__c: '{"retriesUsed":2}'}]);

		expect(readLatestRetryWarning(ORG, true)).toBe('{"retriesUsed":2}');
		expect(execFileSync.mock.calls[0][1]).toContain(UNMANAGED_WARNING_QUERY);
	});

	it('returns nothing when the org holds no such warning', () =>
	{
		cliAnswers([]);

		expect(readLatestRetryWarning(ORG, false)).toBe('');
	});
});
