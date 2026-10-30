#!/usr/bin/env node
// SPDX-License-Identifier: Apache-2.0
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
const os = require('os');
const path = require('path');
const {startTool} = require('./lib/start-tool');

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

/**
 * @description Test suites beyond the derived `<class>_TEST` pair that must run for a class's
 * targeted coverage to be complete — subjects whose test class was split to stay under the
 * cognitive-complexity ceiling, or shared engines exercised from a sibling subject's suite.
 */
const COMPANION_TEST_SUITES = {
	UTIL_AsyncChain: ['UTIL_AsyncChainRecovery_TEST', 'UTIL_AsyncChainApi_TEST', 'UTIL_AsyncChainTransition_TEST', 'UTIL_AsyncChainStepState_TEST'],
	CTRL_ChainMonitor: ['CTRL_ChainMonitorAbort_TEST', 'CTRL_ChainMonitorRedrive_TEST'],
	DML_Transaction: ['TST_Builder_TEST', 'UTIL_HttpClientOutcome_TEST'],
	API_Base: ['API_Outbound_TEST', 'API_Dispatcher_TEST', 'API_Echo_TEST'],
	API_Inbound: ['API_InboundIssue_TEST', 'API_InboundRetryLink_TEST'],
	API_Dispatcher: ['API_InboundIssue_TEST'],
	SEL_Hierarchy: ['SEL_HierarchyDepthLimit_TEST'],
	API_Outbound: [
		'UTIL_AsyncChainApi_TEST',
		'API_Dispatcher_TEST',
		'API_PostExample_TEST',
		'API_PublishGenericEvent_TEST',
		'UTIL_HttpClient_TEST',
		'UTIL_HttpClientDispatch_TEST',
		'UTIL_HttpClientOutcome_TEST'
	],
	UTIL_HttpClient: ['UTIL_HttpClientDispatch_TEST', 'UTIL_HttpClientOutcome_TEST', 'UTIL_AsyncChainApi_TEST'],
	UTIL_ScheduledJobRunner: ['CTRL_HealthCheck_TEST']
};

/**
 * @description Classes whose tests live in a suite other than the derived `<class>_TEST` twin: the class has
 * no twin in source, so the derived name resolves to nothing and a targeted run fails before it starts. Each
 * entry names the one primary suite that carries the class's coverage; a class absent here keeps the derived
 * twin. This is an explicit registry, never a search for a suite that mentions the class: a guessed suite
 * would measure the wrong thing and read as a clean gate.
 */
const PRIMARY_TEST_SUITE_OVERRIDES = {
	API_Inbound: 'API_Echo_TEST',
	API_OutboundTestHelper: 'API_PostExample_TEST',
	CTRL_ChainMonitorTypes: 'CTRL_ChainMonitor_TEST',
	DTO_FlowValidationError: 'FLOW_ExecuteValidationRules_TEST',
	DTO_PicklistValue: 'DTO_PickList_TEST',
	FLOW_LoggerEnd: 'FLOW_Logger_TEST',
	FLOW_LoggerLog: 'FLOW_Logger_TEST',
	FLOW_LoggerStart: 'FLOW_Logger_TEST',
	FLOW_SendEmailInternal: 'FLOW_SendEmail_TEST',
	REST_Echo: 'API_Echo_TEST',
	UTIL_AdaptiveAsynchronousProcessor: 'UTIL_AsynchronousJobLauncher_TEST'
};

/**
 * @description The most test classes one coverage-row repair re-runs. The measured incident was two; a
 * broadly empty aggregate would otherwise turn the repair into a second full run inside one wait.
 */
const REPAIR_RUN_MAXIMUM_TEST_CLASSES = 10;

/**
 * @description How long the repair run waits for a test class the org already has queued or running, in milliseconds.
 * The usual cause is the gate's own earlier run, which ends within minutes.
 */
const REPAIR_RUN_BUSY_WAIT_MILLISECONDS = 300000;

/** @description How often the repair run asks the org again whether a busy test class is done, in milliseconds. */
const REPAIR_RUN_BUSY_POLL_MILLISECONDS = 30000;

/** @description The error name Salesforce gives when it refuses a test run because the test class is already queued or running. */
const ALREADY_IN_PROCESS_ERROR = 'ALREADY_IN_PROCESS';

/** @description Repo-relative path to Jest's raw istanbul coverage output. */
const JEST_COVERAGE_SUMMARY_PATH = 'coverage/coverage-final.json';

/**
 * @description Repo-relative prefix every LWC component source file shares. The
 * baseline's `lwc.files` must contain only LWC `.js` source under this prefix.
 * The dedicated capture config (`LWC_COVERAGE_CONFIG`) still surfaces compiled
 * templates (`.html`), compiled styles (`.css.compiled`), and — in pathological
 * runs — non-LWC node files, so the summary is filtered to this prefix + a
 * `.js` suffix in code (see `filterToLwcSource`).
 */
const LWC_SOURCE_PREFIX = 'force-app/main/default/lwc/';

/**
 * @description Repo-relative path to the dedicated Jest config used for every
 * LWC coverage capture, targeted and full alike. It scopes `testMatch` to
 * force-app LWC specs and drops `collectCoverageFrom` so coverage is collected
 * only from test-loaded modules (the base config's `collectCoverageFrom`
 * triggers an empty-instrumentation pass that silently drops components whose
 * imports fail to resolve standalone).
 */
const LWC_COVERAGE_CONFIG = 'jest.lwc-coverage.config.cjs';

/** @description Exit codes emitted by the harness. */
const EXIT = Object.freeze({
	OK: 0, GATE_FAIL: 1, USAGE: 2, RUNTIME: 3
});

/**
 * @description Shape of an Apex test run id — the `707` AsyncApexJob id, 15 or 18 characters.
 * Anything else reads as absent, so a verdict is never tied to a value that is not a run id.
 */
const TEST_RUN_ID_PATTERN = /^707[A-Za-z0-9]{12}([A-Za-z0-9]{3})?$/;

/** @description How much of a failed subprocess's output is quoted back to the operator, in characters. */
const CLI_OUTPUT_EXCERPT_LENGTH = 300;

/** @description How long the poller waits before its first poll of a detached test run, in milliseconds. */
const POLL_INITIAL_DELAY_MILLISECONDS = 2000;

/** @description Multiplier applied to the poll delay after every poll, so a long run is polled ever more cheaply. */
const POLL_BACKOFF_FACTOR = 1.5;

/** @description Ceiling on a single poll delay, in milliseconds. */
const POLL_MAXIMUM_DELAY_MILLISECONDS = 30000;

/**
 * @description How many consecutive successful polls must show the same untouched queue with
 * nothing executing before the run is called stalled rather than slow.
 */
const STALL_SUCCESSFUL_POLL_THRESHOLD = 10;

/** @description How long one queue item may sit `Processing` before the poller warns about it, in milliseconds. */
const PROCESSING_WARNING_MILLISECONDS = 900000;

/**
 * @description `ApexTestQueueItem` statuses that mean the run still has work outstanding. The
 * complement — `Completed`, `Failed`, `Aborted` — is terminal for the poller, `Failed` on purpose:
 * a class that failed to compile or execute is done, and waiting for it to reach `Completed` would
 * hang every poll to the ceiling. Refusing such a run is the verdict's job, not the poller's.
 */
const QUEUE_ITEM_IN_FLIGHT_STATUSES = Object.freeze([
	'Holding',
	'Queued',
	'Preparing',
	'Processing'
]);

/** @description `ApexTestRunResult` statuses that mean the run row itself has settled. */
const RUN_ROW_TERMINAL_STATUSES = Object.freeze([
	'Completed',
	'Aborted',
	'Failed'
]);

/** @description Default wait ceiling in minutes for the full-run modes, matching the `--wait` default. */
const DEFAULT_FULL_RUN_WAIT_MINUTES = 60;

/**
 * @description How many unfinished queue items a refusal reason names before it summarises the
 * rest as a count. A compile failure usually takes one class down, so a handful is enough to act
 * on and a run that lost two hundred classes still yields a readable line.
 */
