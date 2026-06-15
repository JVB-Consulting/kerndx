// SPDX-License-Identifier: BUSL-1.1
const {clickNavTab} = require('../helpers/sf-navigation');
const {waitForListView, waitForRecordPage} = require('../helpers/wait-helpers');

class ApiCallsPage
{
	constructor(page)
	{
		this.page = page;
	}

	async navigate()
	{
		await clickNavTab(this.page, 'API Calls');
		await waitForListView(this.page);
		const hasRecords = await this.page.locator('table tbody tr th a').first()
		.waitFor({state: 'visible', timeout: 5000}).then(() => true).catch(() => false);
		if(!hasRecords)
		{
			const viewPicker = this.page.locator('button[title="Select a List View"], button:has-text("Recently Viewed")').first();
			await viewPicker.click();
			const allOption = this.page.getByRole('option', {name: /All/i}).first();
			await allOption.waitFor({state: 'visible', timeout: 5_000}).catch(() =>
			{
			});
			await allOption.click().catch(async() =>
			{
				const anyOption = this.page.locator('li[role="presentation"] a, lightning-base-combobox-item').first();
				await anyOption.click();
			});
			await waitForListView(this.page);
		}
	}

	async switchListView(viewName)
	{
		const viewSelector = this.page.locator('button.lds-button_neutral, button[title="Select a List View"]').first();
		await viewSelector.click();
		await this.page.getByRole('option', {name: viewName}).click();
		await waitForListView(this.page);
	}

	async getAvailableListViews()
	{
		const viewSelector = this.page.locator('button.lds-button_neutral, button[title="Select a List View"]').first();
		await viewSelector.click();
		const options = this.page.locator('li[role="presentation"] a, lightning-base-combobox-item');
		const views = await options.allTextContents();
		await this.page.keyboard.press('Escape');
		return views;
	}

	async hasRecords()
	{
		const rows = this.page.locator('table tbody tr');
		return (await rows.count()) > 0;
	}

	async openFirstRecord()
	{
		const firstLink = this.page.locator('table tbody tr th a').first();
		await firstLink.click();
		await waitForRecordPage(this.page);
	}

	async getRecordFields()
	{
		const fieldLabels = this.page.locator('records-record-layout-item dt, .slds-form-element__label');
		return fieldLabels.allTextContents();
	}

	async getRecordFieldValue(label)
	{
		const field = this.page.locator('records-record-layout-item').filter({hasText: label}).first();
		return field.locator('dd, .slds-form-element__control').textContent();
	}
}

module.exports = ApiCallsPage;
