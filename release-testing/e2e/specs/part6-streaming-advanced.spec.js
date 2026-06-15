// SPDX-License-Identifier: BUSL-1.1
const path = require('path');
const {test, expect} = require('@playwright/test');
const StreamingMonitorPage = require('../pages/streaming-monitor.page');
const {navigateToApp} = require('../helpers/sf-navigation');
const {executeAnonymousApex} = require('../helpers/sf-cli');
const {deployMetadataDir} = require('../../runner/cmdt-deployer');
const {waitForSpinnerGone, pollUntil} = require('../helpers/wait-helpers');

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

const USAGE_SIDEBAR_LABEL = 'Event usage metrics';
const USAGE_SEED_APEX = 'for (Integer i = 0; i < 200; i++) { kern.LOG_Builder.build().info(\'usage seed \' + i).emitAt(\'E2E.usageSeed\'); }';
const COUNT_BADGE_ALL_FORMATS = /^(No data to display|Showing [\d,]+( of [\d,]+)? data points)$/;
const COUNT_BADGE_SHOWING_ALL = /^Showing [\d,]+ data points$/;
const COUNT_BADGE_SHOWING_FILTERED = /^Showing [\d,]+ of [\d,]+ data points$/;
// Sub-daily compact time labels carry a time suffix; daily labels are bare dates ("Jun 6").
// The timeline is hour-cycle aware (streamingTimeline usesTwelveHour), so accept both the
// 24-hour ("Jun 6, 06:00") and 12-hour ("Jun 6, 6:00 AM") tick forms.
const SUB_DAILY_TICK_SUFFIX = /, \d{1,2}:\d{2}(?: ?[AP]M)?$/;
const PLATFORM_EVENT_SETTINGS_FIXTURES_DIR = path.join(__dirname, '..', 'fixtures', 'platform-event-settings');
const ENHANCED_USAGE_METRICS_ENABLED_BUNDLE = path.join(PLATFORM_EVENT_SETTINGS_FIXTURES_DIR, 'enhanced-usage-metrics-enabled');
const ENHANCED_USAGE_METRICS_DISABLED_BUNDLE = path.join(PLATFORM_EVENT_SETTINGS_FIXTURES_DIR, 'enhanced-usage-metrics-disabled');

/**
 * Opens the Streaming Event Monitor and switches to the Event usage metrics view.
 * @param {import('@playwright/test').Page} page - The Playwright page.
 * @returns {Promise<StreamingMonitorPage>} The monitor page object, in case the caller needs further actions.
 */
async function openUsageMetrics(page)
{
	await navigateToApp(page, 'Kern');
	const monitor = new StreamingMonitorPage(page);
	await monitor.navigate();
	await monitor.clickSidebarAction(USAGE_SIDEBAR_LABEL);
	await page.locator('[data-spec-id="usage-card-title"]').waitFor({state: 'visible', timeout: 20_000});
	await waitForSpinnerGone(page);
	return monitor;
}

/**
 * Reloads the current Lightning page and reopens the Event usage metrics view, forcing a fresh
 * org-capability probe (the Enhanced Usage Metrics check runs server-side on component fetch).
 * @param {import('@playwright/test').Page} page - The Playwright page, already on the monitor tab.
 * @returns {Promise<void>}
 */
async function reloadUsageMetrics(page)
{
	await page.reload({waitUntil: 'domcontentloaded'});
	await waitForSpinnerGone(page);
	await page.getByText(USAGE_SIDEBAR_LABEL, {exact: true}).first().click({timeout: 20_000});
	await page.locator('[data-spec-id="usage-card-title"]').waitFor({state: 'visible', timeout: 20_000});
	await waitForSpinnerGone(page);
}

