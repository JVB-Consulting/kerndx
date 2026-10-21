#!/usr/bin/env node
// SPDX-License-Identifier: BUSL-1.1
'use strict';

/**
 * @description Runs the package's Apex tests on aer, a local Apex runtime that needs no org, and records the result.
 *
 *              The script finds every test method under force-app/main/default/classes/*_TEST.cls, then asks aer
 *              whether this computer has an aer licence (`aer license show`). With a licence, it runs every test in
 *              one aer run. Without one, what it does depends on UNLICENSED_RUNS_MAY_BATCH below. When that is true,
 *              it runs the tests in groups of at most 100 test methods, four groups at once, because aer's free tier
 *              runs at most 100 test methods at a time. When it is false, it does not run the tests: it says that a
 *              full run needs an aer licence and stops. To register a licence, run `aer license register <key>`;
 *              licences come from https://portal.aertest.com/.
 *              By default it runs on a clean copy of the current commit (git archive), so the result belongs to that
 *              commit and to nothing else in the working tree. That copy has no profiles folder, the same as the
 *              public repository, so pass `-p Administrator` to run as a user who holds the Administrator permission
 *              set.
 *
 *              Two modes:
 *              - record (the default): writes verify-results/aer-run.json, the figure the Metrics guide and the
 *                README badge show, with the commit and the release it belongs to. Each failure carries the category
 *                the baseline gives it ("runtime gap": aer behaves differently from Salesforce; "profile": the copy
 *                has no profiles folder, so a test user lacks access a real org would give; "unclassified": it passes
 *                in an org and the cause is not yet known), or "unclassified" when the baseline does not list it, and
 *                its first error line for information.
 *              - gate (`--gate <baseline>`): compares the run with a list of known failures. It fails on a failure
 *                whose test is not in the list, and on a test aer reported no result for. It warns about a listed test
 *                that now passes or no longer exists. It never compares error text, which changes between aer
 *                versions. The category is compared too, but in a gate run it is read from the same list, so that
 *                part only catches a record written against a different list.
 *
 *              Usage:
 *                node scripts/aer-run.js -p Administrator
 *                node scripts/aer-run.js --gate scripts/aer-baseline.json -p Administrator
 *                node scripts/aer-run.js --dry-run
 *              Options: --source <folder> runs on an existing project folder instead of a copy of the commit;
 *              --out <file> sets where the result is written; --work <folder> sets the working folder
 *              (default tmp/aer-run).
 *
 *              Exit codes: 0 done (gate passed), 1 the gate failed, 2 the run could not start (this includes a run
 *              with no aer licence when UNLICENSED_RUNS_MAY_BATCH is false).
 *
 * @author Kern Framework
 * @date October 2026
 */

const fs = require('node:fs');
const path = require('node:path');
const {spawn, execFileSync} = require('node:child_process');

const REPOSITORY_ROOT = path.resolve(__dirname, '..');
const BATCH_LIMIT = 100;
const CONCURRENT_RUNS = 4;
const CLASSES_FOLDER = path.join('force-app', 'main', 'default', 'classes');
const DEFAULT_WORK_FOLDER = path.join(REPOSITORY_ROOT, 'tmp', 'aer-run');
const DEFAULT_RECORD = path.join(REPOSITORY_ROOT, 'verify-results', 'aer-run.json');
const DEFAULT_BASELINE = path.join(REPOSITORY_ROOT, 'scripts', 'aer-baseline.json');
const NO_RESULT = 'no result reported';
const UNCLASSIFIED = 'unclassified';
const BASELINE_CATEGORIES = ['runtime gap', 'profile', UNCLASSIFIED];

/**
 * @description The text `aer license show` prints when this computer has no aer licence. The command still exits 0
 * then, so the script looks for this text as well as the exit code. The script ignores upper and lower case when it
 * looks, so `LICENSE ERROR` or `license error` also mean there is no licence.
 */
const LICENCE_ERROR_MARKER = 'license error';

/**
 * @description Says whether a run without an aer licence may split the tests into groups of at most 100 test
 * methods, so that aer's free tier can run them. When it is true, such a run runs the groups. When it is false, such
 * a run does not start: it says that a full run needs an aer licence and exits with code 2 (a dry run says the same
 * and exits with code 0). The copy of this script in the public repository has it set to false.
 */
