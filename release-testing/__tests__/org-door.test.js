// SPDX-License-Identifier: Apache-2.0
const os = require('os');
const {runCommand, createOrgDoor} = require('../scripts/consoles-at-volume/org-door');

// The answer `sf apex run --json` writes for a failed script whose log is long: the CLI stops at 64 KiB, inside the logs.
const CUT_ANSWER = '{\n  "status": 1,\n  "result": {\n    "success": false,\n    "compiled": true,\n    "compileProblem": "",\n'
		+ '    "exceptionMessage": "System.LimitException: Too many DML statements: 151",\n    "logs": "' + 'x'.repeat(70_000);

// A command runner whose process exited non-zero with the given stdout, as execFileSync reports it.
function failingExecFile(stdout)
{
	return jest.fn(() =>
	{
		const error = new Error('Command failed: sf');
		error.stdout = stdout;
		error.stderr = '';
		throw error;
	});
}

describe('runCommand', () =>
{
	it('reads the outcome of a failed script from an answer the CLI cut short inside the log', () =>
	{
		const answer = runCommand(failingExecFile(CUT_ANSWER), [
			'apex',
			'run',
			'--json'
		]);
		expect(answer).toMatchObject({status: 1, cut: true, result: {success: false, compileProblem: '', exceptionMessage: 'System.LimitException: Too many DML statements: 151'}});
	});

	it('resolves the escapes inside a salvaged exception message', () =>
	{
		const cut = '{"status": 1, "result": {"success": false, "compileProblem": "", "exceptionMessage": "List has no rows for assignment to SObject \\"x\\" \\\\ y", "logs": "'
				+ 'x'.repeat(70_000);
		const answer = runCommand(failingExecFile(cut), [
			'apex',
			'run',
			'--json'
		]);
		expect(answer.result.exceptionMessage).toBe('List has no rows for assignment to SObject "x" \\ y');
	});

	it('never salvages a successful answer: a cut one is named as cut, a whole one is read as it is', () =>
	{
		const cutSuccess = '{"status": 0, "result": {"success": true, "compileProblem": "", "exceptionMessage": "", "logs": "' + 'x'.repeat(70_000);
		expect(() => runCommand(jest.fn(() => cutSuccess), [
			'apex',
			'run',
			'--json'
		])).toThrow(/cut short at \d+ characters/);
		const whole = `{"status": 0, "result": {"success": true, "compileProblem": "", "exceptionMessage": "", "logs": "${'x'.repeat(70_000)}"}}`;
		expect(runCommand(jest.fn(() => whole), [
			'apex',
			'run',
			'--json'
		])).toMatchObject({status: 0, result: {success: true}});
		expect(runCommand(jest.fn(() => whole), [
			'apex',
			'run',
			'--json'
		]).cut).toBeUndefined();
	});

	it('names an answer it cannot read at all', () =>
	{
		const execFile = jest.fn(() => '{"status": 1, "result": {"logs": "' + 'x'.repeat(100));
		expect(() => runCommand(execFile, [
			'apex',
			'run',
			'--json'
		])).toThrow(/printed unreadable JSON/);
	});
});

