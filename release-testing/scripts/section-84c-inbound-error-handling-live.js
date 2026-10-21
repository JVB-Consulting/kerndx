#!/usr/bin/env node
// SPDX-License-Identifier: BUSL-1.1
/**
 * Section 84c: an inbound handler whose own error handling throws, called over REST
 *
 * API_RetryLiveInbound throws while it processes the request, and its handleError override throws too. The framework
 * must still answer the caller, over a real REST call and not only in a unit test:
 *   84c-1. The answer is status 500, and its body carries both messages: the one the processing threw and the one the
 *          error handling threw.
 *   84c-2. One call record for the service, Failed, with no next retry time.
 *   84c-3. Exactly one Open inbound issue for the service, linked to that Failed call. The handler's own error handling
 *          failed, so the framework writes this issue itself. Like every inbound issue, it keeps no copy of the request:
 *          the call holds it.
 *   84c-cleanup. First it checks that the request left exactly the rows it expects: one call and one issue linked to it.
 *          When a row is missing or another one is found, it prints a FAIL line and deletes nothing, so the rows can be
 *          looked at. Otherwise it deletes the issue, then the call (a call with an Open issue cannot be deleted), then
 *          the log entries the request wrote, and a query proves none is left.
 *
 * Prerequisites:
 *   - API_RetryLiveInbound and REST_RetryLiveInbound deployed, kern__ApiSetting.RetryLiveInbound deployed (Log Issues on)
 *   - the running user holds the Delete API Records permission (the Kern Administrator permission set grants it)
 *   - Node 22 (global fetch)
 *
 * Run:
 *   node release-testing/scripts/section-84c-inbound-error-handling-live.js
 * Prints one SECTION84 PASS or SECTION84 FAIL line per check and exits 1 when any check failed.
 */

const {
	BODY_PREVIEW_CHARACTERS, field, soqlTimeOneSecondAgo, getOrgInfo, postJson, findServiceRows, countLogEntries, deleteIssuesThenCalls, waitForLogEntries,
	isOpenInboundIssueWithoutBody, createCheckReport, runSection
} = require('./inbound-issue-live/org-and-report');

const ENDPOINT = '/services/apexrest/v1/retry-live-inbound';
const SERVICE_NAME = 'API_RetryLiveInbound';
// The two messages API_RetryLiveInbound throws, mirrored from its constants.
const MESSAGE_PROCESSING_THREW = 'RetryLiveInbound: the processing threw on purpose';
const MESSAGE_ERROR_HANDLING_THREW = 'RetryLiveInbound: the error handling threw on purpose';
const HTTP_INTERNAL_SERVER_ERROR = 500;
const STATUS_FAILED = 'Failed';

function findCalls(startedAt)
{
	return findServiceRows('kern__ApiCall__c', ['kern__Status__c', 'kern__NextRetry__c'], SERVICE_NAME, startedAt);
}

function findIssues(startedAt)
{
	return findServiceRows('kern__ApiIssue__c', ['kern__Status__c', 'kern__Direction__c', 'kern__ApiCall__c', 'kern__RequestBody__c'], SERVICE_NAME, startedAt);
}

function countLeft(startedAt)
{
	return {calls: findCalls(startedAt).length, issues: findIssues(startedAt).length, logEntries: countLogEntries(SERVICE_NAME, startedAt)};
}

/**
 * @description Whether the answer carries both messages: the one the processing threw and the one the error handling threw.
 *
 * @param {string} body The answer's body.
 *
 * @returns {boolean} True when it carries both.
 */
function hasBothMessages(body)
{
	return body.includes(MESSAGE_PROCESSING_THREW) && body.includes(MESSAGE_ERROR_HANDLING_THREW);
}

/**
 * @description Whether there is exactly one call, Failed, with no next retry time.
 *
 * @param {object[]} calls The calls of the service since the section started.
 *
 * @returns {boolean} True when there is.
 */
function isOneFailedCallWithoutRetry(calls)
{
	return calls.length === 1 && calls[0][field('Status__c')] === STATUS_FAILED && !calls[0][field('NextRetry__c')];
}

/**
 * @description Whether there is exactly one issue and one call, and the issue is an Open inbound issue linked to the
 * call that keeps no copy of the request.
 *
 * @param {object[]} issues The issues of the service since the section started.
 * @param {object[]} calls The calls of the service since the section started.
 *
 * @returns {boolean} True when it is.
 */
function isOneLeanIssueOfTheCall(issues, calls)
{
	const isOneIssueForOneCall = issues.length === 1 && calls.length === 1;
	return isOneIssueForOneCall && issues[0][field('ApiCall__c')] === calls[0].Id && isOpenInboundIssueWithoutBody(issues[0]);
}

/**
 * @description Checks that the request left exactly one call and one issue linked to it.
 *
 * @param {object[]} calls The calls of the service since the section started.
 * @param {object[]} issues The issues of the service since the section started.
 *
 * @returns {string} Why the rows are not the expected ones, or an empty string when they are.
 */
function describeUnexpectedRows(calls, issues)
{
	let problem = '';
	if(calls.length !== 1 || issues.length !== 1)
	{
		problem = `expected one call and one issue, found ${calls.length} calls and ${issues.length} issues`;
	}
	else if(issues[0][field('ApiCall__c')] !== calls[0].Id)
	{
		problem = `the issue ${issues[0].Id} does not link to the call ${calls[0].Id}`;
	}
	return problem;
}

async function main()
{
	const {report, exitWhenAnyFailed} = createCheckReport();
	const startedAt = soqlTimeOneSecondAgo();
	const org = getOrgInfo();
	try
	{
		const response = await postJson(org, ENDPOINT, '{}');
		report('84c-1', response.status === HTTP_INTERNAL_SERVER_ERROR && hasBothMessages(response.answer),
				`status ${response.status}, body ${response.answer.slice(0, BODY_PREVIEW_CHARACTERS)}`);

		const calls = findCalls(startedAt);
		report('84c-2', isOneFailedCallWithoutRetry(calls), `call records: ${JSON.stringify(calls)}`);

		const issues = findIssues(startedAt);
		report('84c-3', isOneLeanIssueOfTheCall(issues, calls), `issues: ${JSON.stringify(issues)}`);
	}
	finally
	{
		await waitForLogEntries();
		const calls = findCalls(startedAt);
		const issues = findIssues(startedAt);
		const unexpected = describeUnexpectedRows(calls, issues);
		if(unexpected)
		{
			report('84c-cleanup', false, `${unexpected}; nothing was deleted. Calls: ${JSON.stringify(calls)}, issues: ${JSON.stringify(issues)}`);
		}
		else
		{
			deleteIssuesThenCalls({issueIds: [issues[0].Id], callIds: [calls[0].Id], serviceName: SERVICE_NAME, since: startedAt});
			const left = countLeft(startedAt);
			report('84c-cleanup', left.calls + left.issues + left.logEntries === 0, `left behind: ${JSON.stringify(left)}`);
		}
	}
	exitWhenAnyFailed();
}

runSection('84c', main);
