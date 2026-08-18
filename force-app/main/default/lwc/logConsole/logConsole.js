// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Log Console container. Owns the filter state, the two list views
 * (distinct problems and flat entries), the scope summary, endless scrolling and row
 * selection, and renders the tabbed detail drawer. Reads from `CTRL_LogConsole` and
 * hands the loaded entry to `c-log-console-detail`.
 *
 * @author Jason van Beukering
 *
 * @date July 2026, August 2026
 */
import {wire} from 'lwc';
import {CurrentPageReference} from 'lightning/navigation';
import LANGUAGE from '@salesforce/i18n/lang';
import {ComponentBuilder} from 'c/componentBuilder';
import {CONTEXT_CHOICES, CONTEXT_LABEL_BY_VALUE} from 'c/logConsoleContext';
import getLogProblems from '@salesforce/apex/CTRL_LogConsole.getLogProblems';
import getLogEntries from '@salesforce/apex/CTRL_LogConsole.getLogEntries';
import getLogSummary from '@salesforce/apex/CTRL_LogConsole.getLogSummary';
import getEntrySummary from '@salesforce/apex/CTRL_LogConsole.getEntrySummary';
import getLogEntryDetail from '@salesforce/apex/CTRL_LogConsole.getLogEntryDetail';
import getDerivedProblemDetail from '@salesforce/apex/CTRL_LogConsole.getDerivedProblemDetail';
import getApexNamespacePrefix from '@salesforce/apex/CTRL_LogConsole.getApexNamespacePrefix';
import getLogSettingsSetupUrl from '@salesforce/apex/CTRL_LogConsole.getLogSettingsSetupUrl';
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
import viewGroupLabel from '@salesforce/label/c.LogConsole_ViewGroupLabel';
import levelsGroupLabel from '@salesforce/label/c.LogConsole_LevelsGroupLabel';
import contextGroupLabel from '@salesforce/label/c.LogConsole_ContextGroupLabel';
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
import entrySummaryTooLarge from '@salesforce/label/c.LogConsole_EntrySummaryTooLarge';
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
import groupingScopeCaption from '@salesforce/label/c.LogConsole_GroupingScopeCaption';
import groupingDisabled from '@salesforce/label/c.LogConsole_GroupingDisabled';
import groupingSkippedSearch from '@salesforce/label/c.LogConsole_GroupingSkippedSearch';
import groupingSkippedLevelScope from '@salesforce/label/c.LogConsole_GroupingSkippedLevelScope';
import groupingSkippedTooLarge from '@salesforce/label/c.LogConsole_GroupingSkippedTooLarge';
import actionOpenLogSettings from '@salesforce/label/c.LogConsole_ActionOpenLogSettings';
import actionSearchAllEntries from '@salesforce/label/c.LogConsole_ActionSearchAllEntries';
import actionNarrowDateRange from '@salesforce/label/c.LogConsole_ActionNarrowDateRange';
import totalsPartialHelp from '@salesforce/label/c.LogConsole_TotalsPartialHelp';
import problemsEmpty from '@salesforce/label/c.LogConsole_ProblemsEmpty';
import problemsEmptyHint from '@salesforce/label/c.LogConsole_ProblemsEmptyHint';
import problemsEmptyNoGrouping from '@salesforce/label/c.LogConsole_ProblemsEmptyNoGrouping';
import problemsEmptyNoGroupingHint from '@salesforce/label/c.LogConsole_ProblemsEmptyNoGroupingHint';
import emptyStateHint from '@salesforce/label/c.LogConsole_EmptyStateHint';
import detailsHeading from '@salesforce/label/c.LogConsole_DetailsHeading';
import listLoadFailedTitle from '@salesforce/label/c.LogConsole_ListLoadFailed';
import listLoadFailedHint from '@salesforce/label/c.LogConsole_ListLoadFailedHint';
import provenanceTagged from '@salesforce/label/c.LogConsole_ProvenanceTagged';
import groupedLogNumber from '@salesforce/label/c.LogConsole_GroupedLogNumber';
import groupedContext from '@salesforce/label/c.LogConsole_GroupedContext';
import rowSuffixSingular from '@salesforce/label/c.LogConsole_RowSuffixSingular';
import logRowSingular from '@salesforce/label/c.LogConsole_LogRowSingular';
import taggedOnlySuffix from '@salesforce/label/c.LogConsole_TaggedOnlySuffix';
import rangeInverted from '@salesforce/label/c.LogConsole_RangeInverted';
import rangeIncomplete from '@salesforce/label/c.LogConsole_RangeIncomplete';
import occurrencesReconciliation from '@salesforce/label/c.LogConsole_OccurrencesReconciliation';
import summaryLoadFailedNote from '@salesforce/label/c.LogConsole_SummaryLoadFailed';

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
// The problems list opens on severity, worst first, with the occurrence count breaking ties inside one
// severity. Opening on the count alone ranked a chatty INFO success message above every error in the
// window, under a heading that calls the list problems.
const PROBLEM_SORT_FIELD = 'level';
const ENTRY_SORT_FIELD = 'createdDate';
// Columns whose FIRST click sorts descending. A datatable proposes ascending for a column it has not
// sorted before, which for Level is picklist order — DEBUG first — so clicking Level to find errors
// showed the least severe rows. The useful end of severity is the far end.
const DESCENDING_FIRST_COLUMNS = ['level'];
const ESCAPE_KEY = 'Escape';
// How the console asks for its four list and count reads: log the failure, answer undefined, raise no
// toast. An Aura error toast is sticky, and these four failures are the ones a reader recovers from by
// changing a filter — so the toast outlived the failure it described, sitting over a list that had since
// loaded, and carried a raw platform message nobody can act on. Both reads report in the page instead,
// where the next successful load clears them (see listLoadFailed and summaryLoadFailed). Every OTHER
// call this component makes keeps the toast: a failed drawer read has no in-page state to land in.
const SILENT_READ = {silent: true};

// Maps a datatable column fieldName to the controller sort wire key when they differ, which is every
// column showing a value the client composed rather than one the wire sent under that name. Columns whose
// fieldName is already a valid sort key pass through.
const SORT_KEY_BY_COLUMN = {logNumberDisplay: 'logNumber', sourceDisplay: 'className', contextDisplay: 'executionEvent'};

// Date-range presets that resolve to a rolling window measured back from now, keyed by the combobox value.
const WINDOW_MINUTES_BY_PRESET = {
	'15': 15, '60': 60, '240': 240, '1440': 1440, '10080': 10080, '43200': 43200
};
const DEFAULT_RANGE_PRESET = '1440';
// The widest rolling preset — a correlation deep link lands here so an older chain is still visible.
const WIDEST_RANGE_PRESET = '43200';
const CUSTOM_RANGE_PRESET = 'custom';

const pad = (value) => String(value).padStart(2, '0');

