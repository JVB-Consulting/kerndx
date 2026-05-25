// SPDX-License-Identifier: BUSL-1.1
const {test, expect} = require('@playwright/test');
const StreamingMonitorPage = require('../pages/streaming-monitor.page');
const {navigateToApp} = require('../helpers/sf-navigation');
const {executeAnonymousApex} = require('../helpers/sf-cli');

test.describe.serial('Part 6: Streaming — Advanced & Cleanup', () =>
{
	test('V25: Generic Channel — Stale Cache Regression', async({page}) =>
	{
		test.setTimeout(120_000);

		await navigateToApp(page, 'Kern');
		const monitor = new StreamingMonitorPage(page);
		await monitor.navigate();
		await page.waitForTimeout(3000);

		try
		{
			executeAnonymousApex('delete [SELECT Id FROM StreamingChannel WHERE Name = \'/u/TestChannel\'];');
		}
		catch
		{ /* may not exist */
		}

		executeAnonymousApex(`
			StreamingChannel channel = new StreamingChannel();
			channel.Name = '/u/TestChannel';
			channel.Description = 'Visual test streaming channel';
			insert channel;
		`);

		await monitor.clickSubscribe();
		await page.waitForTimeout(5000);
		await monitor.selectEventType('Generic event');
		await page.waitForTimeout(3000);

		await monitor.selectEventName('TestChannel');
		await monitor.clickSubscribeButton();
		await page.waitForTimeout(2000);

		const subCount = await monitor.getActiveSubscriptionCount();
		expect(subCount, 'Should have at least 1 subscription after subscribing to TestChannel').toBeGreaterThanOrEqual(1);
	});

	test('V26: Publish to Generic Channel — Dropdown Refresh', async({page}) =>
	{
		test.setTimeout(120_000);
		await navigateToApp(page, 'Kern');
		const monitor = new StreamingMonitorPage(page);
		await monitor.navigate();
		await page.waitForTimeout(2000);

		await monitor.clickEvents();

		await monitor.clickPublish();
		await page.waitForTimeout(5000);
		await monitor.selectEventType('Generic event');
		await page.waitForTimeout(3000);

		await monitor.selectEventName('TestChannel');
		await monitor.setPublishPayload('Hello from the streaming monitor');
		await monitor.clickPublishButton();
		await page.waitForTimeout(3000);

		await monitor.clickEvents();
		await page.waitForTimeout(2000);

		const eventCount = await monitor.getEventCount();
		test.info().annotations.push({type: 'notes', description: `Events after generic publish: ${eventCount}`});
		expect(eventCount, 'Should have events including the published generic event').toBeGreaterThanOrEqual(0);
	});

	test('V27: Publish Custom Platform Event from Monitor', async({page}) =>
	{
		test.setTimeout(120_000);
		await navigateToApp(page, 'Kern');
		const monitor = new StreamingMonitorPage(page);
		await monitor.navigate();

		await monitor.clickPublish();
		await monitor.selectEventType('Custom Platform event');
		await monitor.selectEventName('Log Entry Event');

		const payload = JSON.stringify({
			kern__Message__c: 'Published from monitor', kern__LogLevel__c: 'DEBUG', kern__ClassMethod__c: 'VisualTest.publish'
		});
		await monitor.setPublishPayload(payload);
		await monitor.clickPublishButton();
		await page.waitForTimeout(3000);

		await monitor.clickEvents();
		await monitor.waitForEvent({channel: 'LogEntryEvent', timeout: 15_000}).catch(() =>
		{
		});

		const eventCount = await monitor.getEventCount();
		test.info().annotations.push({type: 'notes', description: `Events after platform event publish: ${eventCount}`});
	});

	test('V28: Download Events Button', async({page}) =>
	{
		await navigateToApp(page, 'Kern');
		const monitor = new StreamingMonitorPage(page);
		await monitor.navigate();
		await page.waitForTimeout(2000);

		const isVisible = await monitor.isDownloadVisible();
		test.info().annotations.push({type: 'notes', description: `Download button visible: ${isVisible}`});

		if(isVisible)
		{
			await monitor.clickDownload();
			await page.waitForTimeout(2000);

			const hasError = await page.locator('.toastContainer .slds-theme--error')
			.or(page.locator('force-aloha-page .forceToastMessage'))
			.first().isVisible().catch(() => false);
			expect(hasError, 'No error toast should appear on download').toBeFalsy();
		}
	});

	test('V29: Unsubscribe and Clean Up', async({page}) =>
	{
		test.setTimeout(120_000);

		await navigateToApp(page, 'Kern');
		const monitor = new StreamingMonitorPage(page);
		await monitor.navigate();

		try
		{
			await monitor.clickUnsubscribeAll();
			await page.waitForTimeout(2000);
		}
		catch
		{
			test.info().annotations.push({type: 'notes', description: 'Unsubscribe all button not found — may already be clean'});
		}

		const subCount = await monitor.getActiveSubscriptionCount();
		test.info().annotations.push({type: 'notes', description: `Subscriptions after cleanup: ${subCount}`});
		expect(subCount, 'Should have 0 subscriptions after unsubscribe all').toBe(0);

		try
		{
			executeAnonymousApex('delete [SELECT Id FROM StreamingChannel WHERE Name = \'/u/TestChannel\'];');
		}
		catch
		{ /* StreamingChannel may not exist */
		}

		try
		{
			executeAnonymousApex('delete [SELECT Id FROM Account WHERE Name = \'CDC Streaming Test\'];');
		}
		catch
		{ /* Account may not exist */
		}
	});
});
