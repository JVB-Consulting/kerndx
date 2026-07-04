// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Log Console container. Owns the filter state, the two list views
 * (distinct problems and flat entries), the scope summary, endless scrolling and row
 * selection, and renders the tabbed detail drawer. Reads from `CTRL_LogConsole` and
 * hands the loaded entry to `c-log-console-detail`.
 *
 * @author Jason van Beukering
 *
 * @date July 2026
 */
import {wire} from 'lwc';
import {CurrentPageReference} from 'lightning/navigation';
import {ComponentBuilder} from 'c/componentBuilder';
import {CONTEXT_CHOICES, CONTEXT_LABEL_BY_VALUE} from 'c/logConsoleContext';
import getLogProblems from '@salesforce/apex/CTRL_LogConsole.getLogProblems';
import getLogEntries from '@salesforce/apex/CTRL_LogConsole.getLogEntries';
import getLogSummary from '@salesforce/apex/CTRL_LogConsole.getLogSummary';
import getEntrySummary from '@salesforce/apex/CTRL_LogConsole.getEntrySummary';
import getLogEntryDetail from '@salesforce/apex/CTRL_LogConsole.getLogEntryDetail';
import getCorrelatedTrace from '@salesforce/apex/CTRL_LogConsole.getCorrelatedTrace';

import title from '@salesforce/label/c.LogConsole_Title';
import viewProblems from '@salesforce/label/c.LogConsole_ViewProblems';
import viewEntries from '@salesforce/label/c.LogConsole_ViewEntries';
import refresh from '@salesforce/label/c.LogConsole_Refresh';
import clearAll from '@salesforce/label/c.LogConsole_ClearAll';
import searchPlaceholder from '@salesforce/label/c.LogConsole_SearchPlaceholder';
import allContexts from '@salesforce/label/c.LogConsole_AllContexts';
import contextFilterLabel from '@salesforce/label/c.LogConsole_ContextFilter';
import levelGroupLabel from '@salesforce/label/c.LogConsole_LevelGroupLabel';
import totalOccurrences from '@salesforce/label/c.LogConsole_TotalOccurrences';
import totalsApproximate from '@salesforce/label/c.LogConsole_TotalsApproximate';
import totalsApproximateHelp from '@salesforce/label/c.LogConsole_TotalsApproximateHelp';
import distinctShown from '@salesforce/label/c.LogConsole_DistinctShown';
import occurrencesSuffix from '@salesforce/label/c.LogConsole_OccurrencesSuffix';
import distinctSuffix from '@salesforce/label/c.LogConsole_DistinctSuffix';
import topSourcesLabel from '@salesforce/label/c.LogConsole_TopSources';
import entriesInWindow from '@salesforce/label/c.LogConsole_EntriesInWindow';
import logRows from '@salesforce/label/c.LogConsole_LogRows';
import rowsSuffix from '@salesforce/label/c.LogConsole_RowsSuffix';
import emptyState from '@salesforce/label/c.LogConsole_EmptyState';
import cappedBanner from '@salesforce/label/c.LogConsole_CappedBanner';
import loadingAlt from '@salesforce/label/c.LogConsole_LoadingAlt';
import colLogNumber from '@salesforce/label/c.LogConsole_ColLogNumber';
import colLevel from '@salesforce/label/c.LogConsole_ColLevel';
import colProblem from '@salesforce/label/c.LogConsole_ColProblem';
import colMessage from '@salesforce/label/c.LogConsole_ColMessage';
import colSource from '@salesforce/label/c.LogConsole_ColSource';
import colContext from '@salesforce/label/c.LogConsole_ColContext';
import colCount from '@salesforce/label/c.LogConsole_ColCount';
import colLastSeen from '@salesforce/label/c.LogConsole_ColLastSeen';
import colTime from '@salesforce/label/c.LogConsole_ColTime';
import colCorrelation from '@salesforce/label/c.LogConsole_ColCorrelation';
import dateRange from '@salesforce/label/c.LogConsole_DateRange';
import range15m from '@salesforce/label/c.LogConsole_Range15m';
import range1h from '@salesforce/label/c.LogConsole_Range1h';
import range4h from '@salesforce/label/c.LogConsole_Range4h';
import range24h from '@salesforce/label/c.LogConsole_Range24h';
import range7d from '@salesforce/label/c.LogConsole_Range7d';
import range30d from '@salesforce/label/c.LogConsole_Range30d';
import rangeToday from '@salesforce/label/c.LogConsole_RangeToday';
import rangeYesterday from '@salesforce/label/c.LogConsole_RangeYesterday';
import rangeThisWeek from '@salesforce/label/c.LogConsole_RangeThisWeek';
import rangeLastWeek from '@salesforce/label/c.LogConsole_RangeLastWeek';
import rangeThisMonth from '@salesforce/label/c.LogConsole_RangeThisMonth';
import rangeCustom from '@salesforce/label/c.LogConsole_RangeCustom';
import fromDate from '@salesforce/label/c.LogConsole_FromDate';
import fromTime from '@salesforce/label/c.LogConsole_FromTime';
import toDate from '@salesforce/label/c.LogConsole_ToDate';
import toTime from '@salesforce/label/c.LogConsole_ToTime';

