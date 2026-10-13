// SPDX-License-Identifier: BUSL-1.1
/**
 * @description The verdict helper's orchestration against a scripted `sf` CLI: it waits for a run
 * already in flight, launches, resolves its own run by id rather than the newest run on the org, polls
 * to a terminal status, writes the evidence files and exits on the org's truth.
 */
jest.mock('child_process', () => ({execFileSync: jest.fn()}));

const fs = require('fs');
const os = require('os');
const path = require('path');
const {execFileSync} = require('child_process');
const {main, parseArguments} = require('../../release-testing/runner/apex-test-verdict');

const MARK = '2026-08-18T08:00:00.000+0000';
const OURS = {
	AsyncApexJobId: '707di0000L6aBcDAAY',
	Status: 'Completed',
	MethodsEnqueued: 40,
	MethodsCompleted: 40,
	MethodsFailed: 0,
	StartTime: '2026-08-18T08:30:00.000+0000',
	EndTime: '2026-08-18T08:45:00.000+0000'
};
const OURS_RUNNING = {...OURS, Status: 'Processing', MethodsCompleted: 10, EndTime: null};
const SOMEONE_ELSES_NEWER = {...OURS, AsyncApexJobId: '707di0000L9zZzZAAY', Status: 'Processing', StartTime: '2026-08-18T08:40:00.000+0000', EndTime: null};
const NON_PASS = [
	{ApexClass: {Name: 'CTRL_Logger_TEST'}, MethodName: 'groupsByFingerprint', Outcome: 'Fail', Message: 'expected 1 problem'},
	{ApexClass: {Name: 'CTRL_Logger_TEST'}, MethodName: 'groupsByExceptionType', Outcome: 'Fail', Message: 'expected 1 problem'}
];

const noSleep = async() =>
{
};

function queryPayload(records)
{
	return JSON.stringify({status: 0, result: {records, totalSize: records.length, done: true}, warnings: []});
}

/**
 * Scripts the fake CLI: each call's arguments are matched against the steps in order; a step may answer
 * more than once. An unmatched call fails the test loudly.
 */
function scriptCli(steps)
{
	const calls = [];
	execFileSync.mockImplementation((command, args) =>
	{
		calls.push(args);
		const joined = args.join(' ');
		const nextStep = steps.find((candidate) => candidate.remaining > 0 && candidate.match(joined));
		if(!nextStep)
		{
			throw new Error(`unscripted sf call: ${joined}`);
		}
		nextStep.remaining--;
		if(nextStep.reply instanceof Error)
		{
			throw nextStep.reply;
		}
		return nextStep.reply;
	});
	return calls;
}

function step(match, reply, times = 1)
{
	return {match, reply, remaining: times};
}

describe('parseArguments', () =>
{
	it('requires the org, the label and the folder the run writes to', () =>
	{
		expect(() => parseArguments([
			'--org',
			'x',
			'--label',
			'y'
		])).toThrow(/--evidence-dir is required/);
	});

	it('splits the test list and reads the coverage flag', () =>
	{
		const options = parseArguments([
			'--org',
			'x',
			'--label',
			'y',
			'--evidence-dir',
			'z',
			'--tests',
			'kern.A_TEST, kern.B_TEST',
			'--code-coverage',
			'--wait-minutes',
			'5'
		]);
		expect(options.tests).toEqual([
			'kern.A_TEST',
			'kern.B_TEST'
		]);
		expect(options.codeCoverage).toBe(true);
		expect(options.waitMinutes).toBe(5);
	});

	it('reads the test level and the id of a run to attach to, and defaults the rest', () =>
	{
		const options = parseArguments([
			'--org',
			'x',
			'--label',
			'y',
			'--evidence-dir',
			'z',
			'--test-level',
			'RunLocalTests',
			'--run-id',
			'707di0000L6aBcDAAY'
		]);
		expect(options).toEqual({
			org: 'x', label: 'y', evidenceDir: 'z', testLevel: 'RunLocalTests', tests: [], codeCoverage: false, waitMinutes: 120, runId: '707di0000L6aBcDAAY'
		});
	});

	it('defaults the test level to every test in the org when the command line names none', () =>
	{
		expect(parseArguments([
			'--org',
			'x',
			'--label',
			'y',
			'--evidence-dir',
			'z'
		]).testLevel).toBe('RunAllTestsInOrg');
	});

	it('names an argument it does not know rather than ignoring it', () =>
	{
		expect(() => parseArguments([
			'--org',
			'x',
			'--label',
			'y',
			'--evidence-dir',
			'z',
			'--verbose'
		])).toThrow('unknown argument --verbose');
	});
});