describe('query', () =>
{
	const IN_TRANSIT = '{"status": 1, "name": "Error", "message": "fetch failed", "exitCode": 1}';
	const ROWS = '{"status": 0, "result": {"records": [{"Id": "a03000000000001AAA"}], "totalSize": 1, "done": true}}';

	// A command runner that fails in transit the given number of times, then answers with the rows.
	function transitThenRows(failures)
	{
		let failed = 0;
		return jest.fn(() =>
		{
			if(failed < failures)
			{
				failed++;
				const error = new Error('Command failed: sf');
				error.stdout = IN_TRANSIT;
				error.stderr = '';
				throw error;
			}
			return ROWS;
		});
	}

	it('retries a query whose call failed in transit and returns the rows the retry read', () =>
	{
		const execFile = transitThenRows(1);
		const sleepSync = jest.fn();
		const log = jest.fn();
		const orgDoor = createOrgDoor({alias: 'x', execFile, sleepSync, log});
		expect(orgDoor.query('SELECT Id FROM Account')).toEqual({records: [{Id: 'a03000000000001AAA'}], totalSize: 1});
		expect(execFile).toHaveBeenCalledTimes(2);
		expect(sleepSync).toHaveBeenCalledTimes(1);
		expect(sleepSync).toHaveBeenCalledWith(5_000);
		expect(log.mock.calls.some(([line]) => /WARNING a query failed in transit \(fetch failed\); attempt 2 of 3/.test(line))).toBe(true);
	});

	it('stops a query whose call keeps failing in transit once its attempts run out', () =>
	{
		const execFile = transitThenRows(Number.POSITIVE_INFINITY);
		const orgDoor = createOrgDoor({alias: 'x', execFile, sleepSync: jest.fn(), log: jest.fn()});
		expect(() => orgDoor.query('SELECT Id FROM Account')).toThrow(/The query failed: fetch failed/);
		expect(execFile).toHaveBeenCalledTimes(3);
	});

	it('retries a query whose call hung until the timeout killed it and printed nothing', () =>
	{
		const execFile = jest.fn().mockImplementationOnce(() =>
		{
			const error = new Error('Command failed: sf');
			error.stdout = '';
			error.stderr = '';
			throw error;
		}).mockImplementation(() => ROWS);
		const sleepSync = jest.fn();
		const orgDoor = createOrgDoor({alias: 'x', execFile, sleepSync, log: jest.fn()});
		expect(orgDoor.query('SELECT Id FROM Account').totalSize).toBe(1);
		expect(execFile).toHaveBeenCalledTimes(2);
		expect(sleepSync).toHaveBeenCalledTimes(1);
	});

	it('never retries a query the org itself refused', () =>
	{
		const refused = '{"status": 1, "name": "MalformedQuery", "message": "MALFORMED_QUERY: unexpected token", "exitCode": 1}';
		const execFile = failingExecFile(refused);
		const sleepSync = jest.fn();
		const orgDoor = createOrgDoor({alias: 'x', execFile, sleepSync, log: jest.fn()});
		expect(() => orgDoor.query('SELECT Id FROM Account WHERE')).toThrow(/The query failed: MALFORMED_QUERY/);
		expect(execFile).toHaveBeenCalledTimes(1);
		expect(sleepSync).not.toHaveBeenCalled();
	});
});

describe('runApex', () =>
{
	it('throws the script\'s own failure when the CLI cut its answer short', () =>
	{
		const orgDoor = createOrgDoor({alias: 'x', execFile: failingExecFile(CUT_ANSWER), temporaryDirectory: os.tmpdir()});
		expect(() => orgDoor.runApex('System.debug(1);', 'probe')).toThrow(/probe: System.LimitException: Too many DML statements: 151/);
	});

	it('marks the CLI\'s own transport failure as transient, since the script may or may not have run', () =>
	{
		const inTransit = '{"status": 1, "name": "Error", "message": "Unexpected error while executing anonymous apex. fetch failed", "exitCode": 1}';
		const orgDoor = createOrgDoor({alias: 'x', execFile: failingExecFile(inTransit), temporaryDirectory: os.tmpdir()});
		let failure;
		try
		{
			orgDoor.runApex('System.debug(1);', 'small-170');
		}
		catch(caught)
		{
			failure = caught;
		}
		expect(failure.message).toBe('small-170: Unexpected error while executing anonymous apex. fetch failed');
		expect(failure.transient).toBe(true);
	});

	it('never marks a script\'s own failure as transient', () =>
	{
		const orgDoor = createOrgDoor({alias: 'x', execFile: failingExecFile(CUT_ANSWER), temporaryDirectory: os.tmpdir()});
		let failure;
		try
		{
			orgDoor.runApex('System.debug(1);', 'probe');
		}
		catch(caught)
		{
			failure = caught;
		}
		expect(failure.transient).toBe(false);
	});
});
