#!/usr/bin/env node
// SPDX-License-Identifier: BUSL-1.1

const fs = require('fs');
const path = require('path');

const HISTORY_PATH = path.resolve(__dirname, '../results/perf-history.json');
const MAX_HISTORY = 5;
const WARN_RATIO = 1.3;
const LOUD_RATIO = 1.5;
const VERDICT_WIDTH = 5;
const STANDARD_INPUT = 0;
const UNKNOWN_VERSION = 'unknown';

// The options that take a value, either as the next word or after an equals sign.
const VALUE_ARGUMENTS = new Map([
	[
		'--section',
		(settings, value) =>
		{
			settings.section = parseInt(value, 10);
		}
	],
	[
		'--logfile',
		(settings, value) =>
		{
			settings.logfile = value;
		}
	],
	[
		'--package-version',
		(settings, value) =>
		{
			settings.packageVersion = value;
		}
	]
]);

// The options that are a switch on their own.
const FLAG_ARGUMENTS = new Map([
	[
		'--report',
		(settings) =>
		{
			settings.report = true;
		}
	],
	[
		'--reset',
		(settings) =>
		{
			settings.reset = true;
		}
	],
	[
		'--development-org',
		(settings) =>
		{
			settings.packageVersion = developmentVersion();
		}
	]
]);

/**
 * @description The version a development-org run is filed under: the source's version number with -dev, because no
 * package is installed on that org. The subscriber-org run records the real build with --package-version instead.
 * @return {string} the version, for example 1.8.0.NEXT-dev
 */
function developmentVersion()
{
	const project = require('../../sfdx-project.json');
	return `${project.packageDirectories.find((directory) => directory.default).versionNumber}-dev`;
}

/**
 * @description Applies one command-line word and says how many words it used up: two for `--name value`,
 * one for `--name=value`, for a switch and for anything the tool does not know.
 * @param {object} settings the options gathered so far
 * @param {string} argument the word
 * @param {string|undefined} nextArgument the word after it
 * @return {number} the number of words used up
 */
function applyArgument(settings, argument, nextArgument)
{
	const [name, inlineValue] = argument.split('=');
	const setValue = VALUE_ARGUMENTS.get(name);
	if(setValue && inlineValue !== undefined)
	{
		setValue(settings, inlineValue);
		return 1;
	}
	if(setValue && nextArgument)
	{
		setValue(settings, nextArgument);
		return 2;
	}
	const setFlag = FLAG_ARGUMENTS.get(argument);
	if(setFlag)
	{
		setFlag(settings);
	}
	return 1;
}

/**
 * @description Reads the command line.
 * @return {object} the section to keep to, the log file to read, whether to report or to reset, and the package
 * version the measurements were taken on (null when the command line named none)
 */
function parseArguments()
{
	const args = process.argv.slice(2);
	const settings = {section: null, logfile: null, report: false, reset: false, packageVersion: null};
	let index = 0;
	while(index < args.length)
	{
		index += applyArgument(settings, args[index], args[index + 1]);
	}
	return settings;
}

function loadHistory()
{
	if(!fs.existsSync(HISTORY_PATH))
	{
		return {};
	}
	return JSON.parse(fs.readFileSync(HISTORY_PATH, {encoding: 'utf8'}));
}

function saveHistory(history)
{
	fs.writeFileSync(HISTORY_PATH, JSON.stringify(history, null, 2));
}

function median(values)
{
	const sorted = [...values].sort((a, b) => a - b);
	const mid = Math.floor(sorted.length / 2);
	return sorted.length % 2 === 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid];
}

function stdDev(values, mean)
{
	if(values.length < 2)
	{
		return 0;
	}
	const variance = values.reduce((s, v) => s + Math.pow(v - mean, 2), 0) / values.length;
	return Math.sqrt(variance);
}

function harvestRows(input)
{
	const rows = [];
	// Fresh for every call: a global pattern remembers where it stopped.
	const rowPattern = /PERF_ROW:\s*(\{[^}]+})/g;
	let match;
	while((match = rowPattern.exec(input)) !== null)
	{
		try
		{
			rows.push(JSON.parse(match[1]));
		}
		catch
		{
			console.error('Failed to parse PERF_ROW:', match[1]);
		}
	}
	return rows;
}

function classify(value, currentMedian)
{
	if(currentMedian === undefined || currentMedian === null)
	{
		return 'NEW';
	}
	const ratio = value / currentMedian;
	if(ratio >= LOUD_RATIO)
	{
		return 'WARN!';
	}
	if(ratio >= WARN_RATIO)
	{
		return 'WARN';
	}
	if(ratio > 1.0)
	{
		return 'INFO';
	}
	return 'OK';
}

