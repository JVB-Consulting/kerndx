#!/usr/bin/env node
// SPDX-License-Identifier: Apache-2.0

const {execSync: realExecSync} = require('child_process');
const {getSubscriberOrgAlias} = require('./subscriber-config');

// The burst's outbound handler (API_LoadProbeOutbound) answers through its defaultMockBody. Outside a unit test that
// body stands in for the callout only while the MockAllAPIs feature flag is on, so the burst runs inside that window.
const SCRIPTS = [
	{kind: 'apex', path: 'release-testing/scripts/load-extended/sustained-masker-soak.apex'},
	{kind: 'apex', path: 'release-testing/scripts/load-extended/sustained-logger-pe-flood.apex'},
	{kind: 'node', path: 'release-testing/scripts/load-extended/parallel-callout-burst-100.js', mockAllApis: true},
	{kind: 'node', path: 'release-testing/scripts/load-extended/parallel-cache-contention.js'}
];

// Turns MockAllAPIs back off after a script. Left on, it answers every outbound call in the org with a canned
// response, so a failed restore says which fixture to deploy by hand before it counts as a failure.
async function restoreMockAllApisOff(script, deployCmdtState, logError)
{
	try
	{
		await deployCmdtState('mock-all-apis-disabled');
		return true;
	}
	catch(restoreFailure)
	{
		logError(`MockAllAPIs could not be turned off after ${script.path} (${restoreFailure.message}); deploy the `
				+ 'cmdt-states/mock-all-apis-disabled fixture by hand before running anything else on this org once this suite ends.');
		return false;
	}
}

function runScript(script, orgAlias, execSync)
{
	if(script.kind === 'apex')
	{
		execSync(`sf apex run --file ${script.path} -o ${orgAlias}`, {stdio: 'inherit'});
	}
	else
	{
		execSync(`node ${script.path}`, {stdio: 'inherit'});
	}
}

// Runs every script once and answers the exit code: 1 when any script failed, otherwise 0.
async function runExtendedLoad({
	orgAlias = getSubscriberOrgAlias(),
	execSync = realExecSync,
	deployCmdtState = (stateName) => require('./cmdt-deployer').deployCmdtState(stateName),
	log = console.log,
	logError = console.error
} = {})
{
	log('=== Extended load suite ===\n');
	let pass = 0, fail = 0;

	for(const script of SCRIPTS)
	{
		log(`\n--- Running ${script.path} ---`);
		let scriptFailed = false;
		try
		{
			if(script.mockAllApis)
			{
				log('  deploying mock-all-apis-enabled...');
				await deployCmdtState('mock-all-apis-enabled');
			}
			runScript(script, orgAlias, execSync);
		}
		catch(e)
		{
			logError(`FAIL: ${script.path}`);
			scriptFailed = true;
		}
		finally
		{
			// Unlike run-phase2, the restore also runs after a failed enable, so a half-applied enable is turned off.
			if(script.mockAllApis && !(await restoreMockAllApisOff(script, deployCmdtState, logError)))
			{
				scriptFailed = true;
			}
		}
		if(scriptFailed)
		{
			fail++;
		}
		else
		{
			pass++;
		}
	}

	log(`\n=== Extended load suite: ${pass} passed, ${fail} failed ===`);
	return fail > 0 ? 1 : 0;
}

module.exports = {runExtendedLoad};

if(require.main === module)
{
	runExtendedLoad().then((exitCode) => process.exit(exitCode));
}
