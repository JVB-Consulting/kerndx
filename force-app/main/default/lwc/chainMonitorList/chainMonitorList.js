// SPDX-License-Identifier: BUSL-1.1
/**
 * @description List panel showing filtered, sorted, and paginated async chain executions.
 * Supports status filtering and row selection to drive the detail panel.
 *
 * @author Jason van Beukering
 *
 * @date April 2026, October 2026
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
import actionPillTemplate from '@salesforce/label/c.ChainMonitor_ActionPill';
import launchedUnderLabel from '@salesforce/label/c.ChainMonitor_LaunchedUnder';
import launchedByThisAction from '@salesforce/label/c.ChainMonitor_LaunchedByThisAction';
import startedThisAction from '@salesforce/label/c.ChainMonitor_StartedThisAction';
import restartOfTemplate from '@salesforce/label/c.ChainMonitor_RestartOf';
import showActionLogsAction from '@salesforce/label/c.ChainMonitor_ShowActionLogsAction';
import loadingAlt from '@salesforce/label/c.ChainMonitor_LoadingAlt';
import filtersToggleAlt from '@salesforce/label/c.ChainMonitor_FiltersToggleAlt';

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

const CHAIN_COLUMN = {
	label: chainNameLabel, fieldName: 'recordUrl', type: 'url', sortable: true, typeAttributes: {label: {fieldName: 'chainName'}}
};
const STATUS_COLUMN = {
	label: statusLabel, fieldName: 'status', type: 'text', sortable: true, initialWidth: STATUS_COLUMN_WIDTH, hideDefaultActions: true
};
const PROGRESS_COLUMN = {
	label: columnProgress, fieldName: 'progressLabel', type: 'text', sortable: false, initialWidth: PROGRESS_COLUMN_WIDTH, hideDefaultActions: true
};
const STARTED_COLUMN = {
	label: startedLabel, fieldName: 'startedAt', type: 'date', sortable: true, typeAttributes: {year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit'}
};
const DURATION_COLUMN = {
	label: durationLabel, fieldName: 'durationDisplay', type: 'text', sortable: true, initialWidth: DURATION_COLUMN_WIDTH, hideDefaultActions: true
};
const COLUMNS = [
	CHAIN_COLUMN,
	STATUS_COLUMN,
	PROGRESS_COLUMN,
	STARTED_COLUMN,
	DURATION_COLUMN
];
// At 1280 and below the list has half the screen beside the detail panel, or a phone's width under it, and six columns
// crush: the run's name, how it stands and when it began stay, Progress and Duration live on in the detail's Timing card.
// The same query the Log Console's list follows. The string is a CSS media query the browser parses, never text on
// screen, so there is nothing here for a translator.
// eslint-disable-next-line kerndx/no-hardcoded-user-text
const COMPACT_WIDTH_QUERY = '(max-width: 1280px)';
const COMPACT_COLUMNS = [
	CHAIN_COLUMN,
	STATUS_COLUMN,
	STARTED_COLUMN
];

const PAGE_SIZE = 20;

// The row action of the Launched-under column's link: pressing a launcher selects that run.
const LAUNCHER_ACTION_NAME = 'selectLauncher';
// How a run entered its action, the controller's vocabulary.
const LAUNCH_KIND_CHAIN = 'CHAIN';
const LAUNCH_KIND_RESTART = 'RESTART';
const LAUNCH_KIND_ORIGIN = 'ORIGIN';
const LAUNCH_KIND_ACTION = 'ACTION';
// The Launched-under column, shown while the list is scoped to an action: a base-variant button column so the launching
// run is a link that selects it, disabled (and so reading as plain words) for the two cases that name no run.
const LAUNCHED_UNDER_COLUMN = {
	label: launchedUnderLabel, fieldName: 'launchedUnderText', type: 'button', sortable: false, hideDefaultActions: true, typeAttributes: {
		label: {fieldName: 'launchedUnderText'}, name: LAUNCHER_ACTION_NAME, variant: 'base', disabled: {fieldName: 'launchedUnderIsText'}, title: {fieldName: 'launchedUnderText'}
	}
};
// A pill shows the first eight and the last four characters of an id.
const ID_HEAD_LENGTH = 8;
const ID_TAIL_LENGTH = 4;
const ID_ELLIPSIS = '…';

/**
 * @description Shortens an id for the pill, keeping its head and its tail. An id too short to be
 * worth shortening is left whole. Only the pill calls this, and the pill renders only while an
 * action is pinned, so the id is always there to shorten.
 *
 * @param {string} id The id to shorten.
 *
 * @returns {string} The shortened id, or the id itself.
 */
