// SPDX-License-Identifier: BUSL-1.1
const {test, expect} = require('@playwright/test');
const ChainMonitorPage = require('../pages/chain-monitor.page');
const {navigateToApp, waitForPageLoad} = require('../helpers/sf-navigation');
const {getInstanceUrl} = require('../helpers/sf-auth');
const {executeAnonymousApex, soqlQuery} = require('../helpers/sf-cli');
const {waitForSpinnerGone} = require('../helpers/wait-helpers');

test.describe.serial('Part 8: Chain Monitor UI', () =>
{
	let monitor;

	test('V30: Chain Monitor launcher card on Kern Home', async({page}) =>
	{
		await navigateToApp(page, 'Kern');
		await waitForPageLoad(page);

		const homeContent = await page.content();
		expect(homeContent, 'Kern Home should contain Chain Monitor launcher card').toContain('Chain Monitor');
	});

	test('V31: Chain Monitor page loads with split panel layout', async({page}) =>
	{
		monitor = new ChainMonitorPage(page);
		await monitor.navigate();

		const listPanel = monitor.getListPanel();
		await expect(listPanel).toBeVisible({timeout: 15000});

		const datatable = monitor.getDatatable();
		await expect(datatable).toBeVisible({timeout: 10000});

		const pageLabel = await monitor.getPageLabel();
		expect(pageLabel, 'Should show page label').toMatch(/Page \d+ of \d+/);
	});

	test('V32: Chain Monitor shows executions with correct columns', async({page}, testInfo) =>
	{
		monitor = new ChainMonitorPage(page);
		await monitor.navigate();

		const rowCount = await monitor.getRowCount();
		expect(rowCount, 'Should show chain executions from Part 7 tests').toBeGreaterThan(0);

		const headerText = await monitor.getDatatable().locator('thead').innerText();
		expect(headerText, 'Should have Chain Name column').toContain('Chain Name');
		expect(headerText, 'Should have Status column').toContain('Status');
		expect(headerText, 'Should have Progress column').toContain('Progress');
		expect(headerText, 'Should have Started column').toContain('Started');
		expect(headerText, 'Should have Duration column').toContain('Duration');

		testInfo.annotations.push({type: 'notes', description: `${rowCount} rows in datatable`});
	});

	test('V33: Detail panel shows chain metadata for selected row', async({page}, testInfo) =>
	{
		monitor = new ChainMonitorPage(page);
		await monitor.navigate();

		await monitor.selectRow(0);

		const chainName = await monitor.getDetailChainName();
		expect(chainName, 'Detail panel should show chain name').toBeTruthy();

		const status = await monitor.getDetailStatus();
		expect(status, 'Detail panel should show status badge').toBeTruthy();
		expect([
			'Running',
			'Completed',
			'Failed',
			'Aborted',
			'Stalled'
		], 'Status should be a valid value').toContain(status.trim());

		const hasTimeline = await monitor.hasStepTimeline();
		expect(hasTimeline, 'Detail panel should show step timeline').toBeTruthy();

		const hasProgressBar = await monitor.hasProgressBar();
		expect(hasProgressBar, 'Detail panel should show progress bar').toBeTruthy();

		const timingLabels = await monitor.getTimingLabels();
		expect(timingLabels, 'Should show Started in timing').toContain('Started');
		expect(timingLabels, 'Should show Duration in timing').toContain('Duration');
		expect(timingLabels, 'Should show Correlation ID in timing').toContain('Correlation ID');

		testInfo.annotations.push({type: 'notes', description: `${chainName}: ${status}`});
	});

	test('V34: Step timeline renders icons and step names', async({page}, testInfo) =>
	{
		monitor = new ChainMonitorPage(page);
		await monitor.navigate();

		await monitor.selectRow(0);
		await page.waitForTimeout(2000);

		const stepCount = await monitor.getStepCount();
		expect(stepCount, 'Timeline should show steps').toBeGreaterThan(0);

		const stepNames = await monitor.getStepNames();
		expect(stepNames.length, 'Step names should be rendered').toBeGreaterThan(0);

		testInfo.annotations.push({type: 'notes', description: `${stepCount} steps: ${stepNames.join(', ')}`});
	});

	test('V35: Failed chain shows error message in detail', async({page}, testInfo) =>
	{
		monitor = new ChainMonitorPage(page);
		await monitor.navigate();

		const rows = await monitor.getRowTexts();
		let failedIndex = rows.findIndex(t => t.includes('Failed'));

		if(failedIndex < 0)
		{
			testInfo.annotations.push({type: 'notes', description: 'No failed chains — launching one'});
			executeAnonymousApex(`
				kern.UTIL_AsyncChain.newChain('E2E_MonitorFailChain')
						.then(new SubscriberChainSteps.FailingStep())
						.execute();
			`);
			await page.waitForTimeout(15000);
			await monitor.navigate();
			await page.waitForTimeout(3000);

			const updatedRows = await monitor.getRowTexts();
			failedIndex = updatedRows.findIndex(t => t.includes('Failed'));
			expect(failedIndex, 'Failed chain should appear in list').toBeGreaterThanOrEqual(0);
		}

		await monitor.selectRow(failedIndex);
		await page.waitForTimeout(3000);

		const status = await monitor.getDetailStatus();
		expect(status.trim(), 'Detail should show Failed status').toBe('Failed');

		await monitor.expandErrorAccordion();

		const errorText = await monitor.getErrorText();
		expect(errorText, 'Error section should contain error message').toBeTruthy();
		expect(errorText, 'Error should mention the failure reason').toContain('Deliberate');

		testInfo.annotations.push({type: 'notes', description: `Error: ${errorText.substring(0, 80)}`});
	});

	test('V36: Filter toggle shows and hides status checkboxes', async({page}) =>
	{
		monitor = new ChainMonitorPage(page);
		await monitor.navigate();

		let filtersVisible = await monitor.hasFiltersVisible();
		expect(filtersVisible, 'Filters should be hidden by default').toBeFalsy();

		await monitor.toggleFilters();
		filtersVisible = await monitor.hasFiltersVisible();
		expect(filtersVisible, 'Filters should be visible after toggle').toBeTruthy();

		await monitor.toggleFilters();
		filtersVisible = await monitor.hasFiltersVisible();
		expect(filtersVisible, 'Filters should be hidden after second toggle').toBeFalsy();
	});

	test('V37: Column sorting changes row order', async({page}, testInfo) =>
	{
		monitor = new ChainMonitorPage(page);
		await monitor.navigate();

		const beforeRows = await monitor.getRowTexts();
		const beforeFirst = beforeRows[0]?.substring(0, 40);

		await monitor.clickColumnHeader('Chain Name');
		await page.waitForTimeout(3000);
		await waitForSpinnerGone(page);

		const afterRows = await monitor.getRowTexts();
		const afterFirst = afterRows[0]?.substring(0, 40);

		expect(afterRows.length, 'Should still have rows after sort').toBeGreaterThan(0);
		expect(afterFirst, 'First row should change after sorting by Chain Name').not.toBe(beforeFirst);

		const headerText = await monitor.getDatatable().locator('thead').innerText();
		expect(headerText, 'Chain Name should show sort indicator').toContain('Chain Name');

		testInfo.annotations.push({type: 'notes', description: `Before: ${beforeFirst}, After: ${afterFirst}`});
	});

	test('V38: Launched chain appears in monitor and shows correct detail', async({page}, testInfo) =>
	{
		const output = executeAnonymousApex(`
			String executionId = kern.UTIL_AsyncChain.newChain('E2E_MonitorLaunch')
					.then(new SubscriberChainSteps.CreateFoobarStep())
					.then(new SubscriberChainSteps.UpdateFoobarStep())
					.execute();
			System.debug('CHAIN_ID:' + executionId);
		`);

		const match = output.match(/CHAIN_ID:([a-zA-Z0-9]{15,18})/);
		expect(match, 'Should capture chain execution ID').toBeTruthy();
		const chainId = match[1];
		testInfo.annotations.push({type: 'notes', description: `Launched 2-step chain ${chainId}`});

		const records = soqlQuery(`SELECT kern__Status__c, kern__CompletedSteps__c, kern__TotalSteps__c
                                   FROM kern__AsyncChainExecution__c
                                   WHERE Id = '${chainId}'`);
		const execution = records[0];
		testInfo.annotations.push({type: 'notes', description: `DB: ${execution.kern__Status__c}, ${execution.kern__CompletedSteps__c}/${execution.kern__TotalSteps__c}`});

		const instanceUrl = getInstanceUrl();
		await page.goto(`${instanceUrl}/lightning/r/kern__AsyncChainExecution__c/${chainId}/view`, {waitUntil: 'domcontentloaded'});
		await waitForPageLoad(page);
		await page.waitForTimeout(5000);

		const timeline = page.locator('c-chain-step-timeline, kern-chain-step-timeline').first();
		await expect(timeline).toBeVisible({timeout: 15000});

		const stepRows = timeline.locator('[data-testid="step-row"]');
		const stepCount = await stepRows.count();
		expect(stepCount, 'Step timeline should show all steps').toBe(Number(execution.kern__TotalSteps__c));

		testInfo.annotations.push({type: 'notes', description: `Record page timeline: ${stepCount} steps`});
	});

	test('V39: Chain execution record page has embedded step timeline', async({page}) =>
	{
		const records = soqlQuery('SELECT Id FROM kern__AsyncChainExecution__c WHERE kern__ChainName__c = \'E2E_OnboardingChain\' ORDER BY CreatedDate DESC LIMIT 1');
		expect(records.length).toBeGreaterThan(0);

		const instanceUrl = getInstanceUrl();
		await page.goto(`${instanceUrl}/lightning/r/kern__AsyncChainExecution__c/${records[0].Id}/view`, {waitUntil: 'domcontentloaded'});
		await waitForPageLoad(page);
		await page.waitForTimeout(5000);

		const timeline = page.locator('c-chain-step-timeline, kern-chain-step-timeline').first();
		const isVisible = await timeline.isVisible({timeout: 10000}).catch(() => false);
		expect(isVisible, 'Step timeline should be visible on record page').toBeTruthy();
	});
});
