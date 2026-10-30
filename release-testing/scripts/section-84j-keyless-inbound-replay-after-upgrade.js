#!/usr/bin/env node
// SPDX-License-Identifier: Apache-2.0
/**
 * Section 84j: an issue on the call 1.8 saved without a key, run again through Retry Selected after the upgrade
 *
 * Run on the upgrade leg's org after the upgrade to the candidate and the 1.4 deploy, with the command section 84i
 * printed. Section 84i left one Failed call that 1.8 saved for a request without an Idempotency-Key: it has no key, no
 * hash of its body, and the body whole. Version 1.8 wrote no issue for it, so on a real org a person or an automation
 * makes the issue after the upgrade. This script does the same: it saves one Open inbound issue on the call by hand,
 * with no copy of the request, and runs it again through the global Flow action kern.FLOW_RetryApiIssues.retryApiIssues
 * (the action behind Retry Selected), as the user who sent the request. A call with no key and no hash is run again
 * from its own request when it kept the request whole.
 *   84j-1. Checked before anything changes: the call is still there as 1.8 saved it (Failed, no key, no hash), the
 *          service has no issue, and that call is its only call since 84i. Only then the issue is saved and the action
 *          queues it; on any mismatch nothing is changed.
 *   84j-2. The replay's job Completed.
 *   84j-3. The replay made one new call. It is Completed, it holds the same body as the call 1.8 saved, and it links to
 *          that call (Previous Attempt).
 *   84j-4. The issue is Resolved, with the date it was resolved, and the replay wrote no issue of its own.
 *   84j-cleanup. First it checks that the service has exactly the rows it expects: the call 1.8 saved, the issue, and
 *          the replay's call. When a row is missing or another one is found, it prints a FAIL line and deletes nothing,
 *          so the rows can be looked at. Otherwise it deletes the issue, then the calls (a call with an Open issue
 *          cannot be deleted), then the log entries of the service since 84i started and any hold Account, and a query
 *          proves none is left.
 * The script waits for the replay's job for up to three minutes. When the job is still running after that, it prints
 * SECTION84 PENDING with the command to run 30 seconds later, deletes nothing and exits with code 2. That command
 * carries the job and the issue, so it does not save a second issue.
 *
 * Prerequisites:
 *   - section 84i ran on 1.8.0-11 and printed the command for this section
 *   - the org was upgraded to the candidate and the 1.4 artifacts were deployed
 *   - the running user is the one who ran section 84i and holds the Kern Administrator permission set (Retry API
 *     Issue, Delete API Records)
 *   - sections 84g and 84h are not running at the same time, and left no rows behind
 *   - SF_SUBSCRIBER_ORG_ALIAS names the upgrade leg's org
 *
 * Run:
 *   node release-testing/scripts/section-84j-keyless-inbound-replay-after-upgrade.js --since <time> --call <call id>
 *       [--job <job id> --issue <issue id>]
 * Prints one SECTION84 PASS or SECTION84 FAIL line per check and exits 1 when any check failed.
 */

const {soqlQuery, executeAnonymousApex, parseApexOutput} = require('../e2e/helpers/sf-cli');
const {getSubscriberOrgAlias} = require('../runner/subscriber-config');
const {
	field, findServiceRows, countLogEntries, deleteIssuesThenCalls, waitForLogEntries, isResolvedIssue, createCheckReport, runSection
} = require('./inbound-issue-live/org-and-report');

const SERVICE_NAME = 'API_RetryLiveOnHold';
const HOLD_ACCOUNT_NAME = 'RetryLive hold';
const STATUS_FAILED = 'Failed';
const STATUS_COMPLETED = 'Completed';
const JOB_ENDED = new Set(['Completed', 'Failed', 'Aborted']);
const JOB_COMPLETED = 'Completed';
const JOB_WAIT_ATTEMPTS = 12;
const JOB_WAIT_MILLISECONDS = 15_000;
const EXIT_PENDING = 2;
const REQUIRED_ARGUMENTS = ['since', 'call'];
const SALESFORCE_ID = /^[a-zA-Z0-9]{15,18}$/;
const SOQL_DATE_TIME = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/;
const START_MARKER = 'SECTION84J_START|';
const DELETE_HOLD_ACCOUNTS = `delete [SELECT Id FROM Account WHERE Name = '${HOLD_ACCOUNT_NAME}'];`;

/**
 * @description Reads the command-line arguments 84i printed (and, on a second run, the job and the issue), and refuses
 * any value that is not an id or a time, so no value can change the queries it is put into.
 *
 * @param {string[]} argv The arguments after the script name.
 *
 * @returns {object} The time 84i started, the call 1.8 saved, and the job and the issue when a first run started them.
 */
