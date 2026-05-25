// SPDX-License-Identifier: BUSL-1.1
const {clickNavTab} = require('../helpers/sf-navigation');
const {waitForSpinnerGone, pollUntil} = require('../helpers/wait-helpers');

class StreamingMonitorPage
{
	constructor(page)
	{
		this.page = page;
	}

	async navigate()
	{
		await clickNavTab(this.page, 'Kern Home');
		await waitForSpinnerGone(this.page);

		const monitorTab = this.page.locator('one-app-nav-bar-item-root a[title="Streaming Event Monitor"]');
		if(await monitorTab.isVisible().catch(() => false))
		{
			await monitorTab.click();
			await this.page.waitForTimeout(3000);
			await waitForSpinnerGone(this.page);
			return;
		}

		// Launch from the Kern Home streamingMonitor tool card. Use the data-key
		// attribute so we target the correct card — there are three "Open" buttons
		// on the page (one per tool card), so a .first() match would be ambiguous.
		const launchButton = this.page.locator('[data-testid="kern-home-root"] lightning-button[data-key="streamingMonitor"]').first();
		await launchButton.waitFor({state: 'visible', timeout: 15_000});
		await launchButton.click();
		await this.page.waitForTimeout(3000);
		await waitForSpinnerGone(this.page);
	}

	async clickSidebarAction(label)
	{
		await this.page.getByText(label, {exact: true}).click();
		await this.page.waitForTimeout(1000);
		await waitForSpinnerGone(this.page);
	}

	async clickSubscribe()
	{
		await this.clickSidebarAction('Subscribe to a channel');
	}

	async clickSubscribeToChannels()
	{
		await this.clickSidebarAction('Subscribe to channels');
	}

	async clickPublish()
	{
		await this.clickSidebarAction('Publish an event');
	}

	async selectEventType(eventType)
	{
		const combobox = this.page.locator('[data-testid="event-type"]').first();
		await combobox.locator('input, button').first().click();
		await this.page.waitForTimeout(500);
		await this.page.getByRole('option', {name: eventType}).first().click();
		await this.page.waitForTimeout(500);
		await this.page.keyboard.press('Escape');
		await this.page.waitForTimeout(1000);
	}

	async selectEventName(eventName)
	{
		const combobox = this.page.locator('[data-testid="event-name"]').first();
		await combobox.waitFor({state: 'visible', timeout: 10_000});
		await combobox.locator('input, button').first().click();
		await this.page.waitForTimeout(1000);
		await this.page.getByRole('option', {name: eventName}).first().click();
		await this.page.waitForTimeout(500);
	}

	async clickSubscribeButton()
	{
		const btn = this.page.locator('[data-testid="subscribe-button"]').first();
		await btn.evaluate(el => el.click());
		await waitForSpinnerGone(this.page);
		await this.page.waitForTimeout(3000);
	}

	async clickPublishButton()
	{
		const btn = this.page.locator('[data-testid="publish-button"]').first();
		await btn.evaluate(el => el.click());
		await waitForSpinnerGone(this.page);
		await this.page.waitForTimeout(2000);
	}

	async setPublishPayload(payload)
	{
		const container = this.page.locator('[data-testid="publish-payload"]');
		const textarea = container.locator('textarea');
		await textarea.waitFor({state: 'visible', timeout: 10_000});
		await textarea.fill(payload);
	}

	async getActiveSubscriptionCount()
	{
		const badge = this.page.locator('[data-testid="subscription-count"]');
		if(await badge.isVisible().catch(() => false))
		{
			const text = await badge.textContent();
			return parseInt(text, 10) || 0;
		}
		const subsText = this.page.getByText(/Subscriptions\s*\d+/).first();
		if(await subsText.isVisible().catch(() => false))
		{
			const text = await subsText.textContent();
			const match = text.match(/(\d+)/);
			return match ? parseInt(match[1], 10) : 0;
		}
		const items = this.page.locator('[data-testid="subscription-item"]');
		return items.count();
	}

	async getSubscriptionChannels()
	{
		const channels = this.page.locator('[data-testid="subscription-channel"]');
		if(await channels.first().isVisible().catch(() => false))
		{
			return channels.allTextContents();
		}
		return [];
	}