const QUEUE_ITEM_REASON_LIMIT = 5;

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
		apex: [], lwc: [], full: false, fixBaseline: false, skipDeploy: false, runTests: false, org: DEFAULT_ORG, waitMinutes: null, format: 'text', help: false, errors: []
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
				if(argv[index + 1])
				{
					options.org = argv[index + 1];
					index += 2;
				}
				else
				{
					options.errors.push('--org requires a value');
					index += 1;
				}
				break;
			case '--wait':
				if(argv[index + 1])
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
				else
				{
					options.errors.push('--wait requires a value (minutes)');
					index += 1;
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

	const modes = [
		options.full,
		options.fixBaseline,
		options.apex.length > 0 || options.lwc.length > 0
	].filter(Boolean).length;
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
 * @return {{logger: Object, runner: Function, cwd: string, readFile: Function, fileExists: Function,
 *     readdir: Function, writeFile: Function, now: Function, sleepMilliseconds: Function}}
 */
function buildDependencies(overrides)
{
	const defaults = {
		logger: {
			info: (message) => process.stdout.write(`${message}\n`),
			warn: (message) => process.stderr.write(`${message}\n`),
			error: (message) => process.stderr.write(`${message}\n`)
		},
		runner: defaultRunner,
		cwd: process.cwd(),
		readFile: (filePath) => fs.readFileSync(filePath, 'utf8'),
		fileExists: (filePath) => fs.existsSync(filePath),
		readdir: (dir) => fs.readdirSync(dir),
		writeFile: (filePath, contents) => fs.writeFileSync(filePath, contents, 'utf8'),
		now: () => Date.now(),
		sleepMilliseconds: defaultSleepMilliseconds
	};
	return {...defaults, ...(overrides || {})};
}

/**
 * @description Blocks the calling thread for the given number of milliseconds. Synchronous on
 * purpose: this harness is a straight-line `spawnSync` script, and the poll loop must not turn the
 * module async. Injected through the dependency bundle so tests drive a fake clock and never sleep.
 *
 * @param {number} count - Milliseconds to block for; zero or less returns immediately.
 * @return {void}
 */
function defaultSleepMilliseconds(count)
{
	const milliseconds = Math.max(0, Math.floor(Number(count) || 0));
	if(milliseconds === 0)
	{
		return;
	}
	Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, milliseconds);
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
	const result = startTool(command, args, {
		encoding: 'utf8', stdio: options && options.inherit ? 'inherit' : 'pipe', maxBuffer: 128 * 1024 * 1024, env
	});
	return {
		status: typeof result.status === 'number' ? result.status : EXIT.RUNTIME, stdout: result.stdout || '', stderr: result.stderr || ''
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
		apexResult: apexResult ? apexResult.coverage : null, lwcResult, baseline, apexTargets: options.apex, lwcTargets: options.lwc
	});

	return settleVerdict(evaluation, apexResult, lwcResult, options, deps);
}

/**
 * @description Emits the evaluation and settles the exit code the targeted and
 * full modes share. A threshold violation fails first; then apex test
 * failures; then a red component (jest) suite, which still writes coverage and
 * so would otherwise read as a pass. Only a run with none of the three is OK.
 *
 * @param {{pass: boolean, violations: Array<Object>, measurements: Array<Object>, notes: Array<Object>}} evaluation
 * @param {{coverage: {testsPassed: boolean, testFailures: Array<Object>}}|null} apexResult - Null when no apex ran.
 * @param {{testsPassed: boolean, jestExitStatus: number}|null} lwcResult - Null when no component suite ran.
 * @param {Object} options
 * @param {Object} deps
 * @return {number} Exit code.
 */
function settleVerdict(evaluation, apexResult, lwcResult, options, deps)
{
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
	if(lwcResult && !lwcResult.testsPassed)
	{
		deps.logger.error(`lwc jest suite failed (exit ${lwcResult.jestExitStatus})`);
		return EXIT.GATE_FAIL;
	}
	return EXIT.OK;
}

// ─────────────────────────────────────────────────────────────────────────────
// Mode: --full (Phase 3 regression gate)
// ─────────────────────────────────────────────────────────────────────────────

/**
 * @description Lists the Apex classes `--full` checks: every class the baseline holds, and every class in this
 * source tree except test classes, interfaces and enums. A new class the baseline does not hold yet is checked
 * against the floor, so a new class at 0% fails. When no test touches the new class, the org returns no coverage
 * row for it, and the gate fails it as missing. An interface or an enum has no lines to cover and never gets a
 * row, so it is left out by reading its source. A class the org reports that is not in this source tree is left out.
 *
 * @param {Object} baseline - Committed baseline snapshot.
 * @param {Object} deps
 * @return {Array<string>} The class names, sorted.
 */
function listFullApexTargets(baseline, deps)
{
	const classesDirectory = path.join(deps.cwd, CLASSES_RELATIVE_PATH);
	const sourceClasses = listAllApexSourceClasses(deps)
	.filter(className => !declaresInterfaceOrEnum(deps.readFile(path.join(classesDirectory, `${className}.cls`)), className));
	return [...new Set([...Object.keys(baseline.apex?.classes || {}), ...sourceClasses])].sort();
}

/**
 * @description Tells whether an Apex source file declares an interface or an enum at the top level. Neither has
 * lines to cover. It drops comments, string literals and annotations, then looks for `interface <name>` or `enum <name>`, where
 * the name is the file's own type name. An inner type cannot share the file's name, so the word "interface" left
 * in an annotation argument or a comment never makes a class read as an interface.
 *
 * @param {string} source - The text of the `.cls` file.
 * @param {string} className - The file's type name, the file name without `.cls`.
 * @return {boolean} True when the file declares an interface or an enum of that name.
 */
function declaresInterfaceOrEnum(source, className)
{
	const code = String(source || '')
	.replace(/\/\*[\s\S]*?\*\//g, ' ')
	.replace(/\/\/[^\n]*/g, ' ')
	.replace(/'(?:\\.|[^'\\\n])*'/g, ' ')
	.replace(/@\w+(\s*\([^)]*\))?/g, ' ');
	const escapedName = className.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
	return new RegExp(`\\b(interface|enum)\\s+${escapedName}\\b`, 'i').test(code);
}

/**
 * @description Walks every class in the baseline or in source, and every LWC
 * file in the baseline, and fails on any regression or floor breach. Intended
 * for pre-release or CI runs, not per-commit.
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
	if(apexResult.testRunBlocked)
	{
		return EXIT.GATE_FAIL;
	}
	const lwcResult = runFullLwc(deps);

	const evaluation = lib.evaluateThresholds({
		apexResult: apexResult.coverage, lwcResult, baseline, apexTargets: listFullApexTargets(baseline, deps), lwcTargets: listBaselineComponents(baseline)
	});

	return settleVerdict(evaluation, apexResult, lwcResult, options, deps);
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
 * stdout for GitHub Actions to pick up. A target the baseline does not hold is
 * named after the summary in both: as a warning line on stderr in `text`, as a
 * `::notice` in `github-annotations`; the PMD document carries violations only.
 *
 * @param {{pass: boolean, violations: Array<Object>, measurements: Array<Object>, notes?: Array<Object>}} evaluation
 * @param {{format?: string}} options
 * @param {{logger: {info: Function, warn: Function, error: Function}}} deps
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
		const notices = lib.formatGithubNotices(evaluation.notes);
		if(notices.length > 0)
		{
			deps.logger.info(notices.replace(/\n$/, ''));
		}
		return;
	}
	deps.logger.info(lib.formatSummaryLine(evaluation.measurements, evaluation.pass));
	const notes = lib.formatNotesReport(evaluation.notes);
	if(notes.length > 0)
	{
		deps.logger.warn(notes);
	}
	if(!evaluation.pass)
	{
		deps.logger.error(lib.formatViolationsReport(evaluation.violations));
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Mode: --fix-baseline
// ─────────────────────────────────────────────────────────────────────────────

/**
 * @description Captures a fresh baseline from the org's current coverage and a full jest run and
 * writes it to `scripts/coverage-baseline.json`, but only after the test run it reports on is
 * verified fully green (`baselineRunVerdict`); on any other run it writes nothing and fails. The
 * code must already be deployed; no deploy step is performed.
 *
 * @param {Object} options
 * @param {Object} deps
 * @return {number} Exit code.
 */
