// SPDX-License-Identifier: BUSL-1.1
const {test, expect} = require('@playwright/test');
const ScheduledJobsPage = require('../pages/scheduled-jobs.page');
const LogEntriesPage = require('../pages/log-entries.page');
const {navigateToApp, navigateToAppItem, navigateToSetupPage} = require('../helpers/sf-navigation');
const {waitForSpinnerGone, pollUntil} = require('../helpers/wait-helpers');
const {soqlQuery, executeAnonymousApex} = require('../helpers/sf-cli');

test.describe.serial('Part 4: Scheduler Execution', () =>
{
	test('V15: Scheduled Job Execution — Purge Records', async({page}) =>
	{
		test.setTimeout(180_000);
		await navigateToApp(page, 'Kern');
		const jobs = new ScheduledJobsPage(page);
		await jobs.navigate();

		await jobs.clickNew();
		await jobs.fillJobForm({
			name: 'Purge Test Job', className: 'SCHED_PurgeRecords', cron: '0 0 2 * * ?', isActive: true, parameters: {
				'objectName': 'kern__LogEntry__c', 'minimumNumberOfDays': '9999', 'batchSize': '200'
			}
		});
		await jobs.clickSave();
		await page.waitForTimeout(3000);

		const detail = await jobs.getDetailComponent();
		await expect(detail).toBeVisible();

		executeAnonymousApex(`
			List<CronTrigger> triggers = [SELECT Id, State FROM CronTrigger WHERE CronJobDetail.Name LIKE '%Purge Test Job%'];
			System.debug('JOB_FOUND:' + !triggers.isEmpty());
		`);

		await jobs.deleteCurrentRecord();
	});

	test('V16: Scheduled Job Execution — Login History', async({page}) =>
	{
		test.setTimeout(180_000);
		await navigateToApp(page, 'Kern');
		const jobs = new ScheduledJobsPage(page);
		await jobs.navigate();

		await jobs.clickNew();
		await jobs.fillJobForm({
			name: 'Login Stats Test', className: 'SCHED_ProcessLoginHistory', cron: '0 0 3 * * ?', isActive: true
		});
		await jobs.clickSave();
		await page.waitForTimeout(3000);

		const detail = await jobs.getDetailComponent();
		await expect(detail).toBeVisible();

		await jobs.deleteCurrentRecord();
	});

	test('V17: Verify Scheduled Jobs Clean', async({page}) =>
	{
		await navigateToApp(page, 'Kern');
		const jobs = new ScheduledJobsPage(page);
		await jobs.navigate();

		const count = await jobs.getRecordCount();
		expect(count, 'Should have 0 scheduled job records').toBe(0);
	});

	test('V18: Verify No Leftover Test Data', async({page}) =>
	{
		await navigateToAppItem(page, 'Accounts');
		await waitForSpinnerGone(page);
		await page.waitForTimeout(2000);

		const pageContent = await page.content();
		const hasTestAccount = pageContent.includes('Visual Test Account');
		expect(hasTestAccount, 'Visual Test Account should not exist').toBeFalsy();

		await navigateToApp(page, 'Kern');
		const jobs = new ScheduledJobsPage(page);
		await jobs.navigate();

		const count = await jobs.getRecordCount();
		expect(count, 'Scheduled Jobs should be empty').toBe(0);
	});
});
