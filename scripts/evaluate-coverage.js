#!/usr/bin/env node
// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Per-file coverage harness for Apex + LWC. Measures the coverage
 * of a named subset of files, compares it to `scripts/coverage-baseline.json`,
 * and exits non-zero on any per-file regression or floor breach.
 *
 * @see coverage-lib.js
 *
 * @example
 * ```bash
 * # Targeted check — after editing UTIL_FrameworkMasker + its test:
 * npm run coverage:gate -- --apex UTIL_FrameworkMasker
 *
 * # Targeted LWC check:
 * npm run coverage:gate -- --lwc healthCheck,scheduledJobBuilder
 *
 * # Full baseline capture (runs RunLocalTests + full jest; slow):
 * npm run coverage:gate -- --fix-baseline
 * ```
 *
 * @author Kern Framework
 * @version 1.0.0
 */

const fs = require('fs');
const path = require('path');
const {spawnSync} = require('child_process');

const lib = require('./coverage-lib');
const {getDevOrgAlias} = require('./dev-org-config');

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

/** @description Default sf org alias. */
const DEFAULT_ORG = getDevOrgAlias();

/** @description Repo-relative path to the committed baseline JSON. */
const BASELINE_RELATIVE_PATH = 'scripts/coverage-baseline.json';

/** @description Repo-relative path to the Apex classes directory. */
const CLASSES_RELATIVE_PATH = 'force-app/main/default/classes';

/** @description Repo-relative path to Jest's raw istanbul coverage output. */
const JEST_COVERAGE_SUMMARY_PATH = 'coverage/coverage-final.json';

/** @description Exit codes emitted by the harness. */
const EXIT = Object.freeze({
	OK: 0,
	GATE_FAIL: 1,
	USAGE: 2,
	RUNTIME: 3
});

// ─────────────────────────────────────────────────────────────────────────────
// CLI entry point
// ─────────────────────────────────────────────────────────────────────────────

/**
 * @description Orchestrator. Parses argv, dispatches to the right mode, and
 * returns the exit code the process should use. Kept small so the heavy
 * lifting stays in per-mode functions that can be unit-tested with the
 * runner injected.
 *
 * @param {Array<string>} argv - `process.argv.slice(2)`.
 * @param {Object} [deps] - Injected dependencies (runner, logger, cwd).
 * @return {number} Exit code.
 */
