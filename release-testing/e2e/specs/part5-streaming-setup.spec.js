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
		// ChangeEvents channel), so its change event surfaces in the CDC dropdown. Custom change
		// events are grouped under a label-sourced 'Custom: ' prefix
		// (CTRL_EventMonitor.addChangeEventDefinition), so the option reads 'Custom: ' followed by
		// the entity's own 'Change Event: <object label>' label. The channel value stays the
		// unmodified __ChangeEvent api name.
		await monitor.clickSubscribe();
		await monitor.selectEventType('Change Data Capture event');
		await monitor.selectEventName('Custom: Change Event: Subscriber CDC Probe');
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

	test('V104: Org Limits card grid renders worst-first with colour bands', async({page}) =>
	{
		test.setTimeout(120_000);
		await navigateToApp(page, 'Kern');
		const monitor = new StreamingMonitorPage(page);
		await monitor.navigate();
		await monitor.navigateToOrgLimits();

		const cardCount = await monitor.getOrgLimitCardCount();
		expect(cardCount, 'Org limits grid should render at least one card').toBeGreaterThan(0);

		// Every card carries a progress bar and a "<used> of <max>" usage line.
		const firstCard = monitor.orgLimitCards().first();
		await expect(firstCard.locator('[data-testid="limit-bar"]'), 'Each card has a limit bar').toBeVisible();
		await expect(firstCard.locator('.limit-usage'), 'Each card shows a used-of-max usage line').toContainText(/ of /);

		// Worst-first default sort: the per-card percentages are non-increasing down the grid.
		const percentages = await monitor.getOrgLimitPercentages();
		expect(percentages.length, 'Every card exposes an aria-valuenow percentage').toBe(cardCount);
		const sortedDescending = [...percentages].sort((first, second) => second - first);
		expect(percentages, 'Cards should be ordered worst → best usage').toEqual(sortedDescending);

		// Colour bands render; band correctness at every 69/70/89/90/100 boundary is proven in Jest,
		// since a live scratch org cannot be seeded to a specific consumption. Assert the red band only
		// when a real limit actually sits at >= 90%.
		const levels = await monitor.getOrgLimitLevels();
		expect(levels.length, 'Every card carries a colour band level').toBe(cardCount);
		expect(levels.every((level) => ['green', 'amber', 'red'].includes(level)), 'Bands are green/amber/red').toBeTruthy();
		if(percentages[0] >= 90)
		{
			expect(levels[0], 'A limit at >= 90% renders the red band').toBe('red');
		}
	});

	test('V105: Org Limits sort and search controls filter the grid', async({page}) =>
	{
		test.setTimeout(120_000);
		await navigateToApp(page, 'Kern');
		const monitor = new StreamingMonitorPage(page);
		await monitor.navigate();
		await monitor.navigateToOrgLimits();

		const totalCards = await monitor.getOrgLimitCardCount();
		expect(totalCards, 'Grid should start populated').toBeGreaterThan(0);

		// Sort by name (A–Z) reorders the grid alphabetically by the visible (prettified) name.
		await monitor.sortOrgLimitsBy('Name');
		const names = await monitor.getOrgLimitNames();
		const alphabetical = [...names].sort((first, second) => first.localeCompare(second));
		expect(names, 'Name (A–Z) sort should order cards alphabetically').toEqual(alphabetical);

		// Search narrows the grid to matching limits (every org exposes API-request limits).
		await monitor.searchOrgLimits('Api');
		const filteredCount = await monitor.getOrgLimitCardCount();
		expect(filteredCount, 'Search should not widen the grid').toBeLessThanOrEqual(totalCards);
		expect(filteredCount, 'At least one API limit should match').toBeGreaterThan(0);
		const filteredNames = await monitor.getOrgLimitNames();
		for(const name of filteredNames)
		{
			expect(name.toLowerCase(), 'Every visible card matches the search term').toContain('api');
		}

		// Clearing the search restores the full grid.
		await monitor.searchOrgLimits('');
		const restoredCount = await monitor.getOrgLimitCardCount();
		expect(restoredCount, 'Clearing the search restores every card').toBe(totalCards);
	});

	test('V114: Timeline renders events as interactive dots with tooltip and select', async({page}) =>
	{
		test.setTimeout(120_000);
		await navigateToApp(page, 'Kern');
		const monitor = new StreamingMonitorPage(page);
		await monitor.navigate();

		// Streaming subscriptions are per-browser-session, so stay self-sufficient when run standalone.
		const existingCount = await monitor.getActiveSubscriptionCount();
		if(existingCount === 0)
		{
			await monitor.clickSubscribe();
			await monitor.selectEventType('Custom Platform event');
			await monitor.selectEventName('Log Entry Event');
			await monitor.clickSubscribeButton();
			// With replay -1, an event published before the CometD handshake completes is never
			// delivered (see V23) — give the fresh subscription time to go live before the probe.
			await page.waitForTimeout(4000);
		}
		const subscribedChannels = (await monitor.getSubscriptionChannels()).map((channel) => channel.trim());
		expect(subscribedChannels.length, 'Sidebar should list at least one subscribed channel').toBeGreaterThan(0);

		// Namespace-robust probe: managed subscriber orgs expose kern.LOG_Builder; Path-2
		// (no-namespace) installs and the development org expose the bare class name.
		try
		{
			executeAnonymousApex('kern.LOG_Builder.build().info(\'Timeline e2e dot probe\').emitAt(\'E2E.timelineCheck\');');
		}
		catch(namespacedError)
		{
			test.info().annotations.push({type: 'notes', description: `kern.LOG_Builder probe failed (${namespacedError.message.split('\n')[0]}); retried with the bare class name`});
			executeAnonymousApex('LOG_Builder.build().info(\'Timeline e2e dot probe\').emitAt(\'E2E.timelineCheck\');');
		}
		await monitor.waitForEvent({timeout: 20_000}).catch(() =>
		{
		});

		// The monitor defaults to the timeline view; the native-SVG port renders one dot per event.
		const chart = page.locator('[data-spec-id="timeline-chart"]');
		await expect(chart, 'Native-SVG timeline chart renders on the default view').toBeVisible({timeout: 20_000});
		const dots = page.locator('[data-testid="timeline-dot"]');
		await expect(dots.first(), 'Timeline renders at least one interactive dot').toBeVisible({timeout: 20_000});

		// The "Showing N events" badge is load-bearing (subscriber guide + this page object) and must
		// survive the port; the timeline view must also render no table rows.
		const eventCount = await monitor.getEventCount();
		expect(eventCount, '"Showing N events" badge should still report events').toBeGreaterThan(0);
		expect(await page.locator('[data-testid="event-row"]').count(), 'Timeline view renders no table rows').toBe(0);

		// Dot hover shows the detail tooltip: time label, the exact subscribed channel (namespace
		// included — a hardcoded or stripped kern__ prefix must fail here), and the call-to-action.
		await dots.first().hover();
		const tooltip = page.locator('[data-spec-id="timeline-tooltip"]');
		await expect(tooltip, 'Dot hover shows the data tooltip').toBeVisible();
		await expect(tooltip, 'Tooltip carries a time label').toContainText(/\d{1,2}:\d{2}/);
		await expect(tooltip, 'Tooltip carries the click call-to-action').toContainText('Click for more details.');
		const tooltipText = await tooltip.textContent();
		expect(subscribedChannels.some((channel) => tooltipText.includes(channel)),
				`Tooltip should carry one of the subscribed channels verbatim (${subscribedChannels.join(', ')}); got: ${tooltipText}`).toBeTruthy();

		// Dot click dispatches `select` and opens the event-details modal with the datum's channel.
		// Target the inner section: the modal host always renders its content and toggles
		// `slds-hide` on the section, while the custom-element host is a zero-box node Playwright
		// always reports hidden. The tag alternation covers the managed-namespace render
		// (kern-modal) on subscriber orgs — the part8 chain-step-timeline precedent.
		await dots.first().click();
		const modal = page.locator('c-modal section.slds-modal, kern-modal section.slds-modal').filter({hasText: 'Event details'});
		await expect(modal, 'Dot click opens the Event details modal').toBeVisible({timeout: 10_000});
		const modalChannel = await modal.getByLabel('Channel').inputValue();
		expect(subscribedChannels, 'Modal should carry the exact subscribed channel').toContain(modalChannel);
	});
});
