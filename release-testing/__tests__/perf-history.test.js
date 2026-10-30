// SPDX-License-Identifier: Apache-2.0
/**
 * @description The rolling performance baselines the load sections feed. Every test here pins what the tool
 * already does, line for line of its output, so the tool can be reshaped without its behaviour moving. The
 * file system is mocked throughout: the tracked history file is never read and never written.
 */
jest.mock('fs');

const fs = require('fs');
const {parseArguments, median, stdDev, harvestRows, classify, main} = require('../runner/perf-history');

const STANDARD_INPUT = 0;
const HISTORY_FILE = expect.stringContaining('perf-history.json');
const TEXT = {encoding: 'utf8'};

function perfRow(section, metric, value)
{
	return `PERF_ROW: ${JSON.stringify({section, metric, value})}`;
}

function printedLines()
{
	return console.log.mock.calls.map((call) => call[0]).join('\n');
}

function savedHistory()
{
	return JSON.parse(fs.writeFileSync.mock.calls[0][1]);
}

// The history file answers with the history the test set; every other read, the log file or standard input, answers
// with the test's input.
function runWith(argv, input, history)
{
	process.argv = [
		'node',
		'perf-history.js',
		...argv
	];
	fs.existsSync.mockReturnValue(history !== undefined);
	fs.readFileSync.mockImplementation((target) => (typeof target === 'string' && target.endsWith('perf-history.json') ? JSON.stringify(history) : input));
	main();
}

describe('parseArguments', () =>
{
	const realArguments = process.argv;

	afterEach(() =>
	{
		process.argv = realArguments;
	});

	it('reads a section and a log file given as separate words', () =>
	{
		process.argv = [
			'node',
			'perf-history.js',
			'--section',
			'44',
			'--logfile',
			'phase2.log'
		];

		expect(parseArguments()).toEqual({section: 44, logfile: 'phase2.log', report: false, reset: false, packageVersion: null});
	});

	it('reads a section and a log file given as one word with an equals sign', () =>
	{
		process.argv = [
			'node',
			'perf-history.js',
			'--section=51',
			'--logfile=other.log'
		];

		expect(parseArguments()).toEqual({section: 51, logfile: 'other.log', report: false, reset: false, packageVersion: null});
	});

	it('reads the two flags that take no value, and ignores an argument it does not know', () =>
	{
		process.argv = [
			'node',
			'perf-history.js',
			'--report',
			'--reset',
			'--whatever'
		];

		expect(parseArguments()).toEqual({section: null, logfile: null, report: true, reset: true, packageVersion: null});
	});

	it('ignores a section or a log file named last with nothing after it', () =>
	{
		process.argv = [
			'node',
			'perf-history.js',
			'--section'
		];

		expect(parseArguments()).toEqual({section: null, logfile: null, report: false, reset: false, packageVersion: null});
	});

	it('reads the package version the measurements were taken on, as a separate word or after an equals sign', () =>
	{
		process.argv = [
			'node',
			'perf-history.js',
			'--package-version',
			'1.8.0-5'
		];
		expect(parseArguments().packageVersion).toBe('1.8.0-5');
		process.argv = [
			'node',
			'perf-history.js',
			'--package-version=1.8.0-5'
		];
		expect(parseArguments().packageVersion).toBe('1.8.0-5');
	});

	it('names a development-org run by the source version with -dev, since no package is installed there', () =>
	{
		const sourceVersion = require('../../sfdx-project.json').packageDirectories.find((directory) => directory.default).versionNumber;
		process.argv = [
			'node',
			'perf-history.js',
			'--development-org'
		];
		expect(parseArguments().packageVersion).toBe(`${sourceVersion}-dev`);
	});
});

describe('median and stdDev', () =>
{
	it('takes the middle value of an odd-sized list and the mean of the middle two of an even-sized one', () =>
	{
		expect(median([
			5,
			1,
			3
		])).toBe(3);
		expect(median([
			4,
			1,
			3,
			2
		])).toBe(2.5);
	});

	it('leaves the list it was given in its own order', () =>
	{
		const values = [
			3,
			1,
			2
		];

		median(values);

		expect(values).toEqual([
			3,
			1,
			2
		]);
	});

	it('reports no spread for a single value and the population spread otherwise', () =>
	{
		expect(stdDev([7], 7)).toBe(0);
		expect(stdDev([
			2,
			4
		], 3)).toBe(1);
	});
});