function runFixBaseline(options, deps)
{
	const apexResult = runFullApex(options, deps);
	if(apexResult.testRunBlocked)
	{
		return EXIT.GATE_FAIL;
	}
	apexResult.coverage.testRun = withRunVerificationInputs(apexResult.coverage.testRun, options, deps);
	const verdict = baselineRunVerdict(apexResult.coverage, options);
	if(!verdict.green)
	{
		deps.logger.error(`baseline not written: ${verdict.reason}; re-run when RunLocalTests is fully green`);
		return EXIT.GATE_FAIL;
	}

	const lwcResult = runFullLwc(deps);
	if(!lwcResult.testsPassed)
	{
		deps.logger.error(`baseline not written: lwc jest suite failed (exit ${lwcResult.jestExitStatus}); re-run when the component suite is fully green`);
		return EXIT.GATE_FAIL;
	}
	const testSetupClasses = findTestSetupClasses(deps);

	const baseline = lib.buildBaseline({
		apexResult: apexResult.coverage, lwcResult, testSetupClasses, lwcRuntimeSeconds: lwcResult.totalRuntimeSeconds || 0
	});
	const baselinePath = path.join(deps.cwd, BASELINE_RELATIVE_PATH);
	deps.writeFile(baselinePath, `${JSON.stringify(baseline, null, 2)}\n`);

	const apexClassCount = Object.keys(baseline.apex.classes).length;
	const lwcFileCount = Object.keys(baseline.lwc.files).length;
	const testRun = apexResult.coverage.testRun;
	deps.logger.info(`baseline written to ${BASELINE_RELATIVE_PATH}`);
	deps.logger.info(`apex classes: ${apexClassCount} | lwc files: ${lwcFileCount} | @TestSetup classes: ${testSetupClasses.length}`);
	deps.logger.info(`verified against test run ${testRun.runId}: ${verdict.reason}`);
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
			capturedAt: null, apex: {totalWallClockSeconds: 0, testSetupClasses: [], classes: {}}, lwc: {totalRuntimeSeconds: 0, files: {}}
		};
	}
	return JSON.parse(deps.readFile(baselinePath));
}

// ─────────────────────────────────────────────────────────────────────────────
// Apex measurement
// ─────────────────────────────────────────────────────────────────────────────

/**
 * @description The suite that carries a class's own coverage: the registered primary suite when the class has
 * no `_TEST` twin, otherwise the derived twin.
 *
 * @param {string} className
 * @return {string}
 */
function primaryTestSuiteFor(className)
{
	return PRIMARY_TEST_SUITE_OVERRIDES[className] ?? `${className}_TEST`;
}

/**
 * @description The test classes a class's coverage depends on: its primary suite (the `_TEST` twin, or the
 * registered override) plus the companion suites registered for it. Shared by the targeted run and the
 * coverage-row repair.
 *
 * @param {Array<string>} classes
 * @return {Array<string>}
 */
function testSuitesFor(classes)
{
	return [...new Set(classes.flatMap(name => [primaryTestSuiteFor(name), ...(COMPANION_TEST_SUITES[name] ?? [])]))];
}

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
	const testClasses = testSuitesFor(classes);
	const raw = executeApexTests(testClasses, options, deps);
	const parsed = lib.parseApexCoverage(raw);
	const exemptLines = gatherExemptLineNumbers(classes, deps);
	const adjusted = lib.applyApexExemptions(parsed, exemptLines);
	return {coverage: adjusted};
}

/**
 * @description For `--full` and `--fix-baseline`: queries current org coverage
 * via Tooling API. Assumes the code is deployed and the user has recently run
 * tests. This is dramatically faster than `sf apex run test --result-format
 * json` which OOMs Node on large packages during JSON serialisation.
 *
 * With `--run-tests` the run is started detached and waited for by `pollTestRunUntilTerminal`; only
 * a run the poller saw finish is measured. Any other poll outcome, and a started run whose id could
 * not be read at all, returns `testRunBlocked` instead of coverage, so no caller can evaluate — or
 * mint a baseline from — a run that never completed or that this gate never saw.
 *
 * The run's verification inputs are not fetched here: `--fix-baseline` attaches them itself, right
 * before the verdict that is the only thing reading them.
 *
 * @param {Object} options
 * @param {Object} deps
 * @return {{coverage: Object|null, testRunBlocked: Object|null}}
 */
function runFullApex(options, deps)
{
	const executedRun = options.runTests ? startAndAwaitDetachedRun(options, deps) : {runId: null, blocked: null};
	if(executedRun.blocked)
	{
		reportUnverifiableRun(executedRun.blocked, deps);
		return {coverage: null, testRunBlocked: executedRun.blocked};
	}
	const executedRunId = executedRun.runId;
	deps.logger.info(`querying ApexCodeCoverageAggregate from ${options.org}…`);
	const coverageRows = queryToolingApi('SELECT ApexClassOrTrigger.Name, NumLinesCovered, NumLinesUncovered, Coverage FROM ApexCodeCoverageAggregate', options, deps);
	const parsed = normaliseAggregateRows(coverageRows);
	const reconciled = reconcileFlakyAggregateClasses(parsed, options, deps);
	// The run the gate reports on is resolved before any repair run: a repair is a newer, smaller run, and
	// the verdict must stay pinned to the full run the aggregate came from.
	const testStatus = queryLatestTestRunStatus(options, deps, executedRunId);
	const repaired = repairTestClassesWithoutCoverageRows(reconciled, options, deps);
	const allClasses = listAllApexSourceClasses(deps);
	const exemptLines = gatherExemptLineNumbers(allClasses, deps);
	const adjusted = lib.applyApexExemptions(repaired, exemptLines);
	adjusted.testsPassed = testStatus.testsPassed;
	adjusted.testFailures = testStatus.testFailures;
	adjusted.wallClockSeconds = testStatus.wallClockSeconds;
	adjusted.testRun = testStatus;
	adjusted.executedRunId = executedRunId;
	return {coverage: adjusted, testRunBlocked: null};
}

/**
 * @description Starts a detached `RunLocalTests` and waits for the test queue to drain. A run the
 * poller could not see through to `Completed` — timed out, stalled, or settled on `Aborted`/`Failed`
 * — comes back as `blocked` carrying the poll state, which is the only honest thing to report: the
 * org's coverage rows at that moment belong to a run that is still writing them or never finished.
 * A run that was started but whose id could not be read is blocked too, under the `runIdUnreadable`
 * outcome: there is nothing to poll and nothing to verify against, so the org's coverage rows are
 * being written by a run this gate cannot see. Neither caller may measure them, and `--full` has no
 * verdict step that would catch it later.
 *
 * @param {Object} options
 * @param {Object} deps
 * @return {{runId: string|null, blocked: Object|null}}
 */
function startAndAwaitDetachedRun(options, deps)
{
	const runId = startDetachedTestRun(options, deps);
	if(!runId)
	{
		return {
			runId: null,
			blocked: {outcome: 'runIdUnreadable', runId: null, runRowStatus: null, elapsedMilliseconds: 0, warnings: [], inFlightItems: []}
		};
	}
	const poll = pollTestRunUntilTerminal(runId, options, deps);
	if(poll.outcome === 'completed')
	{
		deps.logger.info(`test run ${runId} finished after ${Math.round(poll.elapsedMilliseconds / 1000)}s; verifying it`);
		return {runId, blocked: null};
	}
	return {runId, blocked: {runId, ...poll}};
}

/**
 * @description Prints why a detached run could not be verified: the poll outcome, the run row's last
 * status, the time actually waited (not the budget), every warning the poller raised, and the queue
 * items still in flight when it gave up. Enough for a human to decide between re-running and going
 * to look at a stuck class. The `runIdUnreadable` outcome has none of that to print, so it says
 * instead that the run was started and names both places the id was looked for.
 *
 * @param {Object} blocked - The poll result plus the `runId`: `outcome`, `runRowStatus`,
 *     `elapsedMilliseconds`, `warnings` and `inFlightItems`.
 * @param {Object} deps
 * @return {void}
 */
function reportUnverifiableRun(blocked, deps)
{
	if(blocked.outcome === 'runIdUnreadable')
	{
		deps.logger.error('the test run was started but its id could not be read, from neither the CLI JSON (result.testRunId) nor test-run-id.txt '
			+ 'in the output directory, so there is nothing to poll and nothing to verify the org coverage rows against');
	}
	else
	{
		deps.logger.error(`test run ${blocked.runId} did not complete: ${blocked.outcome} after ${Math.round(blocked.elapsedMilliseconds / 1000)}s `
			+ `(run row status: ${blocked.runRowStatus || 'unknown'})`);
	}
	for(const warning of blocked.warnings)
	{
		deps.logger.error(`  warning: ${warning}`);
	}
	if(blocked.inFlightItems.length > 0)
	{
		deps.logger.error(`  still in flight: ${blocked.inFlightItems.map(item => `${describeQueueItem(item)} ${item.status}`).join(', ')}`);
	}
	deps.logger.error('no coverage was evaluated and no baseline was written');
}

