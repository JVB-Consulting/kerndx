// SPDX-License-Identifier: Apache-2.0
// The exploration's command line: the seed, the session and step counts, the phases, and the volume
// options (the manifest, the output folder and the two timing budgets).
'use strict';

const {
	ALL_PHASES, SHAPED_PHASES, VOLUME_PHASE, SESSION_COUNT, STEPS_PER_SESSION, SEED_CEILING, DEFAULT_PAGE_OPEN_BUDGET_MILLISECONDS,
	DEFAULT_IN_PAGE_READ_BUDGET_MILLISECONDS
} = require('./constants');

const NUMBER_FLAGS = ['seed', 'sessions', 'steps', 'timing-budget-page', 'timing-budget-read'];
const TEXT_FLAGS = ['phases', 'manifest', 'output-directory'];
const USAGE = `Usage: node explore-consoles.js [--seed <number>] [--sessions <number>] [--steps <number>] [--phases ${ALL_PHASES.join(',')}]`
		+ ' [--manifest <path>] [--output-directory <folder>] [--timing-budget-page <ms>] [--timing-budget-read <ms>]';

/**
 * @description Refuses the command line with the reason and the usage line in one message, for the
 *              entry to print and exit on.
 * @param {string} message What was wrong.
 * @returns {Error} The error to throw.
 */
function refusal(message)
{
	return new Error(`${message}\n${USAGE}`);
}

/**
 * @description Pairs every flag with the value after it, refusing a flag the exploration does not
 *              know and a flag with nothing after it.
 * @param {Array<string>} argv The arguments after the script name.
 * @returns {Object} The flag values by flag name, without the leading dashes.
 */
function readFlagValues(argv)
{
	const values = {};
	for(let index = 0; index < argv.length; index += 2)
	{
		const flag = argv[index];
		const name = flag.startsWith('--') ? flag.slice(2) : null;
		if(!name || !(NUMBER_FLAGS.includes(name) || TEXT_FLAGS.includes(name)))
		{
			throw refusal(`the option ${flag} is not one this script knows`);
		}
		const value = argv[index + 1];
		if(value === undefined || value.startsWith('--'))
		{
			throw refusal(`${flag} needs a value after it`);
		}
		values[name] = value;
	}
	return values;
}

/**
 * @description The phases to run. Without a manifest the shaped walk; with one the volume walk, to which the
 *              shaped phases may be added by name (they then lay their seed down beside the load). The volume
 *              phase needs the manifest.
 * @param {string|undefined} requested The --phases value, comma-separated.
 * @param {string|null} manifest The --manifest path, or null.
 * @returns {Array<string>} The phases.
 */
function readPhases(requested, manifest)
{
	let phases = manifest ? [VOLUME_PHASE] : [...SHAPED_PHASES];
	if(requested)
	{
		phases = requested.split(',').map((phase) => phase.trim());
	}
	const unknown = phases.filter((phase) => !ALL_PHASES.includes(phase));
	if(unknown.length > 0)
	{
		throw refusal(`--phases knows only ${ALL_PHASES.join(', ')}; it does not know ${unknown.join(', ')}`);
	}
	if(!manifest && phases.includes(VOLUME_PHASE))
	{
		throw refusal(`the ${VOLUME_PHASE} phase walks a load the driver laid down, so it needs --manifest <path>`);
	}
	if(manifest && !phases.includes(VOLUME_PHASE))
	{
		// A manifest run always walks the load; the shaped phases named are added to that, never put in its place.
		phases.push(VOLUME_PHASE);
	}
	return phases;
}

/**
 * @description Reads the run's options, and refuses a run it could not report on: a seed that is not
 *              a number cannot be replayed, and a phase name nothing matches would walk nothing,
 *              write an empty findings file over the last run's and exit as though all was well. A
 *              refusal is thrown with the usage line; the entry prints it and exits.
 * @param {Array<string>} argv The arguments after the script name.
 * @returns {Object} The seed, the session and step counts, the phases, the manifest and output paths and the timing budgets.
 */
function parseArguments(argv)
{
	const values = readFlagValues(argv);
	const number = (name, fallback) =>
	{
		if(values[name] === undefined)
		{
			return fallback;
		}
		const value = Number(values[name]);
		if(!Number.isFinite(value) || value <= 0)
		{
			throw refusal(`--${name} needs a positive number, not "${values[name]}"`);
		}
		return value;
	};
	const manifest = values.manifest || null;
	const phases = readPhases(values.phases, manifest);
	return {
		seed: number('seed', Math.floor(Math.random() * SEED_CEILING)),
		sessions: number('sessions', SESSION_COUNT),
		steps: number('steps', STEPS_PER_SESSION),
		phases,
		manifest,
		outputDirectory: values['output-directory'] || null,
		timingBudgets: {
			pageOpenMilliseconds: number('timing-budget-page', DEFAULT_PAGE_OPEN_BUDGET_MILLISECONDS),
			inPageReadMilliseconds: number('timing-budget-read', DEFAULT_IN_PAGE_READ_BUDGET_MILLISECONDS)
		}
	};
}

module.exports = {parseArguments, USAGE};