// The wire's provenance for a fingerprinted problem folded from counter rows. Its counterpart, 'derived',
// is never tested for directly: the console asks whether a row was tagged, and everything else is grouped.
const PROVENANCE_ROLLUP = 'rollup';
// A grouped problem's stable client-side key: the three fields it was actually grouped ON, and nothing else.
// Deliberately NOT the signature JSON the server round-trips, which also carries the group's label — the
// widest message seen in the window, a value that moves as new rows arrive. Keying on it silently changed a
// row's identity between loads, so the drawer closed itself on a refresh that had merely seen a longer
// message. The server ignores the label when opening a group, which is what makes it pure key noise here.
// Plain delimited text rather than JSON: this value becomes a datatable key-field, so it stays free of
// quotes and braces.
const groupIdentityKey = (record) => [
	record.exceptionType,
	record.className,
	record.methodLine,
	record.level
].join('|');
// Stands in for a value this kind of row cannot have, rather than leaving the cell blank. Not a Custom
// Label: it is punctuation, identical in every language, and a translator has nothing to decide about it.
const EM_DASH = '—';

// The derived-fold outcome the controller reports. COMPLETE is deliberately absent: the fold ran and the
// list is whole, so there is nothing to say, and a reassurance bar on every normal load is noise people
// learn to skip. 'info' is a configured outcome an admin chose; 'attention' is a list genuinely missing
// problems that exist, and the two must not look alike. Each action sends the reader to the one surface
// that can change the state they are in.
const GROUPING_STATUS_COMPLETE = 'COMPLETE';
const GROUPING_ACTION_SETTINGS = 'settings';
const GROUPING_ACTION_ENTRIES = 'entries';
const GROUPING_ACTION_RANGE = 'range';
// Each status also carries its own icon. The weight is a colour, and this component's rule is that
// nothing is signalled by colour alone; the icon is also read before the sentence is, so a shared mark
// would say "something is up" where a specific one already says which thing.
const GROUPING_STATUS = {
	DISABLED: {text: groupingDisabled, actionLabel: actionOpenLogSettings, action: GROUPING_ACTION_SETTINGS, weight: 'info', icon: 'utility:ban'},
	SKIPPED_SEARCH: {
		text: groupingSkippedSearch, actionLabel: actionSearchAllEntries, action: GROUPING_ACTION_ENTRIES, weight: 'info', icon: 'utility:search'
	}, // contrast, not filter: a half-filled circle says "partially covered", which is the state. A funnel would
	// point at the reader's own filter, when what is narrow is the configured scope.
	SKIPPED_LEVEL_SCOPE: {text: groupingSkippedLevelScope, actionLabel: actionOpenLogSettings, action: GROUPING_ACTION_SETTINGS, weight: 'info', icon: 'utility:contrast'},
	SKIPPED_NON_SELECTIVE: {text: groupingSkippedTooLarge, actionLabel: actionNarrowDateRange, action: GROUPING_ACTION_RANGE, weight: 'attention', icon: 'utility:warning'}
};
// totalsApproximateCause: a leg that never ran is absent rather than trimmed, and the shipped help text
// describes trimming only.
const TOTALS_CAUSE_PARTIAL = 'PARTIAL';
// Where the Log Settings action goes while the server has yet to answer with the setting's own page: the
// Custom Settings index, which lists every custom setting in the org and leaves the reader to find Log
// Settings and press Manage. A worse landing than the page itself, and the only one reachable without a
// round trip, so it stands in rather than a dead button. The status bar links rather than toggles either
// way: whoever is reading a read-only console may not be the person allowed to change an org-wide switch.
const CUSTOM_SETTINGS_HOME_PATH = '/lightning/setup/CustomSettings/home';
// The console's own nav item — the LAST-RESORT target for dropping a spent hand-off's URL state, used only
// when no page reference has been delivered to derive the current page from. The bare api name is deliberate:
// the platform resolves it to the namespaced tab in a subscriber org, the same convention the Chain Monitor
// cross-link relies on.
const LOG_CONSOLE_PAGE_REFERENCE = {type: 'standard__navItemPage', attributes: {apiName: 'LogConsole'}};
// The URL state a Chain Monitor hand-off travels in — the keys the console consumes and, on a clear, drops
// from the address. Only these are ever removed: any other state a host page carries is not ours to touch.
const HANDOFF_STATE_KEYS = [
	'c__correlationId',
	'c__windowStart',
	'c__windowEnd',
	'c__viewLogsAt'
];
// Identity of a correlation hand-off: the correlation, the window it arrived with, and the click that sent
// the link — the Chain Monitor stamps c__viewLogsAt per click. Two deliveries that agree on all four ARE the
// same link (the temporary tab keeps the URL, so the wire re-delivers it on every return) and a link is
// applied once per console; a second click for the same finished chain carries a new stamp and applies again.
const deepLinkIdentity = (state) => HANDOFF_STATE_KEYS.map((key) => state[key]).join('|');
// The plainest join, for when the language-aware one is not available.
const LEVEL_LIST_FALLBACK_SEPARATOR = ', ';
// Joins the level list the way the reader's own language joins one, rather than assuming English "and". The
// SALESFORCE user's language, not the browser's, and the language rather than the locale: the sentence around
// the list is a translated label, chosen by language, so the joining word has to come from the same place or a
// German sentence gets an English "and". Guarded because this runs inside a render getter, where a thrown
// RangeError (an unrecognised tag) or TypeError (a runtime without Intl.ListFormat) would take the whole
// problems view down over a caption; the plain comma join is always readable.
function levelListText(levels)
{
	try
	{
		return new Intl.ListFormat(LANGUAGE, {style: 'long', type: 'conjunction'}).format(levels);
	}
	catch(unsupported /* eslint-disable-line no-unused-vars */)
	{
		return levels.join(LEVEL_LIST_FALLBACK_SEPARATOR);
	}
}

