// SPDX-License-Identifier: BUSL-1.1
const {exec, execSync} = require('child_process');
const path = require('path');
const fs = require('fs');
const {getSubscriberOrgAlias} = require('./subscriber-config');
const {isNamedOrgNotFoundError, NamedOrgNotFoundError} = require('./cmdt-deployer');

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

const SCRIPTS_DIR = path.join(__dirname, '..', 'scripts');
const RESULTS_PATH = path.join(__dirname, '..', 'results', 'current-run.json');
const MAX_CONCURRENT = 5;

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
	{section: 31, file: 'section-31-failure-handling.apex', expected: 8},
	{section: 36, file: 'section-36-masking-applicable-field-types.apex', expected: 4},
	{section: 37, file: 'section-37-masking-min-input-length.apex', expected: 3},
	{section: 38, file: 'section-38-masking-transactionid-preservation.apex', expected: 3},
	{section: 39, file: 'section-39-masking-type-filter-warn.apex', expected: 1},
	{section: 41, file: 'section-41-flow-action-subscriber.apex', expected: 6},
	{section: 44, file: 'section-44-flow-action-upgrade.apex', expected: 3},
	{section: 52, file: 'section-52-edge-dml-builder.apex', expected: 8},
	{section: 53, file: 'section-53-edge-qry-builder.apex', expected: 10},
	{section: 54, file: 'section-54-edge-inbound-api.apex', expected: 4},
	{section: 55, file: 'section-55-edge-outbound-failure.apex', expected: 9},
	{section: 57, file: 'section-57-edge-cache-ttl.apex', expected: 5},
	{section: 58, file: 'section-58-edge-logger.apex', expected: 7},
	{section: 59, file: 'section-59-edge-scheduler.apex', expected: 4},
	{section: 60, file: 'section-60-edge-mock-regex.apex', expected: 5},
	{section: 61, file: 'section-61-edge-masking-rollback.apex', expected: 5},
	{section: 62, file: 'section-62-edge-type-resolver.apex', expected: 4},
	{section: 63, file: 'section-63-edge-resilience-comp.apex', expected: 6},
	{section: 64, file: 'section-64-edge-asyncjob-launcher.apex', expected: 6}
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
	let result = await runScript(scriptPath);
	totalPass += result.pass;
	console.log(`  Section 11 (Fail Fast): ${result.pass} assertions passed`);

	console.log('  Section 11: deploying accumulate state...');
	await deployCmdtState('section11-accumulate');
	result = await runScript(scriptPath);
	totalPass += result.pass;
	console.log(`  Section 11 (Accumulate): ${result.pass} assertions passed`);

	return {
		'section-11': {
			result: totalPass === expected ? 'PASS' : 'FAIL', score: `${totalPass}/${expected}`, notes: 'Fail Fast and Accumulate verified'
		}
	};
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
		const summary = result.result?.summary || {};
		return {
			result: summary.outcome === 'Passed' ? 'PASS' : 'FAIL', passed: summary.testsRan || 0, failed: summary.failing || 0, coverage: summary.testRunCoverage || '0%'
		};
	}
	catch(error)
	{
		return {result: 'FAIL', error: error.message};
	}
}