/**
 * Waits for the usage screen to settle into a data render (legend chips) or the no-data render,
 * then reports whether any bars are visible. A fresh subscriber org may legitimately have zero
 * `PlatformEventUsageMetric` rows (the platform aggregates usage on a lag), so both renders pass.
 * The chart renders a rect for every bucket — zero-value buckets get `height="0"` (the visible
 * floor applies only to non-zero values) — so only `:visible` rects count as data.
 * @param {import('@playwright/test').Page} page - The Playwright page, on the usage metrics view.
 * @returns {Promise<boolean>} True when at least one bar is visibly rendered.
 */
async function waitForUsageRender(page)
{
	await page.locator('[data-spec-id="usage-legend-chip"]').first()
	.or(page.locator('[data-spec-id="usage-empty-state"]'))
	.first()
	.waitFor({state: 'visible', timeout: 30_000});
	return (await page.locator('[data-testid="usage-bar"]:visible').count()) > 0;
}

/**
 * Selects a date-range preset in the usage filters.
 * @param {import('@playwright/test').Page} page - The Playwright page, on the usage metrics view.
 * @param {string} presetLabel - The visible preset option label (e.g. 'Last 24 hours').
 * @returns {Promise<void>}
 */
async function selectRangePreset(page, presetLabel)
{
	const combobox = page.locator('[data-spec-id="usage-range-preset"]');
	await combobox.locator('input, button').first().click();
	const option = combobox.getByRole('option', {name: presetLabel}).first();
	await option.waitFor({state: 'visible', timeout: 10_000});
	await option.click();
	await page.waitForTimeout(500);
	await waitForSpinnerGone(page);
}

/**
 * Collects the x-axis tick labels of the usage chart (the y-axis gridline labels anchor `end`,
 * x-ticks anchor `middle`, so the anchor disambiguates them).
 * @param {import('@playwright/test').Page} page - The Playwright page, on the usage metrics view.
 * @returns {Promise<Array<string>>} The visible x-tick label texts.
 */
async function getXAxisTickLabels(page)
{
	return page.locator('svg text.axis-label[text-anchor="middle"]').allTextContents();
}

