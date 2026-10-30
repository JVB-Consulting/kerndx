// SPDX-License-Identifier: Apache-2.0
// Says, in words a person can act on, why the org the journeys point at cannot be used. The command line
// answers a question about a deleted scratch org without complaint, so a run pointed at one used to die
// later, inside the browser sign-in, with nothing that named the org or the variable that chooses it.

const ALIAS_VARIABLE = 'SF_SUBSCRIBER_ORG_ALIAS';
const USABLE_SCRATCH_ORG_STATUS = 'Active';
const USABLE_CONNECTION_STATUS = 'Connected';
// The name the command line gives its error for an alias it holds no authorisation for.
const UNKNOWN_ALIAS_ERROR = 'NamedOrgNotFoundError';

const NO_ANSWER_REASON = 'the Salesforce CLI gave no answer about it';

/**
 * @description Why an org the command line knows cannot be opened, or null when nothing is wrong with it.
 *
 * @param {object} result The `result` of `sf org display --json`.
 *
 * @returns {string|null}
 */
function findResultReason(result)
{
	const {status, expirationDate, connectedStatus} = result;
	if(Boolean(status) && status !== USABLE_SCRATCH_ORG_STATUS)
	{
		return expirationDate ? `it is a scratch org whose status is ${status}, and it expired on ${expirationDate}` : `it is a scratch org whose status is ${status}`;
	}

	return Boolean(connectedStatus) && connectedStatus !== USABLE_CONNECTION_STATUS ? `its connection status is ${connectedStatus}` : null;
}

// The command line opens some errors with a line that only names the flag it was parsing.
const FLAG_PREAMBLE = 'Parsing ';

/**
 * @description The one line of an error message worth repeating: the first, or the second when the first only names a flag.
 *
 * @param {string|undefined} message The command line's error message, which may run over several lines.
 *
 * @returns {string} The line, or an empty string when there is none.
 */
function findDetailLine(message)
{
	const lines = String(message || '').split('\n').map((line) => line.trim()).filter(Boolean);
	const skipPreamble = lines.length > 1 && lines[0].startsWith(FLAG_PREAMBLE);
	return (skipPreamble ? lines[1] : lines[0]) || '';
}

/**
 * @description Why the command line answered with an error. Only its own "no such org" error is reported as an alias it
 * does not know; a timeout or any other failure is named as what it is, so nobody goes looking for a missing alias.
 *
 * @param {object} display The parsed answer of `sf org display --json`, whose status is an error.
 *
 * @returns {string}
 */
function findErrorReason(display)
{
	const detailLine = findDetailLine(display.message);
	const detail = detailLine ? ` (${detailLine})` : '';
	if(display.name === UNKNOWN_ALIAS_ERROR)
	{
		return `the Salesforce CLI does not know it${detail}`;
	}

	return display.name ? `the Salesforce CLI could not answer for it: ${display.name}${detail}` : `the Salesforce CLI could not answer for it${detail}`;
}

/**
 * @description Why the org cannot be opened, as the middle of a sentence, or null when nothing is wrong with it.
 *
 * @param {object|null} display The parsed answer of `sf org display --json`, or null when there was none to parse.
 *
 * @returns {string|null}
 */
function findReason(display)
{
	if(display?.status === 0)
	{
		return display.result ? findResultReason(display.result) : NO_ANSWER_REASON;
	}

	return display ? findErrorReason(display) : NO_ANSWER_REASON;
}

/**
 * @description The whole message for an org that cannot be opened: which org, why, and what to change.
 *
 * @param {string} alias The alias the journeys were pointed at.
 * @param {object|null} display The parsed answer of `sf org display --json`, or null when there was none to parse.
 *
 * @returns {string|null} The message, or null when the org can be used.
 */
function describeOrgProblem(alias, display)
{
	const reason = findReason(display);
	if(!reason)
	{
		return null;
	}
	const remedy = `Set ${ALIAS_VARIABLE} to the alias of an org that is open, then run again.`;
	return `The journeys are pointed at the org "${alias}", which cannot be opened: ${reason}. ${remedy}`;
}

/**
 * @description Stops a run before the browser starts when the org cannot be opened.
 *
 * @param {string} alias The alias the journeys were pointed at.
 * @param {object|null} display The parsed answer of `sf org display --json`, or null when there was none to parse.
 */
function assertOrgIsUsable(alias, display)
{
	const problem = describeOrgProblem(alias, display);
	if(problem)
	{
		throw new Error(problem);
	}
}

module.exports = {describeOrgProblem, assertOrgIsUsable};
