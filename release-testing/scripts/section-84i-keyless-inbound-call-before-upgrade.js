#!/usr/bin/env node
// SPDX-License-Identifier: Apache-2.0
/**
 * Section 84i: an inbound request without an Idempotency-Key, failed while the org is still on the released 1.8.0-11
 *
 * Run on the upgrade leg's org between the two installs, while the org is on 1.8.0-11. Version 1.8 records the hash of
 * a request's body only when the request carries an Idempotency-Key, and it writes no issue for an inbound call. So a
 * call 1.8 saved for a request without a key has no key and no hash, and no issue. Version 1.9 can run the request of
 * such a call again only when the call kept the request whole. Section 84j, after the upgrade, makes an issue on this
 * call by hand and runs it again.
 *
 * API_RetryLiveOnHold fails every request while an Account named "RetryLive hold" exists (the hold), and otherwise
 * answers status 200 with the body it received.
 *   84i-1. Hold on. A body sent without a key fails. Exactly one call was saved for it: Failed, with no Idempotency-Key,
 *          no hash of the body, and the body whole (the same text that was sent).
 *   84i-2. Version 1.8 wrote no issue for the request.
 * When both checks pass, the script prints SECTION84 PENDING with the command for section 84j. When a check fails, it
 * deletes the call of this run and the log entries, and says so; section 84j is not run. The hold is removed in every
 * case.
 *
 * Prerequisites:
 *   - the org is on 1.8.0-11, and the candidate is not installed yet
 *   - API_RetryLiveOnHold, REST_RetryLiveOnHold and kern__ApiSetting.RetryLiveOnHold deployed (the RUNBOOK 1.3b step)
 *   - the running user holds the Kern Administrator permission set (Delete API Records, for the cleanup on a failure)
 *   - no Account named "RetryLive hold" left from an earlier run
 *   - SF_SUBSCRIBER_ORG_ALIAS names the upgrade leg's org
 *   - Node 22 (global fetch)
 *
 * Run:
 *   SF_SUBSCRIBER_ORG_ALIAS=KernUpgradeSubscriber node release-testing/scripts/section-84i-keyless-inbound-call-before-upgrade.js
 *   then, after the upgrade and the 1.4 deploy, the section 84j command this script prints
 * Prints one SECTION84 PASS or SECTION84 FAIL line per check and exits 1 when any check failed.
 */

const {randomUUID} = require('crypto');
const {soqlQuery, executeAnonymousApex} = require('../e2e/helpers/sf-cli');
const {getSubscriberOrgAlias} = require('../runner/subscriber-config');
const {
	BODY_PREVIEW_CHARACTERS, field, soqlTimeOneSecondAgo, getOrgInfo, postJson, findServiceRows, deleteIssuesThenCalls, waitForLogEntries,
	createCheckReport, runSection
} = require('./inbound-issue-live/org-and-report');

const ENDPOINT = '/services/apexrest/v1/retry-live-on-hold';
const SERVICE_NAME = 'API_RetryLiveOnHold';
// The hold Account's name, mirrored from API_RetryLiveOnHold's constant.
const HOLD_ACCOUNT_NAME = 'RetryLive hold';
// The subscriber org's Account rule asks for a phone or a website.
const HOLD_ACCOUNT_PHONE = '555-0100';
// The subscriber org's Account rule asks for an Industry too.
const HOLD_ACCOUNT_INDUSTRY = 'Technology';
// Any status from 400 up means the request failed.
const HTTP_FIRST_FAILURE_STATUS = 400;
const STATUS_FAILED = 'Failed';

function findCalls(startedAt)
{
	return findServiceRows('kern__ApiCall__c', ['kern__Status__c', 'kern__Request__c', 'kern__IdempotencyKey__c', 'kern__IdempotencyKeyBodyHash__c', 'kern__URL__c'],
			SERVICE_NAME, startedAt);
}

function findIssues(startedAt)
{
	return findServiceRows('kern__ApiIssue__c', ['kern__Status__c', 'kern__ApiCall__c'], SERVICE_NAME, startedAt);
}

function setHold(isOn)
{
	executeAnonymousApex(isOn
			? `insert new Account(Name = '${HOLD_ACCOUNT_NAME}', Phone = '${HOLD_ACCOUNT_PHONE}', Industry = '${HOLD_ACCOUNT_INDUSTRY}');`
			: `delete [SELECT Id FROM Account WHERE Name = '${HOLD_ACCOUNT_NAME}'];`);
}