describe('main', () =>
{
	let evidenceDir;
	beforeEach(() =>
	{
		evidenceDir = fs.mkdtempSync(path.join(os.tmpdir(), 'verdict-'));
		execFileSync.mockReset();
	});
	afterEach(() =>
	{
		fs.rmSync(evidenceDir, {recursive: true, force: true});
	});

	it('waits for the in-flight run, launches, follows its own run by id past a newer run, and passes on the org truth', async() =>
	{
		const calls = scriptCli([
			step((a) => a.includes('FROM ApexTestRunResult WHERE Status IN'), queryPayload([SOMEONE_ELSES_NEWER])),
			step((a) => a.includes('FROM ApexTestRunResult WHERE Status IN'), queryPayload([])),
			step((a) => a.includes('ORDER BY StartTime DESC LIMIT 1'), queryPayload([{StartTime: MARK}])),
			step((a) => a.startsWith('apex run test'), JSON.stringify({status: 0, result: {testRunId: '707di0000L6aBcD'}})),
			step((a) => a.includes('NULLS LAST LIMIT 10'), queryPayload([
				SOMEONE_ELSES_NEWER,
				OURS_RUNNING
			])),
			step((a) => a.includes('WHERE AsyncApexJobId = \'707di0000L6aBcDAAY\'') && a.includes('FROM ApexTestRunResult'), queryPayload([OURS_RUNNING])),
			step((a) => a.includes('WHERE AsyncApexJobId = \'707di0000L6aBcDAAY\'') && a.includes('FROM ApexTestRunResult'), queryPayload([OURS])),
			step((a) => a.includes('FROM ApexTestResult'), queryPayload([]))
		]);
		const log = jest.fn();
		const code = await main({org: 'SubscriberOrg', label: 'fresh', evidenceDir, testLevel: 'RunAllTestsInOrg', tests: [], codeCoverage: false, waitMinutes: 10, runId: null},
				log, noSleep);
		expect(code).toBe(0);
		const launch = calls.find((args) => args[0] === 'apex');
		expect(launch).toEqual(expect.arrayContaining([
			'--test-level',
			'RunAllTestsInOrg',
			'--wait',
			'1',
			'--json'
		]));
		expect(calls.findIndex((args) => args.join(' ').includes('WHERE Status IN'))).toBeLessThan(calls.indexOf(launch));
		expect(JSON.parse(fs.readFileSync(path.join(evidenceDir, 'apex-run-fresh.json'), 'utf8')).AsyncApexJobId).toBe('707di0000L6aBcDAAY');
		expect(JSON.parse(fs.readFileSync(path.join(evidenceDir, 'apex-nonpass-fresh.json'), 'utf8'))).toEqual([]);
		expect(log).toHaveBeenCalledWith('verdict fresh: PASS (Completed, enqueued 40, completed 40, failed 0, non-pass 0)');
	});

	it('reports the org-wide coverage on the verdict line and in the evidence when the run was launched with coverage', async() =>
	{
		scriptCli([
			step((a) => a.includes('WHERE Status IN'), queryPayload([])),
			step((a) => a.includes('ORDER BY StartTime DESC LIMIT 1'), queryPayload([{StartTime: MARK}])),
			step((a) => a.startsWith('apex run test') && a.includes('--code-coverage'), JSON.stringify({status: 0, result: {testRunId: '707di0000L6aBcD'}})),
			step((a) => a.includes('NULLS LAST LIMIT 10'), queryPayload([OURS])),
			step((a) => a.includes('WHERE AsyncApexJobId = \'707di0000L6aBcDAAY\'') && a.includes('FROM ApexTestRunResult'), queryPayload([OURS])),
			step((a) => a.includes('FROM ApexTestResult'), queryPayload([])),
			step((a) => a.includes('-t') && a.includes('FROM ApexOrgWideCoverage'), queryPayload([{PercentCovered: 87}]))
		]);
		const log = jest.fn();
		const code = await main({org: 'SubscriberOrg', label: 'local', evidenceDir, testLevel: 'RunLocalTests', tests: [], codeCoverage: true, waitMinutes: 10, runId: null}, log,
				noSleep);
		expect(code).toBe(0);
		expect(log).toHaveBeenCalledWith('verdict local: PASS (Completed, enqueued 40, completed 40, failed 0, non-pass 0, coverage 87%)');
		expect(JSON.parse(fs.readFileSync(path.join(evidenceDir, 'apex-run-local.json'), 'utf8')).orgWideCoveragePercent).toBe(87);
	});

	it('surfaces the platform refusal when the launch is rejected', async() =>
	{
		const refusal = new Error('Command failed');
		refusal.stdout = '[31mError (ALREADY_IN_PROCESS):[39m This test is already in the execution queue.\n';
		refusal.stderr = '';
		scriptCli([
			step((a) => a.includes('WHERE Status IN'), queryPayload([])),
			step((a) => a.includes('ORDER BY StartTime DESC LIMIT 1'), queryPayload([])),
			step((a) => a.startsWith('apex run test'), refusal)
		]);
		await expect(
				main({org: 'SubscriberOrg', label: 'fresh', evidenceDir, testLevel: 'RunAllTestsInOrg', tests: [], codeCoverage: false, waitMinutes: 10, runId: null}, jest.fn(),
						noSleep))
		.rejects.toThrow(/ALREADY_IN_PROCESS/);
	});

	it('attaches to an existing run with --run-id, launches nothing, and fails on the non-pass rows', async() =>
	{
		const calls = scriptCli([
			step((a) => a.includes('WHERE AsyncApexJobId = \'707di0000L7xYzWAAY\'') && a.includes('FROM ApexTestRunResult'),
					queryPayload([{...OURS, AsyncApexJobId: '707di0000L7xYzWAAY', MethodsFailed: 2}])),
			step((a) => a.includes('FROM ApexTestResult'), queryPayload(NON_PASS))
		]);
		const log = jest.fn();
		const code = await main(
				{org: 'SubscriberOrg', label: 'upgrade', evidenceDir, testLevel: 'RunAllTestsInOrg', tests: [], codeCoverage: false, waitMinutes: 10, runId: '707di0000L7xYzWAAY'},
				log, noSleep);
		expect(code).toBe(1);
		expect(calls.some((args) => args[0] === 'apex')).toBe(false);
		expect(JSON.parse(fs.readFileSync(path.join(evidenceDir, 'apex-nonpass-upgrade.json'), 'utf8'))).toHaveLength(2);
		expect(log).toHaveBeenCalledWith('verdict upgrade: FAIL (Completed, enqueued 40, completed 40, failed 2, non-pass 2; 2 failed methods, 2 non-pass rows)');
		expect(log.mock.calls.map((call) => call[0]).join('\n')).toMatch(/2 CTRL_Logger_TEST \| Fail \| expected 1 problem/);
	});

	it('fails a run that is still running when the wait runs out and says it never reached a terminal status', async() =>
	{
		scriptCli([
			step((a) => a.includes('WHERE AsyncApexJobId = \'707di0000L6aBcDAAY\'') && a.includes('FROM ApexTestRunResult'), queryPayload([OURS_RUNNING]), 5)
		]);
		const log = jest.fn();
		const code = await main(
				{org: 'SubscriberOrg', label: 'slow', evidenceDir, testLevel: 'RunAllTestsInOrg', tests: [], codeCoverage: false, waitMinutes: 0, runId: '707di0000L6aBcDAAY'}, log,
				noSleep);
		expect(code).toBe(1);
		expect(log.mock.calls.map((call) => call[0]).join('\n')).toMatch(/not terminal/);
		expect(fs.existsSync(path.join(evidenceDir, 'apex-nonpass-slow.json'))).toBe(true);
	});
});
