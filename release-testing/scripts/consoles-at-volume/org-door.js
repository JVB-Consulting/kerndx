// SPDX-License-Identifier: Apache-2.0
// The driver's one door to the org: every `sf` call goes through here, with the command runner injectable for tests.
const {execFileSync} = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const OUTPUT_BUFFER_BYTES = 64 * 1024 * 1024;
// eslint-disable-next-line no-control-regex
const COLOUR_CODES = /\x1B\[[0-9;]*[a-zA-Z]/g;
const DEBUG_MARKER = '|DEBUG|';
const DEFAULT_TIMEOUT_MILLISECONDS = 600_000;
const QUERY_TIMEOUT_MILLISECONDS = 120_000;
const IMPORT_TIMEOUT_MILLISECONDS = 900_000;
const IMPORT_WAIT_MINUTES = '10';
const OUTPUT_PREVIEW_LENGTH = 400;
const RAW_ANSWER_PREVIEW_LENGTH = 600;
// A Bulk API job id: the 750 key prefix and fifteen more characters.
const BULK_JOB_ID = /\b750[0-9A-Za-z]{15}\b/;
// The fields of a cut `sf apex run --json` answer that come before the logs and are still whole.
const ANSWER_STATUS = /"status":\s*(\d+)/;
const ANSWER_EXCEPTION_MESSAGE = /"exceptionMessage":\s*"((?:[^"\\]|\\.)*)"/;
const ANSWER_COMPILE_PROBLEM = /"compileProblem":\s*"((?:[^"\\]|\\.)*)"/;
// The CLI writes at most this many bytes when a script fails, then stops.
const CUT_ANSWER_BYTES = 65_536;
// What the CLI says when its own call to the org failed in transit, with no word from the org about the script.
const TRANSPORT_FAILURE_PATTERN = /fetch failed|ECONNRESET|ECONNREFUSED|ETIMEDOUT|EAI_AGAIN|ENOTFOUND|socket hang up/i;
// A query whose call failed in transit is attempted this many times in all, with a growing wait between attempts: a
// query is safe to repeat, and one blip must not end a stage with hours of work behind it.
const QUERY_RETRY_ATTEMPTS = 3;
const QUERY_RETRY_WAIT_MILLISECONDS = 5_000;
// How runCommand names a call that printed no JSON at all, as one the timeout killed does.
const NO_JSON_PATTERN = /printed no JSON/;

/**
 * @description Whether an answer is the CLI's own transport failure: a non-zero status with no word from the org (no
 * script outcome) and a message naming a broken connection. The org's own refusals and a script's failures are not.
 *
 * @param {object} answer The parsed answer.
 *
 * @returns {boolean}
 */
function isTransportFailure(answer)
{
	return answer.status !== 0 && answer.result?.success === undefined && TRANSPORT_FAILURE_PATTERN.test(answer.message ?? '');
}

/**
 * @description Blocks the process for a while: the org door is synchronous, as its callers are, so a wait between two
 * attempts of one call blocks too.
 *
 * @param {number} milliseconds How long.
 */
function defaultSleepSync(milliseconds)
{
	Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, milliseconds);
}

/**
 * @description Runs one `sf` command and returns its parsed JSON answer, whether it exited 0 or not.
 *
 * @param {Function} execFile The command runner (child_process.execFileSync or a test double).
 * @param {string[]} commandArguments The arguments after `sf`.
 * @param {object} [options] `timeout` in milliseconds.
 *
 * @returns {object} The parsed answer, with `status` 0 on success.
 */
function runCommand(execFile, commandArguments, {timeout = DEFAULT_TIMEOUT_MILLISECONDS} = {})
{
	let output;
	try
	{
		output = execFile('sf', commandArguments, {encoding: 'utf8', timeout, maxBuffer: OUTPUT_BUFFER_BYTES, env: {...process.env, FORCE_COLOR: '0', NO_COLOR: '1'}});
	}
	catch(error)
	{
		output = `${error.stdout ?? ''}${error.stderr ?? ''}`;
	}
	const clean = String(output).replace(COLOUR_CODES, '');
	const start = clean.indexOf('{');
	if(start < 0)
	{
		throw new Error(`sf ${commandArguments.join(' ')} printed no JSON: ${clean.slice(0, OUTPUT_PREVIEW_LENGTH)}`);
	}
	const json = clean.slice(start);
	try
	{
		return JSON.parse(json);
	}
	catch(parseError)
	{
		const salvaged = salvageCutAnswer(json);
		if(salvaged)
		{
			return salvaged;
		}
		const shape = json.length >= CUT_ANSWER_BYTES ? `an answer cut short at ${json.length} characters (the CLI stops at 64 KiB)` : 'unreadable JSON';
		throw new Error(`sf ${commandArguments.join(' ')} printed ${shape} (${parseError.message}): ${json.slice(0, OUTPUT_PREVIEW_LENGTH)}`);
	}
}

