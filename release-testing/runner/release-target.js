// SPDX-License-Identifier: BUSL-1.1
// One rule for everything that writes release-testing results: `results/current-run.json` is the record of a
// release-testing cycle, and only a run against an org that has the package installed may write it. Such an org gives
// the package a namespace prefix; a development org that holds the source with no namespace does not. The journeys
// divert a run against any other org to a second file, and the runner scripts, whose checks only mean something
// against the installed package, stop before they write or run anything.
const path = require('path');

const ALIAS_VARIABLE = 'SF_SUBSCRIBER_ORG_ALIAS';
// The escape sequences a terminal uses for colour, which can wrap the JSON the command line prints.
// eslint-disable-next-line no-control-regex
const COLOUR_CODES = /\x1B\[[0-9;]*[a-zA-Z]/g;
const CLOSING_FULL_STOP = /\.$/;
// Runs the journeys alone; their reporter sends a run against any other org to the development results.
const JOURNEYS_COMMAND = 'npm run test:e2e';
const RESULTS_DIRECTORY = path.join(__dirname, '..', 'results');
// The record of a release-testing cycle.
const RECORDED_RESULTS_PATH = path.join(RESULTS_DIRECTORY, 'current-run.json');
// Where a journey run against any other org goes; git ignores it.
const DEVELOPMENT_RESULTS_PATH = path.join(RESULTS_DIRECTORY, 'development-run.json');

/**
 * @description Raised when a runner script is pointed at an org without the package installed, so a caller can print
 * the message alone instead of a stack trace.
 */
class ReleaseTargetError extends Error
{
	constructor(message)
	{
		super(message);
		this.name = 'ReleaseTargetError';
	}
}

/**
 * @description Whether a run against this org belongs in the record of a release-testing cycle.
 *
 * @param {*} namespacePrefix The namespace prefix the org gives the package ('kern__'), empty when it has none.
 * Anything that is not text counts as none: the record is the file that must never be written by mistake.
 *
 * @returns {boolean}
 */
function isReleaseTarget(namespacePrefix)
{
	return typeof namespacePrefix === 'string' && namespacePrefix.length > 0;
}

/**
 * @description The results file a run against this org belongs in.
 *
 * @param {*} namespacePrefix The namespace prefix the org gives the package, empty when it has none.
 *
 * @returns {string}
 */
function resolveResultsPath(namespacePrefix)
{
	return isReleaseTarget(namespacePrefix) ? RECORDED_RESULTS_PATH : DEVELOPMENT_RESULTS_PATH;
}

/**
 * @description What the Salesforce CLI said about a failed command: the `message` of the JSON it printed, read through
 * any colour codes a terminal wrapped it in.
 *
 * @param {Error} error What the command failed with; `stdout` holds the command line's own answer.
 *
 * @returns {string|undefined} The message, or undefined when there is no answer to read or it holds none.
 */
function readCommandLineAnswer(error)
{
	try
	{
		return JSON.parse(String(error.stdout).replace(COLOUR_CODES, '')).message;
	}
	catch
	{
		return undefined;
	}
}

/**
 * @description The one line worth repeating from a failed command: the first line of what the Salesforce CLI said,
 * or of the error itself when the command line said nothing that can be read.
 *
 * @param {Error} error What the question to the org failed with.
 *
 * @returns {string} The line in round brackets with a leading space and no closing full stop, or an empty string when
 * the failure carries no words.
 */
function describeFailedQuestion(error)
{
	const words = String(readCommandLineAnswer(error) || error.message || '');
	const detailLine = words.split('\n').map((line) => line.trim()).find(Boolean);
	return detailLine ? ` (${detailLine.replace(CLOSING_FULL_STOP, '')})` : '';
}

/**
 * @description Whether an error is a command that failed, as `execSync` reports one, and not a mistake in the code.
 *
 * @param {*} error What was thrown.
 *
 * @returns {boolean}
 */
function isFailedCommand(error)
{
	return error instanceof Error && ('stdout' in error || 'status' in error);
}

/**
 * @description Asks the org which namespace it gives the package, and turns a question that fails into a refusal
 * with words a person can act on.
 *
 * @param {string} alias The alias the runner was pointed at.
 * @param {function(): string} readNamespacePrefix Asks the org; throws when the org cannot be asked.
 *
 * @returns {string} The namespace prefix, empty when the org has none.
 */
function askNamespacePrefix(alias, readNamespacePrefix)
{
	try
	{
		return readNamespacePrefix();
	}
	catch(error)
	{
		// A mistake in the code is not the org's fault: it goes on untouched, with its stack trace.
		if(!isFailedCommand(error))
		{
			throw error;
		}
		const reason = `The release runner is pointed at the org "${alias}", which could not be asked whether it has the package installed${describeFailedQuestion(error)}.`;
		throw new ReleaseTargetError(`${reason} Nothing was written. Check that ${ALIAS_VARIABLE} names an org that is open, then run again.`);
	}
}

/**
 * @description Stops a runner script that is pointed at an org without the package installed, or at one that
 * cannot be asked.
 *
 * @param {string} alias The alias the runner was pointed at.
 * @param {function(): string} readNamespacePrefix Asks the org which namespace prefix it gives the package.
 */
function assertReleaseTarget(alias, readNamespacePrefix)
{
	if(isReleaseTarget(askNamespacePrefix(alias, readNamespacePrefix)))
	{
		return;
	}
	const evidence = 'it holds the framework\'s classes with no namespace, or not at all';
	const reason = `The release runner is pointed at the org "${alias}", which does not have the package installed: ${evidence}.`;
	const remedy = `Set ${ALIAS_VARIABLE} to the alias of an org with the package installed, then run again.`;
	const developmentResults = `release-testing/results/${path.basename(DEVELOPMENT_RESULTS_PATH)}`;
	const alternative = `To try the journeys on this org, run "${JOURNEYS_COMMAND}"; their results go to ${developmentResults}.`;
	throw new ReleaseTargetError(`${reason} Nothing was written. ${remedy} ${alternative}`);
}

module.exports = {RESULTS_DIRECTORY, RECORDED_RESULTS_PATH, DEVELOPMENT_RESULTS_PATH, ReleaseTargetError, isReleaseTarget, resolveResultsPath, assertReleaseTarget};
