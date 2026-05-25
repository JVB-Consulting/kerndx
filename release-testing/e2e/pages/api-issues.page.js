// SPDX-License-Identifier: BUSL-1.1
const {clickNavTab} = require('../helpers/sf-navigation');
const {waitForListView, waitForRecordPage} = require('../helpers/wait-helpers');

class ApiIssuesPage
{
	constructor(page)
	{
		this.page = page;
	}

	async navigate()
	{
		await clickNavTab(this.page, 'API Issues');
		await waitForListView(this.page);
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

	async listViewLoads()
	{
		return this.page.locator('force-list-view-manager-presented, lst-list-view-manager-header, lightning-list-view-table')
		.first().isVisible();
	}
}

module.exports = ApiIssuesPage;
