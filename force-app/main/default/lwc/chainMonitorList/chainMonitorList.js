// SPDX-License-Identifier: BUSL-1.1
/**
 * @description List panel showing filtered, sorted, and paginated async chain executions.
 * Supports status filtering and row selection to drive the detail panel.
 *
 * @author Jason van Beukering
 *
 * @date April 2026, May 2026
 */
import {api} from 'lwc';
import {ComponentBuilder} from 'c/componentBuilder';
import getChainExecutions from '@salesforce/apex/CTRL_ChainMonitor.getChainExecutions';

const STATUS_OPTIONS = [
	{label: 'Running', value: 'Running'},
	{label: 'Completed', value: 'Completed'},
	{label: 'Failed', value: 'Failed'},
	{label: 'Aborted', value: 'Aborted'},
	{label: 'Stalled', value: 'Stalled'}
];

const ALL_STATUS_VALUES = STATUS_OPTIONS.map((option) => option.value);

const COLUMNS = [
	{
		label: 'Chain Name', fieldName: 'recordUrl', type: 'url', sortable: true, typeAttributes: {label: {fieldName: 'chainName'}}
	},
	{label: 'Status', fieldName: 'status', type: 'text', sortable: true},
	{label: 'Progress', fieldName: 'progressLabel', type: 'text', sortable: false},
	{
		label: 'Started',
		fieldName: 'startedAt',
		type: 'date',
		sortable: true,
		typeAttributes: {year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit'}
	},
	{label: 'Duration', fieldName: 'durationLabel', type: 'text', sortable: true}
];

const PAGE_SIZE = 20;

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

	get isAllStatusesSelected()
	{
		return this.statusFilters.length === STATUS_OPTIONS.length;
	}

	get toggleAllLabel()
	{
		return this.isAllStatusesSelected ? 'Clear All' : 'Select All';
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
		return `Page ${this.pageNumber} of ${this.totalPages}`;
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
			ChainName: 'recordUrl', Status: 'status', StartedAt: 'startedAt', DurationMs: 'durationLabel'
		};
		return reverseMap[this.sortField] || 'startedAt';
	}

	async connectedCallback()
	{
		await this.loadData();
	}

	async loadData()
	{
		this.isLoading = true;

		const allSelected = this.statusFilters.length === STATUS_OPTIONS.length || this.statusFilters.length === 0;

		const request = {
			statusFilters: allSelected ? [] : [...this.statusFilters],
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
					...record, progressLabel: `${record.completedSteps}/${record.totalSteps} (${percent}%)`, recordUrl: `/lightning/r/${record.executionId}/view`
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

		const currentStillExists = this.selectedExecutionId && this.records.some((record) => record.executionId === this.selectedExecutionId);

		if(currentStillExists)
		{
			return;
		}

		this.selectExecution(this.records[0].executionId);
	}

	selectExecution(executionId)
	{
		this.selectedExecutionId = executionId;
		this.dispatchEvent(new CustomEvent('select', {detail: {executionId}}));
	}

	handleToggleFilters()
	{
		this.showFilters = !this.showFilters;
	}

	async handleStatusChange(event)
	{
		this.statusFilters = event.detail.value;
		this.pageNumber = 1;
		await this.loadData();
	}

	async handleToggleAllStatuses()
	{
		this.statusFilters = this.isAllStatusesSelected ? [] : [...ALL_STATUS_VALUES];
		this.pageNumber = 1;
		await this.loadData();
	}

	async handleNameSearch(event)
	{
		this.nameFilter = event.target.value;
		this.pageNumber = 1;
		await this.loadData();
	}

	async handleSort(event)
	{
		const fieldMap = {
			recordUrl: 'ChainName', status: 'Status', startedAt: 'StartedAt', durationLabel: 'DurationMs'
		};

		this.sortField = fieldMap[event.detail.fieldName] || 'CreatedDate';
		this.sortAscending = event.detail.sortDirection === 'asc';
		await this.loadData();
	}

	handleRowSelection(event)
	{
		const selectedRows = event.detail.selectedRows;
		if(selectedRows && selectedRows.length > 0)
		{
			this.selectExecution(selectedRows[0].executionId);
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
}