function abbreviateId(id)
{
	return id.length > ID_HEAD_LENGTH + ID_TAIL_LENGTH ? `${id.slice(0, ID_HEAD_LENGTH)}${ID_ELLIPSIS}${id.slice(-ID_TAIL_LENGTH)}` : id;
}

/**
 * @description The words of the Launched-under cell by the kind the controller classified: the launching run's label,
 * "restart of {source}", "started this action", or "this action". A row carrying no kind the component knows reads as
 * empty words rather than a guess.
 *
 * @param {object} record The chain summary returned by the controller.
 *
 * @returns {string} The cell text.
 */
function resolveLaunchedUnderText(record)
{
	if(record.launchKind === LAUNCH_KIND_CHAIN)
	{
		return record.launchedUnderLabel ?? '';
	}
	if(record.launchKind === LAUNCH_KIND_RESTART)
	{
		return formatTemplateString(restartOfTemplate, [record.launchedUnderLabel ?? '']);
	}
	if(record.launchKind === LAUNCH_KIND_ORIGIN)
	{
		return startedThisAction;
	}
	return record.launchKind === LAUNCH_KIND_ACTION ? launchedByThisAction : '';
}

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

export default class ChainMonitorList extends ComponentBuilder('controller', 'notification', 'navigation')
{
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
	// The action the list is scoped to (its root correlation id), or null. Set by the container from
	// a deep link, cleared by the pill; a change reloads from page one once the list has loaded at all.
	scopedRoot = null;
	hasLoadedOnce = false;
	// Counts the list requests; an answer is taken only while its request is the newest (see loadData).
	loadSequence = 0;
	// Whether the viewport is at the compact width (1280 and below). Read from matchMedia when the browser has it; jsdom
	// does not, and the list then keeps the full column set.
	isCompactWidth = false;
	compactMediaQuery = null;

	label = {
		nameFilter: chainNameLabel,
		nameFilterPlaceholder,
		statusFilter: statusLabel,
		previous: previousLabel,
		next: nextLabel,
		emptyStateHeading: listEmptyHeading,
		showActionLogs: showActionLogsAction,
		loadingAlt,
		filtersToggleAlt,
		selectAll,
		clearAll
	};

	/**
	 * @description The action the list is kept to, as the container sees it.
	 *
	 * @returns {string|null} The action's root correlation id, or null while the list shows every run.
	 */
	@api get actionRootCorrelationId()
	{
		return this.scopedRoot;
	}

	/**
	 * @description Pins the list to one action, or releases it. A change re-reads from page one,
	 * but only once the list has loaded at all, so the first load is not run twice.
	 *
	 * @param {string|null} value The action's root correlation id, or null to show every run.
	 */
	set actionRootCorrelationId(value)
	{
		const next = value || null;
		if(next === this.scopedRoot)
		{
			return;
		}
		this.scopedRoot = next;
		if(this.hasLoadedOnce)
		{
			this.pageNumber = 1;
			// noinspection JSIgnoredPromiseFromCall
			this.reloadAndResetSelection();
		}
	}

	/**
	 * @description The table's columns. At 1280 and below the list keeps Chain, Status and Started;
	 * the Launched-under column joins either set only while the list is kept to one action, where
	 * saying what launched each run is the whole point of the reading.
	 *
	 * @returns {Array<object>} The column definitions.
	 */
	get columns()
	{
		const base = this.isCompactWidth ? COMPACT_COLUMNS : COLUMNS;
		return this.scopedRoot ? [
			...base,
			LAUNCHED_UNDER_COLUMN
		] : base;
	}

	/**
	 * @description Whether the list is kept to one action, which is what puts the pill on screen.
	 *
	 * @returns {boolean}
	 */
	get isScoped()
	{
		return !!this.scopedRoot;
	}

	/**
	 * @description The pill's words: the action, named by a shortened form of its id.
	 *
	 * @returns {string}
	 */
	get actionPillLabel()
	{
		return formatTemplateString(actionPillTemplate, [abbreviateId(this.scopedRoot)]);
	}

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

