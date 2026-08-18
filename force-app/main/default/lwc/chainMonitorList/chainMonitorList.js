// SPDX-License-Identifier: BUSL-1.1
/**
 * @description List panel showing filtered, sorted, and paginated async chain executions.
 * Supports status filtering and row selection to drive the detail panel.
 *
 * @author Jason van Beukering
 *
 * @date April 2026, August 2026
 */
import {api} from 'lwc';
import {ComponentBuilder} from 'c/componentBuilder';
import {formatTemplateString} from 'c/utilityString';
import getChainExecutions from '@salesforce/apex/CTRL_ChainMonitor.getChainExecutions';
import statusRunning from '@salesforce/label/c.ChainMonitor_StatusRunning';
import statusCompleted from '@salesforce/label/c.ChainMonitor_StatusCompleted';
import statusFailed from '@salesforce/label/c.ChainMonitor_StatusFailed';
import statusAborted from '@salesforce/label/c.ChainMonitor_StatusAborted';
import statusStalled from '@salesforce/label/c.ChainMonitor_StatusStalled';
import chainNameLabel from '@salesforce/label/c.ChainMonitor_ChainName';
import statusLabel from '@salesforce/label/c.ChainMonitor_Status';
import columnProgress from '@salesforce/label/c.ChainMonitor_ColumnProgress';
import startedLabel from '@salesforce/label/c.ChainMonitor_Started';
import durationLabel from '@salesforce/label/c.ChainMonitor_Duration';
import clearAll from '@salesforce/label/c.ChainMonitor_ClearAll';
import selectAll from '@salesforce/label/c.ChainMonitor_SelectAll';
import pageLabelTemplate from '@salesforce/label/c.ChainMonitor_PageLabel';
import nameFilterPlaceholder from '@salesforce/label/c.ChainMonitor_NameFilterPlaceholder';
import previousLabel from '@salesforce/label/c.ChainMonitor_PreviousLabel';
import nextLabel from '@salesforce/label/c.ChainMonitor_NextLabel';
import durationElapsedTemplate from '@salesforce/label/c.ChainMonitor_DurationElapsed';
import listEmptyHeading from '@salesforce/label/c.ChainMonitor_ListEmptyHeading';
import listEmptyBody from '@salesforce/label/c.ChainMonitor_ListEmptyBody';
import listNoStatusBody from '@salesforce/label/c.ChainMonitor_ListNoStatusBody';

const STATUS_OPTIONS = [
	{label: statusRunning, value: 'Running'},
	{label: statusCompleted, value: 'Completed'},
	{label: statusFailed, value: 'Failed'},
	{label: statusAborted, value: 'Aborted'},
	{label: statusStalled, value: 'Stalled'}
];

const ALL_STATUS_VALUES = STATUS_OPTIONS.map((option) => option.value);

// The statuses of a run that has not finished. Their duration is the time since the run started
// rather than a total it recorded on ending, so the cell says which of the two it is showing.
const UNFINISHED_STATUS_VALUES = new Set([
	'Running',
	'Stalled'
]);

// What a cell shows when the row carries no value for it at all.
const EM_DASH = '—';

// Chain Name and Started carry the two values a reader picks a run by, so they take whatever width
// is left; the three compact columns hold their own. Given no width of its own, every column takes
// an equal fifth of the pane, which truncates the name below the very term that was searched for
// and cuts the start time mid-clock while '1.9s' sits in a cell twice the size it needs.
// The pinned columns never wrap, so their header menus only cost width.
const STATUS_COLUMN_WIDTH = 110;
const PROGRESS_COLUMN_WIDTH = 110;
const DURATION_COLUMN_WIDTH = 130;