function readArguments(argv)
{
	const values = new Map();
	for(let index = 0; index < argv.length; index += 2)
	{
		values.set(argv[index].replace(/^--/, ''), argv[index + 1]);
	}
	const missing = REQUIRED_ARGUMENTS.filter((name) => !values.get(name));
	if(missing.length > 0)
	{
		throw new Error(`missing ${missing.map((name) => `--${name}`).join(', ')}; run the command section 84i printed`);
	}
	if(Boolean(values.get('job')) !== Boolean(values.get('issue')))
	{
		throw new Error('--job and --issue go together; run the command this section printed');
	}
	const ids = [values.get('call'), values.get('job'), values.get('issue')].filter(Boolean);
	if(!SOQL_DATE_TIME.test(values.get('since')) || ids.some((id) => !SALESFORCE_ID.test(id)))
	{
		throw new Error('an argument is not a time or an id; run the command section 84i printed');
	}
	return {since: values.get('since'), callId: values.get('call'), jobId: values.get('job'), issueId: values.get('issue')};
}

function findCalls(since)
{
	return findServiceRows('kern__ApiCall__c', ['kern__Status__c', 'kern__Request__c', 'kern__PreviousAttempt__c', 'kern__IdempotencyKey__c',
		'kern__IdempotencyKeyBodyHash__c'], SERVICE_NAME, since);
}

function findIssues(since)
{
	return findServiceRows('kern__ApiIssue__c', ['kern__Status__c', 'kern__ApiCall__c', 'kern__ResolvedDate__c', 'kern__RequestPath__c', 'kern__RequestBody__c'],
			SERVICE_NAME, since);
}

function findJobs(jobId)
{
	return soqlQuery(`SELECT Id, Status, ExtendedStatus FROM AsyncApexJob WHERE Id = '${jobId}'`);
}

function countLeft(since)
{
	return {
		calls: findCalls(since).length,
		issues: findIssues(since).length,
		logEntries: countLogEntries(SERVICE_NAME, since),
		holdAccounts: soqlQuery(`SELECT Id FROM Account WHERE Name = '${HOLD_ACCOUNT_NAME}'`).length
	};
}

/**
 * @description Turns the character references the debug log writes back into the characters they stand for. The log
 * writes a vertical bar as &#124;, and quotes and angle brackets as named references.
 *
 * @param {string} text A line of the debug log.
 *
 * @returns {string} The line as the script printed it.
 */
