// SPDX-License-Identifier: BUSL-1.1
// What sections 84c, 84g and 84h share: the org's session for REST calls, the queries on one service's calls, issues
// and log entries, the delete that removes issues before their calls, and the PASS and FAIL lines each check prints.
const {execFileSync} = require('child_process');
const {soqlQuery, executeAnonymousApex} = require('../../e2e/helpers/sf-cli');
const {namespacePrefix, rewriteNamespaceLiterals} = require('../../e2e/helpers/sf-namespace');
const {getSubscriberOrgAlias} = require('../../runner/subscriber-config');

const ORG_ALIAS = getSubscriberOrgAlias();
// Log entries are written from a platform event after each request ends, so a cleanup waits for them to land.
const LOG_SETTLE_MILLISECONDS = 15_000;
// How much of an answer a check prints.
const BODY_PREVIEW_CHARACTERS = 400;
const STATUS_OPEN = 'Open';
const STATUS_RESOLVED = 'Resolved';
const DIRECTION_INBOUND = 'Inbound';

/**
 * @description Rewrites the `kern__` names in a query to the org's own: stripped on the development org.
 *
 * @param {string} query The query as written in the script.
 *
 * @returns {string} The query for the org.
 */
function forOrg(query)
{
	return rewriteNamespaceLiterals(query, namespacePrefix());
}

/**
 * @description The name a row read from the org uses for a field of the package.
 *
 * @param {string} name The field's name without a namespace.
 *
 * @returns {string} The field's name with the org's namespace, if it has one.
 */
function field(name)
{
	return `${namespacePrefix()}${name}`;
}

/**
 * @description The time one second ago, written as SOQL writes a date and time, so a query finds every row the section
 * writes from now on.
 *
 * @returns {string} The time, for example 2026-10-19T12:50:47Z.
 */
function soqlTimeOneSecondAgo()
{
	return new Date(Date.now() - 1000).toISOString().replace(/\.\d{3}Z$/, 'Z');
}

/**
 * @description Runs one `sf` command on the org with `--json` and returns the `result` part of its answer.
 *
 * @param {string[]} commandArguments The arguments after `sf`, without the org and `--json`.
 *
 * @returns {object} The answer's result.
 */
function readCommandResult(commandArguments)
{
	return JSON.parse(execFileSync('sf', [...commandArguments, '-o', ORG_ALIAS, '--json'], {encoding: 'utf8'})).result;
}

/**
 * @description Whether an access token can be used for REST calls. Newer Salesforce CLI redacts the token in
 * `org display`, and the redacted form fails REST with 401.
 *
 * @param {string} [accessToken] The token `org display` gave, if any.
 *
 * @returns {boolean} True when it can be used.
 */
function isUsableToken(accessToken)
{
	return Boolean(accessToken) && !accessToken.includes('REDACTED');
}

/**
 * @description Reads the org's address and an access token for REST calls.
 *
 * @returns {{instanceUrl: string, accessToken: string}} The org's address and the token.
 */
function getOrgInfo()
{
	const display = readCommandResult(['org', 'display']);
	const accessToken = isUsableToken(display.accessToken) ? display.accessToken : readCommandResult(['org', 'auth', 'show-access-token']).accessToken;
	return {instanceUrl: display.instanceUrl, accessToken};
}

/**
 * @description Sends one JSON request to an Apex REST endpoint of the org, as the user the org's token belongs to.
 *
 * @param {{instanceUrl: string, accessToken: string}} org The org's address and token, from getOrgInfo.
 * @param {string} endpoint The path after the org's address.
 * @param {string} body The request body.
 * @param {string} [idempotencyKey] The Idempotency-Key header to send, or nothing to send none.
 *
 * @returns {Promise<{status: number, answer: string}>} The answer's status and body.
 */
async function postJson(org, endpoint, body, idempotencyKey)
{
	const headers = {'Authorization': `Bearer ${org.accessToken}`, 'Content-Type': 'application/json'};
	if(idempotencyKey)
	{
		headers['Idempotency-Key'] = idempotencyKey;
	}
	const response = await fetch(`${org.instanceUrl}${endpoint}`, {method: 'POST', headers, body});
	return {status: response.status, answer: await response.text()};
}

/**
 * @description Reads the rows of one service written since a time, oldest first.
 *
 * @param {string} objectName The object, as `kern__ApiCall__c` or `kern__ApiIssue__c`.
 * @param {string[]} fieldNames The fields to read besides the id, with the `kern__` namespace.
 * @param {string} serviceName The service's name.
 * @param {string} since The time, as a SOQL date and time.
 *
 * @returns {object[]} The rows.
 */
