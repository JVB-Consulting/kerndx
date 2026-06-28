// SPDX-License-Identifier: BUSL-1.1
// Stills capture spec (the `stills` Playwright project). Each test navigates to one admin surface and
// writes a single full-viewport screenshot to release-testing/test-results/stills/<name>.png. NOT a
// pass/fail gate — the screenshot is the deliverable; process-stills.js then sizes each into
// docs-site/assets/stills/. Determinism comes from the demo seeds (capture-seed + capture-stills-seed),
// the managed subscriber install (kern__ namespace), and direct ?filterName= list-view navigation
// (the default "Recently Viewed" list is empty), not real-time waits.
const {test} = require('@playwright/test');
const fs = require('fs');
const path = require('path');
const {getInstanceUrl} = require('../helpers/sf-auth');
const {waitForSpinnerGone} = require('../helpers/wait-helpers');

const STILLS_DIR = path.join(__dirname, '..', '..', 'test-results', 'stills');

async function shot(page, name)
{
	fs.mkdirSync(STILLS_DIR, {recursive: true});
	await page.screenshot({path: path.join(STILLS_DIR, `${name}.png`)});
}

// Close any transient app-shell toast (e.g. the "this app is invalid, taking you to your default
// app" redirect notice that can flash on a direct deep-link into the Kern app) so it is never baked
// into a screenshot. Best-effort: clicking a toast's close button, then waiting for it to clear.
async function dismissToasts(page)
{
	const closers = page.locator('.slds-notify_toast button[title="Close"], .toastContainer button[title="Close"], .forceToastMessage button[title="Close"], .slds-notify__close button');
	const count = await closers.count().catch(() => 0);
	for(let i = 0; i < count; i++)
	{
		await closers.nth(i).click({timeout: 1500}).catch(() => {});
	}
	await page.locator('.slds-notify_toast, .forceToastMessage').first().waitFor({state: 'hidden', timeout: 6000}).catch(() => {});
}

// Jump straight to a named list view via the URL filter — avoids the (empty) default "Recently
// Viewed" list and the picker entirely, so a populated view renders deterministically.
async function gotoListView(page, objectApiName, filterName)
{
	await page.goto(`${getInstanceUrl()}/lightning/o/${objectApiName}/list?filterName=${filterName}`, {waitUntil: 'domcontentloaded'});
	await waitForSpinnerGone(page);
}

test.describe('admin-tool stills', () =>
{
	test('kern-home', async({page}) =>
	{
		await page.goto(`${getInstanceUrl()}/lightning/app/kern__Kern`, {waitUntil: 'domcontentloaded'});
		await waitForSpinnerGone(page);
		await page.locator('[data-testid="kern-home-root"]').first().waitFor({state: 'visible', timeout: 30000});
		// Let the readiness banner finish running its checks (it renders Action required / Review
		// recommended rows on an unconfigured org), then clear any app-shell toast before the shot.
		await page.waitForTimeout(2500);
		await dismissToasts(page);
		await page.waitForTimeout(1200);
		await dismissToasts(page);
		await shot(page, 'kern-home');
	});

	test('org-limits', async({page}) =>
	{
		await page.goto(`${getInstanceUrl()}/lightning/n/kern__StreamingEventMonitor`, {waitUntil: 'domcontentloaded'});
		await waitForSpinnerGone(page);
		await page.locator('[data-testid="streaming-monitor-root"]').first().waitFor({state: 'visible', timeout: 30000});
		await page.getByText('Org limits', {exact: true}).click();
		await waitForSpinnerGone(page);
		await page.locator('c-org-limits').first().waitFor({state: 'visible', timeout: 20000}).catch(() => {});
		await page.waitForTimeout(2800);
		await shot(page, 'org-limits');
	});

	test('event-usage', async({page}) =>
	{
		await page.goto(`${getInstanceUrl()}/lightning/n/kern__StreamingEventMonitor`, {waitUntil: 'domcontentloaded'});
		await waitForSpinnerGone(page);
		await page.locator('[data-testid="streaming-monitor-root"]').first().waitFor({state: 'visible', timeout: 30000});
		await page.getByText('Event usage metrics', {exact: true}).click();
		await waitForSpinnerGone(page);
		await page.locator('c-streaming-usage-metrics').first().waitFor({state: 'visible', timeout: 20000}).catch(() => {});
		await page.waitForTimeout(3200);
		await shot(page, 'event-usage');
	});

	test('log-entry', async({page}) =>
	{
		await gotoListView(page, 'kern__LogEntry__c', 'kern__AllLogEntries');
		const firstLink = page.locator('table tbody tr th a').first();
		await firstLink.waitFor({state: 'visible', timeout: 25000});
		await firstLink.click();
		await waitForSpinnerGone(page);
		await page.waitForTimeout(2600);
		await shot(page, 'log-entry');
	});

	test('api-calls-picker', async({page}) =>
	{
		// Land on a populated view, then open the LIST-VIEW switcher (the "All" control beside the page
		// title, NOT the Setup gear in the top nav) so the still shows the ready-made views (Today's
		// Calls / Today's Failed Calls / Dead Letters) over a real call history.
		await gotoListView(page, 'kern__ApiCall__c', 'kern__AllDetail');
		await page.locator('table tbody tr').first().waitFor({state: 'visible', timeout: 25000}).catch(() => {});
		await dismissToasts(page);
		const picker = page.locator('button[title^="Select a List View"]').first();
		await picker.waitFor({state: 'visible', timeout: 15000});
		await picker.click();
		await page.waitForTimeout(1800);
		await shot(page, 'api-calls-picker');
	});

	test('api-issues-queue', async({page}) =>
	{
		// The installed package's "Requests Failed Today" view predates the filter fix, so use the All
		// view — it shows the open issues (the triage queue) regardless of the packaged view's filter.
		await gotoListView(page, 'kern__ApiIssue__c', 'kern__All');
		await page.locator('table tbody tr').first().waitFor({state: 'visible', timeout: 25000}).catch(() => {});
		await page.waitForTimeout(2200);
		await shot(page, 'api-issues-queue');
	});

	test('async-timeline', async({page}) =>
	{
		await gotoListView(page, 'kern__AsyncChainExecution__c', 'kern__All');
		const row = page.locator('table tbody tr').filter({hasText: 'Nightly Account Sync'}).first();
		const link = row.locator('th a, a').first();
		await link.waitFor({state: 'visible', timeout: 25000});
		await link.click();
		await waitForSpinnerGone(page);
		await page.waitForTimeout(2800);
		await shot(page, 'async-timeline');
	});
});
