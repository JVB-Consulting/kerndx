// SPDX-License-Identifier: BUSL-1.1
/**
 * @description List panel showing filtered, sorted, and paginated async chain executions.
 * Supports status filtering and row selection to drive the detail panel.
 *
 * @author Jason van Beukering
 *
 * @date April 2026, May 2026, July 2026
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

const STATUS_OPTIONS = [
	{label: statusRunning, value: 'Running'},
	{label: statusCompleted, value: 'Completed'},
	{label: statusFailed, value: 'Failed'},
	{label: statusAborted, value: 'Aborted'},
	{label: statusStalled, value: 'Stalled'}
];

const ALL_STATUS_VALUES = STATUS_OPTIONS.map((option) => option.value);

const COLUMNS = [
	{
		label: chainNameLabel, fieldName: 'recordUrl', type: 'url', sortable: true, typeAttributes: {label: {fieldName: 'chainName'}}
	},
	{label: statusLabel, fieldName: 'status', type: 'text', sortable: true},
	{label: columnProgress, fieldName: 'progressLabel', type: 'text', sortable: false},
	{
		label: startedLabel,
		fieldName: 'startedAt',
		type: 'date',
		sortable: true,
		typeAttributes: {year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit'}
	},
	{label: durationLabel, fieldName: 'durationLabel', type: 'text', sortable: true}
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

	label = {
		nameFilter: chainNameLabel, nameFilterPlaceholder, statusFilter: statusLabel, previous: previousLabel, next: nextLabel
	};

	get isAllStatusesSelected()
	{
		return this.statusFilters.length === STATUS_OPTIONS.length;
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