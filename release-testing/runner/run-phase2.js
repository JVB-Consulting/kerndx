// SPDX-License-Identifier: BUSL-1.1
const {exec, execSync} = require('child_process');
const path = require('path');
const fs = require('fs');
const {getSubscriberOrgAlias} = require('./subscriber-config');
const {isNamedOrgNotFoundError, NamedOrgNotFoundError} = require('./cmdt-deployer');
const {RECORDED_RESULTS_PATH, ReleaseTargetError, assertReleaseTarget} = require('./release-target');
const {namespacePrefix} = require('../e2e/helpers/sf-namespace');

const ORG_ALIAS = getSubscriberOrgAlias();

// Pre-flight sf org display so we fail fast with a clear message if
// SF_SUBSCRIBER_ORG_ALIAS is set but does not match any authenticated org.
// Without this, the first CMDT deploy raises an unhelpful execSync stack
// trace ~10 seconds in.
function preflightOrgAvailable()
{
	try
	{
		execSync(`sf org display -o ${ORG_ALIAS} --json`, {
			encoding: 'utf8', timeout: 30_000, stdio: [
				'pipe',
				'pipe',
				'pipe'
			]
		});
	}
	catch(err)
	{
		const combined = `${err.stderr || ''}\n${err.stdout || ''}\n${err.message || ''}`;
		if(isNamedOrgNotFoundError(combined))
		{
			throw new NamedOrgNotFoundError(ORG_ALIAS, (err.stderr || err.message || '').trim());
		}
		// Surface other failures (network, expired token, etc.) verbatim.
		throw err;
	}
}

// Every script of this phase is written against the installed package, its first act is a deploy into the org, and
// its last is a write into the record of the release-testing cycle. An org without the package is turned away
// here, before anything is run in it, deployed to it or written down about it.
function preflightPackageInstalled()
{
	assertReleaseTarget(ORG_ALIAS, namespacePrefix);
}

const SCRIPTS_DIR = path.join(__dirname, '..', 'scripts');

// Section 79's stale-probe seed writes a back-dated CreatedDate, which an org accepts only
// after the RUNBOOK Phase 1.4 audit-fields enablement; without it the seed fails compile
// deep into the run (the 2026-07-26 cycle lost a section attempt to exactly this). This
// probe turns that gap into a fail-fast at Step 0b with the remediation attached.
async function preflightAuditBackdating()
{
	const result = await runScript(path.join(SCRIPTS_DIR, 'preflight-audit-backdating.apex'));
	if(result.fail > 0 || result.pass === 0)
	{
		const probeLines = (result.raw || '').split('\n').filter(l => l.includes('USER_DEBUG')).join('\n');
		const probeOutput = probeLines || '  (no USER_DEBUG output — likely a compile or auth failure; see raw runner output)';
		throw new Error('Audit-field back-dating is not enabled on this org: Sections 79 and 79c (and Phase-3 part10) will fail.\n'
				+ '  Remediation (RUNBOOK Phase 1.4 — two separate deploys IN THIS ORDER, then the permission set):\n'
				+ '    sf project deploy start --metadata-dir release-testing/e2e/fixtures/audit-fields/step1-security-settings/metadata -o <org>\n'
				+ '    sf project deploy start --metadata-dir release-testing/e2e/fixtures/audit-fields/step2-audit-permset/metadata -o <org>\n'
				+ '    sf org assign permset -o <org> -n KernE2EAuditFieldAccess\n'
				+ `  Probe output:\n${probeOutput}`);
	}
}

const MAX_CONCURRENT = 5;

// How long a launch + verify section waits for the work the platform does on its own once the launch script has
// returned: queueable hops, platform-event delivery and change-event delivery all land inside this window.
const BACKGROUND_WORK_WAIT_MILLISECONDS = 30_000;

// Section 79 schedules its sweep on the next minute boundary through the real scheduler, so the wait has to cover
// the boundary and the sweep that follows it.
const SCHEDULED_SWEEP_WAIT_MILLISECONDS = 100_000;

// Section 75c starts two batch jobs over 290 rows; both jobs and the log events they publish have to finish before
// 75d reads them, which takes longer than the 30 seconds a queueable needs.
const BATCH_JOBS_WAIT_MILLISECONDS = 60_000;

// How much of a scanner failure is kept in the recorded note — enough to recognise the failure, short enough to read.
const SCANNER_NOTE_MAXIMUM_LENGTH = 120;

// The two ESLint scans of the runbook: 2.3d over the scanner's LWC fixtures, and 2.3e over the framework's own components.
const REPOSITORY_ROOT = path.join(__dirname, '..', '..');
const ESLINT_FIXTURES_DIRECTORY = path.join(REPOSITORY_ROOT, 'release-testing', 'scanner', 'lwc');
const FRAMEWORK_COMPONENTS_DIRECTORY = path.join(REPOSITORY_ROOT, 'force-app', 'main', 'default', 'lwc');
const COMPONENT_BUILDER_RULE = 'kerndx/use-component-builder';
const ESLINT_FIXTURES_COMMAND = 'npx eslint "**/*.js" --format json';
const FRAMEWORK_COMPONENTS_COMMAND = `npx eslint --rule "${COMPONENT_BUILDER_RULE}: error" "**/*.js" --ignore-pattern "**/*.test.js" --format json`;
const ESLINT_TIMEOUT_MILLISECONDS = 180_000;
const ESLINT_OUTPUT_MAXIMUM_BYTES = 64 * 1024 * 1024;

// Waits for work that happens outside this process. Sections stub this wait in their unit tests so it fires at once.
function pause(milliseconds)
{
	return new Promise(resolve => setTimeout(resolve, milliseconds));
}

const INDEPENDENT_SCRIPTS = [
	{section: 1, file: 'section-1-trigger-lifecycle.apex', expected: 6},
	{section: 2, file: 'section-2-trigger-bypass.apex', expected: 7},
	{section: 4, file: 'section-4-validation-lifecycle.apex', expected: 7},
	{section: 5, file: 'section-5-validation-bypass.apex', expected: 8},
	{section: 6, file: 'section-6-complex-formulas.apex', expected: 7},
	{section: 7, file: 'section-7-outbound-api.apex', expected: 4},
	{section: 8, file: 'section-8-api-feature-flags.apex', expected: 5},
	{section: 9, file: 'section-9-cross-framework.apex', expected: 7},
	{section: 10, file: 'section-10-shadow-mode.apex', expected: 5},
	{section: 12, file: 'section-12-after-triggers.apex', expected: 7},
	{section: 13, file: 'section-13-inbound-api.apex', expected: 6},
	{section: 14, file: 'section-14-dml-builder.apex', expected: 7},
	{section: 15, file: 'section-15-qry-builder.apex', expected: 13},
	{section: 16, file: 'section-16-log-builder.apex', expected: 10},
	{section: 17, file: 'section-17-flow-invocables.apex', expected: 8},
	{section: 19, file: 'section-19-lwc-logger-persistence.apex', expected: 6},
	{section: 20, file: 'section-20-flow-logger.apex', expected: 7},
	{section: 21, file: 'section-21-scheduler.apex', expected: 8},
	{section: 23, file: 'section-23-trigger-action-ordering.apex', expected: 4},
	{section: 24, file: 'section-24-delegation-overrides.apex', expected: 5},
	{section: 25, file: 'section-25-scheduler-timezone.apex', expected: 4},
	{section: 26, file: 'section-26-log-correlation.apex', expected: 7},
	{section: 28, file: 'section-28-util-cache.apex', expected: 7},
	{section: 29, file: 'section-29-log-scope.apex', expected: 5},
	{section: 30, file: 'section-30-resilience-strategies.apex', expected: 11},
	{section: 36, file: 'section-36-masking-applicable-field-types.apex', expected: 4},
	{section: 37, file: 'section-37-masking-min-input-length.apex', expected: 3},
	{section: 38, file: 'section-38-masking-transactionid-preservation.apex', expected: 3},
	{section: 39, file: 'section-39-masking-type-filter-warn.apex', expected: 1},
	{section: 41, file: 'section-41-flow-action-subscriber.apex', expected: 6},
	{section: 44, file: 'section-44-flow-action-upgrade.apex', expected: 3},
	{section: 52, file: 'section-52-edge-dml-builder.apex', expected: 8},
	{section: 53, file: 'section-53-edge-qry-builder.apex', expected: 10},
	{section: 54, file: 'section-54-edge-inbound-api.apex', expected: 4},
	{section: 57, file: 'section-57-edge-cache-ttl.apex', expected: 5},
	{section: 58, file: 'section-58-edge-logger.apex', expected: 7},
	{section: 59, file: 'section-59-edge-scheduler.apex', expected: 4},
	{section: 61, file: 'section-61-edge-masking-rollback.apex', expected: 5},
	{section: 62, file: 'section-62-edge-type-resolver.apex', expected: 4},
	{section: 64, file: 'section-64-edge-asyncjob-launcher.apex', expected: 6},
	{section: 85, file: 'section-85-sharing-defaults.apex', expected: 1}
];

