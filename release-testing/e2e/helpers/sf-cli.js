// SPDX-License-Identifier: BUSL-1.1
const {execSync, exec} = require('child_process');
const {ORG_ALIAS} = require('./sf-auth');

// Node caps a child process's captured stdout at 1 MB by default and kills the child with ENOBUFS beyond it. A full
// Apex debug log over a large table (the seed scripts on an org holding 200k log rows) passes that easily, so every
// capture below raises the cap; 64 MB is far above any log the CLI can hand back and costs nothing until used.
const OUTPUT_BUFFER_BYTES = 64 * 1024 * 1024;
const SCRIPT_TIMEOUT_MILLISECONDS = 120_000;
const ANONYMOUS_APEX_TIMEOUT_MILLISECONDS = 60_000;
const QUERY_TIMEOUT_MILLISECONDS = 30_000;
const DEPLOY_TIMEOUT_MILLISECONDS = 120_000;
const TEST_RUN_TIMEOUT_MILLISECONDS = 600_000;
// The framework's batches still running: asked every five seconds, at most thirty-six times (about three minutes).
const RUNNING_BATCHES_QUERY = 'SELECT Id FROM AsyncApexJob WHERE JobType = \'BatchApex\' AND Status IN (\'Holding\', \'Queued\', \'Preparing\', \'Processing\')';
const FRAMEWORK_BATCH_POLL_ATTEMPTS = 36;
const FRAMEWORK_BATCH_POLL_MILLISECONDS = 5000;
// A failed script's reason: the command line's compile and exception lines, at most this many, cut at this length.
const FAILURE_REASON_LINE = /(error|exception|failed|too large)/i;
// The debug log echoes the script and stamps each event with a time; those lines can carry the same words without being the reason.
const DEBUG_LOG_LINE = /^(Execute Anonymous:|\d{2}:\d{2}:\d{2}\.\d+)/;
const FAILURE_LINES_SHOWN = 10;
const FAILURE_TEXT_MAXIMUM_CHARACTERS = 4000;

const fs = require('fs');
const os = require('os');
const path = require('path');

// Written where the org's copy of a script goes; removed once the command has run. Every anonymous-Apex script the
// harness sends is rewritten for the org it runs on (SAR-1): namespace tokens filled and namespace literals moved
// or stripped from the org's own probe, so one script serves the subscriber org and the development org alike.
/**
 * @description Writes the org's copy of a script into a fresh temporary directory.
 *
 * @param {string} scriptPath The script as written in the repository.
 *
 * @returns {string} The copy's path.
 */
function writeScriptForOrg(scriptPath)
{
	// Lazy: sf-namespace requires this module for its probe.
	const {prepareApexForOrg} = require('./sf-namespace');
	const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'apex-for-org-'));
	const copyPath = path.join(directory, path.basename(scriptPath));
	fs.writeFileSync(copyPath, prepareApexForOrg(fs.readFileSync(scriptPath, 'utf8')), 'utf8');
	return copyPath;
}

/**
 * @description Removes the org's copy of a script with its temporary directory.
 *
 * @param {string} copyPath The copy's path.
 */
function removeScriptCopy(copyPath)
{
	fs.rmSync(path.dirname(copyPath), {recursive: true, force: true});
}

/**
 * @description The lines of a failed run that say why it failed: the compile error or the exception the command line
 *              prints, never the whole debug log. Falls back to the output's first lines when no such line is found.
 *
 * @param {string} output What the command printed, standard output and errors together.
 *
 * @returns {string} The lines that explain the failure.
 */
function describeApexFailure(output)
{
	const lines = String(output || '').split('\n').map((line) => line.trimEnd()).filter((line) => line.trim());
	const reasons = lines.filter((line) => FAILURE_REASON_LINE.test(line) && !DEBUG_LOG_LINE.test(line)).slice(0, FAILURE_LINES_SHOWN);
	const shown = reasons.length > 0 ? reasons : lines.slice(0, FAILURE_LINES_SHOWN);
	return shown.join('\n').slice(0, FAILURE_TEXT_MAXIMUM_CHARACTERS);
}

