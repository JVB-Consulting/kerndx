// SPDX-License-Identifier: BUSL-1.1
const {ensureAuthenticated, getInstanceUrl} = require('./sf-auth');
const {ELEMENT_WAIT_MILLISECONDS} = require('./wait-times');

// The packaged application's developer name is Console (label "Kern"), so the app URL path is
// kern__Console on the subscriber org and c__Console on an org holding the source without a namespace.
// Navigating by an unknown path silently lands in the org-default app, which is exactly the failure
// mode this map exists to prevent.
const APP_DEVELOPER_NAMES = {
	'Kern': 'Console'
};

function appPathFor(appName)
{
	const developerName = APP_DEVELOPER_NAMES[appName];
	if(!developerName)
	{
		return appName;
	}
	// Lazy: sf-namespace reaches the org through sf-cli, which needs sf-auth loaded first.
	const {namespacePrefix} = require('./sf-namespace');
	return `${namespacePrefix() || 'c__'}${developerName}`;
}

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
	const appPath = appPathFor(appName);
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
	// The packaged tabs render in the Kern app's nav bar only. Pools that stopped defaulting the
	// org into that app leave bare or cross-app contexts without the tab, so hop into the app first.
	const visible = await tab.waitFor({state: 'visible', timeout: 5_000}).then(() => true, () => false);
	if(!visible)
	{
		await navigateToApp(page, 'Kern');
		await tab.waitFor({state: 'visible', timeout: ELEMENT_WAIT_MILLISECONDS});
	}
	await tab.click();
	await waitForPageLoad(page);
}

async function clickOtherNavTab(page, excludeTitle)
{
	// An SPA step off the current page via whichever tab the CURRENT nav bar offers. Exists for
	// state-sensitive journeys (V128) that must not reload: an app hop rebuilds the page, and a
	// rebuilt component legitimately resets its once-per-link state.
	await ensureAuthenticated(page);
	const other = page.locator(`one-app-nav-bar-item-root a:not([title="${excludeTitle}"])`).first();
	await other.waitFor({state: 'visible', timeout: ELEMENT_WAIT_MILLISECONDS});
	await other.click();
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
	.waitFor({state: 'visible', timeout: ELEMENT_WAIT_MILLISECONDS});
}

async function waitForPageLoad(page)
{
	await page.waitForLoadState('domcontentloaded');
	await page.locator(
			'.oneAlohaPage, .oneWorkspace, records-lwc-highlights-panel, records-record-layout-event-broker, force-list-view-manager-grid, lst-list-view-manager-header, [data-testid="kern-home-root"]')
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
	navigateToApp, navigateToAppItem, clickNavTab, clickOtherNavTab, navigateToSetup, navigateToSetupPage, waitForLightningReady, waitForPageLoad, getBaseUrl
};
