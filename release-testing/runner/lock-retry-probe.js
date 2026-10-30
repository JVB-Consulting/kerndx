#!/usr/bin/env node
// SPDX-License-Identifier: Apache-2.0
/**
 * @description Lock-retry probe: proves the DML builder's retry-on-lock dial against a real row lock, which no
 * Apex test can produce because every transaction a test starts shares the test's own lock. One transaction
 * (the holder, a queueable in the subscriber tree) selects an Account FOR UPDATE and keeps its transaction alive
 * for about thirty seconds; a second transaction (the caller, anonymous Apex) updates the same row with
 * withRetryOnLock(2). The platform refuses the caller twice, about ten seconds each, and the third attempt saves
 * once the holder lets go. The runner then reads the WARN entry the retried commit wrote and checks it carries
 * two retries used. The elapsed time it reports is the hold minus the few seconds the CLI spends before the
 * caller starts, about twenty-five seconds with the default hold.
 *
 * Usage:
 *   node release-testing/runner/lock-retry-probe.js --org <alias>                  # namespaced subscriber org
 *   node release-testing/runner/lock-retry-probe.js --org <alias> --no-namespace   # unmanaged deploy, no kern. prefix
 *
 * Prints one verdict line, PASS or FAIL, and exits 0 or 1. Requires LockRetryProbeHolder deployed to the org.
 *
 * @author Kern Framework
 */

const {execFileSync} = require('child_process');
const fs = require('fs');
const path = require('path');

const HOLDER_SCRIPT = path.join(__dirname, '..', 'scripts', 'lock-retry-holder.apex');
const CALLER_SCRIPT = path.join(__dirname, '..', 'scripts', 'lock-retry-caller.apex');
const CALLER_COPY = path.join(__dirname, '..', '..', 'tmp', 'lock-retry-caller.apex');
const HOLDER_CLASS = 'LockRetryProbeHolder';
const JOB_STATUS_PROCESSING = 'Processing';
const JOB_WAIT_SECONDS = 60;
const LOG_PERSIST_WAIT_MILLISECONDS = 5000;
const ELAPSED_MINIMUM_MILLISECONDS = 19000;
const ELAPSED_MAXIMUM_MILLISECONDS = 40000;
const EXPECTED_RETRIES_USED = 2;
const CLI_OUTPUT_PREVIEW_CHARACTERS = 500;

/**
 * @description Reads the two command-line options.
 *
 * @return {{org: string, noNamespace: boolean}} The org alias and whether the org has no namespace prefix.
 */
function parseArguments()
{
	const args = process.argv.slice(2);
	const orgIndex = args.indexOf('--org');
	if(orgIndex === -1 || !args[orgIndex + 1])
	{
		console.error('Usage: node release-testing/runner/lock-retry-probe.js --org <alias> [--no-namespace]');
		process.exit(1);
	}
	return {org: args[orgIndex + 1], noNamespace: args.includes('--no-namespace')};
}

/**
 * @description Runs an sf command and returns its parsed JSON result, tolerating a non-zero exit so the caller
 * can read the failure. Arguments go to the CLI as an array, never through a shell.
 *
 * @param {string[]} args The sf arguments, without --json.
 * @return {object} The parsed JSON the CLI printed.
 */
function runJson(args)
{
	let output;
	try
	{
		output = execFileSync('sf', [
			...args,
			'--json'
		], {
			encoding: 'utf8', stdio: [
				'ignore',
				'pipe',
				'pipe'
			]
		});
	}
	catch(error)
	{
		output = error.stdout || '';
	}
	try
	{
		return JSON.parse(output);
	}
	catch(parseError)
	{
		return {status: 1, message: 'Unparseable CLI output (' + parseError.message + '): ' + output.slice(0, CLI_OUTPUT_PREVIEW_CHARACTERS)};
	}
}

/**
 * @description Runs an anonymous Apex file and returns the debug log text.
 *
 * @param {string} file The .apex file to run.
 * @param {string} org The org alias.
 * @return {string} The execution log, empty when the run failed to compile or execute.
 */
function runApex(file, org)
{
	const result = runJson([
		'apex',
		'run',
		'--file',
		file,
		'-o',
		org
	]);
	const apexResult = result.result || {};
	if(result.status !== 0 || apexResult.success === false || apexResult.compiled === false)
	{
		const reason = apexResult.compileProblem || apexResult.exceptionMessage || result.message || JSON.stringify(result).slice(0, CLI_OUTPUT_PREVIEW_CHARACTERS);
		console.error('Anonymous Apex failed: ' + reason);
		return '';
	}
	return apexResult.logs || '';
}

/**
 * @description Runs a SOQL query and returns its records.
 *
 * @param {string} soql The query.
 * @param {string} org The org alias.
 * @return {object[]} The records, empty on failure.
 */
function query(soql, org)
{
	const result = runJson([
		'data',
		'query',
		'-o',
		org,
		'-q',
		soql
	]);
	return (result.result && result.result.records) || [];
}

/**
 * @description Blocks for the given time.
 *
 * @param {number} milliseconds How long to wait.
 */