function findServiceRows(objectName, fieldNames, serviceName, since)
{
	return soqlQuery(forOrg(`SELECT Id, ${fieldNames.join(', ')} FROM ${objectName} `
			+ `WHERE kern__ServiceName__c = '${serviceName}' AND CreatedDate >= ${since} ORDER BY CreatedDate`));
}

/**
 * @description Counts the log entries of one service written since a time.
 *
 * @param {string} serviceName The service's name.
 * @param {string} since The time, as a SOQL date and time.
 *
 * @returns {number} How many there are.
 */
function countLogEntries(serviceName, since)
{
	return soqlQuery(forOrg(`SELECT Id FROM kern__LogEntry__c WHERE kern__ClassMethod__c LIKE '%${serviceName}%' AND CreatedDate >= ${since}`)).length;
}

/**
 * @description Deletes the given issues first, then the given calls, then the log entries of the service since a time.
 * A call with an Open issue cannot be deleted, so the order matters.
 *
 * @param {object} rows What to delete.
 * @param {string[]} rows.issueIds The issues.
 * @param {string[]} rows.callIds The calls.
 * @param {string} rows.serviceName The service whose log entries go too.
 * @param {string} rows.since When the section started, as a SOQL date and time.
 * @param {string} [rows.moreApex] More Apex to run after the deletes, in the same run.
 */
function deleteIssuesThenCalls({issueIds, callIds, serviceName, since, moreApex = ''})
{
	const quoted = (ids) => ids.map((id) => `'${id}'`).join(',');
	executeAnonymousApex([
		issueIds.length ? `delete [SELECT Id FROM kern__ApiIssue__c WHERE Id IN (${quoted(issueIds)})];` : '',
		callIds.length ? `delete [SELECT Id FROM kern__ApiCall__c WHERE Id IN (${quoted(callIds)})];` : '',
		`delete [SELECT Id FROM kern__LogEntry__c WHERE kern__ClassMethod__c LIKE '%${serviceName}%' AND CreatedDate >= ${since}];`,
		moreApex
	].filter(Boolean).join(' '));
}

/**
 * @description Waits until the log entries of the requests sent so far have been written.
 *
 * @returns {Promise<void>} Done when the wait is over.
 */
function waitForLogEntries()
{
	return new Promise((resolve) => setTimeout(resolve, LOG_SETTLE_MILLISECONDS));
}

/**
 * @description Whether an issue is an Open inbound issue that keeps no copy of the request (the call holds it).
 *
 * @param {object} issue The issue as read from the org.
 *
 * @returns {boolean} True when it is.
 */
function isOpenInboundIssueWithoutBody(issue)
{
	return issue[field('Status__c')] === STATUS_OPEN && issue[field('Direction__c')] === DIRECTION_INBOUND && !issue[field('RequestBody__c')];
}

/**
 * @description Whether an issue was found and is Resolved, with the date it was resolved.
 *
 * @param {object} [issue] The issue as read from the org, or nothing when it was not found.
 *
 * @returns {boolean} True when it is.
 */
function isResolvedIssue(issue)
{
	return Boolean(issue) && issue[field('Status__c')] === STATUS_RESOLVED && Boolean(issue[field('ResolvedDate__c')]);
}

/**
 * @description Prints one SECTION84 PASS or SECTION84 FAIL line per check and counts the failures.
 *
 * @returns {{report: Function, failedCount: Function, exitWhenAnyFailed: Function}} `report(id, isPassing, message)`
 *          prints a line, `failedCount()` says how many checks failed, and `exitWhenAnyFailed()` ends the process with
 *          code 1 when any did.
 */
function createCheckReport()
{
	let failed = 0;
	return {
		report(id, isPassing, message)
		{
			console.log(`SECTION84 ${isPassing ? 'PASS' : 'FAIL'} ${id}: ${message}`);
			failed += isPassing ? 0 : 1;
		},
		failedCount()
		{
			return failed;
		},
		exitWhenAnyFailed()
		{
			if(failed > 0)
			{
				process.exit(1);
			}
		}
	};
}

/**
 * @description Runs a section and, when it throws, prints a FAIL line with the reason and exits with code 1.
 *
 * @param {string} sectionId The section, as 84c.
 * @param {Function} main The section's steps; it may return a promise.
 */
function runSection(sectionId, main)
{
	Promise.resolve().then(main).catch((error) =>
	{
		console.error(`SECTION84 FAIL ${sectionId}: ${error.message}`);
		process.exit(1);
	});
}

module.exports = {
	BODY_PREVIEW_CHARACTERS, field, soqlTimeOneSecondAgo, getOrgInfo, postJson, findServiceRows, countLogEntries, deleteIssuesThenCalls,
	waitForLogEntries, isOpenInboundIssueWithoutBody, isResolvedIssue, createCheckReport, runSection
};