	get hasNoStatusSelection()
	{
		return !this.hasStatusSelection;
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

	/**
	 * @description Follows the viewport across the compact width, so the column set changes with it. A field rather than
	 * a method, so the listener removed on disconnect is the same function that was added.
	 *
	 * @param {Object} event The media query's own change event, carrying whether the query matches now.
	 */
	handleCompactWidthChange = (event) =>
	{
		this.isCompactWidth = event.matches;
	};

	async connectedCallback()
	{
		// The compact column set follows the viewport; a browser without matchMedia keeps the full set.
		this.compactMediaQuery = typeof window.matchMedia === 'function' ? window.matchMedia(COMPACT_WIDTH_QUERY) : null;
		if(this.compactMediaQuery)
		{
			this.isCompactWidth = this.compactMediaQuery.matches === true;
			this.compactMediaQuery.addEventListener('change', this.handleCompactWidthChange);
		}
		await this.loadData();
	}

	/**
	 * @description Runs the base component's teardown first, then stops following the viewport when the list leaves
	 * the page, so the listener added on connect does not outlive it.
	 */
	// noinspection JSUnusedGlobalSymbols - LWC framework lifecycle hook
	disconnectedCallback()
	{
		super.disconnectedCallback();
		this.compactMediaQuery?.removeEventListener('change', this.handleCompactWidthChange);
	}

	async loadData()
	{
		this.hasLoadedOnce = true;
		this.loadSequence++;
		const requestSequence = this.loadSequence;
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
			// A request still in flight is now outdated and will not clear the spinner itself.
			this.isLoading = false;
			return;
		}

		this.isLoading = true;

		const request = {
			statusFilters: this.isAllStatusesSelected ? [] : [...this.statusFilters],
			nameFilter: this.nameFilter || null,
			rootCorrelationId: this.scopedRoot,
			sortField: this.sortField,
			sortAscending: this.sortAscending,
			pageSize: PAGE_SIZE,
			pageNumber: this.pageNumber
		};

		const data = await this.callControllerMethod(getChainExecutions, {requestJson: JSON.stringify(request)});

		// Only the newest request wins. The container refreshes the list on every log event, so a refresh sent
		// with an older filter, sort or page can answer last; written as it lands, it would show rows the
		// current filter excludes and move the selection to one of them. The newer request clears the spinner.
		if(requestSequence !== this.loadSequence)
		{
			return;
		}
		if(data?.records)
		{
			this.records = data.records.map((record) =>
			{
				const percent = record.totalSteps > 0 ? Math.round((record.completedSteps / record.totalSteps) * 100) : 0;
				return {
					...record,
					progressLabel: `${record.completedSteps}/${record.totalSteps} (${percent}%)`,
					durationDisplay: resolveDurationDisplay(record),
					launchedUnderText: this.scopedRoot ? resolveLaunchedUnderText(record) : null,
					launchedUnderIsText: !record.launchedUnderExecutionId,
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

	async handleSelectAllStatuses()
	{
		this.statusFilters = [...ALL_STATUS_VALUES];
		this.pageNumber = 1;
		await this.reloadAndResetSelection();
	}

	async handleClearAllStatuses()
	{
		this.statusFilters = [];
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

	/**
	 * @description The Launched-under column's link: pressing a launcher selects that run, in the
	 * list when it is on the page and in the detail pane either way. The words for the other cases
	 * carry no run and do nothing.
	 *
	 * @param {CustomEvent} event The datatable's row action.
	 */
	handleRowAction(event)
	{
		const row = event.detail.row;
		if(event.detail.action?.name === LAUNCHER_ACTION_NAME && row?.launchedUnderExecutionId)
		{
			this.selectExecution(row.launchedUnderExecutionId, true);
		}
	}

	/**
	 * @description Drops the action pill: the list reloads unscoped from page one and tells the
	 * container, so a later deep link with a new stamp can pin an action again.
	 */
	async handleRemoveAction()
	{
		this.scopedRoot = null;
		this.pageNumber = 1;
		this.dispatchEvent(new CustomEvent('actionclear'));
		await this.reloadAndResetSelection();
	}

	/**
	 * @description Opens the Log Console on the pinned action: the action and a click stamp, no
	 * window keys (the console sets its range from the action's lifetime).
	 */
	handleShowActionLogs()
	{
		this.navigate({type: 'standard__navItemPage', attributes: {apiName: 'LogConsole'}, state: {c__rootCorrelationId: this.scopedRoot, c__viewLogsAt: String(Date.now())}});
	}
}