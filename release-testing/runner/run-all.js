// SPDX-License-Identifier: BUSL-1.1
const {execSync} = require('child_process');
const path = require('path');
const fs = require('fs');
const {getSubscriberOrgAlias} = require('./subscriber-config');

const ROOT = path.join(__dirname, '..', '..');
const RESULTS_PATH = path.join(__dirname, '..', 'results', 'current-run.json');
const ORG_ALIAS = getSubscriberOrgAlias();

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

async function main()
{
	const startTime = Date.now();
	const args = process.argv.slice(2);
	const explicitVersion = args.find(a => !a.startsWith('--'));
	const skipPhase2 = args.includes('--skip-phase2');
	const skipPhase3 = args.includes('--skip-phase3');
	const headed = args.includes('--headed');

	let version = explicitVersion;
	let subscriberPackageVersionId;

	if(!version)
	{
		console.log('Detecting installed package version...');
		const detected = detectInstalledVersion();
		if(detected)
		{
			version = detected.version;
			subscriberPackageVersionId = detected.subscriberPackageVersionId;
			console.log(`  Detected: ${version} (${subscriberPackageVersionId})\n`);
		}
		else
		{
			version = '1.0.0-XX';
			console.log('  Using fallback version: 1.0.0-XX\n');
		}
	}

	console.log('=== KernDX Release Testing — Full Pipeline ===');
	console.log(`Version: ${version}`);
	console.log(`Date: ${new Date().toISOString().split('T')[0]}\n`);

	let results;
	try
	{
		results = JSON.parse(fs.readFileSync(RESULTS_PATH, 'utf8'));
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
	fs.mkdirSync(path.dirname(RESULTS_PATH), {recursive: true});
	fs.writeFileSync(RESULTS_PATH, JSON.stringify(results, null, 2) + '\n', 'utf8');

	let phase2Success = true;
	let phase3Success = true;

	if(!skipPhase2)
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
			phase2Success = false;
			console.error('\nPhase 2 had failures. Continuing to Phase 3...\n');
		}
	}

	if(!skipPhase3)
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
			phase3Success = false;
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
	const overall = phase2Success && phase3Success;

	console.log(`\n=== Pipeline complete in ${elapsed} minutes ===`);
	console.log(`Phase 2: ${phase2Success ? '\x1b[32mPASS\x1b[0m' : '\x1b[31mFAIL\x1b[0m'}`);
	console.log(`Phase 3: ${phase3Success ? '\x1b[32mPASS\x1b[0m' : '\x1b[31mFAIL\x1b[0m'}`);
	console.log(`Overall: ${overall ? '\x1b[32mALL PASS\x1b[0m' : '\x1b[31mFAIL\x1b[0m'}`);

	process.exit(overall ? 0 : 1);
}

main().catch(error =>
{
	console.error('Pipeline failed:', error);
	process.exit(1);
});
