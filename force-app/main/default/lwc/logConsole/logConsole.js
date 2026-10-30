// SPDX-License-Identifier: Apache-2.0
/**
 * @description Log Console container. Owns the filter state, the two list views
 * (distinct problems and flat entries), the scope summary, the pager and row
 * selection, and the whole-action scope: the pill, the banner and the two links to the
 * Chain Monitor. Renders the tabbed detail drawer. Reads from `CTRL_LogConsole` and
 * hands the loaded entry to `c-log-console-detail`.
 *
 * @author Jason van Beukering
 *
 * @date July 2026, October 2026
 */
import {wire} from 'lwc';
import {CurrentPageReference} from 'lightning/navigation';
import LANGUAGE from '@salesforce/i18n/lang';
import {ComponentBuilder} from 'c/componentBuilder';
import {CONTEXT_CHOICES, CONTEXT_LABEL_BY_VALUE, ORIGIN_CHOICES, ORIGIN_LABEL_BY_VALUE, ORIGIN_MIXED} from 'c/logConsoleContext';
import {formatTemplateString} from 'c/utilityString';
import getLogProblems from '@salesforce/apex/CTRL_LogConsole.getLogProblems';
import getLogEntries from '@salesforce/apex/CTRL_LogConsole.getLogEntries';
import getLogSummary from '@salesforce/apex/CTRL_LogConsole.getLogSummary';
import getEntrySummary from '@salesforce/apex/CTRL_LogConsole.getEntrySummary';
import getLogEntryDetail from '@salesforce/apex/CTRL_LogConsole.getLogEntryDetail';
import getDerivedProblemDetail from '@salesforce/apex/CTRL_LogConsole.getDerivedProblemDetail';
import getApexNamespacePrefix from '@salesforce/apex/CTRL_LogConsole.getApexNamespacePrefix';
import getLogSettingsSetupUrl from '@salesforce/apex/CTRL_LogConsole.getLogSettingsSetupUrl';
import getCorrelatedTrace from '@salesforce/apex/CTRL_LogConsole.getCorrelatedTrace';
import getActionSummary from '@salesforce/apex/CTRL_LogConsole.getActionSummary';
import resolveSearchId from '@salesforce/apex/CTRL_LogConsole.resolveSearchId';

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
import allOrigins from '@salesforce/label/c.LogConsole_AllOrigins';
import originFilterLabel from '@salesforce/label/c.LogConsole_OriginFilter';
import originGroupLabel from '@salesforce/label/c.LogConsole_OriginGroupLabel';
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
import colChain from '@salesforce/label/c.LogConsole_ColChain';
import chainThisAction from '@salesforce/label/c.LogConsole_ChainThisAction';
import entriesPosition from '@salesforce/label/c.LogConsole_EntriesPosition';
import perPage from '@salesforce/label/c.LogConsole_PerPage';
import backToList from '@salesforce/label/c.LogConsole_BackToList';
import pagerPrevious from '@salesforce/label/c.PaginatedTable_Previous';
import pagerNext from '@salesforce/label/c.PaginatedTable_Next';
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
import actionPill from '@salesforce/label/c.LogConsole_ActionPill';
import chainPill from '@salesforce/label/c.LogConsole_ChainPill';
import actionRangeNote from '@salesforce/label/c.LogConsole_ActionRangeNote';
import actionBannerEyebrow from '@salesforce/label/c.LogConsole_ActionBannerEyebrow';
import actionBannerStarted from '@salesforce/label/c.LogConsole_ActionBannerStarted';
import actionBannerRanFor from '@salesforce/label/c.LogConsole_ActionBannerRanFor';
import actionBannerStillRunning from '@salesforce/label/c.LogConsole_ActionBannerStillRunning';
import actionBannerChains from '@salesforce/label/c.LogConsole_ActionBannerChains';
import actionBannerNoChains from '@salesforce/label/c.LogConsole_ActionBannerNoChains';
import actionBannerLegacy from '@salesforce/label/c.LogConsole_ActionBannerLegacy';
import actionChipLaunchedBy from '@salesforce/label/c.LogConsole_ActionChipLaunchedBy';
import actionMoreChains from '@salesforce/label/c.LogConsole_ActionMoreChains';
import actionOpenChains from '@salesforce/label/c.LogConsole_ActionOpenChains';
import cappedBannerAction from '@salesforce/label/c.LogConsole_CappedBannerAction';
import chainStatusRunning from '@salesforce/label/c.ChainMonitor_StatusRunning';
import chainStatusCompleted from '@salesforce/label/c.ChainMonitor_StatusCompleted';
import chainStatusFailed from '@salesforce/label/c.ChainMonitor_StatusFailed';
import chainStatusAborted from '@salesforce/label/c.ChainMonitor_StatusAborted';
import chainStatusStalled from '@salesforce/label/c.ChainMonitor_StatusStalled';
import chainRestartOf from '@salesforce/label/c.ChainMonitor_RestartOf';
import chainStartedThisAction from '@salesforce/label/c.ChainMonitor_StartedThisAction';

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
// How many milliseconds one minute lasts.
const MILLISECONDS_PER_MINUTE = 60000;
const DEFAULT_PAGE_SIZE = 50;
// The page sizes a reader can choose; the engine caps a page at 2,000, far above.
const PAGE_SIZE_OPTIONS = [
	25,
	50,
	100
];
// Page numbers are offered only while they can be used: past this many pages the position line, Previous and Next
// are the pager, because 3,529 numbered pages are a fiction and the date range and the chips are the way through.
const MAX_NUMBERED_PAGES = 7;
// With the drawer open at this width and below the list keeps four columns: Time, Level, Message and Chain. The string
// is a CSS media query the browser parses, never text on screen, so there is nothing here for a translator.
// eslint-disable-next-line kerndx/no-hardcoded-user-text
const COMPACT_WIDTH_QUERY = '(max-width: 1280px)';
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
const SORT_KEY_BY_COLUMN = {logNumberDisplay: 'logNumber', sourceDisplay: 'writerName', contextDisplay: 'executionEvent'};

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
// The console's own nav item: the LAST-RESORT base for every address the console writes, a push as much as a
// replace, used only when no page reference has been delivered to derive the current page from. The bare api name
// is deliberate: the platform resolves it to the namespaced tab in a subscriber org, the same convention the
// Chain Monitor cross-link relies on.
const LOG_CONSOLE_PAGE_REFERENCE = {type: 'standard__navItemPage', attributes: {apiName: 'LogConsole'}};
// The keys that record what is pinned: the action, the chain it is narrowed to or the run pinned on its own, and the
// window a run arrived with. These are the keys the console writes, and the keys it compares an address against to
// know whether a pin would change anything.
const PIN_STATE_KEYS = [
	'c__rootCorrelationId',
	'c__correlationId',
	'c__windowStart',
	'c__windowEnd'
];
// The URL state the console owns: the pins, and the click stamp a Chain Monitor hand-off carries (never written, only
// read and then dropped). On a clear these are the only keys dropped from the address; any other state a host page
// carries is not ours to touch.
const HANDOFF_STATE_KEYS = [
	...PIN_STATE_KEYS,
	'c__viewLogsAt'
];
// Identity of a hand-off: the action or the run, the window it arrived with, and the click that sent the link (the
// Chain Monitor stamps c__viewLogsAt per click). A hand-off is applied once per identity, then the address is rewritten
// without the stamp and the plain address carries the pin from there; a second click carries a new stamp and applies
// again. An in-place pin forgets the identity, so Back onto a hand-off's address applies it once more.
const deepLinkIdentity = (state) => HANDOFF_STATE_KEYS.map((key) => state[key]).join('|');
// Opening an action turns these three levels on and leaves DEBUG as the reader had it: the story needs the three, and a
// nightly job's debug lines are not the story.
const ACTION_OPENING_LEVELS = [
	'ERROR',
	'WARN',
	'INFO'
];
// The action's range is its first entry to its last, a minute either side, the same margin the Chain Monitor's View logs
// draws around a run, so an entry written a moment either side of the recorded edges is still inside the window.
const ACTION_RANGE_MARGIN_MILLISECONDS = 60000;
// The shape of a tracking id the search box resolves before searching: the UUID the framework mints. Checked here so a
// plain word never costs a round trip; the server checks again.
const TRACKING_ID_SHAPE = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;
const RESOLVED_ACTION = 'ACTION';
const RESOLVED_LEGACY_ACTION = 'LEGACY_ACTION';
const RESOLVED_CHAIN = 'CHAIN';
// How a chip's run entered the action, the monitor's vocabulary.
const LAUNCH_KIND_CHAIN = 'CHAIN';
const LAUNCH_KIND_RESTART = 'RESTART';
const LAUNCH_KIND_ORIGIN = 'ORIGIN';
// A pill shows the first eight and the last four characters of an id: enough to recognise, short enough to sit in a row.
const ID_HEAD_LENGTH = 8;
const ID_TAIL_LENGTH = 4;
const ID_ELLIPSIS = '…';
// The separator between a chain's name and its number, the same the controllers use. Punctuation, so not a label.
const CHAIN_LABEL_SEPARATOR = ' · ';
const CHAIN_STATUS_LABEL_BY_VALUE = {
	Running: chainStatusRunning, Completed: chainStatusCompleted, Failed: chainStatusFailed, Aborted: chainStatusAborted, Stalled: chainStatusStalled
};
const CHAIN_STATUS_FAILED = 'Failed';

