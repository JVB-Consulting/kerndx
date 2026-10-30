#!/usr/bin/env node
// SPDX-License-Identifier: Apache-2.0
/**
 * Section 84h: the replay section 84g started, checked once it has run, then the rows of both sections deleted
 *
 * Run at least 60 seconds after section 84g, with the command 84g printed. 84g left an Open issue (I4) for a request
 * without a key and started its replay through the global Flow action, as the user who sent the request. A replay sends
 * the request the failed call holds once more, in the background:
 *   84h-1. The replay made one new call. It is Completed, it holds the same body as the failed call of I4, and it links
 *          to that call (Previous Attempt).
 *   84h-2. I4 is Resolved, with the date it was resolved, and the replay wrote no issue of its own.
 *   84h-cleanup. First it checks that the service has exactly the rows the two sections expect: the calls and issues
 *          84g listed, and the replay's call. When a row is missing or another one is found, it prints a FAIL line and
 *          deletes nothing, so the rows can be looked at. Otherwise it deletes the issues, then the calls (a call with an
 *          Open issue cannot be deleted), then the log entries of the service since 84g started, and a query proves none
 *          is left.
 * While the replay's job is still running, the script prints SECTION84 PENDING, deletes nothing and exits with code 2:
 * run it again 30 seconds later.
 *
 * Prerequisites:
 *   - section 84g ran and printed the command for this section
 *   - the running user is the one who ran section 84g and holds the Delete API Records permission
 *
 * Run:
 *   node release-testing/scripts/section-84h-inbound-replay-live-verify.js --since <time> --job <job id> --replay-issue <issue id>
 *       --replayed-call <call id> --calls <call ids> --issues <issue ids>
 * Prints one SECTION84 PASS or SECTION84 FAIL line per check and exits 1 when any check failed.
 */

const {soqlQuery} = require('../e2e/helpers/sf-cli');
const {
	field, findServiceRows, countLogEntries, deleteIssuesThenCalls, isResolvedIssue, createCheckReport, runSection
} = require('./inbound-issue-live/org-and-report');

const SERVICE_NAME = 'API_RetryLiveOnHold';
const HOLD_ACCOUNT_NAME = 'RetryLive hold';
const STATUS_COMPLETED = 'Completed';
const JOB_ENDED = new Set(['Completed', 'Failed', 'Aborted']);
const EXIT_PENDING = 2;
const REQUIRED_ARGUMENTS = ['since', 'job', 'replay-issue', 'replayed-call', 'calls', 'issues'];
const SALESFORCE_ID = /^[a-zA-Z0-9]{15,18}$/;
const SOQL_DATE_TIME = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/;

/**
 * @description Reads the command-line arguments 84g printed, and refuses any value that is not an id or a time, so no
 * value can change the queries it is put into.
 *
 * @param {string[]} argv The arguments after the script name.
 *
 * @returns {object} The time 84g started, the job, the replayed issue and its call, and the ids 84g listed.
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
		throw new Error(`missing ${missing.map((name) => `--${name}`).join(', ')}; run the command section 84g printed`);
	}
	const ids = (text) => text.split(',').filter(Boolean);
	const allIds = [values.get('job'), values.get('replay-issue'), values.get('replayed-call'), ...ids(values.get('calls')), ...ids(values.get('issues'))];
	if(!SOQL_DATE_TIME.test(values.get('since')) || allIds.some((id) => !SALESFORCE_ID.test(id)))
	{
		throw new Error('an argument is not a time or an id; run the command section 84g printed');
	}
	return {
		since: values.get('since'), jobId: values.get('job'), replayIssueId: values.get('replay-issue'), replayedCallId: values.get('replayed-call'),
		callIds: ids(values.get('calls')), issueIds: ids(values.get('issues'))
	};
}

function findCalls(since)
{
	return findServiceRows('kern__ApiCall__c', ['kern__Status__c', 'kern__Request__c', 'kern__PreviousAttempt__c'], SERVICE_NAME, since);
}

function findIssues(since)
{
	return findServiceRows('kern__ApiIssue__c', ['kern__Status__c', 'kern__ResolvedDate__c'], SERVICE_NAME, since);
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
 * @description Whether a call was found and holds the same request body as another call.
 *
 * @param {object} call The call to check.
 * @param {object} [otherCall] The call it should match, or nothing when it was not found.
 *
 * @returns {boolean} True when both bodies are the same.
 */
function holdsBodyOf(call, otherCall)
{
	return Boolean(otherCall) && call[field('Request__c')] === otherCall[field('Request__c')];
}

function main()
{
	const {report, exitWhenAnyFailed} = createCheckReport();
	const {since, jobId, replayIssueId, replayedCallId, callIds, issueIds} = readArguments(process.argv.slice(2));
	const jobs = soqlQuery(`SELECT Id, Status FROM AsyncApexJob WHERE Id = '${jobId}'`);
	if(jobs.length === 1 && !JOB_ENDED.has(jobs[0].Status))
	{
		console.log(`SECTION84 PENDING 84h: the replay's job ${jobId} is ${jobs[0].Status}. Nothing was deleted. Run this command again in 30 seconds.`);
		process.exit(EXIT_PENDING);
	}

	const calls = findCalls(since);
	const issues = findIssues(since);
	const failedCall = calls.find((call) => call.Id === replayedCallId);
	const replayCalls = calls.filter((call) => !callIds.includes(call.Id) && call[field('PreviousAttempt__c')] === replayedCallId);
	const replayCall = replayCalls[0];
	const isOneCompletedReplay = replayCalls.length === 1 && replayCall[field('Status__c')] === STATUS_COMPLETED;
	report('84h-1', jobs.length === 1 && isOneCompletedReplay && holdsBodyOf(replayCall, failedCall),
			`job ${JSON.stringify(jobs)}, replay calls ${JSON.stringify(replayCalls)}`);

	const replayIssue = issues.find((issue) => issue.Id === replayIssueId);
	const newIssues = issues.filter((issue) => !issueIds.includes(issue.Id));
	report('84h-2', isResolvedIssue(replayIssue) && newIssues.length === 0, `issue ${JSON.stringify(replayIssue)}, issues the replay wrote ${JSON.stringify(newIssues)}`);

	const expectedCallIds = replayCall ? [...callIds, replayCall.Id] : callIds;
	const difference = [describeDifference('calls', expectedCallIds, calls.map((call) => call.Id)),
		describeDifference('issues', issueIds, issues.map((issue) => issue.Id))].filter(Boolean).join('; ');
	if(difference || !replayCall)
	{
		report('84h-cleanup', false, `${difference || 'the replay made no call'}; nothing was deleted`);
	}
	else
	{
		const deleteHoldAccounts = `delete [SELECT Id FROM Account WHERE Name = '${HOLD_ACCOUNT_NAME}'];`;
		deleteIssuesThenCalls({issueIds, callIds: expectedCallIds, serviceName: SERVICE_NAME, since, moreApex: deleteHoldAccounts});
		const left = countLeft(since);
		report('84h-cleanup', left.calls + left.issues + left.logEntries + left.holdAccounts === 0, `left behind: ${JSON.stringify(left)}`);
	}
	exitWhenAnyFailed();
}

runSection('84h', main);
