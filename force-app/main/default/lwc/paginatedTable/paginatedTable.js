// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Paginated Lightning Datatable with cross-page row selection tracking,
 * column sorting delegation, and configurable results-per-page validation.
 *
 * @event rowselection When a row is selected, this event emits all the rows selected across pages.
 * @event pagechange When the page is changed, this event emits the current page.
 * @event columnsort When the user clicks on the row sort button, this event emits the column's field name and sorting direction. Sorting is handled by the
 * parent component.
 *
 * @author Jason van Beukering
 *
 * @date February 2026, July 2026
 */
import INVALID_PAGE_SIZE_HEADING from '@salesforce/label/c.PaginatedTable_InvalidPageSizeHeading';
import INVALID_PAGE_SIZE_MESSAGE from '@salesforce/label/c.PaginatedTable_InvalidPageSizeMessage';
import NEXT_LABEL from '@salesforce/label/c.PaginatedTable_Next';
import PAGE_OF_PAGES from '@salesforce/label/c.PaginatedTable_PageOfPages';
import PREVIOUS_LABEL from '@salesforce/label/c.PaginatedTable_Previous';
import {ComponentBuilder} from 'c/componentBuilder';
import {formatTemplateString} from 'c/utilityString';
import {sortBy} from 'c/utilitySystem';
import {api} from 'lwc';

// ── Helpers ──────────────────────────────────────────────────────────────

/**
 * @description Calculates the start and end indices for a page slice given the current
 * page number and page size.
 * @param {number} page - Current 1-based page number
 * @param {number} pageSize - Number of rows per page
 * @returns {{start: number, end: number}} Zero-based start (inclusive) and end (exclusive)
 */
function calculatePageSlice(page, pageSize)
{
	const start = page === 1 ? 0 : (page - 1) * pageSize;
	return {start, end: start + pageSize};
}

//noinspection SpellCheckingInspection
export default class PaginatedTable extends ComponentBuilder('notification', 'lightning-message')
{
	// ── @api Properties ──────────────────────────────────────────────────

	/** @description Unique name for this table instance, used for disambiguation. */
	@api uniqueTableName;

	/**
	 * @description Rows to display on the table. Uses the same form as lightning-datatable.
	 * @type {[]}
	 */
	@api rows = [];

	/**
	 * @description Table Title
	 * @type {string}
	 */
	@api title = '';

	/**
	 * @description Table column configuration. Uses the same form as lightning-datatable.
	 * @type {[]}
	 */
	@api columns = [];

	/**
	 * @description Display Rows per Page. Decides how many results are displayed per page.
	 * @type {number}
	 */
	@api resultsPerPage = 10;

	/**
	 * @description Chooses how many rows can be selected from the table by the user
	 */
	@api maxRowsSelected;

	/**
	 * @description Indicates the row property that is used as the unique row identifier. Defaults to 'Id'.
	 * @type {string}
	 */
	@api keyField = 'Id';

	// ── Internal State ───────────────────────────────────────────────────

	/**
	 * @description Map of page numbers to arrays of selected row IDs for that page.
	 * @type {Object<number, string[]>}
	 */
	pageSelectionMap = {};

	/** @description Current 1-based page number. */
	page = 1;

	/** @description Current sort direction ('asc' or 'desc'). */
	sortDirection = 'asc';

	/** @description Field name of the currently sorted column. */
	sortedBy;

	/**
	 * @description Flattened list of all selected row IDs across every page.
	 * @type {string[]}
	 */
	aggregatedSelections = [];

	/**
	 * @description The invalid results-per-page value already warned about, so the warning fires once
	 * per distinct invalid value instead of on every render.
	 */
	lastWarnedResultsPerPage;

	/** @description Template-bound Custom Labels for the pagination buttons. */
	labels = {
		next: NEXT_LABEL, previous: PREVIOUS_LABEL
	};

	// ── Computed Properties ──────────────────────────────────────────────

	/**
	 * @description Used to ensure that a number is used during page calculation, since a parent component might pass in a string instead of a number
	 * @returns {number}
	 */
	get numResultsPerPage()
	{
		return Number(this.resultsPerPage);
	}

	/**
	 * @description Hides the checkbox column if the table should not allow rows to be selected.
	 * @returns {boolean}
	 */
	get isReadOnly()
	{
		return this.maxRowsSelected === 0;
	}

	get displayMaxRowsSelected()
	{
		return this.maxRowsSelected === 0 ? 0 : this.maxRowsSelected || 100;
	}

	get dataTable()
	{
		let dataTable = this.template.querySelector('lightning-datatable');
		if(!dataTable)
		{
			// Developer-only invariant: fires when a parent composes the table wrongly and
			// queries it before first render — never reachable from subscriber interaction.
			// eslint-disable-next-line kerndx/no-hardcoded-user-text
			this.showErrorToast('Table accessed before render.');
		}
		return dataTable;
	}

	/**
	 * @description Whether the configured results-per-page value is a valid positive number. Pure — the
	 * invalid-value side effects (page reset + warning toast) run in renderedCallback, never during render.
	 * @returns {boolean}
	 */
	get isValidResultsPerPage()
	{
		return !isNaN(this.numResultsPerPage) && (this.numResultsPerPage > 0);
	}

	get currentPage()
	{
		return this.page;
	}

