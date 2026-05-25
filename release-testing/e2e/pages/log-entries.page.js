// SPDX-License-Identifier: BUSL-1.1
const {expect} = require('@playwright/test');
const {clickNavTab} = require('../helpers/sf-navigation');
const {waitForListView, waitForRecordPage} = require('../helpers/wait-helpers');

class LogEntriesPage
{
	constructor(page)
	{
		this.page = page;
	}

	async navigate()
	{
		await clickNavTab(this.page, 'Log Entries');
		await waitForListView(this.page);
		const hasRecords = await this.page.locator('table tbody tr th a').first()
		.waitFor({state: 'visible', timeout: 5000}).then(() => true).catch(() => false);
		if(!hasRecords)
		{
			await this.switchToAllListView();
		}
	}

	async switchToAllListView()
	{
		const viewPicker = this.page.locator('a[role="button"], button').filter({hasText: /Recently Viewed/}).first();
		await viewPicker.click({timeout: 5000}).catch(async() =>
		{
			await this.page.locator('.triggerLinkTextAndIconWrapper, .listviewDisplayName, .forceListViewManagerHeader a').first().click();
		});
		const options = this.page.locator('ul[role="listbox"] li, ul.listContent li');
		await options.first().waitFor({state: 'visible', timeout: 5_000}).catch(() => {});
		const allOption = options.filter({hasText: /All/i}).first();
		await allOption.click().catch(async() =>
		{
			await options.first().click();
		});
		await waitForListView(this.page);
	}

	async getRecordCount()
	{
		const countText = await this.page.locator('span.countSortedByFilteredBy, span.count').first().textContent().catch(() => '0');
		const match = countText.match(/(\d+)/);
		return match ? parseInt(match[1], 10) : 0;
	}

	async hasRecords()
	{
		return (await this.getRecordCount()) > 0;
	}

	async openFirstRecord()
	{
		const firstLink = this.page.locator('table tbody tr th a').first();
		await firstLink.click();
		await waitForRecordPage(this.page);
	}

	async openRecordByLevel(level)
	{
		const row = this.page.locator(`table tbody tr`).filter({hasText: level}).first();
		const link = row.locator('th a').first();
		await link.click();
		await waitForRecordPage(this.page);
	}

	async getRecordTabs()
	{
		const tabs = this.page.locator('lightning-tab-bar li a, article lightning-tab-bar a');
		await tabs.first().waitFor({state: 'visible', timeout: 15_000}).catch((error) =>
		{
			console.warn(`log-entries: tab bar did not become visible within 15s: ${error.message}`);
		});
		return tabs.allTextContents();
	}

	async clickRecordTab(tabName)
	{
		const tab = this.page.getByRole('tab', {name: tabName});
		await tab.click();
		await expect.poll(() => tab.getAttribute('aria-selected'), {timeout: 5_000}).toBe('true');
	}

	async hasMultipleLogLevels()
	{
		const rows = this.page.locator('table tbody tr');
		const count = await rows.count();
		const levels = new Set();
		for(let i = 0; i < Math.min(count, 20); i++)
		{
			const text = await rows.nth(i).textContent();
			for(const level of [
				'ERROR',
				'WARN',
				'INFO',
				'DEBUG'
			])
			{
				if(text.includes(level))
				{
					levels.add(level);
				}
			}
		}
		return levels.size > 1;
	}
}

module.exports = LogEntriesPage;
