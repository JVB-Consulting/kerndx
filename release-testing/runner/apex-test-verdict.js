#!/usr/bin/env node
// SPDX-License-Identifier: Apache-2.0
/**
 * @description The org-truth verdict for an Apex test run. The `sf apex run test` wrapper is trusted for
 * one thing only, the id of the run it started: once its wait expires the wrapper carries nothing else,
 * and the 1.7 cycle read a 25-failure run as "non-pass tests: 0" from that empty payload. Everything
 * that decides the verdict is read from the org: ApexTestRunResult for the run's status and counts,
 * ApexTestResult for every method that did not pass.
 *
 * The run this helper judges is the run it launched: it first waits for any test run already in flight
 * on the org (a launch beside one is refused with ALREADY_IN_PROCESS, and "the newest run" would name
 * the wrong job), then launches, then resolves its own run by id, or by start time after a mark taken
 * before the launch when the wrapper gave no id.
 *
 * Usage:
 *   node release-testing/runner/apex-test-verdict.js --org <alias> --label <label> --evidence-dir <dir>
 *     [--test-level RunLocalTests|RunAllTestsInOrg] [--tests <class>[,<class>]] [--code-coverage]
 *     [--wait-minutes <n>] [--run-id <id>]
 *
 * Writes <dir>/apex-run-<label>.json (the ApexTestRunResult row) and <dir>/apex-nonpass-<label>.json
 * (the non-pass ApexTestResult rows), prints one verdict line and the grouped non-pass lines, and exits 0
 * only for a Completed run with zero failures and zero non-pass rows. `--run-id` attaches to an existing
 * run instead of launching one.
 */
'use strict';

const {execFileSync} = require('child_process');
const fs = require('fs');
const path = require('path');

