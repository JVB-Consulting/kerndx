// SPDX-License-Identifier: Apache-2.0
jest.mock('child_process', () => ({
	execSync: jest.fn(), exec: jest.fn()
}));

jest.mock('../../release-testing/e2e/helpers/sf-auth', () => ({
	ORG_ALIAS: 'TestOrg'
}));

jest.mock('../e2e/helpers/sf-namespace', () => ({
	namespacePrefix: jest.fn(() => 'kern__'), apexNamespacePrefix: () => 'kern.', prepareApexForOrg: (source) => source
}));

const fs = require('fs');
const os = require('os');
const path = require('path');

const {execSync, exec} = require('child_process');
const {namespacePrefix} = require('../e2e/helpers/sf-namespace');
const {
	parseApexOutput, runApexScript, runApexScriptAsync, soqlQuery, createRecord, deleteRecord, deployMetadata, runTests, executeAnonymousApex, waitForFrameworkBatchesToFinish
} = require('../e2e/helpers/sf-cli');

describe('parseApexOutput', () =>
{
	it('counts the lines as the current CLI prints them, with a pipe before the line number', () =>
	{
		const output = [
			'Execute Anonymous: System.debug(\'79a PASS: scheduled\');',
			'13:55:10.23 (24276646)|USER_DEBUG|[61]|DEBUG|79a PASS: watchdog scheduled via the platform scheduler',
			'13:55:10.24 (24276700)|USER_DEBUG|[66]|DEBUG|79a FAIL: System.schedule returned no job id'
		].join('\n');

		const result = parseApexOutput(output);
		expect(result).toMatchObject({pass: 1, fail: 1, total: 2});
		expect(result.results[0].message).toBe('79a PASS: watchdog scheduled via the platform scheduler');
	});

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

// A script on disk, so the runners can copy it for the org; removed after each test.
function withScriptOnDisk(run)
{
	const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'sf-cli-test-'));
	const scriptPath = path.join(directory, 'script.apex');
	fs.writeFileSync(scriptPath, 'System.debug(kern.UTIL_System.getNamespacePrefix());', 'utf8');
	try
	{
		return run(scriptPath);
	}
	finally
	{
		fs.rmSync(directory, {recursive: true, force: true});
	}
}

// The path the runner handed to `sf`: the copy written for the org, keeping the script's base name.
function scriptPathRun(commandLine)
{
	return commandLine.match(/-f "([^"]+)"/)[1];
}

