// SPDX-License-Identifier: BUSL-1.1
const {execSync} = require('child_process');
const fs = require('fs');
const {getSubscriberOrgAlias} = require('../../runner/subscriber-config');
const {ELEMENT_WAIT_MILLISECONDS} = require('./wait-times');
const {authPathsFor} = require('./auth-paths');

const ORG_ALIAS = getSubscriberOrgAlias();
const INSTANCE_CACHE_PATH = authPathsFor(ORG_ALIAS).instancePath;

function getFrontdoorUrl()
{
	const output = execSync(`sf org open -o ${ORG_ALIAS} --url-only -r`, {encoding: 'utf8', timeout: 30_000});
	const match = output.match(/https?:\/\/\S+/);
	if(!match)
	{
		throw new Error(`Could not extract frontdoor URL from sf output: ${output}`);
	}
	return match[0].trim();
}

// A frontdoor URL for another user of the same org. `sf org create user` stores that user's auth locally, so
// `sf org open` can sign in as them by username.
function getFrontdoorUrlFor(username)
{
	const output = execSync(`sf org open -o ${username} --url-only -r`, {encoding: 'utf8', timeout: 30_000});
	const match = output.match(/https?:\/\/\S+/);
	if(!match)
	{
		throw new Error(`Could not extract frontdoor URL for ${username} from sf output: ${output}`);
	}
	return match[0].trim();
}

function stripAnsi(str)
{
	// eslint-disable-next-line no-control-regex
	return str.replace(/\x1B\[[0-9;]*[a-zA-Z]/g, '');
}

function getInstanceUrl()
{
	try
	{
		const cached = JSON.parse(fs.readFileSync(INSTANCE_CACHE_PATH, 'utf8'));
		if(cached && cached.instanceUrl)
		{
			return cached.instanceUrl;
		}
	}
	catch(error)
	{
		// Cache miss — fall through to shell-out. globalSetup writes this file; when
		// tests run outside the runner (e.g. a hand-invoked single spec) the fallback
		// keeps the helper working.
		console.warn(`[sf-auth] instance cache miss (${error.code || error.name}) — falling back to sf org display`);
	}
	const output = execSync(`sf org display -o ${ORG_ALIAS} --json`, {encoding: 'utf8', timeout: 30_000, env: {...process.env, FORCE_COLOR: '0', NO_COLOR: '1'}});
	const result = JSON.parse(stripAnsi(output));
	return result.result.instanceUrl;
}

// A page signed in as another user carries its own frontdoor provider, so a re-sign-in keeps that user; every other
// page signs in as the harness admin.
async function reauthenticate(page)
{
	const frontdoorUrl = page.kernFrontdoorUrl ? page.kernFrontdoorUrl() : getFrontdoorUrl();
	await page.goto(frontdoorUrl, {waitUntil: 'domcontentloaded'});
	await page.waitForURL(url => !url.pathname.includes('/secur/frontdoor.jsp'), {timeout: 30_000});
	await page.waitForLoadState('load', {timeout: 30_000}).catch(() =>
	{
	});
	await page.locator('one-app-nav-bar, one-appnav').first()
	.waitFor({state: 'visible', timeout: ELEMENT_WAIT_MILLISECONDS}).catch(() =>
	{
	});
}

async function ensureAuthenticated(page)
{
	const url = page.url();
	const isOnSalesforcePage = (url.includes('.salesforce.com') || url.includes('.force.com')) && !url.includes('/login') && !url.includes('/secur/frontdoor');
	if(!isOnSalesforcePage)
	{
		await reauthenticate(page);
	}
}

module.exports = {ORG_ALIAS, getFrontdoorUrl, getFrontdoorUrlFor, getInstanceUrl, reauthenticate, ensureAuthenticated};