// Active only while runOrchestratedSection drives a section function: every runScript
// call appends its raw result here so a section-level FAIL can dump the output of all
// sub-scripts (fixture halves, launch + verify) — score aggregation happens above
// runScript, so runScript alone cannot know an attempt failed.
let orchestratedCapture = null;

function runScript(scriptPath)
{
	return new Promise((resolve) =>
	{
		exec(`sf apex run -o ${ORG_ALIAS} -f "${scriptPath}" 2>&1`, {encoding: 'utf8', timeout: 120_000}, (error, stdout) =>
		{
			const output = stdout || '';
			const lines = output.split('\n').filter(l => l.includes('USER_DEBUG'));
			let pass = 0;
			let fail = 0;
			// Word-boundary match prevents substrings like BYPASS (introduced by the bypass-audit work
			// logs) from being miscounted as PASS. Same guard on FAIL for symmetry.
			const passPattern = /\bPASS\b/;
			const failPattern = /\bFAIL\b/;
			for(const line of lines)
			{
				if(passPattern.test(line))
				{
					pass++;
				}
				if(failPattern.test(line))
				{
					fail++;
				}
			}
			const result = {pass, fail, total: pass + fail, raw: output, error: error?.message};
			if(orchestratedCapture)
			{
				orchestratedCapture.push({scriptPath, result});
			}
			resolve(result);
		});
	});
}

const FAILURE_LOG_DIR = path.join(__dirname, '..', 'test-results', 'phase2-failures');

// Keep the raw sf output of a failed attempt on disk — the score alone (e.g. 0/4)
// cannot distinguish a genuine regression from a timeout or a row-lock collision.
function captureFailureOutput(section, result, isRetry)
{
	fs.mkdirSync(FAILURE_LOG_DIR, {recursive: true});
	const fileName = isRetry ? `section-${section}-retry.log` : `section-${section}.log`;
	const body = (result.error ? `error: ${result.error}\n\n` : '') + (result.raw || '');
	fs.writeFileSync(path.join(FAILURE_LOG_DIR, fileName), body, 'utf8');
}

// Orchestrated twin of captureFailureOutput: one log per section attempt, with a
// per-sub-script header so a launch-half timeout is distinguishable from a verify-half
// under-pass. `suffix` is '' (first attempt), '-retry', or '-aborted' (section threw).
function captureOrchestratedFailure(section, captures, suffix)
{
	fs.mkdirSync(FAILURE_LOG_DIR, {recursive: true});
	const body = captures.map(entry => `=== ${entry.scriptPath} ===\n` + (entry.result.error ? `error: ${entry.result.error}\n` : '') + (entry.result.raw || '')).join('\n\n');
	fs.writeFileSync(path.join(FAILURE_LOG_DIR, `section-${section}${suffix}.log`), body, 'utf8');
}

// Gives orchestrated sections the same contract runBatch gives independent scripts:
// raw output captured on failure, ONE serial re-run of the whole section (fixture
// deploys included — the proven manual isolated-rerun, automated), `retried: true` on
// the recorded result, and an uppercase PASS/FAIL summary line the battery monitor can
// grep (the sections' own progress lines are lowercase "n pass, n fail"). A section
// that THROWS (fixture deploy failure, section 77's clone-delete guard) is never
// retried: the partial output is captured to an -aborted log and the throw propagates,
// preserving each section's own abort semantics.
async function runOrchestratedSection(section, sectionFn)
{
	const key = `section-${section}`;
	let captures;

	async function attempt()
	{
		orchestratedCapture = [];
		try
		{
			return await sectionFn();
		}
		catch(error)
		{
			captureOrchestratedFailure(section, orchestratedCapture, '-aborted');
			throw error;
		}
		finally
		{
			captures = orchestratedCapture;
			orchestratedCapture = null;
		}
	}

	const outcome = await attempt();
	if(outcome[key].result === 'PASS')
	{
		console.log(`  Section ${section}: \x1b[32mPASS\x1b[0m (${outcome[key].score})`);
		return outcome;
	}

	captureOrchestratedFailure(section, captures, '');
	console.log(`  Section ${section}: retrying the full section serially after FAIL (${outcome[key].score})...`);

	const retryOutcome = await attempt();
	retryOutcome[key].retried = true;
	if(retryOutcome[key].result === 'FAIL')
	{
		captureOrchestratedFailure(section, captures, '-retry');
	}
	const status = retryOutcome[key].result === 'PASS' ? '\x1b[32mPASS\x1b[0m' : '\x1b[31mFAIL\x1b[0m';
	console.log(`  Section ${section} (retry): ${status} (${retryOutcome[key].score})`);
	return retryOutcome;
}

async function runBatch(scripts, concurrent)
{
	const results = {};
	const queue = [...scripts];
	const failedScripts = [];

	async function worker()
	{
		while(queue.length > 0)
		{
			const script = queue.shift();
			const scriptPath = path.join(SCRIPTS_DIR, script.file);
			console.log(`  Running section ${script.section}: ${script.file}`);
			const result = await runScript(scriptPath);
			const key = `section-${script.section}`;
			results[key] = {
				result: result.pass === script.expected && result.fail === 0 ? 'PASS' : 'FAIL', score: `${result.pass}/${script.expected}`
			};
			const status = results[key].result === 'PASS' ? '\x1b[32mPASS\x1b[0m' : '\x1b[31mFAIL\x1b[0m';
			console.log(`  Section ${script.section}: ${status} (${result.pass}/${script.expected})`);
			if(results[key].result === 'FAIL')
			{
				captureFailureOutput(script.section, result, false);
				failedScripts.push(script);
			}
		}
	}

	const workers = Array.from({length: concurrent}, () => worker());
	await Promise.all(workers);

	// Concurrency flakes (sections 54 and 65 both hit them) fail inside the parallel
	// worker pool but pass in isolation, so each failure gets ONE serial retry on the
	// drained org. A retried result carries `retried: true` — a flake that recovered
	// is still visible in the recorded run, and a persistent failure keeps both logs.
	for(const script of failedScripts)
	{
		const key = `section-${script.section}`;
		console.log(`  Section ${script.section}: retrying serially after concurrent-batch FAIL...`);
		const retry = await runScript(path.join(SCRIPTS_DIR, script.file));
		const passed = retry.pass === script.expected && retry.fail === 0;
		results[key] = {
			result: passed ? 'PASS' : 'FAIL', score: `${retry.pass}/${script.expected}`, retried: true
		};
		if(!passed)
		{
			captureFailureOutput(script.section, retry, true);
		}
		const status = passed ? '\x1b[32mPASS\x1b[0m' : '\x1b[31mFAIL\x1b[0m';
		console.log(`  Section ${script.section} (retry): ${status} (${retry.pass}/${script.expected})`);
	}

	return results;
}

async function runSection3()
{
	const {deployCmdtState} = require('./cmdt-deployer');
	const scriptPath = path.join(SCRIPTS_DIR, 'section-3-trigger-feature-flags.apex');
	const states = [
		'section3-state-a',
		'section3-state-b',
		'section3-state-c',
		'section3-state-d'
	];
	let totalPass = 0;
	const expected = 8;

	for(const state of states)
	{
		console.log(`  Section 3: deploying ${state}...`);
		await deployCmdtState(state);
		const result = await runScript(scriptPath);
		totalPass += result.pass;
		console.log(`  Section 3 (${state}): ${result.pass} assertions passed`);
	}

	console.log(`  Section 3: restoring baseline...`);
	await deployCmdtState('baseline');

	return {
		'section-3': {
			result: totalPass === expected ? 'PASS' : 'FAIL', score: `${totalPass}/${expected}`, notes: '4 CMDT states deployed and tested'
		}
	};
}