describe('runApexScript', () =>
{
	it('runs a copy of the script written for the org, keeping its base name, and removes the copy', () =>
	{
		execSync.mockReturnValue('USER_DEBUG [5]|DEBUG|1a PASS: test');
		const result = withScriptOnDisk((scriptPath) => runApexScript(scriptPath));

		expect(execSync).toHaveBeenCalledWith(expect.stringMatching(/^sf apex run -o TestOrg -f ".*[\\/]apex-for-org-[^\\/]+[\\/]script\.apex" 2>&1$/),
				expect.objectContaining({encoding: 'utf8'}));
		expect(fs.existsSync(scriptPathRun(execSync.mock.calls[0][0]))).toBe(false);
		expect(result.pass).toBe(1);
	});

	it('runs the script itself when the rewrite is switched off', () =>
	{
		execSync.mockReturnValue('USER_DEBUG [5]|DEBUG|1a PASS: test');
		runApexScript('/path/to/script.apex', {rewriteNamespace: false});

		expect(execSync).toHaveBeenCalledWith('sf apex run -o TestOrg -f "/path/to/script.apex" 2>&1', expect.objectContaining({encoding: 'utf8'}));
	});

	it('should use custom timeout', () =>
	{
		execSync.mockReturnValue('');
		runApexScript('/path/to/script.apex', {timeout: 60_000, rewriteNamespace: false});

		expect(execSync).toHaveBeenCalledWith(expect.any(String), expect.objectContaining({timeout: 60_000}));
	});

	describe('when the command fails', () =>
	{
		beforeEach(() =>
		{
			execSync.mockReset();
		});

		afterEach(() =>
		{
			execSync.mockReset();
		});

		// What execSync throws when the command exits non-zero: its message names only the command; the reason is on stdout.
		function commandFailure(stdout)
		{
			const error = new Error('Command failed: sf apex run -o TestOrg -f "/path/to/seed.apex" 2>&1');
			error.stdout = stdout;
			return error;
		}

		it('puts the compile error the command line printed into the thrown error, naming the script and the org', () =>
		{
			const tooLarge = commandFailure('Error (1): Compilation failed at Line 1 column 1 with the error:\nScript too large: // SPDX-License-Identifier: Apache-2.0\n');
			execSync.mockImplementation(() =>
			{
				throw tooLarge;
			});

			let thrown = null;
			try
			{
				runApexScript('/path/to/seed.apex', {rewriteNamespace: false});
			}
			catch(error)
			{
				thrown = error;
			}

			expect(thrown).toBeInstanceOf(Error);
			expect(thrown.message).toContain('sf apex run failed for seed.apex on TestOrg');
			expect(thrown.message).toContain('Compilation failed at Line 1 column 1');
			expect(thrown.message).toContain('Script too large');
			expect(thrown.cause).toBe(tooLarge);
			expect(thrown.stdout).toBe(tooLarge.stdout);
		});

		it('shows the exception line, not the script lines the debug log echoes', () =>
		{
			execSync.mockImplementation(() =>
			{
				throw commandFailure([
					'Compiled successfully.',
					'Error (1): System.DmlException: Insert failed. First exception on row 0; first error: DUPLICATE_VALUE',
					'Execute Anonymous: specs.add(new Map<String, Object>{\'LogLevel__c\' => \'ERROR\'});',
					'12:00:00.1 (100)|EXCEPTION_THROWN|[266]|System.DmlException: Insert failed.'
				].join('\n'));
			});

			const onlyTheExceptionLine = /sf apex run failed for seed\.apex on TestOrg:\nError \(1\): System\.DmlException[^\n]*$/;
			expect(() => runApexScript('/path/to/seed.apex', {rewriteNamespace: false})).toThrow(onlyTheExceptionLine);
		});

		it('shows the first lines of the output when none of them names a reason', () =>
		{
			execSync.mockImplementation(() =>
			{
				throw commandFailure('The org could not be reached.\n');
			});

			expect(() => runApexScript('/path/to/seed.apex', {rewriteNamespace: false})).toThrow('The org could not be reached.');
		});

		it('keeps the command\'s own message when it printed nothing', () =>
		{
			execSync.mockImplementation(() =>
			{
				throw commandFailure(undefined);
			});

			expect(() => runApexScript('/path/to/seed.apex', {rewriteNamespace: false})).toThrow('Command failed: sf apex run');
		});

		it('removes the org\'s copy of the script when the run fails', () =>
		{
			execSync.mockImplementation(() =>
			{
				throw commandFailure('Error (1): Compilation failed');
			});

			expect(() => withScriptOnDisk((scriptPath) => runApexScript(scriptPath))).toThrow('Compilation failed');
			expect(fs.existsSync(scriptPathRun(execSync.mock.calls[0][0]))).toBe(false);
		});
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

		const result = await runApexScriptAsync('/path/to/script.apex', {rewriteNamespace: false});
		expect(result.pass).toBe(1);
		expect(exec).toHaveBeenCalledWith('sf apex run -o TestOrg -f "/path/to/script.apex" 2>&1', expect.objectContaining({encoding: 'utf8'}), expect.any(Function));
	});

	it('runs a copy written for the org and removes it once the command has answered', async() =>
	{
		exec.mockImplementation((cmd, opts, callback) =>
		{
			expect(fs.existsSync(scriptPathRun(cmd))).toBe(true);
			callback(null, 'USER_DEBUG [5]|DEBUG|1a PASS: async test');
		});

		const result = await withScriptOnDisk((scriptPath) => runApexScriptAsync(scriptPath));
		expect(result.pass).toBe(1);
		expect(exec).toHaveBeenCalledWith(expect.stringMatching(/-f ".*[\\/]apex-for-org-[^\\/]+[\\/]script\.apex" 2>&1$/), expect.any(Object), expect.any(Function));
		expect(fs.existsSync(scriptPathRun(exec.mock.calls[0][0]))).toBe(false);
	});

	it('should resolve with parsed output when error has stdout', async() =>
	{
		exec.mockImplementation((cmd, opts, callback) =>
		{
			callback(new Error('non-zero exit'), 'USER_DEBUG [5]|DEBUG|1a FAIL: something broke');
		});

		const result = await runApexScriptAsync('/path/to/script.apex', {rewriteNamespace: false});
		expect(result.fail).toBe(1);
	});

	it('should reject when error has no stdout', async() =>
	{
		exec.mockImplementation((cmd, opts, callback) =>
		{
			callback(new Error('connection failed'), '');
		});

		await expect(runApexScriptAsync('/path/to/script.apex', {rewriteNamespace: false})).rejects.toThrow('connection failed');
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

describe('waitForFrameworkBatchesToFinish', () =>
{
	const RUNNING = JSON.stringify({result: {records: [{Id: '707xx'}]}});
	const NONE_RUNNING = JSON.stringify({result: {records: []}});

	beforeEach(() =>
	{
		execSync.mockReset();
	});

	it('asks for the framework batches still running and returns at once when none is', async() =>
	{
		execSync.mockReturnValue(NONE_RUNNING);
		const sleep = jest.fn(() => Promise.resolve());

		const result = await waitForFrameworkBatchesToFinish({sleep});

		expect(result).toEqual({finished: true, attempts: 1});
		expect(sleep).not.toHaveBeenCalled();
		const command = execSync.mock.calls[0][0];
		expect(command).toContain('FROM AsyncApexJob WHERE JobType = \'BatchApex\'');
		expect(command).toContain('Status IN (\'Holding\', \'Queued\', \'Preparing\', \'Processing\')');
		expect(command).toContain('ApexClass.NamespacePrefix = \'kern\'');
	});

	it('sleeps five seconds between asks until the running batches have finished', async() =>
	{
		execSync.mockReturnValueOnce(RUNNING).mockReturnValueOnce(RUNNING).mockReturnValue(NONE_RUNNING);
		const sleep = jest.fn(() => Promise.resolve());

		const result = await waitForFrameworkBatchesToFinish({sleep});

		expect(result).toEqual({finished: true, attempts: 3});
		expect(sleep).toHaveBeenCalledTimes(2);
		expect(sleep).toHaveBeenCalledWith(5000);
	});

	it('asks for the batches with no namespace on an org without one', async() =>
	{
		namespacePrefix.mockReturnValueOnce('');
		execSync.mockReturnValue(NONE_RUNNING);

		await waitForFrameworkBatchesToFinish({sleep: jest.fn(() => Promise.resolve())});

		const command = execSync.mock.calls[0][0];
		expect(command).toContain('ApexClass.NamespacePrefix = null');
		expect(command).not.toContain('\'kern\'');
	});

	it('gives up after thirty-six asks and lets the caller proceed', async() =>
	{
		execSync.mockReturnValue(RUNNING);
		const sleep = jest.fn(() => Promise.resolve());

		const result = await waitForFrameworkBatchesToFinish({sleep});

		expect(result).toEqual({finished: false, attempts: 36});
		expect(execSync).toHaveBeenCalledTimes(36);
		expect(sleep).toHaveBeenCalledTimes(36);
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
		jest.spyOn(fs, 'writeFileSync');
		jest.spyOn(fs, 'rmSync');
		execSync.mockReturnValue('success');

		const result = executeAnonymousApex('System.debug("hello");');
		expect(result).toBe('success');
		expect(fs.writeFileSync).toHaveBeenCalledWith(expect.stringMatching(/apex-for-org-[^\\/]+[\\/]anonymous\.apex$/), 'System.debug("hello");', 'utf8');
		expect(fs.rmSync).toHaveBeenCalledWith(path.dirname(fs.writeFileSync.mock.calls[0][0]), {recursive: true, force: true});
		expect(fs.existsSync(fs.writeFileSync.mock.calls[0][0])).toBe(false);

		fs.writeFileSync.mockRestore();
		fs.rmSync.mockRestore();
	});

	it('should clean up temp file even on error', () =>
	{
		jest.spyOn(fs, 'writeFileSync');
		execSync.mockImplementation(() =>
		{
			throw new Error('apex error');
		});

		expect(() => executeAnonymousApex('bad code')).toThrow('apex error');
		expect(fs.existsSync(fs.writeFileSync.mock.calls[0][0])).toBe(false);

		fs.writeFileSync.mockRestore();
	});
});
