// SPDX-License-Identifier: BUSL-1.1
const {chromium} = require('@playwright/test');
const {execSync} = require('child_process');
const fs = require('fs');
const {ORG_ALIAS, getFrontdoorUrl} = require('./helpers/sf-auth');
const {assertOrgIsUsable} = require('./helpers/org-health');
const {namespacePrefix} = require('./helpers/sf-namespace');
const {authPathsFor} = require('./helpers/auth-paths');

// One folder per org alias, so a run against another org from the same checkout never overwrites this run's session.
// The run-target file is read by the results reporter at the end of the run: which kind of org this run signed in to.
const {directory: AUTH_DIR, statePath: AUTH_STATE_PATH, instancePath: INSTANCE_CACHE_PATH, runTargetPath: RUN_TARGET_PATH} = authPathsFor(ORG_ALIAS);

function stripAnsi(str)
{
	// eslint-disable-next-line no-control-regex
	return str.replace(/\x1B\[[0-9;]*[a-zA-Z]/g, '');
}

// The command line exits non-zero for an alias it does not know, and still prints its answer as JSON.
function readOrgDisplay()
{
	let output;
	try
	{
		output = execSync(`sf org display -o ${ORG_ALIAS} --json`, {encoding: 'utf8', timeout: 30_000, env: {...process.env, FORCE_COLOR: '0', NO_COLOR: '1'}});
	}
	catch(error)
	{
		output = String(error.stdout || '');
	}
	try
	{
		return JSON.parse(stripAnsi(output));
	}
	catch
	{
		return null;
	}
}

// Stops here, with the org and the variable named, when the org cannot be opened: a deleted scratch org
// answers the command line without complaint and would otherwise fail later, inside the browser sign-in.
function resolveCurrentInstanceUrl()
{
	const display = readOrgDisplay();
	assertOrgIsUsable(ORG_ALIAS, display);
	return display.result.instanceUrl;
}

function invalidateStaleAuthCache(currentInstanceUrl)
{
	if(!fs.existsSync(INSTANCE_CACHE_PATH))
	{
		return;
	}
	try
	{
		const cached = JSON.parse(fs.readFileSync(INSTANCE_CACHE_PATH, 'utf8'));
		if(cached.instanceUrl === currentInstanceUrl)
		{
			return;
		}
		console.warn(`[global-setup] Cached instance URL ${cached.instanceUrl} does not match current ${currentInstanceUrl} — clearing stale auth cache.`);
	}
	catch(error)
	{
		console.warn(`[global-setup] Unreadable instance cache (${error.code || error.name}) — clearing.`);
	}
	fs.rmSync(INSTANCE_CACHE_PATH, {force: true});
	fs.rmSync(AUTH_STATE_PATH, {force: true});
}

async function globalSetup()
{
	fs.mkdirSync(AUTH_DIR, {recursive: true});
	// The last run's note must not outlive it: a run that fails before it signs in counts as a development run.
	fs.rmSync(RUN_TARGET_PATH, {force: true});

	const instanceUrl = resolveCurrentInstanceUrl();
	invalidateStaleAuthCache(instanceUrl);

	const frontdoorUrl = getFrontdoorUrl();
	const browser = await chromium.launch();
	const context = await browser.newContext({ignoreHTTPSErrors: true});
	const page = await context.newPage();

	await page.goto(frontdoorUrl, {waitUntil: 'domcontentloaded'});
	await page.waitForURL(url => !url.pathname.includes('/secur/frontdoor.jsp'), {timeout: 30_000});

	await page.goto(`${instanceUrl}/lightning/app/kern__Kern`, {waitUntil: 'domcontentloaded'});
	await page.locator('one-app-nav-bar, one-appnav').first()
	.waitFor({state: 'attached', timeout: 60_000});

	await context.storageState({path: AUTH_STATE_PATH});
	fs.writeFileSync(INSTANCE_CACHE_PATH, JSON.stringify({instanceUrl}));
	fs.writeFileSync(RUN_TARGET_PATH, JSON.stringify({namespacePrefix: namespacePrefix()}));
	await browser.close();
}

module.exports = globalSetup;
