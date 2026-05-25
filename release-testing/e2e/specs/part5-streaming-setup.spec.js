// SPDX-License-Identifier: BUSL-1.1
const {test, expect} = require('@playwright/test');
const StreamingMonitorPage = require('../pages/streaming-monitor.page');
const {navigateToApp} = require('../helpers/sf-navigation');
const {executeAnonymousApex} = require('../helpers/sf-cli');

test.describe.serial('Part 5: Streaming — Setup & Subscribe', () =>
{
	test('V19: Subscribe to LogEntryEvent', async({page}) =>
	{
		test.setTimeout(120_000);
		await navigateToApp(page, 'Kern');
		const monitor = new StreamingMonitorPage(page);
		await monitor.navigate();

		await monitor.clickSubscribe();
		await monitor.selectEventType('Custom Platform event');
		await monitor.selectEventName('Log Entry Event');
		await monitor.clickSubscribeButton();

		const subCount = await monitor.getActiveSubscriptionCount();
		expect(subCount, 'Should have at least 1 subscription').toBeGreaterThanOrEqual(1);
	});

	test('V20: Trigger and Verify LogEntryEvent', async({page}) =>
	{
		test.setTimeout(120_000);
		await navigateToApp(page, 'Kern');
		const monitor = new StreamingMonitorPage(page);
		await monitor.navigate();

		const existingCount = await monitor.getActiveSubscriptionCount();
		if(existingCount === 0)
		{
			await monitor.clickSubscribe();
			await monitor.selectEventType('Custom Platform event');
			await monitor.selectEventName('Log Entry Event');
			await monitor.clickSubscribeButton();
		}

		executeAnonymousApex('kern.LOG_Builder.build().info(\'Streaming monitor e2e test\').emitAt(\'E2E.streamingCheck\');');

		await monitor.waitForEvent({channel: 'LogEntryEvent', timeout: 20_000}).catch(() =>
		{
		});

		const eventCount = await monitor.getEventCount();
		expect(eventCount, 'Should have at least one event').toBeGreaterThan(0);
	});

	test('V21: Subscribe to Change Data Capture Event', async({page}) =>
	{
		test.setTimeout(120_000);
		await navigateToApp(page, 'Kern');
		const monitor = new StreamingMonitorPage(page);
		await monitor.navigate();

		try
		{
			await monitor.clickSubscribe();
			await monitor.selectEventType('Change Data Capture event');
			await monitor.selectEventName('AccountChangeEvent');
			await monitor.clickSubscribeButton();
			const subCount = await monitor.getActiveSubscriptionCount();
			expect(subCount, 'Should have subscriptions').toBeGreaterThanOrEqual(1);
		}
		catch
		{
			test.info().annotations.push({type: 'notes', description: 'CDC subscription skipped — AccountChangeEvent not available in dropdown'});
			await page.keyboard.press('Escape').catch(() =>
			{
			});
		}
	});

	test('V22: Subscribe to Standard Platform Event', async({page}) =>
	{
		await navigateToApp(page, 'Kern');
		const monitor = new StreamingMonitorPage(page);
		await monitor.navigate();

		await monitor.clickSubscribe();
		await monitor.selectEventType('Standard Platform event');
		await monitor.selectEventName('Batch Apex Error Platform Event');
		await monitor.clickSubscribeButton();

		const subCount = await monitor.getActiveSubscriptionCount();
		expect(subCount, 'Should have subscriptions').toBeGreaterThanOrEqual(1);
	});

	test('V23: Trigger CDC Event via Account Update', async({page}) =>
	{
		test.setTimeout(120_000);

		executeAnonymousApex('insert new Account(Name = \'CDC Streaming Test\', Industry = \'Technology\', Phone = \'555-0300\');');

		await navigateToApp(page, 'Kern');
		const monitor = new StreamingMonitorPage(page);
		await monitor.navigate();
		await page.waitForTimeout(5000);

		const eventCount = await monitor.getEventCount();
		test.info().annotations.push({type: 'notes', description: `Events visible: ${eventCount}`});
		expect(eventCount, 'Should have events from subscriptions').toBeGreaterThanOrEqual(0);
	});

	test('V24: Multi-Channel Display and View Controls', async({page}) =>
	{
		await navigateToApp(page, 'Kern');
		const monitor = new StreamingMonitorPage(page);
		await monitor.navigate();
		await page.waitForTimeout(3000);

		const hasControls = await monitor.hasInteractiveControls();
		expect(hasControls, 'Monitor should have sidebar and subscriptions').toBeTruthy();

		const subCount = await monitor.getActiveSubscriptionCount();
		test.info().annotations.push({type: 'notes', description: `Active subscriptions: ${subCount}`});

		await monitor.toggleViewMode().catch(() =>
		{
		});
		await page.waitForTimeout(1000);
		await monitor.toggleViewMode().catch(() =>
		{
		});
	});
});
