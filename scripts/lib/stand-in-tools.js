// SPDX-License-Identifier: Apache-2.0
/**
 * @description Stand-ins for the tools a guide tells a reader to run (sf, npm, npx). A stand-in records the
 *              arguments it received and exits 0. It never imitates the real tool: what it proves is that every
 *              terminal hands the tool the same request. On Windows a stand-in is a .cmd file, exactly as the real
 *              sf and npm are, so quoting travels the same road. A caller that names pass-through tools gets a
 *              hermetic environment as well: a PATH holding the stand-ins and a pass-through shim for each named
 *              tool the machine has, a home folder of its own, git with no system or global settings and no
 *              prompt, and none of the machine's other variables beyond the few a shell, node or git needs. A
 *              line can then reach only the tools the caller chose, whatever the machine has and whatever the
 *              line's shape.
 */
'use strict';

const fs = require('fs');
const path = require('path');

const RECORDER_SOURCE = [
	'\'use strict\';',
	'const fs = require(\'fs\');',
	'const [tool, ...args] = process.argv.slice(2);',
	'fs.appendFileSync(process.env.STAND_IN_LOG, JSON.stringify({tool, args}) + \'\\n\');',
	''
].join('\n');
// The variables a shell, node or git needs to run at all; every other variable of the machine stays out.
const KEPT_VARIABLES = ['PATHEXT', 'SystemRoot', 'SystemDrive', 'windir', 'ComSpec', 'TEMP', 'TMP', 'TMPDIR', 'LANG', 'LC_ALL', 'LC_CTYPE', 'TERM'];
const WINDOWS_EXTENSIONS = '.COM;.EXE;.BAT;.CMD';
// The one setting git gets: an identity, so a guide's `git commit` line commits on a machine whose hostname gives
// git nothing to derive one from, as a Windows runner's does. No credential helper, no signing, nothing else.
const GIT_CONFIGURATION = '[user]\n\tname = Docs Runner\n\temail = docs-runner@example.invalid\n';

/**
 * @description Finds a tool on an environment's PATH the way the shell would: the name as given, except that on
 *              Windows a name with no extension is tried with each executable extension, as cmd tries them, and
 *              never bare, so a file like npm's extension-less script is never mistaken for the tool.
 * @param {string} tool - The tool's name, as a guide prints it.
 * @param {Object<string, string>} environment - The environment whose PATH is searched.
 * @returns {string|null} The file's absolute path, or null when no folder on the PATH holds it.
 */
function resolveOnPath(tool, environment)
{
	const searchPath = environment.PATH || environment.Path || '';
	const windowsExtensions = process.platform === 'win32' && !path.extname(tool);
	const extensions = windowsExtensions ? (environment.PATHEXT || WINDOWS_EXTENSIONS).split(';') : [''];
	for(const folder of searchPath.split(path.delimiter).filter(Boolean))
	{
		for(const extension of extensions)
		{
			const candidate = path.join(folder, tool + extension);
			if(fs.existsSync(candidate) && fs.statSync(candidate).isFile() && isRunnable(candidate))
			{
				return candidate;
			}
		}
	}
	return null;
}

/**
 * @description True when the file can be started: Windows decides by extension, elsewhere by the execute bit.
 * @param {string} file - An absolute path.
 * @returns {boolean} Whether a shell could run it.
 */
function isRunnable(file)
{
	if(process.platform === 'win32')
	{
		return true;
	}
	try
	{
		fs.accessSync(file, fs.constants.X_OK);
		return true;
	}
	catch(error)
	{
		return false;
	}
}

/**
 * @description Writes a shim that starts a program with fixed leading arguments and then the caller's own.
 * @param {string} directory - Where the shim is written.
 * @param {string} name - The shim's name, the tool a guide line names.
 * @param {string} program - The absolute path of what the shim starts.
 * @param {string[]} leadingArguments - Given to the program before the caller's arguments, each already quoted.
 */
function writeShim(directory, name, program, leadingArguments)
{
	const leading = leadingArguments.length > 0 ? `${leadingArguments.join(' ')} ` : '';
	if(process.platform === 'win32')
	{
		// A .cmd or .bat target must be called, or the shim ends where the target starts and its exit code is lost.
		const call = /\.(cmd|bat)$/i.test(program) ? 'call ' : '';
		fs.writeFileSync(path.join(directory, `${name}.cmd`), `@echo off\r\n${call}"${program}" ${leading}%*\r\n`);
	}
	else
	{
		const shim = path.join(directory, name);
		fs.writeFileSync(shim, `#!/bin/sh\nexec "${program}" ${leading}"$@"\n`);
		fs.chmodSync(shim, 0o755);
	}
}

