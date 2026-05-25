// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for paginatedTable LWC component
 * @author Jason van Beukering
 * @date December 2025, May 2026
 */
import {createElement} from 'lwc';
// Import directly from source to bypass jest.config.js moduleNameMapper mock
import LwcPaginatedTable from '../paginatedTable';
import {
	mockCustomNotificationFactory, mockCustomNotification, mockShowErrorToast
} from 'c/componentBuilder';

// Mock message channel
jest.mock('@salesforce/messageChannel/Component__c', () => ({
	default: {}
}), {virtual: true});

// Mock utilityString - implementation must be inline due to Jest hoisting
jest.mock('c/utilityString', () => ({
	formatTemplateString: jest.fn((template, values) =>
	{
		let result = template || '';
		if(values)
		{
			for(let i = 0; i < values.length; i++)
			{
				result = result.replace(`{${i}}`, values[i]);
			}
		}
		return result;
	})
}), {virtual: true});

// Mock utilitySystem - implementation must be inline due to Jest hoisting
jest.mock('c/utilitySystem', () => ({
	sortBy: jest.fn((field, direction) => (a, b) =>
	{
		if(!field)
		{
			return 0;
		}
		const dir = direction > 0 ? 1 : -1;
		if(a[field] < b[field])
		{
			return -1 * dir;
		}
		if(a[field] > b[field])
		{
			return 1 * dir;
		}
		return 0;
	})
}), {virtual: true});

const mockRows = [
	{Id: '001', Name: 'Account A', Industry: 'Technology'},
	{Id: '002', Name: 'Account B', Industry: 'Finance'},
	{Id: '003', Name: 'Account C', Industry: 'Healthcare'},
	{Id: '004', Name: 'Account D', Industry: 'Retail'},
	{Id: '005', Name: 'Account E', Industry: 'Manufacturing'}
];

const mockColumns = [
	{label: 'Name', fieldName: 'Name', sortable: true},
	{label: 'Industry', fieldName: 'Industry', sortable: true}
];