async function runSection11()
{
	const {deployCmdtState} = require('./cmdt-deployer');
	const scriptPath = path.join(SCRIPTS_DIR, 'section-11-execution-strategies.apex');
	let totalPass = 0;
	const expected = 8;

	console.log('  Section 11: deploying fail-fast state...');
	await deployCmdtState('section11-fail-fast');
	const failFastResult = await runScript(scriptPath);
	totalPass += failFastResult.pass;
	console.log(`  Section 11 (Fail Fast): ${failFastResult.pass} assertions passed`);

	console.log('  Section 11: deploying accumulate state...');
	await deployCmdtState('section11-accumulate');
	const accumulateResult = await runScript(scriptPath);
	totalPass += accumulateResult.pass;
	console.log(`  Section 11 (Accumulate): ${accumulateResult.pass} assertions passed`);

	return {
		'section-11': {
			result: totalPass === expected ? 'PASS' : 'FAIL', score: `${totalPass}/${expected}`, notes: 'Fail Fast and Accumulate verified'
		}
	};
}

// Sections 31, 55, 60 and 63 send their calls through API_EchoSubscriber with an answer registered through
// API_MockFactory. Outside a unit test a registered answer stands in for the callout only while the MockAllAPIs
// feature flag is on, so each runs inside a mock-all-apis-enabled window, restored to mock-all-apis-disabled
// before anything else runs. The log entries a section writes land after its transaction ends, so its cleanup
// script runs once the background wait has passed; it deletes them and proves by query that nothing is left.
const FAILURE_HANDLING_SECTION = 31;
const OUTBOUND_FAILURE_SECTION = 55;
const RESILIENCE_COMPOSITION_SECTION = 63;
const MOCK_REGEX_SECTION = 60;
const MOCKED_OUTBOUND_SECTIONS = {
	[FAILURE_HANDLING_SECTION]: {
		file: 'section-31-failure-handling', expected: 9, notes: 'Failure handling through registered answers (MockAllAPIs window), then the log cleanup'
	},
	[OUTBOUND_FAILURE_SECTION]: {
		file: 'section-55-edge-outbound-failure', expected: 10,
		notes: 'Outbound failure composition through registered answers (MockAllAPIs window), then the log cleanup'
	},
	[MOCK_REGEX_SECTION]: {
		file: 'section-60-edge-mock-regex', expected: 5,
		notes: 'Mock regex edge cases through registered and metadata answers (MockAllAPIs window), then the issue cleanup'
	},
	[RESILIENCE_COMPOSITION_SECTION]: {
		file: 'section-63-edge-resilience-comp', expected: 7,
		notes: 'Breaker + retry composition, 63d through a registered answer (MockAllAPIs window), then the log cleanup'
	}
};

// Turns MockAllAPIs back off after a section. Left on, it answers every outbound call in the org with a canned
// response, so a failed restore says which fixture to deploy by hand before it fails the section.
async function restoreMockAllApisOff(section, deployCmdtState)
{
	console.log(`  Section ${section}: restoring mock-all-apis-disabled...`);
	try
	{
		await deployCmdtState('mock-all-apis-disabled');
	}
	catch(restoreFailure)
	{
		console.error(`  Section ${section}: MockAllAPIs could not be turned off (${restoreFailure.message}); deploy the `
				+ 'cmdt-states/mock-all-apis-disabled fixture by hand before anything else runs on this org.');
		throw restoreFailure;
	}
}

async function runMockedOutboundSection(section)
{
	const {deployCmdtState} = require('./cmdt-deployer');
	const {file, expected, notes} = MOCKED_OUTBOUND_SECTIONS[section];
	const cleanupExpected = 1;

	console.log(`  Section ${section}: deploying mock-all-apis-enabled...`);
	await deployCmdtState('mock-all-apis-enabled');
	let result;
	try
	{
		result = await runScript(path.join(SCRIPTS_DIR, `${file}.apex`));
	}
	finally
	{
		await restoreMockAllApisOff(section, deployCmdtState);
	}
	console.log(`  Section ${section}: ${result.pass} pass, ${result.fail} fail; waiting 30s for its log entries...`);
	await pause(BACKGROUND_WORK_WAIT_MILLISECONDS);

	const cleanupResult = await runScript(path.join(SCRIPTS_DIR, `${file}-cleanup.apex`));
	console.log(`  Section ${section} (cleanup): ${cleanupResult.pass} pass, ${cleanupResult.fail} fail`);

	const totalPass = result.pass + cleanupResult.pass;
	const totalExpected = expected + cleanupExpected;
	return {
		[`section-${section}`]: {
			result: totalPass === totalExpected && result.fail === 0 && cleanupResult.fail === 0 ? 'PASS' : 'FAIL',
			score: `${totalPass}/${totalExpected}`,
			notes
		}
	};
}

function runSection31()
{
	return runMockedOutboundSection(FAILURE_HANDLING_SECTION);
}

function runSection55()
{
	return runMockedOutboundSection(OUTBOUND_FAILURE_SECTION);
}

function runSection63()
{
	return runMockedOutboundSection(RESILIENCE_COMPOSITION_SECTION);
}

function runSection60()
{
	return runMockedOutboundSection(MOCK_REGEX_SECTION);
}

async function runSection27()
{
	const {deployCmdtState} = require('./cmdt-deployer');
	const scriptPath = path.join(SCRIPTS_DIR, 'section-27-mock-selection.apex');
	const expected = 8;

	console.log('  Section 27: deploying mock-enabled state...');
	await deployCmdtState('section27-mock-enabled');
	const result = await runScript(scriptPath);
	console.log(`  Section 27: ${result.pass} pass, ${result.fail} fail`);

	console.log('  Section 27: restoring mock-disabled state...');
	await deployCmdtState('section27-mock-disabled');

	return {
		'section-27': {
			result: result.pass === expected && result.fail === 0 ? 'PASS' : 'FAIL', score: `${result.pass}/${expected}`, notes: 'Mock enabled → test → mock disabled'
		}
	};
}

async function runSection22()
{
	const scripts = [
		{file: 'section-22-setup.apex', label: 'setup'},
		{file: 'section-22-advanced-strategies.apex', label: 'test'},
		{file: 'section-22-cleanup.apex', label: 'cleanup'}
	];
	const expected = 8;
	let totalPass = 0;
	let totalFail = 0;

	for(const script of scripts)
	{
		const scriptPath = path.join(SCRIPTS_DIR, script.file);
		console.log(`  Section 22 (${script.label}): running...`);
		const result = await runScript(scriptPath);
		totalPass += result.pass;
		totalFail += result.fail;
		console.log(`  Section 22 (${script.label}): done (${result.pass} pass, ${result.fail} fail)`);
	}

	return {
		'section-22': {
			result: totalPass === expected && totalFail === 0 ? 'PASS' : 'FAIL', score: `${totalPass}/${expected}`, notes: 'setup + test + cleanup'
		}
	};
}

async function runTestClasses()
{
	console.log('\n  Running test classes (RunLocalTests)...');
	try
	{
		const output = execSync(`sf apex run test -o ${ORG_ALIAS} --test-level RunLocalTests --result-format json --code-coverage --json --wait 15`,
				{encoding: 'utf8', timeout: 600_000});
		const result = JSON.parse(output);
		const {outcome, testsRan, failing, testRunCoverage} = result.result?.summary || {};
		return {
			result: outcome === 'Passed' ? 'PASS' : 'FAIL', passed: testsRan || 0, failed: failing || 0, coverage: testRunCoverage || '0%'
		};
	}
	catch(error)
	{
		return {result: 'FAIL', error: error.message};
	}
}

// Code Analyzer writes a violationCounts summary; output without one carries the violations themselves.
function countScannerViolations(pmdData)
{
	if(pmdData.violationCounts)
	{
		return pmdData.violationCounts.total || 0;
	}
	return pmdData.violations?.length ?? 0;
}

// Runs one ESLint scan and returns its JSON report. ESLint ends with exit code 1 whenever it finds a problem, so a
// failed command that still printed a report is a scan that worked; a failure with no report is passed on.
function readEslintReport(command, directory)
{
	const options = {cwd: directory, encoding: 'utf8', timeout: ESLINT_TIMEOUT_MILLISECONDS, maxBuffer: ESLINT_OUTPUT_MAXIMUM_BYTES};
	let output;
	try
	{
		output = execSync(command, options);
	}
	catch(error)
	{
		if(!error.stdout)
		{
			throw error;
		}
		output = error.stdout;
	}
	return JSON.parse(output);
}

