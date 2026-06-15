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

		// The harness ships a CDC-enabled SubscriberCdcProbe__c (selected on the standard
		// ChangeEvents channel), so its change event surfaces in the CDC dropdown. The option
		// label is the __ChangeEvent entity's own label — 'Change Event: <object label>' —
		// passed through unmodified (CTRL_EventMonitor.addChangeEventDefinition).
		await monitor.clickSubscribe();
		await monitor.selectEventType('Change Data Capture event');
		await monitor.selectEventName('Change Event: Subscriber CDC Probe');
		await monitor.clickSubscribeButton();

		const subCount = await monitor.getActiveSubscriptionCount();
		expect(subCount, 'Should have at least 1 CDC subscription').toBeGreaterThanOrEqual(1);
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

	test('V23: Trigger CDC Event via SubscriberCdcProbe Insert', async({page}) =>
	{
		test.setTimeout(120_000);
		await navigateToApp(page, 'Kern');
		const monitor = new StreamingMonitorPage(page);
		await monitor.navigate();

		// Subscribe to the probe's CDC change event. Re-subscribing is idempotent and covers the
		// case where navigating back into the monitor re-mounted it and dropped V21's subscription.
		await monitor.clickSubscribe();
		await monitor.selectEventType('Change Data Capture event');
		await monitor.selectEventName('Change Event: Subscriber CDC Probe');
		await monitor.clickSubscribeButton();

		const subCount = await monitor.getActiveSubscriptionCount();
		expect(subCount, 'CDC subscription must be active before the probe insert').toBeGreaterThanOrEqual(1);

		// Let the CometD/EMP handshake fully establish before inserting: with replay -1 the
		// monitor only receives events published after the subscription is live.
		await page.waitForTimeout(4000);

		const beforeCount = await monitor.getEventCount();

		// Inserting a probe makes the platform emit a CREATE change event on
		// /data/SubscriberCdcProbe__ChangeEvent, delivered to the monitor's EMP subscription.
		// Asserting an increase (not merely > 0) keeps the check meaningful even when earlier
		// subscriptions left events on screen.
		executeAnonymousApex('insert new SubscriberCdcProbe__c(Name = \'CDC Streaming Test\', ProbeLabel__c = \'E2E_V23\');');

		let afterCount = beforeCount;
		for(let attempt = 0; attempt < 20 && afterCount <= beforeCount; attempt++)
		{
			await page.waitForTimeout(2000);
			afterCount = await monitor.getEventCount();
		}

		test.info().annotations.push({type: 'notes', description: `CDC events before=${beforeCount} after=${afterCount}`});
		expect(afterCount, 'Probe insert should deliver a CDC change event to the monitor').toBeGreaterThan(beforeCount);
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
