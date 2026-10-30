#!/usr/bin/env node
// SPDX-License-Identifier: Apache-2.0
/**
 * Section 84g: an inbound request that fails, then succeeds when the caller sends it again, over real REST calls
 *
 * API_RetryLiveOnHold fails every request while an Account named "RetryLive hold" exists (the hold), and otherwise
 * answers status 200 with the body it received. Its setting has Log Issues, Resolve Issues, Retry Issues and Idempotency
 * Enabled on. An Idempotency-Key is the value a caller sends again with each retry of one request; it belongs to the
 * user who sent it, so every request below is sent by the same user: the one this script signs in as.
 *   84g-1. Hold on. Body B1 with key K1 fails with status 400. One Failed call holds B1, and one Open inbound issue
 *          links to it. The issue keeps no copy of the request.
 *   84g-2. Hold off. B1 with K1 again answers 200 with B1. Its call is Completed and links to the failed call
 *          (Previous Attempt), and the issue of the failed call is Resolved.
 *   84g-3. A corrected body. Hold on: body B2 with key K2 fails and leaves an Open issue. Hold off: a corrected body
 *          with K2 answers 200. It is not a retry, because its body differs, so its call links to nothing; but it is
 *          the same request, so the issue of the failed call is Resolved.
 *   84g-4. B2 sent again with K2 now answers 409: the key was used for a request that completed with another body. No
 *          issue is written for it.
 *   84g-5. Hold on. Body B4 without a key fails and leaves an Open issue (I4) linked to its Failed call.
 *   84g-6. Deleting the call of I4 is refused with the label DeleteApiCall_OpenIssue: a call with an Open issue cannot
 *          be deleted, not even by the administrator running this script. The call is still there.
 *   84g-7. Hold off. The global Flow action kern.FLOW_RetryApiIssues.retryApiIssues is called for I4, as the same user
 *          who sent B4, and queues it. The replay runs in the background, so the script prints SECTION84 PENDING with
 *          the command for section 84h, which checks the replay and deletes the rows.
 * When any check fails, the script does not start the replay. It removes the hold, deletes the issues it wrote, then
 * their calls (a call with an Open issue cannot be deleted), then the log entries, and says so; section 84h is not run.
 * The hold is removed in every case.
 *
 * Prerequisites:
 *   - API_RetryLiveOnHold and REST_RetryLiveOnHold deployed, kern__ApiSetting.RetryLiveOnHold deployed
 *   - the running user holds the Kern Administrator permission set (Retry API Issue, Delete API Records)
 *   - no Account named "RetryLive hold" left from an earlier run
 *   - Node 22 (global fetch)
 *
 * Run:
 *   node release-testing/scripts/section-84g-inbound-issue-live.js
 *   then, at least 60 seconds later, the section 84h command this script prints
 * Prints one SECTION84 PASS or SECTION84 FAIL line per check and exits 1 when any check failed.
 */

const fs = require('fs');
const path = require('path');
const {randomUUID} = require('crypto');
const {executeAnonymousApex, parseApexOutput} = require('../e2e/helpers/sf-cli');
const {
	BODY_PREVIEW_CHARACTERS, field, soqlTimeOneSecondAgo, getOrgInfo, postJson, findServiceRows, deleteIssuesThenCalls, waitForLogEntries,
	isOpenInboundIssueWithoutBody, isResolvedIssue, createCheckReport, runSection
} = require('./inbound-issue-live/org-and-report');

const ENDPOINT = '/services/apexrest/v1/retry-live-on-hold';
const SERVICE_NAME = 'API_RetryLiveOnHold';
// The hold Account's name and the message a request fails with on hold, mirrored from API_RetryLiveOnHold's constants.
const HOLD_ACCOUNT_NAME = 'RetryLive hold';
const MESSAGE_ON_HOLD = 'RetryLiveOnHold: the service is on hold, so the request failed on purpose';
// The subscriber org's Account rule asks for a phone or a website.
const HOLD_ACCOUNT_PHONE = '555-0100';
// The subscriber org's Account rule asks for an Industry too.
const HOLD_ACCOUNT_INDUSTRY = 'Technology';
const LABELS_FILE = path.join(__dirname, '../../force-app/main/default/labels/CustomLabels.labels-meta.xml');
const DELETE_REFUSAL_LABEL = 'DeleteApiCall_OpenIssue';
const HTTP_OK = 200;
const HTTP_BAD_REQUEST = 400;
const HTTP_CONFLICT = 409;
const STATUS_FAILED = 'Failed';
const STATUS_COMPLETED = 'Completed';
const DELETE_MARKER = 'SECTION84G_DELETE|';
const REPLAY_MARKER = 'SECTION84G_REPLAY|';
const VERIFY_DELAY_SECONDS = 60;