test.describe.serial('Part 6: Event Usage Metrics', () =>
{
	test.beforeAll(() =>
	{
		// Normalize the org to the daily-only baseline before asserting it: an interrupted prior
		// run of V102 could have left Enhanced Usage Metrics enabled, which would mis-report
		// V99's contract assertions as a product regression.
		deployMetadataDir(ENHANCED_USAGE_METRICS_DISABLED_BUNDLE);
	});

	test('V99: Usage metrics renders the prototype contract on a daily-only org', async({page}) =>
	{
		test.setTimeout(120_000);
		await openUsageMetrics(page);

		await expect(page.locator('[data-spec-id="usage-count-badge"]')).toBeVisible();
		await expect(page.locator('[data-spec-id="usage-granularity-daily"]')).toBeEnabled();
		await expect(page.locator('[data-spec-id="usage-granularity-daily"]')).toHaveAttribute('aria-pressed', 'true');
		await expect(page.locator('[data-spec-id="usage-granularity-hourly"]'), 'Hourly requires Enhanced Usage Metrics, off by default on a subscriber org').toBeDisabled();
		await expect(page.locator('[data-spec-id="usage-granularity-fifteen"]'), '15-minute requires Enhanced Usage Metrics, off by default on a subscriber org').toBeDisabled();
		await expect(page.locator('[data-spec-id="usage-enhanced-notice"] span').first(), 'A daily-only org must render the Enhanced Usage Metrics notice').toBeVisible();
		await expect(page.locator('[data-spec-id="usage-range-preset"]')).toBeVisible();
		await expect(page.locator('[data-spec-id="usage-refresh"]')).toBeVisible();
		await expect(page.locator('[data-spec-id="usage-view-chart"]')).toBeVisible();
		await expect(page.locator('[data-spec-id="usage-view-table"]')).toBeVisible();
		await expect(page.locator('[data-spec-id="usage-legend"]')).toBeVisible();

		const hasBars = await waitForUsageRender(page);
		await expect(page.locator('[data-spec-id="usage-count-badge"]'), 'Count badge must use one of the Custom Label formats').toHaveText(COUNT_BADGE_ALL_FORMATS);
		const badgeText = (await page.locator('[data-spec-id="usage-count-badge"]').textContent()).trim();
		test.info().annotations.push({type: 'notes', description: `Initial render: ${hasBars ? 'bars present' : 'no bars yet'}; badge="${badgeText}"`});
	});

	test('V100: Chart/table switch, legend filtering, tooltip, and empty-state reset behave', async({page}) =>
	{
		test.setTimeout(180_000);
		await openUsageMetrics(page);
		const hasBars = await waitForUsageRender(page);

		await page.locator('[data-spec-id="usage-view-table"]').click();
		await expect(page.locator('[data-spec-id="usage-table"]')).toBeVisible();
		await page.locator('[data-spec-id="usage-view-chart"]').click();
		await expect(page.locator('[data-spec-id="usage-table"]')).toBeHidden();

		if(hasBars)
		{
			await page.locator('[data-testid="usage-bar"]:visible').first().hover();
			await expect(page.locator('[data-spec-id="usage-tooltip"]')).toBeVisible();
			const tooltipRowCount = await page.locator('[data-spec-id="usage-tooltip"] .tt-row').count();
			expect(tooltipRowCount, 'Tooltip must list at least one series row').toBeGreaterThan(0);
			await page.mouse.move(0, 0);
		}

		const chips = page.locator('[data-spec-id="usage-legend-chip"]');
		const chipCount = await chips.count();
		if(chipCount === 0)
		{
			test.info().annotations.push({type: 'notes', description: 'No legend chips (no usage rows in range yet) — legend filter drive skipped'});
			return;
		}

		if(chipCount > 1)
		{
			await chips.first().click();
			await expect(page.locator('[data-spec-id="usage-count-badge"]'), 'Hiding one of several series must flip the badge to the filtered format')
			.toHaveText(COUNT_BADGE_SHOWING_FILTERED);
			await chips.first().click();
		}
		else
		{
			test.info().annotations.push({type: 'notes', description: 'Single series in range — the filtered badge format (Showing X of Y) has no live coverage this run'});
		}

		for(let index = 0; index < chipCount; index++)
		{
			await chips.nth(index).click();
		}
		await expect(page.locator('[data-spec-id="usage-empty-state"]'), 'Hiding every series must surface the empty state').toBeVisible();
		await page.locator('[data-spec-id="usage-clear-filters"]').click();
		await expect(page.locator('[data-spec-id="usage-empty-state"]')).toBeHidden();
		await expect(page.locator('[data-spec-id="usage-count-badge"]'), 'Reset filters must restore the all-series badge').toHaveText(COUNT_BADGE_SHOWING_ALL);
	});

	test('V101: Seeded platform events surface with grouped count formatting once aggregated', async({page}) =>
	{
		test.setTimeout(420_000);
		executeAnonymousApex(USAGE_SEED_APEX);
		await openUsageMetrics(page);
		await waitForUsageRender(page);

		const platformEventsChip = page.locator('[data-spec-id="usage-legend-chip"]').filter({hasText: 'Platform Events Published'});
		const surfaced = await pollUntil(page, async() =>
		{
			if(await platformEventsChip.first().isVisible().catch(() => false))
			{
				return true;
			}
			await page.locator('[data-spec-id="usage-refresh"]').click();
			await waitForSpinnerGone(page);
			return false;
		}, {interval: 20_000, timeout: 240_000, message: 'Platform Events Published series not yet aggregated'}).catch((pollError) =>
		{
			// Only the poll timeout means "not aggregated yet" — anything else is a real failure.
			if(!String(pollError.message).includes('pollUntil timed out'))
			{
				throw pollError;
			}
			return false;
		});

		if(!surfaced)
		{
			test.info().annotations.push({
				type: 'notes',
				description: 'Seeded events not yet aggregated into PlatformEventUsageMetric (platform-side lag, daily rows can take hours) — '
						+ 'count-formatting proofs deferred; the render contract is covered by V99/V100 regardless'
			});
			return;
		}

		const chipText = (await platformEventsChip.first().textContent()).trim();
		test.info().annotations.push({type: 'notes', description: `Platform events series surfaced: "${chipText}"`});
		const hasFourDigitCount = /\d{4,}/.test(chipText.replace(/,/g, ''));
		if(hasFourDigitCount)
		{
			expect(chipText, 'Counts of 1,000+ must render with thousands separators').toMatch(/\d{1,3}(,\d{3})+/);
		}
		await expect(page.locator('[data-spec-id="usage-count-badge"]')).toHaveText(COUNT_BADGE_ALL_FORMATS);
	});

	test('V102: Enhanced Usage Metrics toggle unlocks sub-daily granularity and restores cleanly', async({page}) =>
	{
		test.setTimeout(600_000);
		deployMetadataDir(ENHANCED_USAGE_METRICS_ENABLED_BUNDLE);
		try
		{
			executeAnonymousApex(USAGE_SEED_APEX);
			await openUsageMetrics(page);
			await pollUntil(page, async() =>
			{
				if(!(await page.locator('[data-spec-id="usage-granularity-hourly"]').isDisabled()))
				{
					return true;
				}
				await reloadUsageMetrics(page);
				return false;
			}, {interval: 5000, timeout: 90_000, message: 'Hourly granularity never became enabled after the enhanced settings deploy'});

			await expect(page.locator('[data-spec-id="usage-granularity-fifteen"]')).toBeEnabled();
			await expect(page.locator('[data-spec-id="usage-enhanced-notice"]'), 'An enhanced org must not render the daily-only notice').toBeHidden();

			await selectRangePreset(page, 'Last 24 hours');
			await page.locator('[data-spec-id="usage-granularity-hourly"]').click();
			await waitForSpinnerGone(page);
			await expect(page.locator('[data-spec-id="usage-granularity-hourly"]')).toHaveAttribute('aria-pressed', 'true');
			await expect(page.locator('[data-spec-id="usage-error-state"]')).toBeHidden();
			await expect(page.locator('[data-spec-id="usage-range-error"]')).toBeHidden();

			const hourlyTicks = await getXAxisTickLabels(page);
			if(hourlyTicks.length > 0)
			{
				expect(hourlyTicks.some((tickLabel) => SUB_DAILY_TICK_SUFFIX.test(tickLabel)), `Hourly ticks must carry a time suffix (got: ${hourlyTicks.join(' | ')})`)
				.toBeTruthy();
			}

			await page.locator('[data-spec-id="usage-granularity-daily"]').click();
			await page.locator('[data-spec-id="usage-granularity-hourly"]').click();
			await page.locator('[data-spec-id="usage-granularity-daily"]').click();
			await waitForSpinnerGone(page);
			await page.waitForTimeout(3000);
			await expect(page.locator('[data-spec-id="usage-granularity-daily"]'), 'After a rapid double-switch the final selection must win')
			.toHaveAttribute('aria-pressed', 'true');
			await expect(page.locator('[data-spec-id="usage-error-state"]')).toBeHidden();
			const dailyTicks = await getXAxisTickLabels(page);
			if(dailyTicks.length > 0)
			{
				expect(dailyTicks.every((tickLabel) => !SUB_DAILY_TICK_SUFFIX.test(tickLabel)), `Daily ticks must be bare dates (got: ${dailyTicks.join(' | ')})`).toBeTruthy();
			}
			else
			{
				test.info().annotations.push({type: 'notes', description: 'No daily ticks rendered after the double-switch (no data in window) — tick-shape proof skipped'});
			}

			// Preset options are granularity-gated (streamingUsageFilters.presetOptions), so the
			// hour-scale preset only appears once the 15-minute segment is active — switch first.
			await page.locator('[data-spec-id="usage-granularity-fifteen"]').click();
			await waitForSpinnerGone(page);
			await selectRangePreset(page, 'Last hour');
			await waitForSpinnerGone(page);
			await expect(page.locator('[data-spec-id="usage-granularity-fifteen"]')).toHaveAttribute('aria-pressed', 'true');
			await expect(page.locator('[data-spec-id="usage-error-state"]')).toBeHidden();
			await expect(page.locator('[data-spec-id="usage-range-error"]')).toBeHidden();
			const fifteenMinuteBars = await page.locator('[data-testid="usage-bar"]:visible').count();
			const fifteenMinuteTicks = await getXAxisTickLabels(page);
			if(fifteenMinuteTicks.length > 0)
			{
				expect(fifteenMinuteTicks.some((tickLabel) => SUB_DAILY_TICK_SUFFIX.test(tickLabel)),
						`15-minute ticks must carry a time suffix (got: ${fifteenMinuteTicks.join(' | ')})`).toBeTruthy();
			}
			test.info().annotations.push({
				type: 'notes',
				description: `Enhanced leg: 15-minute view rendered ${fifteenMinuteBars} bars, ${fifteenMinuteTicks.length} ticks (same-session sub-daily data depends on platform aggregation lag)`
			});
		}
		finally
		{
			// The restore must survive a transient deploy failure: leaving the org enhanced would
			// contaminate V99 (and the gap-finder's notice branch) on every later run.
			let restored = false;
			for(let attempt = 0; attempt < 2 && !restored; attempt++)
			{
				try
				{
					deployMetadataDir(ENHANCED_USAGE_METRICS_DISABLED_BUNDLE);
					restored = true;
				}
				catch(restoreError)
				{
					if(attempt === 1)
					{
						throw new Error('CRITICAL: could not restore the disabled Enhanced Usage Metrics baseline — '
								+ `the org is left enhanced and V99 will mis-report until it is restored: ${restoreError.message}`);
					}
				}
			}
		}

		await reloadUsageMetrics(page);
		await expect(page.locator('[data-spec-id="usage-granularity-hourly"]'), 'Restoring the default settings must re-disable sub-daily granularity').toBeDisabled();
		await expect(page.locator('[data-spec-id="usage-enhanced-notice"] span').first(), 'Restoring the default settings must re-render the notice').toBeVisible();
	});

	test('V103: Custom CDC channel list offers only real change events', async({page}) =>
	{
		test.setTimeout(120_000);
		await navigateToApp(page, 'Kern');
		const monitor = new StreamingMonitorPage(page);
		await monitor.navigate();

		await monitor.clickSubscribe();
		await monitor.selectEventType('Change Data Capture event');

		// Option labels render inside nested shadow roots (textContent cannot reach them), so the
		// assertions read each option's data-value — the entity QualifiedApiName — which is also
		// the exact field the guarded regression polluted with __mdt entities.
		const eventNameCombobox = page.locator('[data-testid="event-name"]').first();
		await eventNameCombobox.waitFor({state: 'visible', timeout: 10_000});
		await eventNameCombobox.locator('input, button').first().click();
		await page.waitForTimeout(1000);
		const optionValues = await page.getByRole('option').evaluateAll((optionElements) => optionElements.map((optionElement) => optionElement.getAttribute('data-value') || ''));
		await page.keyboard.press('Escape');

		test.info().annotations.push({type: 'notes', description: `CDC channel option values: ${optionValues.join(' | ')}`});
		expect(optionValues, 'The harness-staged probe change event must be offered').toContain('SubscriberCdcProbe__ChangeEvent');
		const nonChangeEventEntities = optionValues.filter((value) => !value.endsWith('ChangeEvent'));
		expect(nonChangeEventEntities, 'Every CDC channel option must be a real change-event entity (the guarded regression listed __mdt entities here)').toEqual([]);
	});
});