// Groups a count the way the reader's own language groups one, so a number interpolated into a label
// reads like the numbers the ribbon renders through lightning-formatted-number beside it. Guarded for
// the same reason levelListText is: an unrecognised language tag or a runtime without Intl.NumberFormat
// throws, and this runs inside render getters where that would take a whole view down over a number.
function countText(value)
{
	try
	{
		return new Intl.NumberFormat(LANGUAGE).format(value);
	}
	catch(unsupported /* eslint-disable-line no-unused-vars */)
	{
		return String(value);
	}
}

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
	// The problem whose occurrences the list is pinned to: {classMethod, occurrenceCount}, set by the
	// drawer's View occurrences drill and cleared from its own pill. Null whenever no drill is in force.
	sourceFilter = null;
	// Why the custom range on screen is not the range being queried — inverted, or not finished. Null when
	// the range is usable. An unusable range leaves the previous window in place, so without this the
	// reader is looking at results that answer a question they have already changed.
	customRangeError = null;
	// The identity of the hand-off this console has already applied (see deepLinkIdentity), remembered for
	// the life of the component so a re-delivery of the same link cannot re-pin a filter the reader cleared.
	consumedDeepLinkKey = null;
	// The page reference most recently delivered by the wire — the page the console is hosted on right now,
	// and the base forgetHandoffUrl rebuilds the address from (see handoffFreePageReference).
	latestPageReference = null;
	searchDebounceTimer = null;
	// Monotonic request token: only the newest reload may apply its results, so a slow earlier
	// query (e.g. a shorter search prefix) cannot overwrite the results of a later one.
	requestSequence = 0;
	// Set by the load path the moment the console issues its first query, whichever path issued it.
	hasIssuedInitialLoad = false;

	records = [];
	summary = null;
	totalCount = 0;
	totalPages = 0;
	hasMorePages = false;
	isLoadingMore = false;
	// The visible list was cut short: the problems page's capped (either leg), or the entries page's
	// resultsTruncated, which is the only flag that page carries.
	capped = false;
	// The last fresh list read failed rather than finding nothing. A failed call has already toasted its
	// own error and resolves undefined, which empties the list exactly as a genuine no-match does — so
	// without this flag the console answers a failed read with "No logs match these filters", sending the
	// reader to widen filters that were never the problem while the ribbon still counts six figures.
	listLoadFailed = false;
	// The ribbon's own counts could not be read. The ribbon simply has nothing to draw then, which on
	// screen is indistinguishable from a window with no activity, so it says which of the two it is —
	// in the page, where it clears on the next successful load, rather than only in a passing toast.
	summaryLoadFailed = false;
	// A row's detail has landed and the drawer it opens has yet to be rendered, so the next render moves
	// focus into it. Reaching the drawer by tabbing means passing every loaded row's link first.
	pendingDrawerFocus = false;
	// The derived fold's outcome and the levels it is configured to cover. The entries page carries
	// neither, so both reset to their empty form whenever that view loads.
	derivedStatus = null;
	derivedLevelScope = [];

	/**
	 * @description The namespace prefix a generated Apex snippet must carry to compile in this org — "kern." in
	 * a managed subscriber, empty in a no-namespace deploy. Wired rather than fetched per selection: it cannot
	 * change for the life of an org. Empty until it arrives, which is the correct no-namespace answer, and the
	 * snippet only renders on a drawer that is several interactions away from first paint.
	 * @type {string}
	 */
	apexNamespacePrefix = '';

	/**
	 * @description Setup URL of the Log Settings manage page, resolved server-side because Setup keys that
	 * page by the object's key prefix, which no client can know. Null until the wire answers, and null if it
	 * fails — the grouping bar's Setup action falls back to the Custom Settings index in both cases.
	 * @type {?string}
	 */
	logSettingsSetupUrl = null;

	// The datatable key of the selected row: a record id for an entry or a tagged problem, the delimited
	// grouping identity (see groupIdentityKey) for a grouped one. Not an entry id — the entry the drawer opened,
	// when there is one, is selectedDetail.id.
	selectedRowKey = null;
	// The row whose detail the drawer is showing — its provenance, count and span all read from here — set
	// together with the detail, never ahead of it. Distinct from selectedRowKey, which the table highlights the
	// moment a row is clicked: while the new row's detail is still in flight the drawer keeps describing the
	// previous row WHOLE. A provenance that arrived a round trip before its detail would dress the previous
	// row's detail in the new row's surfaces — hiding its record button, offering to tag a problem that is already
	// tagged, with a copyable snippet built from the wrong row — for as long as the round trip took.
	openedRow = null;
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
		viewGroupLabel,
		levelsGroupLabel,
		contextGroupLabel,
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
		entrySummaryTooLarge,
		emptyState,
		loadingAlt,
		summaryLoadFailedNote,
		detailsHeading
	};

	// What the list region is called when focus is moved onto it: the view it is showing. Reusing the two
	// view names rather than minting a region name of its own keeps the announcement the same words the
	// reader pressed to get here, and there is nothing else the region could honestly be called.
	get listRegionLabel()
	{
		return this.isProblemsView ? this.label.viewProblems : this.label.viewEntries;
	}

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
			{
				label: colLogNumber,
				fieldName: 'logNumberDisplay',
				type: 'logNumber',
				sortable: true,
				typeAttributes: {recordUrl: {fieldName: 'recordUrl'}, isGrouped: {fieldName: 'isGrouped'}}
			},
			{label: colLevel, fieldName: 'level', type: 'logLevel', sortable: true, typeAttributes: {level: {fieldName: 'level'}}},
			// The pill text is a constant, so it rides on the column rather than being copied onto every row.
			{
				label: colProblem,
				fieldName: 'shortMessage',
				type: 'problemName',
				sortable: true,
				wrapText: true,
				typeAttributes: {isTagged: {fieldName: 'isTagged'}, taggedLabel: provenanceTagged}
			},
			{label: colSource, fieldName: 'sourceDisplay', type: 'text', sortable: true},
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
			{
				label: colLogNumber,
				fieldName: 'logNumberDisplay',
				type: 'logNumber',
				sortable: true,
				typeAttributes: {recordUrl: {fieldName: 'recordUrl'}, isGrouped: {fieldName: 'isGrouped'}}
			},
			{
				label: colTime,
				fieldName: 'createdDate',
				type: 'date',
				sortable: true,
				typeAttributes: {year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit'}
			},
			{label: colLevel, fieldName: 'level', type: 'logLevel', sortable: true, typeAttributes: {level: {fieldName: 'level'}}},
			{label: colMessage, fieldName: 'shortMessage', type: 'text', sortable: true, wrapText: true},
			{label: colSource, fieldName: 'sourceDisplay', type: 'text', sortable: true},
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
		return [
			{
				key: 'total',
				isTotal: true,
				label: this.label.totalOccurrences,
				value: this.summary.totalOccurrences ?? 0,
				footnote: `${this.summary.distinctCount ?? 0} ${this.label.distinctShown}`,
				isApproximate: this.summary.totalsApproximate === true, // The shipped help describes a trimmed count ("the most recent activity groups"), which is simply
				// false when a whole leg never ran and its contribution is absent rather than cut short.
				approximateHelp: this.summary.totalsApproximateCause === TOTALS_CAUSE_PARTIAL ? totalsPartialHelp : this.label.totalsApproximateHelp,
				cardClass: 'summary-card summary-card_total'
			},
			...this.activeLevelCards((level, entry) => this.levelCard(level, entry.occurrences ?? 0, this.problemLevelFootnote(level, entry), this.label.occurrencesSuffix)),
			this.topSourcesCard(true)
		];
	}

	// The entries ribbon counts forensic rows: a read-only total, one clickable card per active level (row
	// count), and the ranked top-source list (row count). When the server declined the breakdown (the range
	// held more rows than the ribbon may scan) only the total renders: the pre-flight count that declined the
	// scan measured it exactly, while a zero on every level card would be false — those rows exist, they are
	// just not broken down. The note beside the ribbon says why (see entrySummaryDeclined).
	get entrySummaryCards()
	{
		const totalCard = {
			key: 'total',
			isTotal: true,
			label: this.label.entriesInWindow,
			value: this.summary.totalRows ?? 0,
			footnote: (this.summary.totalRows ?? 0) === 1 ? logRowSingular : this.label.logRows,
			cardClass: 'summary-card summary-card_total'
		};
		if(this.entrySummaryDeclined)
		{
			return [totalCard];
		}
		return [
			totalCard,
			...this.activeLevelCards((level, entry) => this.levelCard(level, entry.rowCount ?? 0, this.rowsWord(entry.rowCount ?? 0), null)),
			this.topSourcesCard(false)
		];
	}

	// Only the entries ribbon can be declined: its per-level and per-source breakdown scans the window, and the
	// server withholds that scan over a range too large for it. The problems ribbon degrades through its own
	// vocabulary (totalsApproximate and the grouping status bar), so this never reads a problems summary.
	get entrySummaryDeclined()
	{
		return !this.isProblemsView && this.summary?.declined === true;
	}

	// Grouped the same way the ribbon's own number beside it is grouped: the banner used to print a bare
	// 3985 next to a formatted 3,985 and leave the reader to work out that the two were the same count.
	get cappedText()
	{
		return cappedBanner.replace('{0}', countText(this.totalCount));
	}

	// Says how a drilled problem's occurrence count and the entries listed under it relate. The two numbers
	// are counted over different things — the problem was counted every time it happened, while the list
	// holds the entries still on file from that source and level — so the sentence relates them rather than
	// claiming one is a subset of the other, and either number can be the larger one.
	//
	// The ENTRIES view only. The pin itself spans both views, like the correlation pill, but in the problems
	// view {1} is a count of problems rather than of entries, and this sentence about entries would then be
	// interpolated with a number that is not one. Absent when nothing is pinned or the count never arrived.
	get occurrencesReconciliation()
	{
		const counted = this.sourceFilter?.occurrenceCount;
		return !this.isProblemsView && counted > 0 ? occurrencesReconciliation.replace('{0}', countText(counted)).replace('{1}', countText(this.totalCount)) : null;
	}

	/**
	 * @description The removable pill text for a pinned problem source, so the drill from a problem to its
	 * own entries is a visible, clearable filter rather than an invisible one.
	 * @returns {string}
	 */
	get sourceFilterPillLabel()
	{
		return `${colSource}: ${this.sourceFilter?.classMethod}`;
	}

	// Only over a list that has rows to be the first of. The problems page reports capped whenever the rollup
	// scan degraded — including a wide window where the rollup leg threw AND the derived leg declined — and
	// that combination leaves an empty list. "Showing the first 0. Narrow the filters to see the rest." over an
	// empty state, under a status bar already explaining the decline, would be a second amber surface saying
	// something false. The status bar and the empty state between them already say what happened.
	get showCappedBanner()
	{
		return this.capped && !this.isEmpty;
	}

	// The grouping status bar, or null when there is nothing to say: the entries view, where grouping does
	// not apply at all, and COMPLETE, where the fold ran and the list is whole.
	get groupingStatus()
	{
		const config = this.isProblemsView ? GROUPING_STATUS[this.derivedStatus] : null;
		return config ? {
			text: config.text.replace('{0}', this.groupedLevelText),
			actionLabel: config.actionLabel,
			action: config.action,
			icon: config.icon,
			barClass: `grouping-bar grouping-bar_${config.weight}`
		} : null;
	}

	// States permanently and quietly what this tab covers. It is the only thing that explains a PARTIAL
	// level mismatch: viewing a level inside the configured scope alongside one outside it leaves the
	// status COMPLETE, fires no bar, and the problems at the outside level simply never appear while the
	// entries view plainly lists their rows. Suppressed while a bar is up, which is already explaining.
	get scopeCaption()
	{
		const covering = this.isProblemsView && this.derivedStatus === GROUPING_STATUS_COMPLETE && this.derivedLevelScope.length > 0;
		return covering ? groupingScopeCaption.replace('{0}', this.groupedLevelText) : null;
	}

	get groupedLevelText()
	{
		return levelListText(this.derivedLevelScope);
	}

	// An empty list has to say which kind of empty it is, and the cases are genuinely different. A read
	// that FAILED comes first and overrides every other sentence here: none of them are true of a list
	// that was never retrieved, and the shipped no-match copy is the worst of them — it hands the reader
	// their own filters to fix while the ribbon behind it still counts every entry in the window.
	// Past that, the page did arrive and was empty: COMPLETE earns the claim that nothing repeats, because
	// the fold ran; a reported skip earns the pointer to the bar above; a NULL status earns neither, and
	// falls back to the neutral shipped copy, which asserts nothing beyond the filters.
	get emptyTitle()
	{
		if(this.listLoadFailed)
		{
			return listLoadFailedTitle;
		}
		if(this.derivedStatus === GROUPING_STATUS_COMPLETE)
		{
			return problemsEmpty;
		}
		return this.derivedStatus ? problemsEmptyNoGrouping : this.label.emptyState;
	}

	get emptyHint()
	{
		if(this.listLoadFailed)
		{
			return listLoadFailedHint;
		}
		if(this.derivedStatus === GROUPING_STATUS_COMPLETE)
		{
			return problemsEmptyHint;
		}
		return this.derivedStatus ? problemsEmptyNoGroupingHint : emptyStateHint;
	}

	get emptySpecId()
	{
		if(this.listLoadFailed)
		{
			return 'list-load-failed-state';
		}
		return this.isProblemsView ? 'problems-empty-state' : 'entries-empty-state';
	}

	// The failed read gets its own test id as well as its own copy, so a test — and the release harness —
	// can tell the two states apart by more than the sentence inside them.
	get emptyTestId()
	{
		return this.listLoadFailed ? 'list-load-failed' : 'empty-state';
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
		return this.selectedRowKey ? [this.selectedRowKey] : [];
	}

	get hasSelection()
	{
		return this.selectedDetail != null;
	}

	get selectedRecord()
	{
		return this.records.find((record) => record.rowKey === this.selectedRowKey) ?? null;
	}

	// Everything the drawer is told about the row it is showing reads from openedRow, so it changes as one with
	// the detail. Whether the open row was tagged in code or grouped at read time cannot be read off the detail
	// — both kinds open on the same DTO — so the row is the only source.
	get selectedProvenance()
	{
		return this.openedRow?.source ?? null;
	}

	get selectedOccurrenceCount()
	{
		return this.openedRow?.occurrenceCount ?? null;
	}

	// The problem's whole span, from the row: the drawer's detail is one entry — for a grouped problem the most
	// recent occurrence — so its own timestamps cannot say when the problem was FIRST seen, and a group whose
	// entries were all purged has none. Null in the entries view, where the entry's own time is the truth.
	get selectedFirstSeen()
	{
		return this.isProblemsView ? this.openedRow?.firstSeen ?? null : null;
	}

	get selectedLastSeen()
	{
		return this.isProblemsView ? this.openedRow?.lastSeen ?? null : null;
	}

	/**
	 * @description The removable pill text for a pinned correlation filter, so a deep-linked
	 * correlation is visible and clearable rather than an invisible filter.
	 * @returns {string}
	 */
	get correlationPillLabel()
	{
		return `${colCorrelation}: ${this.correlationId}`;
	}

	/**
	 * @description Receives the namespace prefix. Through handleWireResponse like every other wire in the
	 * framework, so a failure toasts rather than being swallowed: silently falling back to an empty prefix in a
	 * managed org would hand the reader a snippet that fails on paste — precisely the defect a no-namespace
	 * development org cannot show, because there the empty prefix is right.
	 * @param {Object} result The wire result, {data, error}.
	 */
	@wire(getApexNamespacePrefix) wireApexNamespacePrefix(result)
	{
		this.apexNamespacePrefix = this.handleWireResponse(result) ?? '';
	}

	/**
	 * @description Receives the Setup URL of the Log Settings page — the custom setting's own manage page,
	 * which shows the configured values, rather than the Custom Settings index the reader would otherwise
	 * have to search. Wired rather than fetched on click: the URL is keyed by the object's key prefix, which
	 * cannot change for the life of an org, and a round trip on click would only delay the navigation.
	 * @param {Object} result The wire result, {data, error}.
	 */
	@wire(getLogSettingsSetupUrl) wireLogSettingsSetupUrl(result)
	{
		this.logSettingsSetupUrl = this.handleWireResponse(result) ?? null;
	}

	// One card per ACTIVE level, in the canonical severity order and regardless of what the rollup returned: a level the
	// window holds nothing for keeps its card at zero rather than vanishing, so the ribbon's locked invariant — Total
	// always equals the sum of the level cards on screen — survives an empty level.
	activeLevelCards(buildCard)
	{
		const rollupByLevel = new Map((this.summary.perLevel ?? []).map((entry) => [
			entry.level,
			entry
		]));
		return ALL_LEVELS.filter((level) => this.levels.includes(level)).map((level) => buildCard(level, rollupByLevel.get(level) ?? {}));
	}

	// The footnote under a problems level card: how many distinct problems it counts, and — when problem
	// grouping did not cover that level on this load — that the count is of tagged problems alone. Without
	// it a level the fold never looked at reads as a level with nothing wrong in it, which on a busy org is
	// a zero beside tens of thousands of rows the entries view lists happily.
	problemLevelFootnote(level, entry)
	{
		const distinct = `${entry.distinctCount ?? 0} ${this.label.distinctSuffix}`;
		return this.isGroupedLevel(level) ? distinct : `${distinct} ${taggedOnlySuffix}`;
	}

	// Whether problem grouping contributed to a level's numbers on this load: only when the fold ran whole
	// AND the level sits inside the scope it is configured for. A search term, a switched-off setting, a
	// window too large to fold and a level outside the configured scope all leave the numbers counting the
	// problems a developer tagged in code and nothing else.
	isGroupedLevel(level)
	{
		return this.derivedStatus === GROUPING_STATUS_COMPLETE && this.derivedLevelScope.includes(level);
	}

	// The unit word for a row count, agreeing with the number in front of it: one row, two rows. Two
	// labels rather than string surgery on one, because the two forms are not the same word in every
	// language and a translator has to be given both.
	rowsWord(count)
	{
		return count === 1 ? rowSuffixSingular : this.label.rowsSuffix;
	}

	// A clickable per-level card. Clicking it filters the list to that single level, so the total always equals the sum
	// of the level cards. `labelSuffix` is appended to the humanised level name when present.
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

	// The ranked top-source card: up to three sources, each a click-to-drill row. Problems show each source's share of
	// occurrences; entries show its row count.
	topSourcesCard(isProblems)
	{
		const sources = (this.summary.topSources ?? []).map((source, index) => ({
			key: source.name, name: source.name, rank: index + 1, metric: isProblems ? `${source.percent}%` : `${source.count} ${this.rowsWord(source.count)}`
		}));
		return {key: 'sources', isSources: true, label: this.label.topSourcesLabel, sources, hasSources: sources.length > 0};
	}

	@wire(CurrentPageReference) captureDeepLink(pageReference)
	{
		// Remembered on every delivery, hand-off or not: this is what the console is CURRENTLY hosted on, and
		// the reference forgetHandoffUrl rebuilds the address from — the console can sit on any Lightning page,
		// and a reader clearing a filter must stay on the page they are on.
		this.latestPageReference = pageReference ?? this.latestPageReference;
		const deepLinkCorrelation = pageReference?.state?.c__correlationId;
		// A correlation deep link (e.g. from Chain Monitor) pre-seeds the filter, and re-filters
		// live if it arrives while the console is already open. The chain's raw rows live in the
		// entries view and may predate the default window, so the link lands on Individual entries;
		// the pinned correlation renders as a removable pill so the active filter is visible
		// instead of an inexplicably empty console. Every other filter is reset, including the
		// search term and the execution context: a term left over from the console's previous use
		// would silently hide the very rows the link was followed to see.
		//
		// Applied ONCE per distinct link. The wire re-delivers the page reference on every return to
		// the tab the hand-off opened, and that tab keeps the hand-off URL for as long as it lives —
		// so a link tested only against the pinned correlation came back to life the moment the reader
		// cleared it and stepped off the page. A genuinely different link still applies live.
		if(deepLinkCorrelation && deepLinkIdentity(pageReference.state) !== this.consumedDeepLinkKey)
		{
			this.consumedDeepLinkKey = deepLinkIdentity(pageReference.state);
			this.correlationId = deepLinkCorrelation;
			this.view = 'entries';
			this.sortField = ENTRY_SORT_FIELD;
			this.sortedByColumn = ENTRY_SORT_FIELD;
			this.sortAscending = false;
			this.levels = [...ALL_LEVELS];
			this.searchTerm = '';
			this.executionEvent = '';
			this.sourceFilter = null;
			this.customRangeError = null;
			this.applyDeepLinkRange(pageReference.state.c__windowStart, pageReference.state.c__windowEnd);
			// noinspection JSIgnoredPromiseFromCall
			this.resetAndReload();
		}
	}

	// A deep link that carries the source record's own bounds pins the console to exactly that
	// window (an absent upper bound means the source is still running, so the window runs to now),
	// and the custom From/To inputs are seeded from the same instants so the range on screen is the
	// range being queried. A link with no bounds falls back to the widest rolling preset, which is
	// wide enough that an older correlation is still inside the window.
	applyDeepLinkRange(windowStart, windowEnd)
	{
		if(!windowStart)
		{
			this.rangePreset = WIDEST_RANGE_PRESET;
			this.windowMinutes = WINDOW_MINUTES_BY_PRESET[WIDEST_RANGE_PRESET];
			this.customStart = null;
			this.customEnd = null;
			return;
		}
		this.rangePreset = CUSTOM_RANGE_PRESET;
		this.customStart = windowStart;
		this.customEnd = windowEnd || new Date().toISOString();
		this.seedCustomRangeInputs(new Date(this.customStart), new Date(this.customEnd));
	}

	handleRemoveCorrelation()
	{
		this.correlationId = null;
		this.forgetHandoffUrl();
		// noinspection JSIgnoredPromiseFromCall
		this.resetAndReload();
	}

	// Drops the c__ state a Chain Monitor hand-off left in the URL, once the reader has cleared the filter
	// that state describes. Without it the console's own address still says "show me this correlation, in
	// this two-minute window", and the next mount of the component — a return to the tab, a reload, a
	// bookmark — obediently pins it all again over a filter bar the reader had emptied.
	//
	// Only on a clear, never at consumption time: replacing the URL the moment the link is applied would
	// throw the link away if the platform remounted the component on that navigation, while a remount here
	// merely reloads the console's defaults, which is what the reader just asked for.
	//
	// replace=true rather than a push: the cleared console is the same stop in the reader's journey, not a
	// new one to press Back through. Guarded because tidying the address is housekeeping — the clear the
	// reader asked for has already happened, and must survive a navigation service that is unavailable.
	forgetHandoffUrl()
	{
		if(!this.consumedDeepLinkKey)
		{
			return;
		}
		try
		{
			this.navigate(this.handoffFreePageReference(), true);
		}
		catch(navigationFailure)
		{
			this.consoleError(navigationFailure, 'forgetHandoffUrl: ');
		}
	}

	// The page the console is on, minus the hand-off's own state keys. Derived from the delivered page
	// reference rather than hardcoding the console's nav item: the bundle is exposed to app pages, and a
	// reader clearing a filter on a host page must stay there — with every OTHER state key the host carries
	// intact. The packaged nav item stands in only if no reference was ever delivered.
	handoffFreePageReference()
	{
		const reference = this.latestPageReference;
		if(!reference?.type)
		{
			return LOG_CONSOLE_PAGE_REFERENCE;
		}
		const state = {...(reference.state ?? {})};
		HANDOFF_STATE_KEYS.forEach((key) => delete state[key]);
		return {type: reference.type, attributes: {...(reference.attributes ?? {})}, state};
	}

	// noinspection JSUnusedGlobalSymbols - LWC framework lifecycle hook
	connectedCallback()
	{
		// A deep link's page reference reaches the wire BEFORE this hook runs, and it has already
		// issued the correlation-pinned load. Loading again here would query the same window a second
		// time only for the request-sequence guard to discard the first pair of answers — twice the
		// server work for one list. A plain mount arrives here with nothing loaded and loads normally.
		if(!this.hasIssuedInitialLoad)
		{
			// noinspection JSIgnoredPromiseFromCall
			this.reload();
		}
	}

	// noinspection JSUnusedGlobalSymbols - LWC framework lifecycle hook
	renderedCallback()
	{
		if(this.pendingDrawerFocus)
		{
			this.pendingDrawerFocus = false;
			// The panel, not anything inside it: the drawer is a separate component and its internals are
			// not this one's to reach into. Landing on the panel puts the drawer's own controls next in the
			// tab order, which is the whole point — every loaded row's Log Number link is a tab stop, so a
			// reader who had scrolled a few pages could not reach the drawer by tabbing at all.
			this.template.querySelector('.panel')?.focus();
		}
	}

	// noinspection JSUnusedGlobalSymbols - LWC framework lifecycle hook
	disconnectedCallback()
	{
		window.clearTimeout(this.searchDebounceTimer);
	}

	// Escape closes the drawer from anywhere in the console, which is where a reader's hand already is.
	// The keydown is not stopped: the console owns no other Escape behaviour, and swallowing it would
	// take the key away from a modal or a combobox that opened inside this subtree.
	//
	// An Escape a child has already handled is left alone. A combobox closes its own dropdown on Escape and
	// marks the event handled; without this guard that one key press would shut the dropdown AND the
	// drawer, and the reader would have lost the row they were reading to a keystroke aimed at a menu.
	handleKeyDown(event)
	{
		if(event.key === ESCAPE_KEY && !event.defaultPrevented && this.hasSelection)
		{
			this.handleDetailClose();
		}
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
			classMethod: this.sourceFilter?.classMethod ?? null,
			sortField: this.sortField,
			sortAscending: this.sortAscending,
			pageSize: this.pageSize,
			pageNumber: this.pageNumber
		};
	}

	async reload()
	{
		this.hasIssuedInitialLoad = true;
		this.isLoading = true;
		// Cleared before the round trip, not after it: the bar carries a live action button, and a stale one
		// is worse than none. Clear the search box and the old "grouping cannot apply your search" bar would
		// still be offering to run that search, on a term that no longer exists.
		this.derivedStatus = null;
		this.derivedLevelScope = [];
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
		const data = await this.callControllerMethod(apexMethod, {requestJson: JSON.stringify(request)}, SILENT_READ);
		if(sequence != null && sequence !== this.requestSequence)
		{
			return;
		}
		// A failed call has logged its own error and resolved undefined; a page that arrived and found
		// nothing is an object. That difference is the only thing separating "the read failed" from "your
		// filters matched nothing", and the list says something false to the reader if it guesses wrong.
		// Only a fresh page decides it: an appended page that fails leaves the rows already on screen alone.
		if(!append)
		{
			this.listLoadFailed = data === undefined;
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
			// The wire's capped, falling back to resultsTruncated: on the problems page capped is the OR of both
			// legs, so a derived-leg cap raises the banner the rollup-only flag would have missed. The entries
			// page carries no capped flag at all and both views share this load path, so the fallback keeps it.
			this.capped = (data.capped ?? data.resultsTruncated) === true;
			// Only for a fresh page. The status describes the fold that produced THIS page, and the fold
			// re-runs per page against a rolling window, so an appended page can decline a scan page one
			// completed. Letting it through would relabel rows already on screen — an amber "this range is
			// too large to group" over a list whose first page was grouped, and the caption silently gone.
			if(!append)
			{
				this.derivedStatus = data.derivedStatus ?? null;
				this.derivedLevelScope = data.derivedLevelScope ?? [];
			}
			this.reconcileSelection();
		}
		else if(!append)
		{
			this.records = [];
			this.capped = false;
			this.derivedStatus = null;
			this.derivedLevelScope = [];
			this.clearSelection();
		}
	}

	// A grouped problem owns no LogEntry__c, so it has no id and no log number. Its row key is the delimited
	// grouping identity (groupIdentityKey); the JSON signature the fold emitted travels on the row unchanged, as
	// the only handle the server accepts to open it.
	decorateRow(record)
	{
		// sourceDisplay, never source: the wire's source carries the problem's provenance ('rollup' or
		// 'derived'), so a display value under the same key overwrites it in the spread below and the
		// client loses the only thing that distinguishes a grouped problem from a tagged one. The shipped
		// contextDisplay beside it is the same pattern — the humanised value never shadows its wire key.
		// The dash rather than a blank, for the same reason the log number gets one. A grouped problem is not
		// grouped on its execution context, so the wire never sends one and EVERY grouped row's Context cell is
		// empty; a problem folded from rows with no recorded source has no source either. The class is what makes
		// a source: an entry logged with no class still carries its exception's line number, which the wire sends
		// on its own, and joined to an absent class that reads "null.42" — so a bare line is dashed, not shown.
		const sourceDisplay = record.className ? [
			record.className,
			record.methodLine
		].filter(Boolean).join('.') : EM_DASH;
		// A derived problem is grouped at read time and has no record of its own, so it gets no link at
		// all rather than one to /lightning/r/null/view.
		const recordUrl = record.id ? `/lightning/r/${record.id}/view` : null;
		// A row with no record behind it is a problem the console grouped at read time. Its Log Number and
		// Context cells are not values that went missing — this kind of row never had either, because it
		// owns no LogEntry__c and was not grouped on a context — so both cells say what the row is instead
		// of showing the dash a genuinely absent value gets.
		const isGrouped = !record.id;
		const contextDisplay = CONTEXT_LABEL_BY_VALUE[record.executionEvent] ?? record.executionEvent ?? (isGrouped ? groupedContext : EM_DASH);
		// rowKey is the datatable's key. Keying on id alone would collapse every grouped row onto one undefined
		// key, and the table would treat them as a single row for selection and for its own diffing.
		// logNumberDisplay keeps the dash only for a row that owns a record but has no number to show, which
		// is a value that really did go missing; a grouped row gets the word for what it is instead.
		// isTagged marks one kind of row and not the other — grouping is what the console does by default, so
		// badging every grouped row would dilute the badge into wallpaper, while tagging is deliberate intent.
		return {
			...record,
			sourceDisplay,
			contextDisplay,
			recordUrl,
			isGrouped,
			rowKey: record.id ?? groupIdentityKey(record),
			logNumberDisplay: record.logNumber || (isGrouped ? groupedLogNumber : EM_DASH),
			isTagged: record.source === PROVENANCE_ROLLUP
		};
	}

	async loadSummary(request, sequence = null)
	{
		// The problems view folds occurrences per problem (getLogSummary); the entries view counts forensic
		// rows (getEntrySummary). Each ribbon reads its own aggregate so the total always equals the sum of
		// its per-level cards.
		const summaryMethod = this.isProblemsView ? getLogSummary : getEntrySummary;
		const data = await this.callControllerMethod(summaryMethod, {requestJson: JSON.stringify(request)}, SILENT_READ);
		if(sequence != null && sequence !== this.requestSequence)
		{
			return;
		}
		this.summaryLoadFailed = data === undefined;
		this.summary = data || null;
	}

	// Keeps a selection only while its row is still listed — and, when the row the drawer is SHOWING is the one
	// that survived, re-reads it from the fresh page: its count moves as the window rolls, and the same record id
	// is an entry in one view and a tagged problem in the other, so a selection carried across a view switch
	// would otherwise keep the provenance of the view it was made in. Only that row: while a newer selection is
	// still in flight the drawer is describing the previous row, and re-pointing it at the new selection's record
	// here would dress the old detail in the new row's provenance a page load early — the very gap openedRow exists
	// to close. The in-flight response settles it when it lands, or the guard discards it.
	reconcileSelection()
	{
		if(!this.selectedRowKey)
		{
			return;
		}
		const survivor = this.selectedRecord;
		if(!survivor)
		{
			this.clearSelection();
			return;
		}
		if(this.openedRow?.rowKey === survivor.rowKey)
		{
			this.openedRow = survivor;
		}
	}

	clearSelection()
	{
		this.selectedRowKey = null;
		this.openedRow = null;
		this.selectedDetail = null;
		this.selectedTrace = [];
		this.selectedTraceTruncated = false;
		this.selectedFocusedDetail = null;
		this.pendingFocusId = null;
		this.focusedDetailCache = new Map();
	}

	/**
	 * @description Opens a list row in the drawer. A row carrying a signature is a grouped problem with no
	 * record of its own and is opened through that signature; anything else is opened by its id.
	 * @param {Object} row The selected row, as decorated for the datatable.
	 */
	async selectRow(row)
	{
		// The table highlights the new row now; the drawer keeps describing the previous row, whole, until the new
		// row's detail has landed (see openedRow).
		this.selectedRowKey = row.rowKey;
		this.selectedFocusedDetail = null;
		this.pendingFocusId = null;
		this.focusedDetailCache = new Map();
		const [detail, trace] = row.signature ? await this.loadGroupedProblem(row.signature) : await Promise.all([
			this.callControllerMethod(getLogEntryDetail, {entryId: row.id}),
			this.callControllerMethod(getCorrelatedTrace, {entryId: row.id})
		]);
		// The selection is the guard token: whatever is selected NOW wins. Without this the last response to
		// arrive wins instead, and two ordinary interactions go wrong. Clicking a grouped row then a tagged one
		// leaves the first problem's content in a drawer headed by the second one's count and highlight — the
		// grouped path costs two sequential round trips against the tagged path's one parallel pair, so the
		// slower response lands second almost every time. And a filter change that drops the selected row
		// closes the drawer, only for the in-flight response to re-open it over a row no longer in the list.
		if(this.selectedRowKey !== row.rowKey)
		{
			return;
		}
		// The row and its detail land together, never one ahead of the other (see openedRow). The listed record
		// rather than the clicked object: the datatable hands back its own row, and the loaded list is what the
		// drawer's count and span should agree with; a key no longer listed keeps the clicked row, which is all
		// there is.
		this.openedRow = this.selectedRecord ?? row;
		this.selectedDetail = detail || null;
		this.selectedTrace = trace ? trace.entries || [] : [];
		this.selectedTraceTruncated = trace ? trace.truncated === true : false;
		this.pendingDrawerFocus = true;
	}

	/**
	 * @description Opens a grouped problem: the server resolves which entry represents the group inside the
	 * window being viewed, and only then is there an entry to trace — so unlike the by-id path these two
	 * calls cannot go out together. The same signature opens a different entry under a different filter,
	 * which is why the request travels with it. When every occurrence has been purged between the fold and
	 * the click the server answers with a label-only detail carrying no id, and there is nothing to trace.
	 * @param {string} signatureJson The row's JSON-encoded derived signature.
	 * @returns {Promise<Array>} The detail and the trace, in the shape the by-id path returns.
	 */
	async loadGroupedProblem(signatureJson)
	{
		const detail = await this.callControllerMethod(getDerivedProblemDetail, {signatureJson, requestJson: JSON.stringify(this.buildRequest())});
		const trace = detail?.id ? await this.callControllerMethod(getCorrelatedTrace, {entryId: detail.id}) : null;
		return [
			detail,
			trace
		];
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
		// The opened entry, not the selected row: a grouped problem's row key is its grouping identity, while the
		// entry the drawer actually opened is the representative the server resolved for it.
		if(!entryId || entryId === this.selectedDetail?.id)
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
		this.switchView(event.target.dataset.view);
	}

	// The grouping status bar's action goes to the one surface that can change the state the reader is in:
	// Setup for a switch an admin set, the entries view for a search grouping cannot apply, the date range
	// for a window too large to fold. Setup is a link and never a toggle — whoever is reading a read-only
	// console may not be the person allowed to flip an org-wide switch, and doing it for them silently
	// would be worse than sending them to where it lives.
	handleGroupingAction()
	{
		const action = this.groupingStatus?.action;
		if(action === GROUPING_ACTION_SETTINGS)
		{
			// The setting's own manage page, which shows the configured values. The Custom Settings index
			// stands in only while the server has yet to answer with it, or if that call failed.
			this.navigate({type: 'standard__webPage', attributes: {url: this.logSettingsSetupUrl ?? CUSTOM_SETTINGS_HOME_PATH}});
		}
		else if(action === GROUPING_ACTION_ENTRIES)
		{
			this.switchView('entries');
		}
		else if(action === GROUPING_ACTION_RANGE)
		{
			// Explicitly the range action, never a bare else: switchView sets the view synchronously but the
			// re-render is a microtask later, so this button is still live for a second click. A bare else made a
			// double-click switch view AND yank focus into the date picklist on a view where it means nothing.
			this.template.querySelector('.date-range-combobox')?.focus();
		}
	}

	switchView(nextView)
	{
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
		// eslint-disable-next-line @lwc/lwc/no-async-operation -- search debounce: the timer is cleared on every keystroke, so at most one reload fires after typing settles
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
		// Any preset answers the question the custom range was half-way through asking, so its message goes.
		this.customRangeError = null;
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

	// Combines the four custom inputs into an absolute ISO instant pair once all are present and the range
	// is forward-ordered, then reloads. A range that cannot be run keeps the previous window and says why:
	// running an impossible window would return nothing at all, and running nothing SILENTLY leaves the
	// previous window's rows on screen looking like the answer to the range the reader just typed. A
	// cleared or unparseable box (a date input reports one as empty) is incomplete rather than wrong, and
	// gets its own sentence, because the reader has not finished asking the question yet.
	applyCustomRange()
	{
		if(!this.customFromDate || !this.customFromTime || !this.customToDate || !this.customToTime)
		{
			this.customRangeError = rangeIncomplete;
			return;
		}
		const start = this.combineLocal(this.customFromDate, this.customFromTime);
		const end = this.combineLocal(this.customToDate, this.customToTime);
		if(new Date(start).getTime() > new Date(end).getTime())
		{
			this.customRangeError = rangeInverted;
			return;
		}
		this.customRangeError = null;
		this.customStart = start;
		this.customEnd = end;
		// noinspection JSIgnoredPromiseFromCall
		this.resetAndReload();
	}

	// Seeds the custom inputs to the last 24 hours so switching to a custom range starts from a full window.
	seedCustomRangeDefaults()
	{
		const now = new Date();
		this.seedCustomRangeInputs(new Date(now.getTime() - DEFAULT_WINDOW_MINUTES * 60000), now);
	}

	// Writes an absolute instant pair back into the four From/To display inputs, in the viewer's time zone.
	seedCustomRangeInputs(from, to)
	{
		this.customFromDate = this.toDateInput(from);
		this.customFromTime = this.toTimeInput(from);
		this.customToDate = this.toDateInput(to);
		this.customToTime = this.toTimeInput(to);
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
		this.sourceFilter = null;
		this.customRangeError = null;
		this.rangePreset = DEFAULT_RANGE_PRESET;
		this.windowMinutes = DEFAULT_WINDOW_MINUTES;
		this.customStart = null;
		this.customEnd = null;
		this.customFromDate = '';
		this.customFromTime = '';
		this.customToDate = '';
		this.customToTime = '';
		this.forgetHandoffUrl();
		// noinspection JSIgnoredPromiseFromCall
		this.resetAndReload();
	}

	// The datatable proposes a direction for the column that was clicked; a column being sorted for the
	// first time is proposed ascending. That is right for a name and wrong for severity, where ascending
	// is picklist order and fills the list with DEBUG. So the first click on a descending-first column
	// takes the far end instead, and every click after that toggles from there as usual.
	handleSort(event)
	{
		const column = event.detail.fieldName;
		const firstClick = column !== this.sortedByColumn;
		this.sortedByColumn = column;
		this.sortField = SORT_KEY_BY_COLUMN[column] ?? column;
		this.sortAscending = firstClick && DESCENDING_FIRST_COLUMNS.includes(column) ? false : event.detail.sortDirection === 'asc';
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
		// Refresh replaces the list from page one, the same model a filter change follows. Reloading
		// at the current page would answer with that page alone and drop every row the operator had
		// already scrolled past.
		// noinspection JSIgnoredPromiseFromCall
		this.resetAndReload();
	}

	handleRowSelection(event)
	{
		const selected = event.detail.selectedRows;
		if(selected && selected.length > 0)
		{
			// noinspection JSIgnoredPromiseFromCall
			this.selectRow(selected[0]);
		}
	}

	// Closing the drawer hands focus back to the list rather than dropping it on the document body, so a
	// reader who closed with Escape or the × carries on from the table they were reading. The list
	// WRAPPER takes the focus, not the datatable: the datatable owns its own roving cell focus, and the
	// wrapper is there in every state the list can be in, including empty and loading.
	handleDetailClose()
	{
		this.clearSelection();
		this.template.querySelector('.listwrap')?.focus();
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

	/**
	 * @description Opens the raw rows behind a problem: the console switches to the individual-entries
	 * view, sorted newest first like any entries view, pinned to the class and method the problem was
	 * grouped under and to its own level. Pinned rather than searched — a search for the class name also
	 * matches every entry that merely mentions it in a message or a stack trace, which is how a problem
	 * counted 776 times opened a list of 126 rows from four other classes. The pin shows as a removable
	 * pill, and the two counts are reconciled beneath the ribbon (see occurrencesReconciliation). A
	 * problem logged with no source has only its message to go on and keeps the free-text search.
	 * @param {CustomEvent} event The `viewoccurrences` event carrying the problem's source.
	 */
	handleViewOccurrences(event)
	{
		this.view = 'entries';
		this.sortField = ENTRY_SORT_FIELD;
		this.sortedByColumn = ENTRY_SORT_FIELD;
		this.sortAscending = false;
		const problem = this.openedRow;
		if(problem?.classMethod)
		{
			this.sourceFilter = {classMethod: problem.classMethod, occurrenceCount: problem.occurrenceCount ?? null};
			this.searchTerm = '';
			// The problem is one level's problem, so its entries are that level's entries. Widening to
			// every level would list rows the problem never counted beside the count of the ones it did.
			this.levels = problem.level ? [problem.level] : [...ALL_LEVELS];
		}
		else
		{
			this.sourceFilter = null;
			this.searchTerm = event.detail.source;
		}
		// noinspection JSIgnoredPromiseFromCall
		this.resetAndReload();
	}

	handleRemoveSourceFilter()
	{
		this.sourceFilter = null;
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