/**
 * @description Adds the two inputs the verdict decides on to a run's status: every `ApexTestQueueItem`
 * of the run with the `ExtendedStatus` that explains a failed one, and the run's outcome tally. The
 * tally is aggregated in the org (one row per `Outcome`) because a full run produces thousands of
 * `ApexTestResult` rows and none of them is needed individually. Both are fetched after the run has
 * finished, so a query that throws here is fatal by design: an unreadable run is an unverified run.
 *
 * Only `--fix-baseline` asks for them; `--full` has no verdict step and never issues these queries.
 *
 * @param {Object} testRun - The result of `queryLatestTestRunStatus`.
 * @param {Object} options
 * @param {Object} deps
 * @return {Object} The run status with `queueItems` and `resultTally` added.
 */
function withRunVerificationInputs(testRun, options, deps)
{
	if(!testRun.runFound || !testRun.runId)
	{
		return {...testRun, queueItems: [], resultTally: {}};
	}
	const escaped = String(testRun.runId).replace(/'/g, "\\'");
	const queueItems = queryToolingApi(`SELECT Id, Status, ExtendedStatus, ApexClass.Name FROM ApexTestQueueItem WHERE ParentJobId = '${escaped}'`, options, deps);
	const tallyRows = queryToolingApi(`SELECT Outcome, COUNT(Id) resultTally FROM ApexTestResult WHERE AsyncApexJobId = '${escaped}' GROUP BY Outcome`, options, deps);
	return {...testRun, queueItems, resultTally: normaliseResultTallyRows(tallyRows)};
}

/**
 * @description Converts the `GROUP BY Outcome` rows into an outcome-to-count map. The Tooling API
 * returns the count under the query's alias, falling back to `expr0` when an alias is dropped, so
 * both are read; a row whose count is neither is worth nothing and is skipped rather than counted
 * as zero passes.
 *
 * @param {Array<Object>} rows
 * @return {Object<string, number>}
 */
function normaliseResultTallyRows(rows)
{
	const tally = {};
	for(const row of rows)
	{
		const outcome = row && row.Outcome;
		const count = Number(row && (row.resultTally ?? row.expr0));
		if(!outcome || !Number.isFinite(count))
		{
			continue;
		}
		tally[outcome] = (tally[outcome] || 0) + count;
	}
	return tally;
}

/**
 * @description Salesforce's `ApexCodeCoverageAggregate` under-reports coverage
 * for heavily-shared classes after a parallel `RunLocalTests` — coverage-record
 * write contention drops rollup entries even though each class's per-test
 * `ApexCodeCoverage` rows are complete. For every class the aggregate shows
 * below 100%, this re-derives the true figure from the per-test union and
 * upgrades the class when the union is higher (`reconcileAggregateWithPerTestRows`
 * never downgrades). Classes already at 100% incur no extra query, so the happy
 * path is unchanged and a genuine gap is still reported.
 *
 * @param {{classes: Object<string, Object>}} coverage - Aggregate-derived coverage.
 * @param {Object} options
 * @param {Object} deps
 * @return {{classes: Object<string, Object>}}
 */
function reconcileFlakyAggregateClasses(coverage, options, deps)
{
	const belowFloor = classesBelowFloor(coverage);
	if(belowFloor.length === 0)
	{
		return coverage;
	}
	deps.logger.info(`reconciling ${belowFloor.length} below-100% class(es) against per-test coverage: ${belowFloor.join(', ')}`);
	const perTestRowsByClass = {};
	for(const className of belowFloor)
	{
		perTestRowsByClass[className] = queryPerTestCoverageRows(className, options, deps);
	}
	return lib.reconcileAggregateWithPerTestRows(coverage, perTestRowsByClass);
}

/**
 * @description Queries the raw per-test `ApexCodeCoverage` rows for one class —
 * every test method that touched it — so its true union coverage can be computed
 * when the aggregate rollup is suspected of under-reporting.
 *
 * @param {string} className
 * @param {Object} options
 * @param {Object} deps
 * @return {Array<Object>}
 */
function queryPerTestCoverageRows(className, options, deps)
{
	const escaped = String(className).replace(/'/g, "\\'");
	return queryToolingApi(`SELECT Coverage FROM ApexCodeCoverage WHERE ApexClassOrTrigger.Name = '${escaped}'`, options, deps);
}

/**
 * @description The classes the aggregate shows with at least one uncovered line.
 *
 * @param {{classes: Object<string, Object>}} coverage
 * @return {Array<string>}
 */
function classesBelowFloor(coverage)
{
	return Object.entries((coverage && coverage.classes) || {})
	.filter(([, entry]) => entry && entry.uncoveredLines > 0)
	.map(([name]) => name);
}

/**
 * @description A full run can finish with every test passing and still leave a test class with no per-test
 * `ApexCodeCoverage` rows for a class it covers (2026-09-03, Winter '27: two test classes of 185, 41 tests all
 * Pass, 0 rows), so that class reads far below the floor and the per-test union has nothing to add.
 * For every class still below 100 % after reconciliation, this names the test classes that should have
 * covered it (the `_TEST` twin and the companion suites, those present in source), asks the org which test
 * classes currently hold coverage rows for THAT class, re-runs once with coverage the ones that hold none, and
 * reconciles again. The check is keyed by the pair: a test class that wrote rows for other classes and none
 * for the class below the floor is row-less for it and is re-run. A class whose test classes all hold rows for
 * it is left alone: its gap is genuine and the gate reports it. The repair is best effort: a re-run that fails
 * or leaves no result is logged and the gate evaluates what the org holds. The run the gate reports on is
 * resolved by the caller before this runs, so the repair run never becomes the run a verdict is decided from.
 * Rows carry no run id, so a test class that wrote rows for the class in an earlier run and none in this one
 * reads as healthy here. Every class is asked about before the re-run set is capped: asking is one query per
 * class, and capping first would re-run an arbitrary subset. Before the re-run, a test class the org already has
 * queued or running is waited for (see `testClassesTheOrgIsNotRunning`), because Salesforce refuses to run a test
 * class twice at once.
 *
 * @param {{classes: Object<string, Object>}} coverage - Reconciled coverage.
 * @param {Object} options
 * @param {Object} deps
 * @return {{classes: Object<string, Object>}}
 */
function repairTestClassesWithoutCoverageRows(coverage, options, deps)
{
	const belowFloor = classesBelowFloor(coverage);
	if(belowFloor.length === 0)
	{
		return coverage;
	}
	const allRowless = testSuitesHoldingNoCoverageRowsFor(belowFloor, options, deps);
	const rowless = allRowless.slice(0, REPAIR_RUN_MAXIMUM_TEST_CLASSES);
	if(rowless.length === 0)
	{
		return coverage;
	}
	const capNote = allRowless.length > rowless.length ? ` (the first ${rowless.length} of ${allRowless.length})` : '';
	deps.logger.info(`${allRowless.length} test class(es) left no coverage rows for a class below the floor; re-running with coverage${capNote}: ${rowless.join(', ')}`);
	const runnable = testClassesTheOrgIsNotRunning(rowless, options, deps);
	if(runnable.length > 0)
	{
		runRepairTests(runnable, options, deps);
	}
	return reconcileFlakyAggregateClasses(coverage, options, deps);
}

/**
 * @description The test classes the repair run may start now. Salesforce refuses to run a test class it already
 * has queued or running, so this asks the test queue first. A busy class is asked about again every
 * `REPAIR_RUN_BUSY_POLL_MILLISECONDS`, for up to `REPAIR_RUN_BUSY_WAIT_MILLISECONDS`. A class still busy after
 * that is left out and named in one warning; the gate then uses the coverage the org already holds for it.
 * If the first read of the queue fails, nothing is known to be busy and every class is returned. A later read
 * that fails is retried at the next poll.
 *
 * @param {Array<string>} testClasses - The test classes chosen for the repair run.
 * @param {Object} options
 * @param {Object} deps
 * @return {Array<string>} The test classes not busy, in the order given.
 */
function testClassesTheOrgIsNotRunning(testClasses, options, deps)
{
	const waitMinutes = REPAIR_RUN_BUSY_WAIT_MILLISECONDS / 60000;
	const maximumPolls = REPAIR_RUN_BUSY_WAIT_MILLISECONDS / REPAIR_RUN_BUSY_POLL_MILLISECONDS;
	let busy;
	try
	{
		busy = readBusyTestClasses(testClasses, options, deps);
	}
	catch(error)
	{
		deps.logger.warn(`could not read the test queue before the repair run (${error.code || error.name}: ${error.message}); re-running without waiting`);
		return testClasses;
	}
	if(busy.length > 0)
	{
		deps.logger.info(`the org already has ${busy.join(', ')} queued or running; waiting up to ${waitMinutes} minutes for them to finish`);
	}
	for(let poll = 0; busy.length > 0 && poll < maximumPolls; poll++)
	{
		deps.sleepMilliseconds(REPAIR_RUN_BUSY_POLL_MILLISECONDS);
		try
		{
			busy = readBusyTestClasses(busy, options, deps);
		}
		catch(error)
		{
			deps.logger.warn(`a read of the test queue failed; asking again in ${REPAIR_RUN_BUSY_POLL_MILLISECONDS / 1000}s: ${error.message}`);
		}
	}
	if(busy.length > 0)
	{
		deps.logger.warn(`left out of the repair run, because the org still had them queued or running after ${waitMinutes} minutes: ${busy.join(', ')}; `
			+ 'the verdict uses the coverage the org already holds for them');
	}
	return testClasses.filter(name => !busy.includes(name));
}

/**
 * @description Asks the org which of the given test classes it has waiting or running now: their
 * `ApexTestQueueItem` rows in any status of `QUEUE_ITEM_IN_FLIGHT_STATUSES`, from any test run. One query.
 *
 * @param {Array<string>} testClasses
 * @param {Object} options
 * @param {Object} deps
 * @return {Array<string>} The busy test classes, in the order given.
 */
function readBusyTestClasses(testClasses, options, deps)
{
	const names = testClasses.map(name => `'${String(name).replace(/'/g, "\\'")}'`).join(', ');
	const statuses = QUEUE_ITEM_IN_FLIGHT_STATUSES.map(status => `'${status}'`).join(', ');
	const rows = queryToolingApi(
		`SELECT ApexClass.Name, Status FROM ApexTestQueueItem WHERE ApexClass.Name IN (${names}) AND ApexClass.NamespacePrefix = null AND Status IN (${statuses})`,
		options, deps
	);
	const busyNames = new Set(rows
	.filter(row => QUEUE_ITEM_IN_FLIGHT_STATUSES.includes(row.Status) && row.ApexClass && row.ApexClass.Name)
	.map(row => row.ApexClass.Name));
	return testClasses.filter(name => busyNames.has(name));
}

/**
 * @description Runs the repair tests and reads how the run ended. The CLI's JSON is captured, not shown, so its exit
 * status and error can be read. Three outcomes, each logged: the org refused the run because a test class is
 * already queued or running (`ALREADY_IN_PROCESS`), so the verdict uses the coverage the org already holds; the
 * run failed with another error, named with its code; or the run finished and its result file is read. The repair
 * is best effort, so no outcome stops the gate.
 *
 * @param {Array<string>} testClasses
 * @param {Object} options
 * @param {Object} deps
 * @return {void}
 */
function runRepairTests(testClasses, options, deps)
{
	const outputDir = apexOutputDir(deps);
	const names = testClasses.join(', ');
	deps.logger.info(`running apex tests: ${names}`);
	const result = deps.runner('sf', [...apexTestRunArguments(testClasses, options, outputDir), '--json'], {inherit: false}) || {};
	if(result.status !== 0)
	{
		const envelope = parseJsonOrNull(result.stdout);
		const refused = envelope
			? [envelope.name, envelope.code].includes(ALREADY_IN_PROCESS_ERROR) || String(envelope.message || '').startsWith(ALREADY_IN_PROCESS_ERROR)
			: String(result.stderr || '').includes(ALREADY_IN_PROCESS_ERROR);
		if(refused)
		{
			deps.logger.info(`the org refused the repair run of ${names} with ${ALREADY_IN_PROCESS_ERROR}, because a test class is already queued or running; `
				+ 'the verdict uses the coverage the org already holds');
			return;
		}
		if(envelope && envelope.name)
		{
			const code = envelope.code || 'not given';
			deps.logger.warn(`the repair run of ${names} failed (exit ${result.status}, ${envelope.name}, code ${code}: ${envelope.message || 'no message'}); `
				+ 'evaluating what the org holds');
			return;
		}
	}
	try
	{
		readApexResultFile(outputDir, deps);
	}
	catch(error)
	{
		deps.logger.warn(`the repair run of ${names} produced no result (${error.code || error.name}: ${error.message}); evaluating what the org holds`);
	}
}

/**
 * @description Parses a CLI's JSON output, or gives null when the output is empty or not JSON. For output that may be an
 * error envelope or nothing at all; output that must be JSON goes through `lib.safeParseJson`, which throws.
 *
 * @param {string} text
 * @return {Object|null}
 */
function parseJsonOrNull(text)
{
	try
	{
		return text ? JSON.parse(text) : null;
	}
	catch
	{
		return null;
	}
}

/**
 * @description The test classes that hold no per-test `ApexCodeCoverage` rows for a class they should have
 * covered: for each class, its test suites present in source, minus the ones the org shows holding rows for
 * it. One query per class; a class with no test suite in source is a genuine gap and costs no query.
 *
 * @param {Array<string>} classes - The classes still below the floor.
 * @param {Object} options
 * @param {Object} deps
 * @return {Array<string>} Each row-less test class once, in first-seen order.
 */
function testSuitesHoldingNoCoverageRowsFor(classes, options, deps)
{
	const rowless = new Set();
	for(const className of classes)
	{
		const expected = testSuitesFor([className]).filter(name => deps.fileExists(path.join(deps.cwd, CLASSES_RELATIVE_PATH, `${name}.cls`)));
		const holding = expected.length === 0 ? new Set() : queryTestSuitesHoldingCoverageRowsFor(className, options, deps);
		expected.filter(name => !holding.has(name)).forEach(name => rowless.add(name));
	}
	return [...rowless];
}

/**
 * @description The names of the test classes that currently hold at least one per-test `ApexCodeCoverage` row
 * for a class. Grouped, so the answer is one row per test class however many test methods touched the class.
 *
 * @param {string} className
 * @param {Object} options
 * @param {Object} deps
 * @return {Set<string>}
 */
function queryTestSuitesHoldingCoverageRowsFor(className, options, deps)
{
	const escaped = String(className).replace(/'/g, "\\'");
	const soql = `SELECT ApexTestClass.Name suiteName FROM ApexCodeCoverage WHERE ApexClassOrTrigger.Name = '${escaped}' GROUP BY ApexTestClass.Name`;
	return new Set(queryToolingApi(soql, options, deps).map(row => row.suiteName));
}

/**
 * @description Reads the run id `sf apex run test --output-dir` records in `test-run-id.txt`, so a
 * verdict can be tied to the run that was just executed rather than to whichever run is newest. The
 * id must be an Apex test run id (`707` followed by 12 or 15 alphanumerics); anything else reads as
 * absent, which the baseline verdict treats as "cannot verify" rather than "green".
 *
 * @param {string} outputDir
 * @param {Object} deps
 * @return {string|null} The run id, or null when the file is absent, empty or malformed.
 */
function readTestRunId(outputDir, deps)
{
	const filePath = path.join(outputDir, 'test-run-id.txt');
	if(!deps.fileExists(filePath))
	{
		return null;
	}
	const runId = String(deps.readFile(filePath) || '').trim();
	return TEST_RUN_ID_PATTERN.test(runId) ? runId : null;
}

/**
 * @description Starts a full `RunLocalTests` run and returns as soon as the run is enqueued: the
 * same arguments the blocking run uses, minus `--wait` and plus `--json`. The wait then belongs to
 * `pollTestRunUntilTerminal`, which decides completion from the test queue rather than from the
 * CLI's own progress counter. `--code-coverage` is what makes the run's coverage rows appear, and
 * `--output-dir` keeps the `test-run-id.txt` fallback available, so both must survive any edit.
 *
 * @param {Object} options
 * @param {Object} deps
 * @return {string|null} The `707` run id from the CLI JSON, else from `test-run-id.txt`, else null.
 */
function startDetachedTestRun(options, deps)
{
	const outputDir = apexOutputDir(deps);
	const args = [
		'apex',
		'run',
		'test',
		'-o',
		options.org,
		'--test-level',
		'RunLocalTests',
		'--code-coverage',
		'--json',
		'--output-dir',
		outputDir
	];
	deps.logger.info(`starting RunLocalTests against ${options.org} (detached; this gate polls the test queue for completion)…`);
	const result = deps.runner('sf', args, {inherit: false});
	const runIdFromJson = parseDetachedRunId(result);
	if(!runIdFromJson)
	{
		const cliOutput = String((result && (result.stderr || result.stdout)) || '').trim();
		deps.logger.warn(`the detached start printed no readable run id (exit ${(result && result.status) ?? 'unknown'}): `
			+ `${cliOutput.slice(0, CLI_OUTPUT_EXCERPT_LENGTH) || 'no output'}`);
	}
	return runIdFromJson || readTestRunId(outputDir, deps);
}

/**
 * @description Pulls `result.testRunId` out of `sf apex run test --json` stdout. Deliberately
 * forgiving: a CLI that printed a warning banner, failed outright, or emitted a value that is not
 * a run id yields null so the caller can fall back to `test-run-id.txt`.
 *
 * @param {{stdout: string}} result - The runner result.
 * @return {string|null}
 */
function parseDetachedRunId(result)
{
	let parsed = null;
	try
	{
		parsed = JSON.parse((result && result.stdout) || '');
	}
	catch
	{
		return null;
	}
	const runId = String((parsed && parsed.result && parsed.result.testRunId) || '').trim();
	return TEST_RUN_ID_PATTERN.test(runId) ? runId : null;
}

/**
 * @description Waits for a detached test run to reach a terminal state, deciding from the queue
 * itself: the run is done when no `ApexTestQueueItem` is still in flight and the `ApexTestRunResult`
 * row has settled. `MethodsCompleted` is never consulted — it under-reports on runs that are
 * genuinely finished, which is what makes the CLI's own wait hang past completion.
 *
 * Sleeps before every poll, including the first, backing off from
 * `POLL_INITIAL_DELAY_MILLISECONDS` towards `POLL_MAXIMUM_DELAY_MILLISECONDS`. A poll whose query
 * throws is missed, not fatal: it is logged and retried, and it neither advances nor resets the
 * stall counter. Outcomes: `completed` (queue drained, run row `Completed`), `runNotCompleted`
 * (queue drained, run row `Aborted`/`Failed`), `stall` (past half the ceiling, nothing executing,
 * and the same items left waiting across `STALL_SUCCESSFUL_POLL_THRESHOLD` successful polls), and
 * `timeout` (the `--wait` budget ran out). Every non-`completed` outcome carries the run-row status,
 * the elapsed time and the items still in flight so the caller can say why it gave up. A class that
 * has been executing for more than `PROCESSING_WARNING_MILLISECONDS` adds one warning of its own
 * and is then waited on regardless: slow is not the same as stuck.
 *
 * @param {string} runId - The `707` AsyncApexJob id of the run to wait for.
 * @param {Object} options
 * @param {Object} deps
 * @return {{outcome: string, runRowStatus: string|null, elapsedMilliseconds: number,
 *     warnings: Array<string>, inFlightItems: Array<{id: string, status: string, className: string|null}>}}
 */
function pollTestRunUntilTerminal(runId, options, deps)
{
	const startedAt = deps.now();
	const ceilingMilliseconds = (options.waitMinutes || DEFAULT_FULL_RUN_WAIT_MINUTES) * 60 * 1000;
	const warnings = [];
	let delayMilliseconds = POLL_INITIAL_DELAY_MILLISECONDS;
	let runRowStatus = null;
	let inFlightItems = [];
	let stallSignature = null;
	let stallPollCount = 0;
	const processingSinceById = new Map();
	const processingWarnedIds = new Set();

	while(deps.now() - startedAt < ceilingMilliseconds)
	{
		deps.sleepMilliseconds(delayMilliseconds);
		delayMilliseconds = Math.min(Math.round(delayMilliseconds * POLL_BACKOFF_FACTOR), POLL_MAXIMUM_DELAY_MILLISECONDS);

		let poll = null;
		try
		{
			poll = readTestRunPollState(runId, options, deps);
		}
		catch(error)
		{
			deps.logger.warn(`poll of test run ${runId} failed; retrying: ${error.message}`);
			continue;
		}

		const elapsedMilliseconds = deps.now() - startedAt;
		runRowStatus = poll.runRowStatus;
		inFlightItems = poll.queueItems
		.filter(item => QUEUE_ITEM_IN_FLIGHT_STATUSES.includes(item.Status))
		.map(item => ({id: item.Id, status: item.Status, className: item.ApexClass && item.ApexClass.Name ? item.ApexClass.Name : null}));

		if(inFlightItems.length === 0 && RUN_ROW_TERMINAL_STATUSES.includes(runRowStatus))
		{
			return {
				outcome: runRowStatus === 'Completed' ? 'completed' : 'runNotCompleted', runRowStatus, elapsedMilliseconds, warnings, inFlightItems
			};
		}

		const executing = inFlightItems.filter(item => item.status === 'Processing');
		warnLongRunningItems(executing, elapsedMilliseconds, {processingSinceById, processingWarnedIds, warnings}, deps);

		const waiting = inFlightItems.filter(item => item.status !== 'Processing');
		const stallPossible = elapsedMilliseconds > ceilingMilliseconds / 2 && executing.length === 0 && waiting.length > 0;
		if(!stallPossible)
		{
			stallSignature = null;
			stallPollCount = 0;
			continue;
		}
		const signature = waiting.map(item => item.id).sort().join(',');
		stallPollCount = signature === stallSignature ? stallPollCount + 1 : 1;
		stallSignature = signature;
		if(stallPollCount >= STALL_SUCCESSFUL_POLL_THRESHOLD)
		{
			return {
				outcome: 'stall', runRowStatus, elapsedMilliseconds, warnings, inFlightItems
			};
		}
	}

	return {
		outcome: 'timeout', runRowStatus, elapsedMilliseconds: deps.now() - startedAt, warnings, inFlightItems
	};
}

/**
 * @description Warns about any single test class that has been executing for longer than
 * `PROCESSING_WARNING_MILLISECONDS`, measured from the poll at which that item was first seen
 * `Processing` — not from the start of the run, which would warn about a class that only just
 * began merely because the run itself is long. The warning latches per item id, so each slow class
 * is reported exactly once; an item that leaves `Processing` forgets both its start time and its
 * latch, so a later spell starts its clock afresh.
 *
 * @param {Array<{id: string, status: string, className: string|null}>} executing - The items reading
 *     `Processing` this poll.
 * @param {number} elapsedMilliseconds - Milliseconds since the poll loop started.
 * @param {{processingSinceById: Map, processingWarnedIds: Set, warnings: Array<string>}} tracker -
 *     Mutable per-run state carried across polls.
 * @param {Object} deps
 * @return {void}
 */
function warnLongRunningItems(executing, elapsedMilliseconds, tracker, deps)
{
	const executingIds = new Set(executing.map(item => item.id));
	for(const id of [...tracker.processingSinceById.keys()])
	{
		if(!executingIds.has(id))
		{
			tracker.processingSinceById.delete(id);
			tracker.processingWarnedIds.delete(id);
		}
	}
	for(const item of executing)
	{
		if(!tracker.processingSinceById.has(item.id))
		{
			tracker.processingSinceById.set(item.id, elapsedMilliseconds);
			continue;
		}
		const processingMilliseconds = elapsedMilliseconds - tracker.processingSinceById.get(item.id);
		if(processingMilliseconds < PROCESSING_WARNING_MILLISECONDS || tracker.processingWarnedIds.has(item.id))
		{
			continue;
		}
		tracker.processingWarnedIds.add(item.id);
		const warning = `test class ${describeQueueItem(item)} has been Processing for ${Math.round(processingMilliseconds / 60000)}m`;
		tracker.warnings.push(warning);
		deps.logger.warn(warning);
	}
}

/**
 * @description Reads one poll's worth of state: every `ApexTestQueueItem` of the run with its
 * status, and the run's own row status. Ids are queried rather than aggregated because the stall
 * check needs to know that the *same* classes are still waiting, not merely how many are. The class
 * name rides along so warnings and refusals can name the class, not the queue row.
 *
 * @param {string} runId
 * @param {Object} options
 * @param {Object} deps
 * @return {{queueItems: Array<Object>, runRowStatus: string|null}}
 */
function readTestRunPollState(runId, options, deps)
{
	const escaped = String(runId).replace(/'/g, "\\'");
	const queueItems = queryToolingApi(`SELECT Id, Status, ApexClass.Name FROM ApexTestQueueItem WHERE ParentJobId = '${escaped}'`, options, deps);
	const runRows = queryToolingApi(`SELECT Status FROM ApexTestRunResult WHERE AsyncApexJobId = '${escaped}' LIMIT 1`, options, deps);
	return {queueItems, runRowStatus: (runRows[0] && runRows[0].Status) || null};
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
	const result = deps.runner('sf', [
		'data',
		'query',
		'-o',
		options.org,
		'--use-tooling-api',
		'-q',
		soql,
		'--json'
	], {inherit: false});
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
 * that `lib.parseApexCoverage` emits, keeping the uncovered line numbers from
 * the row's `Coverage` field when the row carries it (an exemption is applied
 * only to a line listed there).
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
		classes[name] = lib.withUncoveredLineNumbers({percentage, coveredLines: covered, uncoveredLines: uncovered}, row.Coverage?.uncoveredLines);
	}
	return {classes};
}

/**
 * @description Queries the `ApexTestRunResult` row for a run: the one whose `AsyncApexJobId` is
 * `runId` when given, otherwise the newest. `testsPassed` keeps its original meaning (no failed
 * methods; no row reads as passed) because `--full` relies on it; the other fields let
 * `baselineRunVerdict` apply the stricter rule `--fix-baseline` needs.
 *
 * @param {Object} options
 * @param {Object} deps
 * @param {string|null} [runId] The run to report on; omit for the newest run.
 * @return {{runFound: boolean, runId: string|null, status: string|null, methodsEnqueued: number,
 *     methodsCompleted: number, methodsFailed: number, testsPassed: boolean,
 *     testFailures: Array<Object>, wallClockSeconds: number}}
 */
function queryLatestTestRunStatus(options, deps, runId)
{
	const scope = runId ? `WHERE AsyncApexJobId = '${runId}' ` : '';
	const soql = `SELECT AsyncApexJobId, Status, MethodsEnqueued, MethodsCompleted, MethodsFailed, TestTime `
		+ `FROM ApexTestRunResult ${scope}ORDER BY StartTime DESC LIMIT 1`;
	const rows = queryToolingApi(soql, options, deps);
	const latest = rows[0];
	if(!latest)
	{
		return {
			runFound: false, runId: runId || null, status: null, methodsEnqueued: 0, methodsCompleted: 0, methodsFailed: 0, testsPassed: true, testFailures: [], wallClockSeconds: 0
		};
	}
	const failed = Number(latest.MethodsFailed) || 0;
	const testTimeMs = Number(latest.TestTime) || 0;
	const failures = failed > 0 ? new Array(failed).fill({Outcome: 'Fail'}) : [];
	return {
		runFound: true,
		runId: latest.AsyncApexJobId || runId || null,
		status: latest.Status || null,
		methodsEnqueued: Number(latest.MethodsEnqueued) || 0,
		methodsCompleted: Number(latest.MethodsCompleted) || 0,
		methodsFailed: failed,
		testsPassed: failed === 0,
		testFailures: failures,
		wallClockSeconds: testTimeMs / 1000
	};
}

/**
 * @description Decides whether a test run is one a baseline may be minted from. Every gate is
 * decided from evidence of what the run actually did: the run row exists and reads `Completed`,
 * every `ApexTestQueueItem` of the run reads `Completed` (a `Failed` item means the class never
 * executed, an `Aborted` one that the run was cancelled, an in-flight one that it is not over),
 * the run produced at least one `ApexTestResult`, and every outcome is `Pass` — `Skip` and
 * `CompileFail` are not passes. With `--run-tests` the run must be the one just executed, never
 * whichever run is newest.
 *
 * `MethodsCompleted` and `MethodsFailed` are reported and never gated on: the completed counter
 * under-reports on runs that are genuinely finished (measured 4,106 of 4,369 enqueued on an
 * all-`Pass` run), and a failing method always appears as a non-`Pass` outcome, which is the gate
 * that refuses it. Nor is any count compared with `MethodsEnqueued` in the other direction: the same
 * clean run produced 4,408 results against 4,369 enqueued methods.
 *
 * @param {{testRun: Object, executedRunId: string|null}} coverage The apex coverage result from runFullApex.
 * @param {Object} options
 * @return {{green: boolean, reason: string|null}}
 */
function baselineRunVerdict(coverage, options)
{
	const testRun = coverage.testRun || {};
	if(options.runTests && !coverage.executedRunId)
	{
		return {green: false, reason: 'the RunLocalTests run id could not be read from test-run-id.txt, so its outcome cannot be verified'};
	}
	if(!testRun.runFound)
	{
		return {green: false, reason: `no ApexTestRunResult row exists for ${testRun.runId ? `run ${testRun.runId}` : 'any run'}`};
	}
	if(testRun.status !== 'Completed')
	{
		return {green: false, reason: `the run's status is ${testRun.status || 'unknown'}, not Completed`};
	}
	const queueItems = testRun.queueItems || [];
	const unfinished = queueItems.filter(item => item.Status !== 'Completed');
	if(unfinished.length > 0)
	{
		return {
			green: false,
			reason: `${unfinished.length} of ${queueItems.length} test queue item(s) did not complete: ${describeUnfinishedQueueItems(unfinished)}`
		};
	}
	const resultTally = testRun.resultTally || {};
	const outcomes = Object.entries(resultTally);
	const resultCount = outcomes.reduce((total, [, count]) => total + count, 0);
	if(resultCount === 0)
	{
		return {green: false, reason: 'the run produced no ApexTestResult rows, so nothing about it is proven'};
	}
	const nonPass = outcomes.filter(([outcome]) => outcome !== 'Pass');
	if(nonPass.length > 0)
	{
		const nonPassCount = nonPass.reduce((total, [, count]) => total + count, 0);
		const detail = nonPass.map(([outcome, count]) => `${count} ${outcome}`).join(', ');
		return {green: false, reason: `${nonPassCount} of ${resultCount} test result(s) did not pass: ${detail}`};
	}
	return {
		green: true,
		reason: `Completed, all ${queueItems.length} test queue item(s) Completed, all ${resultCount} test result(s) Pass; the platform counter `
			+ `reported ${testRun.methodsCompleted}/${testRun.methodsEnqueued} methods completed, which is informational only and gates nothing`
	};
}

/**
 * @description Names a queue item the way a person looks for it: by its test class. The id is the
 * fallback for a row the query could not join to a class, so no message is ever blank.
 *
 * @param {{className?: string|null, ApexClass?: {Name?: string}|null, id?: string, Id?: string}} item
 * @return {string}
 */
function describeQueueItem(item)
{
	const className = item.className || (item.ApexClass && item.ApexClass.Name);
	return className || item.id || item.Id;
}

/**
 * @description Renders the queue items that kept a run from being verified, each named by its test
 * class and carrying the `ExtendedStatus` the platform recorded for it — that is where a compile
 * error or a cancellation says what went wrong. Long lists are trimmed to `QUEUE_ITEM_REASON_LIMIT`
 * with the remainder counted, so the reason stays one readable line.
 *
 * @param {Array<{Id: string, Status: string, ExtendedStatus: string|null, ApexClass: {Name: string}|null}>} items
 * @return {string}
 */
function describeUnfinishedQueueItems(items)
{
	const listed = items
	.slice(0, QUEUE_ITEM_REASON_LIMIT)
	.map(item => `${describeQueueItem(item)} ${item.Status}${item.ExtendedStatus ? ` (${item.ExtendedStatus})` : ''}`)
	.join('; ');
	return items.length > QUEUE_ITEM_REASON_LIMIT ? `${listed}; and ${items.length - QUEUE_ITEM_REASON_LIMIT} more` : listed;
}

/**
 * @description Shells out to `sf project deploy start` for the given classes
 * and the test suites that cover them.
 *
 * @param {Array<string>} classes
 * @param {Object} options
 * @param {Object} deps
 * @return {void}
 */
function deployApexClasses(classes, options, deps)
{
	const metadata = [...new Set(classes.flatMap(name => [
		`ApexClass:${name}`,
		...testSuitesFor([name]).map(suite => `ApexClass:${suite}`)
	]))];
	deps.logger.info(`deploying: ${metadata.join(', ')}`);
	const args = [
		'project',
		'deploy',
		'start',
		'-o',
		options.org
	];
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
	deps.logger.info(`running apex tests: ${testClasses.join(', ')}`);
	deps.runner('sf', apexTestRunArguments(testClasses, options, outputDir), {inherit: true});
	return readApexResultFile(outputDir, deps);
}

/**
 * @description The `sf apex run test` arguments for the given test classes: with coverage, a JSON result format,
 * the `--wait` budget (15 minutes unless `--wait` says otherwise) and the output folder the result file is read from.
 *
 * @param {Array<string>} testClasses
 * @param {Object} options
 * @param {string} outputDir
 * @return {Array<string>}
 */
function apexTestRunArguments(testClasses, options, outputDir)
{
	const waitMinutes = options.waitMinutes || 15;
	const args = [
		'apex',
		'run',
		'test',
		'-o',
		options.org,
		'--code-coverage',
		'--result-format',
		'json',
		'--wait',
		String(waitMinutes),
		'--output-dir',
		outputDir
	];
	for(const name of testClasses)
	{
		args.push('-t', name);
	}
	return args;
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
		const match = entries.find(
				name => name.startsWith('test-result-') && name.endsWith('.json') && !name.endsWith('-codecoverage.json') && !name.endsWith('-junit.json') && !name.endsWith(
						'-tap.json'));
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
	return path.join(os.tmpdir(), `kern-apex-${deps.now()}`);
}

// ─────────────────────────────────────────────────────────────────────────────
// LWC measurement
// ─────────────────────────────────────────────────────────────────────────────

/**
 * @description Measures the components the caller named. The run itself is the
 * same whole-suite capture `--full` makes (`runFullLwc`), and only the summary
 * is narrowed afterwards, for two reasons. Scoping the jest run to a component
 * folder is not possible through the `test:unit:coverage` npm script at all —
 * sfdx-lwc-jest drops the jest flags placed after npm's `--`, so the run falls
 * back to the base config, whose `collectCoverageFrom` empty-instrumentation
 * pass silently drops every component whose top-level imports do not resolve
 * standalone, and the gate then reports no coverage data for a component whose
 * tests just passed. And a scoped run would not be comparable with the
 * committed baseline even if it worked, because the baseline is minted from
 * the whole suite: a child component covered by its parent's suite reads low
 * on its own tests. The whole suite takes seconds.
 *
 * @param {Array<string>} components
 * @param {Object} deps
 * @return {Object}
 */
function measureLwc(components, deps)
{
	deps.logger.info(`measuring lwc coverage for components: ${components.join(', ')}`);
	return filterToNamedComponents(runFullLwc(deps), components);
}

/**
 * @description Runs the LWC jest suite with coverage output using the dedicated
 * `LWC_COVERAGE_CONFIG`, then filters the summary down to LWC `.js` source.
 * Every mode captures through here — `--full`, `--fix-baseline`, and the
 * targeted `--lwc` path via `measureLwc` — so every figure the gate prints is
 * comparable with the committed baseline. Jest is invoked directly (not via the
 * `test:unit:coverage` npm script) because that script routes through
 * sfdx-lwc-jest, which silently drops CLI overrides — the dedicated config is
 * the only reliable way to scope `testMatch` and drop `collectCoverageFrom`.
 * The summary carries jest's own verdict too, `testsPassed` and
 * `jestExitStatus`, because a red component suite still writes coverage and
 * every mode must fail on it rather than read the figures as a pass.
 *
 * @param {Object} deps
 * @return {{files: Object<string, Object>, testsPassed: boolean, jestExitStatus: number}}
 */
function runFullLwc(deps)
{
	const args = [
		'jest',
		'--config',
		LWC_COVERAGE_CONFIG,
		'--coverage',
		'--coverageReporters=json'
	];
	deps.logger.info('running lwc jest suite (force-app/main/default/lwc) with coverage…');
	const result = deps.runner('npx', args, {inherit: true});
	const jestExitStatus = result && typeof result.status === 'number' ? result.status : EXIT.RUNTIME;
	return {...filterToLwcSource(loadJestSummary(deps)), testsPassed: jestExitStatus === 0, jestExitStatus};
}

/**
 * @description Keeps only LWC component `.js` source: entries under
 * `LWC_SOURCE_PREFIX` that end in `.js` and are not test files. This drops the
 * compiled templates (`.html`) and styles (`.css.compiled`) jest reports, plus
 * any non-LWC node file, so the baseline holds only files the 95% LWC floor
 * should apply to.
 *
 * @param {{files: Object<string, Object>}} summary
 * @return {{files: Object<string, Object>}}
 */
function filterToLwcSource(summary)
{
	const files = {};
	for(const [key, value] of Object.entries((summary && summary.files) || {}))
	{
		if(key.startsWith(LWC_SOURCE_PREFIX) && key.endsWith('.js') && !key.includes('/__tests__/'))
		{
			files[key] = value;
		}
	}
	return {...summary, files};
}

/**
 * @description Narrows an LWC summary to the files that belong to the named
 * component folders, so a targeted run reports on what the caller asked about
 * and nothing else. The whole-suite capture it starts from already holds every
 * component, so a name that matches nothing simply contributes no files and
 * the evaluation raises its own "no coverage data" violation.
 *
 * @param {{files: Object<string, Object>}} summary
 * @param {Array<string>} components
 * @return {{files: Object<string, Object>}}
 */
function filterToNamedComponents(summary, components)
{
	const files = {};
	for(const component of components)
	{
		for(const match of lib.findLwcFilesForComponent(summary, component))
		{
			files[match.filePath] = match.coverage;
		}
	}
	return {...summary, files};
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
 * @description Walks the named apex classes, reads each `.cls` file, lists the
 * line each valid `// kern-coverage-exempt:` comment marks, and fails hard on
 * invalid comments (short reason, blocklist hit, empty reason). A comment with
 * no code line below it marks nothing.
 *
 * @param {Array<string>} classes
 * @param {Object} deps
 * @return {Object<string, Array<number>>} `{className: [marked line number]}` for every class whose file exists.
 */
function gatherExemptLineNumbers(classes, deps)
{
	const markedLines = {};
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
		const lines = [];
		for(const comment of comments)
		{
			if(comment.reasonValid)
			{
				lines.push(comment.markedLineNumbers.length > 1 ? comment.markedLineNumbers : comment.targetLineNumber);
			}
			else
			{
				failures.push(`${className}.cls:${comment.lineNumber} kern-coverage-exempt failed policy (${comment.failures.join(', ')}): "${comment.reason}"`);
			}
		}
		markedLines[className] = lines.filter(line => line !== null);
	}
	if(failures.length > 0)
	{
		const error = new Error(`invalid kern-coverage-exempt comments:\n${failures.join('\n')}`);
		error.code = 'EXEMPT_POLICY_VIOLATION';
		throw error;
	}
	return markedLines;
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
		'  --lwc <list>      Measure named lwc component folders (runs the whole component suite).',
		'  --full            Walk baseline; fail on any regression.',
		'  --fix-baseline    Rebuild scripts/coverage-baseline.json from a full run.',
		'',
		'FLAGS:',
		'  --skip-deploy     Do not deploy before apex test (assume deployed).',
		'  --run-tests       Start RunLocalTests detached, wait for its queue to drain, then query coverage;',
		'                    blocks the gate when the run cannot be verified (slow).',
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
	testSuitesFor,
	primaryTestSuiteFor,
	PRIMARY_TEST_SUITE_OVERRIDES,
	deployApexClasses,
	executeApexTests,
	readApexResultFile,
	resolveApexResultFile,
	queryToolingApi,
	queryLatestTestRunStatus,
	baselineRunVerdict,
	normaliseAggregateRows,
	normaliseResultTallyRows,
	withRunVerificationInputs,
	readTestRunId,
	startDetachedTestRun,
	pollTestRunUntilTerminal,
	loadJestSummary,
	gatherExemptLineNumbers,
	listAllApexSourceClasses,
	findTestSetupClasses,
	listBaselineComponents,
	readBaselineFromDeps,
	buildSubprocessEnv,
	printHelp,
	DEFAULT_ORG,
	BASELINE_RELATIVE_PATH,
	CLASSES_RELATIVE_PATH,
	JEST_COVERAGE_SUMMARY_PATH,
	LWC_COVERAGE_CONFIG,
	EXIT
};

/* istanbul ignore next -- CLI bootstrap; covered by real invocation, not unit tests */
if(require.main === module)
{
	const code = main(process.argv.slice(2));
	process.exit(code);
}
