// SPDX-License-Identifier: BUSL-1.1
const {waitForSpinnerGone, pollUntil} = require('../helpers/wait-helpers');
const {getInstanceUrl} = require('../helpers/sf-auth');

class ChainMonitorPage
{
	constructor(page)
	{
		this.page = page;
	}

	async navigate()
	{
		const instanceUrl = getInstanceUrl();
		await this.page.goto(`${instanceUrl}/lightning/n/kern__ChainMonitor`, {waitUntil: 'domcontentloaded'});
		await this.page.waitForTimeout(5000);
		await waitForSpinnerGone(this.page);
	}

	getListPanel()
	{
		return this.page.locator('[data-testid="chain-monitor-list-root"]').first();
	}

	getDetailPanel()
	{
		return this.page.locator('[data-testid="chain-detail"]').first();
	}

	getDatatable()
	{
		return this.getListPanel().locator('lightning-datatable').first();
	}

	async getRowCount()
	{
		const rows = this.getDatatable().locator('tbody tr');
		return rows.count();
	}

	async getRowTexts()
	{
		const rows = this.getDatatable().locator('tbody tr');
		return rows.allInnerTexts();
	}

	async getColumnHeaders()
	{
		const headers = this.getDatatable().locator('thead th');
		const texts = await headers.allInnerTexts();
		return texts.map(t => t.trim()).filter(t => t.length > 0);
	}

	async getColumnValues(columnName)
	{
		const headers = await this.getColumnHeaders();
		const colIndex = headers.indexOf(columnName);
		if(colIndex < 0)
		{
			return [];
		}
		const rows = this.getDatatable().locator('tbody tr');
		const count = await rows.count();
		const values = [];
		for(let i = 0; i < count; i++)
		{
			const cells = rows.nth(i).locator('td, th');
			const cellTexts = await cells.allInnerTexts();
			if(cellTexts.length > colIndex)
			{
				values.push(cellTexts[colIndex].trim());
			}
		}
		return values;
	}

	async getCellValues(columnIndex)
	{
		const rows = this.getDatatable().locator('tbody tr');
		const count = await rows.count();
		const values = [];
		for(let i = 0; i < count; i++)
		{
			const cells = rows.nth(i).locator('td lightning-primitive-cell-factory');
			const cellCount = await cells.count();
			if(cellCount > columnIndex)
			{
				const text = await cells.nth(columnIndex).innerText().catch(() => '');
				values.push(text.trim());
			}
		}
		return values;
	}

	async clickColumnHeader(columnName)
	{
		const sortButton = this.getDatatable().getByRole('button', {name: `Sort by: ${columnName}`}).first();
		await sortButton.scrollIntoViewIfNeeded();
		await sortButton.click({timeout: 30000});
		await this.page.waitForTimeout(2000);
		await waitForSpinnerGone(this.page);
	}

	async selectRow(index)
	{
		const rows = this.getDatatable().locator('tbody tr');
		const row = rows.nth(index);
		const radio = row.locator('lightning-primitive-cell-checkbox, input[type="radio"]').first();
		if(await radio.isVisible().catch(() => false))
		{
			await radio.click();
		}
		else
		{
			await row.click();
		}
		await this.page.waitForTimeout(2000);
		await waitForSpinnerGone(this.page);
	}

	async getDetailChainName()
	{
		const heading = this.getDetailPanel().locator('.slds-text-heading_small').first();
		if(await heading.isVisible({timeout: 5000}).catch(() => false))
		{
			return (await heading.textContent()).trim();
		}
		return null;
	}

	async getDetailStatus()
	{
		const badge = this.getDetailPanel().locator('lightning-badge').first();
		if(await badge.isVisible({timeout: 5000}).catch(() => false))
		{
			return (await badge.textContent()).trim();
		}
		return null;
	}

	async hasProgressBar()
	{
		return this.getDetailPanel().locator('lightning-progress-bar').isVisible({timeout: 5000}).catch(() => false);
	}

	async hasStepTimeline()
	{
		const timeline = this.getDetailPanel().locator('c-chain-step-timeline, kern-chain-step-timeline').first();
		return timeline.isVisible({timeout: 5000}).catch(() => false);
	}

	async getStepCount()
	{
		const timeline = this.getDetailPanel().locator('c-chain-step-timeline, kern-chain-step-timeline').first();
		const items = timeline.locator('.slds-timeline__item_expandable, li');
		return items.count();
	}

	async getStepNames()
	{
		const timeline = this.getDetailPanel().locator('c-chain-step-timeline, kern-chain-step-timeline').first();
		const names = timeline.locator('.slds-truncate .slds-text-body_regular');
		return names.allTextContents();
	}

	async getTimingLabels()
	{
		const dtElements = this.getDetailPanel().locator('dt');
		return dtElements.allTextContents();
	}

	async expandErrorAccordion()
	{
		const detail = this.getDetailPanel();
		const errorButton = detail.getByRole('button', {name: 'Error', exact: true});
		await errorButton.scrollIntoViewIfNeeded();
		await errorButton.click({timeout: 10000});
		await this.page.waitForTimeout(2000);
	}

	async hasErrorSection()
	{
		return this.getDetailPanel().locator('.slds-theme_error').isVisible({timeout: 5000}).catch(() => false);
	}

	async getErrorText()
	{
		const errorBox = this.getDetailPanel().locator('[data-testid="error-message"]')
		.or(this.getDetailPanel().locator('.slds-theme_error'))
		.first();
		if(await errorBox.isVisible({timeout: 5000}).catch(() => false))
		{
			return (await errorBox.textContent()).trim();
		}
		return null;
	}

	async toggleFilters()
	{
		const filterBtn = this.getListPanel().locator('lightning-button-icon').first();
		await filterBtn.click();
		await this.page.waitForTimeout(500);
	}

	async hasFiltersVisible()
	{
		return this.getListPanel().locator('lightning-checkbox-group').isVisible({timeout: 2000}).catch(() => false);
	}

	async getPageLabel()
	{
		const label = this.getListPanel().locator('.slds-align-middle').first();
		if(await label.isVisible().catch(() => false))
		{
			return (await label.textContent()).trim();
		}
		return null;
	}
}

module.exports = ChainMonitorPage;
