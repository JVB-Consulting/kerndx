// SPDX-License-Identifier: BUSL-1.1
const {execSync} = require('child_process');
const path = require('path');
const fs = require('fs');
const {getSubscriberOrgAlias} = require('./subscriber-config');
const {RECORDED_RESULTS_PATH, ReleaseTargetError, assertReleaseTarget} = require('./release-target');
const {namespacePrefix} = require('../e2e/helpers/sf-namespace');

const ROOT = path.join(__dirname, '..', '..');
const ORG_ALIAS = getSubscriberOrgAlias();

// Stamped into the record when neither the command line nor the org can say which version was tested, so a reader of
// the results file can see at a glance that the version was never established rather than reading a plausible number.
const FALLBACK_VERSION = '1.0.0-XX';

function detectInstalledVersion()
{
	try
	{
		const output = execSync(`sf package installed list -o ${ORG_ALIAS} --json`, {encoding: 'utf8', timeout: 60_000});
		const data = JSON.parse(output);
		const kernPkg = (data.result || []).find(p => p.SubscriberPackageName === 'Kern' || p.SubscriberPackageNamespace === 'kern');
		if(kernPkg)
		{
			const parts = `${kernPkg.SubscriberPackageVersionNumber}`.split('.');
			const v = parts.length === 4 ? `${parts[0]}.${parts[1]}.${parts[2]}-${parts[3]}` : parts.join('.');
			return {version: v, subscriberPackageVersionId: kernPkg.SubscriberPackageVersionId};
		}
	}
	catch(error)
	{
		console.warn('  Could not auto-detect package version:', error.message);
	}
	return null;
}

// Which version this cycle is testing, in the order the pipeline trusts: the one named on the command line, then the
// one the org reports for the installed package, then the placeholder.
function resolveVersion(explicitVersion)
{
	if(explicitVersion)
	{
		return {version: explicitVersion, subscriberPackageVersionId: undefined};
	}

	console.log('Detecting installed package version...');
	const detected = detectInstalledVersion();
	if(detected)
	{
		console.log(`  Detected: ${detected.version} (${detected.subscriberPackageVersionId})\n`);
		return detected;
	}

	console.log(`  Using fallback version: ${FALLBACK_VERSION}\n`);
	return {version: FALLBACK_VERSION, subscriberPackageVersionId: undefined};
}

async function main()
{
	// What this pipeline produces is the record of a release-testing cycle, and its first act is to write into it, so
	// an org without the package installed is turned away here, before anything is written or run.
	assertReleaseTarget(ORG_ALIAS, namespacePrefix);

	const startTime = Date.now();
	const args = process.argv.slice(2);
	const explicitVersion = args.find(a => !a.startsWith('--'));
	const skipAutomatedTests = args.includes('--skip-phase2');
	const skipVisualTests = args.includes('--skip-phase3');
	const headed = args.includes('--headed');

	const {version, subscriberPackageVersionId} = resolveVersion(explicitVersion);

	console.log('=== KernDX Release Testing — Full Pipeline ===');
	console.log(`Version: ${version}`);
	console.log(`Date: ${new Date().toISOString().split('T')[0]}\n`);

	let results;
	try
	{
		results = JSON.parse(fs.readFileSync(RECORDED_RESULTS_PATH, {encoding: 'utf8'}));
	}
	catch
	{
		results = {};
	}
	results.packageVersion = version;
	if(subscriberPackageVersionId)
	{
		results.subscriberPackageVersionId = subscriberPackageVersionId;
	}
	results.testDate = new Date().toISOString().split('T')[0];
	fs.mkdirSync(path.dirname(RECORDED_RESULTS_PATH), {recursive: true});
	fs.writeFileSync(RECORDED_RESULTS_PATH, JSON.stringify(results, null, 2) + '\n', 'utf8');

	let automatedTestsPassed = true;
	let visualTestsPassed = true;

	if(!skipAutomatedTests)
	{
		console.log('--- Phase 2: Automated Tests ---\n');
		try
		{
			execSync('node release-testing/runner/run-phase2.js', {
				encoding: 'utf8', stdio: 'inherit', timeout: 600_000, cwd: ROOT
			});
		}
		catch
		{
			automatedTestsPassed = false;
			console.error('\nPhase 2 had failures. Continuing to Phase 3...\n');
		}
	}

	if(!skipVisualTests)
	{
		console.log('\n--- Phase 3: Visual Tests (Playwright) ---\n');
		const playwrightArgs = [
			'npx',
			'playwright',
			'test',
			'--config',
			path.join(__dirname, '..', 'e2e', 'playwright.config.js')
		];
		if(headed)
		{
			playwrightArgs.push('--headed');
		}

		try
		{
			execSync(playwrightArgs.join(' '), {
				encoding: 'utf8', stdio: 'inherit', timeout: 1800_000, cwd: ROOT
			});
		}
		catch
		{
			visualTestsPassed = false;
			console.error('\nPhase 3 had failures.\n');
		}
	}

	console.log('\n--- Phase 4: Compile Results ---\n');
	try
	{
		const {compile} = require('./result-compiler');
		compile(version);
	}
	catch(error)
	{
		console.error('Result compilation failed:', error.message);
	}

	const elapsed = ((Date.now() - startTime) / 1000 / 60).toFixed(1);
	const overall = automatedTestsPassed && visualTestsPassed;

	console.log(`\n=== Pipeline complete in ${elapsed} minutes ===`);
	console.log(`Phase 2: ${automatedTestsPassed ? '\x1b[32mPASS\x1b[0m' : '\x1b[31mFAIL\x1b[0m'}`);
	console.log(`Phase 3: ${visualTestsPassed ? '\x1b[32mPASS\x1b[0m' : '\x1b[31mFAIL\x1b[0m'}`);
	console.log(`Overall: ${overall ? '\x1b[32mALL PASS\x1b[0m' : '\x1b[31mFAIL\x1b[0m'}`);

	process.exit(overall ? 0 : 1);
}

// A refusal already says which org, why, and what to change, so it is printed alone; a stack trace adds nothing to it.
function reportFailure(error)
{
	if(error instanceof ReleaseTargetError)
	{
		console.error('\nPipeline stopped before it started:\n');
		console.error(error.message);
	}
	else
	{
		console.error('Pipeline failed:', error);
	}
	process.exit(1);
}

if(require.main === module)
{
	main().catch(reportFailure);
}

module.exports = {main, reportFailure, resolveVersion};