function sleep(milliseconds)
{
	Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, milliseconds);
}

/**
 * @description Waits until the holder job is running, so the lock is held before the caller starts.
 *
 * @param {string} org The org alias.
 * @return {boolean} True when the job reached Processing within the wait.
 */
function waitForHolderToRun(org)
{
	const soql = 'SELECT Status FROM AsyncApexJob'
		+ ` WHERE ApexClass.Name = '${HOLDER_CLASS}'`
		+ ' ORDER BY CreatedDate DESC LIMIT 1';
	for(let second = 0; second < JOB_WAIT_SECONDS; second++)
	{
		const records = query(soql, org);
		if(records.length > 0 && records[0].Status === JOB_STATUS_PROCESSING)
		{
			return true;
		}
		sleep(1000);
	}
	return false;
}

/**
 * @description Writes the caller script the org can compile: the kern. prefix stays for a namespaced org and is
 * removed for an unmanaged deploy.
 *
 * @param {boolean} noNamespace Whether the org has no namespace prefix.
 * @return {string} The path of the script to run.
 */
function prepareCallerScript(noNamespace)
{
	if(!noNamespace)
	{
		return CALLER_SCRIPT;
	}
	fs.mkdirSync(path.dirname(CALLER_COPY), {recursive: true});
	fs.writeFileSync(CALLER_COPY, fs.readFileSync(CALLER_SCRIPT, 'utf8').replace(/kern\./g, ''));
	return CALLER_COPY;
}

/**
 * @description Reads the context of the latest WARN entry the retried commit wrote.
 *
 * @param {string} org The org alias.
 * @param {boolean} noNamespace Whether the org has no namespace prefix.
 * @return {string} The raw context JSON, empty when no entry was found.
 */
function readLatestRetryWarning(org, noNamespace)
{
	const prefix = noNamespace ? '' : 'kern__';
	// The clauses are named so the statement below stays short: the editor reformats a long query it can read,
	// and that would change the text this tool sends to the org.
	const contextField = `${prefix}ContextData__c`;
	const entryObject = `${prefix}LogEntry__c`;
	const warningFilter = `${prefix}LogLevel__c = 'WARN' AND ${prefix}ClassMethod__c LIKE '%DML_Transaction.commitWork'`;
	const newestFirst = 'ORDER BY CreatedDate DESC LIMIT 1';
	const soql = `SELECT ${contextField} FROM ${entryObject} WHERE ${warningFilter} ${newestFirst}`;
	const records = query(soql, org);
	return records.length > 0 ? (records[0][prefix + 'ContextData__c'] || '') : '';
}

/**
 * @description Runs the probe end to end and prints the verdict.
 */
function main()
{
	const {org, noNamespace} = parseArguments();

	const holderLog = runApex(HOLDER_SCRIPT, org);
	const accountMatch = holderLog.match(/LOCK_RETRY_PROBE_ACCOUNT=(\w+)/);
	if(!accountMatch)
	{
		console.log('FAIL: the holder transaction did not report the probe account');
		process.exit(1);
	}

	if(!waitForHolderToRun(org))
	{
		console.log(`FAIL: the holder job did not reach ${JOB_STATUS_PROCESSING} within ${JOB_WAIT_SECONDS} seconds`);
		process.exit(1);
	}
	sleep(1000);

	const callerLog = runApex(prepareCallerScript(noNamespace), org);
	const resultMatch = callerLog.match(/LOCK_RETRY_PROBE_RESULT success=(true|false) elapsedMs=(\d+)/);
	if(!resultMatch)
	{
		console.log('FAIL: the caller transaction did not report a result');
		process.exit(1);
	}
	const success = resultMatch[1] === 'true';
	const elapsed = Number(resultMatch[2]);

	sleep(LOG_PERSIST_WAIT_MILLISECONDS);
	const context = readLatestRetryWarning(org, noNamespace);
	const retriesMatch = context.match(/"retriesUsed"\s*:\s*"?(\d+)"?/);
	const retriesUsed = retriesMatch ? Number(retriesMatch[1]) : null;

	const observed = `success=${success} elapsedMs=${elapsed}`
		+ ` retriesUsed=${retriesUsed === null ? 'none' : retriesUsed} account=${accountMatch[1]}`;
	const elapsedInRange = elapsed >= ELAPSED_MINIMUM_MILLISECONDS && elapsed <= ELAPSED_MAXIMUM_MILLISECONDS;
	if(success && elapsedInRange && retriesUsed === EXPECTED_RETRIES_USED)
	{
		console.log(`PASS: ${observed}`);
		process.exit(0);
	}
	const expected = `success=true, elapsedMs between ${ELAPSED_MINIMUM_MILLISECONDS} and ${ELAPSED_MAXIMUM_MILLISECONDS}`
		+ `, retriesUsed=${EXPECTED_RETRIES_USED}`;
	console.log(`FAIL: ${observed} (expected ${expected})`);
	process.exit(1);
}

if(require.main === module)
{
	main();
}

module.exports = {parseArguments, runJson, waitForHolderToRun, prepareCallerScript, readLatestRetryWarning};