/**
 * @description The key the history holds a section's metrics under, whatever name the section was recorded with.
 * @param {object} history the whole history
 * @param {number} section the section number
 * @return {string|undefined} the key, or undefined when the history holds none for that section
 */
function findSectionKey(history, section)
{
	return Object.keys(history).find((key) => key.startsWith(`section-${section}-`));
}

/**
 * @description Empties the history, or drops the one section the command line named, and saves it.
 * @param {object} history the whole history
 * @param {number|null} section the section to drop, or null for all of them
 */
function resetHistory(history, section)
{
	const sectionKey = section ? findSectionKey(history, section) : null;
	const remaining = section ? history : {};
	if(sectionKey)
	{
		delete remaining[sectionKey];
	}
	saveHistory(remaining);
	console.log('History reset.');
}

/**
 * @description The measurements to read: the named log file, or whatever was piped in.
 * @param {string|null} logfile the log file the command line named, or null
 * @return {string} the text to harvest the measurements from
 */
function readInput(logfile)
{
	return logfile ? fs.readFileSync(logfile, {encoding: 'utf8'}) : fs.readFileSync(STANDARD_INPUT, {encoding: 'utf8'});
}

/**
 * @description Adds one measurement to the history, grades it against the baseline it had before, and
 * recomputes that baseline. With a package version the measurement goes under that version's own key, so a new
 * release starts its own baseline; without one it goes under whatever key the section already has.
 * @param {object} history the whole history
 * @param {object} row the measurement: its section, its metric and its value
 * @param {string|null} packageVersion the package version the measurement was taken on, or null when unknown
 * @return {{verdict: string, message: string}} the grade and the line to print for it
 */
function recordRow(history, row, packageVersion)
{
	const sectionKey = packageVersion ? `section-${row.section}-${packageVersion}` : findSectionKey(history, row.section) || `section-${row.section}-${UNKNOWN_VERSION}`;
	if(!history[sectionKey])
	{
		history[sectionKey] = {};
	}
	if(!history[sectionKey][row.metric])
	{
		history[sectionKey][row.metric] = {history: [], median: null, stdDev: 0};
	}

	const entry = history[sectionKey][row.metric];
	const currentMedian = entry.median;
	const verdict = classify(row.value, currentMedian);

	entry.history.push(row.value);
	if(entry.history.length > MAX_HISTORY)
	{
		entry.history.shift();
	}
	entry.median = median(entry.history);
	entry.stdDev = stdDev(entry.history, entry.median);

	const message = `${verdict.padEnd(VERDICT_WIDTH)} section-${row.section}`
		+ ` ${row.metric}=${row.value} (median was ${currentMedian || '—'})`;
	return {verdict, message};
}

/**
 * @description Repeats the graded rows that were slower than their baseline, under their own heading.
 * @param {string[]} warnings the lines already printed for those rows
 */
function reportWarnings(warnings)
{
	if(warnings.length === 0)
	{
		return;
	}
	console.log('\n=== Performance regressions ===');
	warnings.forEach((warning) => console.log(warning));
}

/**
 * @description Records every measurement, prints a line for each, saves the history and gathers the
 * regressions under their own heading.
 * @param {object} history the whole history
 * @param {object[]} rows the measurements
 * @param {number|null} section the only section to take, or null for all of them
 * @param {string|null} packageVersion the package version the measurements were taken on, or null when unknown
 */
function recordRows(history, rows, section, packageVersion)
{
	const warnings = [];
	for(const row of rows.filter((candidate) => !section || candidate.section === section))
	{
		const {verdict, message} = recordRow(history, row, packageVersion);
		console.log(message);
		if(verdict === 'WARN' || verdict === 'WARN!')
		{
			warnings.push(message);
		}
	}

	saveHistory(history);
	reportWarnings(warnings);
}

function main()
{
	const settings = parseArguments();
	const history = loadHistory();

	if(settings.report)
	{
		console.log(JSON.stringify(history, null, 2));
		return;
	}

	if(settings.reset)
	{
		resetHistory(history, settings.section);
		return;
	}

	const rows = harvestRows(readInput(settings.logfile));

	if(rows.length === 0)
	{
		console.log('No PERF_ROW lines found in input.');
		return;
	}

	recordRows(history, rows, settings.section, settings.packageVersion);

	process.exit(0);
}

if(require.main === module)
{
	main();
}

module.exports = {parseArguments, median, stdDev, harvestRows, classify, main};
