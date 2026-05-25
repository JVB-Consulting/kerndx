// SPDX-License-Identifier: BUSL-1.1
const {clickNavTab} = require('../helpers/sf-navigation');
const {waitForListView} = require('../helpers/wait-helpers');

class LoginFrequenciesPage
{
	constructor(page)
	{
		this.page = page;
	}

	async navigate()
	{
		await clickNavTab(this.page, 'Login Frequencies');
		await waitForListView(this.page);
	}

	async listViewLoads()
	{
		return this.page.locator('force-list-view-manager-presented, lst-list-view-manager-header, lightning-list-view-table')
		.first().isVisible();
	}
}

module.exports = LoginFrequenciesPage;
