// SPDX-License-Identifier: BUSL-1.1
const {execSync} = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');
const {getSubscriberOrgAlias} = require('./subscriber-config');

const ORG_ALIAS = getSubscriberOrgAlias();
const FIXTURES_DIR = path.join(__dirname, '..', 'e2e', 'fixtures', 'cmdt-states');
const STAGING_DIR = path.join(os.homedir(), '.kern-cmdt-staging');
const CMDT_DEPLOY_DIR = path.join(STAGING_DIR, 'force-app', 'main', 'default', 'customMetadata');
const STAGING_PROJECT = path.join(STAGING_DIR, 'sfdx-project.json');
const STAGING_PROJECT_CONTENT = '{"packageDirectories":[{"path":"force-app","default":true}],"name":"CmdtStaging","sourceApiVersion":"67.0"}\n';

// Dedicated subclass so callers can `instanceof` test this failure mode
// without parsing error messages. Raised when the configured ORG_ALIAS is not
// recognised by the Salesforce CLI (e.g. the alias hasn't been set up, the
// scratch org expired, or the user typoed SF_SUBSCRIBER_ORG_ALIAS).
class NamedOrgNotFoundError extends Error
{
	constructor(orgAlias, originalMessage)
	{
		super(`Salesforce CLI does not recognise org alias "${orgAlias}". Configure it via:\n` + `  • \`sf org login web --alias ${orgAlias}\` (web auth), or\n`
				+ `  • \`sf alias set ${orgAlias}=<existing-username>\` (map to an authenticated user), or\n`
				+ `  • update SF_SUBSCRIBER_ORG_ALIAS in your environment to point at an org you have authenticated.\n` + `Underlying error: ${originalMessage}`);
		this.name = 'NamedOrgNotFoundError';
		this.orgAlias = orgAlias;
	}
}

// Stable patterns that Salesforce CLI surfaces when an org alias is unknown.
// `sf` returns slightly different wording across versions; the union of these
// patterns has been stable since the CLI v2 rollout.
const NAMED_ORG_NOT_FOUND_PATTERNS = [
	/No\s+(?:authenticated|AuthInfo)\s+found\s+for\s+(?:name|alias)/i,
	/No\s+org\s+configuration\s+found\s+for\s+name/i,
	/NoOrgFound/,
	/NamedOrgNotFound/
];

function isNamedOrgNotFoundError(message)
{
	if(!message)
	{
		return false;
	}
	return NAMED_ORG_NOT_FOUND_PATTERNS.some(re => re.test(message));
}

function ensureStagingDir()
{
	fs.mkdirSync(CMDT_DEPLOY_DIR, {recursive: true});
	if(!fs.existsSync(STAGING_PROJECT))
	{
		fs.writeFileSync(STAGING_PROJECT, STAGING_PROJECT_CONTENT, 'utf8');
	}
}

// Shared deploy-command core: runs the given sf deploy command, classifies the
// unknown-org-alias failure into NamedOrgNotFoundError, and asserts the JSON
// result reports success. The two deploy entry points (source-format CMDT states
// vs metadata-format advisor bundles) differ only in staging and command shape.
function executeDeployCommand(command, cwd, failureLabel)
{
	let output;
	try
	{
		output = execSync(command, {encoding: 'utf8', timeout: 120_000, cwd});
	}
	catch(err)
	{
		// Surface the unknown-org case with a clear remediation message.
		// execSync throws with stderr + stdout combined; either may name the
		// org-alias-not-found condition depending on whether sf returned JSON
		// or a bare text error.
		const combined = `${err.stderr || ''}\n${err.stdout || ''}\n${err.message || ''}`;
		if(isNamedOrgNotFoundError(combined))
		{
			throw new NamedOrgNotFoundError(ORG_ALIAS, (err.stderr || err.message || '').trim());
		}
		throw err;
	}

	const result = parseSfJson(output);
	if(result.status !== 0 && result.result?.status !== 'Succeeded')
	{
		throw new Error(`${failureLabel}: ${JSON.stringify(result)}`);
	}

	return result;
}

function deployCmdtState(stateName)
{
	const stateDir = path.join(FIXTURES_DIR, stateName);
	if(!fs.existsSync(stateDir))
	{
		throw new Error(`CMDT state directory not found: ${stateDir}`);
	}

	ensureStagingDir();

	const files = fs.readdirSync(CMDT_DEPLOY_DIR);
	for(const file of files)
	{
		fs.unlinkSync(path.join(CMDT_DEPLOY_DIR, file));
	}

	const stateFiles = fs.readdirSync(stateDir);
	for(const file of stateFiles)
	{
		fs.copyFileSync(path.join(stateDir, file), path.join(CMDT_DEPLOY_DIR, file));
	}

	const sfDir = path.join(STAGING_DIR, '.sf');
	if(fs.existsSync(sfDir))
	{
		fs.rmSync(sfDir, {recursive: true, force: true});
	}

	return executeDeployCommand(`sf project deploy start -o ${ORG_ALIAS} -d "${CMDT_DEPLOY_DIR}" --ignore-conflicts --json`, STAGING_DIR,
			`CMDT deploy failed for state ${stateName}`);
}