/**
 * @description Builds the environment a hermetic run gets: the stand-in directory as the whole PATH, a home of its
 *              own, git with an identity of its own and none of the machine's settings or a prompt, and only the
 *              variables a shell needs.
 * @param {string} directory - The stand-in directory; the home is made inside it.
 * @param {string} logFile - The file every stand-in appends its call to.
 * @param {Object<string, string>} baseEnvironment - The machine's environment, read for the kept variables only.
 * @returns {Object<string, string>} The environment.
 */
function hermeticEnvironment(directory, logFile, baseEnvironment)
{
	const home = path.join(directory, 'home');
	const gitConfiguration = path.join(home, 'gitconfig');
	const environment = {};
	for(const name of KEPT_VARIABLES)
	{
		const found = Object.keys(baseEnvironment).find(key => key.toUpperCase() === name.toUpperCase());
		if(found !== undefined)
		{
			environment[name] = baseEnvironment[found];
		}
	}
	Object.assign(environment, {
		PATH: directory, HOME: home, USERPROFILE: home, APPDATA: path.join(home, 'AppData', 'Roaming'), LOCALAPPDATA: path.join(home, 'AppData', 'Local'),
		STAND_IN_LOG: logFile, GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: gitConfiguration, GIT_TERMINAL_PROMPT: '0'
	});
	fs.mkdirSync(environment.APPDATA, {recursive: true});
	fs.mkdirSync(environment.LOCALAPPDATA, {recursive: true});
	fs.writeFileSync(gitConfiguration, GIT_CONFIGURATION);
	return environment;
}

/**
 * @description Writes the stand-ins into a directory and returns an environment that finds them first. With
 *              pass-through tools named, the environment is hermetic: it finds the stand-ins and the named tools
 *              and nothing else the machine has.
 * @param {string} directory - Where the stand-ins are written (created if missing).
 * @param {string} logFile - The file every stand-in appends its call to.
 * @param {string[]} [tools] - Tool names to stand in for.
 * @param {{passThroughTools?: string[], baseEnvironment?: Object<string, string>}} [options] - The tools a hermetic run may reach
 *        as the machine's own, each found on the base environment's PATH (node is always this process's own); a tool
 *        the machine lacks gets no shim. The base environment defaults to process.env.
 * @returns {{directory: string, logFile: string, environment: Object<string, string>}} What a caller needs to run with them.
 */
function installStandIns(directory, logFile, tools = ['sf', 'npm', 'npx'], options = {})
{
	fs.mkdirSync(directory, {recursive: true});
	const recorder = path.join(directory, 'stand-in.js');
	fs.writeFileSync(recorder, RECORDER_SOURCE);
	for(const tool of tools)
	{
		writeShim(directory, tool, process.execPath, [`"${recorder}"`, tool]);
	}
	if(!options.passThroughTools)
	{
		const environment = {};
		for(const [key, value] of Object.entries(process.env))
		{
			if(key.toUpperCase() !== 'PATH')
			{
				environment[key] = value;
			}
		}
		const inheritedPath = process.env.PATH || process.env.Path || '';
		environment.PATH = directory + path.delimiter + inheritedPath;
		environment.STAND_IN_LOG = logFile;
		return {directory, logFile, environment};
	}
	const baseEnvironment = options.baseEnvironment || process.env;
	for(const tool of options.passThroughTools)
	{
		const program = tool === 'node' ? process.execPath : resolveOnPath(tool, baseEnvironment);
		if(program)
		{
			writeShim(directory, tool, program, []);
		}
	}
	return {directory, logFile, environment: hermeticEnvironment(directory, logFile, baseEnvironment)};
}

/**
 * @description Reads the calls the stand-ins recorded, in order.
 * @param {string} logFile - The log file given to installStandIns.
 * @returns {Array<{tool: string, args: string[]}>} The recorded calls; empty when nothing ran.
 */
function readRecordedCalls(logFile)
{
	if(!fs.existsSync(logFile))
	{
		return [];
	}
	return fs.readFileSync(logFile, 'utf8').split('\n').filter(Boolean).map(line => JSON.parse(line));
}

module.exports = {installStandIns, readRecordedCalls, resolveOnPath};
