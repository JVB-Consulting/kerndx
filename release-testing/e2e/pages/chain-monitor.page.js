// SPDX-License-Identifier: Apache-2.0
const {waitForSpinnerGone} = require('../helpers/wait-helpers');
const {SPINNER} = require('../helpers/sf-selectors');
const {getInstanceUrl} = require('../helpers/sf-auth');
const {namespacePrefix} = require('../helpers/sf-namespace');
const {readColumnLabels} = require('../lib/datatable-headers');
const {ELEMENT_WAIT_MILLISECONDS} = require('../helpers/wait-times');

// The status filter's values, in the order the list offers them.
const STATUS_VALUES = ['Running', 'Completed', 'Failed', 'Aborted', 'Stalled'];
const CHECKBOX_SETTLE_MILLISECONDS = 5000;
const CHECKBOX_POLL_MILLISECONDS = 100;
const FILTER_RELOAD_MILLISECONDS = 500;

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

	/**
	 * @description Navigates to the Chain Monitor tab and returns as soon as its list has rendered, with no
	 *              fixed wait: the open a timer measures. The caller settles afterwards.
	 */
	async navigateUntilRendered()
	{
		await this.page.goto(`${getInstanceUrl()}/lightning/n/${namespacePrefix()}ChainMonitor`, {waitUntil: 'domcontentloaded'});
		await this.waitForListRendered();
	}

	/**
	 * @description Waits until the list shows a row or its empty state and no spinner is on screen, without
	 *              the fixed settle: what a timed open measures to.
	 */
	async waitForListRendered()
	{
		await this.getListPanel().waitFor({state: 'visible', timeout: 60_000});
		await this.getDatatable().locator('tbody tr').first().or(this.getListEmptyState()).waitFor({state: 'visible', timeout: 60_000});
		await this.page.locator(SPINNER).first().waitFor({state: 'hidden', timeout: ELEMENT_WAIT_MILLISECONDS});
	}

	// The monitor opened on one run through its own deep link (chainMonitor.js reads c__correlationId and selects
	// the run), so a script can act on a row without searching the list for it.
	async navigateToRun(correlationId)
	{
		const instanceUrl = getInstanceUrl();
		await this.page.goto(`${instanceUrl}/lightning/n/${namespacePrefix()}ChainMonitor?c__correlationId=${encodeURIComponent(correlationId)}`, {waitUntil: 'domcontentloaded'});
		await this.page.waitForTimeout(5000);
		await waitForSpinnerGone(this.page);
	}

	/**
	 * @description The run's deep link opened until the list and the run's detail have rendered, with no fixed
	 *              wait: the open a timer measures. The caller settles afterwards.
	 * @param {string} correlationId The run's correlation id.
	 */
	async navigateToRunUntilRendered(correlationId)
	{
		const url = `${getInstanceUrl()}/lightning/n/${namespacePrefix()}ChainMonitor?c__correlationId=${encodeURIComponent(correlationId)}`;
		await this.page.goto(url, {waitUntil: 'domcontentloaded'});
		await this.waitForListRendered();
		await this.getDetailPanel().waitFor({state: 'visible', timeout: 60_000});
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

	/**
	 * The data columns' labels, in order: the row-select header is dropped and a sortable header's sort words are
	 * stripped, so a test can compare the column set exactly. getColumnHeaders keeps the raw header texts, which stay
	 * index-aligned with a row's cells for getColumnValues.
	 *
	 * The rule the labels are read by lives in lib/datatable-headers.js, shared with the Log Console's page object,
	 * whose list drops columns at narrow widths the same way this one does.
	 */
	async getColumnLabels()
	{
		return readColumnLabels(this.getDatatable());
	}

	/**
	 * The two halves of the monitor's split row — the list column and the detail column — as bounding boxes in DOM order.
	 * Measured on the grid columns rather than on the panels inside them, because a detail pane with nothing selected
	 * renders no box of its own and a stacking check would then have nothing to compare. Side by side from the tablet
	 * width up (equal top, different left), stacked below it (same left, one under the other).
	 */
	async getSplitPanelBoxes()
	{
		const columns = this.page.locator('[data-testid="split-row"] > .slds-col');
		const count = await columns.count();
		const boxes = [];
		for(let index = 0; index < count; index++)
		{
			boxes.push(await columns.nth(index).boundingBox());
		}
		return boxes;
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

	/**
	 * @description The timeline's step rows by their own test id: one per step, unlike getStepCount's selector,
	 *              which also counts every nested list item inside a step.
	 * @returns {Promise<number>} The step count.
	 */
	async getStepRowCount()
	{
		return this.getDetailPanel().locator('[data-testid="step-row"]').count();
	}

	async getStepNames()
	{
		const timeline = this.getDetailPanel().locator('c-chain-step-timeline, kern-chain-step-timeline').first();
		const names = timeline.locator('.slds-truncate .slds-text-body_regular');
		return names.allTextContents();
	}

	/**
	 * @description The step timeline's state words, one per step, in the order the chain runs them: Completed, Failed,
	 *              Running, No result recorded, Did not run and the rest. Each word is read from the step's details
	 *              box (class, then status), which holds it even when the row itself shows the step's duration.
	 *
	 * @returns {Promise<string[]>} The state words, first step first.
	 */
	async getStepStateWords()
	{
		const statusValues = this.getDetailPanel().locator('[data-testid="step-row"] .step-popover .popover-grid dd:nth-of-type(2)');
		const words = await statusValues.allTextContents();
		return words.map((word) => word.trim());
	}

	/** The step timeline's "Retried manually" lines, one above each step an operator retried. */
	getManualRetryMarkers()
	{
		return this.getDetailPanel().locator('[data-testid="manual-retry-marker"]');
	}

	async getTimingLabels()
	{
		const dtElements = this.getDetailPanel().locator('dt');
		return dtElements.allTextContents();
	}

	/**
	 * The tooltip and the spoken name of the correlation id's copy button. Both are read from the inner button,
	 * because the Lightning host carries neither.
	 */
	async getCopyCorrelationName()
	{
		const button = this.getDetailPanel().locator('[data-testid="copy-correlation"] button').first();
		const spoken = await button.locator('.slds-assistive-text').first().innerText();
		return {title: await button.getAttribute('title'), spoken: spoken.trim()};
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

	statusLegend()
	{
		return this.getListPanel().locator('lightning-checkbox-group legend, lightning-checkbox-group .slds-form-element__legend').first();
	}

	// The rendered inner button is what carries the disabled state; the lightning-button host never does.
	statusAction(label)
	{
		return this.getListPanel().locator(`lightning-button[data-testid="status-${label.toLowerCase().replace(' ', '-')}"] button`).first();
	}

	/**
	 * @description One status's checkbox in the filter tray, by the value the list filters on.
	 * @param {string} status The status value.
	 * @returns {Object} The input's locator.
	 */
	statusCheckbox(status)
	{
		return this.getListPanel().locator(`lightning-checkbox-group input[type="checkbox"][value="${status}"]`).first();
	}

	/**
	 * @description The label beside that checkbox: the input itself is hidden under the faux box, so the label
	 *              takes the click.
	 * @param {string} status The status value.
	 * @returns {Object} The label's locator.
	 */
	statusCheckboxLabel(status)
	{
		return this.getListPanel().locator(`lightning-checkbox-group .slds-checkbox:has(input[value="${status}"]) label`).first();
	}

	/**
	 * @description Leaves exactly the given statuses on, opening the filter tray when it is shut and letting the
	 *              list reload after each box that changes.
	 * @param {Array<string>} statuses The status values to leave on.
	 */
	async setStatusFilter(statuses)
	{
		if(!await this.hasFiltersVisible())
		{
			await this.toggleFilters();
		}
		for(const status of STATUS_VALUES)
		{
			const checkbox = this.statusCheckbox(status);
			const wanted = statuses.includes(status);
			if(await checkbox.isChecked() !== wanted)
			{
				await this.statusCheckboxLabel(status).click();
				await this.waitForCheckbox(checkbox, wanted);
				await this.page.waitForTimeout(FILTER_RELOAD_MILLISECONDS);
				await waitForSpinnerGone(this.page);
			}
		}
	}

	/**
	 * @description Waits until a checkbox reads the wanted state, through the locator (a document query from the
	 *              page cannot see into the component's shadow tree).
	 * @param {Object} checkbox The checkbox locator.
	 * @param {boolean} wanted The state to wait for.
	 */
	async waitForCheckbox(checkbox, wanted)
	{
		const deadline = Date.now() + CHECKBOX_SETTLE_MILLISECONDS;
		while(await checkbox.isChecked() !== wanted)
		{
			if(Date.now() > deadline)
			{
				throw new Error(`The ${await checkbox.getAttribute('value')} checkbox did not become ${wanted ? 'checked' : 'unchecked'}`);
			}
			await this.page.waitForTimeout(CHECKBOX_POLL_MILLISECONDS);
		}
	}

	listEmptyState()
	{
		return this.getListPanel().locator('[data-testid="list-empty-state"]');
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

	/**
	 * @description The paginator's Next: the last of its two buttons, whose rendered inner button carries the
	 *              disabled state.
	 * @returns {Object} The button's locator.
	 */
	getNextPageButton()
	{
		return this.getListPaginator().locator('lightning-button').last().locator('button');
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

	/**
	 * @description Whether an operator action is disabled, read from the rendered inner button: the
	 *              lightning-button host never carries the state, so a read on it always says enabled.
	 * @param {Object} actionLocator The action's host locator (getRetryButton, getRestartButton).
	 * @returns {Promise<boolean>} True when the rendered button is disabled.
	 */
	async isActionDisabled(actionLocator)
	{
		return actionLocator.locator('button').isDisabled();
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

	// --- The action scope (a deep link from the Log Console) ---

	getActionPill()
	{
		return this.getListPanel().locator('[data-testid="action-pill"]').first();
	}

	getShowActionLogsButton()
	{
		return this.getListPanel().locator('[data-testid="show-action-logs"]').first();
	}

	getDetailShowActionLogsButton()
	{
		return this.getDetailPanel().locator('[data-testid="show-action-logs"]').first();
	}

	// The Launched-under cells, in row order: link text or plain words.
	async getLaunchedUnderValues()
	{
		return this.getColumnValues('Launched under');
	}

	getLaunchedUnderRow()
	{
		return this.getDetailPanel().locator('[data-testid="launched-under-row"]').first();
	}

	getLaunchedUnderLink()
	{
		return this.getDetailPanel().locator('[data-testid="launched-under-link"]').first();
	}

	/**
	 * @description The correlation id the detail pane shows for the run it is on, empty when the pane shows none.
	 * @returns {Promise<string>} The correlation id.
	 */
	async getDetailCorrelationId()
	{
		return (await this.getDetailPanel().locator('[data-testid="correlation-id"]').first().innerText().catch(() => '')).trim();
	}

	/**
	 * @description The detail pane's Launched under row as one line of text, empty when the pane shows none.
	 * @returns {Promise<string>} The row's text.
	 */
	async getDetailLaunchedUnderText()
	{
		return (await this.getLaunchedUnderRow().innerText().catch(() => '')).replace(/\s+/g, ' ').trim();
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