const IN_FLIGHT_STATUSES = new Set([
	'Queued',
	'Processing',
	'Holding',
	'Preparing'
]);
const RUN_FIELDS = 'AsyncApexJobId, Status, MethodsEnqueued, MethodsCompleted, MethodsFailed, StartTime, EndTime';
const NON_PASS_FIELDS = 'ApexClass.Name, MethodName, Outcome, Message';
const DEFAULT_TEST_LEVEL = 'RunAllTestsInOrg';
const DEFAULT_WAIT_MINUTES = 120;
const LAUNCH_WAIT_MINUTES = 1;
const POLL_INTERVAL_MS = 60_000;
const IN_FLIGHT_POLL_INTERVAL_MS = 30_000;
const SETTLE_ATTEMPTS = 12;
const SETTLE_INTERVAL_MS = 10_000;
const MESSAGE_PREVIEW_LENGTH = 150;
const OUTPUT_BUFFER_BYTES = 64 * 1024 * 1024;
// eslint-disable-next-line no-control-regex
const ANSI_PATTERN = /\x1B\[[0-9;]*[a-zA-Z]/g;
const RUN_ID_KEY_LENGTH = 15;
const OUTPUT_PREVIEW_LENGTH = 200;

// The command-line options that take a value, and what each one sets.
const VALUE_ARGUMENTS = new Map([
	[
		'--org',
		(options, value) =>
		{
			options.org = value;
		}
	],
	[
		'--label',
		(options, value) =>
		{
			options.label = value;
		}
	],
	[
		'--evidence-dir',
		(options, value) =>
		{
			options.evidenceDir = value;
		}
	],
	[
		'--test-level',
		(options, value) =>
		{
			options.testLevel = value;
		}
	],
	[
		'--tests',
		(options, value) =>
		{
			options.tests = String(value).split(',').map((name) => name.trim()).filter(Boolean);
		}
	],
	[
		'--wait-minutes',
		(options, value) =>
		{
			options.waitMinutes = Number(value);
		}
	],
	[
		'--run-id',
		(options, value) =>
		{
			options.runId = value;
		}
	]
]);

// The command-line options that are a switch on their own.
const FLAG_ARGUMENTS = new Map([
	[
		'--code-coverage',
		(options) =>
		{
			options.codeCoverage = true;
		}
	]
]);

// The options with no default: the run is refused without them.
const REQUIRED_ARGUMENTS = [
	'org',
	'label',
	'evidenceDir'
];

/**
 * @description Parses the JSON an `sf --json` command printed, tolerating a warning line ahead of it and
 * colour codes around it.
 * @param {string} text the command's output
 * @return {object} the parsed payload
 */
function parseCliJson(text)
{
	const clean = String(text ?? '').replace(ANSI_PATTERN, '');
	const start = clean.indexOf('{');
	if(start < 0)
	{
		throw new Error(`no JSON in the CLI output: ${clean.trim().slice(0, OUTPUT_PREVIEW_LENGTH)}`);
	}
	return JSON.parse(clean.slice(start, clean.lastIndexOf('}') + 1));
}

/**
 * @description Reads the run id out of a test launch's output; the only fact the wrapper is trusted for.
 * @param {string} text the launch output
 * @return {{testRunId: string}} the run id
 */
function parseLaunchPayload(text)
{
	let payload;
	try
	{
		payload = parseCliJson(text);
	}
	catch
	{
		throw new Error('the test launch returned no JSON: '
			+ `${String(text ?? '').replace(ANSI_PATTERN, '').trim().slice(0, OUTPUT_PREVIEW_LENGTH)}`);
	}
	const testRunId = payload?.result?.testRunId ?? payload?.result?.summary?.testRunId ?? null;
	if(!testRunId)
	{
		throw new Error('the test launch payload carries no run id: '
			+ `${JSON.stringify(payload).slice(0, OUTPUT_PREVIEW_LENGTH)}`);
	}
	return {testRunId};
}

/**
 * @description Reads the records out of a `sf data query --json` output.
 * @param {string} text the query output
 * @return {object[]} the records, empty when the query matched nothing
 */
function parseQueryPayload(text)
{
	return parseCliJson(text)?.result?.records ?? [];
}

/**
 * @description Whether a run row has reached a status the platform will not change again.
 * @param {object} run an ApexTestRunResult row
 * @return {boolean} true once the run is no longer queued or running
 */
function isTerminal(run)
{
	return !IN_FLIGHT_STATUSES.has(run?.Status);
}

/**
 * @description Counts the runs still queued or running.
 * @param {object[]} runs ApexTestRunResult rows
 * @return {number} the in-flight count
 */
function countInFlight(runs)
{
	return runs.filter((run) => !isTerminal(run)).length;
}

/**
 * @description Picks the run this helper launched: by id when the launch gave one, else the earliest run
 * that started after the mark taken before the launch. Never "the newest run on the org", which on a busy
 * org is someone else's.
 * @param {object[]} runs recent ApexTestRunResult rows
 * @param {string|null} mark the latest StartTime seen before the launch, or null
 * @param {string|null} preferredRunId the id the launch returned, or null
 * @return {object|null} the run, or null when none qualifies
 */
function selectRunStartedAfter(runs, mark, preferredRunId)
{
	if(preferredRunId)
	{
		const key = String(preferredRunId).slice(0, RUN_ID_KEY_LENGTH);
		const byId = runs.find((run) => String(run.AsyncApexJobId ?? '').startsWith(key));
		if(byId)
		{
			return byId;
		}
	}
	const started = runs
	.filter((run) => run.StartTime && (!mark || run.StartTime > mark))
	.sort((a, b) => a.StartTime.localeCompare(b.StartTime));
	return started[0] ?? null;
}

/**
 * @description Decides the verdict from the org's own rows.
 * @param {object} run the ApexTestRunResult row
 * @param {object[]} nonPassRows the ApexTestResult rows whose Outcome is not Pass
 * @return {object} the verdict: passed, status, the counts and a reason when it did not pass
 */
function buildVerdict(run, nonPassRows)
{
	const base = {
		passed: false,
		status: run?.Status ?? null,
		methodsEnqueued: run?.MethodsEnqueued ?? null,
		methodsCompleted: run?.MethodsCompleted ?? null,
		methodsFailed: run?.MethodsFailed ?? null,
		nonPassCount: nonPassRows.length,
		reason: null
	};
	if(!isTerminal(run))
	{
		return {...base, reason: `run not terminal (status ${base.status})`};
	}
	if(base.status !== 'Completed')
	{
		return {...base, reason: `run ended with status ${base.status}`};
	}
	if((base.methodsFailed ?? 0) > 0 || nonPassRows.length > 0)
	{
		return {...base, reason: `${base.methodsFailed ?? 0} failed methods, ${nonPassRows.length} non-pass rows`};
	}
	return {...base, passed: true};
}

/**
 * @description Groups the non-pass rows by class and outcome, one line each with the count and the
 * first message.
 * @param {object[]} nonPassRows the ApexTestResult rows whose Outcome is not Pass
 * @return {string[]} the lines, in first-seen order
 */
function summarizeNonPass(nonPassRows)
{
	const groups = new Map();
	for(const row of nonPassRows)
	{
		const key = `${row?.ApexClass?.Name ?? '?'} | ${row?.Outcome ?? '?'}`;
		const group = groups.get(key) ?? {count: 0, message: String(row?.Message ?? '').slice(0, MESSAGE_PREVIEW_LENGTH)};
		group.count++;
		groups.set(key, group);
	}
	return [...groups.entries()].map(([key, group]) => `${group.count} ${key} | ${group.message}`);
}

/**
 * @description Runs one `sf` command and returns its output; a refused command's output is returned too,
 * so the caller can read the platform's reason out of it.
 * @param {string[]} args the command's arguments
 * @return {string} the output
 */
function runSf(args)
{
	const options = {
		encoding: 'utf8', maxBuffer: OUTPUT_BUFFER_BYTES, env: {...process.env, SF_SKIP_NEW_VERSION_CHECK: 'true', FORCE_COLOR: '0', NO_COLOR: '1'}
	};
	try
	{
		return execFileSync('sf', args, options);
	}
	catch(error)
	{
		return `${error.stdout ?? ''}${error.stderr ?? ''}`;
	}
}

/**
 * @description Queries the org.
 * @param {string} org the org alias
 * @param {string} soql the query
 * @param {boolean} tooling whether the query targets the Tooling API
 * @return {object[]} the records
 */
function query(org, soql, tooling = false)
{
	const args = [
		'data',
		'query',
		'-o',
		org
	];
	if(tooling)
	{
		args.push('-t');
	}
	args.push('-q', soql, '--json');
	return parseQueryPayload(runSf(args));
}

/**
 * @description Reads the org-wide Apex coverage the platform computed after a coverage-enabled run.
 * @param {string} org the org alias
 * @return {number|null} the percentage, or null when the org reports none
 */
function fetchOrgWideCoverage(org)
{
	const rows = query(org, 'SELECT PercentCovered FROM ApexOrgWideCoverage', true);
	return rows[0]?.PercentCovered ?? null;
}

/**
 * @description Sleeps for the given time.
 * @param {number} milliseconds the time
 * @return {Promise<void>} resolves after the time
 */
function sleep(milliseconds)
{
	return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

/**
 * @description Waits until no test run is queued or running on the org.
 * @param {string} org the org alias
 * @param {number} waitMinutes the longest wait
 * @param {function} log the progress logger
 * @param {function} sleepFunction the wait between polls, injectable for tests
 */
async function waitForNoRunInFlight(org, waitMinutes, log, sleepFunction)
{
	const deadline = Date.now() + waitMinutes * 60_000;
	while(Date.now() < deadline)
	{
		const inFlight = query(org, `SELECT ${RUN_FIELDS} FROM ApexTestRunResult`
			+ ' WHERE Status IN (\'Queued\', \'Processing\', \'Holding\', \'Preparing\')');
		if(countInFlight(inFlight) === 0)
		{
			return;
		}
		log(`${inFlight.length} test run(s) still in flight on ${org}; waiting`);
		await sleepFunction(IN_FLIGHT_POLL_INTERVAL_MS);
	}
	throw new Error(`a test run was still in flight on ${org} after ${waitMinutes} minutes`);
}

/**
 * @description The latest StartTime among the org's test runs, the mark a launched run must start after.
 * @param {string} org the org alias
 * @return {string|null} the mark, or null when the org has no runs
 */
function latestRunStart(org)
{
	const rows = query(org, 'SELECT StartTime FROM ApexTestRunResult'
		+ ' WHERE StartTime != null ORDER BY StartTime DESC LIMIT 1');
	return rows[0]?.StartTime ?? null;
}

/**
 * @description Launches the test run and returns the id the wrapper gave it.
 * @param {string} org the org alias
 * @param {object} options testLevel, tests, codeCoverage
 * @return {string} the run id
 */
function launchRun(org, {testLevel, tests, codeCoverage})
{
	const args = [
		'apex',
		'run',
		'test',
		'-o',
		org,
		'--result-format',
		'json',
		'--json',
		'--wait',
		String(LAUNCH_WAIT_MINUTES)
	];
	if(tests && tests.length > 0)
	{
		for(const test of tests)
		{
			args.push('--tests', test);
		}
	}
	else
	{
		args.push('--test-level', testLevel);
	}
	if(codeCoverage)
	{
		args.push('--code-coverage');
	}
	return parseLaunchPayload(runSf(args)).testRunId;
}

/**
 * @description Finds the launched run's row once the platform has written it.
 * @param {string} org the org alias
 * @param {string|null} testRunId the id the launch returned
 * @param {string|null} mark the latest StartTime before the launch
 * @param {function} sleepFunction the wait between polls, injectable for tests
 * @return {Promise<object>} the run row
 */
async function findLaunchedRun(org, testRunId, mark, sleepFunction)
{
	for(let attempt = 0; attempt < SETTLE_ATTEMPTS; attempt++)
	{
		const recent = query(org, `SELECT ${RUN_FIELDS} FROM ApexTestRunResult`
			+ ' ORDER BY StartTime DESC NULLS LAST LIMIT 10');
		const run = selectRunStartedAfter(recent, mark, testRunId);
		if(run)
		{
			return run;
		}
		await sleepFunction(SETTLE_INTERVAL_MS);
	}
	throw new Error(`the launched run (${testRunId ?? 'no id'}) never appeared in ApexTestRunResult on ${org}`);
}

/**
 * @description Polls one run until it reaches a terminal status or the wait runs out.
 * @param {string} org the org alias
 * @param {string} jobId the run's AsyncApexJobId
 * @param {number} waitMinutes the longest wait
 * @param {function} log the progress logger
 * @param {function} sleepFunction the wait between polls, injectable for tests
 * @return {Promise<object>} the final row seen
 */
async function pollRunToTerminal(org, jobId, waitMinutes, log, sleepFunction)
{
	const deadline = Date.now() + waitMinutes * 60_000;
	let run = null;
	// eslint-disable-next-line no-constant-condition
	while(true)
	{
		run = query(org, `SELECT ${RUN_FIELDS} FROM ApexTestRunResult`
			+ ` WHERE AsyncApexJobId = '${jobId}'`)[0] ?? null;
		if(run)
		{
			log(`run ${jobId}: ${run.Status}, `
				+ `${run.MethodsCompleted ?? 0}/${run.MethodsEnqueued ?? 0} completed, ${run.MethodsFailed ?? 0} failed`);
			if(isTerminal(run))
			{
				return run;
			}
		}
		if(Date.now() >= deadline)
		{
			return run ?? {AsyncApexJobId: jobId, Status: 'Unknown'};
		}
		await sleepFunction(POLL_INTERVAL_MS);
	}
}

/**
 * @description Reads every method of the run that did not pass.
 * @param {string} org the org alias
 * @param {string} jobId the run's AsyncApexJobId
 * @return {object[]} the rows
 */
function fetchNonPass(org, jobId)
{
	return query(org, `SELECT ${NON_PASS_FIELDS} FROM ApexTestResult`
		+ ` WHERE AsyncApexJobId = '${jobId}' AND Outcome != 'Pass'`
		+ ' ORDER BY ApexClass.Name, MethodName');
}

/**
 * @description Applies one command-line word and says how many words it used up: two for a `--name value`
 * pair, one for a switch. A word the helper does not know stops the run.
 * @param {object} options the options gathered so far
 * @param {string} argument the word
 * @param {string|undefined} value the word after it
 * @return {number} the number of words used up
 */
function applyArgument(options, argument, value)
{
	const setValue = VALUE_ARGUMENTS.get(argument);
	if(setValue)
	{
		setValue(options, value);
		return 2;
	}
	const setFlag = FLAG_ARGUMENTS.get(argument);
	if(!setFlag)
	{
		throw new Error(`unknown argument ${argument}`);
	}
	setFlag(options);
	return 1;
}

/**
 * @description Stops the run when an option with no default was left out, naming the option as the command
 * line spells it.
 * @param {object} options the parsed command line
 */
function requireArguments(options)
{
	for(const required of REQUIRED_ARGUMENTS)
	{
		if(!options[required])
		{
			throw new Error(`--${required.replace(/[A-Z]/g, (letter) => `-${letter.toLowerCase()}`)} is required`);
		}
	}
}

/**
 * @description Parses the command line: `--name value` pairs and `--code-coverage`.
 * @param {string[]} argv the arguments after the script path
 * @return {object} the options
 */
function parseArguments(argv)
{
	const options = {
		org: null, label: null, evidenceDir: null, testLevel: DEFAULT_TEST_LEVEL, tests: [], codeCoverage: false, waitMinutes: DEFAULT_WAIT_MINUTES, runId: null
	};
	let index = 0;
	while(index < argv.length)
	{
		index += applyArgument(options, argv[index], argv[index + 1]);
	}
	requireArguments(options);
	return options;
}

/**
 * @description The run to judge: the one `--run-id` named, or a freshly launched one, waited for, launched
 * and followed by its own id.
 * @param {object} options the parsed command line
 * @param {function} log the progress logger
 * @param {function} sleepFunction the wait between polls, injectable for tests
 * @return {Promise<object>} the run row, at whatever status the wait left it
 */
async function resolveRun(options, log, sleepFunction)
{
	if(options.runId)
	{
		return pollRunToTerminal(options.org, options.runId, options.waitMinutes, log, sleepFunction);
	}
	await waitForNoRunInFlight(options.org, options.waitMinutes, log, sleepFunction);
	const mark = latestRunStart(options.org);
	const testRunId = launchRun(options.org, options);
	log(`launched run ${testRunId} on ${options.org}`
		+ ` (${options.tests.length > 0 ? options.tests.join(', ') : options.testLevel})`);
	const launched = await findLaunchedRun(options.org, testRunId, mark, sleepFunction);
	return pollRunToTerminal(options.org, launched.AsyncApexJobId, options.waitMinutes, log, sleepFunction);
}

/**
 * @description Writes the two evidence files: the run row, with the org-wide coverage when there is one, and
 * every method that did not pass.
 * @param {object} options the parsed command line
 * @param {object} run the run row
 * @param {number|null} orgWideCoveragePercent the coverage the org reported, or null
 * @param {object[]} nonPassRows the rows whose Outcome is not Pass
 */
function writeEvidence(options, run, orgWideCoveragePercent, nonPassRows)
{
	const evidence = orgWideCoveragePercent === null ? run : {...run, orgWideCoveragePercent};
	fs.writeFileSync(path.join(options.evidenceDir, `apex-run-${options.label}.json`), JSON.stringify(evidence, null, 2));
	fs.writeFileSync(path.join(options.evidenceDir, `apex-nonpass-${options.label}.json`), JSON.stringify(nonPassRows, null, 2));
}

/**
 * @description The one line that carries the verdict: the outcome, the status, the counts, the coverage when
 * there is one and the reason when it did not pass.
 * @param {string} label the label the run was given
 * @param {object} verdict the verdict
 * @param {string} coverageNote the coverage part of the line, empty when the run measured none
 * @return {string} the line
 */
function formatVerdictLine(label, verdict, coverageNote)
{
	const counts = `enqueued ${verdict.methodsEnqueued}, completed ${verdict.methodsCompleted}`
		+ `, failed ${verdict.methodsFailed}, non-pass ${verdict.nonPassCount}`;
	const reasonNote = verdict.reason ? `; ${verdict.reason}` : '';
	return `verdict ${label}: ${verdict.passed ? 'PASS' : 'FAIL'}`
		+ ` (${verdict.status}, ${counts}${coverageNote}${reasonNote})`;
}

/**
 * @description Launches (or attaches to) the run, judges it from the org and writes the evidence.
 * @param {object} options the parsed command line
 * @param {function} log the progress logger
 * @param {function} sleepFunction the wait between polls, injectable for tests
 * @return {Promise<number>} the exit code: 0 for a clean Completed run, 1 otherwise
 */
async function main(options, log = console.log, sleepFunction = sleep)
{
	fs.mkdirSync(options.evidenceDir, {recursive: true});
	const run = await resolveRun(options, log, sleepFunction);
	const nonPassRows = isTerminal(run) ? fetchNonPass(options.org, run.AsyncApexJobId) : [];
	const orgWideCoveragePercent = options.codeCoverage && isTerminal(run) ? fetchOrgWideCoverage(options.org) : null;
	writeEvidence(options, run, orgWideCoveragePercent, nonPassRows);
	const verdict = buildVerdict(run, nonPassRows);
	const coverageNote = orgWideCoveragePercent === null ? '' : `, coverage ${orgWideCoveragePercent}%`;
	log(formatVerdictLine(options.label, verdict, coverageNote));
	for(const line of summarizeNonPass(nonPassRows))
	{
		log(`  ${line}`);
	}
	return verdict.passed ? 0 : 1;
}

if(require.main === module)
{
	main(parseArguments(process.argv.slice(2)))
	.then((code) => process.exit(code))
	.catch((error) =>
	{
		console.error(`apex-test-verdict: ${error.message}`);
		process.exit(2);
	});
}

module.exports = {
	parseCliJson, parseLaunchPayload, parseQueryPayload, isTerminal, countInFlight, selectRunStartedAfter, buildVerdict, summarizeNonPass, parseArguments, main
};