// Counts the problems in an ESLint report, or only the problems of one rule when a rule is named.
function countEslintProblems(report, ruleId)
{
	return report.flatMap(file => file.messages).filter(message => !ruleId || message.ruleId === ruleId).length;
}

// Records both ESLint counts. A scan that cannot report leaves its count empty and says why, never a false zero.
function runEslintScans()
{
	const eslintResult = {fixtureViolations: null, frameworkViolations: null, notes: ''};
	const failures = [];
	try
	{
		eslintResult.fixtureViolations = countEslintProblems(readEslintReport(ESLINT_FIXTURES_COMMAND, ESLINT_FIXTURES_DIRECTORY));
	}
	catch(error)
	{
		failures.push('Fixture scan failed: ' + (error.message || '').slice(0, SCANNER_NOTE_MAXIMUM_LENGTH));
	}
	try
	{
		const frameworkReport = readEslintReport(FRAMEWORK_COMPONENTS_COMMAND, FRAMEWORK_COMPONENTS_DIRECTORY);
		eslintResult.frameworkViolations = countEslintProblems(frameworkReport, COMPONENT_BUILDER_RULE);
	}
	catch(error)
	{
		failures.push('Framework scan failed: ' + (error.message || '').slice(0, SCANNER_NOTE_MAXIMUM_LENGTH));
	}
	eslintResult.notes = failures.join(' ');
	return eslintResult;
}

async function runScanner()
{
	console.log('\n  Running scanner...');
	const pmdResult = {violations: 0, notes: ''};

	const scannerOutputPath = path.join(__dirname, '..', 'results', 'scanner-violations.json');
	try
	{
		fs.rmSync(scannerOutputPath, {force: true});

		// Scanner fixture validation uses the FULL ruleset (code-analyzer-fixtures.yml
		// points to scanner/kerndx-pmd-ruleset.xml) — including the "use the framework
		// API instead of the platform primitive" rules that the framework-scoped
		// code-analyzer.yml deliberately excludes. Fixtures in release-testing/scanner/
		// classes/ contain deliberate violations of those framework-API rules.
		execSync('sf code-analyzer run --target release-testing/scanner/classes/ --rule-selector pmd:KernDXFrameworkCompliance'
				+ ' --config-file release-testing/scanner/code-analyzer-fixtures.yml'
				+ ` --output-file "${scannerOutputPath}" 2>&1`, {encoding: 'utf8', timeout: 120_000});

		if(fs.existsSync(scannerOutputPath))
		{
			const pmdData = JSON.parse(fs.readFileSync(scannerOutputPath, {encoding: 'utf8'}));
			pmdResult.violations = countScannerViolations(pmdData);
		}
		else
		{
			pmdResult.notes = 'Scanner output file not generated';
		}
	}
	catch(error)
	{
		pmdResult.notes = 'Scanner failed: ' + (error.message || '').slice(0, SCANNER_NOTE_MAXIMUM_LENGTH);
	}

	console.log('\n  Running ESLint scans...');
	return {scanner: pmdResult, eslint: runEslintScans()};
}

async function runSection35()
{
	const {deployCmdtState} = require('./cmdt-deployer');
	const defaultScript = path.join(SCRIPTS_DIR, 'section-35-secure-by-default.apex');
	const killSwitchScript = path.join(SCRIPTS_DIR, 'section-35-kill-switch.apex');
	const expectedDefault = 8;
	const expectedKillSwitch = 4;

	console.log('  Section 35: running secure-by-default assertions under shipped flag state...');
	const defaultResult = await runScript(defaultScript);
	console.log(`  Section 35 (default): ${defaultResult.pass} pass, ${defaultResult.fail} fail`);

	console.log('  Section 35: flipping flags off (kill-switch state)...');
	await deployCmdtState('section35-flags-disabled');

	const killSwitchResult = await runScript(killSwitchScript);
	console.log(`  Section 35 (kill-switch): ${killSwitchResult.pass} pass, ${killSwitchResult.fail} fail`);

	console.log('  Section 35: restoring flags-default state...');
	await deployCmdtState('section35-flags-default');

	const totalPass = defaultResult.pass + killSwitchResult.pass;
	const totalExpected = expectedDefault + expectedKillSwitch;

	return {
		'section-35': {
			result: totalPass === totalExpected && defaultResult.fail === 0 && killSwitchResult.fail === 0 ? 'PASS' : 'FAIL',
			score: `${totalPass}/${totalExpected}`,
			notes: `Default (flags on): ${defaultResult.pass}/${expectedDefault}, Kill-switch (flags off): ${killSwitchResult.pass}/${expectedKillSwitch}`
		}
	};
}

async function runSection34()
{
	const launchScript = path.join(SCRIPTS_DIR, 'section-34-async-chain.apex');
	const verifyScript = path.join(SCRIPTS_DIR, 'section-34b-async-chain-verify.apex');
	const expectedLaunch = 11;
	const expectedVerify = 9;

	console.log('  Section 34: launching chains...');
	const launchResult = await runScript(launchScript);
	console.log(`  Section 34 (launch): ${launchResult.pass} pass, ${launchResult.fail} fail`);

	console.log('  Section 34: waiting 30s for queueables to complete (includes handler isolation hops)...');
	await pause(BACKGROUND_WORK_WAIT_MILLISECONDS);

	console.log('  Section 34: verifying chain results...');
	const verifyResult = await runScript(verifyScript);
	console.log(`  Section 34 (verify): ${verifyResult.pass} pass, ${verifyResult.fail} fail`);

	const totalPass = launchResult.pass + verifyResult.pass;
	const totalExpected = expectedLaunch + expectedVerify;

	return {
		'section-34': {
			result: totalPass === totalExpected && launchResult.fail === 0 && verifyResult.fail === 0 ? 'PASS' : 'FAIL',
			score: `${totalPass}/${totalExpected}`,
			notes: `Launch: ${launchResult.pass}/${expectedLaunch}, Verify: ${verifyResult.pass}/${expectedVerify}`
		}
	};
}

async function runSection66()
{
	const launchScript = path.join(SCRIPTS_DIR, 'section-66-log-fingerprint.apex');
	const verifyScript = path.join(SCRIPTS_DIR, 'section-66b-log-fingerprint-verify.apex');
	const expectedLaunch = 2;
	const expectedVerify = 8;

	console.log('  Section 66: launching fingerprinted log entries via withFingerprint...');
	const launchResult = await runScript(launchScript);
	console.log(`  Section 66 (launch): ${launchResult.pass} pass, ${launchResult.fail} fail`);

	console.log('  Section 66: waiting 30s for LogEntryEvent__e delivery + TRG_PersistLogEntry persistence...');
	await pause(BACKGROUND_WORK_WAIT_MILLISECONDS);

	console.log('  Section 66: verifying detail/rollup flood-control shape...');
	const verifyResult = await runScript(verifyScript);
	console.log(`  Section 66 (verify): ${verifyResult.pass} pass, ${verifyResult.fail} fail`);

	const totalPass = launchResult.pass + verifyResult.pass;
	const totalExpected = expectedLaunch + expectedVerify;

	return {
		'section-66': {
			result: totalPass === totalExpected && launchResult.fail === 0 && verifyResult.fail === 0 ? 'PASS' : 'FAIL',
			score: `${totalPass}/${totalExpected}`,
			notes: `Launch: ${launchResult.pass}/${expectedLaunch}, Verify: ${verifyResult.pass}/${expectedVerify}`
					+ ' — subscriber withFingerprint -> detail/rollup grouping + OccurrenceCount'
		}
	};
}

