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
const STAGING_PROJECT_CONTENT = '{"packageDirectories":[{"path":"force-app","default":true}],"name":"CmdtStaging","sourceApiVersion":"66.0"}\n';

// Dedicated subclass so callers can `instanceof` test this failure mode
// without parsing error messages. Raised when the configured ORG_ALIAS is not
// recognised by the Salesforce CLI (e.g. the alias hasn't been set up, the
// scratch org expired, or the user typoed SF_SUBSCRIBER_ORG_ALIAS).
class NamedOrgNotFoundError extends Error
{
	constructor(orgAlias, originalMessage)
	{
		super(
			`Salesforce CLI does not recognise org alias "${orgAlias}". Configure it via:\n` +
			`  • \`sf org login web --alias ${orgAlias}\` (web auth), or\n` +
			`  • \`sf alias set ${orgAlias}=<existing-username>\` (map to an authenticated user), or\n` +
			`  • update SF_SUBSCRIBER_ORG_ALIAS in your environment to point at an org you have authenticated.\n` +
			`Underlying error: ${originalMessage}`
		);
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
	if(!message) return false;
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

	let output;
	try
	{
		output = execSync(`sf project deploy start -o ${ORG_ALIAS} -d "${CMDT_DEPLOY_DIR}" --ignore-conflicts --json`, {encoding: 'utf8', timeout: 120_000, cwd: STAGING_DIR});
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

	const result = JSON.parse(output);
	if(result.status !== 0 && result.result?.status !== 'Succeeded')
	{
		throw new Error(`CMDT deploy failed for state ${stateName}: ${JSON.stringify(result)}`);
	}

	return result;
}

function getAvailableStates()
{
	return fs.readdirSync(FIXTURES_DIR).filter(name =>
	{
		const fullPath = path.join(FIXTURES_DIR, name);
		return fs.statSync(fullPath).isDirectory();
	});
}

module.exports = {
	deployCmdtState,
	getAvailableStates,
	NamedOrgNotFoundError,
	isNamedOrgNotFoundError,
	FIXTURES_DIR,
	STAGING_DIR
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
