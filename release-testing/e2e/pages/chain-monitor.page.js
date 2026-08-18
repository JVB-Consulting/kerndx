// SPDX-License-Identifier: BUSL-1.1
const {waitForSpinnerGone, pollUntil} = require('../helpers/wait-helpers');
const {getInstanceUrl} = require('../helpers/sf-auth');
const {namespacePrefix} = require('../helpers/sf-namespace');

class ChainMonitorPage
{
	constructor(page)
	{
		this.page = page;
	}

	async navigate()
	{
		const instanceUrl = getInstanceUrl();
		await this.page.goto(`${instanceUrl}/lightning/n/${namespacePrefix()}ChainMonitor`, {waitUntil: 'domcontentloaded'});
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

	async selectRowByChainName(chainName)
	{
		const rowTexts = await this.getRowTexts();
		const index = rowTexts.findIndex(text => text.includes(chainName));
		if(index < 0)
		{
			throw new Error(`No Chain Monitor row found for chain name "${chainName}"`);
		}
		await this.selectRow(index);
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
		const errorButton = detail.getByRole('button', {name: 'Error', exact: true}).first();
		await errorButton.scrollIntoViewIfNeeded();
		// The Error section renders in its own accordion, open by default for a Failed chain; that
		// accordion allows toggling, so a click on an already-open section would collapse it. Only
		// click when the error box is not visible yet. (isVisible never waits — its timeout option
		// is ignored — so the attach wait is explicit.)
		const errorBox = this.getErrorBox();
		await errorBox.waitFor({state: 'attached', timeout: 10000});
		if(await errorBox.isVisible())
		{
			return;
		}
		await errorButton.click({timeout: 10000});
		await errorBox.waitFor({state: 'visible', timeout: 10000});
	}

	getErrorBox()
	{
		// The detail header's "Failed" status pill and the live stream's ERROR badges also carry
		// slds-theme_error, so the fallback pins the box's own slds-box; the test id and the fallback
		// resolve to the same element, and neither can match the pill.
		return this.getDetailPanel().locator('[data-testid="error-message"], .slds-box.slds-theme_error').first();
	}

	async getErrorText()
	{
		const errorBox = this.getErrorBox();
		const visible = await errorBox.waitFor({state: 'visible', timeout: 5000}).then(() => true, () => false);
		if(!visible)
		{
			return null;
		}
		return (await errorBox.textContent()).trim();
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

	// What the list shows in place of the table when nothing matches: a headers-only table with a
	// paginator reading "Page 1 of 0" was what it used to show instead.
	getListEmptyState()
	{
		return this.getListPanel().locator('[data-testid="list-empty-state"]').first();
	}

	getListPaginator()
	{
		return this.getListPanel().locator('[data-testid="list-paginator"]').first();
	}

	async setNameSearch(term)
	{
		const searchInput = this.getListPanel().locator('lightning-input input').first();
		await searchInput.fill(term);
		await searchInput.press('Enter');
		await this.page.waitForTimeout(2000);
		await waitForSpinnerGone(this.page);
	}

	// Rendered header cell widths, in DOM order. The U37 defect was every column taking an equal
	// fifth of the pane, so the check is relative: the name column must outgrow the pinned ones.
	async getColumnWidths()
	{
		const headers = this.getDatatable().locator('thead th');
		const count = await headers.count();
		const widths = [];
		for(let index = 0; index < count; index++)
		{
			const box = await headers.nth(index).boundingBox();
			widths.push(box ? Math.round(box.width) : 0);
		}
		return widths;
	}

	// The reason a greyed-out header action cannot run, shown for readers who can reach neither the
	// tooltip (a disabled button suppresses pointer events) nor the description (it takes no focus).
	getOperationsUnavailableNotes()
	{
		return this.page.locator('[data-testid="operations-unavailable-note"]');
	}

	// --- Detail header: identity row, toolbar row, operator action group (retry / restart / abort) ---

	getStatusBadge()
	{
		return this.page.locator('[data-testid="status-badge"]');
	}

	// The status icon, pill, chain name, progress phrase and step dots. It holds no buttons: the
	// whole point of the U1 layout is that nothing can be painted over the name.
	getIdentityRow()
	{
		return this.getDetailPanel().locator('[data-testid="detail-identity-row"]').first();
	}

	// The row every action lives on. Wraps, so it never overlaps the name or clips off the pane.
	getToolbarRow()
	{
		return this.getDetailPanel().locator('[data-testid="detail-toolbar-row"]').first();
	}

	getChainNameHeading()
	{
		return this.getDetailPanel().locator('[data-testid="chain-name"]').first();
	}

	getViewLogsButton()
	{
		return this.getDetailPanel().locator('[data-testid="view-logs"]').first();
	}

	// The operator wrapper lays its buttons out as direct toolbar items (display: contents), so it
	// has no box of its own — measure the buttons, never this locator.
	getActionGroup()
	{
		return this.getDetailPanel().locator('[data-testid="detail-action-group"]').first();
	}

	// Every button on the toolbar row, in DOM order — the set a layout check has to fit inside the pane.
	getToolbarButtons()
	{
		return this.getToolbarRow().locator('lightning-button button');
	}

	// The refusal sentences shown on screen for keyboard-only readers (a disabled button takes no focus).
	getUnavailableNotes()
	{
		return this.getDetailPanel().locator('[data-testid="action-unavailable-note"]');
	}

	getRetryButton()
	{
		return this.page.locator('[data-testid="retry-action"]');
	}

	getRestartButton()
	{
		return this.page.locator('[data-testid="restart-action"]');
	}

	getAbortButton()
	{
		return this.page.locator('[data-testid="abort-button"]');
	}

	// The rendered inner button carries the disabled state and the refusal tooltip the
	// lightning-button host forwards; assertions target it, clicks can use the host.
	async getActionTooltip(actionLocator)
	{
		return actionLocator.locator('button').getAttribute('title');
	}

	// --- Confirm modal (shared by every operator action; abort keeps its own body testid) ---

	getModalBody()
	{
		return this.page.locator('[data-testid="action-modal-body"]');
	}

	getAbortModalBody()
	{
		return this.page.locator('[data-testid="abort-modal-body"]');
	}

	getConfirmButton()
	{
		return this.page.locator('[data-testid="confirm-button"]');
	}

	getCancelButton()
	{
		return this.page.locator('[data-testid="cancel-button"]');
	}

	// --- Operations control (monitor card header): state badge + clear-stalled + suspend/resume ---

	getOperationsControl()
	{
		return this.page.locator('[data-testid="operations-control"]').first();
	}

	getOperationsBadge()
	{
		return this.page.locator('[data-testid="operations-state-badge"]');
	}

	getClearStalledButton()
	{
		return this.page.locator('[data-testid="clear-stalled-action"]');
	}

	getSuspendButton()
	{
		return this.page.locator('[data-testid="suspend-action"]');
	}

	getResumeButton()
	{
		return this.page.locator('[data-testid="resume-action"]');
	}

	// --- Live activity stream (detail pane) ---

	getStreamPanel()
	{
		return this.getDetailPanel().locator('[data-testid="log-stream-panel"]').first();
	}

	getStreamTitle()
	{
		return this.page.locator('[data-testid="log-stream-title"]');
	}

	getStreamEntries()
	{
		return this.page.locator('[data-testid="log-stream-entry"]');
	}

	getStreamEmpty()
	{
		return this.page.locator('[data-testid="log-stream-empty"]');
	}

	getStreamCaveat()
	{
		return this.page.locator('[data-testid="log-stream-caveat"]');
	}

	getStreamDisconnected()
	{
		return this.page.locator('[data-testid="log-stream-disconnected"]');
	}

	getLineageLink()
	{
		return this.page.locator('[data-testid="restart-lineage-link"]');
	}

	// The datatable keys its rows on executionId, so the checked row's key IS the selected record id.
	async getSelectedRowKey()
	{
		return this.getDatatable().locator('tr:has(input:checked)').first().getAttribute('data-row-key-value');
	}

	// Every row's record id, in the order the list currently shows them.
	async getRowKeys()
	{
		return this.getDatatable().locator('tbody tr').evaluateAll((rows) => rows.map((row) => row.getAttribute('data-row-key-value')));
	}

	// --- Toasts (platform ShowToastEvent renders outside the component tree) ---

	getToast()
	{
		return this.page.locator('.forceToastMessage .toastMessage, lightning-toast').first();
	}
}

module.exports = ChainMonitorPage;
