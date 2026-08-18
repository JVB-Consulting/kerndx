// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for chainMonitorList LWC component
 * @author Jason van Beukering
 * @date April 2026, August 2026
 */

// The page-position label carries {0}/{1} placeholders; mocking it to the real template value
// keeps the 'Page 1 of 1' assertion an end-to-end check of formatTemplateString interpolation
// (the default sfdx-lwc-jest mock would resolve it to the bare label id and skip substitution).
jest.mock('@salesforce/label/c.ChainMonitor_PageLabel', () => ({default: 'Page {0} of {1}'}), {virtual: true});

// The empty-state and elapsed-duration labels mirror their in-org values byte-for-byte, so the
// assertions below check the wiring end to end rather than restating a placeholder id.
jest.mock('@salesforce/label/c.ChainMonitor_DurationElapsed', () => ({default: '{0} elapsed'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_ListEmptyHeading', () => ({default: 'No chains to show'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_ListEmptyBody', () => ({default: 'No chain runs match your search and status filters. Clear the search, or select more statuses.'}),
		{virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_ListNoStatusBody', () => ({default: 'No statuses are selected, so no chain run can match. Select at least one status.'}),
		{virtual: true});

import {createElement} from 'lwc';
import ChainMonitorList from 'c/chainMonitorList';
import {mockCallControllerMethod} from 'c/componentBuilder';
import CLEAR_ALL from '@salesforce/label/c.ChainMonitor_ClearAll';
import SELECT_ALL from '@salesforce/label/c.ChainMonitor_SelectAll';
import NEXT_LABEL from '@salesforce/label/c.ChainMonitor_NextLabel';
import PREVIOUS_LABEL from '@salesforce/label/c.ChainMonitor_PreviousLabel';
import COLUMN_CHAIN_NAME from '@salesforce/label/c.ChainMonitor_ChainName';
import COLUMN_STATUS from '@salesforce/label/c.ChainMonitor_Status';
import COLUMN_STARTED from '@salesforce/label/c.ChainMonitor_Started';

const MOCK_PAGE = {
	records: [
		{
			executionId: 'id-1',
			chainName: 'Chain1',
			status: 'Running',
			completedSteps: 1,
			totalSteps: 3,
			startedAt: '2026-04-09T10:00:00.000Z',
			durationMs: null,
			durationLabel: null
		},
		{executionId: 'id-2', chainName: 'Chain2', status: 'Failed', completedSteps: 0, totalSteps: 2, startedAt: '2026-04-09T09:00:00.000Z', durationMs: 5000, durationLabel: '5s'}
	], totalCount: 2, pageNumber: 1, totalPages: 1, hasMorePages: false
};

const MOCK_PAGE_1 = {
	records: [{executionId: 'id-1', chainName: 'Chain1', status: 'Completed', completedSteps: 1, totalSteps: 1}], totalCount: 3, pageNumber: 1, totalPages: 2, hasMorePages: true
};

const MOCK_PAGE_2 = {
	records: [{executionId: 'id-2', chainName: 'Chain2', status: 'Completed', completedSteps: 1, totalSteps: 1}], totalCount: 3, pageNumber: 2, totalPages: 2, hasMorePages: false
};

const MOCK_EMPTY_PAGE = {records: [], totalCount: 0, pageNumber: 1, totalPages: 0, hasMorePages: false};

// The controller answers an unfinished run with the time since it started, and a finished one with
// the duration it recorded when it ended; the third row records nothing either way.
const MOCK_DURATION_PAGE = {
	records: [
		{executionId: 'id-1', chainName: 'StillGoing', status: 'Stalled', completedSteps: 1, totalSteps: 3, durationMs: 5520000, durationLabel: '1h 32m'},
		{executionId: 'id-2', chainName: 'Ended', status: 'Failed', completedSteps: 0, totalSteps: 2, durationMs: 5000, durationLabel: '5s'},
		{executionId: 'id-3', chainName: 'Untimed', status: 'Completed', completedSteps: 1, totalSteps: 1, durationMs: null, durationLabel: null}
	], totalCount: 3, pageNumber: 1, totalPages: 1, hasMorePages: false
};

function getLastRequestJson()
{
	const lastCall = mockCallControllerMethod.mock.calls[mockCallControllerMethod.mock.calls.length - 1];
	return JSON.parse(lastCall[1].requestJson);
}

describe('c-chain-monitor-list', () =>
{
	beforeEach(() =>
	{
		mockCallControllerMethod.mockResolvedValue(MOCK_PAGE);
	});

	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
		jest.clearAllMocks();
	});

	async function createComponent()
	{
		const element = createElement('c-chain-monitor-list', {is: ChainMonitorList});
		document.body.appendChild(element);
		await Promise.resolve();
		await Promise.resolve();
		return element;
	}

	it('should render datatable with data from controller', async() =>
	{
		const element = await createComponent();

		const datatable = element.shadowRoot.querySelector('lightning-datatable');
		expect(datatable).toBeTruthy();
		expect(datatable.data.length).toBe(2);
	});

	it('should call controller with empty status filters when all selected on load', async() =>
	{
		await createComponent();

		const request = getLastRequestJson();
		expect(request.statusFilters).toEqual([]);
		expect(request.sortField).toBe('StartedAt');
		expect(request.sortAscending).toBe(false);
		expect(request.pageNumber).toBe(1);
		expect(request.pageSize).toBe(20);
	});

	it('should hide filters by default and show on toggle', async() =>
	{
		const element = await createComponent();

		expect(element.shadowRoot.querySelector('lightning-checkbox-group')).toBeFalsy();

		const filterButton = element.shadowRoot.querySelector('lightning-button-icon');
		expect(filterButton.iconName).toBe('utility:filterList');
		filterButton.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();

		expect(element.shadowRoot.querySelector('lightning-checkbox-group')).toBeTruthy();
	});

	it('should reload with updated filters when status changes', async() =>
	{
		const element = await createComponent();

		element.shadowRoot.querySelector('lightning-button-icon').dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();

		mockCallControllerMethod.mockClear();
		const checkboxGroup = element.shadowRoot.querySelector('lightning-checkbox-group');
		checkboxGroup.dispatchEvent(new CustomEvent('change', {detail: {value: ['Completed']}}));
		await Promise.resolve();
		await Promise.resolve();

		const request = getLastRequestJson();
		expect(request.statusFilters).toEqual(['Completed']);
		expect(request.pageNumber).toBe(1);
	});

	it('should show Select All / Clear All toggle in filters', async() =>
	{
		const element = await createComponent();

		element.shadowRoot.querySelector('lightning-button-icon').dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();

		const buttons = element.shadowRoot.querySelectorAll('lightning-button');
		const toggleButton = Array.from(buttons).find(b => b.label === CLEAR_ALL);
		expect(toggleButton).toBeTruthy();
	});

	it('should clear all filters when Clear All clicked', async() =>
	{
		const element = await createComponent();

		element.shadowRoot.querySelector('lightning-button-icon').dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();

		mockCallControllerMethod.mockClear();
		const buttons = element.shadowRoot.querySelectorAll('lightning-button');
		const toggleButton = Array.from(buttons).find(b => b.label === CLEAR_ALL);
		toggleButton.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();
		await Promise.resolve();

		const checkboxGroup = element.shadowRoot.querySelector('lightning-checkbox-group');
		expect(checkboxGroup.value).toEqual([]);
	});

	it('should select all filters when Select All clicked', async() =>
	{
		const element = await createComponent();

		element.shadowRoot.querySelector('lightning-button-icon').dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();

		const checkboxGroup = element.shadowRoot.querySelector('lightning-checkbox-group');
		checkboxGroup.dispatchEvent(new CustomEvent('change', {detail: {value: []}}));
		await Promise.resolve();
		await Promise.resolve();

		mockCallControllerMethod.mockClear();
		const buttons = element.shadowRoot.querySelectorAll('lightning-button');
		const toggleButton = Array.from(buttons).find(b => b.label === SELECT_ALL);
		toggleButton.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();
		await Promise.resolve();

		expect(checkboxGroup.value).toEqual([
			'Running',
			'Completed',
			'Failed',
			'Aborted',
			'Stalled'
		]);
	});

	it('should say no statuses are selected rather than silently showing every chain', async() =>
	{
		const element = await createComponent();

		element.shadowRoot.querySelector('lightning-button-icon').dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();

		mockCallControllerMethod.mockClear();
		const checkboxGroup = element.shadowRoot.querySelector('lightning-checkbox-group');
		checkboxGroup.dispatchEvent(new CustomEvent('change', {detail: {value: []}}));
		await Promise.resolve();
		await Promise.resolve();

		// Every box unticked used to read as "no filter" and return the whole list, pixel-identical
		// to every box ticked, so the reader could not tell the two states apart.
		expect(mockCallControllerMethod).not.toHaveBeenCalled();
		expect(element.shadowRoot.querySelector('lightning-datatable')).toBeFalsy();
		const emptyState = element.shadowRoot.querySelector('[data-testid="list-empty-state"]');
		expect(emptyState.textContent).toContain('No statuses are selected, so no chain run can match. Select at least one status.');
	});

	it('should clear the selection when the status filter changes', async() =>
	{
		const element = await createComponent();
		const datatable = element.shadowRoot.querySelector('lightning-datatable');
		datatable.dispatchEvent(new CustomEvent('rowselection', {detail: {selectedRows: [{executionId: 'id-2'}]}}));
		await Promise.resolve();
		const handler = jest.fn();
		element.addEventListener('select', handler);

		element.shadowRoot.querySelector('lightning-button-icon').dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();
		element.shadowRoot.querySelector('lightning-checkbox-group').dispatchEvent(new CustomEvent('change', {detail: {value: ['Completed']}}));
		await Promise.resolve();
		await Promise.resolve();

		// A filter the selected chain no longer passes must not leave it open in the detail pane.
		expect(handler).toHaveBeenCalledWith(expect.objectContaining({detail: expect.objectContaining({executionId: 'id-1', isUserSelection: false})}));
		expect(element.shadowRoot.querySelector('lightning-datatable').selectedRows).toEqual(['id-1']);
	});

	it('should clear the selection when the Select All / Clear All toggle changes the filter', async() =>
	{
		const element = await createComponent();
		const datatable = element.shadowRoot.querySelector('lightning-datatable');
		datatable.dispatchEvent(new CustomEvent('rowselection', {detail: {selectedRows: [{executionId: 'id-2'}]}}));
		await Promise.resolve();
		element.shadowRoot.querySelector('lightning-button-icon').dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();
		element.shadowRoot.querySelector('lightning-checkbox-group').dispatchEvent(new CustomEvent('change', {detail: {value: ['Completed']}}));
		await Promise.resolve();
		await Promise.resolve();
		const handler = jest.fn();
		element.addEventListener('select', handler);

		const toggleButton = Array.from(element.shadowRoot.querySelectorAll('lightning-button')).find(button => button.label === SELECT_ALL);
		toggleButton.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();
		await Promise.resolve();

		expect(handler).toHaveBeenCalledWith(expect.objectContaining({detail: expect.objectContaining({executionId: 'id-1', isUserSelection: false})}));
	});

	it('should reload with name filter when search committed', async() =>
	{
		const element = await createComponent();
		mockCallControllerMethod.mockClear();

		const searchInput = element.shadowRoot.querySelector('lightning-input');
		searchInput.value = 'Account';
		searchInput.dispatchEvent(new CustomEvent('commit', {detail: {value: 'Account'}}));
		await Promise.resolve();
		await Promise.resolve();

		const request = getLastRequestJson();
		expect(request.nameFilter).toBe('Account');
		expect(request.pageNumber).toBe(1);
	});

	it('should clear the selection when the search term changes', async() =>
	{
		const element = await createComponent();
		element.shadowRoot.querySelector('lightning-datatable')
		.dispatchEvent(new CustomEvent('rowselection', {detail: {selectedRows: [{executionId: 'id-2'}]}}));
		await Promise.resolve();
		const handler = jest.fn();
		element.addEventListener('select', handler);

		const searchInput = element.shadowRoot.querySelector('lightning-input');
		searchInput.value = 'Chain';
		searchInput.dispatchEvent(new CustomEvent('commit', {detail: {value: 'Chain'}}));
		await Promise.resolve();
		await Promise.resolve();

		expect(handler).toHaveBeenCalledWith(expect.objectContaining({detail: expect.objectContaining({executionId: 'id-1', isUserSelection: false})}));
	});

	it('should reload with sort parameters when column header clicked', async() =>
	{
		const element = await createComponent();
		mockCallControllerMethod.mockClear();

		const datatable = element.shadowRoot.querySelector('lightning-datatable');
		datatable.dispatchEvent(new CustomEvent('sort', {detail: {fieldName: 'recordUrl', sortDirection: 'asc'}}));
		await Promise.resolve();
		await Promise.resolve();

		const request = getLastRequestJson();
		expect(request.sortField).toBe('ChainName');
		expect(request.sortAscending).toBe(true);
	});

	it('should clear the selection when the sort changes', async() =>
	{
		const element = await createComponent();
		const datatable = element.shadowRoot.querySelector('lightning-datatable');
		datatable.dispatchEvent(new CustomEvent('rowselection', {detail: {selectedRows: [{executionId: 'id-2'}]}}));
		await Promise.resolve();
		const handler = jest.fn();
		element.addEventListener('select', handler);

		// Re-sorting reorders every row, so the pane kept showing a chain no row was highlighting.
		datatable.dispatchEvent(new CustomEvent('sort', {detail: {fieldName: 'recordUrl', sortDirection: 'asc'}}));
		await Promise.resolve();
		await Promise.resolve();

		expect(handler).toHaveBeenCalledWith(expect.objectContaining({detail: expect.objectContaining({executionId: 'id-1', isUserSelection: false})}));
	});

	it('should advance to next page when Next clicked', async() =>
	{
		mockCallControllerMethod.mockResolvedValueOnce(MOCK_PAGE_1);
		const element = await createComponent();
		mockCallControllerMethod.mockClear();
		mockCallControllerMethod.mockResolvedValueOnce(MOCK_PAGE_2);

		const buttons = element.shadowRoot.querySelectorAll('lightning-button');
		const nextButton = Array.from(buttons).find(b => b.label === NEXT_LABEL);
		nextButton.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();
		await Promise.resolve();

		const request = getLastRequestJson();
		expect(request.pageNumber).toBe(2);
	});

	it('should go to previous page when Previous clicked', async() =>
	{
		mockCallControllerMethod.mockResolvedValueOnce(MOCK_PAGE_2);
		const element = await createComponent();
		mockCallControllerMethod.mockClear();
		mockCallControllerMethod.mockResolvedValueOnce(MOCK_PAGE_1);

		const buttons = element.shadowRoot.querySelectorAll('lightning-button');
		const prevButton = Array.from(buttons).find(b => b.label === PREVIOUS_LABEL);
		prevButton.dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();
		await Promise.resolve();

		const request = getLastRequestJson();
		expect(request.pageNumber).toBe(1);
	});

	it('should dispatch select event when row checkbox clicked', async() =>
	{
		const element = await createComponent();
		const handler = jest.fn();
		element.addEventListener('select', handler);

		const datatable = element.shadowRoot.querySelector('lightning-datatable');
		datatable.dispatchEvent(new CustomEvent('rowselection', {
			detail: {selectedRows: [{executionId: 'id-1'}]}
		}));
		await Promise.resolve();

		expect(handler).toHaveBeenCalled();
		expect(handler.mock.calls[0][0].detail.executionId).toBe('id-1');
	});

	it('should not dispatch select event when no rows selected', async() =>
	{
		const element = await createComponent();
		const handler = jest.fn();
		element.addEventListener('select', handler);

		const datatable = element.shadowRoot.querySelector('lightning-datatable');
		datatable.dispatchEvent(new CustomEvent('rowselection', {detail: {selectedRows: []}}));
		await Promise.resolve();

		expect(handler).not.toHaveBeenCalled();
	});

	it('should compute record URL for each row', async() =>
	{
		const element = await createComponent();

		const datatable = element.shadowRoot.querySelector('lightning-datatable');
		expect(datatable.data[0].recordUrl).toBe('/lightning/r/id-1/view');
		expect(datatable.data[1].recordUrl).toBe('/lightning/r/id-2/view');
	});

	it('should use url column type for chain name', async() =>
	{
		const element = await createComponent();

		const datatable = element.shadowRoot.querySelector('lightning-datatable');
		const chainNameColumn = datatable.columns.find(c => c.label === COLUMN_CHAIN_NAME);
		expect(chainNameColumn.type).toBe('url');
		expect(chainNameColumn.fieldName).toBe('recordUrl');
	});

	it('should show progress label as completedSteps/totalSteps', async() =>
	{
		const element = await createComponent();

		const datatable = element.shadowRoot.querySelector('lightning-datatable');
		expect(datatable.data[0].progressLabel).toBe('1/3 (33%)');
		expect(datatable.data[1].progressLabel).toBe('0/2 (0%)');
	});

	it('should show 0% progress when totalSteps is zero', async() =>
	{
		mockCallControllerMethod.mockResolvedValue({
			records: [{executionId: 'id-1', chainName: 'Empty', status: 'Running', completedSteps: 0, totalSteps: 0}],
			totalCount: 1,
			pageNumber: 1,
			totalPages: 1,
			hasMorePages: false
		});
		const element = await createComponent();

		const datatable = element.shadowRoot.querySelector('lightning-datatable');
		expect(datatable.data[0].progressLabel).toBe('0/0 (0%)');
	});

	it('should expose sortedBy getter matching current sort field', async() =>
	{
		const element = await createComponent();

		const datatable = element.shadowRoot.querySelector('lightning-datatable');
		expect(datatable.sortedBy).toBe('startedAt');
		expect(datatable.sortedDirection).toBe('desc');
	});

	it('should reload data on refresh api call', async() =>
	{
		const element = await createComponent();
		mockCallControllerMethod.mockClear();

		await element.refresh();

		expect(mockCallControllerMethod).toHaveBeenCalled();
	});

	it('should show page label', async() =>
	{
		const element = await createComponent();

		const pageText = element.shadowRoot.querySelector('.slds-align-middle');
		expect(pageText.textContent).toBe('Page 1 of 1');
	});

	it('should disable previous button on first page', async() =>
	{
		const element = await createComponent();

		const buttons = element.shadowRoot.querySelectorAll('lightning-button');
		const prevButton = Array.from(buttons).find(b => b.label === PREVIOUS_LABEL);
		expect(prevButton.disabled).toBe(true);
	});

	it('should disable next button on last page', async() =>
	{
		const element = await createComponent();

		const buttons = element.shadowRoot.querySelectorAll('lightning-button');
		const nextButton = Array.from(buttons).find(b => b.label === NEXT_LABEL);
		expect(nextButton.disabled).toBe(true);
	});

	it('should use default sort field for unknown field names', async() =>
	{
		const element = await createComponent();
		mockCallControllerMethod.mockClear();

		const datatable = element.shadowRoot.querySelector('lightning-datatable');
		datatable.dispatchEvent(new CustomEvent('sort', {detail: {fieldName: 'unknownField', sortDirection: 'asc'}}));
		await Promise.resolve();
		await Promise.resolve();

		const request = getLastRequestJson();
		expect(request.sortField).toBe('CreatedDate');
	});

	it('should send requestJson as string parameter', async() =>
	{
		await createComponent();

		const lastCall = mockCallControllerMethod.mock.calls[mockCallControllerMethod.mock.calls.length - 1];
		expect(typeof lastCall[1].requestJson).toBe('string');
		expect(() => JSON.parse(lastCall[1].requestJson)).not.toThrow();
	});

	it('should auto-select first row on initial load', async() =>
	{
		const handler = jest.fn();
		const element = createElement('c-chain-monitor-list', {is: ChainMonitorList});
		element.addEventListener('select', handler);
		document.body.appendChild(element);
		await Promise.resolve();
		await Promise.resolve();

		expect(handler).toHaveBeenCalledWith(expect.objectContaining({detail: expect.objectContaining({executionId: 'id-1', isUserSelection: false})}));

		const datatable = element.shadowRoot.querySelector('lightning-datatable');
		expect(datatable.selectedRows).toEqual(['id-1']);
	});

	it('should mark row clicks as user selections', async() =>
	{
		const element = await createComponent();
		const handler = jest.fn();
		element.addEventListener('select', handler);

		const datatable = element.shadowRoot.querySelector('lightning-datatable');
		datatable.dispatchEvent(new CustomEvent('rowselection', {detail: {selectedRows: [{executionId: 'id-2'}]}}));
		await Promise.resolve();

		expect(handler).toHaveBeenCalledWith(expect.objectContaining({detail: expect.objectContaining({executionId: 'id-2', isUserSelection: true})}));
	});

	it('should keep an off-page selection across refresh', async() =>
	{
		const element = await createComponent();
		element.selectById('off-page-id');
		await Promise.resolve();
		const handler = jest.fn();
		element.addEventListener('select', handler);

		await element.refresh();
		await Promise.resolve();

		expect(handler).not.toHaveBeenCalled();
	});

	it('should handle null controller response', async() =>
	{
		mockCallControllerMethod.mockResolvedValue(null);

		const handler = jest.fn();
		const element = createElement('c-chain-monitor-list', {is: ChainMonitorList});
		element.addEventListener('select', handler);
		document.body.appendChild(element);
		await Promise.resolve();
		await Promise.resolve();

		expect(handler).toHaveBeenCalledWith(expect.objectContaining({detail: expect.objectContaining({executionId: null})}));
		expect(element.shadowRoot.querySelector('lightning-datatable')).toBeFalsy();
	});

	it('should render an empty state instead of a headers-only table when nothing matches', async() =>
	{
		mockCallControllerMethod.mockResolvedValue(MOCK_EMPTY_PAGE);
		const element = await createComponent();

		// A no-match search used to leave column headers over blank space beside a detail pane
		// telling the reader to choose a chain from that list.
		expect(element.shadowRoot.querySelector('lightning-datatable')).toBeFalsy();
		const emptyState = element.shadowRoot.querySelector('[data-testid="list-empty-state"]');
		expect(emptyState.textContent).toContain('No chains to show');
		expect(emptyState.textContent).toContain('No chain runs match your search and status filters. Clear the search, or select more statuses.');
	});

	it('should hide the paginator when there is nothing to page through', async() =>
	{
		mockCallControllerMethod.mockResolvedValue(MOCK_EMPTY_PAGE);
		const element = await createComponent();

		// The paginator read "Page 1 of 0" over an empty table.
		expect(element.shadowRoot.querySelector('[data-testid="list-paginator"]')).toBeFalsy();
	});

	it('should give the chain name and start time the leftover width and pin the compact columns', async() =>
	{
		const element = await createComponent();

		const columns = element.shadowRoot.querySelector('lightning-datatable').columns;
		const widthOf = (label) => columns.find(column => column.label === label).initialWidth;
		// Five columns split evenly used to truncate the chain name and cut the start time mid-clock
		// while a 144px cell held '1.9s'.
		expect(widthOf(COLUMN_CHAIN_NAME)).toBeUndefined();
		expect(widthOf(COLUMN_STARTED)).toBeUndefined();
		expect(widthOf(COLUMN_STATUS)).toBeGreaterThan(0);
		expect(columns.find(column => column.label === COLUMN_STATUS).hideDefaultActions).toBe(true);
	});

	it('should mark an unfinished run duration as elapsed and leave a finished one as recorded', async() =>
	{
		mockCallControllerMethod.mockResolvedValue(MOCK_DURATION_PAGE);
		const element = await createComponent();

		const rows = element.shadowRoot.querySelector('lightning-datatable').data;
		expect(rows[0].durationDisplay).toBe('1h 32m elapsed');
		expect(rows[1].durationDisplay).toBe('5s');
		expect(rows[2].durationDisplay).toBe('—');
	});

	it('should clear selection when results are empty', async() =>
	{
		mockCallControllerMethod.mockResolvedValue({
			records: [], totalCount: 0, pageNumber: 1, totalPages: 0, hasMorePages: false
		});

		const handler = jest.fn();
		const element = createElement('c-chain-monitor-list', {is: ChainMonitorList});
		element.addEventListener('select', handler);
		document.body.appendChild(element);
		await Promise.resolve();
		await Promise.resolve();

		expect(handler).toHaveBeenCalledWith(expect.objectContaining({detail: expect.objectContaining({executionId: null})}));
	});

	it('should select a deep-linked execution via selectById', async() =>
	{
		mockCallControllerMethod.mockResolvedValue(MOCK_PAGE);
		const element = await createComponent();
		const handler = jest.fn();
		element.addEventListener('select', handler);

		element.selectById('id-2');
		await Promise.resolve();

		expect(handler).toHaveBeenCalledWith(expect.objectContaining({detail: expect.objectContaining({executionId: 'id-2'})}));
	});

	it('should ignore selectById without an execution id', async() =>
	{
		mockCallControllerMethod.mockResolvedValue(MOCK_PAGE);
		const element = await createComponent();
		const handler = jest.fn();
		element.addEventListener('select', handler);

		element.selectById(null);
		await Promise.resolve();

		expect(handler).not.toHaveBeenCalled();
	});
});
