// SPDX-License-Identifier: BUSL-1.1
const {chromium} = require('@playwright/test');
const {execSync} = require('child_process');
const path = require('path');
const fs = require('fs');
const {ORG_ALIAS, getFrontdoorUrl} = require('./helpers/sf-auth');

const AUTH_DIR = path.join(__dirname, '.auth');
const AUTH_STATE_PATH = path.join(AUTH_DIR, 'state.json');
const INSTANCE_CACHE_PATH = path.join(AUTH_DIR, 'instance.json');

function stripAnsi(str)
{
	return str.replace(/\x1B\[[0-9;]*[a-zA-Z]/g, '');
}

function resolveCurrentInstanceUrl()
{
	const output = execSync(`sf org display -o ${ORG_ALIAS} --json`, {encoding: 'utf8', timeout: 30_000, env: {...process.env, FORCE_COLOR: '0', NO_COLOR: '1'}});
	return JSON.parse(stripAnsi(output)).result.instanceUrl;
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
	await browser.close();
}

module.exports = globalSetup;