	/**
	 * @description Returns the slice of rows for the current page, sorted by the active column.
	 * @returns {Array}
	 */
	get displayRows()
	{
		if(!this.isValidResultsPerPage)
		{
			return [];
		}

		const rows = [...this.rows].sort(sortBy(this.sortedBy, this.sortDirection === 'asc' ? 1 : -1, null));
		const {start, end} = calculatePageSlice(this.currentPage, this.numResultsPerPage);
		return rows.slice(start, end);
	}

	get numberOfRows()
	{
		return this.rows.length;
	}

	get totalPages()
	{
		return Math.ceil(this.numberOfRows / this.resultsPerPage);
	}

	get showPagination()
	{
		return this.isValidResultsPerPage && this.totalPages > 1;
	}

	/**
	 * @description Pagination position text composed from the page-of-pages template label —
	 * the HTML template cannot interpolate a label around bindings.
	 * @returns {string}
	 */
	get pageOfPagesLabel()
	{
		return formatTemplateString(PAGE_OF_PAGES, [
			this.page,
			this.totalPages
		]);
	}

	/**
	 * @description Returns the current state of the table. Will only return which rows are visibly selected on the table. To see all rows selected across pages,
	 * listen for the 'rowselection' event or get the totalSelectedRows property.
	 * @returns {*[]}
	 */
	@api get selectedTableRows()
	{
		//noinspection JSUnresolvedVariable
		return this.dataTable ? this.dataTable.selectedRows : [];
	}

	//noinspection JSUnusedGlobalSymbols
	/**
	 * @description Directly sets the table with a list of values
	 * @param {Array} value Array of row IDs to select
	 */
	set selectedTableRows(value)
	{
		if(this.dataTable)
		{
			this.dataTable.selectedRows = [...value];
		}
	}

	/**
	 * @description Returns all row Ids that have been selected across pages.
	 * @returns {*[]}
	 */
	@api get totalSelectedRowIds()
	{
		return this.aggregatedSelections;
	}

	get disablePreviousButton()
	{
		return this.page <= 1;
	}

	get disableNextButton()
	{
		return this.page >= this.totalPages;
	}

	// ── Lifecycle ────────────────────────────────────────────────────────

	connectedCallback()
	{
		// Overriding showWarningToast to use 'pester' instead of 'dismissible'
		this.showWarningToast = this.customNotificationFactory('warning', 'pester');
	}

	renderedCallback()
	{
		this.handleInvalidResultsPerPage();
	}

	/**
	 * @description Runs the invalid results-per-page side effects outside the render path: resets to the
	 * first page and warns once per distinct invalid value. Clears the warned marker on a valid value so a
	 * later regression warns again.
	 */
	handleInvalidResultsPerPage()
	{
		if(this.isValidResultsPerPage)
		{
			this.lastWarnedResultsPerPage = undefined;
			return;
		}

		if(this.page !== 1)
		{
			this.resetPageNumber();
		}

		if(this.lastWarnedResultsPerPage !== this.resultsPerPage)
		{
			this.lastWarnedResultsPerPage = this.resultsPerPage;
			this.showWarningToast(INVALID_PAGE_SIZE_MESSAGE, formatTemplateString(INVALID_PAGE_SIZE_HEADING, [this.resultsPerPage]));
		}
	}

	// ── Navigation ───────────────────────────────────────────────────────

	resetPageNumber()
	{
		this.page = 1;
	}

	/**
	 * @description Handles Previous page button click
	 */
	previousHandler()
	{
		this.page--;
		this.setPreselectedRows();
		this.dispatchPageChangeEvent();
	}

	/**
	 * @description Handles Next page button click
	 */
	nextHandler()
	{
		this.page++;
		this.setPreselectedRows();
		this.dispatchPageChangeEvent();
	}

	// ── Event Handlers ───────────────────────────────────────────────────

	/**
	 * @description Emits an event requesting for the table data to be sorted. Sorting must be handled by the parent component, in order to support both client-
	 * side and server-side sorting.
	 * @param {CustomEvent} event Sort event with detail containing fieldName and sortDirection
	 */
	sortColumns(event)
	{
		const {fieldName: sortedBy, sortDirection} = event.detail;
		this.sortedBy = sortedBy;
		this.sortDirection = sortDirection;
		this.dispatchEvent(new CustomEvent('columnsort', {detail: {sortedBy, sortDirection}}));
	}

	/**
	 * @description Dispatches a 'pagechange' event to alert the parent component that the page has changed.
	 */
	dispatchPageChangeEvent()
	{
		this.dispatchEvent(new CustomEvent('pagechange', {detail: {pageNumber: this.page}}));
	}

	// ── Row Selection ────────────────────────────────────────────────────

	/**
	 * @description Handles selection of rows across all pages. Saves the current page's
	 * selections and rebuilds the flattened aggregation from all pages.
	 */
	selectRows()
	{
		this.pageSelectionMap[this.page] = [...this.selectedTableRows];

		const allRows = Object.values(this.pageSelectionMap)
		.filter(Boolean)
		.flat();

		this.aggregatedSelections = [...allRows];
		this.dispatchEvent(new CustomEvent('rowselection', {detail: {rows: allRows}}));
	}

	/**
	 * @description Sets the table rows to the currently selected rows. Used to re-render the table.
	 */
	setPreselectedRows()
	{
		this.dataTable.selectedRows = this.aggregatedSelections;
	}
}