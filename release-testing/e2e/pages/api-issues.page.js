// SPDX-License-Identifier: Apache-2.0
const {expect} = require('@playwright/test');
const {clickNavTab} = require('../helpers/sf-navigation');
const {waitForListView, waitForRecordPage, waitForToastMessage} = require('../helpers/wait-helpers');
const {TOAST_MESSAGE} = require('../helpers/sf-selectors');
const {ELEMENT_WAIT_MILLISECONDS} = require('../helpers/wait-times');

// The request a list view sends to read its rows, and so the one that answers a search of the list.
const LIST_ROWS_REQUEST = 'ListUi.postListRecordsByName';
// One try at ticking a row's checkbox; the tick is tried again while the list draws its rows again.
const ROW_TICK_TRY_MILLISECONDS = 2_000;
// A list search finds a new record only once the org's search index holds it, which takes up to about twenty seconds
// after the record is saved (measured on a scratch org). The search is run again until then, for at most this long.
const SEARCH_INDEX_WAIT_MILLISECONDS = 90_000;

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

	// Opens one API issue by its record id.
	async openRecordById(recordId)
	{
		await this.page.goto(`${this.page.url().split('/lightning/')[0]}/lightning/r/${recordId}/view`);
		await waitForRecordPage(this.page);
	}

	// Presses the record page's Retry action, which runs the call again and answers with a toast.
	async clickRetry()
	{
		await this.page.getByRole('button', {name: 'Retry', exact: true}).click();
	}

	// The text of the first toast on the page, once one shows, through the shared toast wait.
	async readToast()
	{
		await waitForToastMessage(this.page, null);
		return (await this.page.locator(TOAST_MESSAGE).first().textContent()) || '';
	}

	// Searches the list and waits for the server's answer to that search. Rows read before the answer belong to the list
	// as it was before the search, and the list draws them again when the answer arrives.
	// The box is emptied first, so a search for the same words as before is sent again and not skipped.
	async searchList(term)
	{
		const answered = this.page.waitForResponse((response) => response.url().includes(LIST_ROWS_REQUEST)
				&& (response.request().postData() || '').includes(term), {timeout: ELEMENT_WAIT_MILLISECONDS});
		const search = this.page.getByPlaceholder('Search this list...');
		await search.fill('');
		await search.fill(term);
		await search.press('Enter');
		await answered;
	}

	// Searches the list until every row that holds one of the texts shows. Records saved moments ago are missing from
	// the search until the org's search index holds them, so the search is run again until they show. The page keeps the
	// answer to a search it has already made and does not ask the server again, so each new try reloads the list first.
	async searchListUntilRowsShow(term, rowTexts)
	{
		let firstTry = true;
		await expect(async() =>
		{
			if(!firstTry)
			{
				await this.page.reload({waitUntil: 'domcontentloaded'});
				await waitForListView(this.page);
			}
			firstTry = false;
			await this.searchList(term);
			for(const text of rowTexts)
			{
				await expect(this.listRow(text)).toHaveCount(1, {timeout: ROW_TICK_TRY_MILLISECONDS});
			}
		}, `the search for ${term} shows ${rowTexts.join(', ')}`).toPass({timeout: SEARCH_INDEX_WAIT_MILLISECONDS});
	}

	// The list row that holds the text.
	listRow(text)
	{
		return this.page.locator('table tbody tr').filter({hasText: text});
	}

	// Ticks the checkbox of the one row that holds the text. If the list draws its rows again during the click, the tick
	// is lost, so the helper checks the box is ticked and tries again until it stays ticked.
	async selectRow(text)
	{
		const row = this.listRow(text);
		await expect(row, `the list shows ${text}`).toHaveCount(1, {timeout: ELEMENT_WAIT_MILLISECONDS});
		const checkbox = row.locator('input[type="checkbox"]');
		await expect(async() =>
		{
			await checkbox.check({force: true, timeout: ROW_TICK_TRY_MILLISECONDS});
			await expect(checkbox).toBeChecked({timeout: ROW_TICK_TRY_MILLISECONDS});
		}, `the row for ${text} stays ticked`).toPass({timeout: ELEMENT_WAIT_MILLISECONDS});
	}

	// Checks that the row that holds the text is still ticked once every row was selected.
	async expectRowSelected(text)
	{
		const checkbox = this.listRow(text).locator('input[type="checkbox"]');
		await expect(checkbox, `the row for ${text} is still ticked`).toBeChecked({timeout: ELEMENT_WAIT_MILLISECONDS});
	}

	async listViewLoads()
	{
		return this.page.locator('force-list-view-manager-presented, lst-list-view-manager-header, lightning-list-view-table')
		.first().isVisible();
	}
}

module.exports = ApiIssuesPage;
