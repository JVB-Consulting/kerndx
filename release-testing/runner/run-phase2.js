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
		execSync(`sf org display -o ${ORG_ALIAS} --json`, {encoding: 'utf8', timeout: 30_000, stdio: ['pipe', 'pipe', 'pipe']});
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
	{section: 37, file: 'section-37-masking-min-input-length.apex', expected: 2},
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
	{section: 64, file: 'section-64-edge-asyncjob-launcher.apex', expected: 6},
	{section: 65, file: 'section-65-bypass-audit-framework-wide.apex', expected: 5}
];

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
			resolve({pass, fail, total: pass + fail, raw: output, error: error?.message});
		});
	});
}

async function runBatch(scripts, concurrent)
{
	const results = {};
	const queue = [...scripts];

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
		}
	}

	const workers = Array.from({length: concurrent}, () => worker());
	await Promise.all(workers);
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
			pmdResult.violations = pmdData.violationCounts
				? pmdData.violationCounts.total || 0
				: (pmdData.violations ? pmdData.violations.length : 0);
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
			result: result.pass === expected && result.fail === 0 ? 'PASS' : 'FAIL',
			score: `${result.pass}/${expected}`,
			notes: 'BlockDml active → test → default restored'
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
			result: result.pass === expected && result.fail === 0 ? 'PASS' : 'FAIL',
			score: `${result.pass}/${expected}`,
			notes: 'Flag disabled → test → default restored'
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

	console.log('\nStep 2: Section 3 (CMDT state transitions)...');
	const section3Results = await runSection3();

	console.log('\nStep 3: Section 11 (execution strategies)...');
	const section11Results = await runSection11();

	console.log('\nStep 4: Section 22 (advanced strategies)...');
	const section22Results = await runSection22();

	console.log('\nStep 5: Section 27 (mock selection)...');
	const section27Results = await runSection27();

	console.log('\nStep 6: Section 34 (async chain)...');
	const section34Results = await runSection34();

	console.log('\nStep 6b: Section 35 (secure-by-default + kill-switch)...');
	const section35Results = await runSection35();

	console.log('\nStep 6c: Section 42 (BlockDml strategy — CMDT cycle)...');
	const section42Results = await runSection42();

	console.log('\nStep 6d: Section 43 (RequiredFeatureFlag gate — CMDT cycle)...');
	const section43Results = await runSection43();

	console.log('\nStep 6e: Section 56 (edge async chain — launch + verify)...');
	const section56Results = await runSection56();

	console.log('\nStep 7: Test classes + Scanner...');
	const [testClassResults, scannerResults] = await Promise.all([
		runTestClasses(),
		runScanner()
	]);

	const allScripts = {...scriptResults, ...section3Results, ...section11Results, ...section22Results, ...section27Results, ...section34Results, ...section35Results, ...section42Results, ...section43Results, ...section56Results};
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
	INDEPENDENT_SCRIPTS, MAX_CONCURRENT, runScript, runBatch, runSection3, runSection11, runSection22, runSection27, runSection35, runTestClasses, runScanner, main
};
