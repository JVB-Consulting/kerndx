// SPDX-License-Identifier: BUSL-1.1
jest.mock('child_process', () => ({
	execSync: jest.fn(), exec: jest.fn()
}));

jest.mock('../../release-testing/e2e/helpers/sf-auth', () => ({
	ORG_ALIAS: 'TestOrg'
}));

const {execSync, exec} = require('child_process');
const {parseApexOutput, runApexScript, runApexScriptAsync, soqlQuery, createRecord, deleteRecord, deployMetadata, runTests, executeAnonymousApex} = require(
		'../e2e/helpers/sf-cli');

describe('parseApexOutput', () =>
{
	it('should count PASS results from USER_DEBUG lines', () =>
	{
		const output = [
			'USER_DEBUG [5]|DEBUG|1a PASS: trigger fires on insert',
			'USER_DEBUG [10]|DEBUG|1b PASS: handler runs',
			'USER_DEBUG [15]|DEBUG|1c PASS: defaults set'
		].join('\n');

		const result = parseApexOutput(output);
		expect(result.pass).toBe(3);
		expect(result.fail).toBe(0);
		expect(result.total).toBe(3);
		expect(result.results).toHaveLength(3);
	});

	it('should count FAIL results', () =>
	{
		const output = [
			'USER_DEBUG [5]|DEBUG|1a PASS: trigger fires',
			'USER_DEBUG [10]|DEBUG|1b FAIL: handler did not run'
		].join('\n');

		const result = parseApexOutput(output);
		expect(result.pass).toBe(1);
		expect(result.fail).toBe(1);
		expect(result.total).toBe(2);
	});

	it('should handle empty output', () =>
	{
		const result = parseApexOutput('');
		expect(result.pass).toBe(0);
		expect(result.fail).toBe(0);
		expect(result.total).toBe(0);
		expect(result.results).toHaveLength(0);
	});

	it('should ignore non-USER_DEBUG lines', () =>
	{
		const output = [
			'Execute Anonymous: System.debug("test");',
			'USER_DEBUG [5]|DEBUG|1a PASS: works',
			'Some other log line with PASS in it',
			'DEBUG LOG --- stuff ---'
		].join('\n');

		const result = parseApexOutput(output);
		expect(result.pass).toBe(1);
		expect(result.total).toBe(1);
	});

	it('should preserve raw output', () =>
	{
		const output = 'USER_DEBUG [1]|DEBUG|1a PASS: test';
		const result = parseApexOutput(output);
		expect(result.raw).toBe(output);
	});

	it('should parse results with varying line formats', () =>
	{
		const output = [
			'07:30:00.5 (12345)|USER_DEBUG [5]|DEBUG|1a PASS: trigger lifecycle',
			'07:30:01.2 (23456)|USER_DEBUG [10|5]|DEBUG|1b FAIL: bypass not applied'
		].join('\n');

		const result = parseApexOutput(output);
		expect(result.pass).toBe(1);
		expect(result.fail).toBe(1);
	});

	it('should set pass and fail flags on individual results', () =>
	{
		const output = 'USER_DEBUG [5]|DEBUG|1a PASS: works';
		const result = parseApexOutput(output);
		expect(result.results[0].pass).toBe(true);
		expect(result.results[0].fail).toBe(false);
		expect(result.results[0].message).toBe('1a PASS: works');
	});
});

describe('runApexScript', () =>
{
	it('should call execSync with correct command', () =>
	{
		execSync.mockReturnValue('USER_DEBUG [5]|DEBUG|1a PASS: test');
		const result = runApexScript('/path/to/script.apex');

		expect(execSync).toHaveBeenCalledWith('sf apex run -o TestOrg -f /path/to/script.apex 2>&1', expect.objectContaining({encoding: 'utf8'}));
		expect(result.pass).toBe(1);
	});

	it('should use custom timeout', () =>
	{
		execSync.mockReturnValue('');
		runApexScript('/path/to/script.apex', {timeout: 60_000});

		expect(execSync).toHaveBeenCalledWith(expect.any(String), expect.objectContaining({timeout: 60_000}));
	});
});

describe('runApexScriptAsync', () =>
{
	it('should resolve with parsed output on success', async() =>
	{
		exec.mockImplementation((cmd, opts, callback) =>
		{
			callback(null, 'USER_DEBUG [5]|DEBUG|1a PASS: async test');
		});

		const result = await runApexScriptAsync('/path/to/script.apex');
		expect(result.pass).toBe(1);
	});

	it('should resolve with parsed output when error has stdout', async() =>
	{
		exec.mockImplementation((cmd, opts, callback) =>
		{
			callback(new Error('non-zero exit'), 'USER_DEBUG [5]|DEBUG|1a FAIL: something broke');
		});

		const result = await runApexScriptAsync('/path/to/script.apex');
		expect(result.fail).toBe(1);
	});

	it('should reject when error has no stdout', async() =>
	{
		exec.mockImplementation((cmd, opts, callback) =>
		{
			callback(new Error('connection failed'), '');
		});

		await expect(runApexScriptAsync('/path/to/script.apex')).rejects.toThrow('connection failed');
	});
});