/**
 * @description Shortens a tracking id for a pill: the first eight characters, an ellipsis, and the last four. An id
 * already short enough to read whole is answered unchanged, as is an empty one.
 * @param {?string} id The tracking id to shorten.
 * @returns {?string} The short form, or the id itself when there is nothing to shorten.
 */
function abbreviateId(id)
{
	return id && id.length > ID_HEAD_LENGTH + ID_TAIL_LENGTH ? `${id.slice(0, ID_HEAD_LENGTH)}${ID_ELLIPSIS}${id.slice(-ID_TAIL_LENGTH)}` : id;
}

/**
 * @description Moves an instant forwards or backwards by a number of milliseconds.
 * @param {string} instant The instant to move, as an ISO string.
 * @param {number} offsetMilliseconds How far to move it; negative moves it earlier.
 * @returns {string} The moved instant, as an ISO string.
 */
function shiftInstant(instant, offsetMilliseconds)
{
	return new Date(new Date(instant).getTime() + offsetMilliseconds).toISOString();
}

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
	catch
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
	catch
	{
		return String(value);
	}
}

export default class LogConsole extends ComponentBuilder('controller', 'notification', 'navigation')
{
	view = 'problems';
	levels = [...DEFAULT_LEVELS];
	executionEvent = '';
	origin = '';
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
	// The action the console is pinned to (the root correlation id), or null. Every request carries it; the banner
	// describes it; the drawer hides Show the whole action for it.
	actionRootCorrelationId = null;
	// What the server said about the pinned action, or null while it loads, after it failed, or with no pill.
	actionSummary = null;
	// The status line under the filters once the range was set to an action's lifetime. Stays until the reader changes the
	// range themselves, even after the pill is removed, so nobody is left on a range they did not choose without the
	// sentence that explains it.
	rangeNote = null;
	// True while the date range was set by a link or an action's lifetime around a source that is still running, and the
	// reader has not changed it since, so Refresh moves its end forward instead of leaving it where it was.
	rangeFollowsRunningSource = false;
	// The chain a pinned correlation belongs to ({name, number}) when the console knows it (a chip, or the resolver), so the
	// correlation pill reads "Chain: name · number" instead of a raw id. Null for a correlation the console cannot name.
	pinnedChain = null;
	// Why the custom range on screen is not the range being queried — inverted, or not finished. Null when
	// the range is usable. An unusable range leaves the previous window in place, so without this the
	// reader is looking at results that answer a question they have already changed.
	customRangeError = null;
	// The identity of the hand-off this console has already applied (see deepLinkIdentity). Kept after the address is
	// rewritten, so a late re-delivery of the stamped reference is still ignored; forgotten on an in-place pin.
	consumedDeepLinkKey = null;
	// The page reference most recently delivered by the wire — the page the console is hosted on right now,
	// and the base every address the console writes is rebuilt from (see handoffFreePageReference).
	latestPageReference = null;
	// The window a run hand-off arrived with ({start, end}), kept beside the chain key in the console's own address so a
	// refresh restores it from there. Null when the chain pill came without a window, or nothing is pinned.
	pinnedRunWindow = null;
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
	// A page turn is in flight: the list alone is being replaced, so the datatable carries the spinner while the rows
	// already on screen, the pager and the ribbon stay put. A whole reload uses the console's own spinner instead.
	isTurningPage = false;
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
	// Whether the viewport is at the compact width (1280 and below). Read from matchMedia when the browser has it; jsdom
	// does not, and the console then keeps the full column set.
	isCompactWidth = false;
	compactMediaQuery = null;
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
	// when there is one, is selectedDetail.id.
	selectedRowKey = null;