async function runSection65()
{
	const launchScript = path.join(SCRIPTS_DIR, 'section-65-bypass-audit-framework-wide.apex');
	const verifyScript = path.join(SCRIPTS_DIR, 'section-65b-bypass-audit-verify.apex');
	const expectedLaunch = 2;
	const expectedVerify = 6;

	console.log('  Section 65: exercising the four global bypass surfaces (launch)...');
	const launchResult = await runScript(launchScript);
	console.log(`  Section 65 (launch): ${launchResult.pass} pass, ${launchResult.fail} fail`);

	console.log('  Section 65: waiting 30s for LogEntryEvent__e delivery + TRG_PersistLogEntry persistence...');
	await pause(BACKGROUND_WORK_WAIT_MILLISECONDS);

	console.log('  Section 65: verifying object-qualified bypass-audit targets + flood-control shape...');
	const verifyResult = await runScript(verifyScript);
	console.log(`  Section 65 (verify): ${verifyResult.pass} pass, ${verifyResult.fail} fail`);

	const totalPass = launchResult.pass + verifyResult.pass;
	const totalExpected = expectedLaunch + expectedVerify;

	return {
		'section-65': {
			result: totalPass === totalExpected && launchResult.fail === 0 && verifyResult.fail === 0 ? 'PASS' : 'FAIL',
			score: `${totalPass}/${totalExpected}`,
			notes: `Launch: ${launchResult.pass}/${expectedLaunch}, Verify: ${verifyResult.pass}/${expectedVerify}`
					+ ' — four bypass surfaces -> object-qualified query/DML audit targets + flood-control shape'
		}
	};
}

async function runSection42()
{
	const {deployCmdtState} = require('./cmdt-deployer');
	const scriptPath = path.join(SCRIPTS_DIR, 'section-42-flow-action-blockdml.apex');
	const expected = 1;

	console.log('  Section 42: deploying section-flow-blockdml-active...');
	await deployCmdtState('section-flow-blockdml-active');
	const result = await runScript(scriptPath);
	console.log(`  Section 42: ${result.pass} pass, ${result.fail} fail`);

	console.log('  Section 42: restoring section-flow-blockdml-default...');
	await deployCmdtState('section-flow-blockdml-default');

	return {
		'section-42': {
			result: result.pass === expected && result.fail === 0 ? 'PASS' : 'FAIL', score: `${result.pass}/${expected}`, notes: 'BlockDml active → test → default restored'
		}
	};
}

async function runSection43()
{
	const {deployCmdtState} = require('./cmdt-deployer');
	const scriptPath = path.join(SCRIPTS_DIR, 'section-43-flow-action-feature-flag.apex');
	const expected = 1;

	console.log('  Section 43: deploying section-flow-flag-disabled...');
	await deployCmdtState('section-flow-flag-disabled');
	const result = await runScript(scriptPath);
	console.log(`  Section 43: ${result.pass} pass, ${result.fail} fail`);

	console.log('  Section 43: restoring section-flow-flag-default...');
	await deployCmdtState('section-flow-flag-default');

	return {
		'section-43': {
			result: result.pass === expected && result.fail === 0 ? 'PASS' : 'FAIL', score: `${result.pass}/${expected}`, notes: 'Flag disabled → test → default restored'
		}
	};
}

async function runSection56()
{
	const launchScript = path.join(SCRIPTS_DIR, 'section-56-edge-async-chain.apex');
	const verifyScript = path.join(SCRIPTS_DIR, 'section-56b-edge-async-chain-verify.apex');
	const expectedLaunch = 4;
	const expectedVerify = 3;

	console.log('  Section 56: launching edge chains...');
	const launchResult = await runScript(launchScript);
	console.log(`  Section 56 (launch): ${launchResult.pass} pass, ${launchResult.fail} fail`);

	console.log('  Section 56: waiting 30s for queueables to complete...');
	await pause(BACKGROUND_WORK_WAIT_MILLISECONDS);

	console.log('  Section 56: verifying edge chain results...');
	const verifyResult = await runScript(verifyScript);
	console.log(`  Section 56 (verify): ${verifyResult.pass} pass, ${verifyResult.fail} fail`);

	const totalPass = launchResult.pass + verifyResult.pass;
	const totalExpected = expectedLaunch + expectedVerify;

	return {
		'section-56': {
			result: totalPass === totalExpected && launchResult.fail === 0 && verifyResult.fail === 0 ? 'PASS' : 'FAIL',
			score: `${totalPass}/${totalExpected}`,
			notes: `Launch: ${launchResult.pass}/${expectedLaunch}, Verify: ${verifyResult.pass}/${expectedVerify}`
		}
	};
}

async function runSection76()
{
	const {deployMetadataDir} = require('./cmdt-deployer');
	const bundlesDir = path.join(__dirname, '..', 'e2e', 'fixtures', 'masking-advisor-bundles');
	const baselineScript = path.join(SCRIPTS_DIR, 'section-76-masking-advisor-roundtrip.apex');
	const verifyCreatedScript = path.join(SCRIPTS_DIR, 'section-76b-masking-advisor-verify-created.apex');
	const verifyDisabledScript = path.join(SCRIPTS_DIR, 'section-76c-masking-advisor-verify-disabled.apex');
	const verifyReenabledScript = path.join(SCRIPTS_DIR, 'section-76d-masking-advisor-verify-reenabled.apex');

	// 3 baseline + 3 create + 3 disable + 2 re-enable + 3 cleanup re-verify
	const expected = 14;
	let totalPass = 0;
	let totalFail = 0;

	async function step(label, scriptPath)
	{
		console.log(`  Section 76 (${label}): running...`);
		const result = await runScript(scriptPath);
		totalPass += result.pass;
		totalFail += result.fail;
		console.log(`  Section 76 (${label}): ${result.pass} pass, ${result.fail} fail`);
	}

	await step('baseline', baselineScript);

	console.log('  Section 76: deploying create bundle (advisor-format, Export-modal deploy command)...');
	deployMetadataDir(path.join(bundlesDir, 'create'));
	await step('verify create', verifyCreatedScript);

	console.log('  Section 76: deploying disable bundle...');
	deployMetadataDir(path.join(bundlesDir, 'disable'));
	await step('verify disable', verifyDisabledScript);

	console.log('  Section 76: deploying re-enable bundle...');
	deployMetadataDir(path.join(bundlesDir, 'reenable'));
	await step('verify re-enable', verifyReenabledScript);

	console.log('  Section 76: cleanup — restoring disabled steady state...');
	deployMetadataDir(path.join(bundlesDir, 'disable'));
	await step('verify cleanup', verifyDisabledScript);

	return {
		'section-76': {
			result: totalPass === expected && totalFail === 0 ? 'PASS' : 'FAIL',
			score: `${totalPass}/${expected}`,
			notes: 'Advisor bundle round-trip: baseline → create → disable → re-enable → cleanup'
		}
	};
}

async function runSection67()
{
	const {deployCmdtState} = require('./cmdt-deployer');
	const scriptPath = path.join(SCRIPTS_DIR, 'section-67-post-trigger-actions.apex');
	const expected = 6;

	console.log('  Section 67: deploying postaction-enabled...');
	await deployCmdtState('postaction-enabled');
	const result = await runScript(scriptPath);
	console.log(`  Section 67: ${result.pass} pass, ${result.fail} fail`);

	console.log('  Section 67: restoring postaction-disabled...');
	await deployCmdtState('postaction-disabled');

	return {
		'section-67': {
			result: result.pass === expected && result.fail === 0 ? 'PASS' : 'FAIL',
			score: `${result.pass}/${expected}`,
			notes: 'Post-action core: ordering, dispatch-scope, touched types, object-scope filter, entry-criteria'
		}
	};
}

async function runSection68()
{
	const {deployCmdtState} = require('./cmdt-deployer');
	const flagOffScript = path.join(SCRIPTS_DIR, 'section-68-post-trigger-actions-flag-gate.apex');
	const flagOnScript = path.join(SCRIPTS_DIR, 'section-68b-post-trigger-actions-flag-gate.apex');
	const expected = 2;

	console.log('  Section 68: deploying postaction-disabled (flag off)...');
	await deployCmdtState('postaction-disabled');
	const flagOffResult = await runScript(flagOffScript);
	console.log(`  Section 68 (flag off): ${flagOffResult.pass} pass, ${flagOffResult.fail} fail`);

	console.log('  Section 68: deploying postaction-enabled (flag on)...');
	await deployCmdtState('postaction-enabled');
	const flagOnResult = await runScript(flagOnScript);
	console.log(`  Section 68 (flag on): ${flagOnResult.pass} pass, ${flagOnResult.fail} fail`);

	console.log('  Section 68: restoring postaction-disabled...');
	await deployCmdtState('postaction-disabled');

	const totalPass = flagOffResult.pass + flagOnResult.pass;
	return {
		'section-68': {
			result: totalPass === expected && flagOffResult.fail === 0 && flagOnResult.fail === 0 ? 'PASS' : 'FAIL',
			score: `${totalPass}/${expected}`,
			notes: 'Required-feature-flag gate: off (dormant) then on (fires)'
		}
	};
}