function runApexScript(scriptPath, {timeout = SCRIPT_TIMEOUT_MILLISECONDS, rewriteNamespace = true} = {})
{
	const scriptToRun = rewriteNamespace ? writeScriptForOrg(scriptPath) : scriptPath;
	try
	{
		let output;
		try
		{
			output = execSync(`sf apex run -o ${ORG_ALIAS} -f "${scriptToRun}" 2>&1`, {encoding: 'utf8', timeout, maxBuffer: OUTPUT_BUFFER_BYTES});
		}
		catch(error)
		{
			// The command line prints the compile error or the exception on its output and exits non-zero; without
			// this, the thrown error only says "Command failed" and the reason never reaches the log.
			const reason = describeApexFailure(error.stdout) || error.message;
			const failure = new Error(`sf apex run failed for ${path.basename(scriptPath)} on ${ORG_ALIAS}:\n${reason}`, {cause: error});
			failure.stdout = error.stdout;
			throw failure;
		}
		return parseApexOutput(output);
	}
	finally
	{
		if(scriptToRun !== scriptPath)
		{
			removeScriptCopy(scriptToRun);
		}
	}
}

function runApexScriptAsync(scriptPath, {timeout = SCRIPT_TIMEOUT_MILLISECONDS, rewriteNamespace = true} = {})
{
	const scriptToRun = rewriteNamespace ? writeScriptForOrg(scriptPath) : scriptPath;
	return new Promise((resolve, reject) =>
	{
		exec(`sf apex run -o ${ORG_ALIAS} -f "${scriptToRun}" 2>&1`, {encoding: 'utf8', timeout, maxBuffer: OUTPUT_BUFFER_BYTES}, (error, stdout) =>
		{
			if(scriptToRun !== scriptPath)
			{
				removeScriptCopy(scriptToRun);
			}
			if(error && !stdout)
			{
				reject(error);
				return;
			}
			resolve(parseApexOutput(stdout || ''));
		});
	});
}

function executeAnonymousApex(apex, {timeout = ANONYMOUS_APEX_TIMEOUT_MILLISECONDS, rewriteNamespace = true} = {})
{
	const {prepareApexForOrg} = require('./sf-namespace');
	const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'apex-for-org-'));
	const scriptPath = path.join(directory, 'anonymous.apex');
	fs.writeFileSync(scriptPath, rewriteNamespace ? prepareApexForOrg(apex) : apex, 'utf8');
	try
	{
		return execSync(`sf apex run -o ${ORG_ALIAS} -f "${scriptPath}" 2>&1`, {encoding: 'utf8', timeout, maxBuffer: OUTPUT_BUFFER_BYTES});
	}
	catch(failure)
	{
		// The command's own words (a compile error, an exception line) are what explain the failure; without them the
		// error says only that the command failed.
		const output = String(failure.stdout || failure.message || '').trim();
		throw new Error(`Anonymous Apex failed on ${ORG_ALIAS}: ${output.slice(0, 2000)}`);
	}
	finally
	{
		fs.rmSync(directory, {recursive: true, force: true});
	}
}