/**
 * @description The outcome of a FAILED script, read from an answer the CLI cut short: `sf apex run --json` writes at
 * most 64 KiB when the script failed, so a long debug log leaves the JSON unterminated inside the logs, while the
 * status, the compile problem and the exception message come before the logs and are still whole. An answer whose
 * status says the script succeeded is never salvaged: its logs are what the caller wanted, and they are gone.
 *
 * @param {string} json The cut answer.
 *
 * @returns {object|null} An answer shaped like the CLI's, marked `cut`, or null when nothing can be read.
 */
function salvageCutAnswer(json)
{
	const status = json.match(ANSWER_STATUS);
	const exceptionMessage = json.match(ANSWER_EXCEPTION_MESSAGE);
	const compileProblem = json.match(ANSWER_COMPILE_PROBLEM);
	if(!status || Number(status[1]) === 0 || (!exceptionMessage && !compileProblem))
	{
		return null;
	}
	return {status: Number(status[1]), cut: true, result: {success: false, compileProblem: unescaped(compileProblem), exceptionMessage: unescaped(exceptionMessage)}};
}

/**
 * @description The text of a JSON string a regex captured, with its escapes resolved; the raw capture when the
 * escapes do not resolve (the cut can land anywhere).
 *
 * @param {Array|null} match The regex match, its first group the string's body.
 *
 * @returns {string}
 */
function unescaped(match)
{
	if(!match)
	{
		return '';
	}
	try
	{
		return JSON.parse(`"${match[1]}"`);
	}
	catch
	{
		return match[1];
	}
}

/**
 * @description The USER_DEBUG messages in an anonymous-Apex log, in order.
 *
 * @param {string} logs The log text the command line returned.
 *
 * @returns {string[]}
 */
function readDebugLines(logs)
{
	return String(logs).split('\n').filter((line) => line.includes('|USER_DEBUG|')).map((line) => line.slice(line.lastIndexOf(DEBUG_MARKER) + DEBUG_MARKER.length).trim());
}

/**
 * @description Builds the org door for one alias.
 *
 * @param {object} options `alias` (required), `execFile` (default execFileSync), `temporaryDirectory` (default the OS temp dir),
 *                         `sleepSync` (the blocking wait between two attempts of a query), `log` (where a retry is announced).
 *
 * @returns {object} `{alias, query, runApex, listLimits, orgDisplay, runUserId, importCsv}`.
 */