function getAvailableStates()
{
	return fs.readdirSync(FIXTURES_DIR).filter(name =>
	{
		const fullPath = path.join(FIXTURES_DIR, name);
		return fs.statSync(fullPath).isDirectory();
	});
}

// Deletes org-local CMDT records by their <Type>.<Record> identifiers via a destructive source
// deploy from the staging project (the prior deployCmdtState() call leaves the record files staged,
// so the CLI resolves them locally and removes both the org rows and the staged copies). Section 77
// uses this to remove the deliberately colliding org-local clone — the recovery half of the
// collision-tolerance gate. Identifiers use the deployed form, e.g. 'kern__MaskingRule.MaskPaymentCard'
// (namespaced TYPE, unprefixed org-local RECORD name); a packaged record would be
// 'kern__MaskingRule.kern__MaskPaymentCard', so the two can never be confused.
function deleteCmdtRecords(recordIdentifiers)
{
	ensureStagingDir();
	const metadataArguments = recordIdentifiers.map(identifier => `-m "CustomMetadata:${identifier}"`).join(' ');
	return executeDeployCommand(`sf project delete source -o ${ORG_ALIAS} ${metadataArguments} --no-prompt --json`, STAGING_DIR,
			`CMDT delete failed for ${recordIdentifiers.join(', ')}`);
}

// Deploys a metadata-format bundle directory (package.xml + customMetadata/) with the
// exact command the Data Masking Advisor's Export modal prescribes to subscribers:
//   sf project deploy start --metadata-dir metadata -o <alias>
// run project-free from the unzipped bundle root. Section 76 uses this to round-trip
// advisor-format bundles, so the deploy path itself is part of what gets validated —
// do not reroute through the source-format staging project deployCmdtState() uses.
function deployMetadataDir(bundleDir)
{
	const metadataDir = path.join(bundleDir, 'metadata');
	if(!fs.existsSync(metadataDir))
	{
		throw new Error(`Bundle metadata directory not found: ${metadataDir}`);
	}

	return executeDeployCommand(`sf project deploy start --metadata-dir metadata -o ${ORG_ALIAS} --json`, bundleDir, `Bundle deploy failed for ${bundleDir}`);
}

// Parses `sf ... --json` stdout robustly. The CLI should emit pure JSON, but under a forced-color
// environment (e.g. Playwright sets FORCE_COLOR, which the child sf process inherits) it wraps the
// payload in ANSI escape sequences, and an occasional warning banner can prepend non-JSON text. Strip
// ANSI, then isolate the JSON object before parsing so every caller — the runner and the e2e suite —
// gets a clean result regardless of the invoking environment. Assumes object-shaped output ({ ... }),
// which every `sf project deploy start --json` response is; a top-level array would need a different slice.
function parseSfJson(rawOutput)
{
	const withoutAnsi = rawOutput.replace(/\u001B\[[0-9;]*[A-Za-z]/g, '');
	const firstBrace = withoutAnsi.indexOf('{');
	const lastBrace = withoutAnsi.lastIndexOf('}');
	const jsonSlice = (firstBrace !== -1 && lastBrace !== -1) ? withoutAnsi.slice(firstBrace, lastBrace + 1) : withoutAnsi;
	return JSON.parse(jsonSlice);
}

module.exports = {
	deployCmdtState, deployMetadataDir, deleteCmdtRecords, getAvailableStates, NamedOrgNotFoundError, isNamedOrgNotFoundError, FIXTURES_DIR, STAGING_DIR
};

// CLI entry point: `node cmdt-deployer.js <stateName>` so the RUNBOOK's
// `node release-testing/runner/cmdt-deployer.js section35-flags-disabled`
// invocation actually deploys (previously it loaded the module as no-op).
if(require.main === module)
{
	const stateName = process.argv[2];
	if(!stateName)
	{
		console.error(`Usage: node ${path.basename(__filename)} <stateName>`);
		console.error(`Available states: ${getAvailableStates().join(', ')}`);
		process.exit(1);
	}

	try
	{
		console.log(`Deploying CMDT state: ${stateName}`);
		const result = deployCmdtState(stateName);
		const jobId = result?.result?.id || result?.result?.deployUrl || '(unknown)';
		console.log(`✓ CMDT deploy succeeded (${jobId})`);
	}
	catch(err)
	{
		console.error(`✗ CMDT deploy failed: ${err.message}`);
		process.exit(1);
	}
}