const UNLICENSED_RUNS_MAY_BATCH = false;

/**
 * @description The message a run without an aer licence prints when UNLICENSED_RUNS_MAY_BATCH is false.
 */
const LICENCE_NEEDED_MESSAGE = 'A full run needs an aer licence, and aer has none. Register one with `aer license register <key>`; '
	+ 'get one at https://portal.aertest.com/.';

// A test method: `@IsTest` with no options or with options, any further annotations, then `static void name(`.
// The class-level `@IsTest(...)` is followed by `class`, not `static void`, so it never matches.
const TEST_METHOD_PATTERN = /@IsTest\b[^\n]*\n(?:[ \t]*@\w+[^\n]*\n)*[ \t]*(?:(?:private|public|global)\s+)?static\s+void\s+(\w+)\s*\(/gi;

/**
 * @description Finds every test class and its test methods in a classes folder.
 *
 * @param {string} classesFolder
 * @return {Array<{className: string, methods: string[]}>} sorted by class name
 */
function discoverTestClasses(classesFolder)
{
	if(!fs.existsSync(classesFolder))
	{
		return [];
	}
	return fs.readdirSync(classesFolder)
	.filter(name => name.endsWith('_TEST.cls'))
	.sort()
	.map(file =>
	{
		const source = fs.readFileSync(path.join(classesFolder, file), 'utf8');
		const methods = [...source.matchAll(TEST_METHOD_PATTERN)].map(match => match[1]);
		return {className: file.replace(/\.cls$/, ''), methods};
	});
}

/**
 * @description Groups the test classes into runs of at most `limit` methods. Whole classes share a run while they
 * fit, named `Class.*`; a class with more methods than the limit is split into runs of single methods.
 *
 * @param {Array<{className: string, methods: string[]}>} classes
 * @param {number} limit
 * @return {Array<{filters: string[], methodCount: number}>}
 */
function buildBatches(classes, limit)
{
	const batches = [];
	let current = null;
	for(const {className, methods} of classes)
	{
		if(methods.length === 0)
		{
			continue;
		}
		if(methods.length > limit)
		{
			for(let start = 0; start < methods.length; start += limit)
			{
				const slice = methods.slice(start, start + limit);
				batches.push({filters: slice.map(method => `${className}.${method}`), methodCount: slice.length});
			}
			continue;
		}
		if(!current || current.methodCount + methods.length > limit)
		{
			current = {filters: [], methodCount: 0};
			batches.push(current);
		}
		current.filters.push(`${className}.*`);
		current.methodCount += methods.length;
	}
	return batches;
}

/**
 * @description Reads aer's JSON Lines output: one row per test with `passed` and, on a failure, `errorMessage`.
 * Lines that are not a test result are ignored.
 *
 * @param {string} text
 * @return {Array<{testName: string, passed: boolean, errorMessage: string}>}
 */
function parseResultRows(text)
{
	const rows = [];
	for(const line of text.split('\n'))
	{
		if(!line.trim())
		{
			continue;
		}
		let row;
		try
		{
			row = JSON.parse(line);
		}
		catch
		{
			continue;
		}
		if(typeof row.passed !== 'boolean')
		{
			continue;
		}
		rows.push({testName: row.testName || `${row.className}.${row.methodName}`, passed: row.passed, errorMessage: row.errorMessage || ''});
	}
	return rows;
}

/**
 * @description Reads the version number from the output of `aer --version`.
 *
 * @param {string} output
 * @return {string} for example "1.4.23"
 */
function parseAerVersion(output)
{
	const match = output.match(/aer version v?(\d+\.\d+\.\d+)/);
	if(!match)
	{
		throw new Error(`Could not read the aer version from: ${output.trim()}`);
	}
	return match[1];
}

/**
 * @description Builds the record of one full run. The total counts every test found in the source and every test
 * aer reported, so a test aer ran but the search missed still counts. A test with no result is a failure.
 *
 * @param {object} input aerVersion, commit, measuredAt, permissionSet, classes, rows, durationSeconds, baseline
 * @return {object} the record written to verify-results/aer-run.json
 */
function buildRecord({aerVersion, commit, release, measuredAt, permissionSet, classes, rows, durationSeconds, baseline})
{
	const results = new Map();
	for(const row of rows)
	{
		results.set(row.testName, row);
	}
	const names = new Set(results.keys());
	for(const {className, methods} of classes)
	{
		for(const method of methods)
		{
			names.add(`${className}.${method}`);
		}
	}
	const categories = new Map((baseline?.failures ?? []).map(entry => [entry.test, entry.category]));
	const failures = [];
	let passed = 0;
	for(const name of [...names].sort())
	{
		const result = results.get(name);
		if(result?.passed)
		{
			passed++;
			continue;
		}
		const error = result ? result.errorMessage.split('\n')[0].trim() : NO_RESULT;
		failures.push({test: name, error, category: categories.get(name) ?? UNCLASSIFIED});
	}
	return {aerVersion, commit, release, measuredAt, permissionSet, total: names.size, passed, failures, durationSeconds: Math.round(durationSeconds)};
}

/**
 * @description Reads the list of known failures and checks that each entry names a known category. A missing file
 * gives an empty list.
 *
 * @param {string} file
 * @return {{failures: Array<{test: string, category: string, detail: string}>}}
 */
function readBaseline(file)
{
	if(!fs.existsSync(file))
	{
		return {failures: []};
	}
	const baseline = JSON.parse(fs.readFileSync(file, 'utf8'));
	for(const entry of baseline.failures)
	{
		if(!BASELINE_CATEGORIES.includes(entry.category))
		{
			throw new Error(`${file}: ${entry.test} has the category "${entry.category}"; use one of: ${BASELINE_CATEGORIES.join(', ')}`);
		}
	}
	return baseline;
}

/**
 * @description Compares a run with the list of known failures. A failure is known when the list holds the same test
 * with the same category; the error text is never compared.
 *
 * @param {{failures: Array<{test: string, error: string, category: string}>}} record
 * @param {{failures: Array<{test: string, category: string}>}} baseline
 * @return {{unexpected: Array<object>, notRun: string[], nowPassing: string[]}}
 */
function compareWithBaseline(record, baseline)
{
	const known = new Map(baseline.failures.map(entry => [entry.test, entry.category]));
	const failing = new Set(record.failures.map(failure => failure.test));
	return {
		unexpected: record.failures.filter(failure => failure.error !== NO_RESULT && known.get(failure.test) !== failure.category),
		notRun: record.failures.filter(failure => failure.error === NO_RESULT).map(failure => failure.test),
		nowPassing: baseline.failures.map(entry => entry.test).filter(test => !failing.has(test))
	};
}

/**
 * @description Names the release a run belongs to, in words a reader of the public repository can find: the release
 * tag that points at the commit (for example "v1.8.0-4"), or, before the release is tagged, "the X.Y release candidate"
 * for the version line being built. A project file with no version line, such as the public repository's, holds only
 * the alias of the release it was taken from, so that alias names the release (for example "v1.7.0-13"). With neither,
 * there is no release to name. The commit itself stays in the record for the maintainers.
 *
 * @param {string[]} tags the tags that point at the commit
 * @param {object} project the parsed sfdx-project.json
 * @return {?string} the release, or null when the project file names none
 */
function describeRelease(tags, project)
{
	const tag = tags.find(name => /^v\d+\.\d+\.\d+-\d+$/.test(name));
	if(tag)
	{
		return tag;
	}
	const versionNumber = (project.packageDirectories || []).map(directory => directory.versionNumber).find(Boolean);
	const line = String(versionNumber ?? '').match(/^(\d+)\.(\d+)\./);
	if(line)
	{
		return `the ${line[1]}.${line[2]} release candidate`;
	}
	const aliases = Object.keys(project.packageAliases || {})
	.map(alias => alias.match(/@(\d+)\.(\d+)\.(\d+)-(\d+)$/))
	.filter(Boolean)
	.sort((left, right) => left.slice(1).reduce((difference, part, index) => difference || Number(part) - Number(right[index + 1]), 0));
	return aliases.length ? `v${aliases[aliases.length - 1].slice(1, 4).join('.')}-${aliases[aliases.length - 1][4]}` : null;
}

/**
 * @description Reads the command-line options.
 *
 * @param {string[]} argv
 * @return {{dryRun: boolean, permissionSet: ?string, gate: ?string, source: ?string, out: ?string, work: ?string}}
 */
function parseArguments(argv)
{
	const options = {dryRun: false, permissionSet: null, gate: null, source: null, out: null, work: null};
	const valued = {'-p': 'permissionSet', '--gate': 'gate', '--source': 'source', '--out': 'out', '--work': 'work'};
	for(let index = 0; index < argv.length; index++)
	{
		const argument = argv[index];
		if(argument === '--dry-run')
		{
			options.dryRun = true;
			continue;
		}
		const key = valued[argument];
		if(!key)
		{
			throw new Error(`Unknown option: ${argument}`);
		}
		const value = argv[index + 1];
		if(value === undefined)
		{
			throw new Error(`${argument} needs a value`);
		}
		options[key] = value;
		index++;
	}
	return options;
}

/**
 * @description Writes a count with its word, in the plural when the count is not one.
 *
 * @param {number} count
 * @param {string} word
 * @return {string} for example "1 class" or "3 classes"
 */
function plural(count, word)
{
	return `${count} ${word}${count === 1 ? '' : (word.endsWith('s') ? 'es' : 's')}`;
}

/**
 * @description Checks whether this computer has an aer licence. It does only when `aer license show` exits 0 and
 * prints some text, and that text does not hold the licence error text in any case. A command that cannot start, a
 * non-zero exit, empty output, or that text all mean there is no licence.
 *
 * @param {Function} runAer starts aer with the given arguments
 * @param {string} folder the folder aer runs in
 * @return {Promise<boolean>} true when aer has a licence
 */
async function hasAerLicence(runAer, folder)
{
	const result = await runAer(['license', 'show'], {cwd: folder});
	const output = (result.output || '').trim();
	return !result.error && result.code === 0 && output !== '' && !output.toLowerCase().includes(LICENCE_ERROR_MARKER);
}

/**
 * @description Starts one aer test run and reads its result rows. A run with no filters runs every test in force-app.
 *
 * @param {{filters: string[], methodCount: number}} batch the tests to run
 * @param {string} label names the run's result and log files in the working folder
 * @param {object} settings runAer, source, work, permissionSet
 * @return {Promise<Array<{testName: string, passed: boolean, errorMessage: string}>>}
 */
async function runOneAerTest(batch, label, {runAer, source, work, permissionSet})
{
	const jsonFile = path.join(work, `${label}.jsonl`);
	const args = ['test', 'force-app', '--skip-errors', `--json=${jsonFile}`];
	if(permissionSet)
	{
		args.push('-p', permissionSet);
	}
	for(const filter of batch.filters)
	{
		args.push('-f', filter);
	}
	const result = await runAer(args, {cwd: source});
	fs.writeFileSync(path.join(work, `${label}.log`), result.output);
	return fs.existsSync(jsonFile) ? parseResultRows(fs.readFileSync(jsonFile, 'utf8')) : [];
}

/**
 * @description Runs the groups of tests, four at once, as aer's free tier needs, and gathers every result row.
 *
 * @param {Array<{filters: string[], methodCount: number}>} batches
 * @param {object} settings runAer, source, work, permissionSet, log
 * @return {Promise<Array<{testName: string, passed: boolean, errorMessage: string}>>}
 */
async function runBatches(batches, settings)
{
	const queue = batches.map((batch, index) => ({batch, number: index + 1}));
	const rows = [];
	async function worker()
	{
		while(queue.length)
		{
			const {batch, number} = queue.shift();
			rows.push(...await runOneAerTest(batch, `batch-${String(number).padStart(3, '0')}`, settings));
			settings.log(`run ${number} of ${batches.length} finished (${batch.methodCount} methods)`);
		}
	}
	await Promise.all(Array.from({length: CONCURRENT_RUNS}, worker));
	return rows;
}

/**
 * @description Runs every test in one aer run, as a licensed aer allows. When aer reports fewer results than the
 * number of test methods found, it warns that the licence may not be in force, because aer without a licence stops
 * after 100 test methods. The record and the exit code stay the same; the warning only makes the gap visible.
 *
 * @param {number} methodCount the number of test methods found, for the progress log and the warning
 * @param {object} settings runAer, source, work, permissionSet, log, warn
 * @return {Promise<Array<{testName: string, passed: boolean, errorMessage: string}>>}
 */
async function runWholeSuite(methodCount, settings)
{
	settings.log(`Running all ${plural(methodCount, 'test method')} in one aer run.`);
	const rows = await runOneAerTest({filters: [], methodCount}, 'run', settings);
	settings.log(`The run finished: aer reported ${plural(rows.length, 'result')}.`);
	if(rows.length < methodCount)
	{
		settings.warn(`aer reported results for ${rows.length} of ${methodCount} test methods: the aer licence may not be in force. Check it with \`aer license show\`.`);
	}
	return rows;
}

/**
 * @description Prints what the gate found and gives the exit code: 1 when a test failed outside the baseline or
 * reported no result, otherwise 0.
 *
 * @param {object} record the record of the run
 * @param {object} baseline the list of known failures
 * @param {{log: Function, warn: Function}} output
 * @return {number} the exit code
 */
function reportGate(record, baseline, {log, warn})
{
	const {unexpected, notRun, nowPassing} = compareWithBaseline(record, baseline);
	for(const test of nowPassing)
	{
		warn(`${test} is in the baseline but now passes or no longer exists: remove it from the baseline.`);
	}
	// An entry whose cause is not yet known must not sit silently in the baseline: every run says so until it is narrowed.
	const stillFailing = new Set(record.failures.map(failure => failure.test));
	for(const entry of baseline.failures.filter(known => known.category === UNCLASSIFIED && stillFailing.has(known.test)))
	{
		warn(`${entry.test} is in the baseline as ${UNCLASSIFIED}: its cause is not yet known. Narrow it, then give it a category or fix it.`);
	}
	for(const failure of unexpected)
	{
		log(`FAIL ${failure.test} failed and is not in the baseline: ${failure.error}`);
	}
	for(const test of notRun)
	{
		log(`FAIL ${test} did not run: aer reported no result for it`);
	}
	if(unexpected.length || notRun.length)
	{
		log(`Gate failed: ${unexpected.length} new failure(s), ${notRun.length} test(s) with no result.`);
		return 1;
	}
	log('Gate passed: every failure is a known one.');
	return 0;
}

/**
 * @description Runs the script. Every outside effect (aer, git, the clock, the console) comes in through
 * `dependencies`, so the tests can stand in for aer.
 *
 * @param {string[]} argv
 * @param {object} dependencies runAer, readCommit, readRelease, prepareSource, now, log, warn, and optionally
 * unlicensedRunsMayBatch, which takes the place of UNLICENSED_RUNS_MAY_BATCH when it is given
 * @return {Promise<number>} the exit code
 */
async function run(argv, dependencies)
{
	const {runAer, readCommit, readRelease, prepareSource, now, log, warn} = dependencies;
	const unlicensedRunsMayBatch = dependencies.unlicensedRunsMayBatch ?? UNLICENSED_RUNS_MAY_BATCH;
	let options;
	try
	{
		options = parseArguments(argv);
	}
	catch(error)
	{
		log(error.message);
		return 2;
	}
	const work = path.resolve(options.work || DEFAULT_WORK_FOLDER);
	if(options.gate && !fs.existsSync(options.gate))
	{
		log(`The baseline file ${options.gate} does not exist.`);
		return 2;
	}
	// A dry run reads the working tree (or --source); a real run first takes its clean copy of the commit and
	// finds the tests in that copy, so uncommitted test changes never leak into the count.
	let tree = options.source ? path.resolve(options.source) : null;
	let aerVersion = null;
	if(!options.dryRun)
	{
		fs.rmSync(work, {recursive: true, force: true});
		fs.mkdirSync(work, {recursive: true});
		const version = await runAer(['--version'], {cwd: work});
		if(version.error || version.code !== 0)
		{
			log('aer was not found, or it could not start. Install it and put it on your PATH.');
			return 2;
		}
		aerVersion = parseAerVersion(version.output);
		tree = tree || prepareSource(path.join(work, 'tree'));
	}
	const classesFolder = path.join(tree || REPOSITORY_ROOT, CLASSES_FOLDER);
	const classes = discoverTestClasses(classesFolder);
	const batches = buildBatches(classes, BATCH_LIMIT);
	const methodCount = batches.reduce((sum, batch) => sum + batch.methodCount, 0);
	if(methodCount === 0)
	{
		log(`No test classes found under ${classesFolder}`);
		return 2;
	}
	const licensed = await hasAerLicence(runAer, tree || REPOSITORY_ROOT);
	if(licensed)
	{
		log(`${plural(methodCount, 'test method')} in ${plural(classes.length, 'class')}, in one run: aer has a licence`);
	}
	else if(!unlicensedRunsMayBatch)
	{
		log(`${plural(methodCount, 'test method')} in ${plural(classes.length, 'class')}. ${LICENCE_NEEDED_MESSAGE}`);
		return options.dryRun ? 0 : 2;
	}
	else
	{
		log(`${plural(methodCount, 'test method')} in ${plural(classes.length, 'class')}, ${plural(batches.length, 'run')} of at most ${BATCH_LIMIT}: `
			+ 'aer has no licence, and its free tier runs at most 100 test methods at a time. '
			+ 'To run them in one run, register a licence with `aer license register <key>`; get one at https://portal.aertest.com/.');
	}
	if(options.dryRun)
	{
		if(licensed)
		{
			log(`run 1 (${methodCount} methods): every test in force-app`);
		}
		else
		{
			batches.forEach((batch, index) => log(`run ${index + 1} (${batch.methodCount} methods): ${batch.filters.join(' ')}`));
		}
		return 0;
	}
	const commit = readCommit();
	// A gate run checks the tests only; the release names the figure a record run publishes.
	const release = options.gate ? null : readRelease(tree || REPOSITORY_ROOT);
	if(!options.gate && !release)
	{
		log('No release found: no release tag points at the commit, and sfdx-project.json has no version line or released alias. The record leaves it empty.');
	}

	const started = now();
	const settings = {runAer, source: tree, work, permissionSet: options.permissionSet, log, warn};
	const rows = licensed ? await runWholeSuite(methodCount, settings) : await runBatches(batches, settings);
	const durationSeconds = (now() - started) / 1000;

	const baselineFile = options.gate || DEFAULT_BASELINE;
	const baseline = readBaseline(baselineFile);
	const record = buildRecord({
		aerVersion, commit, release, measuredAt: started.toISOString(), permissionSet: options.permissionSet, classes, rows, durationSeconds, baseline
	});
	const out = path.resolve(options.out || (options.gate ? path.join(work, 'aer-run.json') : DEFAULT_RECORD));
	fs.mkdirSync(path.dirname(out), {recursive: true});
	fs.writeFileSync(out, JSON.stringify(record, null, '\t') + '\n');
	log(`aer ${aerVersion} on ${commit.slice(0, 9)}: ${record.passed} of ${record.total} passed. Written to ${out}`);
	return options.gate ? reportGate(record, baseline, {log, warn}) : 0;
}

/**
 * @description Starts aer and waits for it to end. It never rejects: a command that cannot start gives `error`.
 *
 * @param {string[]} args
 * @param {{cwd: string}} options
 * @return {Promise<{code: ?number, output: string, error?: Error}>}
 */
function runAerProcess(args, {cwd})
{
	return new Promise(resolve =>
	{
		const child = spawn('aer', args, {cwd});
		let output = '';
		child.stdout.on('data', chunk => output += chunk);
		child.stderr.on('data', chunk => output += chunk);
		child.on('error', error => resolve({code: null, output, error}));
		child.on('close', code => resolve({code, output}));
	});
}

/**
 * @description Names the release of the current commit from its tags and the copy's project file.
 *
 * @param {string} tree the folder that holds sfdx-project.json
 * @return {?string}
 */
function readReleaseOfCommit(tree)
{
	const tags = execFileSync('git', ['tag', '--points-at', 'HEAD'], {cwd: REPOSITORY_ROOT, encoding: 'utf8'}).split('\n').map(tag => tag.trim());
	const project = JSON.parse(fs.readFileSync(path.join(tree, 'sfdx-project.json'), 'utf8'));
	return describeRelease(tags, project);
}

/**
 * @description Patterns aer reads differently from Salesforce, rewritten in aer's copy of the source only. Each rewrite keeps
 * the pattern's meaning for Java and Salesforce, so the tests check the same behaviour; the shipped source is never changed.
 * Remove a row when aer fixes the issue it names.
 */
const AER_SOURCE_WORKAROUNDS = [
	{
		file: 'force-app/main/default/classes/UTIL_String.cls',
		issue: 'https://github.com/octoberswimmer/aer-dist/issues/606',
		// aer reads an escaped backslash followed by Q or E as the \Q...\E quoting operator; [Q] and [E] are the same letters.
		from: String.raw`'\\\\Q[\\s\\S]*?(?:\\\\E|$)`,
		to: String.raw`'\\\\[Q][\\s\\S]*?(?:\\\\[E]|$)`
	}
];

/**
 * @description Applies AER_SOURCE_WORKAROUNDS to a copy of the source. A row whose text is not found exactly once is
 * reported and skipped, so a later change to the pattern shows up here instead of as a silent difference.
 *
 * @param {string} folder - the copy of the source
 * @param {Array<{file: string, issue: string, from: string, to: string}>} [workarounds]
 * @return {{applied: Array<string>, missed: Array<string>}} the files changed, and the rows not applied
 */
function applyAerWorkarounds(folder, workarounds = AER_SOURCE_WORKAROUNDS)
{
	const applied = [];
	const missed = [];
	for(const workaround of workarounds)
	{
		const file = path.join(folder, workaround.file);
		const text = fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '';
		if(text.split(workaround.from).length !== 2)
		{
			missed.push(`${workaround.file} (${workaround.issue})`);
			continue;
		}
		fs.writeFileSync(file, text.split(workaround.from).join(workaround.to));
		applied.push(workaround.file);
	}
	return {applied, missed};
}

/**
 * @description Writes a clean copy of the current commit's force-app folder and project file into a folder, with the aer
 * workarounds applied to the copy.
 *
 * @param {string} folder
 * @return {string} the folder
 */
function prepareCommitTree(folder)
{
	fs.mkdirSync(folder, {recursive: true});
	const archive = path.join(path.dirname(folder), 'tree.tar');
	execFileSync('git', ['archive', '--output', archive, 'HEAD', 'force-app', 'sfdx-project.json'], {cwd: REPOSITORY_ROOT});
	execFileSync('tar', ['-xf', archive, '-C', folder]);
	const {applied, missed} = applyAerWorkarounds(folder);
	applied.forEach(file => console.log(`aer workaround applied to the copy of ${file}`));
	missed.forEach(row => console.warn(`WARNING aer workaround not applied, its text was not found: ${row}`));
	return folder;
}

module.exports = {
	AER_SOURCE_WORKAROUNDS,
	applyAerWorkarounds,
	BATCH_LIMIT,
	UNLICENSED_RUNS_MAY_BATCH,
	LICENCE_NEEDED_MESSAGE,
	discoverTestClasses,
	buildBatches,
	parseResultRows,
	parseAerVersion,
	buildRecord,
	compareWithBaseline,
	readBaseline,
	describeRelease,
	parseArguments,
	run
};

if(require.main === module)
{
	run(process.argv.slice(2), {
		runAer: runAerProcess,
		readCommit: () => execFileSync('git', ['rev-parse', 'HEAD'], {cwd: REPOSITORY_ROOT, encoding: 'utf8'}).trim(),
		readRelease: readReleaseOfCommit,
		prepareSource: prepareCommitTree,
		now: () => new Date(),
		log: message => console.log(message),
		warn: message => console.warn(`WARNING ${message}`)
	}).then(code =>
	{
		process.exitCode = code;
	});
}