describe('harvestRows', () =>
{
	it('reads every PERF_ROW object out of a log and leaves the rest of it alone', () =>
	{
		const input = `noise\n${perfRow(44, 'insertMs', 120)}\nmore noise\n${perfRow(45, 'queryMs', 30)}\n`;

		expect(harvestRows(input)).toEqual([
			{section: 44, metric: 'insertMs', value: 120},
			{section: 45, metric: 'queryMs', value: 30}
		]);
	});

	it('names an unreadable row on the error stream and keeps the readable ones', () =>
	{
		jest.spyOn(console, 'error').mockImplementation(() => undefined);

		expect(harvestRows(`PERF_ROW: {not json}\n${perfRow(44, 'insertMs', 120)}`)).toEqual([{section: 44, metric: 'insertMs', value: 120}]);
		expect(console.error).toHaveBeenCalledWith('Failed to parse PERF_ROW:', '{not json}');

		console.error.mockRestore();
	});

	it('finds nothing in a log without a PERF_ROW line', () =>
	{
		expect(harvestRows('just a log\n')).toEqual([]);
	});
});

describe('classify', () =>
{
	it('calls a metric with no baseline yet NEW', () =>
	{
		expect(classify(100, null)).toBe('NEW');
		expect(classify(100, undefined)).toBe('NEW');
	});

	it('grades a metric against its baseline: half again as slow is loud, a third slower is a warning, anything slower is a note', () =>
	{
		expect(classify(150, 100)).toBe('WARN!');
		expect(classify(130, 100)).toBe('WARN');
		expect(classify(101, 100)).toBe('INFO');
		expect(classify(100, 100)).toBe('OK');
		expect(classify(50, 100)).toBe('OK');
	});
});

