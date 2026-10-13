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
 *   84c-cleanup. The call records, any issue and the log entries the request wrote are deleted, and a query proves none
 *          is left.
 *
 * Prerequisites:
 *   - API_RetryLiveInbound and REST_RetryLiveInbound deployed, kern__ApiSetting.RetryLiveInbound deployed
 *   - Node 22 (global fetch)
 *
 * Run:
 *   node release-testing/scripts/section-84c-inbound-error-handling-live.js
 * Prints one SECTION84 PASS or SECTION84 FAIL line per check and exits 1 when any check failed.
 */

const {execFileSync} = require('child_process');
const {soqlQuery, executeAnonymousApex} = require('../e2e/helpers/sf-cli');
const {namespacePrefix, rewriteNamespaceLiterals} = require('../e2e/helpers/sf-namespace');
const {getSubscriberOrgAlias} = require('../runner/subscriber-config');

const ORG_ALIAS = getSubscriberOrgAlias();
const ENDPOINT = '/services/apexrest/v1/retry-live-inbound';
const SERVICE_NAME = 'API_RetryLiveInbound';
// The two messages API_RetryLiveInbound throws, mirrored from its constants.
const MESSAGE_PROCESSING_THREW = 'RetryLiveInbound: the processing threw on purpose';
const MESSAGE_ERROR_HANDLING_THREW = 'RetryLiveInbound: the error handling threw on purpose';
const HTTP_INTERNAL_SERVER_ERROR = 500;
// How much of the answer the check prints.
const BODY_PREVIEW_CHARACTERS = 400;
const STATUS_FAILED = 'Failed';
// Log entries are written from a platform event after the request ends, so the cleanup waits for them to land.
const LOG_SETTLE_MILLISECONDS = 15_000;

function forOrg(query)
{
	return rewriteNamespaceLiterals(query, namespacePrefix());
}

function getOrgInfo()
{
	const result = JSON.parse(execFileSync('sf', ['org', 'display', '-o', ORG_ALIAS, '--json'], {encoding: 'utf8'})).result;
	let accessToken = result.accessToken;
	// Newer Salesforce CLI redacts the access token in `org display` output; the redacted form fails REST with 401.
	if(!accessToken || accessToken.includes('REDACTED'))
	{
		accessToken = JSON.parse(execFileSync('sf', ['org', 'auth', 'show-access-token', '-o', ORG_ALIAS, '--json'], {encoding: 'utf8'})).result.accessToken;
	}
	return {instanceUrl: result.instanceUrl, accessToken};
}

function countLeft(startedAt)
{
	const since = `CreatedDate >= ${startedAt}`;
	return {
		calls: soqlQuery(forOrg(`SELECT Id FROM kern__ApiCall__c WHERE kern__ServiceName__c = '${SERVICE_NAME}' AND ${since}`)).length,
		issues: soqlQuery(forOrg(`SELECT Id FROM kern__ApiIssue__c WHERE kern__ServiceName__c = '${SERVICE_NAME}' AND ${since}`)).length,
		logEntries: soqlQuery(forOrg(`SELECT Id FROM kern__LogEntry__c WHERE kern__ClassMethod__c LIKE '%${SERVICE_NAME}%' AND ${since}`)).length
	};
}

function deleteRows(startedAt)
{
	const since = `CreatedDate >= ${startedAt}`;
	executeAnonymousApex(`delete [SELECT Id FROM kern__ApiIssue__c WHERE kern__ServiceName__c = '${SERVICE_NAME}' AND ${since}];`
			+ ` delete [SELECT Id FROM kern__ApiCall__c WHERE kern__ServiceName__c = '${SERVICE_NAME}' AND ${since}];`
			+ ` delete [SELECT Id FROM kern__LogEntry__c WHERE kern__ClassMethod__c LIKE '%${SERVICE_NAME}%' AND ${since}];`);
}

async function main()
{
	let failed = 0;
	const report = (id, isPassing, message) =>
	{
		console.log(`SECTION84 ${isPassing ? 'PASS' : 'FAIL'} ${id}: ${message}`);
		failed += isPassing ? 0 : 1;
	};

	const startedAt = new Date(Date.now() - 1000).toISOString().replace(/\.\d{3}Z$/, 'Z');
	const {instanceUrl, accessToken} = getOrgInfo();
	try
	{
		const response = await fetch(`${instanceUrl}${ENDPOINT}`, {
			method: 'POST', headers: {'Authorization': `Bearer ${accessToken}`, 'Content-Type': 'application/json'}, body: '{}'
		});
		const body = await response.text();
		report('84c-1', response.status === HTTP_INTERNAL_SERVER_ERROR && body.includes(MESSAGE_PROCESSING_THREW) && body.includes(MESSAGE_ERROR_HANDLING_THREW),
				`status ${response.status}, body ${body.slice(0, BODY_PREVIEW_CHARACTERS)}`);

		const calls = soqlQuery(forOrg('SELECT Id, kern__Status__c, kern__NextRetry__c FROM kern__ApiCall__c '
				+ `WHERE kern__ServiceName__c = '${SERVICE_NAME}' AND CreatedDate >= ${startedAt}`));
		const prefix = namespacePrefix();
		report('84c-2', calls.length === 1 && calls[0][`${prefix}Status__c`] === STATUS_FAILED && !calls[0][`${prefix}NextRetry__c`], `call records: ${JSON.stringify(calls)}`);
	}
	finally
	{
		await new Promise((resolve) => setTimeout(resolve, LOG_SETTLE_MILLISECONDS));
		deleteRows(startedAt);
		const left = countLeft(startedAt);
		report('84c-cleanup', left.calls + left.issues + left.logEntries === 0, `left behind: ${JSON.stringify(left)}`);
	}

	if(failed > 0)
	{
		process.exit(1);
	}
}

main().catch((error) =>
{
	console.error(`SECTION84 FAIL 84c: ${error.message}`);
	process.exit(1);
});
