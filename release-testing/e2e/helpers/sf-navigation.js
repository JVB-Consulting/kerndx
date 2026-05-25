// SPDX-License-Identifier: BUSL-1.1
const {ensureAuthenticated, getInstanceUrl} = require('./sf-auth');

const APP_PATHS = {
	'Kern': 'kern__Kern'
};

let cachedInstanceUrl = null;

function resolveInstanceUrl()
{
	if(!cachedInstanceUrl)
	{
		cachedInstanceUrl = getInstanceUrl();
	}
	return cachedInstanceUrl;
}

async function navigateToApp(page, appName)
{
	await ensureAuthenticated(page);
	const instanceUrl = resolveInstanceUrl();
	const appPath = APP_PATHS[appName] || appName;
	await page.goto(`${instanceUrl}/lightning/app/${appPath}`, {waitUntil: 'domcontentloaded'});
	await waitForLightningReady(page);
}

async function navigateToAppItem(page, itemName)
{
	await ensureAuthenticated(page);
	const instanceUrl = resolveInstanceUrl();
	await page.goto(`${instanceUrl}/lightning/o/${itemName}/list`, {waitUntil: 'domcontentloaded'});
	await waitForLightningReady(page);
}

async function clickNavTab(page, tabName)
{
	await ensureAuthenticated(page);
	const tab = page.locator(`one-app-nav-bar-item-root a[title="${tabName}"]`);
	await tab.waitFor({state: 'visible', timeout: 15_000});
	await tab.click();
	await waitForPageLoad(page);
}

async function navigateToSetup(page, setupPath)
{
	const instanceUrl = resolveInstanceUrl();
	await page.goto(`${instanceUrl}/lightning/setup/${setupPath}`, {waitUntil: 'domcontentloaded'});
	await waitForPageLoad(page);
}

async function navigateToSetupPage(page, label)
{
	const setupPaths = {
		'Custom Metadata Types': 'CustomMetadata/home', 'Change Data Capture': 'CdcObjectEnablement/home', 'Scheduled Jobs': 'ScheduledJobs/home', 'Apex Jobs': 'AsyncApexJobs/home'
	};

	const path = setupPaths[label];
	if(!path)
	{
		throw new Error(`Unknown setup page: ${label}`);
	}
	await navigateToSetup(page, path);
}

async function waitForLightningReady(page)
{
	await page.waitForLoadState('domcontentloaded');
	await page.locator('one-app-nav-bar, one-appnav').first()
	.waitFor({state: 'attached', timeout: 30_000});
	await page.locator('one-app-nav-bar a, one-appnav a').first()
	.waitFor({state: 'visible', timeout: 15_000});
}

async function waitForPageLoad(page)
{
	await page.waitForLoadState('domcontentloaded');
	await page.locator('.oneAlohaPage, .oneWorkspace, records-lwc-highlights-panel, records-record-layout-event-broker, force-list-view-manager-grid, lst-list-view-manager-header, [data-testid="kern-home-root"]')
	.first()
	.waitFor({state: 'attached', timeout: 5_000})
	.catch(() =>
	{
	});
}

async function getBaseUrl(page)
{
	return page.url().match(/https?:\/\/[^/]+/)?.[0] || '';
}

module.exports = {
	navigateToApp, navigateToAppItem, clickNavTab, navigateToSetup, navigateToSetupPage, waitForLightningReady, waitForPageLoad, getBaseUrl
};
