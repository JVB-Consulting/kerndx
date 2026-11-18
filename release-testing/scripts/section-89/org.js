// SPDX-License-Identifier: Apache-2.0
// Section 89's one door to the org. Every `sf` call goes through here: its answer is written to a file under the
// run's folder first, its exit code is kept, and only then is the file read. The command runner is injectable for tests.
'use strict';
const childProcess = require('child_process');
const fs = require('fs');
const path = require('path');
const {readDebugLines} = require('./probe-lines');

const OUTPUT_BUFFER_BYTES = 64 * 1024 * 1024;
// One anonymous Apex run, query or deploy ends well inside this; a longer one is stuck and is stopped.
const COMMAND_TIMEOUT_MILLISECONDS = 360_000;
const DEPLOY_WAIT_MINUTES = '5';
// eslint-disable-next-line no-control-regex
const COLOUR_CODES = /\x1B\[[0-9;]*[a-zA-Z]/g;
const MESSAGE_PREVIEW_LENGTH = 400;
// On Windows `sf` is a .cmd file, which starts only through cmd.exe, and cmd.exe reads spaces, quotes and the signs
// & | ^ % < > as its own. So every argument the driver passes is made of these signs only: the alias, the flags, the
// metadata names, and file paths relative to the folder the command runs in, built from the driver's own labels.
// A query goes in a file for the same reason.
const SHELL_SAFE_ARGUMENT = /^[A-Za-z0-9_.:@\\/-]+$/;
// The folders, inside the run's folder, that hold the scripts and the queries the commands read.
const SCRIPTS_FOLDER = 'scripts';
const QUERIES_FOLDER = 'queries';

/**
 * @description The options each `sf` command starts with. On Windows the command starts through cmd.exe (`shell`),
 * because `sf` is a .cmd file there. On macOS and Linux the command starts in its own process group, so a Ctrl-C in
 * the terminal reaches only the driver, and the command running at that moment finishes. Windows has no process groups
 * of this kind (there, `detached` would open a new console window), so the command stays in the driver's console, and
 * the clean-up runs again any action whose command a Ctrl-C stopped.
 *
 * @param {string} [cwd] The folder to run in.
 * @param {string} [platform] The operating system, as `process.platform` names it.
 *
 * @returns {object}
 */
function commandOptions(cwd, platform = process.platform)
{
	return {
		cwd, encoding: 'utf8', timeout: COMMAND_TIMEOUT_MILLISECONDS, maxBuffer: OUTPUT_BUFFER_BYTES, env: {...process.env, FORCE_COLOR: '0', NO_COLOR: '1'},
		detached: platform !== 'win32', shell: platform === 'win32'
	};
}

/**
 * @description Refuses an argument cmd.exe could read as its own (see SHELL_SAFE_ARGUMENT), on every system, so a run
 * on macOS proves the same arguments a run on Windows passes.
 *
 * @param {string[]} commandArguments The arguments after `sf`.
 */
function checkShellSafe(commandArguments)
{
	const unsafe = commandArguments.filter((argument) => !SHELL_SAFE_ARGUMENT.test(String(argument)));
	if(unsafe.length > 0)
	{
		throw new Error(`Section 89 cannot pass ${unsafe.map((argument) => `"${argument}"`).join(', ')} to sf safely on Windows: `
			+ 'use only letters, digits and the signs _ . : @ - / \\ (for the org, an alias such as kern-subscriber)');
	}
}

/**
 * @description Runs one `sf` command and returns its exit code, the signal that ended it (if one did) and its printed output.
 *
 * @param {string[]} commandArguments The arguments after `sf`.
 * @param {object} [options] `cwd`, the folder to run in.
 *
 * @returns {{exitCode: number, signal: string|null, output: string}}
 */
function runSalesforceCommand(commandArguments, {cwd} = {})
{
	checkShellSafe(commandArguments);
	// noinspection JSCheckFunctionSignatures
	const result = childProcess.spawnSync('sf', commandArguments, commandOptions(cwd));
	return {exitCode: result.status ?? 1, signal: result.signal ?? null, output: `${result.stdout ?? ''}${result.stderr && !result.stdout ? result.stderr : ''}`};
}

/**
 * @description The JSON answer in a command's output, or an answer that says why there is none.
 *
 * @param {string} output What the command printed.
 *
 * @returns {object}
 */
// noinspection FunctionWithMultipleReturnPointsJS
function readAnswer(output)
{
	const clean = String(output).replace(COLOUR_CODES, '');
	const start = clean.indexOf('{');
	if(start < 0)
	{
		return {status: 1, message: `the command printed no JSON: ${clean.slice(0, MESSAGE_PREVIEW_LENGTH)}`};
	}
	try
	{
		return JSON.parse(clean.slice(start));
	}
	catch(parseError)
	{
		return {status: 1, message: `the command printed unreadable JSON (${parseError.message})`};
	}
}

/**
 * @description Builds the door for one org.
 *
 * @param {object} options `alias` (required), `runDirectory` (where every answer is written), `execute` (default runSalesforceCommand).
 *
 * @returns {object} `{alias, runApex, query, deploy, deleteSource, retrieve}`.
 */
function createOrg({alias, runDirectory, execute = runSalesforceCommand})
{
	if(!alias)
	{
		throw new Error('Section 89 needs an org alias: set SF_SUBSCRIBER_ORG_ALIAS');
	}
	checkShellSafe([alias]);
	fs.mkdirSync(path.join(runDirectory, SCRIPTS_FOLDER), {recursive: true});
	fs.mkdirSync(path.join(runDirectory, QUERIES_FOLDER), {recursive: true});
	let sequence = 0;

	/**
	 * @description Runs a command, writes its answer to `<number>-<label>.json` in the run's folder, and reads it back.
	 *
	 * @param {string[]} commandArguments The arguments after `sf`.
	 * @param {string} label A short name for the file.
	 * @param {string} [cwd] The folder to run in (the run's folder when not given).
	 *
	 * @returns {{exitCode: number, signal: string|null, answer: object, file: string}}
	 */
	// noinspection NestedFunctionJS
	function runAndRecord(commandArguments, label, cwd = runDirectory)
	{
		sequence++;
		const file = path.join(runDirectory, `${String(sequence).padStart(3, '0')}-${label}.json`);
		const {exitCode, signal = null, output} = execute(commandArguments, {cwd});
		fs.writeFileSync(file, output, 'utf8');
		return {exitCode, signal, answer: readAnswer(fs.readFileSync(file, 'utf8')), file};
	}

	/**
	 * @description Runs anonymous Apex. A script that fails is not an error here: the outcome says what happened.
	 *
	 * @param {string} apex The script.
	 * @param {string} label A short name for the script and its answer.
	 *
	 * @returns {{exitCode: number, signal: string|null, success: boolean, compiled: boolean, compileProblem: string, exceptionMessage: string, debugLines: string[], file: string}}
	 */
	// noinspection NestedFunctionJS
	function runApex(apex, label)
	{
		const scriptPath = path.join(SCRIPTS_FOLDER, `${label}.apex`);
		fs.writeFileSync(path.join(runDirectory, scriptPath), apex, 'utf8');
		const {exitCode, signal, answer, file} = runAndRecord(['apex', 'run', '-o', alias, '-f', scriptPath, '--json'], label);
		// A script that failed comes back as an error answer, with the outcome under data instead of result.
		const result = answer.result ?? answer.data ?? {};
		return {
			exitCode,
			signal,
			success: exitCode === 0 && result.success === true,
			compiled: result.compiled === true,
			compileProblem: result.compileProblem ?? '',
			exceptionMessage: result.exceptionMessage ?? answer.message ?? '',
			debugLines: readDebugLines(result.logs ?? ''),
			file
		};
	}

	/**
	 * @description Runs one SOQL query, read from a file (a query holds spaces and quotes), and returns its rows; a
	 * failed query throws, naming its answer file and carrying the exit code and the signal that ended the command.
	 *
	 * @param {string} soql The query.
	 * @param {string} label A short name for the query file and the answer file.
	 *
	 * @returns {object[]}
	 */
	// noinspection NestedFunctionJS
	function query(soql, label)
	{
		const queryPath = path.join(QUERIES_FOLDER, `${label}.soql`);
		fs.writeFileSync(path.join(runDirectory, queryPath), soql, 'utf8');
		const {exitCode, signal, answer, file} = runAndRecord(['data', 'query', '-o', alias, '--file', queryPath, '--json'], label);
		if(exitCode !== 0 || answer.status !== 0)
		{
			const failure = new Error(`The query failed (${answer.message ?? `exit code ${exitCode}`}); see ${file}`);
			Object.assign(failure, {exitCode, signal, file});
			throw failure;
		}
		return answer.result?.records ?? [];
	}

	/**
	 * @description Deploys metadata from a project folder.
	 *
	 * @param {string} projectDirectory The project folder (it holds its own sfdx-project.json).
	 * @param {string} metadata The metadata to deploy, such as `Settings:Apex`.
	 * @param {string} label A short name for the answer file.
	 *
	 * @returns {{success: boolean, exitCode: number, signal: string|null, message: string, file: string}}
	 */
	// noinspection NestedFunctionJS
	function deploy(projectDirectory, metadata, label)
	{
		const {exitCode, signal, answer, file} = runAndRecord(
			['project', 'deploy', 'start', '-o', alias, '-m', metadata, '--ignore-conflicts', '--wait', DEPLOY_WAIT_MINUTES, '--json'], label, projectDirectory);
		return {success: exitCode === 0 && answer.status === 0, exitCode, signal, message: answer.message ?? '', file};
	}

	/**
	 * @description Deletes metadata from the org, from a project folder that holds its source.
	 *
	 * @param {string} projectDirectory The project folder.
	 * @param {string} metadata The metadata to delete, such as `ApexClass:ElasticProbeFiller`.
	 * @param {string} label A short name for the answer file.
	 *
	 * @returns {{success: boolean, exitCode: number, signal: string|null, message: string, file: string}}
	 */
	// noinspection NestedFunctionJS
	function deleteSource(projectDirectory, metadata, label)
	{
		const {exitCode, signal, answer, file} = runAndRecord(['project', 'delete', 'source', '-o', alias, '-m', metadata, '--no-prompt', '--json'], label, projectDirectory);
		return {success: exitCode === 0 && answer.status === 0, exitCode, signal, message: answer.message ?? '', file};
	}

	/**
	 * @description Retrieves metadata from the org into a project folder, where it replaces the local copy.
	 *
	 * @param {string} projectDirectory The project folder.
	 * @param {string} metadata The metadata to retrieve, such as `Settings:Apex`.
	 * @param {string} label A short name for the answer file.
	 *
	 * @returns {{success: boolean, exitCode: number, signal: string|null, message: string, file: string}}
	 */
	// noinspection NestedFunctionJS
	function retrieve(projectDirectory, metadata, label)
	{
		const {exitCode, signal, answer, file} = runAndRecord(
			['project', 'retrieve', 'start', '-o', alias, '-m', metadata, '--ignore-conflicts', '--wait', DEPLOY_WAIT_MINUTES, '--json'], label, projectDirectory);
		return {success: exitCode === 0 && answer.status === 0, exitCode, signal, message: answer.message ?? '', file};
	}

	return {alias, runApex, query, deploy, deleteSource, retrieve};
}

module.exports = {createOrg, readAnswer, runSalesforceCommand, commandOptions, checkShellSafe};