function soqlQuery(query, {tooling = false, timeout = QUERY_TIMEOUT_MILLISECONDS} = {})
{
	const toolingFlag = tooling ? '-t' : '';
	const output = execSync(`sf data query -o ${ORG_ALIAS} ${toolingFlag} -q "${query}" --json`,
			{encoding: 'utf8', timeout, maxBuffer: OUTPUT_BUFFER_BYTES, env: {...process.env, FORCE_COLOR: '0', NO_COLOR: '1'}});
	// eslint-disable-next-line no-control-regex
	const clean = output.replace(/\x1B\[[0-9;]*[a-zA-Z]/g, '');
	const result = JSON.parse(clean);
	return result.result.records || [];
}

/**
 * @description Waits out the framework's batches still running, such as the fire-and-forget log-entry purge part 1
 *              launches, so a spec that seeds rows after it cannot have them deleted mid-spec. Bounded: after about
 *              three minutes the caller proceeds regardless (the purge has then almost certainly drained; a leftover
 *              long-runner should not deadlock the suite).
 *
 * @param {object} options `sleep`, which waits the given milliseconds (a timer by default).
 *
 * @returns {Promise<{finished: boolean, attempts: number}>} Whether no batch was left running, and how many asks it took.
 */
async function waitForFrameworkBatchesToFinish({sleep = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds))} = {})
{
	// Lazy: sf-namespace requires this module for its probe. The framework's classes carry the org's namespace, or none.
	const {namespacePrefix} = require('./sf-namespace');
	const namespace = namespacePrefix().replace(/__$/, '');
	const query = `${RUNNING_BATCHES_QUERY} AND ApexClass.NamespacePrefix = ${namespace ? `'${namespace}'` : 'null'}`;
	for(let attempt = 1; attempt <= FRAMEWORK_BATCH_POLL_ATTEMPTS; attempt++)
	{
		if(soqlQuery(query).length === 0)
		{
			return {finished: true, attempts: attempt};
		}
		await sleep(FRAMEWORK_BATCH_POLL_MILLISECONDS);
	}
	return {finished: false, attempts: FRAMEWORK_BATCH_POLL_ATTEMPTS};
}

function createRecord(sobjectType, values, {timeout = QUERY_TIMEOUT_MILLISECONDS} = {})
{
	const valuesStr = Object.entries(values)
	.map(([key, val]) => `${key}="${val}"`)
	.join(' ');
	const output = execSync(`sf data create record -o ${ORG_ALIAS} -s ${sobjectType} -v "${valuesStr}" --json`, {encoding: 'utf8', timeout});
	return JSON.parse(output).result;
}

function deleteRecord(sobjectType, recordId, {timeout = QUERY_TIMEOUT_MILLISECONDS} = {})
{
	execSync(`sf data delete record -o ${ORG_ALIAS} -s ${sobjectType} -i ${recordId} --json`, {encoding: 'utf8', timeout});
}

function deployMetadata(sourcePath, {timeout = DEPLOY_TIMEOUT_MILLISECONDS} = {})
{
	const output = execSync(`sf project deploy start -o ${ORG_ALIAS} -d "${sourcePath}" --ignore-conflicts --json`, {encoding: 'utf8', timeout});
	return JSON.parse(output);
}

function runTests({testLevel = 'RunLocalTests', timeout = TEST_RUN_TIMEOUT_MILLISECONDS} = {})
{
	const output = execSync(`sf apex run test -o ${ORG_ALIAS} --test-level ${testLevel} --result-format json --code-coverage --json`,
			{encoding: 'utf8', timeout, maxBuffer: OUTPUT_BUFFER_BYTES});
	return JSON.parse(output);
}

function parseApexOutput(output)
{
	const lines = output.split('\n').filter(line => line.includes('USER_DEBUG'));
	let pass = 0;
	let fail = 0;
	const results = [];

	for(const line of lines)
	{
		// Older CLIs print `USER_DEBUG [12]|DEBUG|`, the current one `|USER_DEBUG|[12]|DEBUG|`; both count.
		const debugMatch = line.match(/USER_DEBUG[\s|]+\[[\d|]+]\|DEBUG\|(.+)/);
		if(!debugMatch)
		{
			continue;
		}
		const message = debugMatch[1];
		const isPassing = message.includes('PASS');
		const isFailing = message.includes('FAIL');
		if(isPassing)
		{
			pass++;
		}
		if(isFailing)
		{
			fail++;
		}
		results.push({message, pass: isPassing, fail: isFailing});
	}

	return {pass, fail, total: pass + fail, results, raw: output};
}

module.exports = {
	runApexScript, runApexScriptAsync, executeAnonymousApex, soqlQuery, createRecord, deleteRecord, deployMetadata, runTests, parseApexOutput,
	waitForFrameworkBatchesToFinish
};