async function runScanner()
{
	console.log('\n  Running scanner...');
	const pmdResult = {violations: 0, notes: ''};
	const eslintResult = {fixtureViolations: 0, frameworkViolations: 0, notes: ''};

	const scannerOutputPath = path.join(__dirname, '..', 'results', 'scanner-violations.json');
	try
	{
		fs.rmSync(scannerOutputPath, {force: true});

		// Scanner fixture validation uses the FULL ruleset (code-analyzer-fixtures.yml
		// points to scanner/kerndx-pmd-ruleset.xml) — including the "use the framework
		// API instead of the platform primitive" rules that the framework-scoped
		// code-analyzer.yml deliberately excludes. Fixtures in release-testing/scanner/
		// classes/ contain deliberate violations of those framework-API rules.
		execSync(
				`sf code-analyzer run --target release-testing/scanner/classes/ --rule-selector pmd:KernDXFrameworkCompliance --config-file release-testing/scanner/code-analyzer-fixtures.yml --output-file "${scannerOutputPath}" 2>&1`,
				{encoding: 'utf8', timeout: 120_000});

		if(fs.existsSync(scannerOutputPath))
		{
			const pmdData = JSON.parse(fs.readFileSync(scannerOutputPath, 'utf8'));
			pmdResult.violations = pmdData.violationCounts ? pmdData.violationCounts.total || 0 : (pmdData.violations ? pmdData.violations.length : 0);
		}
		else
		{
			pmdResult.notes = 'Scanner output file not generated';
		}
	}
	catch(error)
	{
		pmdResult.notes = 'Scanner failed: ' + (error.message || '').slice(0, 120);
	}

	return {scanner: pmdResult, eslint: eslintResult};
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
	await new Promise(resolve => setTimeout(resolve, 30_000));

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
	await new Promise(resolve => setTimeout(resolve, 30_000));

	console.log('  Section 66: verifying detail/rollup flood-control shape...');
	const verifyResult = await runScript(verifyScript);
	console.log(`  Section 66 (verify): ${verifyResult.pass} pass, ${verifyResult.fail} fail`);

	const totalPass = launchResult.pass + verifyResult.pass;
	const totalExpected = expectedLaunch + expectedVerify;

	return {
		'section-66': {
			result: totalPass === totalExpected && launchResult.fail === 0 && verifyResult.fail === 0 ? 'PASS' : 'FAIL',
			score: `${totalPass}/${totalExpected}`,
			notes: `Launch: ${launchResult.pass}/${expectedLaunch}, Verify: ${verifyResult.pass}/${expectedVerify} — subscriber withFingerprint -> detail/rollup grouping + OccurrenceCount`
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
	await new Promise(resolve => setTimeout(resolve, 30_000));

	console.log('  Section 65: verifying object-qualified bypass-audit targets + flood-control shape...');
	const verifyResult = await runScript(verifyScript);
	console.log(`  Section 65 (verify): ${verifyResult.pass} pass, ${verifyResult.fail} fail`);

	const totalPass = launchResult.pass + verifyResult.pass;
	const totalExpected = expectedLaunch + expectedVerify;

	return {
		'section-65': {
			result: totalPass === totalExpected && launchResult.fail === 0 && verifyResult.fail === 0 ? 'PASS' : 'FAIL',
			score: `${totalPass}/${totalExpected}`,
			notes: `Launch: ${launchResult.pass}/${expectedLaunch}, Verify: ${verifyResult.pass}/${expectedVerify} — four bypass surfaces -> object-qualified query/DML audit targets + flood-control shape`
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
	await new Promise(resolve => setTimeout(resolve, 30_000));

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
	await new Promise(resolve => setTimeout(resolve, 30_000));

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
	await new Promise(resolve => setTimeout(resolve, 30_000));

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
	const expectedVerify = 2;

	console.log('  Section 75: launching throwing async step...');
	const launchResult = await runScript(launchScript);
	console.log(`  Section 75 (launch): ${launchResult.pass} pass, ${launchResult.fail} fail`);

	console.log('  Section 75: waiting 30s for the queueable to run and fail...');
	await new Promise(resolve => setTimeout(resolve, 30_000));

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
			console.error('  Section 77: clone delete FAILED — the org STILL carries the colliding org-local record (framework DML degraded, or bricked on builds without the engine fallback).');
			console.error('  Manual cleanup: cd ~/.kern-cmdt-staging && sf project delete source -o $SF_SUBSCRIBER_ORG_ALIAS -m "CustomMetadata:kern__MaskingRule.MaskPaymentCard" --no-prompt');
			throw deleteFailure;
		}
	}

	console.log('  Section 77: waiting 30s for the seeded invocation\'s WARN log event to persist...');
	await new Promise(resolve => setTimeout(resolve, 30_000));

	const recoveredResult = await runScript(scriptPath);
	console.log(`  Section 77 (recovered): ${recoveredResult.pass} pass, ${recoveredResult.fail} fail`);

	const totalPass = seededResult.pass + recoveredResult.pass;
	const totalExpected = expectedSeeded + expectedRecovered;

	return {
		'section-77': {
			result: totalPass === totalExpected && seededResult.fail === 0 && recoveredResult.fail === 0 ? 'PASS' : 'FAIL',
			score: `${totalPass}/${totalExpected}`,
			notes: 'Masking CMDT name-collision tolerance: collision seeded → inserts survive on the engine fallback (the pre-fix brick) → clone deleted → fast path recovered + collision WARN persisted'
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
	{section: 66, header: 'Step 6n: Section 66 (log-fingerprint flood control — subscriber API — launch + verify)...', run: runSection66},
	{section: 65, header: 'Step 6o: Section 65 (framework-wide bypass audit — launch + verify)...', run: runSection65},
	{section: 77, header: 'Step 6p: Section 77 (masking CMDT name-collision tolerance — seeded + recovery)...', run: runSection77}
];

async function main()
{
	console.log('=== KernDX Release Testing — Phase 2 ===\n');
	const startTime = Date.now();

	// Pre-flight: confirm `sf` recognises ORG_ALIAS before we touch the org.
	// NamedOrgNotFoundError bubbles up with a one-line remediation.
	console.log(`Step 0a: Verifying Salesforce CLI alias "${ORG_ALIAS}"...`);
	preflightOrgAvailable();
	console.log('  CLI alias resolved.\n');

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

	let results = {};
	try
	{
		results = JSON.parse(fs.readFileSync(RESULTS_PATH, 'utf8'));
	}
	catch
	{
	}

	results.phase2 = {
		scripts: allScripts, testClasses: testClassResults, ...scannerResults
	};

	fs.mkdirSync(path.dirname(RESULTS_PATH), {recursive: true});
	fs.writeFileSync(RESULTS_PATH, JSON.stringify(results, null, 2) + '\n', 'utf8');

	const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
	console.log(`\n=== Phase 2 complete in ${elapsed}s ===`);
	console.log(`Scripts: ${allPassing ? '\x1b[32mALL PASS\x1b[0m' : '\x1b[31mSOME FAILED\x1b[0m'}`);
	console.log(`Test classes: ${testClassResults.result}`);
	console.log(`Results written to ${RESULTS_PATH}`);

	process.exit(allPassing && testClassResults.result === 'PASS' ? 0 : 1);
}

if(require.main === module)
{
	main().catch(error =>
	{
		// Surface NamedOrgNotFoundError with the remediation message
		// front-and-center (the error's `.message` already encodes the fix).
		if(error instanceof NamedOrgNotFoundError)
		{
			console.error('\nPhase 2 aborted at pre-flight:\n');
			console.error(error.message);
			process.exit(1);
		}
		console.error('Phase 2 failed:', error);
		process.exit(1);
	});
}

module.exports = {
	INDEPENDENT_SCRIPTS,
	MAX_CONCURRENT,
	ORCHESTRATED_SECTIONS,
	runScript,
	runBatch,
	runOrchestratedSection,
	runSection3,
	runSection11,
	runSection22,
	runSection27,
	runSection35,
	runSection76,
	runSection67,
	runSection68,
	runSection69,
	runSection70,
	runSection71,
	runSection72,
	runSection75,
	runSection66,
	runSection65,
	runSection77,
	runTestClasses,
	runScanner,
	main
};