	// The datatable key of the selected row: a record id for an entry or a tagged problem, the delimited
	// grouping identity (see groupIdentityKey) for a grouped one. Not an entry id — the entry the drawer opened,
	// tagged, with a copyable snippet built from the wrong row — for as long as the round trip took.
	openedRow = null;
	// The row whose detail the drawer is showing — its provenance, count and span all read from here — set
	// together with the detail, never ahead of it. Distinct from selectedRowKey, which the table highlights the
	// moment a row is clicked: while the new row's detail is still in flight the drawer keeps describing the
	// previous row WHOLE. A provenance that arrived a round trip before its detail would dress the previous
	// row's detail in the new row's surfaces — hiding its record button, offering to tag a problem that is already
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
		allOrigins,
		originFilterLabel,
		originGroupLabel,
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
		detailsHeading,
		actionBannerEyebrow,
		actionBannerStarted,
		actionOpenChains,
		backToList,
		pagerPrevious,
		pagerNext,
		perPage
	};

	// reader pressed to get here, and there is nothing else the region could honestly be called.
	get listRegionLabel()
	{
		return this.isProblemsView ? this.label.viewProblems : this.label.viewEntries;
	}

	// What the list region is called when focus is moved onto it: the view it is showing. Reusing the two
	// view names rather than minting a region name of its own keeps the announcement the same words the

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

	/**
	 * @description The problems list's columns. With the drawer open at a compact width the list keeps four (the log
	 * number, the source and the context are in the drawer's header and Details), the same rule the entries list follows;
	 * the sort is state and survives the change.
	 * @returns {Array} The column definitions, in the order the list shows them.
	 */
	get problemColumns()
	{
		const columns = {
			logNumber: {
				label: colLogNumber,
				fieldName: 'logNumberDisplay',
				type: 'logNumber',
				sortable: true,
				typeAttributes: {recordUrl: {fieldName: 'recordUrl'}, isGrouped: {fieldName: 'isGrouped'}}
			},
			level: {
				label: colLevel, fieldName: 'level', type: 'logLevel', sortable: true, typeAttributes: {level: {fieldName: 'level'}}
			}, // The pill text is a constant, so it rides on the column rather than being copied onto every row.
			problem: {
				label: colProblem,
				fieldName: 'shortMessage',
				type: 'problemName',
				sortable: true,
				wrapText: true,
				typeAttributes: {isTagged: {fieldName: 'isTagged'}, taggedLabel: provenanceTagged}
			},
			source: {label: colSource, fieldName: 'sourceDisplay', type: 'writerSource', sortable: true, typeAttributes: {originLabel: {fieldName: 'writerOriginLabel'}}},
			context: {label: colContext, fieldName: 'contextDisplay', type: 'text', sortable: true},
			count: {label: colCount, fieldName: 'occurrenceCount', type: 'number', sortable: true, cellAttributes: {alignment: 'left'}},
			lastSeen: {
				label: colLastSeen,
				fieldName: 'lastSeen',
				type: 'date',
				sortable: true,
				typeAttributes: {year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit'}
			}
		};
		return this.isCompactWidth && this.hasSelection ? [
			columns.level,
			columns.problem,
			columns.count,
			columns.lastSeen
		] : [
			columns.logNumber,
			columns.level,
			columns.problem,
			columns.source,
			columns.context,
			columns.count,
			columns.lastSeen
		];
	}

	/**
	 * @description The entries list's columns. The Correlation column became Chain: a name and a number mean something to
	 * a reader where a raw id did not. Unsortable in this piece: sorting by the id would order chains by their UUIDs. With
	 * the drawer open at a compact width the list keeps four columns (the log number and the source are in the drawer's
	 * header and Details); the sort is state and survives the change.
	 * @returns {Array} The column definitions, in the order the list shows them.
	 */
	get entryColumns()
	{
		const columns = {
			logNumber: {
				label: colLogNumber,
				fieldName: 'logNumberDisplay',
				type: 'logNumber',
				sortable: true,
				typeAttributes: {recordUrl: {fieldName: 'recordUrl'}, isGrouped: {fieldName: 'isGrouped'}}
			},
			time: {
				label: colTime,
				fieldName: 'createdDate',
				type: 'date',
				sortable: true,
				typeAttributes: {year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit'}
			},
			level: {label: colLevel, fieldName: 'level', type: 'logLevel', sortable: true, typeAttributes: {level: {fieldName: 'level'}}},
			message: {label: colMessage, fieldName: 'shortMessage', type: 'text', sortable: true, wrapText: true},
			source: {label: colSource, fieldName: 'sourceDisplay', type: 'writerSource', sortable: true, typeAttributes: {originLabel: {fieldName: 'writerOriginLabel'}}},
			context: {label: colContext, fieldName: 'contextDisplay', type: 'text', sortable: true},
			chain: {label: colChain, fieldName: 'chainDisplay', type: 'text', sortable: false}
		};
		return this.isCompactWidth && this.hasSelection ? [
			columns.time,
			columns.level,
			columns.message,
			columns.chain
		] : [
			columns.logNumber,
			columns.time,
			columns.level,
			columns.message,
			columns.source,
			columns.context,
			columns.chain
		];
	}

	get contextOptions()
	{
		return [{label: this.label.allContexts, value: ''}].concat(CONTEXT_CHOICES);
	}

	get originOptions()
	{
		return [{label: this.label.allOrigins, value: ''}].concat(ORIGIN_CHOICES);
	}

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

	// The single date-range picklist: quick rolling windows, then calendar presets computed in the viewer's
	// time zone, then longer rolling windows, then a custom From/To range. Quick/rolling values are minute

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

	// The problems ribbon folds occurrences per problem: a read-only total, one clickable card per active
	// level (occurrences + distinct count), and the ranked top-source list (share of occurrences). When the
	// server folded a capped rollup window the total card carries a "totals approximate" badge, so a

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

	// The entries ribbon counts forensic rows: a read-only total, one clickable card per active level (row
	// count), and the ranked top-source list (row count). When the server declined the breakdown (the range
	// held more rows than the ribbon may scan) only the total renders: the pre-flight count that declined the
	// scan measured it exactly, while a zero on every level card would be false — those rows exist, they are

	// vocabulary (totalsApproximate and the grouping status bar), so this never reads a problems summary.
	get entrySummaryDeclined()
	{
		return !this.isProblemsView && this.summary?.declined === true;
	}

	// Only the entries ribbon can be declined: its per-level and per-source breakdown scans the window, and the
	// server withholds that scan over a range too large for it. The problems ribbon degrades through its own

	// Under an action the remedy names the chips and a shorter range.
	get cappedText()
	{
		return (this.actionRootCorrelationId ? cappedBannerAction : cappedBanner).replace('{0}', countText(this.totalCount));
	}

	// Grouped the same way the ribbon's own number beside it is grouped: the banner used to print a bare
	// 3985 next to a formatted 3,985 and leave the reader to work out that the two were the same count.

	// interpolated with a number that is not one. Absent when nothing is pinned, the count never arrived, or the list read failed.
	get occurrencesReconciliation()
	{
		const counted = this.sourceFilter?.occurrenceCount;
		if(this.isProblemsView || this.listLoadFailed || !(counted > 0))
		{
			return null;
		}
		return occurrencesReconciliation.replace('{0}', countText(counted)).replace('{1}', countText(this.totalCount));
	}

	// Says how a drilled problem's occurrence count and the entries listed under it relate. The two numbers
	// are counted over different things — the problem was counted every time it happened, while the list
	// holds the entries still on file from that source and level — so the sentence relates them rather than
	// claiming one is a subset of the other, and either number can be the larger one.
	//
	// The ENTRIES view only. The pin itself spans both views, like the correlation pill, but in the problems
	// view {1} is a count of problems rather than of entries, and this sentence about entries would then be
	// something false. The status bar and the empty state between them already say what happened.

	/**
	 * @description The removable pill text for a pinned writer, whether a ranked source drilled from the Top
	 * sources card or a problem drilled to its own entries, so the drill is a visible, clearable filter rather
	 * than an invisible one. A problem drilled from the list names the writer the way its rows' Source cells
	 * name it, and falls back to the class and method only for a problem that stored no writer.
	 * @returns {string}
	 */
	get sourceFilterPillLabel()
	{
		return `${colSource}: ${this.sourceFilter?.source ?? this.sourceFilter?.label ?? this.sourceFilter?.classMethod}`;
	}

	get showCappedBanner()
	{
		return this.capped && !this.isEmpty;
	}

	// Only over a list that has rows to be the first of. The problems page reports capped whenever the rollup
	// scan degraded — including a wide window where the rollup leg threw AND the derived leg declined — and
	// that combination leaves an empty list. "Showing the first 0. Narrow the filters to see the rest." over an
	// empty state, under a status bar already explaining the decline, would be a second amber surface saying

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

	// The grouping status bar, or null when there is nothing to say: the entries view, where grouping does

	// entries view plainly lists their rows. Suppressed while a bar is up, which is already explaining.
	get scopeCaption()
	{
		const covering = this.isProblemsView && this.derivedStatus === GROUPING_STATUS_COMPLETE && this.derivedLevelScope.length > 0;
		return covering ? groupingScopeCaption.replace('{0}', this.groupedLevelText) : null;
	}

	// States permanently and quietly what this tab covers. It is the only thing that explains a PARTIAL
	// level mismatch: viewing a level inside the configured scope alongside one outside it leaves the
	// status COMPLETE, fires no bar, and the problems at the outside level simply never appear while the

	get groupedLevelText()
	{
		return levelListText(this.derivedLevelScope);
	}

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

	// An empty list has to say which kind of empty it is, and the cases are genuinely different. A read
	// that FAILED comes first and overrides every other sentence here: none of them are true of a list
	// that was never retrieved, and the shipped no-match copy is the worst of them — it hands the reader
	// their own filters to fix while the ribbon behind it still counts every entry in the window.
	// Past that, the page did arrive and was empty: COMPLETE earns the claim that nothing repeats, because
	// the fold ran; a reported skip earns the pointer to the bar above; a NULL status earns neither, and

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

	// can tell the two states apart by more than the sentence inside them.
	get emptyTestId()
	{
		return this.listLoadFailed ? 'list-load-failed' : 'empty-state';
	}

	// The failed read gets its own test id as well as its own copy, so a test — and the release harness —

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

	// — both kinds open on the same DTO — so the row is the only source.
	get selectedProvenance()
	{
		return this.openedRow?.source ?? null;
	}

	// Everything the drawer is told about the row it is showing reads from openedRow, so it changes as one with
	// the detail. Whether the open row was tagged in code or grouped at read time cannot be read off the detail

	get selectedOccurrenceCount()
	{
		return this.openedRow?.occurrenceCount ?? null;
	}

	// entries were all purged has none. Null in the entries view, where the entry's own time is the truth.
	get selectedFirstSeen()
	{
		return this.isProblemsView ? this.openedRow?.firstSeen ?? null : null;
	}

	// The problem's whole span, from the row: the drawer's detail is one entry — for a grouped problem the most
	// recent occurrence — so its own timestamps cannot say when the problem was FIRST seen, and a group whose

	get selectedLastSeen()
	{
		return this.isProblemsView ? this.openedRow?.lastSeen ?? null : null;
	}

	/**
	 * @description The removable pill text for a pinned correlation: the chain's name and number when the console knows the
	 * chain, the raw id otherwise, so a deep-linked or pasted correlation is visible and clearable rather than an invisible
	 * filter.
	 * @returns {string}
	 */
	get correlationPillLabel()
	{
		return this.pinnedChain ? chainPill.replace('{0}', this.pinnedChain.name).replace('{1}', this.pinnedChain.number) : `${colCorrelation}: ${this.correlationId}`;
	}

	get actionPillLabel()
	{
		return actionPill.replace('{0}', abbreviateId(this.actionRootCorrelationId));
	}

	get showActionBanner()
	{
		return Boolean(this.actionRootCorrelationId) && Boolean(this.actionSummary);
	}

	// built, so no label carries a date placeholder and the viewer's own zone applies.
	get actionBannerStartedAt()
	{
		return this.actionSummary.startedAt;
	}

	// The banner's sentence is composed from label fragments around a formatted date, the way the drawer's Logged line is

	get actionBannerIsLegacy()
	{
		return this.actionSummary.recordedBeforeRoots === true;
	}

	get actionBannerDurationText()
	{
		const fragment = this.actionSummary.stillRunning ? actionBannerStillRunning : actionBannerRanFor;
		return fragment.replace('{0}', this.actionSummary.durationLabel ?? '');
	}

	get actionBannerChainsText()
	{
		const chainCount = this.actionSummary.chainCount ?? 0;
		return chainCount > 0 ? actionBannerChains.replace('{0}', countText(chainCount)).replace('{1}', countText(this.actionSummary.failedCount ?? 0)) : actionBannerNoChains;
	}

	get actionBannerLegacyText()
	{
		return actionBannerLegacy;
	}

	// Failed first, then the rest by start time, as the server ordered them; each says how its run entered the action.
	get actionChips()
	{
		return (this.actionSummary.chains ?? []).map((chain) => ({
			key: chain.executionId,
			correlationId: chain.correlationId,
			chainName: chain.chainName,
			chainNumber: chain.chainNumber,
			label: `${chain.chainName}${CHAIN_LABEL_SEPARATOR}${chain.chainNumber}`,
			statusLabel: CHAIN_STATUS_LABEL_BY_VALUE[chain.status] ?? chain.status,
			launchText: this.chipLaunchText(chain),
			chipClass: chain.status === CHAIN_STATUS_FAILED ? 'action-chip action-chip_failed' : 'action-chip'
		}));
	}

	get actionMoreChainsText()
	{
		const more = this.actionSummary.moreChainCount ?? 0;
		return more > 0 ? actionMoreChains.replace('{0}', countText(more)) : null;
	}

	// Hidden for an action that ran no chains and for a legacy action: the monitor lists by root, and a legacy action has none.
	get showOpenChainsButton()
	{
		return !this.actionBannerIsLegacy && (this.actionSummary.chainCount ?? 0) > 0;
	}

	/**
	 * @description Whether the pager belongs under the list. The template renders it beside the rows, and a page turn
	 * replaces the rows alone, so the pager and its position line stay on screen and hold the reader's place while the
	 * next page loads. Read from the total, so an empty list and a failed read carry no pager.
	 * @returns {boolean} Whether there is anything to page through.
	 */
	get showPager()
	{
		return this.totalCount > 0;
	}

	/**
	 * @description Where in the list the reader is: the first and last row of the page on screen, and the total, each
	 * grouped the way the reader's own language groups a number.
	 * @returns {string} The position line.
	 */
	get positionText()
	{
		const first = (this.pageNumber - 1) * this.pageSize + 1;
		const last = first + this.records.length - 1;
		return entriesPosition.replace('{0}', countText(first)).replace('{1}', countText(last)).replace('{2}', countText(this.totalCount));
	}

	/**
	 * @description The numbered page buttons. Page numbers only while they can be used; past MAX_NUMBERED_PAGES the
	 * position line, Previous and Next are the pager.
	 * @returns {Array} One entry per page: its number, its label, its button variant and its aria-current value.
	 */
	get pageNumbers()
	{
		if(this.totalPages > MAX_NUMBERED_PAGES)
		{
			return [];
		}
		return Array.from({length: this.totalPages}, (unused, index) => index + 1).map((number) => ({
			number, label: String(number), variant: number === this.pageNumber ? 'brand' : 'neutral', current: number === this.pageNumber ? 'page' : null
		}));
	}

	/**
	 * @description Whether there is no page before this one, which is what disables Previous.
	 * @returns {boolean} Whether the first page is on screen.
	 */
	get noPrevious()
	{
		return this.pageNumber <= 1;
	}

	// One card per ACTIVE level, in the canonical severity order and regardless of what the rollup returned: a level the
	// window holds nothing for keeps its card at zero rather than vanishing, so the ribbon's locked invariant — Total

	/**
	 * @description Whether there is no page after this one, which is what disables Next.
	 * @returns {boolean} Whether the last page is on screen.
	 */
	get noNext()
	{
		return !this.hasMorePages;
	}

	// The footnote under a problems level card: how many distinct problems it counts, and — when problem
	// grouping did not cover that level on this load — that the count is of tagged problems alone. Without
	// it a level the fold never looked at reads as a level with nothing wrong in it, which on a busy org is

	/**
	 * @description The page sizes the reader can choose between, each worded as a count and the words for what it counts.
	 * @returns {Array} The combobox options.
	 */
	get pageSizeOptions()
	{
		return PAGE_SIZE_OPTIONS.map((size) => ({label: formatTemplateString(this.label.perPage, [size]), value: String(size)}));
	}

	// Whether problem grouping contributed to a level's numbers on this load: only when the fold ran whole
	// AND the level sits inside the scope it is configured for. A search term, a switched-off setting, a
	// window too large to fold and a level outside the configured scope all leave the numbers counting the

	/**
	 * @description The chosen page size as the combobox holds it, which is a string.
	 * @returns {string} The current page size.
	 */
	get pageSizeValue()
	{
		return String(this.pageSize);
	}

	// The unit word for a row count, agreeing with the number in front of it: one row, two rows. Two
	// labels rather than string surgery on one, because the two forms are not the same word in every

	/**
	 * @description Follows the viewport across the compact width, so the column set changes with it. A field rather than
	 * a method, so the listener removed on disconnect is the same function that was added.
	 * @param {Object} event The media query's own change event, carrying whether the query matches now.
	 */
	handleCompactWidthChange = (event) =>
	{
		this.isCompactWidth = event.matches;
	};

	// A clickable per-level card. Clicking it filters the list to that single level, so the total always equals the sum

	/**
	 * @description The words for how a chip's run entered the action; nothing for the action's own launch.
	 * @param {Object} chain One chain of the pinned action's summary.
	 * @returns {?string} The words, or null when the run launched the action itself.
	 */
	chipLaunchText(chain)
	{
		if(chain.launchKind === LAUNCH_KIND_CHAIN)
		{
			return actionChipLaunchedBy.replace('{0}', chain.launcherName ?? '');
		}
		if(chain.launchKind === LAUNCH_KIND_RESTART)
		{
			return chainRestartOf.replace('{0}', chain.launcherName ?? '');
		}
		return chain.launchKind === LAUNCH_KIND_ORIGIN ? chainStartedThisAction : null;
	}

	// The ranked top-source card: up to three sources, each a click-to-drill row. Problems show each source's share of

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

	// always equals the sum of the level cards on screen — survives an empty level.
	activeLevelCards(buildCard)
	{
		const rollupByLevel = new Map((this.summary.perLevel ?? []).map((entry) => [
			entry.level,
			entry
		]));
		return ALL_LEVELS.filter((level) => this.levels.includes(level)).map((level) => buildCard(level, rollupByLevel.get(level) ?? {}));
	}

	// a zero beside tens of thousands of rows the entries view lists happily.
	problemLevelFootnote(level, entry)
	{
		const distinct = `${entry.distinctCount ?? 0} ${this.label.distinctSuffix}`;
		return this.isGroupedLevel(level) ? distinct : `${distinct} ${taggedOnlySuffix}`;
	}

	// problems a developer tagged in code and nothing else.
	isGroupedLevel(level)
	{
		return this.derivedStatus === GROUPING_STATUS_COMPLETE && this.derivedLevelScope.includes(level);
	}

	// language and a translator has to be given both.
	rowsWord(count)
	{
		return count === 1 ? rowSuffixSingular : this.label.rowsSuffix;
	}

	// A deep link that carries the source record's own bounds pins the console to exactly that
	// window (an absent upper bound means the source is still running, so the window runs to now),
	// and the custom From/To inputs are seeded from the same instants so the range on screen is the
	// range being queried. A link with no bounds falls back to the widest rolling preset, which is

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

	// occurrences; entries show its row count.
	topSourcesCard(isProblems)
	{
		const sources = (this.summary.topSources ?? []).map((source, index) => ({
			key: `${source.origin}|${source.name}`,
			name: source.name,
			origin: source.origin,
			originLabel: ORIGIN_LABEL_BY_VALUE[source.origin] ?? source.origin,
			rank: index + 1,
			metric: isProblems ? `${source.percent}%` : `${source.count} ${this.rowsWord(source.count)}`
		}));
		return {key: 'sources', isSources: true, label: this.label.topSourcesLabel, sources, hasSources: sources.length > 0};
	}

	@wire(CurrentPageReference) captureDeepLink(pageReference)
	{
		// Remembered on every delivery: this is what the console is CURRENTLY hosted on, and the reference every address
		// the console writes is rebuilt from (see handoffFreePageReference). An empty delivery says nothing about the
		// pins and is not an address: it is ignored, so the console neither forgets its host nor drops a pin on its account.
		if(!pageReference)
		{
			return;
		}
		this.latestPageReference = pageReference;
		const state = pageReference.state ?? {};
		if(state.c__viewLogsAt)
		{
			this.applyHandoff(state);
			return;
		}
		// noinspection JSIgnoredPromiseFromCall
		this.mirrorAddress(state);
	}

	/**
	 * @description Applies a hand-off from the Chain Monitor once per distinct link, then rewrites the address without the
	 * stamp, so the pin lives on as the console's own state and the plain address governs it from there: a refresh restores
	 * it from the address, Back goes to the monitor, a second click carries a new stamp and applies again. The pin's state
	 * is set before the rewrite is issued: a live re-delivery of the plain address then finds nothing to change, and a
	 * remount on the rewrite reads the same pin back from the address.
	 * @param {Object} state The delivered page state, carrying c__viewLogsAt.
	 */
	applyHandoff(state)
	{
		const identity = deepLinkIdentity(state);
		if(identity === this.consumedDeepLinkKey || !(state.c__rootCorrelationId || state.c__correlationId))
		{
			return;
		}
		this.consumedDeepLinkKey = identity;
		if(state.c__rootCorrelationId)
		{
			// noinspection JSIgnoredPromiseFromCall
			this.openAction(state.c__rootCorrelationId);
		}
		else
		{
			// noinspection JSIgnoredPromiseFromCall
			this.pinRun(state.c__correlationId, state.c__windowStart, state.c__windowEnd);
		}
		this.writeAddress(this.addressOfPins(), true);
	}

	/**
	 * @description Makes the pins match a plain address: an action key alone pins that action whole, an action key beside
	 * a chain key pins the action narrowed to that chain, a chain key alone pins that run with the window beside it, and no
	 * key unpins everything. Only what differs changes, so the console's own push of the address it already shows changes
	 * nothing, and neither does the wire re-delivering the tab's address on a return to it.
	 * @param {Object} state The delivered page state, without c__viewLogsAt.
	 * @returns {Promise<void>} Resolves once the pins match the address.
	 */
	async mirrorAddress(state)
	{
		const action = state.c__rootCorrelationId || null;
		const chain = state.c__correlationId || null;
		if(action)
		{
			if(action !== this.actionRootCorrelationId)
			{
				await this.openAction(action, chain);
			}
			else if(chain !== this.correlationId)
			{
				await this.narrowPinnedAction(chain);
			}
			return;
		}
		if(chain)
		{
			// The window is part of what the address records about a run, so a delivery of the same chain key with a
			// different window is a different pin: Back and Forward between two hand-offs of one run land on the window
			// each of them carried. A key that is absent, and a key that is there but empty, both read as no window at
			// all, the same way the action and chain keys above read, and that is what the pin is given.
			const windowStart = state.c__windowStart || null;
			const windowEnd = state.c__windowEnd || null;
			const windowDiffers = windowStart !== (this.pinnedRunWindow?.start ?? null) || windowEnd !== (this.pinnedRunWindow?.end ?? null);
			if(chain !== this.correlationId || this.actionRootCorrelationId || windowDiffers)
			{
				await this.pinRun(chain, windowStart, windowEnd);
			}
			return;
		}
		if(this.actionRootCorrelationId)
		{
			this.unpinAction();
		}
		else if(this.correlationId)
		{
			this.unpinRun();
		}
	}

	/**
	 * @description Pins an action: the console lists the action's own entries beside the entries of every chain run launched
	 * under it. The view switches to Individual entries, ERROR, WARN and INFO come on (DEBUG stays as it was), the sort is
	 * oldest first, the page returns to one, every other pill and the search term are cleared, and the date range becomes
	 * the action's lifetime once the summary has said what that is. The summary is fetched before the list so the list's
	 * first load already runs on the action's range. A chain to narrow to may come with it, from an address that carries
	 * both keys; the chain is named once the summary's chips are known.
	 * @param {string} rootCorrelationId The action's tracking id.
	 * @param {string|null} narrowTo The chain's correlation id to narrow to at once, or null for the whole action.
	 */
	async openAction(rootCorrelationId, narrowTo = null)
	{
		this.hasIssuedInitialLoad = true;
		// The console is busy from here, and every load still in flight is retired before the summary is awaited: a page
		// turn answering during that await would otherwise paint the old list's rows under the new action. The reload
		// below takes a sequence of its own and clears the spinner when it lands.
		this.isLoading = true;
		this.requestSequence++;
		window.clearTimeout(this.searchDebounceTimer);
		this.actionRootCorrelationId = rootCorrelationId;
		this.actionSummary = null;
		// The chain to narrow to is part of the pin, so it is set here rather than after the summary: a delivery that
		// arrives while the summary is in flight then reads the pin the address asked for, and what it decides to change
		// is not undone by this summary landing afterwards.
		this.correlationId = narrowTo;
		this.pinnedChain = null;
		this.pinnedRunWindow = null;
		this.rangeFollowsRunningSource = false;
		this.sourceFilter = null;
		this.searchTerm = '';
		this.executionEvent = '';
		this.origin = '';
		this.customRangeError = null;
		this.view = 'entries';
		this.sortField = ENTRY_SORT_FIELD;
		this.sortedByColumn = ENTRY_SORT_FIELD;
		this.sortAscending = true;
		this.levels = this.levels.includes('DEBUG') ? [
			...ACTION_OPENING_LEVELS,
			'DEBUG'
		] : [...ACTION_OPENING_LEVELS];
		this.pageNumber = 1;
		await this.loadActionSummary();
		if(narrowTo && this.actionRootCorrelationId === rootCorrelationId && this.correlationId === narrowTo)
		{
			const name = await this.nameChain(narrowTo);
			// Checked again after the naming read: a name that arrives for a chain the reader has already left behind
			// would put the wrong chain's words on the pill beside the right chain's rows.
			if(this.actionRootCorrelationId === rootCorrelationId && this.correlationId === narrowTo)
			{
				this.pinnedChain = name;
			}
		}
		if(this.actionRootCorrelationId === rootCorrelationId)
		{
			await this.reload();
		}
	}

	/**
	 * @description Narrows the pinned action to one chain, or widens it back to the whole action, as the address says. A
	 * name that arrives after the reader has moved to another chain, or to another action, is dropped, and so is the
	 * reload it would have run.
	 * @param {string|null} chain The chain's correlation id, or null for the whole action.
	 * @returns {Promise<void>} Resolves once the list matches.
	 */
	async narrowPinnedAction(chain)
	{
		const action = this.actionRootCorrelationId;
		this.correlationId = chain;
		this.pinnedRunWindow = null;
		this.pinnedChain = null;
		if(chain)
		{
			const name = await this.nameChain(chain);
			// The action is checked beside the chain: an answer that lands once another action is pinned, even one
			// narrowed to this same chain, belongs to neither that action's pill nor the list it is loading.
			if(this.correlationId !== chain || this.actionRootCorrelationId !== action)
			{
				return;
			}
			this.pinnedChain = name;
		}
		await this.resetAndReload();
	}

	/**
	 * @description Pins one run as the chain pill, the way the Chain Monitor's View logs has always arrived: any pinned
	 * action is dropped, the list lands on Individual entries with every level on, the window is drawn around the run
	 * when the address carries one, and every other filter is cleared, because a term left over from the console's
	 * previous use would silently hide the very rows the link was followed to see. The pill is named through the resolver
	 * when the console does not know the chain, while the list is already loading rather than after the name arrives, and
	 * a name that arrives after another link has been followed is dropped.
	 * @param {string} correlationId The run's correlation id.
	 * @param {string|null|undefined} windowStart The window's start, when the address carries one.
	 * @param {string|null|undefined} windowEnd The window's end, when the address carries one.
	 * @param {Object|null} knownChain The chain's name and number when the caller already has them, which saves the
	 * naming read; null when the pill has to be named here.
	 * @returns {Promise<void>} Resolves once the list matches.
	 */
	async pinRun(correlationId, windowStart, windowEnd, knownChain = null)
	{
		this.hasIssuedInitialLoad = true;
		this.actionRootCorrelationId = null;
		this.actionSummary = null;
		this.rangeNote = null;
		this.pinnedChain = null;
		this.correlationId = correlationId;
		this.pinnedRunWindow = windowStart ? {start: windowStart, end: windowEnd ?? null} : null;
		this.view = 'entries';
		this.sortField = ENTRY_SORT_FIELD;
		this.sortedByColumn = ENTRY_SORT_FIELD;
		this.sortAscending = false;
		this.levels = [...ALL_LEVELS];
		this.searchTerm = '';
		this.executionEvent = '';
		this.origin = '';
		this.sourceFilter = null;
		this.customRangeError = null;
		this.applyDeepLinkRange(windowStart, windowEnd);
		// The rows are asked for at once, alongside the naming read rather than after it: the name only chooses the
		// words on the pill, so waiting for it would show the reader "no logs match these filters" where the spinner
		// belongs and cost them a whole round trip before the first row. The reload marks the console busy and takes a
		// request sequence of its own as it starts, so a load already in flight is retired here too. A name the caller
		// already holds (the search resolver's own answer about the id just pasted) is taken instead of read again,
		// and it still goes through the guard below, so one code path words the pill however the name was come by.
		const naming = knownChain ? Promise.resolve(knownChain) : this.nameChain(correlationId);
		const loading = this.resetAndReload();
		const name = await naming;
		// A name for a run the reader has already left behind is dropped: a slower answer for an earlier link would
		// otherwise word the pill after one chain over the rows of another.
		if(this.correlationId === correlationId)
		{
			this.pinnedChain = name;
		}
		await loading;
	}

	/**
	 * @description Unpins the action and any chain it was narrowed to, putting back what opening it changed: the levels
	 * and the sort return to their defaults; the range stays as it is, and its note stays until the reader changes the range
	 * themselves, so nobody is left on a range they did not choose with nothing to explain it.
	 */
	unpinAction()
	{
		this.actionRootCorrelationId = null;
		this.actionSummary = null;
		this.correlationId = null;
		this.pinnedChain = null;
		this.pinnedRunWindow = null;
		this.rangeFollowsRunningSource = false;
		this.restoreActionDefaults();
		// noinspection JSIgnoredPromiseFromCall
		this.resetAndReload();
	}

	/**
	 * @description Unpins the chain pill, whether it narrowed an action or stood on its own; a pinned action stays, and so
	 * does a range that follows it while it runs.
	 */
	unpinRun()
	{
		this.correlationId = null;
		this.pinnedChain = null;
		this.pinnedRunWindow = null;
		this.rangeFollowsRunningSource = this.rangeFollowsRunningSource && Boolean(this.actionRootCorrelationId);
		// noinspection JSIgnoredPromiseFromCall
		this.resetAndReload();
	}

	/**
	 * @description Names a chain for its pill: from the banner's chips when the pinned action lists it, otherwise through
	 * the search resolver, one read. Null when no run holds the id, and the pill then shows the raw id.
	 * @param {string} correlationId The run's correlation id.
	 * @returns {Promise<Object|null>} The chain's name and number, or null.
	 */
	async nameChain(correlationId)
	{
		const chip = (this.actionSummary?.chains ?? []).find((chain) => chain.correlationId === correlationId);
		if(chip)
		{
			return {name: chip.chainName, number: chip.chainNumber};
		}
		const resolved = await this.callControllerMethod(resolveSearchId, {term: correlationId}, SILENT_READ);
		return resolved?.kind === RESOLVED_CHAIN ? {name: resolved.chainName, number: resolved.chainNumber} : null;
	}

	/**
	 * @description Reads the pinned action's summary and sets the range from it, which is what opening an action does. A
	 * summary that fails or finds no entries leaves the widest rolling preset in place, so the pill still filters something
	 * visible.
	 */
	async loadActionSummary()
	{
		if(await this.refreshActionSummary())
		{
			this.applyActionLifetimeRange();
		}
	}

	/**
	 * @description Re-reads the pinned action's summary so the banner tells the story as it stands now, and touches nothing
	 * else. A range the reader set themselves stays theirs, so this never pulls them back to the action's lifetime or
	 * brings back the note; a range that still follows the running action is moved by the refresh itself, from the answer
	 * read here.
	 * @returns {Promise<boolean>} Whether the answer was still about the pinned action by the time it arrived; an answer
	 * about an action the reader has already left is dropped.
	 */
	async refreshActionSummary()
	{
		const rootCorrelationId = this.actionRootCorrelationId;
		const data = await this.callControllerMethod(getActionSummary, {requestJson: JSON.stringify({rootCorrelationId})}, SILENT_READ);
		if(rootCorrelationId !== this.actionRootCorrelationId)
		{
			return false;
		}
		this.actionSummary = data || null;
		return true;
	}

	/**
	 * @description Sets the date range to the action's lifetime: its first entry to its last, a minute either side, ending
	 * now while the action is still running, with the note that explains it. The note stays until the reader changes the
	 * range themselves. Without a summary the widest rolling preset stands in and there is no note to show.
	 */
	applyActionLifetimeRange()
	{
		if(!this.actionSummary?.startedAt)
		{
			this.applyDeepLinkRange(null, null);
			this.rangeNote = null;
			return;
		}
		const stillOpen = this.actionSummary.stillRunning || !this.actionSummary.endedAt;
		const end = stillOpen ? new Date().toISOString() : shiftInstant(this.actionSummary.endedAt, ACTION_RANGE_MARGIN_MILLISECONDS);
		this.applyDeepLinkRange(shiftInstant(this.actionSummary.startedAt, -ACTION_RANGE_MARGIN_MILLISECONDS), end);
		this.rangeFollowsRunningSource = stillOpen;
		this.rangeNote = actionRangeNote;
	}

	// wide enough that an older correlation is still inside the window.
	applyDeepLinkRange(windowStart, windowEnd)
	{
		if(!windowStart)
		{
			this.rangePreset = WIDEST_RANGE_PRESET;
			this.windowMinutes = WINDOW_MINUTES_BY_PRESET[WIDEST_RANGE_PRESET];
			this.customStart = null;
			this.customEnd = null;
			this.rangeFollowsRunningSource = false;
			return;
		}
		this.rangePreset = CUSTOM_RANGE_PRESET;
		this.rangeFollowsRunningSource = !windowEnd;
		this.customStart = windowStart;
		this.customEnd = windowEnd || new Date().toISOString();
		this.seedCustomRangeInputs(new Date(this.customStart), new Date(this.customEnd));
	}

	// ---- pages -------------------------------------------------------------------------------------------------

	handleRemoveCorrelation()
	{
		// The pill was on screen to be closed, so something was pinned: the address is rewritten whether or not the
		// platform has delivered the pin's own address back to the console.
		this.unpinRun();
		this.replaceAddress(true);
	}

	/**
	 * @description Unpins the action: the levels and the sort go back to what they are by default, and the range stays as
	 * it is, exactly as removing the correlation pill behaves. The range note stays too, until the reader changes the range
	 * themselves (see rangeNote), so nobody is left on a range they did not choose with nothing to explain it. The sort
	 * returns to the sort of the view being looked at: the pill spans both views, and the entries' sort key means nothing
	 * to the problems list.
	 */
	handleRemoveAction()
	{
		// As with the chain pill: the action pill was there to be closed, so the address is rewritten on its own word.
		this.unpinAction();
		this.replaceAddress(true);
	}

	/**
	 * @description Puts back what opening an action changed on the reader's behalf: the severities it switched on and the
	 * oldest-first sort it set. The sort returns to the sort of the view being looked at, because the entries' sort key
	 * means nothing to the problems list. Both ways of leaving an action, the pill and Clear all, go through here.
	 */
	restoreActionDefaults()
	{
		this.levels = [...DEFAULT_LEVELS];
		this.sortField = this.isProblemsView ? PROBLEM_SORT_FIELD : ENTRY_SORT_FIELD;
		this.sortedByColumn = this.sortField;
		this.sortAscending = false;
	}

	/**
	 * @description Narrows the list to the one chain a banner chip names, as the shipped correlation pill worded with the
	 * chain's name and number.
	 * @param {Event} event The chip's click, carrying the run's correlation id on the button.
	 */
	handleChainChipSelect(event)
	{
		const chip = this.actionChips.find((candidate) => candidate.correlationId === event.currentTarget.dataset.correlationId);
		if(chip)
		{
			this.pinChain({id: chip.correlationId, chainName: chip.chainName, chainNumber: chip.chainNumber});
			this.pushAddress();
		}
	}

	/**
	 * @description Pins one chain run as the correlation filter, worded as the chain pill.
	 * @param {Object} chain The run to pin: its id, and the chain's name and number.
	 */
	pinChain(chain)
	{
		this.correlationId = chain.id;
		this.pinnedChain = {name: chain.chainName, number: chain.chainNumber};
		this.pinnedRunWindow = null;
		// noinspection JSIgnoredPromiseFromCall
		this.resetAndReload();
	}

	/**
	 * @description Opens the pinned action's chains in the Chain Monitor, carrying the action and a click stamp and nothing
	 * else: no window keys, because View logs' window is drawn around one run and would clip the action. The stamp is what
	 * makes a second click a new hand-off rather than a repeat the monitor ignores.
	 */
	handleOpenChains()
	{
		const state = {c__rootCorrelationId: this.actionRootCorrelationId, c__viewLogsAt: String(Date.now())};
		this.navigate({type: 'standard__navItemPage', attributes: {apiName: 'ChainMonitor'}, state});
	}

	/**
	 * @description Pins the action the drawer asked to see whole, the same way a deep link or a pasted id pins one. The pin
	 * is then written into the address as a new history entry, so Back undoes it.
	 * @param {CustomEvent} event The `showwholeaction` event carrying the action's tracking id.
	 */
	handleShowWholeAction(event)
	{
		// noinspection JSIgnoredPromiseFromCall
		this.openAction(event.detail.rootCorrelationId);
		this.pushAddress();
	}

	/**
	 * @description Turns the list to a page: the rows are replaced and nothing else on screen is. The list alone, never
	 * a whole reload: the ribbon counts the window rather than the page, so re-reading it per turn would buy the reader
	 * the same numbers at the price of a second query, and taking the pager away while it loaded would lose them their
	 * place. The datatable carries the spinner meanwhile. The page number travels on the request rather than being taken
	 * up front: the page on screen is still the page before, so the position line and the buttons keep describing it
	 * until the new page lands and the answer moves them. The current request token travels with the load too, so a
	 * filter change made mid-turn still wins.
	 * @param {number} pageNumber The page to turn to.
	 * @returns {Promise<void>} Resolves once that page is on screen.
	 */
	async turnPage(pageNumber)
	{
		this.isTurningPage = true;
		await this.loadList({...this.buildRequest(), pageNumber}, this.requestSequence);
		this.isTurningPage = false;
	}

	/**
	 * @description Goes back one page. Guarded as well as disabled, so a click that reaches the handler anyway cannot
	 * walk off the front of the list.
	 * @returns {Promise<void>} Resolves once the page before this one is on screen.
	 */
	async handlePreviousPage()
	{
		if(!this.noPrevious)
		{
			await this.turnPage(this.pageNumber - 1);
		}
	}

	/**
	 * @description Goes on one page, guarded the same way Previous is, so the console never asks for a page past the end.
	 * @returns {Promise<void>} Resolves once the next page is on screen.
	 */
	async handleNextPage()
	{
		if(!this.noNext)
		{
			await this.turnPage(this.pageNumber + 1);
		}
	}

	/**
	 * @description Goes to the page a numbered button names. The page already on screen is not fetched again: its button
	 * is the one marked as current, and clicking where you already are should cost nothing.
	 * @param {Event} event The button's click, carrying the page number on the button.
	 * @returns {Promise<void>} Resolves once that page is on screen.
	 */
	async handlePageNumber(event)
	{
		const pageNumber = Number(event.currentTarget.dataset.page);
		if(pageNumber !== this.pageNumber)
		{
			await this.turnPage(pageNumber);
		}
	}

	/**
	 * @description Changes how many rows a page holds, which starts the list again at page one: the page the reader was
	 * on holds different rows at a different size, so keeping the number would land them somewhere they never chose.
	 * @param {CustomEvent} event The combobox's change event, carrying the chosen size.
	 * @returns {Promise<void>} Resolves once the first page of the new size is on screen.
	 */
	async handlePageSizeChange(event)
	{
		this.pageSize = Number(event.detail.value);
		await this.resetAndReload();
	}

	/**
	 * @description The console's own address keys for what is pinned now: the action, the chain it is narrowed to or the
	 * run pinned on its own, and the window a run hand-off arrived with. Never the stamp.
	 * @returns {Object} The keys to write, only those that are set.
	 */
	addressOfPins()
	{
		const keys = {};
		if(this.actionRootCorrelationId)
		{
			keys.c__rootCorrelationId = this.actionRootCorrelationId;
		}
		if(this.correlationId)
		{
			keys.c__correlationId = this.correlationId;
			if(this.pinnedRunWindow?.start)
			{
				keys.c__windowStart = this.pinnedRunWindow.start;
				if(this.pinnedRunWindow.end)
				{
					keys.c__windowEnd = this.pinnedRunWindow.end;
				}
			}
		}
		return keys;
	}

	/**
	 * @description Whether the address the console sits on carries any of its own keys.
	 * @returns {boolean}
	 */
	addressCarriesPins()
	{
		const state = this.latestPageReference?.state ?? {};
		return HANDOFF_STATE_KEYS.some((key) => state[key]);
	}

	/**
	 * @description Whether the address the console sits on already records exactly these pins: every pin key the same,
	 * with the same value. A key that is absent and a key that is there but empty read alike, as they do everywhere
	 * else in the model.
	 * @param {Object} keys The keys a push would write, from addressOfPins.
	 * @returns {boolean} Whether writing them would say nothing new.
	 */
	addressAlreadyRecords(keys)
	{
		const state = this.latestPageReference?.state ?? {};
		return PIN_STATE_KEYS.every((key) => (state[key] || null) === (keys[key] || null));
	}

	/**
	 * @description Writes the console's address: the page it is hosted on with every other key the host carries, the
	 * console's own keys replaced by the ones given. A push makes a history entry Back can pop; a replace rewrites the
	 * entry in place. Guarded, because the address is a record of what the reader already sees: a navigation service that
	 * refuses must not take the pin down with it.
	 * @param {Object} keys The console's keys to carry, from addressOfPins.
	 * @param {boolean} replace Whether to rewrite the current entry rather than add one.
	 */
	writeAddress(keys, replace)
	{
		const reference = this.handoffFreePageReference();
		const target = Object.keys(keys).length ? {...reference, state: {...(reference.state ?? {}), ...keys}} : reference;
		try
		{
			this.navigate(target, replace);
		}
		catch(navigationFailure)
		{
			this.consoleError(navigationFailure, 'writeAddress: ');
		}
	}

	/**
	 * @description Records an in-place pin or narrowing as a new history entry, so Back undoes it. The consumed hand-off
	 * identity is forgotten with it: the pin the reader just made is the console's own, and Back onto the link that
	 * brought them here should apply it again. Pinning what the address already records writes nothing: the platform
	 * does not coalesce an identical address, so re-clicking a chip or re-pasting an id that is pinned already would
	 * buy the reader a history entry whose Back appears to do nothing.
	 */
	pushAddress()
	{
		this.consumedDeepLinkKey = null;
		const keys = this.addressOfPins();
		if(this.addressAlreadyRecords(keys))
		{
			return;
		}
		this.writeAddress(keys, false);
	}

	/**
	 * @description Rewrites the address in place with what stays pinned after a clear, never a new entry: the cleared
	 * console is the same stop in the reader's journey. The rewrite runs when something was pinned at the moment of the
	 * clear, or when the address itself still carries one of the console's keys. A pin the reader made in place is in
	 * the address whether or not the platform has handed that address back to the console, so asking the address alone
	 * would leave the key behind and a refresh would bring back what the reader just cleared. A console with nothing
	 * pinned and no key in its address has nothing to rewrite, and rewriting a history entry for nothing is worse than
	 * leaving it alone.
	 * @param {boolean} heldPin Whether the console held a pin when the clear was made.
	 */
	replaceAddress(heldPin)
	{
		if(!heldPin && !this.addressCarriesPins())
		{
			return;
		}
		this.writeAddress(this.addressOfPins(), true);
	}

	// The page the console is on, minus the console's own state keys. Derived from the delivered page
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
		// The compact column set follows the viewport; a browser without matchMedia keeps the full set.
		this.compactMediaQuery = typeof window.matchMedia === 'function' ? window.matchMedia(COMPACT_WIDTH_QUERY) : null;
		if(this.compactMediaQuery)
		{
			this.isCompactWidth = this.compactMediaQuery.matches === true;
			this.compactMediaQuery.addEventListener('change', this.handleCompactWidthChange);
		}
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

	/**
	 * @description Runs the base component's teardown first, then stops the pending search and the viewport listener.
	 */
	// noinspection JSUnusedGlobalSymbols - LWC framework lifecycle hook
	disconnectedCallback()
	{
		super.disconnectedCallback();
		window.clearTimeout(this.searchDebounceTimer);
		this.compactMediaQuery?.removeEventListener('change', this.handleCompactWidthChange);
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
			rootCorrelationId: this.actionRootCorrelationId,
			classMethod: this.sourceFilter?.classMethod ?? null,
			origins: this.origin ? [this.origin] : [],
			source: this.sourceFilter?.source ?? null,
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
		this.requestSequence += 1;
		const sequence = this.requestSequence;
		const request = this.buildRequest();
		await Promise.all([
			this.loadList(request, sequence),
			this.loadSummary(request, sequence)
		]);
		if(sequence === this.requestSequence)
		{
			this.isLoading = false;
		}
	}

	/**
	 * @description Loads the page of rows the request asks for and puts it on screen in place of the page before it. A
	 * page is a replacement, never an addition: what the reader sees is the page they asked for, whole.
	 * @param {Object} request The list request, as buildRequest composes it.
	 * @param {?number} sequence The request token this load belongs to; a load overtaken by a newer one applies nothing.
	 * @returns {Promise<void>} Resolves once the page has been applied, or dropped as stale.
	 */
	async loadList(request, sequence = null)
	{
		const apexMethod = this.isProblemsView ? getLogProblems : getLogEntries;
		const data = await this.callControllerMethod(apexMethod, {requestJson: JSON.stringify(request)}, SILENT_READ);
		if(sequence != null && sequence !== this.requestSequence)
		{
			return;
		}
		// A failed call has logged its own error and resolved undefined; a page that arrived and found nothing is an
		// object. That difference is the only thing separating "the read failed" from "your filters matched nothing".
		this.listLoadFailed = data === undefined;
		if(data?.records)
		{
			this.records = data.records.map((record) => this.decorateRow(record));
			this.totalCount = data.totalCount;
			this.totalPages = data.totalPages;
			this.hasMorePages = data.hasMorePages;
			this.pageNumber = data.pageNumber;
			// The wire's capped, falling back to resultsTruncated: on the problems page capped is the OR of both
			// legs, so a derived-leg cap raises the banner the rollup-only flag would have missed. The entries
			// page carries no capped flag at all and both views share this load path, so the fallback keeps it.
			this.capped = (data.capped ?? data.resultsTruncated) === true;
			// The status describes the fold that produced the page now on screen, and the fold re-runs per page
			// against a rolling window: a later page can decline a scan page one completed, and the bar then
			// describes the rows the reader is actually looking at.
			this.derivedStatus = data.derivedStatus ?? null;
			this.derivedLevelScope = data.derivedLevelScope ?? [];
			this.reconcileSelection();
		}
		else
		{
			// No page arrived, so no count arrived either. The counts of the page before must not stay behind.
			this.records = [];
			this.totalCount = 0;
			this.totalPages = 0;
			this.hasMorePages = false;
			this.pageNumber = 1;
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
		// The Source cell reads the writer the entry stored for itself, and falls back to the class and method
		// only for a row that stored none. Still under the key sourceDisplay, never source:
		// the wire's source carries the problem's provenance ('rollup' or 'derived'), so a display value under
		// the same key overwrites it in the spread below and the client loses the only thing that distinguishes
		// a grouped problem from a tagged one. The shipped contextDisplay beside it is the same pattern, and the
		// key is what the sort map and both views' columns address, so it stays as it is.
		// The dash rather than a blank, for the same reason the log number gets one. A grouped problem is not
		// grouped on its execution context, so the wire never sends one and EVERY grouped row's Context cell is
		// empty; a problem folded from rows with no recorded source has no source either. The class is what makes
		// that fallback: an entry logged with no class still carries its exception's line number, which the wire
		// sends on its own, and joined to an absent class that reads "null.42", so a bare line is dashed, not shown.
		// The origin travels as its readable label, and only beside a writer the cell actually names. The logger
		// stamps an origin on every entry and a name only when it knew the class and method behind it, so a row
		// can carry an origin with nobody to show it beside, and a pill there would describe a writer the cell
		// never shows.
		const classLocation = record.className ? [
			record.className,
			record.methodLine
		].filter(Boolean).join('.') : EM_DASH;
		const sourceDisplay = record.writerLocation ?? classLocation;
		const writerOriginLabel = record.writerLocation && record.writerOrigin ? ORIGIN_LABEL_BY_VALUE[record.writerOrigin] ?? record.writerOrigin : null;
		// A derived problem is grouped at read time and has no record of its own, so it gets no link at
		// all rather than one to /lightning/r/null/view.
		const recordUrl = record.id ? `/lightning/r/${record.id}/view` : null;
		// A row with no record behind it is a problem the console grouped at read time. Its Log Number and
		// Context cells are not values that went missing — this kind of row never had either, because it
		// owns no LogEntry__c and was not grouped on a context — so both cells say what the row is instead
		// of showing the dash a genuinely absent value gets.
		const isGrouped = !record.id;
		const contextDisplay = CONTEXT_LABEL_BY_VALUE[record.executionEvent] ?? record.executionEvent ?? (isGrouped ? groupedContext : EM_DASH);
		// The chain behind the row: name and number when a run holds the correlation, "this action" for an entry the action
		// wrote itself, the dash for a row that recorded no correlation (an empty cell reads as data that went missing).
		const chainWithoutRun = record.isActionOwn ? chainThisAction : EM_DASH;
		const chainDisplay = record.chainName ? `${record.chainName}${CHAIN_LABEL_SEPARATOR}${record.chainNumber}` : chainWithoutRun;
		// rowKey is the datatable's key. Keying on id alone would collapse every grouped row onto one undefined
		// key, and the table would treat them as a single row for selection and for its own diffing.
		// logNumberDisplay keeps the dash only for a row that owns a record but has no number to show, which
		// is a value that really did go missing; a grouped row gets the word for what it is instead.
		// isTagged marks one kind of row and not the other — grouping is what the console does by default, so
		// badging every grouped row would dilute the badge into wallpaper, while tagging is deliberate intent.
		return {
			...record,
			sourceDisplay,
			writerOriginLabel,
			contextDisplay,
			chainDisplay,
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
		if(!detail)
		{
			// The read failed and has already said so. Take the highlight off too, so the reader can select the row again to retry.
			this.clearSelection();
			return;
		}
		this.openedRow = this.selectedRecord ?? row;
		this.selectedDetail = detail;
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
			// A fresh copy: the drawer may have cleared its focus card, and the same object again is no change, so it would stay on loading.
			this.selectedFocusedDetail = {...this.focusedDetailCache.get(entryId)};
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
			// Each view has its own counts, in a different shape. Until the new view's counts arrive, the ribbon shows none.
			this.summary = null;
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

	handleOriginChange(event)
	{
		this.origin = event.detail.value;
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
			this.applySearch();
		}, SEARCH_DEBOUNCE_MS);
	}

	/**
	 * @description Runs the settled search. A term shaped like a tracking id is first put to the server: an action opens as
	 * the action pill, a chain run pins as the chain pill, and either clears the box; anything else, and every plain term,
	 * searches as text. The check runs here, once typing has settled, never per keystroke.
	 */
	async applySearch()
	{
		const term = (this.searchTerm || '').trim();
		if(TRACKING_ID_SHAPE.test(term))
		{
			const resolved = await this.callControllerMethod(resolveSearchId, {term}, SILENT_READ);
			if(term !== (this.searchTerm || '').trim())
			{
				return;
			}
			if(resolved?.kind === RESOLVED_ACTION || resolved?.kind === RESOLVED_LEGACY_ACTION)
			{
				this.searchTerm = '';
				const opened = this.openAction(resolved.id);
				this.pushAddress();
				await opened;
				return;
			}
			if(resolved?.kind === RESOLVED_CHAIN)
			{
				this.searchTerm = '';
				// A pasted id pins the run alone, the way a chain key alone in the address does: any pinned action
				// goes, because a run pasted from somewhere else need not belong to the action on screen, and a pill
				// and banner left telling that action's story over an empty list would be a lie the reader cannot
				// undo in one Back. So the screen a paste produces is the screen its address reproduces on a refresh.
				// A chip stays a narrowing: under an action, that is what a chip means.
				const pinned = this.pinRun(resolved.id, null, null, {name: resolved.chainName, number: resolved.chainNumber});
				this.pushAddress();
				await pinned;
				return;
			}
		}
		await this.resetAndReload();
	}

	handleDateRangeChange(event)
	{
		const preset = event.detail.value;
		this.rangePreset = preset;
		this.rangeNote = null;
		this.rangeFollowsRunningSource = false;
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
		this.rangeNote = null;
		this.rangeFollowsRunningSource = false;
		this.customStart = start;
		this.customEnd = end;
		// noinspection JSIgnoredPromiseFromCall
		this.resetAndReload();
	}

	// Seeds the custom inputs to the last 24 hours so switching to a custom range starts from a full window.
	seedCustomRangeDefaults()
	{
		const now = new Date();
		this.seedCustomRangeInputs(new Date(now.getTime() - DEFAULT_WINDOW_MINUTES * MILLISECONDS_PER_MINUTE), now);
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
		// Read before anything is cleared: whether there was a pin to clear is what decides if the address is rewritten.
		const heldPin = Boolean(this.actionRootCorrelationId || this.correlationId);
		window.clearTimeout(this.searchDebounceTimer);
		this.levels = [...DEFAULT_LEVELS];
		this.executionEvent = '';
		this.origin = '';
		this.searchTerm = '';
		this.correlationId = null;
		this.sourceFilter = null;
		// Clear all returns everything to its default, the pinned action included: the sort it set goes back with it.
		if(this.actionRootCorrelationId)
		{
			this.restoreActionDefaults();
		}
		this.actionRootCorrelationId = null;
		this.actionSummary = null;
		this.pinnedChain = null;
		this.pinnedRunWindow = null;
		this.rangeNote = null;
		this.rangeFollowsRunningSource = false;
		this.customRangeError = null;
		this.rangePreset = DEFAULT_RANGE_PRESET;
		this.windowMinutes = DEFAULT_WINDOW_MINUTES;
		this.customStart = null;
		this.customEnd = null;
		this.customFromDate = '';
		this.customFromTime = '';
		this.customToDate = '';
		this.customToTime = '';
		this.replaceAddress(heldPin);
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

	/**
	 * @description Reloads what is on screen: the list from page one, the same model a filter change follows, and, while
	 * an action is pinned, the banner beside it. A refresh is a fresh look at the list, so it starts where the list
	 * starts. A range the reader set themselves stays exactly where they put it, and the list and the banner are read
	 * together. A range that still follows a running source, set by a link or by an action's lifetime and not changed
	 * since, has its end moved first, so the list is read over the new range: to now while the source runs, and for an
	 * action to its real end and the margin once the banner says it has ended, after which the range stops following.
	 */
	async handleRefresh()
	{
		if(this.rangeFollowsRunningSource)
		{
			// A summary that failed, or came back without a start, leaves the range, its note and the following as they
			// were: a passing failure while the action runs must not throw its window away. The following is read again once
			// the summary lands, because a range the reader chose while it was on its way is theirs.
			if(this.actionRootCorrelationId)
			{
				if(await this.refreshActionSummary() && this.rangeFollowsRunningSource && this.actionSummary?.startedAt)
				{
					this.applyActionLifetimeRange();
				}
			}
			else
			{
				this.applyDeepLinkRange(this.pinnedRunWindow.start, null);
			}
			await this.resetAndReload();
		}
		else
		{
			await Promise.all([
				this.resetAndReload(),
				this.actionRootCorrelationId ? this.refreshActionSummary() : Promise.resolve()
			]);
		}
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
		// Clicking a ranked top source pins the list to exactly that writer, never a text search: the pill names the
		// source, and the Origin filter follows the row's origin so the card and the list count the same rows. A
		// Mixed row has no single origin to follow, so it pins the name alone across every origin.
		const {source, origin} = event.currentTarget.dataset;
		if(!source)
		{
			return;
		}
		this.sourceFilter = {source};
		this.origin = origin && origin !== ORIGIN_MIXED ? origin : '';
		this.searchTerm = '';
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
	 * @param {CustomEvent} event The `viewoccurrences` event, carrying the search term for a problem that
	 * recorded no source; a problem that recorded one is pinned to it and the term goes unread.
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
			this.sourceFilter = {classMethod: problem.classMethod, label: problem.writerLocation?.replace(/:\d+$/, '') ?? null, occurrenceCount: problem.occurrenceCount ?? null};
			this.searchTerm = '';
			// The problem is one level's problem, so its entries are that level's entries. Widening to
			// every level would list rows the problem never counted beside the count of the ones it did.
			this.levels = problem.level ? [problem.level] : [...ALL_LEVELS];
		}
		else
		{
			this.sourceFilter = null;
			this.searchTerm = event.detail.searchTerm;
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