/**
 * @description Whether a call is Failed, has no Idempotency-Key and no hash of its body, and holds the body that was sent.
 *
 * @param {object} call The call as read from the org.
 * @param {string} body The body the request sent.
 *
 * @returns {boolean} True when it is.
 */
function isFailedCallWithoutKeyOrHash(call, body)
{
	return call[field('Status__c')] === STATUS_FAILED && !call[field('IdempotencyKey__c')] && !call[field('IdempotencyKeyBodyHash__c')]
			&& call[field('Request__c')] === body;
}

/**
 * @description Prints the calls made since the run started for this endpoint under any service name. Used when no call was
 * found by the service name, so the person can see where the request went. It deletes nothing.
 *
 * @param {string} startedAt The time the run started, as a SOQL date and time.
 */
function printCallsOfOtherServices(startedAt)
{
	const serviceField = field('ServiceName__c');
	const calls = soqlQuery(`SELECT Id, ${serviceField} FROM ${field('ApiCall__c')} WHERE ${field('URL__c')} LIKE '%retry-live-on-hold%'`
			+ ` AND CreatedDate >= ${startedAt}`);
	calls.forEach((call) => console.log(`SECTION84 84i: call ${call.Id} has service name ${call[serviceField]}; left for you to delete`));
}

/**
 * @description 84i-1: with the hold on, a body without a key fails, and exactly one call holds it as version 1.8 saves it.
 *
 * @param {object} run The state of this run: the start time and the org.
 *
 * @returns {Promise<object[]>} The calls the request wrote.
 */
async function checkKeylessFailure(run)
{
	const body = JSON.stringify({leg: 'keyless-before-upgrade', value: randomUUID()});
	setHold(true);
	const {status, answer} = await postJson(run.org, ENDPOINT, body);
	const calls = findCalls(run.startedAt);
	if(calls.length === 0)
	{
		printCallsOfOtherServices(run.startedAt);
	}
	const isOneSavedAsExpected = calls.length === 1 && isFailedCallWithoutKeyOrHash(calls[0], body);
	run.report('84i-1', status >= HTTP_FIRST_FAILURE_STATUS && isOneSavedAsExpected,
			`status ${status}, answer ${answer.slice(0, BODY_PREVIEW_CHARACTERS)}, sent ${body}, calls ${JSON.stringify(calls)}`);
	return calls;
}

/**
 * @description 84i-2: version 1.8 wrote no issue for the request.
 *
 * @param {object} run The state of this run.
 */
function checkNoIssue(run)
{
	const issues = findIssues(run.startedAt);
	run.report('84i-2', issues.length === 0, `issues ${JSON.stringify(issues)}`);
}

/**
 * @description Prints the section 84j command with the time this run started and the call it saved.
 *
 * @param {object} run The state of this run.
 * @param {object} call The call 84i-1 found.
 */
function printHandOff(run, call)
{
	const command = [`SF_SUBSCRIBER_ORG_ALIAS=${getSubscriberOrgAlias()} node release-testing/scripts/section-84j-keyless-inbound-replay-after-upgrade.js`,
		`--since ${run.startedAt}`, `--call ${call.Id}`].join(' ');
	console.log(`SECTION84 PENDING 84j: the call ${call.Id} was saved by 1.8 with no key and no hash. After the upgrade to the candidate `
			+ `and the 1.4 deploy, run: ${command}`);
}

/**
 * @description Deletes the calls of this run, then its log entries, when a check failed.
 *
 * @param {object} run The state of this run.
 */
async function deleteRunRows(run)
{
	await waitForLogEntries();
	const issueIds = findIssues(run.startedAt).map((issue) => issue.Id);
	const callIds = findCalls(run.startedAt).map((call) => call.Id);
	deleteIssuesThenCalls({issueIds, callIds, serviceName: SERVICE_NAME, since: run.startedAt});
	console.log(`SECTION84 84i: deleted ${issueIds.length} issues, then ${callIds.length} calls and the log entries of this run; do not run section 84j`);
}

async function main()
{
	const checks = createCheckReport();
	const run = {startedAt: soqlTimeOneSecondAgo(), org: getOrgInfo(), report: checks.report};
	let isHandedOff = false;
	try
	{
		const calls = await checkKeylessFailure(run);
		checkNoIssue(run);
		if(checks.failedCount() === 0)
		{
			printHandOff(run, calls[0]);
			isHandedOff = true;
		}
	}
	finally
	{
		setHold(false);
		if(!isHandedOff)
		{
			await deleteRunRows(run);
		}
	}
	checks.exitWhenAnyFailed();
}

runSection('84i', main);
