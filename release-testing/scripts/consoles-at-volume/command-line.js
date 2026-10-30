// SPDX-License-Identifier: Apache-2.0
// The driver's command line: one subcommand, the mode and size, where the manifest lives, which org.
const path = require('path');
const {authFolderName} = require('../../e2e/helpers/auth-paths');

const COMMANDS = [
	'run',
	'status',
	'preflight',
	'launch',
	'drain',
	'operate',
	'verify',
	'teardown'
];
const MODES = [
	'staged',
	'full'
];
// Each org's load gets its own folder under this one, named after the org alias, so two orgs never share a manifest.
const VOLUME_OUTPUT_ROOT = path.join(__dirname, '..', '..', '..', 'tmp', 'consoles-at-volume');
// The id scheme spells ordinals in four letters (1,296 values); a nested import's root ordinal of 1,000 plus the action's runs out above size 1.
const MAXIMUM_SIZE = 1;
const USAGE = `Usage: node release-testing/scripts/consoles-at-volume.js <${COMMANDS.join('|')}> [--mode staged|full] [--size <factor>] [--output-directory <dir>] `
		+ '[--org <alias>] [--reuse] [--stalled-started <rows>]';
const WHOLE_NUMBER = /^\d+$/;

/**
 * @description Sets the mode, one of MODES.
 *
 * @param {object} options The options being read.
 * @param {string} value The word after `--mode`.
 */
function setMode(options, value)
{
	if(!MODES.includes(value))
	{
		throw new Error(`Unknown mode "${value}". ${USAGE}`);
	}
	options.mode = value;
}

/**
 * @description Sets the size factor, a positive number.
 *
 * @param {object} options The options being read.
 * @param {string} value The word after `--size`.
 */
function setSize(options, value)
{
	options.size = Number(value);
	if(!Number.isFinite(options.size) || options.size <= 0 || options.size > MAXIMUM_SIZE)
	{
		throw new Error(`The size must be a number above zero and at most ${MAXIMUM_SIZE}, not "${value}". ${USAGE}`);
	}
}

/**
 * @description Sets the output directory, resolved against the working directory.
 *
 * @param {object} options The options being read.
 * @param {string} value The word after `--output-directory`.
 */
function setOutputDirectory(options, value)
{
	options.outputDirectory = path.resolve(value);
}

/**
 * @description Sets the org alias.
 *
 * @param {object} options The options being read.
 * @param {string} value The word after `--org`.
 */
function setAlias(options, value)
{
	options.alias = value;
}

/**
 * @description Sets how many Stalled rows the operate stage lays whose current step had started, for the watchdog to
 * end Failed. Zero, the default, lays none.
 *
 * @param {object} options The options being read.
 * @param {string} value The word after `--stalled-started`.
 */
function setStalledStarted(options, value)
{
	if(!WHOLE_NUMBER.test(String(value)))
	{
		throw new Error(`The row count after --stalled-started must be a whole number of zero or more, not "${value}". ${USAGE}`);
	}
	options.stalledStarted = Number(value);
}

/**
 * @description Marks the run as one that reuses a verified load.
 *
 * @param {object} options The options being read.
 */
function setReuse(options)
{
	options.reuse = true;
}

/**
 * @description The folder one org's load keeps its manifest and logs in when no `--output-directory` is given.
 *
 * @param {string} alias The org alias the run points at.
 *
 * @returns {string} The org's folder under tmp/consoles-at-volume/, named the same safe way as its sign-in folder.
 */
function outputDirectoryFor(alias)
{
	return path.join(VOLUME_OUTPUT_ROOT, authFolderName(alias));
}

// Each option that takes a value, and each that stands alone: what it sets on the options.
const VALUE_OPTIONS = {'--mode': setMode, '--size': setSize, '--output-directory': setOutputDirectory, '--org': setAlias, '--stalled-started': setStalledStarted};
const FLAG_OPTIONS = {'--reuse': setReuse};

/**
 * @description Reads the command line; throws with a usage line on anything it does not know.
 *
 * @param {string[]} argv The arguments after the script name.
 * @param {object} defaults `alias`, the org when `--org` is absent.
 *
 * @returns {{command: string, mode: string, size: number, outputDirectory: string, manifestPath: string, alias: string, reuse: boolean, stalledStarted: number}}
 */
function parseCommandLine(argv, {alias})
{
	const [command, ...rest] = argv;
	if(!COMMANDS.includes(command))
	{
		throw new Error(`Unknown command "${command}". ${USAGE}`);
	}
	const options = {command, mode: 'staged', size: 1, outputDirectory: null, alias, reuse: false, stalledStarted: 0, manifestPath: ''};
	const words = [...rest];
	while(words.length > 0)
	{
		const word = words.shift();
		if(VALUE_OPTIONS[word])
		{
			VALUE_OPTIONS[word](options, words.shift());
		}
		else if(FLAG_OPTIONS[word])
		{
			FLAG_OPTIONS[word](options);
		}
		else
		{
			throw new Error(`Unknown argument "${word}". ${USAGE}`);
		}
	}
	// Read after every option, so the folder follows the org `--org` names wherever it stands on the line.
	options.outputDirectory ??= outputDirectoryFor(options.alias);
	options.manifestPath = path.join(options.outputDirectory, 'manifest.json');
	return options;
}

module.exports = {COMMANDS, MODES, USAGE, VOLUME_OUTPUT_ROOT, outputDirectoryFor, parseCommandLine};
