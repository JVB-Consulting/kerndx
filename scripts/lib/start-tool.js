// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Starts a tool a reader has installed with npm (sf, npm, npx) the way each system needs: shell-free
 *              where the tool is a program, through Command Prompt where it is a .cmd file, which Node will not start
 *              without a shell and refuses by name. The tool quotes every argument itself, so a path with a space
 *              arrives intact and no shell expands a pathspec. The same code lives in pipeline/src/lib/sfca-runner.js,
 *              because the pipeline ships on its own and may require nothing outside itself.
 */
'use strict';

const {spawn, spawnSync} = require('child_process');

/**
 * @description Quotes one argument for Command Prompt: only when it holds a space or a character the prompt would
 *              interpret; an inner double quote is escaped for the program that receives it.
 * @param {string} argument - One argument.
 * @returns {string} The argument as it goes on the command line.
 */
function quoteForCommandPrompt(argument)
{
	return /[\s"&|<>^()]/.test(argument) ? `"${argument.replace(/"/g, '\\"')}"` : argument;
}

/**
 * @description Works out what to start on this system: the tool itself where it is a program, or, on Windows, where
 *              the tool is a .cmd file, Command Prompt running the tool's quoted command line.
 * @param {string} tool - sf, npm or npx (or any tool on the PATH).
 * @param {string[]} args - The arguments, exactly as the tool should receive them.
 * @param {Object} options - The start options; a missing `env` means the process environment.
 * @returns {{command: string, commandArguments: string[], commandOptions: Object}} What to hand spawn or spawnSync.
 */
function describeStart(tool, args, options)
{
	if(process.platform !== 'win32')
	{
		return {command: tool, commandArguments: args, commandOptions: options};
	}
	const environment = options.env || process.env;
	const commandLine = [tool, ...args].map(quoteForCommandPrompt).join(' ');
	return {
		command: environment.ComSpec || process.env.ComSpec || 'cmd.exe',
		commandArguments: ['/d', '/s', '/c', `"${commandLine}"`],
		commandOptions: {...options, windowsVerbatimArguments: true}
	};
}

/**
 * @description Starts the tool with the given arguments and returns spawnSync's result.
 * @param {string} tool - sf, npm or npx (or any tool on the PATH).
 * @param {string[]} args - The arguments, exactly as the tool should receive them.
 * @param {Object} [options] - spawnSync options; a missing `env` means the process environment.
 * @returns {Object} The spawnSync result; a missing tool is a non-zero status with `error` set, never a throw.
 */
function startTool(tool, args, options = {})
{
	const start = describeStart(tool, args, options);
	return spawnSync(start.command, start.commandArguments, start.commandOptions);
}

/**
 * @description Starts the tool with the given arguments without waiting for it, so a caller can show the tool's
 *              output while it runs, and returns the running process.
 * @param {string} tool - sf, npm or npx (or any tool on the PATH).
 * @param {string[]} args - The arguments, exactly as the tool should receive them.
 * @param {Object} [options] - spawn options; a missing `env` means the process environment.
 * @returns {Object} The ChildProcess; a missing tool is an `error` event or a non-zero `close` code, never a throw.
 */
function startToolStreaming(tool, args, options = {})
{
	const start = describeStart(tool, args, options);
	return spawn(start.command, start.commandArguments, start.commandOptions);
}

module.exports = {quoteForCommandPrompt, startTool, startToolStreaming};