describe('soqlQuery', () =>
{
	it('should return records from JSON output', () =>
	{
		execSync.mockReturnValue(JSON.stringify({result: {records: [{Id: '001xx'}]}}));
		const records = soqlQuery('SELECT Id FROM Account');

		expect(records).toEqual([{Id: '001xx'}]);
		expect(execSync).toHaveBeenCalledWith(expect.stringContaining('sf data query -o TestOrg'), expect.any(Object));
	});

	it('should return empty array when no records', () =>
	{
		execSync.mockReturnValue(JSON.stringify({result: {}}));
		const records = soqlQuery('SELECT Id FROM Account');
		expect(records).toEqual([]);
	});

	it('should include tooling flag when specified', () =>
	{
		execSync.mockReturnValue(JSON.stringify({result: {records: []}}));
		soqlQuery('SELECT Id FROM ApexClass', {tooling: true});

		expect(execSync).toHaveBeenCalledWith(expect.stringContaining('-t'), expect.any(Object));
	});
});

describe('createRecord', () =>
{
	it('should build values string from object', () =>
	{
		execSync.mockReturnValue(JSON.stringify({result: {id: '001xx'}}));
		const result = createRecord('Account', {Name: 'Test', Industry: 'Tech'});

		expect(execSync).toHaveBeenCalledWith(expect.stringContaining('Name="Test" Industry="Tech"'), expect.any(Object));
		expect(result.id).toBe('001xx');
	});
});

describe('deleteRecord', () =>
{
	it('should call delete with correct parameters', () =>
	{
		execSync.mockReturnValue('');
		deleteRecord('Account', '001xx');

		expect(execSync).toHaveBeenCalledWith(expect.stringContaining('sf data delete record -o TestOrg -s Account -i 001xx'), expect.any(Object));
	});
});

describe('deployMetadata', () =>
{
	it('should call deploy with correct path', () =>
	{
		execSync.mockReturnValue(JSON.stringify({status: 0}));
		const result = deployMetadata('/path/to/metadata');

		expect(execSync).toHaveBeenCalledWith(expect.stringContaining('-d "/path/to/metadata"'), expect.any(Object));
		expect(result.status).toBe(0);
	});
});

describe('runTests', () =>
{
	it('should use RunLocalTests by default', () =>
	{
		execSync.mockReturnValue(JSON.stringify({result: {summary: {outcome: 'Passed'}}}));
		runTests();

		expect(execSync).toHaveBeenCalledWith(expect.stringContaining('--test-level RunLocalTests'), expect.any(Object));
	});

	it('should accept custom test level', () =>
	{
		execSync.mockReturnValue(JSON.stringify({result: {summary: {}}}));
		runTests({testLevel: 'RunSpecifiedTests'});

		expect(execSync).toHaveBeenCalledWith(expect.stringContaining('--test-level RunSpecifiedTests'), expect.any(Object));
	});
});

describe('executeAnonymousApex', () =>
{
	it('should write apex to temp file and clean up', () =>
	{
		const fs = require('fs');
		jest.spyOn(fs, 'writeFileSync').mockImplementation(() =>
		{
		});
		jest.spyOn(fs, 'unlinkSync').mockImplementation(() =>
		{
		});
		execSync.mockReturnValue('success');

		const result = executeAnonymousApex('System.debug("hello");');
		expect(result).toBe('success');
		expect(fs.writeFileSync).toHaveBeenCalledWith(expect.stringContaining('/tmp/kern-e2e-'), 'System.debug("hello");', 'utf8');
		expect(fs.unlinkSync).toHaveBeenCalled();

		fs.writeFileSync.mockRestore();
		fs.unlinkSync.mockRestore();
	});

	it('should clean up temp file even on error', () =>
	{
		const fs = require('fs');
		jest.spyOn(fs, 'writeFileSync').mockImplementation(() =>
		{
		});
		jest.spyOn(fs, 'unlinkSync').mockImplementation(() =>
		{
		});
		execSync.mockImplementation(() =>
		{
			throw new Error('apex error');
		});

		expect(() => executeAnonymousApex('bad code')).toThrow('apex error');
		expect(fs.unlinkSync).toHaveBeenCalled();

		fs.writeFileSync.mockRestore();
		fs.unlinkSync.mockRestore();
	});
});
