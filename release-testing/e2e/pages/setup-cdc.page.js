// SPDX-License-Identifier: BUSL-1.1
const {navigateToSetupPage} = require('../helpers/sf-navigation');
const {waitForSpinnerGone} = require('../helpers/wait-helpers');

class SetupCdcPage
{
	constructor(page)
	{
		this.page = page;
	}

	async navigate()
	{
		await navigateToSetupPage(this.page, 'Change Data Capture');
		await waitForSpinnerGone(this.page);
		await this.page.waitForTimeout(3000);
	}

	async enableEntity(entityName)
	{
		const entityRow = this.page.getByText(entityName, {exact: false}).first();
		await entityRow.click();
		await this.page.waitForTimeout(500);

		const moveRight = this.page.locator('button[title="Move selection to Selected Entities"]')
		.or(this.page.locator('button.slds-button >> svg >> ..').filter({has: this.page.locator('use[href*="right"]')}))
		.or(this.page.getByRole('button', {name: /right|add/i}))
		.first();
		await moveRight.click();
		await this.page.waitForTimeout(1000);
	}

	async disableEntity(entityName)
	{
		const entityRow = this.page.locator('[class*="selected"] >> text=' + entityName).first();
		await entityRow.click();
		await this.page.waitForTimeout(500);

		const moveLeft = this.page.locator('button[title="Move selection to Available Entities"]')
		.or(this.page.getByRole('button', {name: /left|remove/i}))
		.first();
		await moveLeft.click();
		await this.page.waitForTimeout(1000);
	}

	async save()
	{
		await this.page.getByRole('button', {name: 'Save'}).click();
		await waitForSpinnerGone(this.page);
		await this.page.waitForTimeout(2000);
	}
}

module.exports = SetupCdcPage;