async function runSection69()
{
	const {deployCmdtState} = require('./cmdt-deployer');
	const scriptPath = path.join(SCRIPTS_DIR, 'section-69-post-trigger-actions-no-dml.apex');
	const expected = 2;

	console.log('  Section 69: deploying dml-active...');
	await deployCmdtState('dml-active');
	const result = await runScript(scriptPath);
	console.log(`  Section 69: ${result.pass} pass, ${result.fail} fail`);

	console.log('  Section 69: restoring postaction-disabled...');
	await deployCmdtState('postaction-disabled');

	return {
		'section-69': {
			result: result.pass === expected && result.fail === 0 ? 'PASS' : 'FAIL', score: `${result.pass}/${expected}`, notes: 'No-DML contract guard: exception text + rollback'
		}
	};
}

async function runSection70()
{
	const {deployCmdtState} = require('./cmdt-deployer');
	const logAndContinueScript = path.join(SCRIPTS_DIR, 'section-70-post-trigger-actions-failure-policy.apex');
	const blockDmlScript = path.join(SCRIPTS_DIR, 'section-70b-post-trigger-actions-failure-policy.apex');
	const expected = 4;

	console.log('  Section 70: deploying failing-logandcontinue...');
	await deployCmdtState('failing-logandcontinue');
	const logAndContinueResult = await runScript(logAndContinueScript);
	console.log(`  Section 70 (LogAndContinue): ${logAndContinueResult.pass} pass, ${logAndContinueResult.fail} fail`);

	console.log('  Section 70: deploying failing-blockdml...');
	await deployCmdtState('failing-blockdml');
	const blockDmlResult = await runScript(blockDmlScript);
	console.log(`  Section 70 (BlockDml): ${blockDmlResult.pass} pass, ${blockDmlResult.fail} fail`);

	console.log('  Section 70: restoring postaction-disabled...');
	await deployCmdtState('postaction-disabled');

	const totalPass = logAndContinueResult.pass + blockDmlResult.pass;
	return {
		'section-70': {
			result: totalPass === expected && logAndContinueResult.fail === 0 && blockDmlResult.fail === 0 ? 'PASS' : 'FAIL',
			score: `${totalPass}/${expected}`,
			notes: 'FailureAction policy: LogAndContinue (commit) vs BlockDml (rollback)'
		}
	};
}

async function runSection71()
{
	const {deployCmdtState} = require('./cmdt-deployer');
	const launchScript = path.join(SCRIPTS_DIR, 'section-71-cdc-header-recorder.apex');
	const verifyScript = path.join(SCRIPTS_DIR, 'section-71b-cdc-header-verify.apex');
	const expected = 3;

	console.log('  Section 71: deploying cdc-header-enabled (recorder flag on)...');
	await deployCmdtState('cdc-header-enabled');

	console.log('  Section 71: launching CDC probe inserts...');
	const launchResult = await runScript(launchScript);
	console.log(`  Section 71 (launch): ${launchResult.pass} pass, ${launchResult.fail} fail`);

	console.log('  Section 71: waiting 30s for change-event delivery...');
	await pause(BACKGROUND_WORK_WAIT_MILLISECONDS);

	console.log('  Section 71: verifying delivered markers...');
	const verifyResult = await runScript(verifyScript);
	console.log(`  Section 71 (verify): ${verifyResult.pass} pass, ${verifyResult.fail} fail`);

	console.log('  Section 71: restoring cdc-header-disabled...');
	await deployCmdtState('cdc-header-disabled');

	const totalPass = launchResult.pass + verifyResult.pass;
	return {
		'section-71': {
			result: totalPass === expected && launchResult.fail === 0 && verifyResult.fail === 0 ? 'PASS' : 'FAIL',
			score: `${totalPass}/${expected}`,
			notes: 'CDC header recorder: probe inserts deliver change events, sink records markers, record ids audited'
		}
	};
}

async function runSection72()
{
	const {deployCmdtState} = require('./cmdt-deployer');
	const launchScript = path.join(SCRIPTS_DIR, 'section-72-cdc-blockdml-degrade.apex');
	const verifyScript = path.join(SCRIPTS_DIR, 'section-72b-cdc-blockdml-degrade-verify.apex');
	const expected = 4;

	console.log('  Section 72: deploying cdc-blockdml-degrade-active...');
	await deployCmdtState('cdc-blockdml-degrade-active');

	console.log('  Section 72: launching CDC probe inserts (recorder + BlockDml degrade)...');
	const launchResult = await runScript(launchScript);
	console.log(`  Section 72 (launch): ${launchResult.pass} pass, ${launchResult.fail} fail`);

	console.log('  Section 72: waiting 30s for change-event delivery...');
	await pause(BACKGROUND_WORK_WAIT_MILLISECONDS);

	console.log('  Section 72: verifying degrade...');
	const verifyResult = await runScript(verifyScript);
	console.log(`  Section 72 (verify): ${verifyResult.pass} pass, ${verifyResult.fail} fail`);

	console.log('  Section 72: restoring cdc-header-disabled...');
	await deployCmdtState('cdc-header-disabled');

	const totalPass = launchResult.pass + verifyResult.pass;
	return {
		'section-72': {
			result: totalPass === expected && launchResult.fail === 0 && verifyResult.fail === 0 ? 'PASS' : 'FAIL',
			score: `${totalPass}/${expected}`,
			notes: 'CDC BlockDml degrade: degrade-exclusive cdc-block-dml-degraded WARN logged (the proof); recorder co-action + source rows intact'
		}
	};
}

async function runSection75()
{
	const launchScript = path.join(SCRIPTS_DIR, 'section-75-queueable-unhandled-exception.apex');
	const verifyScript = path.join(SCRIPTS_DIR, 'section-75b-queueable-unhandled-exception-verify.apex');
	const expectedLaunch = 1;
	// The job is Failed, it keeps the exception's message, and the framework's finalizer wrote one ERROR log entry.
	const expectedVerify = 3;

	console.log('  Section 75: launching throwing async step...');
	const launchResult = await runScript(launchScript);
	console.log(`  Section 75 (launch): ${launchResult.pass} pass, ${launchResult.fail} fail`);

	console.log('  Section 75: waiting 30s for the queueable to run and fail...');
	await pause(BACKGROUND_WORK_WAIT_MILLISECONDS);

	console.log('  Section 75: verifying the surfaced Failed AsyncApexJob...');
	const verifyResult = await runScript(verifyScript);
	console.log(`  Section 75 (verify): ${verifyResult.pass} pass, ${verifyResult.fail} fail`);

	const totalPass = launchResult.pass + verifyResult.pass;
	const totalExpected = expectedLaunch + expectedVerify;

	return {
		'section-75': {
			result: totalPass === totalExpected && launchResult.fail === 0 && verifyResult.fail === 0 ? 'PASS' : 'FAIL',
			score: `${totalPass}/${totalExpected}`,
			notes: 'Queueable unhandled-exception surfacing: a throwing framework-launched step surfaces as a Failed AsyncApexJob with the exception identity in ExtendedStatus'
					+ ' and one ERROR log entry from the framework\'s finalizer'
		}
	};
}

// Launch and verify, no fixture: 75c starts a batch job that throws in one chunk and a job the launcher sizes from its
// setting; 75d, a minute later, reads both jobs, the ERROR entries the batch failure listener filed and the size warning.
async function runSection75c()
{
	const launchScript = path.join(SCRIPTS_DIR, 'section-75c-batch-failure-listener.apex');
	const verifyScript = path.join(SCRIPTS_DIR, 'section-75d-batch-failure-listener-verify.apex');
	const expectedLaunch = 2;
	const expectedVerify = 4;

	console.log('  Section 75c: starting the throwing batch and the launcher-sized batch...');
	const launchResult = await runScript(launchScript);
	console.log(`  Section 75c (launch): ${launchResult.pass} pass, ${launchResult.fail} fail`);

	console.log('  Section 75c: waiting 60s for both batch jobs and their log entries...');
	await pause(BATCH_JOBS_WAIT_MILLISECONDS);

	const verifyResult = await runScript(verifyScript);
	console.log(`  Section 75c (verify, 75d): ${verifyResult.pass} pass, ${verifyResult.fail} fail`);

	const totalPass = launchResult.pass + verifyResult.pass;
	const totalExpected = expectedLaunch + expectedVerify;

	return {
		'section-75c': {
			result: totalPass === totalExpected && launchResult.fail === 0 && verifyResult.fail === 0 ? 'PASS' : 'FAIL',
			score: `${totalPass}/${totalExpected}`,
			notes: 'Batch failure listener: a batch chunk that throws is filed as ERROR entries, and the launcher reads the batch size from the job setting (75c)'
					+ ' then the two jobs, the entries and the size warning are checked (75d)'
		}
	};
}