/**
 * @description Reads the text of a custom label from the package's label file, so the script never keeps a second copy.
 *
 * @param {string} labelName The label's API name.
 *
 * @returns {string} The label's text.
 */
function readLabel(labelName)
{
	const labels = fs.readFileSync(LABELS_FILE, 'utf8');
	const match = labels.match(new RegExp(`<fullName>${labelName}</fullName>[\\s\\S]*?<value>([\\s\\S]*?)</value>`));
	if(!match)
	{
		throw new Error(`The label ${labelName} is not in ${LABELS_FILE}`);
	}
	return match[1].replace(/&apos;/g, '\'').replace(/&quot;/g, '"').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&');
}

function findCalls(startedAt)
{
	return findServiceRows('kern__ApiCall__c', ['kern__Status__c', 'kern__Request__c', 'kern__PreviousAttempt__c'], SERVICE_NAME, startedAt);
}

function findIssues(startedAt)
{
	return findServiceRows('kern__ApiIssue__c', ['kern__Status__c', 'kern__Direction__c', 'kern__ApiCall__c', 'kern__RequestBody__c', 'kern__ResolvedDate__c'],
			SERVICE_NAME, startedAt);
}

function setHold(isOn)
{
	executeAnonymousApex(isOn
			? `insert new Account(Name = '${HOLD_ACCOUNT_NAME}', Phone = '${HOLD_ACCOUNT_PHONE}', Industry = '${HOLD_ACCOUNT_INDUSTRY}');`
			: `delete [SELECT Id FROM Account WHERE Name = '${HOLD_ACCOUNT_NAME}'];`);
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
 * @description Sends one request as the script's own user and notes the calls it wrote.
 *
 * @param {object} run The state of this run: the start time, the org and the ids of the calls seen so far.
 * @param {string} body The request body.
 * @param {string} [idempotencyKey] The Idempotency-Key to send, or nothing to send none.
 *
 * @returns {Promise<{status: number, answer: string, newCalls: object[]}>} The answer and the calls the request wrote.
 */
async function send(run, body, idempotencyKey)
{
	const {status, answer} = await postJson(run.org, ENDPOINT, body, idempotencyKey);
	const newCalls = findCalls(run.startedAt).filter((call) => !run.knownCallIds.has(call.Id));
	newCalls.forEach((call) => run.knownCallIds.add(call.Id));
	return {status, answer, newCalls};
}

function findIssuesOfCall(run, call)
{
	return findIssues(run.startedAt).filter((issue) => call && issue[field('ApiCall__c')] === call.Id);
}

function describe(attempt)
{
	return `status ${attempt.status}, answer ${attempt.answer.slice(0, BODY_PREVIEW_CHARACTERS)}, new calls ${JSON.stringify(attempt.newCalls)}`;
}

function hasOneNewCall(attempt)
{
	return attempt.newCalls.length === 1;
}

function isRefusedOnHold(attempt)
{
	return attempt.status === HTTP_BAD_REQUEST && attempt.answer.includes(MESSAGE_ON_HOLD);
}

/**
 * @description Whether a request failed on hold and wrote exactly one Failed call that holds its body.
 *
 * @param {object} attempt The request's answer and the calls it wrote.
 * @param {string} body The body the request sent.
 *
 * @returns {boolean} True when it did.
 */
function isOneFailedCallHolding(attempt, body)
{
	const isFailedCallHoldingBody = (call) => call[field('Status__c')] === STATUS_FAILED && call[field('Request__c')] === body;
	return isRefusedOnHold(attempt) && hasOneNewCall(attempt) && isFailedCallHoldingBody(attempt.newCalls[0]);
}

function isOneOpenLeanIssue(issues)
{
	return issues.length === 1 && isOpenInboundIssueWithoutBody(issues[0]);
}

function isIssueResolved(run, issueId)
{
	return isResolvedIssue(findIssues(run.startedAt).find((row) => row.Id === issueId));
}

/**
 * @description 84g-1: with the hold on, a body with a key fails and leaves one Open issue linked to its Failed call.
 *
 * @param {object} run The state of this run.
 *
 * @returns {Promise<object>} The body, the key, the failed attempt and its issues.
 */
async function checkFirstFailure(run)
{
	const body = JSON.stringify({leg: 'retry', value: randomUUID()});
	const key = randomUUID();
	setHold(true);
	const failure = await send(run, body, key);
	const issues = findIssuesOfCall(run, failure.newCalls[0]);
	run.report('84g-1', isOneFailedCallHolding(failure, body) && isOneOpenLeanIssue(issues), `${describe(failure)}, issues ${JSON.stringify(issues)}`);
	return {body, key, failure, issues};
}

/**
 * @description 84g-2: with the hold off, the same body with the same key succeeds, its call links to the failed call,
 * and the issue of the failed call is Resolved.
 *
 * @param {object} run The state of this run.
 * @param {object} first What checkFirstFailure returned.
 */
async function checkRetryWithSameKey(run, first)
{
	setHold(false);
	const retry = await send(run, first.body, first.key);
	const isAnsweredWithBody = retry.status === HTTP_OK && retry.answer === first.body;
	const isLinkedToFailedCall = (call) => call[field('Status__c')] === STATUS_COMPLETED && call[field('PreviousAttempt__c')] === first.failure.newCalls[0]?.Id;
	const isLinkedRetry = hasOneNewCall(retry) && isLinkedToFailedCall(retry.newCalls[0]);
	const isFirstIssueResolved = first.issues.length === 1 && isIssueResolved(run, first.issues[0].Id);
	run.report('84g-2', isAnsweredWithBody && isLinkedRetry && isFirstIssueResolved, `${describe(retry)}, issue resolved: ${isFirstIssueResolved}`);
}

/**
 * @description 84g-3: with the hold on, a body with a key fails and leaves an Open issue; with the hold off, a corrected
 * body with the same key succeeds, links to nothing, and resolves the issue.
 *
 * @param {object} run The state of this run.
 *
 * @returns {Promise<{body: string, key: string}>} The body that failed and its key.
 */
async function checkCorrectedBody(run)
{
	const body = JSON.stringify({leg: 'corrected', value: randomUUID()});
	const correctedBody = JSON.stringify({leg: 'corrected', value: randomUUID(), corrected: true});
	const key = randomUUID();
	setHold(true);
	const failure = await send(run, body, key);
	const issues = findIssuesOfCall(run, failure.newCalls[0]);
	setHold(false);
	const correction = await send(run, correctedBody, key);
	const isFailureLogged = isOneFailedCallHolding(failure, body) && isOneOpenLeanIssue(issues);
	const isUnlinkedCompletedCall = (call) => call[field('Status__c')] === STATUS_COMPLETED && !call[field('PreviousAttempt__c')];
	const isUnlinkedCompletion = correction.status === HTTP_OK && hasOneNewCall(correction) && isUnlinkedCompletedCall(correction.newCalls[0]);
	run.report('84g-3', isFailureLogged && isUnlinkedCompletion && isIssueResolved(run, issues[0]?.Id),
			`failure: ${describe(failure)}; correction: ${describe(correction)}; issues ${JSON.stringify(issues)}`);
	return {body, key};
}

/**
 * @description 84g-4: the body that failed, sent again with its key, is refused with 409 and writes no issue.
 *
 * @param {object} run The state of this run.
 * @param {{body: string, key: string}} second What checkCorrectedBody returned.
 */
async function checkReusedKey(run, second)
{
	const issueCountBefore = findIssues(run.startedAt).length;
	const reuse = await send(run, second.body, second.key);
	const issueCountAfter = findIssues(run.startedAt).length;
	run.report('84g-4', reuse.status === HTTP_CONFLICT && issueCountAfter === issueCountBefore,
			`${describe(reuse)}, issues before ${issueCountBefore}, after ${issueCountAfter}`);
}

/**
 * @description 84g-5: with the hold on, a request without a key fails and leaves the issue the replay will run.
 *
 * @param {object} run The state of this run.
 *
 * @returns {Promise<{failedCall: object, issues: object[]}>} The Failed call and its issues.
 */
async function checkReplayFailure(run)
{
	const body = JSON.stringify({leg: 'replay', value: randomUUID()});
	setHold(true);
	const failure = await send(run, body);
	const failedCall = failure.newCalls[0];
	const issues = findIssuesOfCall(run, failedCall);
	run.report('84g-5', isOneFailedCallHolding(failure, body) && isOneOpenLeanIssue(issues), `${describe(failure)}, issues ${JSON.stringify(issues)}`);
	return {failedCall, issues};
}

/**
 * @description 84g-6: deleting the call of the Open issue is refused with the label's text, and the call is still there.
 *
 * @param {object} run The state of this run.
 * @param {{failedCall: object}} replay What checkReplayFailure returned.
 */
function checkDeleteRefused(run, replay)
{
	if(replay.failedCall)
	{
		checkDeleteOfCallRefused(run, replay.failedCall.Id);
	}
	else
	{
		run.report('84g-6', false, 'no failed call to try to delete');
	}
}

/**
 * @description Tries to delete one call as the running user, and reports whether the delete was refused with the
 * label's text and the call is still there.
 *
 * @param {object} run The state of this run.
 * @param {string} callId The call to try to delete.
 */
function checkDeleteOfCallRefused(run, callId)
{
	const deleteOutput = executeAnonymousApex(`Database.DeleteResult result = Database.delete(Id.valueOf('${callId}'), false);`
			+ ` System.debug('${DELETE_MARKER}' + result.isSuccess() + '|' + (result.isSuccess() ? '' : result.getErrors()[0].getMessage()));`);
	const deleteLines = readMarkedLines(deleteOutput, DELETE_MARKER);
	const isStillThere = findCalls(run.startedAt).some((call) => call.Id === callId);
	run.report('84g-6', deleteLines.length === 1 && deleteLines[0] === `false|${run.refusalText}` && isStillThere,
			`delete result: ${JSON.stringify(deleteLines)}, call still there: ${isStillThere}, expected the refusal: ${run.refusalText}`);
}

/**
 * @description 84g-7: calls the global Flow action for the replay issue, and prints the section 84h command when the
 * replay was queued.
 *
 * @param {object} run The state of this run.
 * @param {{failedCall: object, issues: object[]}} replay What checkReplayFailure returned.
 *
 * @returns {boolean} Whether the replay was queued.
 */
function startReplay(run, replay)
{
	const issueId = replay.issues[0].Id;
	const replayOutput = executeAnonymousApex('kern.FLOW_RetryApiIssues.DTO_Request request = new kern.FLOW_RetryApiIssues.DTO_Request();'
			+ ` request.apiIssueIds = new List<String> {'${issueId}'};`
			+ ' kern.FLOW_RetryApiIssues.DTO_Response response = kern.FLOW_RetryApiIssues.retryApiIssues(new List<kern.FLOW_RetryApiIssues.DTO_Request> {request}).get(0);'
			+ ` System.debug('${REPLAY_MARKER}' + response.success + '|' + response.queuedCount + '|' + response.jobId + '|' + response.message);`);
	const replayLines = readMarkedLines(replayOutput, REPLAY_MARKER);
	const [isSuccess, queuedCount, jobId] = (replayLines[0] || '').split('|');
	const hasJob = Boolean(jobId) && jobId !== 'null';
	const isReplayStarted = isSuccess === 'true' && queuedCount === '1' && hasJob;
	run.report('84g-7', isReplayStarted, `the action answered: ${JSON.stringify(replayLines)}`);
	if(isReplayStarted)
	{
		const command = ['node release-testing/scripts/section-84h-inbound-replay-live-verify.js', `--since ${run.startedAt}`, `--job ${jobId}`,
			`--replay-issue ${issueId}`, `--replayed-call ${replay.failedCall.Id}`, `--calls ${[...run.knownCallIds].join(',')}`,
			`--issues ${findIssues(run.startedAt).map((issue) => issue.Id).join(',')}`].join(' ');
		console.log(`SECTION84 PENDING 84h: the replay of issue ${issueId} runs in job ${jobId}. At least ${VERIFY_DELAY_SECONDS} seconds `
				+ `from now, run: ${command}`);
	}
	return isReplayStarted;
}

/**
 * @description Deletes the issues of this run, then its calls, then its log entries, when no replay was started.
 *
 * @param {object} run The state of this run.
 */
async function deleteRunRows(run)
{
	await waitForLogEntries();
	const issueIds = findIssues(run.startedAt).map((issue) => issue.Id);
	const callIds = findCalls(run.startedAt).map((call) => call.Id);
	deleteIssuesThenCalls({issueIds, callIds, serviceName: SERVICE_NAME, since: run.startedAt});
	console.log(`SECTION84 84g: deleted ${issueIds.length} issues, then ${callIds.length} calls and the log entries of this run; do not run section 84h`);
}

async function main()
{
	const checks = createCheckReport();
	const run = {startedAt: soqlTimeOneSecondAgo(), org: getOrgInfo(), refusalText: readLabel(DELETE_REFUSAL_LABEL), knownCallIds: new Set(), report: checks.report};
	let isReplayStarted = false;
	try
	{
		await checkRetryWithSameKey(run, await checkFirstFailure(run));
		await checkReusedKey(run, await checkCorrectedBody(run));
		const replay = await checkReplayFailure(run);
		checkDeleteRefused(run, replay);
		setHold(false);
		if(checks.failedCount() === 0)
		{
			isReplayStarted = startReplay(run, replay);
		}
		else
		{
			run.report('84g-7', false, 'not started, because a check above failed');
		}
	}
	finally
	{
		setHold(false);
		if(!isReplayStarted)
		{
			await deleteRunRows(run);
		}
	}
	checks.exitWhenAnyFailed();
}

runSection('84g', main);