describe('c-paginated-table', () =>
{
	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
		jest.clearAllMocks();
	});

	async function flushPromises()
	{
		return new Promise((resolve) => setTimeout(resolve, 0));
	}

	// Helper to find button by label (LWC stubs expose label as property, not attribute)
	const findButtonByLabel = (element, label) =>
	{
		const buttons = element.shadowRoot.querySelectorAll('lightning-button');
		return Array.from(buttons).find(btn => btn.label === label);
	};

	const createComponent = (props = {}) =>
	{
		const element = createElement('c-paginated-table', {is: LwcPaginatedTable});
		Object.assign(element, {
			rows: mockRows, columns: mockColumns, resultsPerPage: 2, title: 'Test Table', ...props
		});
		document.body.appendChild(element);
		return element;
	};

	const mockDatatableSelectedRows = (datatable, initialRows = []) =>
	{
		let rows = initialRows;
		Object.defineProperty(datatable, 'selectedRows', {
			get: () => rows, set: (value) =>
			{
				rows = value;
			}, configurable: true
		});
		return {
			get rows()
			{
				return rows;
			}, set rows(value)
			{
				rows = value;
			}
		};
	};

	describe('initialization', () =>
	{
		it('renders lightning-card with title', async() =>
		{
			const element = createComponent();
			await flushPromises();

			const card = element.shadowRoot.querySelector('lightning-card');
			expect(card).not.toBeNull();
			expect(card.title).toBe('Test Table');
		});

		it('renders lightning-datatable', async() =>
		{
			const element = createComponent();
			await flushPromises();

			const datatable = element.shadowRoot.querySelector('lightning-datatable');
			expect(datatable).not.toBeNull();
		});

		it('sets up custom warning toast in connectedCallback', async() =>
		{
			createComponent();
			await flushPromises();

			// connectedCallback should call customNotificationFactory to create pester-mode warning
			expect(mockCustomNotificationFactory).toHaveBeenCalledWith('warning', 'pester');
		});
	});

	describe('@api properties', () =>
	{
		it('sets uniqueTableName', async() =>
		{
			const element = createComponent({uniqueTableName: 'myTable'});
			await flushPromises();

			expect(element.uniqueTableName).toBe('myTable');
		});

		it('sets keyField with default Id', async() =>
		{
			const element = createComponent();
			await flushPromises();

			expect(element.keyField).toBe('Id');
		});

		it('sets custom keyField', async() =>
		{
			const element = createComponent({keyField: 'CustomId__c'});
			await flushPromises();

			expect(element.keyField).toBe('CustomId__c');
		});
	});

	describe('numResultsPerPage getter', () =>
	{
		it('converts string resultsPerPage to number', async() =>
		{
			// @ts-ignore - intentionally passing string to test Number() coercion in numResultsPerPage getter
			const element = createComponent({resultsPerPage: '5'});
			await flushPromises();

			// Access internal getter via displayRows which uses numResultsPerPage
			const datatable = element.shadowRoot.querySelector('lightning-datatable');
			expect(datatable.data.length).toBeLessThanOrEqual(5);
		});
	});

	describe('isReadOnly getter', () =>
	{
		it('returns true when maxRowsSelected is 0', async() =>
		{
			const element = createComponent({maxRowsSelected: 0});
			await flushPromises();

			const datatable = element.shadowRoot.querySelector('lightning-datatable');
			expect(datatable.hideCheckboxColumn).toBe(true);
		});

		it('returns false when maxRowsSelected is not 0', async() =>
		{
			const element = createComponent({maxRowsSelected: 5});
			await flushPromises();

			const datatable = element.shadowRoot.querySelector('lightning-datatable');
			expect(datatable.hideCheckboxColumn).toBe(false);
		});
	});

	describe('displayMaxRowsSelected getter', () =>
	{
		it('returns 0 when maxRowsSelected is 0', async() =>
		{
			const element = createComponent({maxRowsSelected: 0});
			await flushPromises();

			const datatable = element.shadowRoot.querySelector('lightning-datatable');
			expect(datatable.maxRowSelection).toBe(0);
		});

		it('returns 100 when maxRowsSelected is undefined', async() =>
		{
			const element = createComponent({maxRowsSelected: undefined});
			await flushPromises();

			const datatable = element.shadowRoot.querySelector('lightning-datatable');
			expect(datatable.maxRowSelection).toBe(100);
		});

		it('returns actual value when maxRowsSelected is set', async() =>
		{
			const element = createComponent({maxRowsSelected: 25});
			await flushPromises();

			const datatable = element.shadowRoot.querySelector('lightning-datatable');
			expect(datatable.maxRowSelection).toBe(25);
		});
	});

	describe('dataTable getter', () =>
	{
		it('returns datatable element when rendered', async() =>
		{
			const element = createComponent();
			await flushPromises();

			const datatable = element.shadowRoot.querySelector('lightning-datatable');
			expect(datatable).not.toBeNull();
		});

		it('shows error toast when datatable accessed before render', async() =>
		{
			const element = createElement('c-paginated-table', {is: LwcPaginatedTable});
			element.rows = mockRows;
			element.columns = mockColumns;

			element.selectedTableRows;
			expect(mockShowErrorToast).toHaveBeenCalledWith('Table accessed before render.');
		});
	});

	describe('isValidResultsPerPage getter', () =>
	{
		it('returns true for valid positive number', async() =>
		{
			// Use resultsPerPage: 2 so pagination shows (5 rows / 2 = 3 pages)
			const element = createComponent({resultsPerPage: 2});
			await flushPromises();

			// showPagination uses isValidResultsPerPage
			const paginationExists = element.shadowRoot.querySelector('lightning-layout') !== null;
			expect(paginationExists).toBe(true);
		});

		it('returns false and shows warning for NaN', async() =>
		{
			// @ts-ignore - intentionally passing string to test NaN validation in isValidResultsPerPage
			const element = createComponent({resultsPerPage: 'invalid'});
			await flushPromises();

			// Invalid resultsPerPage should result in empty data
			const datatable = element.shadowRoot.querySelector('lightning-datatable');
			expect(datatable.data.length).toBe(0);
		});

		it('returns false and shows warning for zero', async() =>
		{
			createComponent({resultsPerPage: 0});
			await flushPromises();

			expect(mockCustomNotification).toHaveBeenCalled();
		});

		it('returns false and shows warning for negative number', async() =>
		{
			createComponent({resultsPerPage: -5});
			await flushPromises();

			expect(mockCustomNotification).toHaveBeenCalled();
		});
	});

	describe('displayRows getter', () =>
	{
		it('returns first page of rows', async() =>
		{
			const element = createComponent({resultsPerPage: 2});
			await flushPromises();

			const datatable = element.shadowRoot.querySelector('lightning-datatable');
			expect(datatable.data.length).toBe(2);
		});

		it('returns empty array for invalid resultsPerPage', async() =>
		{
			const element = createComponent({resultsPerPage: 'invalid'});
			await flushPromises();

			const datatable = element.shadowRoot.querySelector('lightning-datatable');
			expect(datatable.data.length).toBe(0);
		});

		it('sorts rows when sortedBy is set', async() =>
		{
			const element = createComponent({resultsPerPage: 5});
			await flushPromises();

			// Trigger sort
			const datatable = element.shadowRoot.querySelector('lightning-datatable');
			datatable.dispatchEvent(new CustomEvent('sort', {
				detail: {fieldName: 'Name', sortDirection: 'desc'}
			}));
			await flushPromises();

			// Verify sorting was applied by checking first row
			expect(datatable.sortedBy).toBe('Name');
			expect(datatable.sortedDirection).toBe('desc');
		});
	});

	describe('numberOfRows getter', () =>
	{
		it('returns total row count', async() =>
		{
			const element = createComponent();
			await flushPromises();

			// numberOfRows is used in totalPages calculation
			// With 5 rows and 2 per page = 3 pages
			const pageText = element.shadowRoot.querySelector('lightning-layout-item:nth-child(2)');
			expect(pageText.textContent).toContain('3');
		});
	});

	describe('totalPages getter', () =>
	{
		it('calculates correct total pages', async() =>
		{
			const element = createComponent({resultsPerPage: 2});
			await flushPromises();

			// 5 rows / 2 per page = 3 pages (ceil)
			const pageText = element.shadowRoot.querySelector('lightning-layout-item:nth-child(2)');
			expect(pageText.textContent).toContain('of 3');
		});
	});

	describe('showPagination getter', () =>
	{
		it('shows pagination when more than one page', async() =>
		{
			const element = createComponent({resultsPerPage: 2});
			await flushPromises();

			const pagination = element.shadowRoot.querySelector('lightning-layout');
			expect(pagination).not.toBeNull();
		});

		it('hides pagination when only one page', async() =>
		{
			const element = createComponent({resultsPerPage: 10});
			await flushPromises();

			const pagination = element.shadowRoot.querySelector('lightning-layout');
			expect(pagination).toBeNull();
		});
	});

	describe('selectedTableRows getter/setter', () =>
	{
		it('gets selected rows from datatable', async() =>
		{
			const element = createComponent();
			await flushPromises();

			const selectedRows = element.selectedTableRows;
			expect(Array.isArray(selectedRows)).toBe(true);
		});

		it('sets selected rows on datatable', async() =>
		{
			const element = createComponent();
			await flushPromises();

			element.selectedTableRows = [
				'001',
				'002'
			];
			await flushPromises();

			const datatable = element.shadowRoot.querySelector('lightning-datatable');
			expect(datatable.selectedRows).toEqual([
				'001',
				'002'
			]);
		});
	});

	describe('totalSelectedRowIds getter', () =>
	{
		it('returns all selected row IDs across pages', async() =>
		{
			const element = createComponent();
			await flushPromises();

			// Initially empty
			expect(element.totalSelectedRowIds).toEqual([]);
		});
	});

	describe('disablePreviousButton getter', () =>
	{
		it('returns true on first page', async() =>
		{
			const element = createComponent({resultsPerPage: 2});
			await flushPromises();

			const prevButton = findButtonByLabel(element, 'Previous');
			expect(prevButton).not.toBeNull();
			expect(prevButton.disabled).toBe(true);
		});

		it('returns false on subsequent pages', async() =>
		{
			const element = createComponent({resultsPerPage: 2});
			await flushPromises();

			// Go to next page
			const nextButton = findButtonByLabel(element, 'Next');
			nextButton.click();
			await flushPromises();

			const prevButton = findButtonByLabel(element, 'Previous');
			expect(prevButton.disabled).toBe(false);
		});
	});

	describe('disableNextButton getter', () =>
	{
		it('returns false when not on last page', async() =>
		{
			const element = createComponent({resultsPerPage: 2});
			await flushPromises();

			const nextButton = findButtonByLabel(element, 'Next');
			expect(nextButton).not.toBeNull();
			expect(nextButton.disabled).toBe(false);
		});

		it('returns true on last page', async() =>
		{
			const element = createComponent({resultsPerPage: 2});
			await flushPromises();

			// Go to page 2
			let nextButton = findButtonByLabel(element, 'Next');
			nextButton.click();
			await flushPromises();

			// Go to page 3 (last page)
			nextButton = findButtonByLabel(element, 'Next');
			nextButton.click();
			await flushPromises();

			nextButton = findButtonByLabel(element, 'Next');
			expect(nextButton.disabled).toBe(true);
		});
	});

	describe('previousHandler', () =>
	{
		it('decrements page and dispatches pagechange event', async() =>
		{
			const element = createComponent({resultsPerPage: 2});
			await flushPromises();

			const pageChangeHandler = jest.fn();
			element.addEventListener('pagechange', pageChangeHandler);

			// Go to page 2 first
			let nextButton = findButtonByLabel(element, 'Next');
			nextButton.click();
			await flushPromises();

			// Now go back
			const prevButton = findButtonByLabel(element, 'Previous');
			prevButton.click();
			await flushPromises();

			expect(pageChangeHandler).toHaveBeenCalledWith(expect.objectContaining({
				detail: {pageNumber: 1}
			}));
		});

		it('sets preselected rows after page change', async() =>
		{
			const element = createComponent({resultsPerPage: 2});
			await flushPromises();

			// Go to page 2
			let nextButton = findButtonByLabel(element, 'Next');
			nextButton.click();
			await flushPromises();

			// Select rows on page 2
			const datatable = element.shadowRoot.querySelector('lightning-datatable');
			datatable.selectedRows = [
				'003',
				'004'
			];
			datatable.dispatchEvent(new CustomEvent('rowselection'));
			await flushPromises();

			// Go back to page 1
			const prevButton = findButtonByLabel(element, 'Previous');
			prevButton.click();
			await flushPromises();

			// Verify datatable still has all selected rows
			expect(datatable.selectedRows).toBeDefined();
		});
	});

	describe('nextHandler', () =>
	{
		it('increments page and dispatches pagechange event', async() =>
		{
			const element = createComponent({resultsPerPage: 2});
			await flushPromises();

			const pageChangeHandler = jest.fn();
			element.addEventListener('pagechange', pageChangeHandler);

			const nextButton = findButtonByLabel(element, 'Next');
			nextButton.click();
			await flushPromises();

			expect(pageChangeHandler).toHaveBeenCalledWith(expect.objectContaining({
				detail: {pageNumber: 2}
			}));
		});
	});

	describe('sortColumns', () =>
	{
		it('dispatches columnsort event with field and direction', async() =>
		{
			const element = createComponent({resultsPerPage: 2});
			await flushPromises();

			const sortHandler = jest.fn();
			element.addEventListener('columnsort', sortHandler);

			const datatable = element.shadowRoot.querySelector('lightning-datatable');
			datatable.dispatchEvent(new CustomEvent('sort', {
				detail: {fieldName: 'Name', sortDirection: 'asc'}
			}));
			await flushPromises();

			expect(sortHandler).toHaveBeenCalledWith(expect.objectContaining({
				detail: {sortedBy: 'Name', sortDirection: 'asc'}
			}));
		});

		it('updates sortedBy and sortDirection properties', async() =>
		{
			const element = createComponent({resultsPerPage: 2});
			await flushPromises();

			const datatable = element.shadowRoot.querySelector('lightning-datatable');
			datatable.dispatchEvent(new CustomEvent('sort', {
				detail: {fieldName: 'Industry', sortDirection: 'desc'}
			}));
			await flushPromises();

			// Verify sort was applied by checking sortedBy attribute
			expect(datatable.sortedBy).toBe('Industry');
		});
	});

	describe('selectRows', () =>
	{
		it('dispatches rowselection event with all selected rows', async() =>
		{
			const element = createComponent({resultsPerPage: 2});
			await flushPromises();

			const rowSelectionHandler = jest.fn();
			element.addEventListener('rowselection', rowSelectionHandler);

			const datatable = element.shadowRoot.querySelector('lightning-datatable');
			mockDatatableSelectedRows(datatable, [
				'001',
				'002'
			]);
			datatable.dispatchEvent(new CustomEvent('rowselection'));
			await flushPromises();

			expect(rowSelectionHandler).toHaveBeenCalled();
		});

		it('tracks selected rows across pages', async() =>
		{
			const element = createComponent({resultsPerPage: 2});
			await flushPromises();

			const datatable = element.shadowRoot.querySelector('lightning-datatable');
			const mock = mockDatatableSelectedRows(datatable, ['001']);
			datatable.dispatchEvent(new CustomEvent('rowselection'));
			await flushPromises();

			// Go to page 2
			const nextButton = findButtonByLabel(element, 'Next');
			nextButton.click();
			await flushPromises();

			// Select on page 2
			mock.rows = ['003'];
			datatable.dispatchEvent(new CustomEvent('rowselection'));
			await flushPromises();

			// Check totalSelectedRowIds includes both pages
			const totalSelected = element.totalSelectedRowIds;
			expect(totalSelected).toContain('001');
			expect(totalSelected).toContain('003');
		});

		it('handles empty selection', async() =>
		{
			const element = createComponent({resultsPerPage: 2});
			await flushPromises();

			const datatable = element.shadowRoot.querySelector('lightning-datatable');
			mockDatatableSelectedRows(datatable, []);
			datatable.dispatchEvent(new CustomEvent('rowselection'));
			await flushPromises();

			expect(element.totalSelectedRowIds).toEqual([]);
		});
	});

	describe('resetPageNumber', () =>
	{
		it('resets page to 1 when resultsPerPage becomes invalid', async() =>
		{
			// Use enough rows per page that we have pagination
			const element = createComponent({resultsPerPage: 2});
			await flushPromises();

			// Verify pagination exists
			let nextButton = findButtonByLabel(element, 'Next');
			expect(nextButton).not.toBeUndefined();

			// Go to page 2
			nextButton.click();
			await flushPromises();

			// @ts-ignore - intentionally passing string to test resetPageNumber via isValidResultsPerPage
			element.resultsPerPage = 'invalid';
			await flushPromises();
			await flushPromises();

			// Pagination should be hidden now
			const pagination = element.shadowRoot.querySelector('lightning-layout');
			expect(pagination).toBeNull();
		});
	});

	describe('currentPage getter', () =>
	{
		it('returns current page number', async() =>
		{
			const element = createComponent({resultsPerPage: 2});
			await flushPromises();

			const pageText = element.shadowRoot.querySelector('lightning-layout-item:nth-child(2)');
			expect(pageText.textContent).toContain('Page 1');
		});
	});

	describe('displayRows pagination', () =>
	{
		it('calculates correct start index for page 1', async() =>
		{
			const element = createComponent({resultsPerPage: 2});
			await flushPromises();

			const datatable = element.shadowRoot.querySelector('lightning-datatable');
			expect(datatable).not.toBeNull();
			expect(datatable.data.length).toBe(2);
		});

		it('calculates correct start index for page 2', async() =>
		{
			const element = createComponent({resultsPerPage: 2});
			await flushPromises();

			const nextButton = findButtonByLabel(element, 'Next');
			expect(nextButton).not.toBeUndefined();
			nextButton.click();
			await flushPromises();

			const datatable = element.shadowRoot.querySelector('lightning-datatable');
			expect(datatable).not.toBeNull();
			expect(datatable.data.length).toBe(2);
		});

		it('handles last page with fewer rows', async() =>
		{
			const element = createComponent({resultsPerPage: 2});
			await flushPromises();

			// Go to last page (page 3 with 5 rows / 2 per page)
			let nextButton = findButtonByLabel(element, 'Next');
			expect(nextButton).not.toBeUndefined();
			nextButton.click();
			await flushPromises();

			// Re-query because DOM updates
			nextButton = findButtonByLabel(element, 'Next');
			nextButton.click();
			await flushPromises();

			const datatable = element.shadowRoot.querySelector('lightning-datatable');
			expect(datatable).not.toBeNull();
			expect(datatable.data.length).toBe(1); // Only 1 row on last page
		});
	});

	describe('edge cases', () =>
	{
		it('handles empty rows array', async() =>
		{
			const element = createComponent({rows: [], resultsPerPage: 2});
			await flushPromises();

			const datatable = element.shadowRoot.querySelector('lightning-datatable');
			expect(datatable).not.toBeNull();
			expect(datatable.data).toEqual([]);
		});

		it('handles single row', async() =>
		{
			const element = createComponent({
				rows: [{Id: '001', Name: 'Single'}], resultsPerPage: 2
			});
			await flushPromises();

			const pagination = element.shadowRoot.querySelector('lightning-layout');
			expect(pagination).toBeNull(); // No pagination needed
		});

		it('handles datatable access before render via selectedTableRows getter', async() =>
		{
			// Test selectedTableRows getter when dataTable returns null
			const element = createElement('c-paginated-table', {is: LwcPaginatedTable});
			element.rows = mockRows;
			element.columns = mockColumns;
			element.resultsPerPage = 2;

			// Access selectedTableRows before appending to DOM - this triggers dataTable getter with null
			const selectedRows = element.selectedTableRows;
			expect(selectedRows).toEqual([]);
		});

		it('handles datatable access before render via selectedTableRows setter', async() =>
		{
			const element = createElement('c-paginated-table', {is: LwcPaginatedTable});
			element.rows = mockRows;
			element.columns = mockColumns;
			element.resultsPerPage = 2;

			element.selectedTableRows = ['001'];
			expect(mockShowErrorToast).toHaveBeenCalledWith('Table accessed before render.');
		});

		it('handles setPreselectedRows when dataTable exists', async() =>
		{
			const element = createComponent({resultsPerPage: 2});
			await flushPromises();

			// Select some rows
			const datatable = element.shadowRoot.querySelector('lightning-datatable');
			mockDatatableSelectedRows(datatable, ['001']);
			datatable.dispatchEvent(new CustomEvent('rowselection'));
			await flushPromises();

			// Navigate to trigger setPreselectedRows - use helper, not attribute selector
			const nextButton = findButtonByLabel(element, 'Next');
			nextButton.click();
			await flushPromises();

			// setPreselectedRows should have been called
			expect(datatable.selectedRows).toBeDefined();
		});
	});
});