const ALL_LEVELS = [
	'ERROR',
	'WARN',
	'INFO',
	'DEBUG'
];
const DEFAULT_LEVELS = [
	'ERROR',
	'WARN'
];
const DEFAULT_WINDOW_MINUTES = 1440;
const DEFAULT_PAGE_SIZE = 50;
// Fast typing settles before the server is queried; each keystroke does not fire its own query.
const SEARCH_DEBOUNCE_MS = 300;
const PROBLEM_SORT_FIELD = 'occurrenceCount';
const ENTRY_SORT_FIELD = 'createdDate';

// Maps a datatable column fieldName to the controller sort wire key when they differ
// (derived or url columns). Columns whose fieldName is already a valid sort key pass through.
const SORT_KEY_BY_COLUMN = {recordUrl: 'logNumber', source: 'className', contextDisplay: 'executionEvent'};

// Date-range presets that resolve to a rolling window measured back from now, keyed by the combobox value.
const WINDOW_MINUTES_BY_PRESET = {
	'15': 15, '60': 60, '240': 240, '1440': 1440, '10080': 10080, '43200': 43200
};
const DEFAULT_RANGE_PRESET = '1440';
// The widest rolling preset — a correlation deep link lands here so an older chain is still visible.
const WIDEST_RANGE_PRESET = '43200';
const CUSTOM_RANGE_PRESET = 'custom';

const pad = (value) => String(value).padStart(2, '0');

export default class LogConsole extends ComponentBuilder('controller', 'notification', 'navigation')
{
	view = 'problems';
	levels = [...DEFAULT_LEVELS];
	executionEvent = '';
	searchTerm = '';
	windowMinutes = DEFAULT_WINDOW_MINUTES;
	rangePreset = DEFAULT_RANGE_PRESET;
	customStart = null;
	customEnd = null;
	customFromDate = '';
	customFromTime = '';
	customToDate = '';
	customToTime = '';
	sortField = PROBLEM_SORT_FIELD;
	sortedByColumn = PROBLEM_SORT_FIELD;
	sortAscending = false;
	pageNumber = 1;
	pageSize = DEFAULT_PAGE_SIZE;
	correlationId = null;
	searchDebounceTimer = null;
	// Monotonic request token: only the newest reload may apply its results, so a slow earlier
	// query (e.g. a shorter search prefix) cannot overwrite the results of a later one.
	requestSequence = 0;

	records = [];
	summary = null;
	totalCount = 0;
	totalPages = 0;
	hasMorePages = false;
	isLoadingMore = false;
	resultsTruncated = false;