async function runSection77()
{
	const {deployCmdtState, deleteCmdtRecords} = require('./cmdt-deployer');
	const scriptPath = path.join(SCRIPTS_DIR, 'section-77-masking-cmdt-collision.apex');
	const expectedSeeded = 2;
	const expectedRecovered = 3;

	console.log('  Section 77: deploying collision-clone state (org-local MaskPaymentCard, unprefixed record name)...');
	await deployCmdtState('collision-clone');

	// The clone delete lives in a finally with explicit cleanup guidance: anything escaping the
	// seeded window would otherwise leave the org carrying the colliding record — degraded on
	// fixed builds, fully bricked on builds without the engine fallback.
	let seededResult;
	try
	{
		seededResult = await runScript(scriptPath);
		console.log(`  Section 77 (collision seeded): ${seededResult.pass} pass, ${seededResult.fail} fail`);
	}
	finally
	{
		console.log('  Section 77: deleting the org-local clone (recovery)...');
		try
		{
			await deleteCmdtRecords(['kern__MaskingRule.MaskPaymentCard']);
		}
		catch(deleteFailure)
		{
			console.error('  Section 77: clone delete FAILED — the org STILL carries the colliding org-local record'
					+ ' (framework DML degraded, or bricked on builds without the engine fallback).');
			console.error('  Manual cleanup: cd ~/.kern-cmdt-staging && sf project delete source -o $SF_SUBSCRIBER_ORG_ALIAS'
					+ ' -m "CustomMetadata:kern__MaskingRule.MaskPaymentCard" --no-prompt');
			// noinspection ThrowInsideFinallyBlockJS
			// eslint-disable-next-line no-unsafe-finally
			throw deleteFailure;
		}
	}

	console.log('  Section 77: waiting 30s for the seeded invocation\'s WARN log event to persist...');
	await pause(BACKGROUND_WORK_WAIT_MILLISECONDS);

	const recoveredResult = await runScript(scriptPath);
	console.log(`  Section 77 (recovered): ${recoveredResult.pass} pass, ${recoveredResult.fail} fail`);

	const totalPass = seededResult.pass + recoveredResult.pass;
	const totalExpected = expectedSeeded + expectedRecovered;

	return {
		'section-77': {
			result: totalPass === totalExpected && seededResult.fail === 0 && recoveredResult.fail === 0 ? 'PASS' : 'FAIL',
			score: `${totalPass}/${totalExpected}`,
			notes: 'Masking CMDT name-collision tolerance: collision seeded → inserts survive on the engine fallback (the pre-fix brick)'
					+ ' → clone deleted → fast path recovered + collision WARN persisted'
		}
	};
}

async function runSection78()
{
	// Two scripts because a same-transaction permission-set assignment is not reliably visible to
	// FeatureManagement.checkPermission (permission-cache staleness — the section-68 flag-gate
	// precedent), and it keeps the setup-object DML (PermissionSetAssignment, script 78) in a
	// separate transaction from the non-setup DML (AsyncChainExecution__c seed, script 78b).
	const strategyScript = path.join(SCRIPTS_DIR, 'section-78-abort-gate.apex');
	const grantedScript = path.join(SCRIPTS_DIR, 'section-78b-abort-gate-granted.apex');
	const expectedStrategy = 1;
	const expectedGranted = 2;

	console.log('  Section 78: running the strategy-resolution gate + permission-set grant...');
	const strategyResult = await runScript(strategyScript);
	console.log(`  Section 78 (strategy resolution): ${strategyResult.pass} pass, ${strategyResult.fail} fail`);

	console.log('  Section 78: running the granted gate in a fresh transaction (permission caches rebuilt)...');
	const grantedResult = await runScript(grantedScript);
	console.log(`  Section 78 (granted): ${grantedResult.pass} pass, ${grantedResult.fail} fail`);

	const totalPass = strategyResult.pass + grantedResult.pass;
	const totalExpected = expectedStrategy + expectedGranted;

	return {
		'section-78': {
			result: totalPass === totalExpected && strategyResult.fail === 0 && grantedResult.fail === 0 ? 'PASS' : 'FAIL',
			score: `${totalPass}/${totalExpected}`,
			notes: 'Abort gate custom-permission strategy: flag verdict matches the runner\'s real permission state + set granted (78)'
					+ ' → granted user resolves core.AbortAsyncChain in a fresh transaction + contradictory-row isTerminal probe through the released API (78b)'
		}
	};
}

async function runSection79()
{
	// Launch + verify split (RUNBOOK section 79 note): the launch seeds an audit-back-dated stale
	// probe and schedules a one-off watchdog CronTrigger on the next minute boundary through the
	// real platform-scheduler path; the verify runs after the fire window and hard-gates only the
	// Stalled flip (the stall-notification trail is observational). 79b cleans up the probe and
	// any lingering CronTrigger, restoring the watchdog-unscheduled baseline.
	const launchScript = path.join(SCRIPTS_DIR, 'section-79-watchdog-sweep.apex');
	const verifyScript = path.join(SCRIPTS_DIR, 'section-79b-watchdog-sweep-verify.apex');
	const expectedLaunch = 2;
	const expectedVerify = 1;

	console.log('  Section 79: seeding the stale probe + scheduling the one-off watchdog sweep...');
	const launchResult = await runScript(launchScript);
	console.log(`  Section 79 (launch): ${launchResult.pass} pass, ${launchResult.fail} fail`);

	console.log('  Section 79: waiting 100s for the scheduled sweep to fire...');
	await pause(SCHEDULED_SWEEP_WAIT_MILLISECONDS);

	const verifyResult = await runScript(verifyScript);
	console.log(`  Section 79 (verify): ${verifyResult.pass} pass, ${verifyResult.fail} fail`);

	const totalPass = launchResult.pass + verifyResult.pass;
	const totalExpected = expectedLaunch + expectedVerify;

	return {
		'section-79': {
			result: totalPass === totalExpected && launchResult.fail === 0 && verifyResult.fail === 0 ? 'PASS' : 'FAIL',
			score: `${totalPass}/${totalExpected}`,
			notes: 'Chain Watchdog sweep: audit-back-dated stuck Running probe seeded + one-off watchdog scheduled via the real scheduler (79)'
					+ ' → probe marked Stalled after the fire, then cleanup (79b)'
		}
	};
}

// Launch and verify, no fixture, the same shape and wait as section 79: 79c seeds a stuck chain whose current step has
// started and cannot safely run twice, and schedules a one-off watchdog; 79d checks the watchdog ended it Failed with
// an end time and the refusal message, then cleans up. 79d prints a FAIL line while the watchdog has not fired yet.
async function runSection79c()
{
	const launchScript = path.join(SCRIPTS_DIR, 'section-79c-watchdog-started-step.apex');
	const verifyScript = path.join(SCRIPTS_DIR, 'section-79d-watchdog-started-step-verify.apex');
	const expectedLaunch = 2;
	const expectedVerify = 1;

	console.log('  Section 79c: seeding the chain stuck at a started step + scheduling the one-off watchdog...');
	const launchResult = await runScript(launchScript);
	console.log(`  Section 79c (launch): ${launchResult.pass} pass, ${launchResult.fail} fail`);

	console.log('  Section 79c: waiting 100s for the scheduled watchdog to fire...');
	await pause(SCHEDULED_SWEEP_WAIT_MILLISECONDS);

	const verifyResult = await runScript(verifyScript);
	console.log(`  Section 79c (verify, 79d): ${verifyResult.pass} pass, ${verifyResult.fail} fail`);

	const totalPass = launchResult.pass + verifyResult.pass;
	const totalExpected = expectedLaunch + expectedVerify;

	return {
		'section-79c': {
			result: totalPass === totalExpected && launchResult.fail === 0 && verifyResult.fail === 0 ? 'PASS' : 'FAIL',
			score: `${totalPass}/${totalExpected}`,
			notes: 'Chain Watchdog at a started step: a stuck chain whose current step started and is not safe to repeat is seeded (79c)'
					+ ' → the watchdog ends it Failed with an end time and the refusal message, then cleanup (79d)'
		}
	};
}

