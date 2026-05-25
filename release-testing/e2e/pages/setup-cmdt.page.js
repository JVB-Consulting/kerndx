// SPDX-License-Identifier: BUSL-1.1
const {navigateToSetupPage} = require('../helpers/sf-navigation');
const {waitForSpinnerGone} = require('../helpers/wait-helpers');

class SetupCmdtPage
{
	constructor(page)
	{
		this.page = page;
	}

	async navigate()
	{
		await navigateToSetupPage(this.page, 'Custom Metadata Types');
		await waitForSpinnerGone(this.page);
	}

	async navigateToType(typeName)
	{
		const baseUrl = this.page.url().match(/https?:\/\/[^/]+/)?.[0];
		const iframe = this.page.frameLocator('iframe[name="setupFrame"]').first();
		const link = iframe.getByRole('link', {name: typeName}).first();

		if(await link.isVisible().catch(() => false))
		{
			await link.click();
		}
		else
		{
			await this.page.goto(`${baseUrl}/lightning/setup/CustomMetadata/home`, {waitUntil: 'domcontentloaded'});
			await waitForSpinnerGone(this.page);
			const retryFrame = this.page.frameLocator('iframe[name="setupFrame"]').first();
			await retryFrame.getByRole('link', {name: typeName}).first().click();
		}
		const postNavFrame = this.page.frameLocator('iframe[name="setupFrame"]').first();
		await postNavFrame.getByRole('link', {name: 'Manage Records'}).first()
		.waitFor({state: 'visible', timeout: 10_000}).catch(() => {});
	}

	async manageRecords(typeName)
	{
		await this.navigateToType(typeName);
		const iframe = this.page.frameLocator('iframe[name="setupFrame"]').first();
		await iframe.getByRole('link', {name: 'Manage Records'}).first().click().catch(() =>
		{
		});
		await iframe.locator('table.list, .pbBody table').first()
		.waitFor({state: 'visible', timeout: 10_000}).catch(() => {});
	}

	async getRecordCount()
	{
		const iframe = this.page.frameLocator('iframe[name="setupFrame"]').first();
		const rows = iframe.locator('table.list tbody tr, .pbBody table tbody tr');
		return rows.count();
	}

	async hasRecords()
	{
		return (await this.getRecordCount()) > 0;
	}

	async getTypeNames()
	{
		const iframe = this.page.frameLocator('iframe[name="setupFrame"]').first();
		const links = iframe.locator('table tbody tr td a');
		return links.allTextContents();
	}
}

module.exports = SetupCmdtPage;