	async clickUnsubscribeAll()
	{
		const btn = this.page.locator('[data-testid="unsubscribe-all"]')
		.or(this.page.getByRole('button', {name: /Unsubscribe/i}))
		.first();
		await btn.click();
		await this.page.waitForTimeout(1000);
	}

	async getEventCount()
	{
		const showingText = this.page.getByText(/Showing \d+ event/).first();
		if(await showingText.isVisible().catch(() => false))
		{
			const text = await showingText.textContent();
			const match = text.match(/Showing (\d+)/);
			return match ? parseInt(match[1], 10) : 0;
		}
		const events = this.page.locator('[data-testid="event-row"]');
		return events.count();
	}

	async waitForEvent({channel, type, timeout = 15_000} = {})
	{
		return pollUntil(this.page, async() =>
		{
			const count = await this.getEventCount();
			return count > 0;
		}, {interval: 2000, timeout, message: `Waiting for event (channel=${channel}, type=${type})`});
	}

	async clickEventRow(index = 0)
	{
		await this.page.locator('[data-testid="event-row"]').nth(index).click();
		await this.page.waitForTimeout(500);
	}

	async getEventPayload()
	{
		return this.page.locator('[data-testid="event-payload"]').textContent().catch(() => '');
	}

	async toggleFilter()
	{
		const filterBtn = this.page.locator('[data-testid="filter-toggle"]')
		.or(this.page.getByRole('button', {name: /filter/i}))
		.first();
		await filterBtn.click();
		await this.page.waitForTimeout(500);
	}

	async selectFilterChannel(channel)
	{
		const filterChannel = this.page.locator('[data-testid="filter-channel"]')
		.or(this.page.locator('lightning-combobox').filter({hasText: /channel/i}).first())
		.first();
		await filterChannel.locator('input, button').first().click();
		await this.page.getByRole('option', {name: channel}).click();
		await this.page.waitForTimeout(500);
	}

	async clearFilter()
	{
		const btn = this.page.locator('[data-testid="filter-clear"]')
		.or(this.page.getByRole('button', {name: 'Clear'}))
		.first();
		await btn.click();
		await this.page.waitForTimeout(500);
	}

	async toggleViewMode()
	{
		const toggle = this.page.locator('[data-testid="view-toggle"]')
		.or(this.page.getByRole('button', {name: /view|toggle|timeline|table/i}))
		.first();
		await toggle.click();
		await this.page.waitForTimeout(500);
	}

	async clickDownload()
	{
		const btn = this.page.locator('[data-testid="download-button"]')
		.or(this.page.getByRole('button', {name: /download|export/i}))
		.first();
		await btn.click();
		await this.page.waitForTimeout(500);
	}

	async isDownloadVisible()
	{
		return this.page.locator('[data-testid="download-button"]')
		.or(this.page.getByRole('button', {name: /download|export/i}))
		.first().isVisible().catch(() => false);
	}

	async hasInteractiveControls()
	{
		const monitorRoot = this.page.locator('[data-testid="streaming-monitor-root"]');
		const rootVisible = await monitorRoot.isVisible().catch(() => false);
		if(!rootVisible)
		{
			return false;
		}
		const hasActions = await monitorRoot.getByText('Actions').isVisible().catch(() => false);
		const hasSubscriptions = await monitorRoot.getByText('Subscriptions').isVisible().catch(() => false);
		return hasActions && hasSubscriptions;
	}

	async clickEvents()
	{
		const monitorLink = this.page.locator('a').filter({hasText: 'Streaming Monitor'}).first();
		if(await monitorLink.isVisible().catch(() => false))
		{
			await monitorLink.click();
			await this.page.waitForTimeout(2000);
			await waitForSpinnerGone(this.page);
		}
	}

	async getEventNameOptions()
	{
		const combobox = this.page.locator('[data-testid="event-name"]').first();
		await combobox.waitFor({state: 'visible', timeout: 10_000});
		await combobox.locator('input, button').first().click();
		await this.page.waitForTimeout(1000);
		const options = await this.page.getByRole('option').allTextContents();
		await this.page.keyboard.press('Escape');
		await this.page.waitForTimeout(500);
		return options;
	}

	async clearEvents()
	{
		const btn = this.page.locator('[data-testid="clear-button"]')
		.or(this.page.getByRole('button', {name: 'Clear'}))
		.first();
		await btn.click();
		await this.page.waitForTimeout(500);
	}
}

module.exports = StreamingMonitorPage;