// Declarative registry of every orchestrated (non-runBatch) section, in execution
// order — the order is load-bearing: CMDT fixture cycles restore shared states and the
// async launch + verify splits sit late so the org is drained. main() drives each entry
// through runOrchestratedSection.
const ORCHESTRATED_SECTIONS = [
	{section: 3, header: 'Step 2: Section 3 (CMDT state transitions)...', run: runSection3},
	{section: 11, header: 'Step 3: Section 11 (execution strategies)...', run: runSection11},
	{section: 22, header: 'Step 4: Section 22 (advanced strategies)...', run: runSection22},
	{section: 27, header: 'Step 5: Section 27 (mock selection)...', run: runSection27},
	{section: 31, header: 'Step 5a: Section 31 (failure handling — MockAllAPIs window + log cleanup)...', run: runSection31},
	{section: 55, header: 'Step 5b: Section 55 (outbound failure composition — MockAllAPIs window + log cleanup)...', run: runSection55},
	{section: 63, header: 'Step 5c: Section 63 (breaker + retry composition — MockAllAPIs window + log cleanup)...', run: runSection63},
	{section: 60, header: 'Step 5d: Section 60 (mock regex edge cases — MockAllAPIs window + issue cleanup)...', run: runSection60},
	{section: 34, header: 'Step 6: Section 34 (async chain)...', run: runSection34},
	{section: 35, header: 'Step 6b: Section 35 (secure-by-default + kill-switch)...', run: runSection35},
	{section: 42, header: 'Step 6c: Section 42 (BlockDml strategy — CMDT cycle)...', run: runSection42},
	{section: 43, header: 'Step 6d: Section 43 (RequiredFeatureFlag gate — CMDT cycle)...', run: runSection43},
	{section: 56, header: 'Step 6e: Section 56 (edge async chain — launch + verify)...', run: runSection56},
	{section: 76, header: 'Step 6f: Section 76 (masking advisor round-trip — bundle deploys)...', run: runSection76},
	{section: 67, header: 'Step 6g: Section 67 (post-trigger actions — core behaviour — CMDT cycle)...', run: runSection67},
	{section: 68, header: 'Step 6h: Section 68 (post-trigger actions — feature-flag gate — CMDT cycle)...', run: runSection68},
	{section: 69, header: 'Step 6i: Section 69 (post-trigger actions — no-DML guard — CMDT cycle)...', run: runSection69},
	{section: 70, header: 'Step 6j: Section 70 (post-trigger actions — failure-action policy — CMDT cycle)...', run: runSection70},
	{section: 71, header: 'Step 6k: Section 71 (CDC change-event header recorder — launch + verify)...', run: runSection71},
	{section: 72, header: 'Step 6l: Section 72 (CDC BlockDml degrade — launch + verify)...', run: runSection72},
	{section: 75, header: 'Step 6m: Section 75 (queueable unhandled-exception surfacing — launch + verify)...', run: runSection75},
	{section: '75c', header: 'Step 6m2: Section 75c (batch failure listener and launcher batch size: launch, 60s wait, verify 75d)...', run: runSection75c},
	{section: 66, header: 'Step 6n: Section 66 (log-fingerprint flood control — subscriber API — launch + verify)...', run: runSection66},
	{section: 65, header: 'Step 6o: Section 65 (framework-wide bypass audit — launch + verify)...', run: runSection65},
	{section: 77, header: 'Step 6p: Section 77 (masking CMDT name-collision tolerance — seeded + recovery)...', run: runSection77},
	{section: 78, header: 'Step 6q: Section 78 (abort gate — core.-prefixed custom-permission strategy — strategy resolution + granted)...', run: runSection78},
	{section: 79, header: 'Step 6r: Section 79 (chain watchdog sweep — scheduled detection of a stuck chain — launch + verify)...', run: runSection79},
	{section: '79c', header: 'Step 6s: Section 79c (chain watchdog at a started step: launch, 100s wait, verify 79d)...', run: runSection79c}
];

async function main()
{
	console.log('=== KernDX Release Testing — Phase 2 ===\n');
	const startTime = Date.now();

	// Pre-flight: confirm `sf` recognises ORG_ALIAS before we touch the org.
	// NamedOrgNotFoundError bubbles up with a one-line remediation.
	console.log(`Step 0a: Verifying Salesforce CLI alias "${ORG_ALIAS}"...`);
	preflightOrgAvailable();
	preflightPackageInstalled();
	console.log('  CLI alias resolved, and the org has the package installed.\n');

	console.log('Step 0b: Verifying audit-field back-dating enablement (Section 79 prerequisite)...');
	await preflightAuditBackdating();
	console.log('  Audit back-dating verified.\n');

	console.log('Step 0: Deploying baseline CMDT state...');
	const {deployCmdtState} = require('./cmdt-deployer');
	await deployCmdtState('baseline');
	console.log('  Baseline deployed.\n');

	console.log('Step 1: Independent scripts (parallel)...');
	const scriptResults = await runBatch(INDEPENDENT_SCRIPTS, MAX_CONCURRENT);

	const orchestratedResults = {};
	for(const entry of ORCHESTRATED_SECTIONS)
	{
		console.log(`\n${entry.header}`);
		Object.assign(orchestratedResults, await runOrchestratedSection(entry.section, entry.run));
	}

	console.log('\nStep 7: Test classes + Scanner...');
	const [testClassResults, scannerResults] = await Promise.all([
		runTestClasses(),
		runScanner()
	]);

	const allScripts = {...scriptResults, ...orchestratedResults};
	const allPassing = Object.values(allScripts).every(r => r.result === 'PASS');

	let results;
	try
	{
		results = JSON.parse(fs.readFileSync(RECORDED_RESULTS_PATH, {encoding: 'utf8'}));
	}
	catch
	{
		results = {};
	}

	results.phase2 = {
		scripts: allScripts, testClasses: testClassResults, ...scannerResults
	};

	fs.mkdirSync(path.dirname(RECORDED_RESULTS_PATH), {recursive: true});
	fs.writeFileSync(RECORDED_RESULTS_PATH, JSON.stringify(results, null, 2) + '\n', 'utf8');

	const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
	console.log(`\n=== Phase 2 complete in ${elapsed}s ===`);
	console.log(`Scripts: ${allPassing ? '\x1b[32mALL PASS\x1b[0m' : '\x1b[31mSOME FAILED\x1b[0m'}`);
	console.log(`Test classes: ${testClassResults.result}`);
	console.log(`Results written to ${RECORDED_RESULTS_PATH}`);

	process.exit(allPassing && testClassResults.result === 'PASS' ? 0 : 1);
}

// Surface the two pre-flight refusals with the remediation message
// front-and-center (the error's `.message` already encodes the fix).
function reportFailure(error)
{
	if(error instanceof NamedOrgNotFoundError || error instanceof ReleaseTargetError)
	{
		console.error('\nPhase 2 aborted at pre-flight:\n');
		console.error(error.message);
	}
	else
	{
		console.error('Phase 2 failed:', error);
	}
	process.exit(1);
}

if(require.main === module)
{
	main().catch(reportFailure);
}

module.exports = {
	INDEPENDENT_SCRIPTS,
	MAX_CONCURRENT,
	BACKGROUND_WORK_WAIT_MILLISECONDS,
	ORCHESTRATED_SECTIONS,
	runScript,
	runBatch,
	runOrchestratedSection,
	runSection3,
	runSection11,
	runSection22,
	runSection27,
	runSection31,
	runSection55,
	runSection60,
	runSection63,
	runSection35,
	runSection76,
	runSection67,
	runSection68,
	runSection69,
	runSection70,
	runSection71,
	runSection72,
	runSection75,
	runSection75c,
	runSection66,
	runSection65,
	runSection77,
	runSection78,
	runSection79,
	runSection79c,
	runTestClasses,
	runScanner,
	preflightAuditBackdating,
	preflightPackageInstalled,
	reportFailure,
	main
};
