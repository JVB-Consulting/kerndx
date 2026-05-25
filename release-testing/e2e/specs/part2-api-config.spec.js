// SPDX-License-Identifier: BUSL-1.1
const {test, expect} = require('@playwright/test');
const ApiCallsPage = require('../pages/api-calls.page');
const ApiIssuesPage = require('../pages/api-issues.page');
const StreamingMonitorPage = require('../pages/streaming-monitor.page');
const SetupCmdtPage = require('../pages/setup-cmdt.page');
const LoginFrequenciesPage = require('../pages/login-frequencies.page');
const {navigateToApp, waitForPageLoad} = require('../helpers/sf-navigation');
const {getInstanceUrl} = require('../helpers/sf-auth');
const {soqlQuery} = require('../helpers/sf-cli');

test.describe.serial('Part 2: API Results, Config & Login', () =>
{
	test('V6: Verify Echo Call Results', async({page}) =>
	{
		const records = soqlQuery('SELECT Id, kern__ServiceName__c, kern__Status__c FROM kern__ApiCall__c ORDER BY CreatedDate DESC LIMIT 1');
		expect(records.length, 'Should have API Call records').toBeGreaterThan(0);

		const instanceUrl = getInstanceUrl();
		await page.goto(`${instanceUrl}/lightning/r/kern__ApiCall__c/${records[0].Id}/view`, {waitUntil: 'domcontentloaded'});
		await waitForPageLoad(page);

		await expect(page.getByText('Service Name')).toBeVisible({timeout: 15_000});
		await expect(page.getByText('Status', {exact: true})).toBeVisible();
		await expect(page.getByText('Direction')).toBeVisible();
	});

	test('V7: API Issues', async({page}) =>
	{
		await navigateToApp(page, 'Kern');
		const apiIssues = new ApiIssuesPage(page);
		await apiIssues.navigate();

		const loads = await apiIssues.listViewLoads();
		expect(loads, 'API Issues list view should load').toBeTruthy();

		if(await apiIssues.hasRecords())
		{
			await apiIssues.openFirstRecord();
		}
	});

	test('V8: Streaming Event Monitor UI', async({page}) =>
	{
		await navigateToApp(page, 'Kern');
		const monitor = new StreamingMonitorPage(page);
		await monitor.navigate();

		const hasControls = await monitor.hasInteractiveControls();
		expect(hasControls, 'Monitor should have sidebar and main content area').toBeTruthy();
	});

	test('V9: CMDT Configuration', async() =>
	{
		const expectedTypes = [
			{name: 'TriggerSetting__mdt', label: 'Trigger Setting'},
			{name: 'TriggerAction__mdt', label: 'Trigger Action'},
			{name: 'FeatureFlag__mdt', label: 'Feature Flag'},
			{name: 'ValidationRule__mdt', label: 'Validation Rule'}
		];

		for(const type of expectedTypes)
		{
			const records = soqlQuery(`SELECT Id, DeveloperName
                                       FROM kern__${type.name} LIMIT 5`);
			expect(records.length, `${type.label} should have CMDT records`).toBeGreaterThan(0);
			test.info().annotations.push({type: 'notes', description: `${type.label}: ${records.length} records`});
		}
	});

	test('V10: Login Frequencies', async({page}) =>
	{
		await navigateToApp(page, 'Kern');
		const loginFreq = new LoginFrequenciesPage(page);
		await loginFreq.navigate();

		const loads = await loginFreq.listViewLoads();
		expect(loads, 'Login Frequencies list view should load without error').toBeTruthy();
	});
});