function decodeDebugText(text)
{
	return text.replace(/&#124;/g, '|').replace(/&apos;/g, '\'').replace(/&#39;/g, '\'').replace(/&quot;/g, '"').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
	.replace(/&amp;/g, '&');
}

/**
 * @description Reads the debug lines an anonymous Apex run printed that start with a marker.
 *
 * @param {string} output What the run printed.
 * @param {string} marker The start of the lines to read.
 *
 * @returns {string[]} The text after the marker, one entry per line.
 */
function readMarkedLines(output, marker)
{
	return parseApexOutput(output).results.map((line) => decodeDebugText(line.message)).filter((message) => message.startsWith(marker))
	.map((message) => message.slice(marker.length));
}

/**
 * @description Whether the call is still there as 1.8 saved it: Failed, with no Idempotency-Key and no hash of its body.
 *
 * @param {object} [call] The call as read from the org, or nothing when it was not found.
 *
 * @returns {boolean} True when it is.
 */
function isCallAsSavedByOldVersion(call)
{
	return Boolean(call) && call[field('Status__c')] === STATUS_FAILED && !call[field('IdempotencyKey__c')] && !call[field('IdempotencyKeyBodyHash__c')];
}

/**
 * @description Saves one Open inbound issue on the call, the way a person would (no copy of the request), in its own
 * transaction.
 *
 * @param {string} callId The call 1.8 saved.
 *
 * @returns {string} The issue's id, or nothing when the id could not be read.
 */
function saveIssue(callId)
{
	const saveOutput = executeAnonymousApex(`kern__ApiIssue__c issue = new kern__ApiIssue__c(kern__ApiCall__c = '${callId}',`
			+ ` kern__ServiceName__c = '${SERVICE_NAME}', kern__Direction__c = 'Inbound', kern__Status__c = 'Open');`
			+ ` insert issue; System.debug('${START_MARKER}' + issue.Id);`);
	const issueId = readMarkedLines(saveOutput, START_MARKER)[0];
	return issueId && SALESFORCE_ID.test(issueId) ? issueId : null;
}

/**
 * @description Calls the global Flow action for the issue, in a second transaction, as Retry Selected does.
 *
 * @param {string} issueId The issue saved by hand.
 *
 * @returns {string[]} What the action answered: success, the number queued, the job and the message.
 */
function retryIssue(issueId)
{
	const retryOutput = executeAnonymousApex('kern.FLOW_RetryApiIssues.DTO_Request request = new kern.FLOW_RetryApiIssues.DTO_Request();'
			+ ` request.apiIssueIds = new List<String> {'${issueId}'};`
			+ ' kern.FLOW_RetryApiIssues.DTO_Response response = kern.FLOW_RetryApiIssues.retryApiIssues(new List<kern.FLOW_RetryApiIssues.DTO_Request> {request}).get(0);'
			+ ` System.debug('${START_MARKER}' + response.success + '|' + response.queuedCount + '|' + response.jobId + '|' + response.message);`);
	return readMarkedLines(retryOutput, START_MARKER);
}

/**
 * @description 84j-1: reads the call, the issues and the calls of the service first, and goes on only when the call is
 * as 1.8 saved it, the service has no issue yet, and the call is its only call. Only then removes any hold, saves the
 * issue and starts its replay. When the check fails, it changes nothing.
 *
 * @param {object} run The state of this run: the arguments and the report.
 *
 * @returns {{issueId: string, jobId: string}} The issue and the job, either of them null when it was not made.
 */
function startReplay(run)
{
	const calls = findCalls(run.since);
	const oldCall = calls.find((call) => call.Id === run.callId);
	const issuesBefore = findIssues(run.since);
	const otherCalls = calls.filter((call) => call.Id !== run.callId);
	if(!isCallAsSavedByOldVersion(oldCall) || issuesBefore.length > 0 || otherCalls.length > 0)
	{
		run.report('84j-1', false, `nothing was changed; call ${JSON.stringify(oldCall)}, issues found ${JSON.stringify(issuesBefore)}, `
				+ `other calls found ${JSON.stringify(otherCalls)}`);
		return {issueId: null, jobId: null};
	}
	executeAnonymousApex(DELETE_HOLD_ACCOUNTS);
	const issueId = saveIssue(run.callId);
	if(!issueId)
	{
		run.report('84j-1', false, 'the issue was not saved');
		return {issueId: null, jobId: null};
	}
	let answer;
	try
	{
		answer = retryIssue(issueId);
	}
	catch(error)
	{
		run.report('84j-1', false, `issue saved ${issueId}, but the action failed: ${error.message}`);
		return {issueId, jobId: null};
	}
	const [isSuccess, queuedCount, jobId] = (answer[0] || '').split('|');
	const hasJob = Boolean(jobId) && SALESFORCE_ID.test(jobId);
	run.report('84j-1', isSuccess === 'true' && queuedCount === '1' && hasJob,
			`call ${JSON.stringify(oldCall)}, issue saved ${issueId}, the action answered ${JSON.stringify(answer)}`);
	return {issueId, jobId: hasJob ? jobId : null};
}

/**
 * @description Runs startReplay, and when an Apex run fails (for example the org refuses the issue), reports 84j-1 as
 * failed instead of ending the script, so the cleanup still runs. Any issue that was saved is found by the cleanup's
 * row check, which then deletes nothing.
 *
 * @param {object} run The state of this run.
 *
 * @returns {{issueId: string, jobId: string}} The issue and the job, either of them null when it was not made.
 */
function startReplayOrReport(run)
{
	try
	{
		return startReplay(run);
	}
	catch(error)
	{
		run.report('84j-1', false, `an Apex run failed: ${error.message}`);
		return {issueId: null, jobId: null};
	}
}

/**
 * @description Waits until the replay's job has ended, asking every 15 seconds, for three minutes at most.
 *
 * @param {string} jobId The job.
 *
 * @returns {Promise<object[]>} The job as last read: one row, or none when the job was not found.
 */
async function waitForJob(jobId)
{
	let jobs = findJobs(jobId);
	for(let attempt = 1; attempt < JOB_WAIT_ATTEMPTS && jobs.length === 1 && !JOB_ENDED.has(jobs[0].Status); attempt++)
	{
		await new Promise((resolve) => setTimeout(resolve, JOB_WAIT_MILLISECONDS));
		jobs = findJobs(jobId);
	}
	return jobs;
}

/**
 * @description 84j-2 to 84j-4: the job Completed, the replay made one Completed call with the old call's body that links
 * to it, the issue is Resolved and the replay wrote no issue.
 *
 * @param {object} run The state of this run.
 * @param {object[]} jobs The job as last read.
 * @param {string} issueId The issue saved by hand.
 *
 * @returns {object} The replay's call, or nothing when there is not exactly one.
 */
function checkReplay(run, jobs, issueId)
{
	run.report('84j-2', jobs.length === 1 && jobs[0].Status === JOB_COMPLETED, `job ${JSON.stringify(jobs)}`);

	const calls = findCalls(run.since);
	const oldCall = calls.find((call) => call.Id === run.callId);
	const replayCalls = calls.filter((call) => call.Id !== run.callId && call[field('PreviousAttempt__c')] === run.callId);
	const replayCall = replayCalls.length === 1 ? replayCalls[0] : null;
	const holdsOldBody = Boolean(replayCall && oldCall) && replayCall[field('Request__c')] === oldCall[field('Request__c')];
	run.report('84j-3', Boolean(replayCall) && replayCall[field('Status__c')] === STATUS_COMPLETED && holdsOldBody,
			`call 1.8 saved ${JSON.stringify(oldCall)}, replay calls ${JSON.stringify(replayCalls)}`);

	const issues = findIssues(run.since);
	const issue = issues.find((row) => row.Id === issueId);
	const newIssues = issues.filter((row) => row.Id !== issueId);
	const keepsNoRequestCopy = Boolean(issue) && !issue[field('RequestPath__c')] && !issue[field('RequestBody__c')];
	run.report('84j-4', isResolvedIssue(issue) && keepsNoRequestCopy && newIssues.length === 0,
			`issue ${JSON.stringify(issue)}, issues the replay wrote ${JSON.stringify(newIssues)}`);
	return replayCall;
}

/**
 * @description Compares the ids found with the ids expected.
 *
 * @param {string} kind What the rows are, for the message.
 * @param {string[]} expectedIds The ids expected.
 * @param {string[]} foundIds The ids found.
 *
 * @returns {string} What is missing and what is extra, or an empty string when the two match.
 */
function describeDifference(kind, expectedIds, foundIds)
{
	const missing = expectedIds.filter((id) => !foundIds.includes(id));
	const extra = foundIds.filter((id) => !expectedIds.includes(id));
	return missing.length + extra.length === 0 ? '' : `${kind}: missing ${JSON.stringify(missing)}, extra ${JSON.stringify(extra)}`;
}

/**
 * @description 84j-cleanup: when the service has exactly the rows expected, deletes the issue, then the calls, then the
 * log entries and any hold Account, and reports what is left. Otherwise deletes nothing.
 *
 * @param {object} run The state of this run.
 * @param {string[]} expectedCallIds The call 1.8 saved and the replay's call, when there is one.
 * @param {string[]} expectedIssueIds The issue saved by hand, when there is one.
 */
async function deleteRows(run, expectedCallIds, expectedIssueIds)
{
	await waitForLogEntries();
	const difference = [describeDifference('calls', expectedCallIds, findCalls(run.since).map((call) => call.Id)),
		describeDifference('issues', expectedIssueIds, findIssues(run.since).map((issue) => issue.Id))].filter(Boolean).join('; ');
	if(difference)
	{
		run.report('84j-cleanup', false, `${difference}; nothing was deleted`);
		return;
	}
	deleteIssuesThenCalls({issueIds: expectedIssueIds, callIds: expectedCallIds, serviceName: SERVICE_NAME, since: run.since, moreApex: DELETE_HOLD_ACCOUNTS});
	const left = countLeft(run.since);
	run.report('84j-cleanup', left.calls + left.issues + left.logEntries + left.holdAccounts === 0, `left behind: ${JSON.stringify(left)}`);
}

async function main()
{
	const {report, exitWhenAnyFailed} = createCheckReport();
	const run = {...readArguments(process.argv.slice(2)), report};
	const {issueId, jobId} = run.jobId ? {issueId: run.issueId, jobId: run.jobId} : startReplayOrReport(run);
	let replayCall = null;
	if(jobId)
	{
		const jobs = await waitForJob(jobId);
		if(jobs.length === 1 && !JOB_ENDED.has(jobs[0].Status))
		{
			const command = [`SF_SUBSCRIBER_ORG_ALIAS=${getSubscriberOrgAlias()} node release-testing/scripts/section-84j-keyless-inbound-replay-after-upgrade.js`,
				`--since ${run.since}`, `--call ${run.callId}`,
				`--job ${jobId}`, `--issue ${issueId}`].join(' ');
			console.log(`SECTION84 PENDING 84j: the replay's job ${jobId} is ${jobs[0].Status}. Nothing was deleted. In 30 seconds, run: ${command}`);
			process.exit(EXIT_PENDING);
		}
		replayCall = checkReplay(run, jobs, issueId);
	}
	else
	{
		report('84j-2', false, 'no job was started, so the replay was not checked');
	}
	const expectedCallIds = replayCall ? [run.callId, replayCall.Id] : [run.callId];
	await deleteRows(run, expectedCallIds, issueId ? [issueId] : []);
	exitWhenAnyFailed();
}

runSection('84j', main);