	selectedId = null;
	selectedDetail = null;
	selectedTrace = [];
	selectedTraceTruncated = false;
	selectedFocusedDetail = null;
	focusedDetailCache = new Map();
	pendingFocusId = null;

	label = {
		title,
		viewProblems,
		viewEntries,
		refresh,
		clearAll,
		searchPlaceholder,
		allContexts,
		contextFilterLabel,
		levelGroupLabel,
		dateRange,
		fromDate,
		fromTime,
		toDate,
		toTime,
		totalOccurrences,
		totalsApproximate,
		totalsApproximateHelp,
		distinctShown,
		occurrencesSuffix,
		distinctSuffix,
		topSourcesLabel,
		entriesInWindow,
		logRows,
		rowsSuffix,
		emptyState,
		loadingAlt
	};

	get isProblemsView()
	{
		return this.view === 'problems';
	}

	get problemsVariant()
	{
		return this.isProblemsView ? 'brand' : 'neutral';
	}

	get entriesVariant()
	{
		return this.isProblemsView ? 'neutral' : 'brand';
	}

	get columns()
	{
		return this.isProblemsView ? this.problemColumns : this.entryColumns;
	}

	get problemColumns()
	{
		return [
			{label: colLogNumber, fieldName: 'recordUrl', type: 'url', sortable: true, typeAttributes: {label: {fieldName: 'logNumber'}, target: '_blank'}},
			{label: colLevel, fieldName: 'level', type: 'logLevel', sortable: true, typeAttributes: {level: {fieldName: 'level'}}},
			{label: colProblem, fieldName: 'shortMessage', type: 'text', sortable: true, wrapText: true},
			{label: colSource, fieldName: 'source', type: 'text', sortable: true},
			{label: colContext, fieldName: 'contextDisplay', type: 'text', sortable: true},
			{label: colCount, fieldName: 'occurrenceCount', type: 'number', sortable: true, cellAttributes: {alignment: 'left'}},
			{
				label: colLastSeen,
				fieldName: 'lastSeen',
				type: 'date',
				sortable: true,
				typeAttributes: {year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit'}
			}
		];
	}

	get entryColumns()
	{
		return [
			{label: colLogNumber, fieldName: 'recordUrl', type: 'url', sortable: true, typeAttributes: {label: {fieldName: 'logNumber'}, target: '_blank'}},
			{
				label: colTime,
				fieldName: 'createdDate',
				type: 'date',
				sortable: true,
				typeAttributes: {year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit'}
			},
			{label: colLevel, fieldName: 'level', type: 'logLevel', sortable: true, typeAttributes: {level: {fieldName: 'level'}}},
			{label: colMessage, fieldName: 'shortMessage', type: 'text', sortable: true, wrapText: true},
			{label: colSource, fieldName: 'source', type: 'text', sortable: true},
			{label: colContext, fieldName: 'contextDisplay', type: 'text', sortable: true},
			{label: colCorrelation, fieldName: 'correlationId', type: 'text', sortable: true}
		];
	}

	get contextOptions()
	{
		return [{label: this.label.allContexts, value: ''}].concat(CONTEXT_CHOICES);
	}

	// The single date-range picklist: quick rolling windows, then calendar presets computed in the viewer's
	// time zone, then longer rolling windows, then a custom From/To range. Quick/rolling values are minute
	// counts; calendar/custom values resolve to an absolute ISO instant pair (customStart/customEnd).
	get dateRangeOptions()
	{
		return [
			{label: range15m, value: '15'},
			{label: range1h, value: '60'},
			{label: range4h, value: '240'},
			{label: range24h, value: '1440'},
			{label: rangeToday, value: 'today'},
			{label: rangeYesterday, value: 'yesterday'},
			{label: rangeThisWeek, value: 'thisweek'},
			{label: rangeLastWeek, value: 'lastweek'},
			{label: rangeThisMonth, value: 'thismonth'},
			{label: range7d, value: '10080'},
			{label: range30d, value: '43200'},
			{label: rangeCustom, value: CUSTOM_RANGE_PRESET}
		];
	}

	get isCustomRange()
	{
		return this.rangePreset === CUSTOM_RANGE_PRESET;
	}

	get levelToggles()
	{
		return ALL_LEVELS.map((level) => ({level, pressed: String(this.levels.includes(level))}));
	}

	get isEmpty()
	{
		return this.records.length === 0;
	}

	get summaryCards()
	{
		if(!this.summary)
		{
			return [];
		}
		return this.isProblemsView ? this.problemSummaryCards : this.entrySummaryCards;
	}

	// The problems ribbon folds occurrences per problem: a read-only total, one clickable card per active
	// level (occurrences + distinct count), and the ranked top-source list (share of occurrences). When the
	// server folded a capped rollup window the total card carries a "totals approximate" badge, so a
	// best-effort count is never presented as exact.
	get problemSummaryCards()
	{
		const cards = [
			{
				key: 'total',
				isTotal: true,
				label: this.label.totalOccurrences,
				value: this.summary.totalOccurrences ?? 0,
				footnote: `${this.summary.distinctCount ?? 0} ${this.label.distinctShown}`,
				isApproximate: this.summary.totalsApproximate === true,
				cardClass: 'summary-card summary-card_total'
			}
		];
		(this.summary.perLevel ?? [])
		.filter((entry) => this.levels.includes(entry.level))
		.forEach((entry) => cards.push(
				this.levelCard(entry.level, entry.occurrences ?? 0, `${entry.distinctCount ?? 0} ${this.label.distinctSuffix}`, this.label.occurrencesSuffix)));
		cards.push(this.topSourcesCard(true));
		return cards;
	}

	// The entries ribbon counts forensic rows: a read-only total, one clickable card per active level (row
	// count), and the ranked top-source list (row count).
	get entrySummaryCards()
	{
		const cards = [
			{
				key: 'total',
				isTotal: true,
				label: this.label.entriesInWindow,
				value: this.summary.totalRows ?? 0,
				footnote: this.label.logRows,
				cardClass: 'summary-card summary-card_total'
			}
		];
		(this.summary.perLevel ?? [])
		.filter((entry) => this.levels.includes(entry.level))
		.forEach((entry) => cards.push(this.levelCard(entry.level, entry.rowCount ?? 0, this.label.rowsSuffix, null)));
		cards.push(this.topSourcesCard(false));
		return cards;
	}

	get resultsTruncatedText()
	{
		return cappedBanner.replace('{0}', this.totalCount);
	}

	get sortedBy()
	{
		return this.sortedByColumn;
	}

	get sortDirection()
	{
		return this.sortAscending ? 'asc' : 'desc';
	}

	get selectedRows()
	{
		return this.selectedId ? [this.selectedId] : [];
	}

	get hasSelection()
	{
		return this.selectedDetail != null;
	}

	get selectedOccurrenceCount()
	{
		const problem = this.records.find((record) => record.id === this.selectedId);
		return problem ? problem.occurrenceCount : null;
	}

	// A clickable per-level card. Clicking it filters the list to that single level, so the total always

	/**
	 * @description The removable pill text for a pinned correlation filter, so a deep-linked
	 * correlation is visible and clearable rather than an invisible filter.
	 * @returns {string}
	 */
	get correlationPillLabel()
	{
		return `${colCorrelation}: ${this.correlationId}`;
	}

	// The ranked top-source card: up to three sources, each a click-to-drill row. Problems show each source's

	// equals the sum of the level cards. `labelSuffix` is appended to the humanised level name when present.
	levelCard(level, value, footnote, labelSuffix)
	{
		const levelName = `${level.charAt(0)}${level.slice(1).toLowerCase()}`;
		return {
			key: level,
			isLevel: true,
			level,
			label: labelSuffix ? `${levelName} ${labelSuffix}` : levelName,
			value,
			footnote,
			cardClass: `summary-card summary-card_clickable summary-card_${level.toLowerCase()}`
		};
	}

	// share of occurrences; entries show its row count.
	topSourcesCard(isProblems)
	{
		const sources = (this.summary.topSources ?? []).map((source, index) => ({
			key: source.name, name: source.name, rank: index + 1, metric: isProblems ? `${source.percent}%` : `${source.count} ${this.label.rowsSuffix}`
		}));
		return {key: 'sources', isSources: true, label: this.label.topSourcesLabel, sources, hasSources: sources.length > 0};
	}

	@wire(CurrentPageReference) captureDeepLink(pageReference)
	{
		const deepLinkCorrelation = pageReference?.state?.c__correlationId;
		// A correlation deep link (e.g. from Chain Monitor) pre-seeds the filter, and re-filters
		// live if it arrives while the console is already open. The chain's raw rows live in the
		// entries view and may predate the default window, so the link lands on Individual entries
		// with the widest rolling range; the pinned correlation renders as a removable pill so the
		// active filter is visible instead of an inexplicably empty console.
		if(deepLinkCorrelation && deepLinkCorrelation !== this.correlationId)
		{
			this.correlationId = deepLinkCorrelation;
			this.view = 'entries';
			this.sortField = ENTRY_SORT_FIELD;
			this.sortedByColumn = ENTRY_SORT_FIELD;
			this.sortAscending = false;
			this.levels = [...ALL_LEVELS];
			this.rangePreset = WIDEST_RANGE_PRESET;
			this.windowMinutes = WINDOW_MINUTES_BY_PRESET[WIDEST_RANGE_PRESET];
			this.customStart = null;
			this.customEnd = null;
			// noinspection JSIgnoredPromiseFromCall
			this.resetAndReload();
		}
	}

	handleRemoveCorrelation()
	{
		this.correlationId = null;
		// noinspection JSIgnoredPromiseFromCall
		this.resetAndReload();
	}

	// noinspection JSUnusedGlobalSymbols - LWC framework lifecycle hook
	connectedCallback()
	{
		// noinspection JSIgnoredPromiseFromCall
		this.reload();
	}

	// noinspection JSUnusedGlobalSymbols - LWC framework lifecycle hook
	disconnectedCallback()
	{
		window.clearTimeout(this.searchDebounceTimer);
	}

	buildRequest()
	{
		return {
			levels: this.levels,
			executionEvents: this.executionEvent ? [this.executionEvent] : [],
			searchTerm: this.searchTerm || null,
			windowMinutes: this.windowMinutes,
			customStart: this.customStart,
			customEnd: this.customEnd,
			correlationId: this.correlationId,
			sortField: this.sortField,
			sortAscending: this.sortAscending,
			pageSize: this.pageSize,
			pageNumber: this.pageNumber
		};
	}

	async reload()
	{
		this.isLoading = true;
		const sequence = ++this.requestSequence;
		const request = this.buildRequest();
		await Promise.all([
			this.loadList(request, false, sequence),
			this.loadSummary(request, sequence)
		]);
		if(sequence === this.requestSequence)
		{
			this.isLoading = false;
		}
	}

	async loadList(request, append = false, sequence = null)
	{
		const apexMethod = this.isProblemsView ? getLogProblems : getLogEntries;
		const data = await this.callControllerMethod(apexMethod, {requestJson: JSON.stringify(request)});
		if(sequence != null && sequence !== this.requestSequence)
		{
			return;
		}
		if(data?.records)
		{
			const decorated = data.records.map((record) => this.decorateRow(record));
			this.records = append ? [
				...this.records,
				...decorated
			] : decorated;
			this.totalCount = data.totalCount;
			this.totalPages = data.totalPages;
			this.hasMorePages = data.hasMorePages;
			this.pageNumber = data.pageNumber;
			this.resultsTruncated = data.resultsTruncated === true;
			this.reconcileSelection();
		}
		else if(!append)
		{
			this.records = [];
			this.resultsTruncated = false;
			this.clearSelection();
		}
	}

	decorateRow(record)
	{
		const source = record.methodLine ? `${record.className}.${record.methodLine}` : record.className;
		return {
			...record, source, contextDisplay: CONTEXT_LABEL_BY_VALUE[record.executionEvent] ?? record.executionEvent, recordUrl: `/lightning/r/${record.id}/view`
		};
	}

	async loadSummary(request, sequence = null)
	{
		// The problems view folds occurrences per problem (getLogSummary); the entries view counts forensic
		// rows (getEntrySummary). Each ribbon reads its own aggregate so the total always equals the sum of
		// its per-level cards.
		const summaryMethod = this.isProblemsView ? getLogSummary : getEntrySummary;
		const data = await this.callControllerMethod(summaryMethod, {requestJson: JSON.stringify(request)});
		if(sequence != null && sequence !== this.requestSequence)
		{
			return;
		}
		this.summary = data || null;
	}

	reconcileSelection()
	{
		if(this.selectedId && !this.records.some((record) => record.id === this.selectedId))
		{
			this.clearSelection();
		}
	}

	clearSelection()
	{
		this.selectedId = null;
		this.selectedDetail = null;
		this.selectedTrace = [];
		this.selectedTraceTruncated = false;
		this.selectedFocusedDetail = null;
		this.pendingFocusId = null;
		this.focusedDetailCache = new Map();
	}

	async selectEntry(entryId)
	{
		this.selectedId = entryId;
		this.selectedFocusedDetail = null;
		this.pendingFocusId = null;
		this.focusedDetailCache = new Map();
		const [detail, trace] = await Promise.all([
			this.callControllerMethod(getLogEntryDetail, {entryId}),
			this.callControllerMethod(getCorrelatedTrace, {entryId})
		]);
		this.selectedDetail = detail || null;
		this.selectedTrace = trace ? trace.entries || [] : [];
		this.selectedTraceTruncated = trace ? trace.truncated === true : false;
	}

	/**
	 * @description Loads a focused hop's full detail on demand for the timeline focus card, serving repeats
	 * from a per-selection cache and guarding against an out-of-order response overwriting a newer focus. The
	 * console's main list is never touched; only the drawer's focus card changes.
	 * @param {CustomEvent} event The `entryfocus` event carrying the focused entry id.
	 */
	async handleEntryFocus(event)
	{
		const entryId = event.detail.entryId;
		this.pendingFocusId = entryId;
		if(!entryId || entryId === this.selectedId)
		{
			this.selectedFocusedDetail = this.selectedDetail;
			return;
		}
		if(this.focusedDetailCache.has(entryId))
		{
			this.selectedFocusedDetail = this.focusedDetailCache.get(entryId);
			return;
		}
		const detail = await this.callControllerMethod(getLogEntryDetail, {entryId});
		if(detail)
		{
			this.focusedDetailCache.set(entryId, detail);
		}
		if(this.pendingFocusId === entryId)
		{
			// On a failed load, surface a sentinel so the focus card shows an error instead of a stuck spinner;
			// do not cache the sentinel, so a later focus retries the load.
			this.selectedFocusedDetail = detail || {loadFailed: true};
		}
	}

	async resetAndReload()
	{
		this.pageNumber = 1;
		await this.reload();
	}

	handleViewChange(event)
	{
		const nextView = event.target.dataset.view;
		if(nextView !== this.view)
		{
			this.view = nextView;
			this.sortField = this.isProblemsView ? PROBLEM_SORT_FIELD : ENTRY_SORT_FIELD;
			this.sortedByColumn = this.sortField;
			this.sortAscending = false;
			// noinspection JSIgnoredPromiseFromCall
			this.resetAndReload();
		}
	}

	handleLevelToggle(event)
	{
		const level = event.currentTarget.dataset.level;
		this.levels = this.levels.includes(level) ? this.levels.filter((value) => value !== level) : [
			...this.levels,
			level
		];
		// noinspection JSIgnoredPromiseFromCall
		this.resetAndReload();
	}

	handleContextChange(event)
	{
		this.executionEvent = event.detail.value;
		// noinspection JSIgnoredPromiseFromCall
		this.resetAndReload();
	}

	handleSearch(event)
	{
		this.searchTerm = event.target.value;
		window.clearTimeout(this.searchDebounceTimer);
		this.searchDebounceTimer = window.setTimeout(() =>
		{
			// noinspection JSIgnoredPromiseFromCall
			this.resetAndReload();
		}, SEARCH_DEBOUNCE_MS);
	}

	handleDateRangeChange(event)
	{
		const preset = event.detail.value;
		this.rangePreset = preset;
		if(preset === CUSTOM_RANGE_PRESET)
		{
			this.seedCustomRangeDefaults();
			this.applyCustomRange();
			return;
		}
		if(WINDOW_MINUTES_BY_PRESET[preset])
		{
			this.windowMinutes = WINDOW_MINUTES_BY_PRESET[preset];
			this.customStart = null;
			this.customEnd = null;
		}
		else
		{
			const range = this.calendarRange(preset);
			this.customStart = range.start;
			this.customEnd = range.end;
		}
		// noinspection JSIgnoredPromiseFromCall
		this.resetAndReload();
	}

	handleCustomRangeChange(event)
	{
		const field = event.target.dataset.field;
		const value = event.detail.value;
		if(field === 'fromDate')
		{
			this.customFromDate = value;
		}
		else if(field === 'fromTime')
		{
			this.customFromTime = value;
		}
		else if(field === 'toDate')
		{
			this.customToDate = value;
		}
		else if(field === 'toTime')
		{
			this.customToTime = value;
		}
		this.applyCustomRange();
	}

	// Combines the four custom inputs into an absolute ISO instant pair once all are present and the range is
	// forward-ordered, then reloads. An inverted (from after to) range is ignored rather than run as an
	// impossible window that would silently return nothing.
	applyCustomRange()
	{
		if(this.customFromDate && this.customFromTime && this.customToDate && this.customToTime)
		{
			const start = this.combineLocal(this.customFromDate, this.customFromTime);
			const end = this.combineLocal(this.customToDate, this.customToTime);
			if(new Date(start).getTime() <= new Date(end).getTime())
			{
				this.customStart = start;
				this.customEnd = end;
				// noinspection JSIgnoredPromiseFromCall
				this.resetAndReload();
			}
		}
	}

	// Seeds the custom inputs to the last 24 hours so switching to a custom range starts from a full window.
	seedCustomRangeDefaults()
	{
		const now = new Date();
		const from = new Date(now.getTime() - DEFAULT_WINDOW_MINUTES * 60000);
		this.customFromDate = this.toDateInput(from);
		this.customFromTime = this.toTimeInput(from);
		this.customToDate = this.toDateInput(now);
		this.customToTime = this.toTimeInput(now);
	}

	// Resolves a calendar preset to an absolute instant pair in the viewer's local time zone.
	calendarRange(preset)
	{
		const now = new Date();
		const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
		if(preset === 'yesterday')
		{
			const startOfYesterday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1);
			return {start: startOfYesterday.toISOString(), end: new Date(startOfToday.getTime() - 1).toISOString()};
		}
		if(preset === 'thisweek')
		{
			return {start: this.startOfWeek(now).toISOString(), end: now.toISOString()};
		}
		if(preset === 'lastweek')
		{
			const startOfThisWeek = this.startOfWeek(now);
			const startOfLastWeek = new Date(startOfThisWeek.getFullYear(), startOfThisWeek.getMonth(), startOfThisWeek.getDate() - 7);
			return {start: startOfLastWeek.toISOString(), end: new Date(startOfThisWeek.getTime() - 1).toISOString()};
		}
		if(preset === 'thismonth')
		{
			return {start: new Date(now.getFullYear(), now.getMonth(), 1).toISOString(), end: now.toISOString()};
		}
		// 'today', and any unrecognised calendar preset, spans the start of today to now.
		return {start: startOfToday.toISOString(), end: now.toISOString()};
	}

	// The Monday that opens the calendar week containing the given date, at local midnight.
	startOfWeek(date)
	{
		const start = new Date(date.getFullYear(), date.getMonth(), date.getDate());
		const mondayIndex = (start.getDay() + 6) % 7;
		start.setDate(start.getDate() - mondayIndex);
		return start;
	}

	// Combines a YYYY-MM-DD date value and an HH:mm:ss time value into an absolute ISO instant (viewer TZ).
	combineLocal(dateValue, timeValue)
	{
		const [year, month, day] = dateValue.split('-').map(Number);
		const [hour, minute, second] = timeValue.split(':').map(Number);
		return new Date(year, month - 1, day, hour || 0, minute || 0, Math.trunc(second) || 0).toISOString();
	}

	toDateInput(date)
	{
		return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
	}

	toTimeInput(date)
	{
		return `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
	}

	handleClearAll()
	{
		window.clearTimeout(this.searchDebounceTimer);
		this.levels = [...DEFAULT_LEVELS];
		this.executionEvent = '';
		this.searchTerm = '';
		this.correlationId = null;
		this.rangePreset = DEFAULT_RANGE_PRESET;
		this.windowMinutes = DEFAULT_WINDOW_MINUTES;
		this.customStart = null;
		this.customEnd = null;
		this.customFromDate = '';
		this.customFromTime = '';
		this.customToDate = '';
		this.customToTime = '';
		// noinspection JSIgnoredPromiseFromCall
		this.resetAndReload();
	}

	handleSort(event)
	{
		this.sortedByColumn = event.detail.fieldName;
		this.sortField = SORT_KEY_BY_COLUMN[event.detail.fieldName] ?? event.detail.fieldName;
		this.sortAscending = event.detail.sortDirection === 'asc';
		// noinspection JSIgnoredPromiseFromCall
		this.resetAndReload();
	}

	// Endless scroll: the datatable fires loadmore near the bottom. Fetch the next page and append it, leaving
	// the window-scoped ribbon untouched. A filter, sort or view change resets to page one and replaces the rows.
	async handleLoadMore()
	{
		if(!this.hasMorePages || this.isLoadingMore)
		{
			return;
		}
		this.isLoadingMore = true;
		this.pageNumber += 1;
		await this.loadList(this.buildRequest(), true, this.requestSequence);
		this.isLoadingMore = false;
	}

	handleRefresh()
	{
		// noinspection JSIgnoredPromiseFromCall
		this.reload();
	}

	handleRowSelection(event)
	{
		const selected = event.detail.selectedRows;
		if(selected && selected.length > 0)
		{
			// noinspection JSIgnoredPromiseFromCall
			this.selectEntry(selected[0].id);
		}
	}

	handleDetailClose()
	{
		this.clearSelection();
	}

	handleLevelCardFilter(event)
	{
		// Clicking a per-level ribbon card narrows the list to that single level.
		this.levels = [event.currentTarget.dataset.level];
		// noinspection JSIgnoredPromiseFromCall
		this.resetAndReload();
	}

	handleSourceDrill(event)
	{
		// Clicking a ranked top-source drills the list to that source via the search term.
		this.searchTerm = event.currentTarget.dataset.source;
		// noinspection JSIgnoredPromiseFromCall
		this.resetAndReload();
	}

	handleOpenRecord(event)
	{
		this.navigate({type: 'standard__recordPage', attributes: {recordId: event.detail.entryId, actionName: 'view'}});
	}

	handleNavigateChain(event)
	{
		this.navigate({type: 'standard__navItemPage', attributes: {apiName: 'ChainMonitor'}, state: {c__correlationId: event.detail.correlationId}});
	}
}