describe('main', () =>
{
	const realArguments = process.argv;
	let exitSpy;

	beforeEach(() =>
	{
		jest.resetAllMocks();
		exitSpy = jest.spyOn(process, 'exit').mockImplementation(() => undefined);
		jest.spyOn(console, 'log').mockImplementation(() => undefined);
	});

	afterEach(() =>
	{
		process.argv = realArguments;
		jest.restoreAllMocks();
	});

	it('prints the whole history and writes nothing when it is asked to report', () =>
	{
		const history = {'section-44-insert': {insertMs: {history: [100], median: 100, stdDev: 0}}};

		runWith(['--report'], undefined, history);

		expect(printedLines()).toBe(JSON.stringify(history, null, 2));
		expect(fs.readFileSync).toHaveBeenCalledWith(HISTORY_FILE, TEXT);
		expect(fs.writeFileSync).not.toHaveBeenCalled();
	});

	it('reports an empty history when the file is not there yet', () =>
	{
		runWith(['--report'], undefined, undefined);

		expect(printedLines()).toBe('{}');
	});

	it('empties the whole history when it is reset without a section', () =>
	{
		runWith(['--reset'], undefined, {'section-44-insert': {insertMs: {history: [100], median: 100, stdDev: 0}}});

		expect(savedHistory()).toEqual({});
		expect(printedLines()).toBe('History reset.');
	});

	it('drops one section alone when the reset names it, and leaves the others', () =>
	{
		runWith([
			'--reset',
			'--section',
			'44'
		], undefined, {
			'section-44-insert': {insertMs: {history: [100], median: 100, stdDev: 0}}, 'section-45-query': {queryMs: {history: [30], median: 30, stdDev: 0}}
		});

		expect(savedHistory()).toEqual({'section-45-query': {queryMs: {history: [30], median: 30, stdDev: 0}}});
	});

	it('leaves the history untouched when the reset names a section it does not hold', () =>
	{
		runWith([
			'--reset',
			'--section',
			'99'
		], undefined, {'section-44-insert': {insertMs: {history: [100], median: 100, stdDev: 0}}});

		expect(savedHistory()).toEqual({'section-44-insert': {insertMs: {history: [100], median: 100, stdDev: 0}}});
	});

	it('says so and writes nothing when the input carries no measurements', () =>
	{
		runWith([], 'a log with nothing in it', undefined);

		expect(printedLines()).toBe('No PERF_ROW lines found in input.');
		expect(fs.writeFileSync).not.toHaveBeenCalled();
	});

	it('takes the input from the named log file rather than from standard input', () =>
	{
		runWith([
			'--logfile',
			'phase2.log'
		], perfRow(44, 'insertMs', 120), undefined);

		expect(fs.readFileSync).toHaveBeenCalledWith('phase2.log', TEXT);
	});

	it('takes the input from standard input when no log file is named', () =>
	{
		runWith([], perfRow(44, 'insertMs', 120), undefined);

		expect(fs.readFileSync).toHaveBeenCalledWith(STANDARD_INPUT, TEXT);
	});

	it('records a metric it has never seen before under a new section key, and calls it NEW', () =>
	{
		runWith([], perfRow(44, 'insertMs', 120), undefined);

		expect(savedHistory()).toEqual({'section-44-unknown': {insertMs: {history: [120], median: 120, stdDev: 0}}});
		expect(printedLines()).toBe('NEW   section-44 insertMs=120 (median was —)');
		expect(exitSpy).toHaveBeenCalledWith(0);
	});

	it('adds a measurement to the section key the history already holds and recomputes the baseline', () =>
	{
		runWith([], perfRow(44, 'insertMs', 140), {
			'section-44-bulk-insert': {
				insertMs: {
					history: [
						100,
						120
					], median: 110, stdDev: 10
				}
			}
		});

		expect(savedHistory()['section-44-bulk-insert'].insertMs).toEqual({
			history: [
				100,
				120,
				140
			], median: 120, stdDev: expect.closeTo(16.33, 2)
		});
		expect(printedLines()).toBe('INFO  section-44 insertMs=140 (median was 110)');
	});

	it('keeps only the five most recent measurements of a metric', () =>
	{
		runWith([], perfRow(44, 'insertMs', 60), {
			'section-44-bulk-insert': {
				insertMs: {
					history: [
						10,
						20,
						30,
						40,
						50
					], median: 30, stdDev: 0
				}
			}
		});

		expect(savedHistory()['section-44-bulk-insert'].insertMs.history).toEqual([
			20,
			30,
			40,
			50,
			60
		]);
	});

	it('gathers the warnings under their own heading once every row is printed', () =>
	{
		runWith([], `${perfRow(44, 'insertMs', 200)}\n${perfRow(44, 'queryMs', 31)}`, {
			'section-44-bulk-insert': {insertMs: {history: [100], median: 100, stdDev: 0}, queryMs: {history: [30], median: 30, stdDev: 0}}
		});

		expect(printedLines()).toBe([
			'WARN! section-44 insertMs=200 (median was 100)',
			'INFO  section-44 queryMs=31 (median was 30)',
			'\n=== Performance regressions ===',
			'WARN! section-44 insertMs=200 (median was 100)'
		].join('\n'));
	});

	it('takes only the rows of the section it was pointed at', () =>
	{
		runWith([
			'--section',
			'44'
		], `${perfRow(44, 'insertMs', 120)}\n${perfRow(45, 'queryMs', 30)}`, undefined);

		expect(savedHistory()).toEqual({'section-44-unknown': {insertMs: {history: [120], median: 120, stdDev: 0}}});
	});

	it('records under the package version it was given, beside the old key of the same section, never into it', () =>
	{
		const unknownVersion = {'section-83-unknown': {runs: {history: [3300], median: 3300, stdDev: 0}}};
		runWith([
			'--package-version',
			'1.8.0-5'
		], perfRow(83, 'runs', 3550), unknownVersion);

		expect(savedHistory()).toEqual({
			'section-83-unknown': {runs: {history: [3300], median: 3300, stdDev: 0}},
			'section-83-1.8.0-5': {runs: {history: [3550], median: 3550, stdDev: 0}}
		});
		expect(printedLines()).toBe('NEW   section-83 runs=3550 (median was —)');
	});
});