const COLUMNS = [
	{
		label: chainNameLabel, fieldName: 'recordUrl', type: 'url', sortable: true, typeAttributes: {label: {fieldName: 'chainName'}}
	},
	{
		label: statusLabel, fieldName: 'status', type: 'text', sortable: true, initialWidth: STATUS_COLUMN_WIDTH, hideDefaultActions: true
	},
	{
		label: columnProgress, fieldName: 'progressLabel', type: 'text', sortable: false, initialWidth: PROGRESS_COLUMN_WIDTH, hideDefaultActions: true
	},
	{
		label: startedLabel,
		fieldName: 'startedAt',
		type: 'date',
		sortable: true,
		typeAttributes: {year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit'}
	},
	{
		label: durationLabel, fieldName: 'durationDisplay', type: 'text', sortable: true, initialWidth: DURATION_COLUMN_WIDTH, hideDefaultActions: true
	}
];

const PAGE_SIZE = 20;

/**
 * @description What the Duration cell shows for one row: the recorded total for a run that has
 * ended, the same value marked as still climbing for a run that has not, and an em dash when the
 * row carries no duration at all. The marking earns its place because a running or stalled row is
 * the one a stuck-chain triage measures, and its number is still moving.
 *
 * @param {object} record The chain summary returned by the controller.
 *
 * @returns {string} The text for the row's Duration cell.
 */
function resolveDurationDisplay(record)
{
	if(!record.durationLabel)
	{
		return EM_DASH;
	}

	return UNFINISHED_STATUS_VALUES.has(record.status) ? formatTemplateString(durationElapsedTemplate, [record.durationLabel]) : record.durationLabel;
}

export default class ChainMonitorList extends ComponentBuilder('controller', 'notification')
{
	columns = COLUMNS;
	statusOptions = STATUS_OPTIONS;
	statusFilters = [...ALL_STATUS_VALUES];
	nameFilter = '';
	sortField = 'StartedAt';
	sortAscending = false;
	pageNumber = 1;
	totalCount = 0;
	totalPages = 0;
	hasMorePages = false;
	records = [];
	showFilters = false;
	selectedExecutionId = null;

	label = {
		nameFilter: chainNameLabel, nameFilterPlaceholder, statusFilter: statusLabel, previous: previousLabel, next: nextLabel, emptyStateHeading: listEmptyHeading
	};

	get isAllStatusesSelected()
	{
		return this.statusFilters.length === STATUS_OPTIONS.length;
	}

	get hasRecords()
	{
		return this.records.length > 0;
	}

	get hasStatusSelection()
	{
		return this.statusFilters.length > 0;
	}

	/**
	 * @description Why the list is empty, in the reader's terms: an unselectable status filter is a
	 * different problem from a search that matched nothing, and each has its own way out.
	 *
	 * @returns {string}
	 */
	get emptyStateBody()
	{
		return this.hasStatusSelection ? listEmptyBody : listNoStatusBody;
	}

	get toggleAllLabel()
	{
		return this.isAllStatusesSelected ? clearAll : selectAll;
	}

	get noPrevious()
	{
		return this.pageNumber <= 1;
	}

	get noNext()
	{
		return !this.hasMorePages;
	}

	get pageLabel()
	{
		return formatTemplateString(pageLabelTemplate, [
			this.pageNumber,
			this.totalPages
		]);
	}

	get sortDirection()
	{
		return this.sortAscending ? 'asc' : 'desc';
	}

	get selectedRows()
	{
		return this.selectedExecutionId ? [this.selectedExecutionId] : [];
	}

	get sortedBy()
	{
		const reverseMap = {
			ChainName: 'recordUrl', Status: 'status', StartedAt: 'startedAt', DurationMs: 'durationDisplay'
		};
		return reverseMap[this.sortField] || 'startedAt';
	}

	async connectedCallback()
	{
		await this.loadData();
	}

	async loadData()
	{
		// Nothing can match an empty set of statuses, so the list says so rather than sending the empty
		// set as "no status filter", which returns every chain and looks exactly like every status
		// ticked, leaving nothing on screen to tell the two apart.
		if(!this.hasStatusSelection)
		{
			this.records = [];
			this.totalCount = 0;
			this.totalPages = 0;
			this.hasMorePages = false;
			this.selectExecution(null);
			return;
		}

		this.isLoading = true;

		const request = {
			statusFilters: this.isAllStatusesSelected ? [] : [...this.statusFilters],
			nameFilter: this.nameFilter || null,
			sortField: this.sortField,
			sortAscending: this.sortAscending,
			pageSize: PAGE_SIZE,
			pageNumber: this.pageNumber
		};

		const data = await this.callControllerMethod(getChainExecutions, {requestJson: JSON.stringify(request)});
		if(data?.records)
		{
			this.records = data.records.map((record) =>
			{
				const percent = record.totalSteps > 0 ? Math.round((record.completedSteps / record.totalSteps) * 100) : 0;
				return {
					...record,
					progressLabel: `${record.completedSteps}/${record.totalSteps} (${percent}%)`,
					durationDisplay: resolveDurationDisplay(record),
					recordUrl: `/lightning/r/${record.executionId}/view`
				};
			});
			this.totalCount = data.totalCount;
			this.totalPages = data.totalPages;
			this.hasMorePages = data.hasMorePages;
			this.pageNumber = data.pageNumber;

			this.reconcileSelection();
		}
		else
		{
			this.records = [];
			this.selectExecution(null);
		}

		this.isLoading = false;
	}

	reconcileSelection()
	{
		if(this.records.length === 0)
		{
			this.selectExecution(null);
			return;
		}

		// An existing selection is kept even when it is not on the current page (deep-linked or
		// paged-away chains): the detail panel keeps showing it and only the row highlight is
		// absent. Auto-select the first row only when nothing is selected yet.
		if(!this.selectedExecutionId)
		{
			this.selectExecution(this.records[0].executionId);
		}
	}

	selectExecution(executionId, isUserSelection)
	{
		this.selectedExecutionId = executionId;
		this.dispatchEvent(new CustomEvent('select', {detail: {executionId, isUserSelection: isUserSelection === true}}));
	}

	handleToggleFilters()
	{
		this.showFilters = !this.showFilters;
	}

	async handleStatusChange(event)
	{
		this.statusFilters = event.detail.value;
		this.pageNumber = 1;
		await this.reloadAndResetSelection();
	}

	async handleToggleAllStatuses()
	{
		this.statusFilters = this.isAllStatusesSelected ? [] : [...ALL_STATUS_VALUES];
		this.pageNumber = 1;
		await this.reloadAndResetSelection();
	}

	async handleNameSearch(event)
	{
		this.nameFilter = event.target.value;
		this.pageNumber = 1;
		await this.reloadAndResetSelection();
	}

	async handleSort(event)
	{
		const fieldMap = {
			recordUrl: 'ChainName', status: 'Status', startedAt: 'StartedAt', durationDisplay: 'DurationMs'
		};

		this.sortField = fieldMap[event.detail.fieldName] || 'CreatedDate';
		this.sortAscending = event.detail.sortDirection === 'asc';
		await this.reloadAndResetSelection();
	}

	/**
	 * @description Reloads after a change that rebuilds the whole result: a new sort order, a new
	 * status filter, a new search term. Dropping the selection first is what makes the detail pane
	 * follow. Keeping it would leave the pane showing a chain the new result excludes, or one no
	 * row highlights, because the selected id never changed and the pane only reloads when it does.
	 * The tolerance for a selection that is simply on another page belongs to paging alone, where
	 * the reader moved the window rather than the result.
	 */
	async reloadAndResetSelection()
	{
		this.selectedExecutionId = null;
		await this.loadData();
	}

	handleRowSelection(event)
	{
		const selectedRows = event.detail.selectedRows;
		if(selectedRows && selectedRows.length > 0)
		{
			this.selectExecution(selectedRows[0].executionId, true);
		}
	}

	async handlePrevious()
	{
		if(this.pageNumber > 1)
		{
			this.pageNumber--;
			await this.loadData();
		}
	}

	async handleNext()
	{
		if(this.hasMorePages)
		{
			this.pageNumber++;
			await this.loadData();
		}
	}

	@api async refresh()
	{
		await this.loadData();
	}

	@api selectById(executionId)
	{
		// Drives the detail panel to a deep-linked chain. The row highlight follows only when the
		// chain is on the current page; the detail panel loads by id either way.
		if(executionId)
		{
			this.selectExecution(executionId);
		}
	}
}