function createOrgDoor({alias, execFile = execFileSync, temporaryDirectory = os.tmpdir(), sleepSync = defaultSleepSync, log = () => {}})
{
	if(!alias)
	{
		throw new Error('createOrgDoor needs an org alias');
	}

	/**
	 * @description Runs one SOQL query and returns its rows. A call that failed in transit (the CLI's own "fetch
	 * failed", with no word from the org) is made again after a wait, a bounded number of times; a query is safe to
	 * repeat. The org's own refusal is thrown at once.
	 *
	 * @param {string} soql The query.
	 * @param {object} [options] `tooling` to query the Tooling API.
	 *
	 * @returns {{records: object[], totalSize: number}}
	 */
	function query(soql, {tooling = false} = {})
	{
		const commandArguments = [
			'data',
			'query',
			'-o',
			alias,
			'-q',
			soql,
			'--json'
		];
		if(tooling)
		{
			commandArguments.push('--use-tooling-api');
		}
		for(let attempt = 1; ; attempt++)
		{
			let answer;
			try
			{
				answer = runCommand(execFile, commandArguments, {timeout: QUERY_TIMEOUT_MILLISECONDS});
			}
			catch(failure)
			{
				// A call the timeout killed prints nothing at all; that too is a broken connection, not the org's word.
				if(!NO_JSON_PATTERN.test(failure.message) || attempt >= QUERY_RETRY_ATTEMPTS)
				{
					throw failure;
				}
				answer = {status: 1, message: 'the call printed no answer'};
			}
			if(answer.status === 0)
			{
				return {records: answer.result?.records ?? [], totalSize: answer.result?.totalSize ?? 0};
			}
			const inTransit = answer.result === undefined && (isTransportFailure(answer) || answer.message === 'the call printed no answer');
			if(!inTransit || attempt >= QUERY_RETRY_ATTEMPTS)
			{
				throw new Error(`The query failed: ${answer.message ?? 'no message'}\n${soql}`);
			}
			const wait = QUERY_RETRY_WAIT_MILLISECONDS * attempt;
			log(`WARNING a query failed in transit (${answer.message}); attempt ${attempt + 1} of ${QUERY_RETRY_ATTEMPTS} after ${wait / 1000} s`);
			sleepSync(wait);
		}
	}

	/**
	 * @description Runs anonymous Apex from a temporary file and returns its log and debug lines.
	 *
	 * @param {string} apex The script.
	 * @param {string} label A name for the script file and for error messages.
	 *
	 * @returns {{logs: string, debugLines: string[]}}
	 */
	function runApex(apex, label)
	{
		const directory = fs.mkdtempSync(path.join(temporaryDirectory, 'consoles-at-volume-'));
		const scriptPath = path.join(directory, `${label}.apex`);
		fs.writeFileSync(scriptPath, apex, 'utf8');
		try
		{
			const answer = runCommand(execFile, [
				'apex',
				'run',
				'-o',
				alias,
				'-f',
				scriptPath,
				'--json'
			]);
			const result = answer.result ?? {};
			if(answer.status !== 0 || result.success === false)
			{
				const failure = new Error(`${label}: ${result.compileProblem || result.exceptionMessage || answer.message || 'the script failed'}`);
				// The CLI's own transport failure, with no word from the org: the script may or may not have run, so a
				// caller that can read the org for what landed may try again. A script's own failure never is.
				failure.transient = isTransportFailure(answer);
				throw failure;
			}
			return {logs: result.logs ?? '', debugLines: readDebugLines(result.logs ?? '')};
		}
		finally
		{
			fs.rmSync(directory, {recursive: true, force: true});
		}
	}

	/**
	 * @description Reads the org's data storage limit.
	 *
	 * @returns {{dataStorageMegabytes: {maximum: number, remaining: number}}}
	 */
	function listLimits()
	{
		const answer = runCommand(execFile, [
			'org',
			'list',
			'limits',
			'-o',
			alias,
			'--json'
		]);
		const storage = (answer.result ?? []).find((limit) => limit.name === 'DataStorageMB') ?? {max: 0, remaining: 0};
		return {dataStorageMegabytes: {maximum: Number(storage.max), remaining: Number(storage.remaining)}};
	}

	/**
	 * @description Reads the org's username and instance URL.
	 *
	 * @returns {{username: string, instanceUrl: string}}
	 */
	function orgDisplay()
	{
		const answer = runCommand(execFile, [
			'org',
			'display',
			'-o',
			alias,
			'--json'
		]);
		return {username: answer.result?.username, instanceUrl: answer.result?.instanceUrl};
	}

	/**
	 * @description The id of the user the alias authenticates as.
	 *
	 * @returns {string}
	 */
	function runUserId()
	{
		const {username} = orgDisplay();
		return query(`SELECT Id FROM User WHERE Username = '${username}' LIMIT 1`).records[0].Id;
	}

	/**
	 * @description Inserts a CSV file through the Bulk API and reports the job's counts.
	 *
	 * @param {string} sobjectName The object to insert into.
	 * @param {string} filePath The CSV file.
	 *
	 * @returns {{jobId: string, processed: number, succeeded: number, failed: number, completed: boolean}}
	 */
	function importCsv(sobjectName, filePath)
	{
		const commandArguments = [
			'data',
			'import',
			'bulk',
			'--sobject',
			sobjectName,
			'--file',
			filePath,
			'--line-ending',
			'LF',
			'--wait',
			IMPORT_WAIT_MINUTES,
			'-o',
			alias,
			'--json'
		];
		const answer = runCommand(execFile, commandArguments, {timeout: IMPORT_TIMEOUT_MILLISECONDS});
		const result = answer.result ?? {};
		const raw = JSON.stringify(answer);
		// A job with rejected rows makes the CLI exit non-zero with an error-shaped answer; the job id is still in its text.
		const jobId = result.jobId ?? (raw.match(BULK_JOB_ID) || [])[0] ?? 'unknown';
		const parsed = {
			jobId,
			processed: Number(result.processedRecords ?? 0),
			succeeded: Number(result.successfulRecords ?? 0),
			failed: Number(result.failedRecords ?? 0),
			completed: answer.status === 0
		};
		// An answer the parse could not read in full is kept, so a failed stage names what the CLI actually said.
		return result.jobId === undefined || !parsed.completed ? {...parsed, raw: raw.slice(0, RAW_ANSWER_PREVIEW_LENGTH)} : parsed;
	}

	return {alias, query, runApex, listLimits, orgDisplay, runUserId, importCsv};
}

module.exports = {createOrgDoor, runCommand, readDebugLines};
