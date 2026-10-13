// SPDX-License-Identifier: BUSL-1.1
/**
 * @description The org-truth verdict for an Apex test run: the run's outcome is read from
 * ApexTestRunResult and ApexTestResult on the org, never from the CLI wrapper's JSON, because the
 * wrapper carries nothing but a run id once its wait expires (the 1.7 cycle read a 25-failure run
 * as "non-pass tests: 0" that way). The payloads below are the 1.7.0 release cycle's own.
 */
const {
	parseLaunchPayload,
	parseQueryPayload,
	isTerminal,
	countInFlight,
	selectRunStartedAfter,
	buildVerdict,
	summarizeNonPass
} = require('../../release-testing/runner/apex-test-verdict');

const LAUNCH_WAIT_EXPIRED = JSON.stringify({status: 0, result: {testRunId: '707di0000L5tWze'}, warnings: []});
const LAUNCH_REFUSED = '[1m[31mError (ALREADY_IN_PROCESS):[39m[22m This test is already in the execution queue.\n';
const QUERY_WITH_WARNING_PREFIX = 'Warning: @salesforce/cli update available\n' + JSON.stringify({
	status: 0, result: {records: [{Status: 'Completed'}], totalSize: 1, done: true}, warnings: []
});

const RUN_PROCESSING = {
	attributes: {type: 'ApexTestRunResult'}, AsyncApexJobId: '707di0000L5tWzeAQE', Status: 'Processing',
	MethodsEnqueued: 4554, MethodsCompleted: 3980, MethodsFailed: 24, StartTime: '2026-08-17T09:00:00.000+0000', EndTime: null
};
const RUN_COMPLETED_CLEAN = {
	attributes: {type: 'ApexTestRunResult'}, AsyncApexJobId: '707di0000L6aBcDAAY', Status: 'Completed',
	MethodsEnqueued: 4554, MethodsCompleted: 4554, MethodsFailed: 0, StartTime: '2026-08-17T11:00:00.000+0000', EndTime: '2026-08-17T12:10:00.000+0000'
};
const RUN_COMPLETED_WITH_FAILURES = {...RUN_COMPLETED_CLEAN, AsyncApexJobId: '707di0000L7xYzWAAY', MethodsFailed: 24};
const NON_PASS_TWO = [
	{ApexClass: {Name: 'CTRL_Logger_TEST'}, MethodName: 'groupsByFingerprint', Outcome: 'Fail', Message: 'System.AssertException: Assertion Failed: expected 1 problem'},
	{ApexClass: {Name: 'CTRL_Logger_TEST'}, MethodName: 'groupsByExceptionType', Outcome: 'Fail', Message: 'System.AssertException: Assertion Failed: expected 1 problem'},
	{ApexClass: {Name: 'DML_Builder_TEST'}, MethodName: 'retriesOnLock', Outcome: 'CompileFail', Message: 'Dependent class is invalid'}
];

describe('parseLaunchPayload', () =>
{
	it('returns the run id from a launch whose CLI wait expired, which carries nothing else', () =>
	{
		expect(parseLaunchPayload(LAUNCH_WAIT_EXPIRED)).toEqual({testRunId: '707di0000L5tWze'});
	});

	it('names the platform refusal when the CLI printed an error instead of JSON', () =>
	{
		expect(() => parseLaunchPayload(LAUNCH_REFUSED)).toThrow(/ALREADY_IN_PROCESS/);
	});
});

describe('parseQueryPayload', () =>
{
	it('tolerates a CLI warning line ahead of the JSON', () =>
	{
		expect(parseQueryPayload(QUERY_WITH_WARNING_PREFIX)).toEqual([{Status: 'Completed'}]);
	});

	it('returns an empty list for a query with no rows', () =>
	{
		expect(parseQueryPayload(JSON.stringify({status: 0, result: {records: [], totalSize: 0, done: true}}))).toEqual([]);
	});
});

describe('isTerminal and countInFlight', () =>
{
	it('treats Queued, Processing, Holding and Preparing as in flight and everything else as terminal', () =>
	{
		expect(isTerminal(RUN_PROCESSING)).toBe(false);
		expect(isTerminal(RUN_COMPLETED_CLEAN)).toBe(true);
		expect(isTerminal({Status: 'Aborted'})).toBe(true);
		expect(countInFlight([RUN_PROCESSING, RUN_COMPLETED_CLEAN, {Status: 'Queued'}])).toBe(2);
	});
});

describe('selectRunStartedAfter', () =>
{
	it('picks the run started after the mark, not the newest run on the org', () =>
	{
		const earlierRun = {...RUN_PROCESSING, StartTime: '2026-08-18T09:00:00.000+0000'};
		const launchedRun = {...RUN_COMPLETED_CLEAN, StartTime: '2026-08-18T08:30:00.000+0000'};
		const mark = '2026-08-18T08:00:00.000+0000';
		expect(selectRunStartedAfter([earlierRun, launchedRun], mark, '707di0000L6aBcD')).toBe(launchedRun);
	});

	it('returns null when no run started after the mark', () =>
	{
		expect(selectRunStartedAfter([RUN_PROCESSING], '2026-08-18T09:00:00.000+0000', null)).toBeNull();
	});
});

describe('buildVerdict', () =>
{
	it('passes a completed run with no failures and no non-pass rows', () =>
	{
		const verdict = buildVerdict(RUN_COMPLETED_CLEAN, []);
		expect(verdict.passed).toBe(true);
		expect(verdict.status).toBe('Completed');
		expect(verdict.methodsFailed).toBe(0);
	});

	it('fails a completed run whose org truth carries failures, whatever the wrapper said', () =>
	{
		const verdict = buildVerdict(RUN_COMPLETED_WITH_FAILURES, NON_PASS_TWO);
		expect(verdict.passed).toBe(false);
		expect(verdict.methodsFailed).toBe(24);
		expect(verdict.nonPassCount).toBe(3);
	});

	it('fails a run that never reached a terminal status and says so', () =>
	{
		const verdict = buildVerdict(RUN_PROCESSING, []);
		expect(verdict.passed).toBe(false);
		expect(verdict.reason).toMatch(/not terminal/i);
	});

	it('fails a completed run with zero MethodsFailed but non-pass rows, since a compile failure counts no method', () =>
	{
		const verdict = buildVerdict(RUN_COMPLETED_CLEAN, [NON_PASS_TWO[2]]);
		expect(verdict.passed).toBe(false);
		expect(verdict.nonPassCount).toBe(1);
	});
});

describe('summarizeNonPass', () =>
{
	it('groups non-pass rows by class and outcome with a count and the first message', () =>
	{
		const lines = summarizeNonPass(NON_PASS_TWO);
		expect(lines).toEqual([
			'2 CTRL_Logger_TEST | Fail | System.AssertException: Assertion Failed: expected 1 problem',
			'1 DML_Builder_TEST | CompileFail | Dependent class is invalid'
		]);
	});
});