function main(argv, deps)
{
	const dependencies = buildDependencies(deps);
	const options = parseArgs(argv);

	if(options.help)
	{
		printHelp(dependencies.logger);
		return EXIT.OK;
	}
	if(options.errors.length > 0)
	{
		options.errors.forEach(message => dependencies.logger.error(message));
		printHelp(dependencies.logger);
		return EXIT.USAGE;
	}

	try
	{
		if(options.fixBaseline)
		{
			return runFixBaseline(options, dependencies);
		}
		if(options.full)
		{
			return runFull(options, dependencies);
		}
		return runTargeted(options, dependencies);
	}
	catch(error)
	{
		dependencies.logger.error(`[${error.code || 'ERROR'}] ${error.message}`);
		return EXIT.RUNTIME;
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Argv parsing
// ─────────────────────────────────────────────────────────────────────────────

/**
 * @description Parses argv into a typed options object.
 *
 * @param {Array<string>} argv
 * @return {{apex: Array<string>, lwc: Array<string>, full: boolean, fixBaseline: boolean, skipDeploy: boolean, org: string, help: boolean, errors: Array<string>}}
 */
function parseArgs(argv)
{
	const options = {
		apex: [],
		lwc: [],
		full: false,
		fixBaseline: false,
		skipDeploy: false,
		runTests: false,
		org: DEFAULT_ORG,
		waitMinutes: null,
		format: 'text',
		help: false,
		errors: []
	};

	let index = 0;
	while(index < argv.length)
	{
		const token = argv[index];
		switch(token)
		{
			case '--apex':
				options.apex = splitList(argv[index + 1]);
				index += 2;
				break;
			case '--lwc':
				options.lwc = splitList(argv[index + 1]);
				index += 2;
				break;
			case '--full':
				options.full = true;
				index += 1;
				break;
			case '--fix-baseline':
				options.fixBaseline = true;
				index += 1;
				break;
			case '--skip-deploy':
				options.skipDeploy = true;
				index += 1;
				break;
			case '--run-tests':
				options.runTests = true;
				index += 1;
				break;
			case '--org':
				if(!argv[index + 1])
				{
					options.errors.push('--org requires a value');
					index += 1;
				}
				else
				{
					options.org = argv[index + 1];
					index += 2;
				}
				break;
			case '--wait':
				if(!argv[index + 1])
				{
					options.errors.push('--wait requires a value (minutes)');
					index += 1;
				}
				else
				{
					const minutes = Number(argv[index + 1]);
					if(!Number.isFinite(minutes) || minutes <= 0)
					{
						options.errors.push(`--wait value must be a positive number, got "${argv[index + 1]}"`);
						index += 2;
					}
					else
					{
						options.waitMinutes = minutes;
						index += 2;
					}
				}
				break;
			case '--format':
				if(!argv[index + 1])
				{
					options.errors.push('--format requires a value (one of: ' + lib.SUPPORTED_FORMATS.join(', ') + ')');
					index += 1;
				}
				else if(!lib.SUPPORTED_FORMATS.includes(argv[index + 1]))
				{
					options.errors.push(`--format value must be one of ${lib.SUPPORTED_FORMATS.join(', ')}, got "${argv[index + 1]}"`);
					index += 2;
				}
				else
				{
					options.format = argv[index + 1];
					index += 2;
				}
				break;
			case '--help':
			case '-h':
				options.help = true;
				index += 1;
				break;
			default:
				options.errors.push(`unknown argument: ${token}`);
				index += 1;
				break;
		}
	}

	const modes = [options.full, options.fixBaseline, options.apex.length > 0 || options.lwc.length > 0].filter(Boolean).length;
	if(!options.help && modes === 0)
	{
		options.errors.push('specify at least one of --apex, --lwc, --full, or --fix-baseline');
	}
	if(options.full && options.fixBaseline)
	{
		options.errors.push('--full and --fix-baseline are mutually exclusive');
	}
	return options;
}

/**
 * @description Splits a `--apex "Foo,Bar,Baz"` value into `['Foo', 'Bar',
 * 'Baz']`. Tolerates whitespace; empty entries are dropped.
 *
 * @param {string} raw
 * @return {Array<string>}
 */
function splitList(raw)
{
	if(!raw)
	{
		return [];
	}
	return raw.split(',').map(item => item.trim()).filter(Boolean);
}

// ─────────────────────────────────────────────────────────────────────────────
// Dependency injection
// ─────────────────────────────────────────────────────────────────────────────

/**
 * @description Builds the dependency bundle used by the orchestrator and mode
 * functions. Callers (unit tests) may inject any subset; defaults hit real
 * child_process, fs, and stdout.
 *
 * @param {Object} [overrides] - Partial override map.
 * @return {{logger: Object, runner: Function, cwd: string, readFile: Function, fileExists: Function, readdir: Function, writeFile: Function, now: Function}}
 */
function buildDependencies(overrides)
{
	const defaults = {
		logger: {
			info: (message) => process.stdout.write(`${message}\n`),
			error: (message) => process.stderr.write(`${message}\n`)
		},
		runner: defaultRunner,
		cwd: process.cwd(),
		readFile: (filePath) => fs.readFileSync(filePath, 'utf8'),
		fileExists: (filePath) => fs.existsSync(filePath),
		readdir: (dir) => fs.readdirSync(dir),
		writeFile: (filePath, contents) => fs.writeFileSync(filePath, contents, 'utf8'),
		now: () => Date.now()
	};
	return {...defaults, ...(overrides || {})};
}

/**
 * @description Synchronous child-process runner used by the default deps.
 * Returns `{status, stdout, stderr}` and never throws on a non-zero exit; the
 * orchestrator decides whether that's fatal (deploy failure) or expected
 * (apex tests that failed).
 *
 * @param {string} command
 * @param {Array<string>} args
 * @param {Object} [options]
 * @return {{status: number, stdout: string, stderr: string}}
 */
function defaultRunner(command, args, options)
{
	const env = buildSubprocessEnv(command, process.env);
	const result = spawnSync(command, args, {
		encoding: 'utf8',
		stdio: options && options.inherit ? 'inherit' : 'pipe',
		maxBuffer: 128 * 1024 * 1024,
		env
	});
	return {
		status: typeof result.status === 'number' ? result.status : EXIT.RUNTIME,
		stdout: result.stdout || '',
		stderr: result.stderr || ''
	};
}

/**
 * @description Builds the environment for a spawned subprocess. For `sf`
 * commands, bumps `NODE_OPTIONS --max-old-space-size` to 8 GB because sf's
 * RunLocalTests JSON serialiser OOMs on large packages at Node's 4 GB
 * default. Existing `--max-old-space-size` overrides are preserved.
 *
 * @param {string} command - The command being spawned.
 * @param {Object} parentEnv - The parent process.env.
 * @return {Object} A new env map for the subprocess.
 */
function buildSubprocessEnv(command, parentEnv)
{
	const env = {...parentEnv};
	if(command === 'sf')
	{
		const existing = (env.NODE_OPTIONS || '').trim();
		if(!/--max-old-space-size/.test(existing))
		{
			env.NODE_OPTIONS = existing.length > 0 ? `${existing} --max-old-space-size=8192` : '--max-old-space-size=8192';
		}
	}
	return env;
}

// ─────────────────────────────────────────────────────────────────────────────
// Mode: targeted (--apex and/or --lwc)
// ─────────────────────────────────────────────────────────────────────────────

/**
 * @description Runs the targeted coverage check: measures only the classes
 * and/or components the caller named, compares to baseline, emits summary.
 *
 * @param {Object} options
 * @param {Object} deps
 * @return {number} Exit code.
 */
function runTargeted(options, deps)
{
	const baselinePath = path.join(deps.cwd, BASELINE_RELATIVE_PATH);
	const baseline = readBaselineFromDeps(baselinePath, deps);

	let apexResult = null;
	if(options.apex.length > 0)
	{
		apexResult = measureApex(options.apex, options, deps);
	}

	let lwcResult = null;
	if(options.lwc.length > 0)
	{
		lwcResult = measureLwc(options.lwc, deps);
	}

	const evaluation = lib.evaluateThresholds({
		apexResult: apexResult ? apexResult.coverage : null,
		lwcResult,
		baseline,
		apexTargets: options.apex,
		lwcTargets: options.lwc
	});

	emitEvaluation(evaluation, options, deps);
	if(!evaluation.pass)
	{
		return EXIT.GATE_FAIL;
	}
	if(apexResult && !apexResult.coverage.testsPassed)
	{
		deps.logger.error(`apex test failures: ${apexResult.coverage.testFailures.length}`);
		return EXIT.GATE_FAIL;
	}
	return EXIT.OK;
}

// ─────────────────────────────────────────────────────────────────────────────
// Mode: --full (Phase 3 regression gate)
// ─────────────────────────────────────────────────────────────────────────────

/**
 * @description Walks every class and every LWC file in the baseline and fails
 * on any regression. Intended for pre-release or CI runs, not per-commit.
 *
 * @param {Object} options
 * @param {Object} deps
 * @return {number} Exit code.
 */
function runFull(options, deps)
{
	const baselinePath = path.join(deps.cwd, BASELINE_RELATIVE_PATH);
	if(!deps.fileExists(baselinePath))
	{
		deps.logger.error(`baseline not found at ${baselinePath} — run with --fix-baseline first`);
		return EXIT.RUNTIME;
	}
	const baseline = readBaselineFromDeps(baselinePath, deps);
	const apexResult = runFullApex(options, deps);
	const lwcResult = runFullLwc(deps);

	const evaluation = lib.evaluateThresholds({
		apexResult: apexResult.coverage,
		lwcResult,
		baseline,
		apexTargets: Object.keys(baseline.apex && baseline.apex.classes || {}),
		lwcTargets: listBaselineComponents(baseline)
	});

	emitEvaluation(evaluation, options, deps);
	if(!evaluation.pass)
	{
		return EXIT.GATE_FAIL;
	}
	if(!apexResult.coverage.testsPassed)
	{
		deps.logger.error(`apex test failures: ${apexResult.coverage.testFailures.length}`);
		return EXIT.GATE_FAIL;
	}
	return EXIT.OK;
}

// ─────────────────────────────────────────────────────────────────────────────
// Output dispatch
// ─────────────────────────────────────────────────────────────────────────────

/**
 * @description Dispatches the evaluation result to the emitter selected via
 * `--format`. `text` is the default human output: a summary line on stdout and
 * a multi-line violations report on stderr. `pmd-xml` writes a single
 * PMD 7 XML document to stdout (suitable for piping into Gearset/Copado).
 * `github-annotations` writes one `::error`/`::warning` per violation to
 * stdout for GitHub Actions to pick up.
 *
 * @param {{pass: boolean, violations: Array<Object>, measurements: Array<Object>}} evaluation
 * @param {{format?: string}} options
 * @param {{logger: {info: Function, error: Function}}} deps
 * @return {void}
 */
function emitEvaluation(evaluation, options, deps)
{
	const format = (options && options.format) || 'text';
	if(format === 'pmd-xml')
	{
		deps.logger.info(lib.formatPmdXml(evaluation.violations));
		return;
	}
	if(format === 'github-annotations')
	{
		const payload = lib.formatGithubAnnotations(evaluation.violations);
		if(payload.length > 0)
		{
			deps.logger.info(payload.replace(/\n$/, ''));
		}
		else
		{
			deps.logger.info(lib.formatSummaryLine(evaluation.measurements, evaluation.pass));
		}
		return;
	}
	deps.logger.info(lib.formatSummaryLine(evaluation.measurements, evaluation.pass));
	if(!evaluation.pass)
	{
		deps.logger.error(lib.formatViolationsReport(evaluation.violations));
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Mode: --fix-baseline
// ─────────────────────────────────────────────────────────────────────────────

/**
 * @description Captures a fresh baseline from a full RunLocalTests + full
 * jest run and writes it to `scripts/coverage-baseline.json`. The code must
 * already be deployed; no deploy step is performed.
 *
 * @param {Object} options
 * @param {Object} deps
 * @return {number} Exit code.
 */
function runFixBaseline(options, deps)
{
	const apexResult = runFullApex(options, deps);
	const lwcResult = runFullLwc(deps);
	const testSetupClasses = findTestSetupClasses(deps);

	const baseline = lib.buildBaseline({
		apexResult: apexResult.coverage,
		lwcResult,
		testSetupClasses,
		lwcRuntimeSeconds: lwcResult.totalRuntimeSeconds || 0
	});
	const baselinePath = path.join(deps.cwd, BASELINE_RELATIVE_PATH);
	deps.writeFile(baselinePath, `${JSON.stringify(baseline, null, 2)}\n`);

	const apexClassCount = Object.keys(baseline.apex.classes).length;
	const lwcFileCount = Object.keys(baseline.lwc.files).length;
	deps.logger.info(`baseline written to ${BASELINE_RELATIVE_PATH}`);
	deps.logger.info(`apex classes: ${apexClassCount} | lwc files: ${lwcFileCount} | @TestSetup classes: ${testSetupClasses.length}`);

	if(!apexResult.coverage.testsPassed)
	{
		deps.logger.error(`apex test failures: ${apexResult.coverage.testFailures.length} — baseline captured but CI gate would fail until tests are green`);
		return EXIT.GATE_FAIL;
	}
	return EXIT.OK;
}

// ─────────────────────────────────────────────────────────────────────────────
// Baseline I/O (uses injected deps so unit tests never hit real fs)
// ─────────────────────────────────────────────────────────────────────────────

/**
 * @description Reads the committed baseline via injected deps, returning the
 * empty baseline shape when the file does not yet exist.
 *
 * @param {string} baselinePath
 * @param {Object} deps
 * @return {Object}
 */
function readBaselineFromDeps(baselinePath, deps)
{
	if(!deps.fileExists(baselinePath))
	{
		return {
			capturedAt: null,
			apex: {totalWallClockSeconds: 0, testSetupClasses: [], classes: {}},
			lwc: {totalRuntimeSeconds: 0, files: {}}
		};
	}
	return JSON.parse(deps.readFile(baselinePath));
}

// ─────────────────────────────────────────────────────────────────────────────
// Apex measurement
// ─────────────────────────────────────────────────────────────────────────────

/**
 * @description Deploys (unless `--skip-deploy`), runs the matching `_TEST`
 * classes, parses coverage, applies exemptions, returns the adjusted result.
 *
 * @param {Array<string>} classes
 * @param {Object} options
 * @param {Object} deps
 * @return {{coverage: Object}}
 */
function measureApex(classes, options, deps)
{
	if(!options.skipDeploy)
	{
		deployApexClasses(classes, options, deps);
	}
	const testClasses = classes.map(name => `${name}_TEST`);
	const raw = executeApexTests(testClasses, options, deps);
	const parsed = lib.parseApexCoverage(raw);
	const exemptCounts = gatherExemptLineCounts(classes, deps);
	const adjusted = lib.applyApexExemptions(parsed, exemptCounts);
	return {coverage: adjusted};
}

/**
 * @description For `--full` and `--fix-baseline`: queries current org coverage
 * via Tooling API. Assumes the code is deployed and the user has recently run
 * tests. This is dramatically faster than `sf apex run test --result-format
 * json` which OOMs Node on large packages during JSON serialisation.
 *
 * @param {Object} options
 * @param {Object} deps
 * @return {{coverage: Object}}
 */
function runFullApex(options, deps)
{
	if(options.runTests)
	{
		executeFullRunLocalTests(options, deps);
	}
	deps.logger.info(`querying ApexCodeCoverageAggregate from ${options.org}…`);
	const coverageRows = queryToolingApi(
		'SELECT ApexClassOrTrigger.Name, NumLinesCovered, NumLinesUncovered FROM ApexCodeCoverageAggregate',
		options,
		deps
	);
	const parsed = normaliseAggregateRows(coverageRows);
	const allClasses = listAllApexSourceClasses(deps);
	const exemptCounts = gatherExemptLineCounts(allClasses, deps);
	const adjusted = lib.applyApexExemptions(parsed, exemptCounts);
	const testStatus = queryLatestTestRunStatus(options, deps);
	adjusted.testsPassed = testStatus.testsPassed;
	adjusted.testFailures = testStatus.testFailures;
	adjusted.wallClockSeconds = testStatus.wallClockSeconds;
	return {coverage: adjusted};
}

/**
 * @description Kicks off a full RunLocalTests run and blocks until it finishes.
 * Used only when `--run-tests` is explicitly requested; `--fix-baseline` and
 * `--full` default to reading the most recent org state.
 *
 * @param {Object} options
 * @param {Object} deps
 * @return {void}
 */
function executeFullRunLocalTests(options, deps)
{
	const outputDir = apexOutputDir(deps);
	const waitMinutes = options.waitMinutes || 60;
	const args = ['apex', 'run', 'test', '-o', options.org, '--test-level', 'RunLocalTests', '--code-coverage', '--wait', String(waitMinutes), '--output-dir', outputDir];
	deps.logger.info(`running RunLocalTests against ${options.org} (wait up to ${waitMinutes}m)…`);
	deps.runner('sf', args, {inherit: true});
}

/**
 * @description Runs `sf data query --use-tooling-api` and returns the record
 * array. JSON is parsed via `lib.safeParseJson` so non-JSON output fails
 * loudly.
 *
 * @param {string} soql
 * @param {Object} options
 * @param {Object} deps
 * @return {Array<Object>}
 */
function queryToolingApi(soql, options, deps)
{
	const result = deps.runner('sf', ['data', 'query', '-o', options.org, '--use-tooling-api', '-q', soql, '--json'], {inherit: false});
	if(result.status !== 0)
	{
		const error = new Error(`tooling query failed (exit ${result.status}): ${(result.stderr || result.stdout || '').slice(0, 300)}`);
		error.code = 'TOOLING_QUERY_FAILED';
		throw error;
	}
	const parsed = lib.safeParseJson(result.stdout, `sf data query (${soql.slice(0, 60)}…)`);
	return (parsed && parsed.result && parsed.result.records) || [];
}

/**
 * @description Converts `ApexCodeCoverageAggregate` rows to the same shape
 * that `lib.parseApexCoverage` emits.
 *
 * @param {Array<Object>} rows
 * @return {{classes: Object<string, Object>}}
 */
function normaliseAggregateRows(rows)
{
	const classes = {};
	for(const row of rows)
	{
		const nameHolder = row && row.ApexClassOrTrigger;
		const name = nameHolder && nameHolder.Name;
		if(!name)
		{
			continue;
		}
		const covered = Number(row.NumLinesCovered) || 0;
		const uncovered = Number(row.NumLinesUncovered) || 0;
		const total = covered + uncovered;
		const percentage = total === 0 ? 100 : Number(((covered / total) * 100).toFixed(1));
		classes[name] = {percentage, coveredLines: covered, uncoveredLines: uncovered};
	}
	return {classes};
}

/**
 * @description Queries the latest `ApexTestRunResult` row to determine whether
 * the most recent test run passed and how long it took.
 *
 * @param {Object} options
 * @param {Object} deps
 * @return {{testsPassed: boolean, testFailures: Array<Object>, wallClockSeconds: number}}
 */
function queryLatestTestRunStatus(options, deps)
{
	const rows = queryToolingApi(
		'SELECT Status, MethodsEnqueued, MethodsCompleted, MethodsFailed, TestTime FROM ApexTestRunResult ORDER BY StartTime DESC LIMIT 1',
		options,
		deps
	);
	const latest = rows[0];
	if(!latest)
	{
		return {testsPassed: true, testFailures: [], wallClockSeconds: 0};
	}
	const failed = Number(latest.MethodsFailed) || 0;
	const testTimeMs = Number(latest.TestTime) || 0;
	const failures = failed > 0 ? new Array(failed).fill({Outcome: 'Fail'}) : [];
	return {
		testsPassed: failed === 0,
		testFailures: failures,
		wallClockSeconds: testTimeMs / 1000
	};
}

/**
 * @description Shells out to `sf project deploy start` for the given classes
 * and their `_TEST` companions.
 *
 * @param {Array<string>} classes
 * @param {Object} options
 * @param {Object} deps
 * @return {void}
 */
function deployApexClasses(classes, options, deps)
{
	const metadata = classes.flatMap(name => [`ApexClass:${name}`, `ApexClass:${name}_TEST`]);
	deps.logger.info(`deploying: ${metadata.join(', ')}`);
	const args = ['project', 'deploy', 'start', '-o', options.org];
	for(const entry of metadata)
	{
		args.push('-m', entry);
	}
	args.push('--ignore-conflicts');
	const result = deps.runner('sf', args, {inherit: true});
	if(result.status !== 0)
	{
		const error = new Error(`deploy failed (exit ${result.status})`);
		error.code = 'DEPLOY_FAILED';
		throw error;
	}
}

/**
 * @description Shells out to `sf apex run test` for the targeted test
 * classes. Uses `--output-dir` so we never parse stdout; `--synchronous`
 * is omitted for safety when `testClasses.length > 1`.
 *
 * @param {Array<string>} testClasses
 * @param {Object} options
 * @param {Object} deps
 * @return {Object} Parsed test-result.json.
 */
function executeApexTests(testClasses, options, deps)
{
	const outputDir = apexOutputDir(deps);
	const waitMinutes = options.waitMinutes || 15;
	const args = ['apex', 'run', 'test', '-o', options.org, '--code-coverage', '--result-format', 'json', '--wait', String(waitMinutes), '--output-dir', outputDir];
	for(const name of testClasses)
	{
		args.push('-t', name);
	}
	deps.logger.info(`running apex tests: ${testClasses.join(', ')}`);
	deps.runner('sf', args, {inherit: true});
	return readApexResultFile(outputDir, deps);
}

/**
 * @description Reads `<outputDir>/test-result.json` and parses it with the
 * first-byte JSON safety check.
 *
 * @param {string} outputDir
 * @param {Object} deps
 * @return {Object}
 */
function readApexResultFile(outputDir, deps)
{
	const filePath = resolveApexResultFile(outputDir, deps);
	const raw = deps.readFile(filePath);
	return lib.safeParseJson(raw, `sf apex run test output (${filePath})`);
}

/**
 * @description Finds the apex result JSON in the output dir. sf CLI 2.130.9
 * writes `test-result-<runId>.json`; older versions wrote `test-result.json`.
 * Accept either. Exclude `-codecoverage.json` / `-junit.xml` / any other
 * decorated file.
 *
 * @param {string} outputDir
 * @param {Object} deps
 * @return {string}
 */
function resolveApexResultFile(outputDir, deps)
{
	const direct = path.join(outputDir, 'test-result.json');
	if(deps.fileExists(direct))
	{
		return direct;
	}
	if(deps.fileExists(outputDir))
	{
		const entries = deps.readdir(outputDir);
		const match = entries.find(name =>
			name.startsWith('test-result-') &&
			name.endsWith('.json') &&
			!name.endsWith('-codecoverage.json') &&
			!name.endsWith('-junit.json') &&
			!name.endsWith('-tap.json')
		);
		if(match)
		{
			return path.join(outputDir, match);
		}
	}
	const error = new Error(`no test-result*.json file in ${outputDir} after sf apex run test`);
	error.code = 'APEX_RESULT_MISSING';
	throw error;
}

/**
 * @description Composes a per-run tmp directory path for apex output. Keeping
 * this in a helper makes it trivial to stub in tests.
 *
 * @param {Object} deps
 * @return {string}
 */
function apexOutputDir(deps)
{
	return `/tmp/kern-apex-${deps.now()}`;
}

// ─────────────────────────────────────────────────────────────────────────────
// LWC measurement
// ─────────────────────────────────────────────────────────────────────────────

/**
 * @description Runs jest against the named component folders with
 * coverage-summary output, then parses the resulting summary file.
 *
 * @param {Array<string>} components
 * @param {Object} deps
 * @return {Object}
 */
function measureLwc(components, deps)
{
	const pattern = `(${components.map(escapeRegex).join('|')})`;
	const collectArgs = components.map(name => `--collectCoverageFrom=force-app/main/default/lwc/${name}/**/*.js`);
	const args = ['run', 'test:unit:coverage', '--', '--coverageReporters=json', `--testPathPattern=${pattern}`, ...collectArgs];
	deps.logger.info(`running jest for components: ${components.join(', ')}`);
	deps.runner('npm', args, {inherit: true});
	return loadJestSummary(deps);
}

/**
 * @description Runs the full jest suite with coverage-summary output for
 * `--full` / `--fix-baseline`.
 *
 * @param {Object} deps
 * @return {Object}
 */
function runFullLwc(deps)
{
	const args = ['run', 'test:unit:coverage', '--', '--coverageReporters=json'];
	deps.logger.info('running full jest suite with coverage…');
	deps.runner('npm', args, {inherit: true});
	return loadJestSummary(deps);
}

/**
 * @description Reads and parses jest's coverage-summary.json, rebasing file
 * keys to repo-relative POSIX paths.
 *
 * @param {Object} deps
 * @return {Object}
 */
function loadJestSummary(deps)
{
	const summaryPath = path.join(deps.cwd, JEST_COVERAGE_SUMMARY_PATH);
	if(!deps.fileExists(summaryPath))
	{
		const error = new Error(`jest coverage output not found at ${summaryPath} — ensure --coverageReporters=json is passed`);
		error.code = 'JEST_SUMMARY_MISSING';
		throw error;
	}
	const raw = deps.readFile(summaryPath);
	const parsed = JSON.parse(raw);
	return lib.parseJestCoverageFinal(parsed, deps.cwd);
}

// ─────────────────────────────────────────────────────────────────────────────
// Exemption scanning
// ─────────────────────────────────────────────────────────────────────────────

/**
 * @description Walks the named apex classes, reads each `.cls` file, counts
 * valid `// kern-coverage-exempt:` comments, and fails hard on invalid
 * comments (short reason, blocklist hit, empty reason).
 *
 * @param {Array<string>} classes
 * @param {Object} deps
 * @return {Object<string, number>}
 */
function gatherExemptLineCounts(classes, deps)
{
	const counts = {};
	const failures = [];
	for(const className of classes)
	{
		const filePath = path.join(deps.cwd, CLASSES_RELATIVE_PATH, `${className}.cls`);
		if(!deps.fileExists(filePath))
		{
			continue;
		}
		const source = deps.readFile(filePath);
		const comments = lib.parseCoverageExemptComments(source);
		let valid = 0;
		for(const comment of comments)
		{
			if(comment.reasonValid)
			{
				valid += 1;
			}
			else
			{
				failures.push(`${className}.cls:${comment.lineNumber} kern-coverage-exempt failed policy (${comment.failures.join(', ')}): "${comment.reason}"`);
			}
		}
		counts[className] = valid;
	}
	if(failures.length > 0)
	{
		const error = new Error(`invalid kern-coverage-exempt comments:\n${failures.join('\n')}`);
		error.code = 'EXEMPT_POLICY_VIOLATION';
		throw error;
	}
	return counts;
}

// ─────────────────────────────────────────────────────────────────────────────
// Source enumeration
// ─────────────────────────────────────────────────────────────────────────────

/**
 * @description Returns every non-`_TEST` apex class name under
 * `force-app/main/default/classes`.
 *
 * @param {Object} deps
 * @return {Array<string>}
 */
function listAllApexSourceClasses(deps)
{
	const dir = path.join(deps.cwd, CLASSES_RELATIVE_PATH);
	if(!deps.fileExists(dir))
	{
		return [];
	}
	return deps.readdir(dir)
		.filter(name => name.endsWith('.cls'))
		.filter(name => !name.endsWith('_TEST.cls'))
		.map(name => name.replace(/\.cls$/, ''))
		.sort();
}

/**
 * @description Scans `_TEST.cls` files for `@TestSetup` annotations. Used to
 * surface the optimisation queue in the baseline.
 *
 * @param {Object} deps
 * @return {Array<string>}
 */
function findTestSetupClasses(deps)
{
	const dir = path.join(deps.cwd, CLASSES_RELATIVE_PATH);
	if(!deps.fileExists(dir))
	{
		return [];
	}
	const names = [];
	for(const entry of deps.readdir(dir))
	{
		if(!entry.endsWith('_TEST.cls'))
		{
			continue;
		}
		const source = deps.readFile(path.join(dir, entry));
		if(/@TestSetup/i.test(source))
		{
			names.push(entry.replace(/\.cls$/, ''));
		}
	}
	return names.sort();
}

/**
 * @description Derives the list of LWC component folder names that appear in
 * the baseline, so `--full` knows which components to target.
 *
 * @param {Object} baseline
 * @return {Array<string>}
 */
function listBaselineComponents(baseline)
{
	const files = (baseline && baseline.lwc && baseline.lwc.files) || {};
	const components = new Set();
	for(const filePath of Object.keys(files))
	{
		const match = filePath.match(/\/lwc\/([^/]+)\//);
		if(match)
		{
			components.add(match[1]);
		}
	}
	return [...components].sort();
}

/**
 * @description Escapes a string for safe use inside a regex character class.
 *
 * @param {string} value
 * @return {string}
 */
function escapeRegex(value)
{
	return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

// ─────────────────────────────────────────────────────────────────────────────
// Help text
// ─────────────────────────────────────────────────────────────────────────────

/**
 * @description Prints the harness help banner.
 *
 * @param {Object} logger
 * @return {void}
 */
function printHelp(logger)
{
	const lines = [
		'kern coverage harness — per-file coverage gate',
		'',
		'USAGE:',
		'  npm run coverage:gate -- [--apex ClassA,ClassB] [--lwc compA,compB] [flags]',
		'',
		'MODES:',
		'  --apex <list>     Measure named apex classes (deploys + runs *_TEST).',
		'  --lwc <list>      Measure named lwc component folders.',
		'  --full            Walk baseline; fail on any regression.',
		'  --fix-baseline    Rebuild scripts/coverage-baseline.json from a full run.',
		'',
		'FLAGS:',
		'  --skip-deploy     Do not deploy before apex test (assume deployed).',
		'  --run-tests       Kick off RunLocalTests before querying org coverage (slow).',
		`  --org <alias>     Target org (default: ${DEFAULT_ORG}).`,
		'  --wait <minutes>  Max time to wait for apex tests to finish (default: 60 for --full/--fix-baseline, 15 for --apex).',
		`  --format <fmt>    Output format — one of: ${lib.SUPPORTED_FORMATS.join(', ')} (default: text).`,
		'                    text              → human summary + multi-line violations report',
		'                    pmd-xml           → PMD 7 XML (Gearset, Copado, AutoRABIT, CodeScan)',
		'                    github-annotations → ::error/::warning lines for GitHub Actions',
		'  --help            Show this help.'
	];
	for(const line of lines)
	{
		logger.info(line);
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Exports & CLI bootstrap
// ─────────────────────────────────────────────────────────────────────────────

module.exports = {
	main,
	parseArgs,
	splitList,
	buildDependencies,
	runTargeted,
	runFull,
	runFixBaseline,
	emitEvaluation,
	measureApex,
	measureLwc,
	runFullApex,
	runFullLwc,
	deployApexClasses,
	executeApexTests,
	readApexResultFile,
	resolveApexResultFile,
	queryToolingApi,
	queryLatestTestRunStatus,
	normaliseAggregateRows,
	executeFullRunLocalTests,
	loadJestSummary,
	gatherExemptLineCounts,
	listAllApexSourceClasses,
	findTestSetupClasses,
	listBaselineComponents,
	readBaselineFromDeps,
	buildSubprocessEnv,
	escapeRegex,
	printHelp,
	DEFAULT_ORG,
	BASELINE_RELATIVE_PATH,
	CLASSES_RELATIVE_PATH,
	JEST_COVERAGE_SUMMARY_PATH,
	EXIT
};

/* istanbul ignore next -- CLI bootstrap; covered by real invocation, not unit tests */
if(require.main === module)
{
	const code = main(process.argv.slice(2));
	process.exit(code);
}
