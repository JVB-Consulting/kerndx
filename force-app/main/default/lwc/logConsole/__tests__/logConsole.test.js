// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for logConsole LWC container
 * @author Jason van Beukering
 * @date June 2026, October 2026
 */
import {createElement} from 'lwc';
import LogConsole from 'c/logConsole';
// noinspection JSUnresolvedReference - mock helpers are provided by the c/componentBuilder jest mock at run time
import {mockCallControllerMethod, mockNavigate, mockShowErrorToast} from 'c/componentBuilder';
import {CurrentPageReference} from 'lightning/navigation';
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

// The namespace prefix and the Log Settings URL are the console's two @wires onto Apex, so each needs a real
// test wire adapter (emit / error) rather than the resolved-promise stand-in the transformer gives an
// imperative Apex import.
jest.mock('@salesforce/apex/CTRL_LogConsole.getApexNamespacePrefix', () =>
{
	const {createApexTestWireAdapter} = require('@salesforce/sfdx-lwc-jest');
	return {default: createApexTestWireAdapter(jest.fn())};
}, {virtual: true});
jest.mock('@salesforce/apex/CTRL_LogConsole.getLogSettingsSetupUrl', () =>
{
	const {createApexTestWireAdapter} = require('@salesforce/sfdx-lwc-jest');
	return {default: createApexTestWireAdapter(jest.fn())};
}, {virtual: true});

jest.mock('@salesforce/label/c.LogConsole_Title', () => ({default: 'Log Console'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ViewProblems', () => ({default: 'Problem summary'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ViewEntries', () => ({default: 'Individual entries'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_Refresh', () => ({default: 'Refresh'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ClearAll', () => ({default: 'Clear all'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_SearchPlaceholder', () => ({default: 'Search'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_AllContexts', () => ({default: 'All contexts'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ContextFilter', () => ({default: 'Execution context'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_OriginGroupLabel', () => ({default: 'Origin'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_OriginFilter', () => ({default: 'Origin'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_AllOrigins', () => ({default: 'All origins'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_OriginFramework', () => ({default: 'Framework'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_OriginApex', () => ({default: 'Apex'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_OriginFlow', () => ({default: 'Flow'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_OriginComponent', () => ({default: 'Component'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_OriginMixed', () => ({default: 'Mixed'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_TotalOccurrences', () => ({default: 'Total occurrences'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_TotalsApproximate', () => ({default: 'Totals approximate'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_TotalsApproximateHelp',
		() => ({default: 'This window holds more activity than the console counts at once. Totals include only the most recent activity groups and may be higher.'}),
		{virtual: true});
jest.mock('@salesforce/label/c.LogConsole_DistinctShown', () => ({default: 'distinct shown'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_OccurrencesSuffix', () => ({default: 'occurrences'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_DistinctSuffix', () => ({default: 'distinct'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_TopSources', () => ({default: 'Top sources'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_EntriesInWindow', () => ({default: 'Entries in window'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_LogRows', () => ({default: 'log rows'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_RowsSuffix', () => ({default: 'rows'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_EntrySummaryTooLarge',
		() => ({default: 'This range holds too many entries to break down by level and source. Narrow the range or the level filter to see the breakdown.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_EmptyState', () => ({default: 'No logs match these filters.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_EmptyStateHint', () => ({default: 'Widen the date range, or clear a level or search filter.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ListLoadFailed', () => ({default: 'The log list couldn\'t be loaded.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ListLoadFailedHint', () => ({default: 'Narrow the date range or the filters, then refresh.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ProvenanceTagged', () => ({default: 'Tagged'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_DetailsHeading', () => ({default: 'Details'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_GroupedLogNumber', () => ({default: 'Grouped'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_GroupedContext', () => ({default: 'Any context'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_RowSuffixSingular', () => ({default: 'row'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_LogRowSingular', () => ({default: 'log row'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_TaggedOnlySuffix', () => ({default: '(tagged only)'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_RangeInverted', () => ({default: 'The To date and time must come after the From date and time.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_RangeIncomplete', () => ({default: 'Fill in all four boxes to apply a custom range.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_OccurrencesReconciliation',
		() => ({default: 'This problem was counted {0} times in this window. The list shows the {1} entries still on file from its source and level.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_SummaryLoadFailed', () => ({default: 'These counts could not be read. Refresh to try again.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_GroupingScopeCaption', () => ({default: 'Problem grouping covers {0}. Problems tagged in code appear at every level.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_GroupingDisabled', () => ({default: 'Problem grouping is off, so this list shows only the errors you have tagged yourself.'}),
		{virtual: true});
jest.mock('@salesforce/label/c.LogConsole_GroupingSkippedSearch',
		() => ({default: 'Problem grouping cannot apply your search, so these are your tagged problems only. Individual entries searches every word of every log.'}),
		{virtual: true});
jest.mock('@salesforce/label/c.LogConsole_GroupingSkippedLevelScope',
		() => ({default: 'Problem grouping is set up for {0}, and the levels you are viewing are not among them. Showing tagged problems only.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_GroupingSkippedTooLarge',
		() => ({default: 'This date range holds too many entries for the console to group them, so only your tagged problems are shown.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ActionOpenLogSettings', () => ({default: 'Open Log Settings'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ActionSearchAllEntries', () => ({default: 'Search every log in Individual entries'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ActionNarrowDateRange', () => ({default: 'Narrow the date range'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_TotalsPartialHelp',
		() => ({default: 'Part of this list could not be worked out for this date range, so these totals count only what was available. The real totals are higher.'}),
		{virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ProblemsEmpty', () => ({default: 'No repeating problems match these filters.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ProblemsEmptyHint',
		() => ({default: 'Problem summary shows errors that repeat often enough to be worth grouping. Individual entries lists the log entries themselves.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ProblemsEmptyNoGrouping', () => ({default: 'No problems match these filters.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ProblemsEmptyNoGroupingHint',
		() => ({default: 'Problem grouping is not running right now — the message above says why — so only problems you have tagged yourself can appear here.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_CappedBanner', () => ({default: 'Counted the first {0} matches, and there may be more. Narrow the filters to see the rest.'}),
		{virtual: true});
jest.mock('@salesforce/label/c.LogConsole_LoadingAlt', () => ({default: 'Loading logs'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ColLogNumber', () => ({default: 'Log Number'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ColLevel', () => ({default: 'Level'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ColProblem', () => ({default: 'Problem'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ColMessage', () => ({default: 'Message'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ColSource', () => ({default: 'Source'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ColContext', () => ({default: 'Context'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ColCount', () => ({default: 'Count'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ColLastSeen', () => ({default: 'Last seen'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ColTime', () => ({default: 'Time'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ColCorrelation', () => ({default: 'Correlation'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ColChain', () => ({default: 'Chain'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ChainThisAction', () => ({default: 'this action'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_EntriesPosition', () => ({default: 'Rows {0} to {1} of {2}'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_PerPage', () => ({default: '{0} per page'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_BackToList', () => ({default: 'Back to the list'}), {virtual: true});
jest.mock('@salesforce/label/c.PaginatedTable_Previous', () => ({default: 'Previous'}), {virtual: true});
jest.mock('@salesforce/label/c.PaginatedTable_Next', () => ({default: 'Next'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_LevelGroupLabel', () => ({default: 'Log levels'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ViewGroupLabel', () => ({default: 'View'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_LevelsGroupLabel', () => ({default: 'Levels'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ContextGroupLabel', () => ({default: 'Context'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_DateRange', () => ({default: 'Date range'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_Range15m', () => ({default: 'Last 15 minutes'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_Range1h', () => ({default: 'Last hour'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_Range4h', () => ({default: 'Last 4 hours'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_Range24h', () => ({default: 'Last 24 hours'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_Range7d', () => ({default: 'Last 7 days'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_Range30d', () => ({default: 'Last 30 days'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_RangeToday', () => ({default: 'Today'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_RangeYesterday', () => ({default: 'Yesterday'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_RangeThisWeek', () => ({default: 'This week'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_RangeLastWeek', () => ({default: 'Last week'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_RangeThisMonth', () => ({default: 'This month'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_RangeCustom', () => ({default: 'Custom range…'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_FromDate', () => ({default: 'From date'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_FromTime', () => ({default: 'From time'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ToDate', () => ({default: 'To date'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ToTime', () => ({default: 'To time'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ContextBatchApex', () => ({default: 'Batch Apex'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ContextQueueable', () => ({default: 'Queueable'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ContextQueueableFinalizer', () => ({default: 'Queueable finalizer'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ContextScheduled', () => ({default: 'Scheduled'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ContextFuture', () => ({default: 'Future'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ContextAura', () => ({default: 'Aura / LWC'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ContextRest', () => ({default: 'REST API'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ContextSynchronous', () => ({default: 'Synchronous'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ContextAnonymous', () => ({default: 'Anonymous Apex'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ActionPill', () => ({default: 'Action: {0}'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ChainPill', () => ({default: 'Chain: {0} · {1}'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ActionRangeNote', () => ({default: 'Date range set to this action\'s lifetime.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ActionBannerEyebrow', () => ({default: 'Everything this action did'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ActionBannerStarted', () => ({default: 'This action started on'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ActionBannerRanFor', () => ({default: 'and ran for {0}.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ActionBannerStillRunning', () => ({default: 'and is still running after {0}.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ActionBannerChains', () => ({default: 'It ran {0} chains, {1} of them failed.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ActionBannerNoChains', () => ({default: 'No chains ran under it.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ActionBannerLegacy', () => ({default: 'This action was recorded before chains were tracked by action.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ActionChipLaunchedBy', () => ({default: 'launched by {0}'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ActionMoreChains', () => ({default: 'and {0} more chains'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ActionOpenChains', () => ({default: 'Open the chains in the Chain Monitor'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_CappedBannerAction',
		() => ({default: 'Counted the first {0} matches, and there may be more. Narrow to one chain or a shorter range to see the rest.'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_StatusRunning', () => ({default: 'Running'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_StatusCompleted', () => ({default: 'Completed'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_StatusFailed', () => ({default: 'Failed'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_StatusAborted', () => ({default: 'Aborted'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_StatusStalled', () => ({default: 'Stalled'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_RestartOf', () => ({default: 'restart of {0}'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_StartedThisAction', () => ({default: 'started this action'}), {virtual: true});

const DEFAULT_WINDOW_MINUTES = 1440;
const SEVEN_DAY_WINDOW_MINUTES = 10080;

// The bounds a Chain Monitor hand-off carries, so a re-delivery of the same link is byte-identical.
const DEEP_LINK_START = '2026-06-01T09:00:00.000Z';
const DEEP_LINK_END = '2026-06-01T09:02:00.000Z';

// The Log Settings manage page the controller resolves — keyed by the object's key prefix, address-encoded
// exactly as Setup reads it.
const LOG_SETTINGS_MANAGE_URL = '/lightning/setup/CustomSettings/page?address=%2Fsetup%2Fui%2FlistCustomSettingsData.apexp%3Fid%3Da06';
const CUSTOM_SETTINGS_HOME_PATH = '/lightning/setup/CustomSettings/home';

const PROBLEM_ROWS = [
	{
		id: '001p1',
		logNumber: 'L-001',
		level: 'ERROR',
		shortMessage: 'NPE',
		exceptionType: 'System.NullPointerException',
		className: 'AcctHandler',
		methodLine: 'run:42',
		classMethod: 'AcctHandler.run',
		executionEvent: 'BATCH_APEX',
		correlationId: 'c1',
		occurrenceCount: 1284,
		firstSeen: '2026-06-28T09:00:00.000Z',
		lastSeen: '2026-06-28T11:00:00.000Z'
	},
	{
		id: '001p2',
		logNumber: 'L-002',
		level: 'WARN',
		shortMessage: 'Circuit open',
		exceptionType: '',
		className: 'Breaker',
		methodLine: 'guard:9',
		classMethod: 'Breaker.guard',
		executionEvent: 'QUEUEABLE',
		correlationId: 'c2',
		occurrenceCount: 96,
		firstSeen: '2026-06-28T08:00:00.000Z',
		lastSeen: '2026-06-28T10:00:00.000Z'
	}
];
const MOCK_PROBLEM_PAGE = {records: PROBLEM_ROWS, totalCount: 2, pageNumber: 1, totalPages: 1, hasMorePages: false, resultsTruncated: false};
// The same page after a fold that ran whole over both default levels — the state in which a level card's
// numbers include the problems the console grouped, not only the ones a developer tagged in code.
const GROUPED_PROBLEM_PAGE = {
	...MOCK_PROBLEM_PAGE, derivedStatus: 'COMPLETE', derivedLevelScope: [
		'ERROR',
		'WARN'
	]
};
const MOCK_ENTRY_PAGE = {
	records: [
		{
			id: '001e1',
			logNumber: 'L-010',
			level: 'INFO',
			shortMessage: 'Done',
			className: 'Chain',
			methodLine: 'fin:1',
			executionEvent: 'QUEUEABLE',
			correlationId: 'c1',
			createdDate: '2026-06-28T10:00:00.000Z'
		}
	], totalCount: 1, pageNumber: 1, totalPages: 1, hasMorePages: false
};
const MOCK_SUMMARY = {
	totalOccurrences: 1380, distinctCount: 2, perLevel: [
		{level: 'ERROR', occurrences: 1284, distinctCount: 1},
		{level: 'WARN', occurrences: 96, distinctCount: 1}
	], topSources: [
		{name: 'AcctHandler', origin: 'APEX', count: 1284, percent: 93},
		{name: 'Breaker', origin: 'FRAMEWORK', count: 96, percent: 7}
	]
};
const MOCK_ENTRY_SUMMARY = {
	totalRows: 42, perLevel: [
		{level: 'ERROR', rowCount: 30},
		{level: 'WARN', rowCount: 12}
	], topSources: [
		{name: 'Chain', origin: 'FRAMEWORK', count: 30, percent: 71},
		{name: 'Breaker', origin: 'FRAMEWORK', count: 12, percent: 29}
	]
};
const MOCK_DETAIL = {
	id: '001p1',
	logNumber: 'L-001',
	level: 'ERROR',
	shortMessage: 'NPE',
	message: 'm',
	stackTrace: 's',
	contextJson: '{}',
	className: 'AcctHandler',
	methodLine: 'run:42',
	executionEvent: 'BATCH_APEX',
	userId: '005x',
	correlationId: 'c1',
	transactionId: 'tx',
	parentTransactionId: 'ptx',
	recordId: '001r',
	firstSeen: '2026-06-28T09:00:00.000Z',
	lastSeen: '2026-06-28T11:00:00.000Z',
	durationMs: 10,
	limitBars: []
};

const MOCK_TRACE = [
	{
		id: '001p0',
		logNumber: 'L-000',
		level: 'INFO',
		shortMessage: 'begin',
		className: 'OrderService',
		methodLine: 'begin:1',
		executionEvent: 'BATCH_APEX',
		createdDate: '2026-06-28T08:59:00.000Z',
		isSelf: false
	},
	{
		id: '001p1',
		logNumber: 'L-001',
		level: 'ERROR',
		shortMessage: 'NPE',
		className: 'AcctHandler',
		methodLine: 'run:42',
		executionEvent: 'BATCH_APEX',
		createdDate: '2026-06-28T09:00:00.000Z',
		isSelf: true
	}
];

const ACTION_ID = 'a7d2f4c1-1111-4111-8111-00000000f13a';
const ACTION_START = '2026-09-01T10:00:00.000Z';
const ACTION_END = '2026-09-01T10:03:00.000Z';
const CHIP_A = {executionId: 'a00A', chainName: 'OrderSync', chainNumber: 'CHAIN-00214', correlationId: 'run-a', status: 'Failed', launchKind: 'ACTION', launcherName: null};
const CHIP_B = {
	executionId: 'a00B', chainName: 'Ledger', chainNumber: 'CHAIN-00215', correlationId: 'run-b', status: 'Completed', launchKind: 'CHAIN', launcherName: 'OrderSync · CHAIN-00214'
};
const MOCK_ACTION_SUMMARY = {
	rootCorrelationId: ACTION_ID,
	startedAt: ACTION_START,
	endedAt: ACTION_END,
	stillRunning: false,
	recordedBeforeRoots: false,
	chainCount: 7,
	failedCount: 1,
	durationLabel: '3m',
	chains: [
		CHIP_A,
		CHIP_B
	],
	moreChainCount: 5
};
const RUNNING_ACTION_SUMMARY = {...MOCK_ACTION_SUMMARY, endedAt: null, stillRunning: true, durationLabel: '8s', chainCount: 0, failedCount: 0, chains: [], moreChainCount: 0};
const LEGACY_ACTION_SUMMARY = {
	...MOCK_ACTION_SUMMARY, recordedBeforeRoots: true, chainCount: 1, failedCount: 0, chains: [{...CHIP_B, launchKind: 'ORIGIN', launcherName: null}], moreChainCount: 0
};
// One minute either side of the action's span, in milliseconds.
const ACTION_RANGE_MARGIN_MILLISECONDS = 60000;

function wireMockResponses(overrides = {})
{
	const responseByMethod = new Map([
		[
			getLogProblems,
			overrides.problems ?? MOCK_PROBLEM_PAGE
		],
		[
			getLogEntries,
			overrides.entries ?? MOCK_ENTRY_PAGE
		],
		[
			getLogSummary,
			overrides.summary ?? MOCK_SUMMARY
		],
		[
			getEntrySummary,
			overrides.entrySummary ?? MOCK_ENTRY_SUMMARY
		],
		[
			getLogEntryDetail,
			overrides.detail ?? MOCK_DETAIL
		],
		[
			getDerivedProblemDetail,
			overrides.derivedDetail ?? MOCK_DETAIL
		],
		[
			getCorrelatedTrace,
			overrides.trace ?? {entries: MOCK_TRACE, truncated: false}
		],
		[
			getActionSummary,
			overrides.actionSummary ?? MOCK_ACTION_SUMMARY
		],
		[
			resolveSearchId,
			overrides.resolvedSearchId ?? {kind: 'NONE'}
		]
	]);
	mockCallControllerMethod.mockImplementation((apexFn) => Promise.resolve(responseByMethod.has(apexFn) ? responseByMethod.get(apexFn) : null));
}

// Answers both list methods with a page that echoes the page the request asked for, so a test can
// walk the pager as deep as it needs in either view. Each page carries one row, so the rows on
// screen are countable and a page turn is visible as a replacement. The two ribbons answer with the
// usual aggregates.
function wirePagedResponses(totalPages)
{
	mockCallControllerMethod.mockImplementation((apexFn, params) =>
	{
		if(apexFn === getLogProblems || apexFn === getLogEntries)
		{
			const pageNumber = JSON.parse(params.requestJson).pageNumber;
			const template = apexFn === getLogProblems ? PROBLEM_ROWS[0] : MOCK_ENTRY_PAGE.records[0];
			return Promise.resolve({
				records: [{...template, id: `page-${pageNumber}`, logNumber: `L-10${pageNumber}`}],
				totalCount: totalPages,
				pageNumber,
				totalPages,
				hasMorePages: pageNumber < totalPages,
				resultsTruncated: false
			});
		}
		if(apexFn === getLogSummary)
		{
			return Promise.resolve(MOCK_SUMMARY);
		}
		return Promise.resolve(apexFn === getEntrySummary ? MOCK_ENTRY_SUMMARY : null);
	});
}

function lastRequestFor(apexFn)
{
	const calls = mockCallControllerMethod.mock.calls.filter((call) => call[0] === apexFn);
	return JSON.parse(calls[calls.length - 1][1].requestJson);
}

// How many times a controller method was called since the last mockClear, so a test can hold the
// console to a single load rather than only checking the state it settles on.
function callCountFor(apexFn)
{
	return mockCallControllerMethod.mock.calls.filter((call) => call[0] === apexFn).length;
}

async function flushAll()
{
	await Promise.resolve();
	await Promise.resolve();
	await Promise.resolve();
	await Promise.resolve();
}

async function createComponent()
{
	const element = createElement('c-log-console', {is: LogConsole});
	document.body.appendChild(element);
	await flushAll();
	return element;
}

function table(element)
{
	return element.shadowRoot.querySelector('c-log-console-table');
}

function buttonByLabel(element, text)
{
	return Array.from(element.shadowRoot.querySelectorAll('lightning-button')).find((button) => button.label === text);
}

function levelButton(element, level)
{
	return element.shadowRoot.querySelector(`.level-seg-btn[data-level="${level}"]`);
}

function dateRangeCombobox(element)
{
	return element.shadowRoot.querySelector('.date-range-combobox');
}

function setCustomField(element, field, value)
{
	customField(element, field).dispatchEvent(new CustomEvent('change', {detail: {value}}));
}

function customField(element, field)
{
	return Array.from(element.shadowRoot.querySelectorAll('.customrange-field')).find((candidate) => candidate.dataset.field === field);
}

// The four custom inputs are viewer-time-zone display values; parsing them back without a zone
// designator re-reads them in the same local zone, so the assertion holds in any test time zone.
function customRangeInstant(element, dateField, timeField)
{
	return new Date(`${customField(element, dateField).value}T${customField(element, timeField).value}`).getTime();
}

function columnFieldNames(element)
{
	return element.shadowRoot.querySelector('c-log-console-table').columns.map((column) => column.fieldName);
}

// The datatable hands back whole rows from its own data, so a selected row always carries the key field.
// For an entry or a tagged problem that key IS the record id, which is what this shorthand builds.
async function selectRow(element, id)
{
	table(element).dispatchEvent(new CustomEvent('rowselection', {detail: {selectedRows: [{id, rowKey: id}]}}));
	await flushAll();
}

// Turns the list to the next page the way a reader does: the pager's own Next button.
async function turnToNextPage(element)
{
	element.shadowRoot.querySelector('[data-testid="pager-next"]').click();
	await flushAll();
}

describe('c-log-console', () =>
{
	beforeEach(() => wireMockResponses());

	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
		jest.clearAllMocks();
	});

	describe('initial load and defaults', () =>
	{
		it('loads the distinct problems and the summary on connect', async() =>
		{
			const element = await createComponent();

			// A plain mount loads exactly once: the list and its ribbon are each queried a single time.
			expect(callCountFor(getLogProblems)).toBe(1);
			expect(callCountFor(getLogSummary)).toBe(1);
			expect(table(element).data.length).toBe(2);
		});

		it('requests the problems view with the documented defaults', async() =>
		{
			await createComponent();

			const request = lastRequestFor(getLogProblems);
			expect(request.windowMinutes).toBe(DEFAULT_WINDOW_MINUTES);
			// Severity first, worst at the top: ranking on the count alone put a chatty INFO message above
			// every error in the window, in a list the heading calls problems.
			expect(request.sortField).toBe('level');
			expect(request.sortAscending).toBe(false);
			expect(request.pageNumber).toBe(1);
			expect(request.levels).toEqual([
				'ERROR',
				'WARN'
			]);
		});
	});

	describe('view switching', () =>
	{
		it('switches to the entries view sorted by createdDate', async() =>
		{
			const element = await createComponent();
			mockCallControllerMethod.mockClear();

			buttonByLabel(element, 'Individual entries').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			expect(mockCallControllerMethod.mock.calls.some((call) => call[0] === getLogEntries)).toBe(true);
			const request = lastRequestFor(getLogEntries);
			expect(request.sortField).toBe('createdDate');
		});

		it('loads the entries ribbon from getEntrySummary, not getLogSummary, in the entries view', async() =>
		{
			const element = await createComponent();
			mockCallControllerMethod.mockClear();

			buttonByLabel(element, 'Individual entries').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			expect(mockCallControllerMethod.mock.calls.some((call) => call[0] === getEntrySummary)).toBe(true);
			expect(mockCallControllerMethod.mock.calls.some((call) => call[0] === getLogSummary)).toBe(false);
		});

		it('shows no ribbon cards while the other view\'s counts are still loading', async() =>
		{
			const element = await createComponent();
			expect(element.shadowRoot.querySelectorAll('[data-testid="summary-card"]').length).toBeGreaterThan(0);
			// The entries counts never arrive in this test. Until they do, the problems counts must not be drawn as entries cards.
			const pageAnswer = mockCallControllerMethod.getMockImplementation();
			mockCallControllerMethod.mockImplementation((apexFn, params) => (apexFn === getEntrySummary ? new Promise(() =>
			{
			}) : pageAnswer(apexFn, params)));

			buttonByLabel(element, 'Individual entries').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			expect(element.shadowRoot.querySelectorAll('[data-testid="summary-card"]')).toHaveLength(0);
		});

		it('does not reload when the already-active view is clicked', async() =>
		{
			const element = await createComponent();
			mockCallControllerMethod.mockClear();

			buttonByLabel(element, 'Problem summary').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			expect(mockCallControllerMethod).not.toHaveBeenCalled();
		});

		it('restores the severity-first sort when switching back to the problems view', async() =>
		{
			const element = await createComponent();
			buttonByLabel(element, 'Individual entries').dispatchEvent(new CustomEvent('click'));
			await flushAll();
			expect(lastRequestFor(getLogEntries).sortField).toBe('createdDate');
			mockCallControllerMethod.mockClear();

			buttonByLabel(element, 'Problem summary').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			expect(lastRequestFor(getLogProblems).sortField).toBe('level');
			expect(lastRequestFor(getLogProblems).sortAscending).toBe(false);
			// the sort-arrow indicator follows the restored default rather than staying on the entries-view column
			expect(table(element).sortedBy).toBe('level');
		});
	});

	describe('filtering', () =>
	{
		it('resets to page one when a level filter is toggled', async() =>
		{
			wirePagedResponses(3);
			const element = await createComponent();

			// The console only reaches page three through its public surface: two turns of the pager.
			// Setting pageNumber on the host would not reach component state (the container declares
			// no @api members), so the reset would appear to work even if it were deleted.
			await turnToNextPage(element);
			expect(lastRequestFor(getLogProblems).pageNumber).toBe(2);
			await turnToNextPage(element);
			expect(lastRequestFor(getLogProblems).pageNumber).toBe(3);
			mockCallControllerMethod.mockClear();

			levelButton(element, 'INFO').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			const request = lastRequestFor(getLogProblems);
			expect(request.pageNumber).toBe(1);
			expect(request.levels).toContain('INFO');
			// Page one is what the list shows again; each page of this fixture carries a single row.
			expect(table(element).data.map((row) => row.logNumber)).toEqual(['L-101']);
		});

		it('drops a level from the query when an already-active level is toggled off', async() =>
		{
			const element = await createComponent();
			expect(levelButton(element, 'ERROR').getAttribute('aria-pressed')).toBe('true');
			mockCallControllerMethod.mockClear();

			levelButton(element, 'ERROR').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			expect(lastRequestFor(getLogProblems).levels).toEqual(['WARN']);
			expect(levelButton(element, 'ERROR').getAttribute('aria-pressed')).toBe('false');
		});

		it('clears the filters back to defaults', async() =>
		{
			const element = await createComponent();
			levelButton(element, 'INFO').dispatchEvent(new CustomEvent('click'));
			await flushAll();
			mockCallControllerMethod.mockClear();

			buttonByLabel(element, 'Clear all').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			expect(lastRequestFor(getLogProblems).levels).toEqual([
				'ERROR',
				'WARN'
			]);
		});

		it('filters by execution context', async() =>
		{
			const element = await createComponent();
			mockCallControllerMethod.mockClear();

			const combobox = element.shadowRoot.querySelector('.filter-combobox');
			combobox.dispatchEvent(new CustomEvent('change', {detail: {value: 'QUEUEABLE'}}));
			await flushAll();

			expect(lastRequestFor(getLogProblems).executionEvents).toEqual(['QUEUEABLE']);
		});

		it('filters by search term after the debounce settles', async() =>
		{
			jest.useFakeTimers();
			try
			{
				const element = await createComponent();
				mockCallControllerMethod.mockClear();

				const search = element.shadowRoot.querySelector('lightning-input');
				search.value = 'timeout';
				search.dispatchEvent(new CustomEvent('change'));
				await flushAll();
				expect(mockCallControllerMethod).not.toHaveBeenCalled();

				jest.advanceTimersByTime(300);
				await flushAll();

				expect(lastRequestFor(getLogProblems).searchTerm).toBe('timeout');
			}
			finally
			{
				jest.useRealTimers();
			}
		});

		it('debounces fast typing into a single query carrying only the final term', async() =>
		{
			jest.useFakeTimers();
			try
			{
				const element = await createComponent();
				mockCallControllerMethod.mockClear();

				const search = element.shadowRoot.querySelector('lightning-input');
				for(const term of [
					'b',
					'bl',
					'blah'
				])
				{
					search.value = term;
					search.dispatchEvent(new CustomEvent('change'));
					jest.advanceTimersByTime(100);
				}
				expect(mockCallControllerMethod).not.toHaveBeenCalled();

				jest.advanceTimersByTime(300);
				await flushAll();

				const problemCalls = mockCallControllerMethod.mock.calls.filter((call) => call[0] === getLogProblems);
				expect(problemCalls.length).toBe(1);
				expect(lastRequestFor(getLogProblems).searchTerm).toBe('blah');
			}
			finally
			{
				jest.useRealTimers();
			}
		});

		it('renders the documented date-range preset options', async() =>
		{
			const element = await createComponent();

			const values = dateRangeCombobox(element).options.map((option) => option.value);
			expect(values).toEqual([
				'15',
				'60',
				'240',
				'1440',
				'today',
				'yesterday',
				'thisweek',
				'lastweek',
				'thismonth',
				'10080',
				'43200',
				'custom'
			]);
		});

		it('sets windowMinutes and clears any custom range when a preset window is chosen', async() =>
		{
			const element = await createComponent();
			mockCallControllerMethod.mockClear();

			dateRangeCombobox(element).dispatchEvent(new CustomEvent('change', {detail: {value: '10080'}}));
			await flushAll();

			const request = lastRequestFor(getLogProblems);
			expect(request.windowMinutes).toBe(SEVEN_DAY_WINDOW_MINUTES);
			expect(request.customStart).toBeNull();
			expect(request.customEnd).toBeNull();
		});

		it('sends an ordered custom ISO range and no window when a calendar preset is chosen', async() =>
		{
			const element = await createComponent();
			mockCallControllerMethod.mockClear();

			dateRangeCombobox(element).dispatchEvent(new CustomEvent('change', {detail: {value: 'today'}}));
			await flushAll();

			const request = lastRequestFor(getLogProblems);
			expect(typeof request.customStart).toBe('string');
			expect(typeof request.customEnd).toBe('string');
			expect(new Date(request.customStart).getTime()).toBeLessThanOrEqual(new Date(request.customEnd).getTime());
		});

		it('resolves each calendar preset to the correct local-time range', async() =>
		{
			const element = await createComponent();
			const combo = dateRangeCombobox(element);
			const now = new Date();
			const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());

			const rangeFor = async(preset) =>
			{
				mockCallControllerMethod.mockClear();
				combo.dispatchEvent(new CustomEvent('change', {detail: {value: preset}}));
				await flushAll();
				const request = lastRequestFor(getLogProblems);
				return {start: new Date(request.customStart), end: new Date(request.customEnd)};
			};

			const yesterday = await rangeFor('yesterday');
			expect(yesterday.start.getTime()).toBe(new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1).getTime());
			expect(yesterday.end.getTime()).toBe(startOfToday.getTime() - 1);

			const thisMonth = await rangeFor('thismonth');
			expect(thisMonth.start.getTime()).toBe(new Date(now.getFullYear(), now.getMonth(), 1).getTime());

			const thisWeek = await rangeFor('thisweek');
			expect(thisWeek.start.getDay()).toBe(1);
			expect(thisWeek.start.getTime()).toBeLessThanOrEqual(now.getTime());
			// The only Monday that is a local midnight within the last seven days uniquely identifies this week.
			expect(now.getTime() - thisWeek.start.getTime()).toBeLessThan(7 * 24 * 60 * 60 * 1000);

			const lastWeek = await rangeFor('lastweek');
			expect(lastWeek.start.getDay()).toBe(1);
			expect(lastWeek.end.getTime()).toBe(thisWeek.start.getTime() - 1);
		});

		it('reveals the four custom date and time inputs only when the custom range is chosen', async() =>
		{
			const element = await createComponent();
			expect(element.shadowRoot.querySelectorAll('.customrange-field').length).toBe(0);

			dateRangeCombobox(element).dispatchEvent(new CustomEvent('change', {detail: {value: 'custom'}}));
			await flushAll();

			expect(element.shadowRoot.querySelectorAll('.customrange-field').length).toBe(4);
		});

		it('sends the entered custom range as customStart and customEnd instants', async() =>
		{
			const element = await createComponent();
			dateRangeCombobox(element).dispatchEvent(new CustomEvent('change', {detail: {value: 'custom'}}));
			await flushAll();
			mockCallControllerMethod.mockClear();

			setCustomField(element, 'fromDate', '2026-06-01');
			setCustomField(element, 'fromTime', '00:00:00');
			setCustomField(element, 'toDate', '2026-06-02');
			setCustomField(element, 'toTime', '12:30:00');
			await flushAll();

			const request = lastRequestFor(getLogProblems);
			expect(new Date(request.customStart).getTime()).toBe(new Date(2026, 5, 1, 0, 0, 0).getTime());
			expect(new Date(request.customEnd).getTime()).toBe(new Date(2026, 5, 2, 12, 30, 0).getTime());
		});

		it('says an inverted custom range is inverted, and keeps the window it had', async() =>
		{
			const element = await createComponent();
			dateRangeCombobox(element).dispatchEvent(new CustomEvent('change', {detail: {value: 'custom'}}));
			await flushAll();
			setCustomField(element, 'fromDate', '2026-06-15');
			setCustomField(element, 'fromTime', '00:00:00');
			setCustomField(element, 'toDate', '2026-06-16');
			setCustomField(element, 'toTime', '00:00:00');
			await flushAll();
			const before = lastRequestFor(getLogProblems).customEnd;
			mockCallControllerMethod.mockClear();

			setCustomField(element, 'toDate', '2026-06-14');
			await flushAll();

			// Silently keeping the old window left the previous rows on screen looking like the answer to
			// the range that had just been typed, with nothing anywhere saying the range was refused.
			const message = element.shadowRoot.querySelector('[data-testid="custom-range-error"]');
			expect(message).not.toBeNull();
			expect(message.textContent).toContain('must come after');
			expect(message.getAttribute('role')).toBe('alert');
			expect(callCountFor(getLogProblems)).toBe(0);
			expect(before).not.toBeNull();
		});

		it('says a half-filled custom range is unfinished rather than refusing it silently', async() =>
		{
			const element = await createComponent();
			dateRangeCombobox(element).dispatchEvent(new CustomEvent('change', {detail: {value: 'custom'}}));
			await flushAll();
			mockCallControllerMethod.mockClear();

			// A date input reports an unparseable value as an empty one, so this is also what typing
			// nonsense into the box looks like from here.
			setCustomField(element, 'toDate', '');
			await flushAll();

			expect(element.shadowRoot.querySelector('[data-testid="custom-range-error"]').textContent).toContain('all four boxes');
			expect(callCountFor(getLogProblems)).toBe(0);
		});

		it('takes the range message back down once the range can be run', async() =>
		{
			const element = await createComponent();
			dateRangeCombobox(element).dispatchEvent(new CustomEvent('change', {detail: {value: 'custom'}}));
			await flushAll();
			setCustomField(element, 'fromDate', '2026-06-15');
			setCustomField(element, 'fromTime', '00:00:00');
			setCustomField(element, 'toDate', '');
			setCustomField(element, 'toTime', '00:00:00');
			await flushAll();
			expect(element.shadowRoot.querySelector('[data-testid="custom-range-error"]')).not.toBeNull();
			mockCallControllerMethod.mockClear();

			setCustomField(element, 'toDate', '2026-06-16');
			await flushAll();

			expect(element.shadowRoot.querySelector('[data-testid="custom-range-error"]')).toBeNull();
			expect(callCountFor(getLogProblems)).toBeGreaterThan(0);
		});

		it('drops the range message when a preset answers the question instead', async() =>
		{
			const element = await createComponent();
			dateRangeCombobox(element).dispatchEvent(new CustomEvent('change', {detail: {value: 'custom'}}));
			await flushAll();
			setCustomField(element, 'fromDate', '');
			await flushAll();
			expect(element.shadowRoot.querySelector('[data-testid="custom-range-error"]')).not.toBeNull();

			dateRangeCombobox(element).dispatchEvent(new CustomEvent('change', {detail: {value: '60'}}));
			await flushAll();

			expect(element.shadowRoot.querySelector('[data-testid="custom-range-error"]')).toBeNull();
		});

		it('offers the two custom time inputs at second granularity', async() =>
		{
			const element = await createComponent();
			dateRangeCombobox(element).dispatchEvent(new CustomEvent('change', {detail: {value: 'custom'}}));
			await flushAll();

			const timeSteps = Array.from(element.shadowRoot.querySelectorAll('.customrange-field')).filter((field) => field.type === 'time').map((field) => field.step);
			expect(timeSteps).toEqual([
				'1',
				'1'
			]);
		});

		it('carries the entered seconds through to the instants it sends', async() =>
		{
			const element = await createComponent();
			dateRangeCombobox(element).dispatchEvent(new CustomEvent('change', {detail: {value: 'custom'}}));
			await flushAll();
			mockCallControllerMethod.mockClear();

			setCustomField(element, 'fromDate', '2026-06-01');
			setCustomField(element, 'fromTime', '08:15:05');
			setCustomField(element, 'toDate', '2026-06-01');
			setCustomField(element, 'toTime', '09:30:45');
			await flushAll();

			const request = lastRequestFor(getLogProblems);
			expect(new Date(request.customStart).getTime()).toBe(new Date(2026, 5, 1, 8, 15, 5).getTime());
			expect(new Date(request.customEnd).getTime()).toBe(new Date(2026, 5, 1, 9, 30, 45).getTime());
		});

		it('does not query when the entered custom range is inverted (from after to)', async() =>
		{
			const element = await createComponent();
			dateRangeCombobox(element).dispatchEvent(new CustomEvent('change', {detail: {value: 'custom'}}));
			await flushAll();
			setCustomField(element, 'fromDate', '2026-06-10');
			await flushAll();
			mockCallControllerMethod.mockClear();

			setCustomField(element, 'toDate', '2026-06-01');
			await flushAll();

			expect(mockCallControllerMethod.mock.calls.some((call) => call[0] === getLogProblems)).toBe(false);
		});

		it('lands a correlation deep link on the entries view with the widest range and a visible pill, ignoring a repeat', async() =>
		{
			const element = await createComponent();
			mockCallControllerMethod.mockClear();

			CurrentPageReference.emit({state: {c__correlationId: 'deep-1'}});
			await flushAll();

			const request = lastRequestFor(getLogEntries);
			expect(request.correlationId).toBe('deep-1');
			expect(request.windowMinutes).toBe(43200);
			// With no bounds on the link the console falls back to the widest rolling preset.
			expect(request.customStart).toBeNull();
			expect(request.customEnd).toBeNull();
			expect(dateRangeCombobox(element).value).toBe('43200');
			expect(request.levels).toEqual([
				'ERROR',
				'WARN',
				'INFO',
				'DEBUG'
			]);
			expect(element.shadowRoot.querySelector('[data-testid="correlation-pill"]').label).toContain('deep-1');

			mockCallControllerMethod.mockClear();
			CurrentPageReference.emit({state: {c__correlationId: 'deep-1'}});
			await flushAll();
			expect(mockCallControllerMethod).not.toHaveBeenCalled();
		});

		it('clears a stale search term and context filter when a correlation deep link arrives', async() =>
		{
			const element = await createComponent();
			element.shadowRoot.querySelector('.filter-combobox').dispatchEvent(new CustomEvent('change', {detail: {value: 'QUEUEABLE'}}));
			await flushAll();
			element.shadowRoot.querySelector('[data-testid="source-row"]').click();
			await flushAll();
			expect(lastRequestFor(getLogProblems).searchTerm).toBeNull();
			expect(lastRequestFor(getLogProblems).source).toBe('AcctHandler');
			expect(lastRequestFor(getLogProblems).origins).toEqual(['APEX']);
			mockCallControllerMethod.mockClear();

			CurrentPageReference.emit({state: {c__correlationId: 'deep-stale'}});
			await flushAll();

			// A search term or context left over from the console's previous use would silently hide
			// the deep-linked rows, so the link clears both along with the rest of the filter state.
			const request = lastRequestFor(getLogEntries);
			expect(request.searchTerm).toBeNull();
			expect(request.executionEvents).toEqual([]);
			expect(request.origins).toEqual([]);
			expect(request.source).toBeNull();
			expect(element.shadowRoot.querySelector('.filter-search').value).toBe('');
			expect(element.shadowRoot.querySelector('.filter-combobox').value).toBe('');
		});

		it('pins the window to the bounds a deep link carries instead of widening to the rolling preset', async() =>
		{
			const element = await createComponent();
			mockCallControllerMethod.mockClear();

			CurrentPageReference.emit({
				state: {c__correlationId: 'deep-bounded', c__windowStart: '2026-06-01T09:00:30.000Z', c__windowEnd: '2026-06-01T10:15:45.000Z'}
			});
			await flushAll();

			const request = lastRequestFor(getLogEntries);
			expect(request.customStart).toBe('2026-06-01T09:00:30.000Z');
			expect(request.customEnd).toBe('2026-06-01T10:15:45.000Z');
			expect(dateRangeCombobox(element).value).toBe('custom');
			// The four custom inputs are revealed and show the same two instants in viewer time.
			expect(element.shadowRoot.querySelectorAll('.customrange-field').length).toBe(4);
			expect(customRangeInstant(element, 'fromDate', 'fromTime')).toBe(new Date('2026-06-01T09:00:30.000Z').getTime());
			expect(customRangeInstant(element, 'toDate', 'toTime')).toBe(new Date('2026-06-01T10:15:45.000Z').getTime());
		});

		it('reads a deep link with a start but no end as running to now', async() =>
		{
			const element = await createComponent();
			mockCallControllerMethod.mockClear();
			const beforeLink = Date.now();

			CurrentPageReference.emit({state: {c__correlationId: 'deep-open-ended', c__windowStart: '2026-06-01T09:00:00.000Z'}});
			await flushAll();

			const request = lastRequestFor(getLogEntries);
			expect(request.customStart).toBe('2026-06-01T09:00:00.000Z');
			expect(new Date(request.customEnd).getTime()).toBeGreaterThanOrEqual(beforeLink);
			expect(dateRangeCombobox(element).value).toBe('custom');
			expect(customRangeInstant(element, 'toDate', 'toTime')).toBe(new Date(request.customEnd).setMilliseconds(0));
		});

		describe('refreshing a range a deep link set', () =>
		{
			const LINK_START = '2026-06-01T09:00:00.000Z';
			const LINK_END = '2026-06-01T09:04:00.000Z';
			const FIRST_LOOK = new Date('2026-06-01T09:05:00.000Z');
			const SECOND_LOOK = new Date('2026-06-01T09:12:30.000Z');
			const READER_WINDOW_MINUTES = 60;

			beforeEach(() =>
			{
				jest.useFakeTimers();
				jest.setSystemTime(FIRST_LOOK);
			});

			afterEach(() => jest.useRealTimers());

			async function followLink(state)
			{
				const element = await createComponent();
				CurrentPageReference.emit({state});
				await flushAll();
				return element;
			}

			async function refreshLater(element)
			{
				mockCallControllerMethod.mockClear();
				jest.setSystemTime(SECOND_LOOK);
				buttonByLabel(element, 'Refresh').click();
				await flushAll();
				await flushAll();
				return lastRequestFor(getLogEntries);
			}

			it('moves the end of an open-ended deep link to now on every refresh while the run is still going', async() =>
			{
				const element = await followLink({c__correlationId: 'deep-open-ended', c__windowStart: LINK_START});
				expect(lastRequestFor(getLogEntries).customEnd).toBe(FIRST_LOOK.toISOString());

				const request = await refreshLater(element);

				expect(request.customStart).toBe(LINK_START);
				expect(request.customEnd).toBe(SECOND_LOOK.toISOString());
				expect(customRangeInstant(element, 'toDate', 'toTime')).toBe(SECOND_LOOK.getTime());
			});

			it('leaves a preset the reader chose after following an open-ended link in place', async() =>
			{
				const element = await followLink({c__correlationId: 'deep-open-ended', c__windowStart: LINK_START});
				dateRangeCombobox(element).dispatchEvent(new CustomEvent('change', {detail: {value: String(READER_WINDOW_MINUTES)}}));
				await flushAll();

				const request = await refreshLater(element);

				expect(request.windowMinutes).toBe(READER_WINDOW_MINUTES);
				expect(request.customStart).toBeNull();
				expect(request.customEnd).toBeNull();
			});

			it('leaves a custom end the reader typed after following an open-ended link where they put it', async() =>
			{
				const element = await followLink({c__correlationId: 'deep-edited', c__windowStart: LINK_START});
				// The reader types the To time they want: one minute after the instant the link filled in.
				const readerEnd = new Date(FIRST_LOOK.getTime() + 60000);
				const twoDigits = (value) => String(value).padStart(2, '0');
				setCustomField(element, 'toTime', `${twoDigits(readerEnd.getHours())}:${twoDigits(readerEnd.getMinutes())}:00`);
				await flushAll();

				const request = await refreshLater(element);

				expect(request.customEnd).toBe(readerEnd.toISOString());
				expect(customRangeInstant(element, 'toDate', 'toTime')).toBe(readerEnd.getTime());
			});

			it('stops moving the end once the reader removes the run the open-ended link pinned', async() =>
			{
				const element = await followLink({c__correlationId: 'deep-open-ended', c__windowStart: LINK_START});
				element.shadowRoot.querySelector('[data-testid="correlation-pill"]').dispatchEvent(new CustomEvent('remove'));
				await flushAll();

				const request = await refreshLater(element);

				expect(request.correlationId).toBeNull();
				expect(request.customEnd).toBe(FIRST_LOOK.toISOString());
			});

			it('leaves the end a deep link carried exactly as the link gave it', async() =>
			{
				const element = await followLink({c__correlationId: 'deep-bounded', c__windowStart: LINK_START, c__windowEnd: LINK_END});

				const request = await refreshLater(element);

				expect(request.customStart).toBe(LINK_START);
				expect(request.customEnd).toBe(LINK_END);
				expect(customRangeInstant(element, 'toDate', 'toTime')).toBe(new Date(LINK_END).getTime());
			});
		});

		it('lands a correlation deep link that arrives before the console mounts', async() =>
		{
			const element = createElement('c-log-console', {is: LogConsole});

			// On a real deep link the page reference is delivered by the wire BEFORE connectedCallback
			// runs, so the console must already be correlation-pinned when it first loads: the default
			// problems view must never be queried, or the operator sees the wrong list flash by first.
			CurrentPageReference.emit({state: {c__correlationId: 'deep-premount'}});
			document.body.appendChild(element);
			// Twice: the pill's chain is named through the resolver alongside the first load rather than before it, so
			// the naming read and the list's answers land a tick apart.
			await flushAll();
			await flushAll();

			const request = lastRequestFor(getLogEntries);
			expect(request.correlationId).toBe('deep-premount');
			expect(request.sortField).toBe('createdDate');
			expect(request.windowMinutes).toBe(43200);
			expect(request.pageNumber).toBe(1);
			expect(mockCallControllerMethod.mock.calls.some((call) => call[0] === getLogProblems)).toBe(false);
			// The wire's pre-mount load IS the console's initial load. connectedCallback must not issue a
			// second, identical pair of queries whose results the request-sequence guard only throws away.
			expect(callCountFor(getLogEntries)).toBe(1);
			expect(callCountFor(getEntrySummary)).toBe(1);
			expect(columnFieldNames(element)).toContain('chainDisplay');
			expect(element.shadowRoot.querySelector('[data-testid="correlation-pill"]').label).toContain('deep-premount');
		});

		it('clears the pinned correlation and hides the pill when the pill is removed', async() =>
		{
			const element = await createComponent();
			CurrentPageReference.emit({state: {c__correlationId: 'deep-1'}});
			await flushAll();
			mockCallControllerMethod.mockClear();

			element.shadowRoot.querySelector('[data-testid="correlation-pill"]').dispatchEvent(new CustomEvent('remove'));
			await flushAll();

			expect(lastRequestFor(getLogEntries).correlationId).toBeNull();
			expect(element.shadowRoot.querySelector('[data-testid="correlation-pill"]')).toBeNull();
		});

		it('pins the run again when the address a consumed hand-off was rewritten to comes back, window and all', async() =>
		{
			const element = await createComponent();
			CurrentPageReference.emit({state: {c__correlationId: 'deep-1', c__windowStart: DEEP_LINK_START, c__windowEnd: DEEP_LINK_END, c__viewLogsAt: '1000'}});
			await flushAll();
			await flushAll();
			buttonByLabel(element, 'Clear all').dispatchEvent(new CustomEvent('click'));
			await flushAll();
			expect(element.shadowRoot.querySelector('[data-testid="correlation-pill"]')).toBeNull();
			expect(dateRangeCombobox(element).value).toBe('1440');
			mockCallControllerMethod.mockClear();

			// The plain address the hand-off was rewritten to arrives again, the keys without the stamp: a link someone
			// shared, or Forward onto a later entry carrying it. That address IS the pinned state, so the run comes
			// back with the window it travelled with, however the reader had cleared it since.
			CurrentPageReference.emit({state: {c__correlationId: 'deep-1', c__windowStart: DEEP_LINK_START, c__windowEnd: DEEP_LINK_END}});
			await flushAll();
			await flushAll();

			expect(element.shadowRoot.querySelector('[data-testid="correlation-pill"]').label).toContain('deep-1');
			const request = lastRequestFor(getLogEntries);
			expect(request.correlationId).toBe('deep-1');
			expect(request.customStart).toBe(DEEP_LINK_START);
			expect(request.customEnd).toBe(DEEP_LINK_END);
		});

		it('applies the same chain again when View logs is clicked afresh, because each click carries its own stamp', async() =>
		{
			const element = await createComponent();
			CurrentPageReference.emit({state: {c__correlationId: 'deep-1', c__windowStart: DEEP_LINK_START, c__windowEnd: DEEP_LINK_END, c__viewLogsAt: '1000'}});
			await flushAll();
			element.shadowRoot.querySelector('[data-testid="correlation-pill"]').dispatchEvent(new CustomEvent('remove'));
			await flushAll();
			mockCallControllerMethod.mockClear();

			// The platform re-delivering the SAME hand-off (same stamp) stays ignored ...
			CurrentPageReference.emit({state: {c__correlationId: 'deep-1', c__windowStart: DEEP_LINK_START, c__windowEnd: DEEP_LINK_END, c__viewLogsAt: '1000'}});
			await flushAll();
			expect(mockCallControllerMethod).not.toHaveBeenCalled();

			// ... while a fresh click on View logs for the very same finished chain — same correlation, same window,
			// new stamp — is a new hand-off and pins the correlation again.
			CurrentPageReference.emit({state: {c__correlationId: 'deep-1', c__windowStart: DEEP_LINK_START, c__windowEnd: DEEP_LINK_END, c__viewLogsAt: '2000'}});
			await flushAll();
			expect(lastRequestFor(getLogEntries).correlationId).toBe('deep-1');
			expect(element.shadowRoot.querySelector('[data-testid="correlation-pill"]').label).toContain('deep-1');
		});

		it('still applies a genuinely new deep link after an earlier one was cleared', async() =>
		{
			const element = await createComponent();
			CurrentPageReference.emit({state: {c__correlationId: 'deep-1'}});
			await flushAll();
			element.shadowRoot.querySelector('[data-testid="correlation-pill"]').dispatchEvent(new CustomEvent('remove'));
			await flushAll();
			mockCallControllerMethod.mockClear();

			// Consumed-once is per link, not per console: following View logs on a second chain must pin it.
			CurrentPageReference.emit({state: {c__correlationId: 'deep-2'}});
			await flushAll();

			expect(lastRequestFor(getLogEntries).correlationId).toBe('deep-2');
			expect(element.shadowRoot.querySelector('[data-testid="correlation-pill"]').label).toContain('deep-2');
		});

		it('replaces the handoff URL when the pinned correlation is removed', async() =>
		{
			const element = await createComponent();
			CurrentPageReference.emit({state: {c__correlationId: 'deep-1', c__windowStart: DEEP_LINK_START, c__windowEnd: DEEP_LINK_END}});
			await flushAll();
			mockNavigate.mockClear();

			element.shadowRoot.querySelector('[data-testid="correlation-pill"]').dispatchEvent(new CustomEvent('remove'));
			await flushAll();

			// Clearing the filter has to clear the URL that carries it, or the deep link outlives the clear
			// on the next return to the tab. Replace, not push: the cleared console is not a second history stop.
			expect(mockNavigate).toHaveBeenCalledTimes(1);
			expect(mockNavigate.mock.calls[0][0]).toEqual({type: 'standard__navItemPage', attributes: {apiName: 'LogConsole'}});
			expect(mockNavigate.mock.calls[0][1]).toBe(true);
		});

		it('replaces the handoff URL when Clear all clears the pinned correlation', async() =>
		{
			const element = await createComponent();
			CurrentPageReference.emit({state: {c__correlationId: 'deep-1', c__windowStart: DEEP_LINK_START, c__windowEnd: DEEP_LINK_END}});
			await flushAll();
			mockNavigate.mockClear();

			buttonByLabel(element, 'Clear all').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			expect(mockNavigate).toHaveBeenCalledTimes(1);
			expect(mockNavigate.mock.calls[0][0]).toEqual({type: 'standard__navItemPage', attributes: {apiName: 'LogConsole'}});
			expect(mockNavigate.mock.calls[0][1]).toBe(true);
			expect(element.shadowRoot.querySelector('[data-testid="correlation-pill"]')).toBeNull();
			expect(dateRangeCombobox(element).value).toBe('1440');
		});

		it('rebuilds the replace target from the host page, keeping every non-hand-off state key', async() =>
		{
			const element = await createComponent();
			// The console can be hosted on a subscriber's own app page; clearing the pill must keep the reader
			// THERE, with the host's own URL state intact — only the hand-off's c__ keys are dropped.
			CurrentPageReference.emit({
				type: 'standard__navItemPage',
				attributes: {apiName: 'My_Operations_Workspace'},
				state: {c__correlationId: 'deep-1', c__windowStart: DEEP_LINK_START, c__windowEnd: DEEP_LINK_END, c__viewLogsAt: '1000', c__hostTab: 'monitoring'}
			});
			await flushAll();
			mockNavigate.mockClear();

			element.shadowRoot.querySelector('[data-testid="correlation-pill"]').dispatchEvent(new CustomEvent('remove'));
			await flushAll();

			expect(mockNavigate).toHaveBeenCalledTimes(1);
			expect(mockNavigate.mock.calls[0][0]).toEqual({
				type: 'standard__navItemPage', attributes: {apiName: 'My_Operations_Workspace'}, state: {c__hostTab: 'monitoring'}
			});
			expect(mockNavigate.mock.calls[0][1]).toBe(true);
		});

		it('keeps the remembered host page when the wire delivers an empty reference', async() =>
		{
			const element = await createComponent();
			CurrentPageReference.emit({
				type: 'standard__navItemPage', attributes: {apiName: 'My_Operations_Workspace'}, state: {c__correlationId: 'deep-1'}
			});
			await flushAll();
			// A spurious empty delivery must not make the console forget where it is hosted.
			CurrentPageReference.emit(undefined);
			await flushAll();
			mockNavigate.mockClear();

			element.shadowRoot.querySelector('[data-testid="correlation-pill"]').dispatchEvent(new CustomEvent('remove'));
			await flushAll();

			expect(mockNavigate.mock.calls[0][0]).toEqual({
				type: 'standard__navItemPage', attributes: {apiName: 'My_Operations_Workspace'}, state: {}
			});
		});

		it('rebuilds a bare reference (no attributes, no state) without inventing either', async() =>
		{
			const element = await createComponent();
			CurrentPageReference.emit({type: 'standard__navItemPage', attributes: {apiName: 'LogConsole'}, state: {c__correlationId: 'deep-1'}});
			await flushAll();
			await flushAll();
			expect(element.shadowRoot.querySelector('[data-testid="correlation-pill"]')).toBeTruthy();

			// The platform later reports a reference with neither attributes nor state: an address with no console key
			// pins nothing, so the run is unpinned, and the next address the console writes is rebuilt from exactly what
			// the platform said, empty bags and all.
			CurrentPageReference.emit({type: 'standard__webPage'});
			await flushAll();
			expect(element.shadowRoot.querySelector('[data-testid="correlation-pill"]')).toBeNull();
			wireMockResponses({resolvedSearchId: {kind: 'ACTION', id: ACTION_ID}});
			mockNavigate.mockClear();

			// A pasted action id is the in-place pin available here: the banner's chips belong to an action, and there
			// is none pinned any more.
			jest.useFakeTimers();
			try
			{
				const search = element.shadowRoot.querySelector('.filter-search');
				search.value = ACTION_ID;
				search.dispatchEvent(new CustomEvent('change'));
				jest.advanceTimersByTime(300);
				await flushAll();
				await flushAll();
			}
			finally
			{
				jest.useRealTimers();
			}

			expect(mockNavigate.mock.calls[0][0]).toEqual({type: 'standard__webPage', attributes: {}, state: {c__rootCorrelationId: ACTION_ID}});
			expect(mockNavigate.mock.calls[0][1]).toBe(false);
		});

		it('leaves the URL alone when the console was never deep-linked', async() =>
		{
			const element = await createComponent();
			mockNavigate.mockClear();

			buttonByLabel(element, 'Clear all').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			// A console reached by its own tab has no handoff state to drop; replacing the URL there would
			// rewrite a history entry for nothing.
			expect(mockNavigate).not.toHaveBeenCalled();
		});

		it('clears the filter even when the navigation service refuses the URL replacement', async() =>
		{
			const element = await createComponent();
			CurrentPageReference.emit({state: {c__correlationId: 'deep-1'}});
			await flushAll();
			mockCallControllerMethod.mockClear();
			mockNavigate.mockImplementationOnce(() =>
			{
				throw new Error('navigation service unavailable');
			});

			element.shadowRoot.querySelector('[data-testid="correlation-pill"]').dispatchEvent(new CustomEvent('remove'));
			await flushAll();

			// Tidying the URL is housekeeping; the clear the reader asked for is the point, so a navigation
			// that throws must not take it down with it.
			expect(lastRequestFor(getLogEntries).correlationId).toBeNull();
			expect(element.shadowRoot.querySelector('[data-testid="correlation-pill"]')).toBeNull();
		});
	});

	describe('columns and row decoration', () =>
	{
		it('exposes the documented column set for each view', async() =>
		{
			const element = await createComponent();

			// Both views show the writer in the Source column, so both draw it with the cell type that can put
			// the origin beside the name; both still sort on it.
			const problemSource = table(element).columns.find((column) => column.fieldName === 'sourceDisplay');
			expect(problemSource.type).toBe('writerSource');
			expect(problemSource.sortable).toBe(true);
			expect(problemSource.typeAttributes.originLabel.fieldName).toBe('writerOriginLabel');

			expect(columnFieldNames(element)).toEqual([
				'logNumberDisplay',
				'level',
				'shortMessage',
				'sourceDisplay',
				'contextDisplay',
				'occurrenceCount',
				'lastSeen'
			]);

			buttonByLabel(element, 'Individual entries').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			const entryColumns = table(element).columns;
			const entryCols = entryColumns.map((column) => column.fieldName);
			expect(entryCols).toEqual([
				'logNumberDisplay',
				'createdDate',
				'level',
				'shortMessage',
				'sourceDisplay',
				'contextDisplay',
				'chainDisplay'
			]);
			expect(entryCols).not.toContain('userId');
			expect(entryCols).not.toContain('occurrenceCount');
			// Context resolves to a server-side sort key (executionEvent), so it advertises sortability; Chain is a name
			// and a number the client composed, and sorting on what lies under it would order chains by their UUIDs.
			expect(entryColumns.find((column) => column.fieldName === 'contextDisplay').sortable).toBe(true);
			expect(entryColumns.find((column) => column.fieldName === 'chainDisplay').sortable).toBe(false);
			const entrySource = entryColumns.find((column) => column.fieldName === 'sourceDisplay');
			expect(entrySource.type).toBe('writerSource');
			expect(entrySource.sortable).toBe(true);
			expect(entrySource.typeAttributes.originLabel.fieldName).toBe('writerOriginLabel');
		});

		it('renders the log-number column as a record link', async() =>
		{
			const element = await createComponent();

			// A custom type rather than the standard url one: the standard type renders an empty cell for a
			// grouped problem, which owns no record and so has no number to link.
			const logNumberColumn = table(element).columns.find((column) => column.fieldName === 'logNumberDisplay');
			expect(logNumberColumn.type).toBe('logNumber');
			expect(logNumberColumn.typeAttributes.recordUrl.fieldName).toBe('recordUrl');
		});

		it('carries the tagged pill on the problem column and nowhere in the entries view', async() =>
		{
			const element = await createComponent();

			const problemColumn = table(element).columns.find((column) => column.fieldName === 'shortMessage');
			expect(problemColumn.type).toBe('problemName');
			expect(problemColumn.typeAttributes.isTagged.fieldName).toBe('isTagged');
			// The pill text is a constant, so it rides on the column instead of being copied onto every row.
			expect(problemColumn.typeAttributes.taggedLabel).toBe('Tagged');

			buttonByLabel(element, 'Individual entries').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			// An individual entry is a raw row; provenance is a property of a grouped problem, not of a log line.
			expect(table(element).columns.find((column) => column.fieldName === 'shortMessage').type).toBe('text');
		});

		it('humanises the execution context and builds the source and record link per row', async() =>
		{
			// A Flow writes under a bridge class, so its stored location is text the class and method could
			// never compose: it is the row that tells the two apart. The same for the Mixed row, whose stored
			// location names a different class from the one the wire recorded.
			const stored = {...PROBLEM_ROWS[0], writerName: 'Order Intake', writerOrigin: 'FLOW', writerLocation: 'Order Intake.Decide:12'};
			const mixed = {...PROBLEM_ROWS[1], writerName: 'Breaker', writerOrigin: 'MIXED', writerLocation: 'CircuitBreaker.guard:9'};
			const unmappedOrigin = {...PROBLEM_ROWS[1], id: '001p4', writerName: 'Agent', writerOrigin: 'AGENT', writerLocation: 'Agent.reply:7'};
			const withoutWriter = {...PROBLEM_ROWS[1], id: '001p3'};
			// The logger stamps an origin on every entry and a writer's name only when it knew the class and
			// method behind it, so this row has an origin and nobody to show it beside.
			const originOnly = {...PROBLEM_ROWS[1], id: '001p5', writerOrigin: 'APEX'};
			wireMockResponses({
				problems: {
					...MOCK_PROBLEM_PAGE, records: [
						stored,
						mixed,
						unmappedOrigin,
						withoutWriter,
						originOnly
					]
				}
			});
			const element = await createComponent();

			const rows = table(element).data;
			// The Source cell shows the location the entry stored for its writer, and names who that writer was
			// beside it. The origin travels as its readable label, so the cell never shows a raw enum value.
			expect(rows[0].contextDisplay).toBe('Batch Apex');
			expect(rows[0].sourceDisplay).toBe('Order Intake.Decide:12');
			expect(rows[0].writerOriginLabel).toBe('Flow');
			expect(rows[0].recordUrl).toBe('/lightning/r/001p1/view');
			// A problem folded from rows written under more than one origin reads Mixed, the same word the
			// Top sources card uses for it, and still shows the location it stored rather than its class text.
			expect(rows[1].sourceDisplay).toBe('CircuitBreaker.guard:9');
			expect(rows[1].writerOriginLabel).toBe('Mixed');
			// An origin the console has no name for still has to reach the cell, exactly as an unmapped
			// execution context does: a row that says nothing about who wrote it reads as data gone missing.
			expect(rows[2].sourceDisplay).toBe('Agent.reply:7');
			expect(rows[2].writerOriginLabel).toBe('AGENT');
			// A row that stored no writer reads exactly as it did before, and has nothing to put in a pill.
			expect(rows[3].sourceDisplay).toBe('Breaker.guard:9');
			expect(rows[3].writerOriginLabel).toBeNull();
			// A row that stored an origin but no writer's name reads the same way: the pill says who wrote the
			// name beside it, so with no name shown there is nothing for it to describe.
			expect(rows[4].sourceDisplay).toBe('Breaker.guard:9');
			expect(rows[4].writerOriginLabel).toBeNull();
		});

		it('keeps the wire provenance intact beside the class and method string', async() =>
		{
			wireMockResponses({problems: {...MOCK_PROBLEM_PAGE, records: [{...PROBLEM_ROWS[0], source: 'derived'}]}});
			const element = await createComponent();

			// The wire's source is the problem's provenance ('rollup' or 'derived'). The row spread must not
			// overwrite it with the display string the Source column renders, or the client can never tell a
			// grouped problem from a tagged one.
			const firstRow = table(element).data[0];
			expect(firstRow.source).toBe('derived');
			expect(firstRow.sourceDisplay).toBe('AcctHandler.run:42');
		});

		it('gives a derived problem no record link rather than a link to a null id', async() =>
		{
			wireMockResponses({problems: {...MOCK_PROBLEM_PAGE, records: [{...PROBLEM_ROWS[0], id: null, source: 'derived'}]}});
			const element = await createComponent();

			// A derived problem is grouped at read time and has no LogEntry__c of its own to open.
			expect(table(element).data[0].recordUrl).toBeNull();
		});

		it('decorates a class-only row (no method line) with the bare class name', async() =>
		{
			wireMockResponses({problems: {...MOCK_PROBLEM_PAGE, records: [{...PROBLEM_ROWS[0], methodLine: null}]}});
			const element = await createComponent();

			expect(table(element).data[0].sourceDisplay).toBe('AcctHandler');
		});

		it('shows the raw execution event when the context is not one the console has a name for', async() =>
		{
			wireMockResponses({problems: {...MOCK_PROBLEM_PAGE, records: [{...PROBLEM_ROWS[0], executionEvent: 'INVOCABLE_ACTION'}]}});
			const element = await createComponent();

			// An unmapped Quiddity must still render its raw value rather than an empty Context cell.
			expect(table(element).data[0].contextDisplay).toBe('INVOCABLE_ACTION');
		});

		it('maps synthesised/url columns back to their real controller sort keys', async() =>
		{
			const element = await createComponent();

			mockCallControllerMethod.mockClear();
			table(element).dispatchEvent(new CustomEvent('sort', {detail: {fieldName: 'sourceDisplay', sortDirection: 'asc'}}));
			await flushAll();
			// The column shows the writer the entry stored, so that is what the server orders on; sorting on the
			// class name would order the list by something the cell no longer shows.
			expect(lastRequestFor(getLogProblems).sortField).toBe('writerName');
			// the sort-arrow indicator stays on the Source column, not the wire key
			expect(table(element).sortedBy).toBe('sourceDisplay');

			mockCallControllerMethod.mockClear();
			table(element).dispatchEvent(new CustomEvent('sort', {detail: {fieldName: 'logNumberDisplay', sortDirection: 'desc'}}));
			await flushAll();
			expect(lastRequestFor(getLogProblems).sortField).toBe('logNumber');

			mockCallControllerMethod.mockClear();
			table(element).dispatchEvent(new CustomEvent('sort', {detail: {fieldName: 'contextDisplay', sortDirection: 'asc'}}));
			await flushAll();
			expect(lastRequestFor(getLogProblems).sortField).toBe('executionEvent');
		});

		it('reloads with the new sort when the table dispatches sort', async() =>
		{
			const element = await createComponent();
			mockCallControllerMethod.mockClear();

			table(element).dispatchEvent(new CustomEvent('sort', {detail: {fieldName: 'lastSeen', sortDirection: 'asc'}}));
			await flushAll();

			const request = lastRequestFor(getLogProblems);
			expect(request.sortField).toBe('lastSeen');
			expect(request.sortAscending).toBe(true);
		});

		it('exposes the level-toggle pressed state to assistive technology', async() =>
		{
			const element = await createComponent();
			expect(levelButton(element, 'ERROR').getAttribute('aria-pressed')).toBe('true');
			expect(levelButton(element, 'INFO').getAttribute('aria-pressed')).toBe('false');

			levelButton(element, 'INFO').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			expect(levelButton(element, 'INFO').getAttribute('aria-pressed')).toBe('true');
		});
	});

	describe('sort persistence and continuity', () =>
	{
		// Puts the console on a non-default sort (Last seen, ascending; the defaults are occurrence
		// count, descending) AND past page one, so the assertions each test then makes about the sort
		// surviving and the page resetting to one cannot pass by accident.
		async function sortByLastSeenThenTurnToPageTwo(element)
		{
			table(element).dispatchEvent(new CustomEvent('sort', {detail: {fieldName: 'lastSeen', sortDirection: 'asc'}}));
			await flushAll();
			await turnToNextPage(element);
		}

		it('keeps the chosen sort when a level filter is toggled', async() =>
		{
			wirePagedResponses(3);
			const element = await createComponent();
			await sortByLastSeenThenTurnToPageTwo(element);
			expect(lastRequestFor(getLogProblems).pageNumber).toBe(2);
			mockCallControllerMethod.mockClear();

			levelButton(element, 'INFO').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			// A filter change resets the page but must not silently throw away the operator's sort.
			const request = lastRequestFor(getLogProblems);
			expect(request.sortField).toBe('lastSeen');
			expect(request.sortAscending).toBe(true);
			expect(request.pageNumber).toBe(1);
			expect(request.levels).toContain('INFO');
			expect(table(element).sortedBy).toBe('lastSeen');
		});

		it('keeps the chosen sort when the execution context filter changes', async() =>
		{
			wirePagedResponses(3);
			const element = await createComponent();
			await sortByLastSeenThenTurnToPageTwo(element);
			expect(lastRequestFor(getLogProblems).pageNumber).toBe(2);
			mockCallControllerMethod.mockClear();

			element.shadowRoot.querySelector('.filter-combobox').dispatchEvent(new CustomEvent('change', {detail: {value: 'QUEUEABLE'}}));
			await flushAll();

			const request = lastRequestFor(getLogProblems);
			expect(request.sortField).toBe('lastSeen');
			expect(request.sortAscending).toBe(true);
			expect(request.pageNumber).toBe(1);
			expect(request.executionEvents).toEqual(['QUEUEABLE']);
		});

		it('keeps the chosen sort when a search term settles', async() =>
		{
			jest.useFakeTimers();
			try
			{
				wirePagedResponses(3);
				const element = await createComponent();
				await sortByLastSeenThenTurnToPageTwo(element);
				expect(lastRequestFor(getLogProblems).pageNumber).toBe(2);
				mockCallControllerMethod.mockClear();

				const search = element.shadowRoot.querySelector('.filter-search');
				search.value = 'timeout';
				search.dispatchEvent(new CustomEvent('change'));
				jest.advanceTimersByTime(300);
				await flushAll();

				const request = lastRequestFor(getLogProblems);
				expect(request.searchTerm).toBe('timeout');
				expect(request.sortField).toBe('lastSeen');
				expect(request.sortAscending).toBe(true);
				expect(request.pageNumber).toBe(1);
			}
			finally
			{
				jest.useRealTimers();
			}
		});

		it('keeps the chosen sort when the date range changes', async() =>
		{
			wirePagedResponses(3);
			const element = await createComponent();
			await sortByLastSeenThenTurnToPageTwo(element);
			expect(lastRequestFor(getLogProblems).pageNumber).toBe(2);
			mockCallControllerMethod.mockClear();

			dateRangeCombobox(element).dispatchEvent(new CustomEvent('change', {detail: {value: '10080'}}));
			await flushAll();

			const request = lastRequestFor(getLogProblems);
			expect(request.sortField).toBe('lastSeen');
			expect(request.sortAscending).toBe(true);
			expect(request.pageNumber).toBe(1);
			expect(request.windowMinutes).toBe(SEVEN_DAY_WINDOW_MINUTES);
		});

		it('keeps the chosen entries-view sort when a level filter is toggled', async() =>
		{
			wirePagedResponses(3);
			const element = await createComponent();
			buttonByLabel(element, 'Individual entries').dispatchEvent(new CustomEvent('click'));
			await flushAll();
			table(element).dispatchEvent(new CustomEvent('sort', {detail: {fieldName: 'shortMessage', sortDirection: 'asc'}}));
			await flushAll();
			await turnToNextPage(element);
			expect(lastRequestFor(getLogEntries).pageNumber).toBe(2);
			mockCallControllerMethod.mockClear();

			levelButton(element, 'INFO').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			const request = lastRequestFor(getLogEntries);
			expect(request.sortField).toBe('shortMessage');
			expect(request.sortAscending).toBe(true);
			expect(request.pageNumber).toBe(1);
			expect(request.levels).toContain('INFO');
		});

		it('shows the sort indicator in the direction the last sort event carried', async() =>
		{
			const element = await createComponent();
			expect(table(element).sortedBy).toBe('level');
			expect(table(element).sortedDirection).toBe('desc');

			table(element).dispatchEvent(new CustomEvent('sort', {detail: {fieldName: 'lastSeen', sortDirection: 'asc'}}));
			await flushAll();
			expect(table(element).sortedBy).toBe('lastSeen');
			expect(table(element).sortedDirection).toBe('asc');
			expect(lastRequestFor(getLogProblems).sortAscending).toBe(true);

			table(element).dispatchEvent(new CustomEvent('sort', {detail: {fieldName: 'lastSeen', sortDirection: 'desc'}}));
			await flushAll();
			expect(table(element).sortedDirection).toBe('desc');
			expect(lastRequestFor(getLogProblems).sortAscending).toBe(false);
		});

		it('re-sends the chosen sort with the next page the pager asks for', async() =>
		{
			wirePagedResponses(3);
			const element = await createComponent();
			table(element).dispatchEvent(new CustomEvent('sort', {detail: {fieldName: 'sourceDisplay', sortDirection: 'asc'}}));
			await flushAll();
			expect(lastRequestFor(getLogProblems).pageNumber).toBe(1);
			mockCallControllerMethod.mockClear();

			await turnToNextPage(element);

			// The next page must continue the same ordering, or page two is a slice of a different
			// sequence and the list stops being one sorted list read a page at a time.
			const request = lastRequestFor(getLogProblems);
			expect(request.sortField).toBe('writerName');
			expect(request.sortAscending).toBe(true);
			expect(request.pageNumber).toBe(2);
			// The page replaces the rows rather than adding to them: page two's row, and only it.
			expect(table(element).data.map((row) => row.logNumber)).toEqual(['L-102']);
		});

		it('sends the server sort key for the entries-view Source and Context columns', async() =>
		{
			const element = await createComponent();
			buttonByLabel(element, 'Individual entries').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			mockCallControllerMethod.mockClear();
			table(element).dispatchEvent(new CustomEvent('sort', {detail: {fieldName: 'sourceDisplay', sortDirection: 'asc'}}));
			await flushAll();
			expect(lastRequestFor(getLogEntries).sortField).toBe('writerName');
			expect(table(element).sortedBy).toBe('sourceDisplay');

			mockCallControllerMethod.mockClear();
			table(element).dispatchEvent(new CustomEvent('sort', {detail: {fieldName: 'contextDisplay', sortDirection: 'desc'}}));
			await flushAll();

			// The Context column shows a humanised label, so the server has to be told to sort on the
			// raw execution event; the arrow stays on the column the operator clicked.
			expect(lastRequestFor(getLogEntries).sortField).toBe('executionEvent');
			expect(lastRequestFor(getLogEntries).sortAscending).toBe(false);
			expect(table(element).sortedBy).toBe('contextDisplay');
		});

		it('takes the first click on Level to the most severe end, then toggles from there', async() =>
		{
			// A datatable proposes ascending for a column it has not sorted before, and ascending on a
			// picklist is declared order — DEBUG first. Clicking Level to find errors filled the list with
			// the least severe rows and only reached errors on a second click.
			const element = await createComponent();
			buttonByLabel(element, 'Individual entries').dispatchEvent(new CustomEvent('click'));
			await flushAll();
			mockCallControllerMethod.mockClear();

			table(element).dispatchEvent(new CustomEvent('sort', {detail: {fieldName: 'level', sortDirection: 'asc'}}));
			await flushAll();
			expect(lastRequestFor(getLogEntries).sortField).toBe('level');
			expect(lastRequestFor(getLogEntries).sortAscending).toBe(false);
			expect(table(element).sortedDirection).toBe('desc');

			mockCallControllerMethod.mockClear();
			table(element).dispatchEvent(new CustomEvent('sort', {detail: {fieldName: 'level', sortDirection: 'asc'}}));
			await flushAll();

			// Only the FIRST click is redirected; the column then behaves like any other.
			expect(lastRequestFor(getLogEntries).sortAscending).toBe(true);
			expect(table(element).sortedDirection).toBe('asc');
		});

		it('leaves a text column ascending on its first click', async() =>
		{
			const element = await createComponent();
			buttonByLabel(element, 'Individual entries').dispatchEvent(new CustomEvent('click'));
			await flushAll();
			mockCallControllerMethod.mockClear();

			table(element).dispatchEvent(new CustomEvent('sort', {detail: {fieldName: 'shortMessage', sortDirection: 'asc'}}));
			await flushAll();

			expect(lastRequestFor(getLogEntries).sortField).toBe('shortMessage');
			expect(lastRequestFor(getLogEntries).sortAscending).toBe(true);
		});
	});

	describe('summary cards', () =>
	{
		it('renders the total, a card per active level, and the top-sources card in the problems view', async() =>
		{
			const element = await createComponent();

			const cards = element.shadowRoot.querySelectorAll('[data-testid="summary-card"]');
			expect(cards.length).toBe(4);
			const totalCard = cards[0];
			expect(totalCard.querySelector('lightning-formatted-number').value).toBe(MOCK_SUMMARY.totalOccurrences);
			expect(totalCard.textContent).toContain('2 distinct shown');
		});

		it('badges the ribbon total as approximate when the server folded a capped rollup window', async() =>
		{
			wireMockResponses({summary: {...MOCK_SUMMARY, totalsApproximate: true}});
			const element = await createComponent();

			const badge = element.shadowRoot.querySelector('[data-testid="totals-approximate"]');
			expect(badge).not.toBeNull();
			expect(badge.textContent).toContain('Totals approximate');
			// The explanation rides on a help component, not a title attribute: a title reaches neither a
			// keyboard nor a touch device, which is every reader who does not hover.
			expect(badge.getAttribute('title')).toBeNull();
			expect(element.shadowRoot.querySelector('[data-testid="totals-approximate-help"]').content).toContain('may be higher');
		});

		it('renders no approximate badge when the summary totals are exact', async() =>
		{
			const element = await createComponent();

			expect(element.shadowRoot.querySelector('[data-testid="totals-approximate"]')).toBeNull();
		});

		it('renders the ranked top sources as click-to-drill rows that name their origin', async() =>
		{
			const element = await createComponent();

			const sourceRows = element.shadowRoot.querySelectorAll('[data-testid="source-row"]');
			expect(sourceRows.length).toBe(MOCK_SUMMARY.topSources.length);
			expect(sourceRows[0].textContent).toContain('AcctHandler');
			expect(sourceRows[0].textContent).toContain('93%');
			expect(sourceRows[0].dataset.origin).toBe('APEX');
			expect(sourceRows[0].querySelector('.origin').textContent).toBe('Apex');
			expect(sourceRows[1].querySelector('.origin').textContent).toBe('Framework');
		});

		it('offers every origin the console knows, in order, on the Origin filter', async() =>
		{
			const element = await createComponent();

			const labels = element.shadowRoot.querySelector('[data-spec-id="origin-filter"]').options.map((option) => option.label);
			expect(labels).toEqual([
				'All origins',
				'Framework',
				'Apex',
				'Flow',
				'Component'
			]);
		});

		it('drills into a source when a top-source row is clicked', async() =>
		{
			const element = await createComponent();
			mockCallControllerMethod.mockClear();

			element.shadowRoot.querySelector('[data-testid="source-row"]').click();
			await flushAll();

			expect(lastRequestFor(getLogProblems).searchTerm).toBeNull();
			expect(lastRequestFor(getLogProblems).source).toBe('AcctHandler');
			expect(lastRequestFor(getLogProblems).origins).toEqual(['APEX']);
		});

		it('ignores a source-row click that carries no source name', async() =>
		{
			const element = await createComponent();
			mockCallControllerMethod.mockClear();

			const row = element.shadowRoot.querySelector('[data-testid="source-row"]');
			row.removeAttribute('data-source');
			row.click();
			await flushAll();

			expect(mockCallControllerMethod).not.toHaveBeenCalled();
		});

		it('pins a drilled source as a removable pill and clears the pin when the pill is removed', async() =>
		{
			const element = await createComponent();
			element.shadowRoot.querySelector('[data-testid="source-row"]').click();
			await flushAll();

			const pill = element.shadowRoot.querySelector('[data-testid="source-filter-pill"]');
			expect(pill.label).toContain('AcctHandler');
			mockCallControllerMethod.mockClear();
			pill.dispatchEvent(new CustomEvent('remove'));
			await flushAll();

			expect(lastRequestFor(getLogProblems).source).toBeNull();
			expect(lastRequestFor(getLogProblems).origins).toEqual(['APEX']);
			expect(element.shadowRoot.querySelector('[data-spec-id="origin-filter"]').value).toBe('APEX');
		});

		it('keeps the pinned writer and its origin on the request when a search term is typed after the drill', async() =>
		{
			jest.useFakeTimers();
			try
			{
				const element = await createComponent();
				element.shadowRoot.querySelector('[data-testid="source-row"]').click();
				await flushAll();
				mockCallControllerMethod.mockClear();

				const search = element.shadowRoot.querySelector('lightning-input');
				search.value = 'timeout';
				search.dispatchEvent(new CustomEvent('change'));
				jest.advanceTimersByTime(300);
				await flushAll();

				const request = lastRequestFor(getLogProblems);
				expect(request.searchTerm).toBe('timeout');
				expect(request.source).toBe('AcctHandler');
				expect(request.origins).toEqual(['APEX']);
			}
			finally
			{
				jest.useRealTimers();
			}
		});

		it('returns the Origin filter and the pinned writer to their defaults on Clear all', async() =>
		{
			const element = await createComponent();
			element.shadowRoot.querySelector('[data-testid="source-row"]').click();
			await flushAll();
			mockCallControllerMethod.mockClear();

			buttonByLabel(element, 'Clear all').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			const request = lastRequestFor(getLogProblems);
			expect(request.origins).toEqual([]);
			expect(request.source).toBeNull();
			expect(element.shadowRoot.querySelector('[data-spec-id="origin-filter"]').value).toBe('');
		});

		it('drills a Mixed source by name alone, leaving the Origin filter on every origin', async() =>
		{
			wireMockResponses({summary: {...MOCK_SUMMARY, topSources: [{name: 'AcctHandler', origin: 'MIXED', count: 1284, percent: 93}]}});
			const element = await createComponent();
			element.shadowRoot.querySelector('[data-testid="source-row"]').click();
			await flushAll();

			expect(lastRequestFor(getLogProblems).source).toBe('AcctHandler');
			expect(lastRequestFor(getLogProblems).origins).toEqual([]);
			expect(element.shadowRoot.querySelector('[data-testid="source-row"] .origin').textContent).toBe('Mixed');
		});

		it('narrows the list to one origin from the Origin filter and clears it on a deep link', async() =>
		{
			const element = await createComponent();
			mockCallControllerMethod.mockClear();
			element.shadowRoot.querySelector('[data-spec-id="origin-filter"]').dispatchEvent(new CustomEvent('change', {detail: {value: 'FLOW'}}));
			await flushAll();

			expect(lastRequestFor(getLogProblems).origins).toEqual(['FLOW']);

			CurrentPageReference.emit({state: {c__correlationId: 'deep-origin'}});
			await flushAll();
			expect(lastRequestFor(getLogEntries).origins).toEqual([]);
			expect(element.shadowRoot.querySelector('[data-spec-id="origin-filter"]').value).toBe('');
		});

		it('filters to a single level when a per-level card is clicked', async() =>
		{
			const element = await createComponent();
			mockCallControllerMethod.mockClear();

			const errorCard = Array.from(element.shadowRoot.querySelectorAll('[data-testid="summary-card"]')).find((card) => card.dataset.level === 'ERROR');
			errorCard.click();
			await flushAll();

			const request = lastRequestFor(getLogProblems);
			expect(request.levels).toEqual(['ERROR']);
			expect(request.pageNumber).toBe(1);
		});

		it('renders the entries ribbon from the row-count aggregate in the entries view', async() =>
		{
			const element = await createComponent();
			buttonByLabel(element, 'Individual entries').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			const cards = element.shadowRoot.querySelectorAll('[data-testid="summary-card"]');
			const totalCard = cards[0];
			expect(totalCard.querySelector('lightning-formatted-number').value).toBe(MOCK_ENTRY_SUMMARY.totalRows);
			expect(totalCard.textContent).toContain('log rows');
			const sourceRows = element.shadowRoot.querySelectorAll('[data-testid="source-row"]');
			expect(sourceRows[0].textContent).toContain('30 rows');
		});

		it('renders the top-sources card with no rows when there are no top sources', async() =>
		{
			wireMockResponses({summary: {...MOCK_SUMMARY, topSources: []}});
			const element = await createComponent();

			expect(element.shadowRoot.querySelectorAll('[data-testid="source-row"]').length).toBe(0);
			expect(element.shadowRoot.querySelectorAll('[data-testid="summary-card"]').length).toBe(4);
		});

		it('renders the problems ribbon safely when the summary omits its counts and lists', async() =>
		{
			wireMockResponses({summary: {}});
			const element = await createComponent();

			const cards = element.shadowRoot.querySelectorAll('[data-testid="summary-card"]');
			// Total card, a zero card for each active level, and the (empty) top-sources card.
			expect(cards.length).toBe(4);
			expect(cards[0].querySelector('lightning-formatted-number').value).toBe(0);
			expect(Array.from(cards).filter((card) => card.dataset.level).every((card) => card.querySelector('lightning-formatted-number').value === 0)).toBe(true);
			expect(element.shadowRoot.querySelectorAll('[data-testid="source-row"]').length).toBe(0);
		});

		it('renders the entries ribbon safely when the row-count aggregate omits its fields', async() =>
		{
			wireMockResponses({entrySummary: {}});
			const element = await createComponent();
			buttonByLabel(element, 'Individual entries').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			const cards = element.shadowRoot.querySelectorAll('[data-testid="summary-card"]');
			expect(cards.length).toBe(4);
			expect(cards[0].querySelector('lightning-formatted-number').value).toBe(0);
		});

		it('withholds the level and source cards when the server declined the breakdown, and says why', async() =>
		{
			// A range past the ribbon's scan ceiling: the server declines the two aggregates and answers with the
			// exact total its pre-flight count measured. Level cards at zero would be false — the rows exist, they
			// are just not broken down — so only the total renders, with the note saying what to narrow.
			wireMockResponses({entrySummary: {totalRows: 48000, perLevel: [], topSources: [], declined: true}});
			const element = await createComponent();
			buttonByLabel(element, 'Individual entries').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			const cards = element.shadowRoot.querySelectorAll('[data-testid="summary-card"]');
			expect(cards.length).toBe(1);
			expect(cards[0].querySelector('lightning-formatted-number').value).toBe(48000);
			expect(element.shadowRoot.querySelectorAll('[data-testid="source-row"]').length).toBe(0);
			expect(element.shadowRoot.querySelector('[data-testid="entry-summary-declined"]').textContent).toContain('too many entries');
		});

		it('shows no declined note when the breakdown ran, in either view', async() =>
		{
			const element = await createComponent();
			expect(element.shadowRoot.querySelector('[data-testid="entry-summary-declined"]')).toBeNull();

			buttonByLabel(element, 'Individual entries').dispatchEvent(new CustomEvent('click'));
			await flushAll();
			expect(element.shadowRoot.querySelector('[data-testid="entry-summary-declined"]')).toBeNull();
		});

		it('never shows the declined note over the problems ribbon, even while a declined entries summary lingers', async() =>
		{
			// The summary object is shared between views: switching entries → problems paints the problems ribbon
			// at once while the declined entries DTO still stands in summary until the reload lands. The note is
			// entries-view vocabulary and must not dress the problems ribbon for that round trip.
			wireMockResponses({summary: {...MOCK_SUMMARY, declined: true}});
			const element = await createComponent();

			expect(element.shadowRoot.querySelector('[data-testid="entry-summary-declined"]')).toBeNull();
			expect(element.shadowRoot.querySelectorAll('[data-testid="summary-card"]').length).toBe(4);
		});

		it('renders a zero-valued level card when the per-level rollup omits its counts', async() =>
		{
			wireMockResponses({problems: GROUPED_PROBLEM_PAGE, summary: {...MOCK_SUMMARY, perLevel: [{level: 'ERROR'}]}});
			const element = await createComponent();

			const errorCard = Array.from(element.shadowRoot.querySelectorAll('[data-testid="summary-card"]')).find((card) => card.dataset.level === 'ERROR');
			expect(errorCard.querySelector('lightning-formatted-number').value).toBe(0);
			expect(errorCard.querySelector('.footnote').textContent).toBe('0 distinct');
		});

		it('says a level card counts tagged problems alone when grouping did not cover that level', async() =>
		{
			// The fold ran, but only over ERROR. A WARN card built from it counts the problems a developer
			// tagged in code and nothing else, and a bare zero there reads as a level with nothing wrong in
			// it — on an org whose entries view plainly lists thousands of WARN rows.
			wireMockResponses({problems: {...GROUPED_PROBLEM_PAGE, derivedLevelScope: ['ERROR']}, summary: MOCK_SUMMARY});
			const element = await createComponent();

			const cards = Array.from(element.shadowRoot.querySelectorAll('[data-testid="summary-card"]'));
			expect(cards.find((card) => card.dataset.level === 'ERROR').querySelector('.footnote').textContent).not.toContain('tagged only');
			expect(cards.find((card) => card.dataset.level === 'WARN').querySelector('.footnote').textContent).toContain('(tagged only)');
		});

		it('keeps a card for an active level the window holds no rows for, at zero', async() =>
		{
			wireMockResponses({problems: GROUPED_PROBLEM_PAGE, summary: {...MOCK_SUMMARY, perLevel: [{level: 'ERROR', occurrences: 1284, distinctCount: 1}]}});
			const element = await createComponent();

			// One card per ACTIVE level is the ribbon's locked invariant (Total = their sum): a level
			// with nothing in the window reads zero rather than losing its card.
			const cards = Array.from(element.shadowRoot.querySelectorAll('[data-testid="summary-card"]'));
			expect(cards.filter((card) => card.dataset.level).length).toBe(2);
			const warnCard = cards.find((card) => card.dataset.level === 'WARN');
			expect(warnCard.querySelector('lightning-formatted-number').value).toBe(0);
			expect(warnCard.querySelector('.footnote').textContent).toBe('0 distinct');
		});

		it('keeps a card for an active level with no rows in the entries ribbon, at zero', async() =>
		{
			wireMockResponses({entrySummary: {...MOCK_ENTRY_SUMMARY, perLevel: [{level: 'ERROR', rowCount: 30}]}});
			const element = await createComponent();
			buttonByLabel(element, 'Individual entries').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			const cards = Array.from(element.shadowRoot.querySelectorAll('[data-testid="summary-card"]'));
			expect(cards.filter((card) => card.dataset.level).length).toBe(2);
			const warnCard = cards.find((card) => card.dataset.level === 'WARN');
			expect(warnCard.querySelector('lightning-formatted-number').value).toBe(0);
			expect(warnCard.querySelector('.footnote').textContent).toBe('rows');
		});

		it('gives a newly activated level its own card before any rows arrive for it', async() =>
		{
			const element = await createComponent();
			expect(Array.from(element.shadowRoot.querySelectorAll('[data-testid="summary-card"]')).some((card) => card.dataset.level === 'INFO')).toBe(false);

			levelButton(element, 'INFO').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			const infoCard = Array.from(element.shadowRoot.querySelectorAll('[data-testid="summary-card"]')).find((card) => card.dataset.level === 'INFO');
			expect(infoCard).not.toBeUndefined();
			expect(infoCard.querySelector('lightning-formatted-number').value).toBe(0);
		});

		it('orders the level cards by severity, not by the order the rollup returned them', async() =>
		{
			wireMockResponses({
				summary: {
					...MOCK_SUMMARY, perLevel: [
						{level: 'WARN', occurrences: 96, distinctCount: 1},
						{level: 'ERROR', occurrences: 1284, distinctCount: 1}
					]
				}
			});
			const element = await createComponent();

			const levels = Array.from(element.shadowRoot.querySelectorAll('[data-testid="summary-card"]')).map((card) => card.dataset.level).filter(Boolean);
			expect(levels).toEqual([
				'ERROR',
				'WARN'
			]);
		});

		it('clears the ribbon when a later summary load returns nothing', async() =>
		{
			const element = await createComponent();
			expect(element.shadowRoot.querySelectorAll('[data-testid="summary-card"]').length).toBe(4);

			mockCallControllerMethod.mockImplementation((apexFn) => Promise.resolve(apexFn === getLogSummary ? undefined : MOCK_PROBLEM_PAGE));
			buttonByLabel(element, 'Refresh').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			// A failed aggregate must blank the ribbon rather than leave the previous window's totals on screen.
			expect(element.shadowRoot.querySelectorAll('[data-testid="summary-card"]').length).toBe(0);
			expect(table(element).data.length).toBe(2);
		});
	});

	describe('counting words and unreadable counts', () =>
	{
		it('agrees the row word with the number in front of it', async() =>
		{
			wireMockResponses({
				entrySummary: {
					...MOCK_ENTRY_SUMMARY, totalRows: 1, perLevel: [{level: 'ERROR', rowCount: 1}], topSources: [
						{name: 'Chain', count: 1, percent: 100},
						{name: 'Breaker', count: 12, percent: 0}
					]
				}
			});
			const element = await createComponent();
			buttonByLabel(element, 'Individual entries').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			const metrics = Array.from(element.shadowRoot.querySelectorAll('[data-testid="source-row"] .metric')).map((metric) => metric.textContent);
			expect(metrics).toEqual([
				'1 row',
				'12 rows'
			]);
			const cards = Array.from(element.shadowRoot.querySelectorAll('[data-testid="summary-card"]'));
			expect(cards.find((card) => card.dataset.level === 'ERROR').querySelector('.footnote').textContent).toBe('row');
			expect(cards.find((card) => !card.dataset.level).querySelector('.footnote').textContent).toBe('log row');
		});

		it('prints a plain number when the platform cannot group one in the reader\'s language', async() =>
		{
			// Same guard as the level-list join, for the same reason: the number is composed inside a render
			// getter, where a RangeError from an unrecognised language tag would take the banner down.
			const numberFormat = jest.spyOn(Intl, 'NumberFormat').mockImplementation(() =>
			{
				throw new RangeError('Incorrect locale information provided');
			});
			try
			{
				wireMockResponses({problems: {...MOCK_PROBLEM_PAGE, totalCount: 2000, resultsTruncated: true}});
				const element = await createComponent();

				expect(element.shadowRoot.querySelector('[data-testid="capped-banner"]').textContent).toContain('2000');
			}
			finally
			{
				numberFormat.mockRestore();
			}
		});

		it('asks for its list and count reads silently, because both failures are reported in the page', async() =>
		{
			// An Aura error toast is sticky, and these are the failures a reader recovers from by changing a
			// filter — so the toast outlived the failure, sitting over a list that had since loaded, and
			// carried a raw platform message nobody can act on. Every other call keeps its toast.
			const element = await createComponent();
			await selectRow(element, '001p1');

			const silentFor = (apexFn) => mockCallControllerMethod.mock.calls.filter((call) => call[0] === apexFn).map((call) => call[2]);
			expect(silentFor(getLogProblems)).toEqual([{silent: true}]);
			expect(silentFor(getLogSummary)).toEqual([{silent: true}]);
			// The drawer reads have no in-page failure state to land in, so they keep the toast.
			expect(silentFor(getLogEntryDetail)).toEqual([undefined]);
			expect(element.shadowRoot.querySelector('[data-testid="detail-panel"]')).not.toBeNull();
		});

		it('says the counts could not be read rather than drawing an empty ribbon', async() =>
		{
			// A ribbon with nothing in it looks exactly like a window with no activity, and the console
			// would otherwise report a failed count as a quiet blank strip above a populated list.
			mockCallControllerMethod.mockImplementation((apexFn) => Promise.resolve(apexFn === getLogSummary ? undefined : MOCK_PROBLEM_PAGE));
			const element = await createComponent();

			const note = element.shadowRoot.querySelector('[data-testid="summary-load-failed"]');
			expect(note).not.toBeNull();
			expect(note.getAttribute('role')).toBe('status');
			expect(element.shadowRoot.querySelectorAll('[data-testid="summary-card"]').length).toBe(0);
		});

		it('takes the unreadable-counts note back down once a load succeeds', async() =>
		{
			mockCallControllerMethod.mockImplementation((apexFn) => Promise.resolve(apexFn === getLogSummary ? undefined : MOCK_PROBLEM_PAGE));
			const element = await createComponent();
			expect(element.shadowRoot.querySelector('[data-testid="summary-load-failed"]')).not.toBeNull();

			wireMockResponses();
			buttonByLabel(element, 'Refresh').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			expect(element.shadowRoot.querySelector('[data-testid="summary-load-failed"]')).toBeNull();
		});
	});

	describe('keyboard and focus', () =>
	{
		it('moves focus into the drawer as soon as a row opens it', async() =>
		{
			// Every loaded row's Log Number link is its own tab stop, so on a scrolled list the drawer was
			// thousands of stops away; landing on the panel puts the drawer's own controls next.
			const element = await createComponent();
			await selectRow(element, '001p1');

			expect(element.shadowRoot.activeElement?.dataset.testid).toBe('detail-panel');
		});

		it('closes the drawer on Escape and returns focus to the list', async() =>
		{
			const element = await createComponent();
			await selectRow(element, '001p1');

			element.shadowRoot.querySelector('.log-console').dispatchEvent(new KeyboardEvent('keydown', {bubbles: true, key: 'Escape'}));
			await flushAll();

			expect(element.shadowRoot.querySelector('[data-testid="detail-panel"]')).toBeNull();
			expect(element.shadowRoot.activeElement?.className).toContain('listwrap');
		});

		it('leaves every other key alone, and Escape with no drawer open', async() =>
		{
			const element = await createComponent();
			await selectRow(element, '001p1');

			element.shadowRoot.querySelector('.log-console').dispatchEvent(new KeyboardEvent('keydown', {bubbles: true, key: 'a'}));
			await flushAll();
			expect(element.shadowRoot.querySelector('[data-testid="detail-panel"]')).not.toBeNull();

			element.shadowRoot.querySelector('.log-console').dispatchEvent(new KeyboardEvent('keydown', {bubbles: true, key: 'Escape'}));
			await flushAll();
			element.shadowRoot.querySelector('.log-console').dispatchEvent(new KeyboardEvent('keydown', {bubbles: true, key: 'Escape'}));
			await flushAll();

			expect(element.shadowRoot.querySelector('[data-testid="detail-panel"]')).toBeNull();
		});
	});

	describe('problem grouping status', () =>
	{
		const withStatus = (derivedStatus, extra = {}) => ({
			problems: {
				...MOCK_PROBLEM_PAGE, derivedStatus, derivedLevelScope: [
					'ERROR',
					'WARN'
				], ...extra
			}
		});

		it('states the grouped levels and raises no bar when the fold ran', async() =>
		{
			wireMockResponses(withStatus('COMPLETE'));
			const element = await createComponent();

			// COMPLETE is the normal load; a reassurance bar on every one of them is noise.
			expect(element.shadowRoot.querySelector('[data-testid="grouping-status-bar"]')).toBeNull();
			const caption = element.shadowRoot.querySelector('[data-testid="grouping-scope-caption"]');
			expect(caption).not.toBeNull();
			expect(caption.textContent).toContain('ERROR and WARN');
		});

		// The bar's weight is carried by colour, and this file's own rule is that a level is never shown by
		// colour alone. Each status also earns its OWN icon rather than one shared mark: the icon is read
		// before the sentence, so a generic one would say "something is up" where a specific one already
		// says which thing.
		it.each([
			[
				'DISABLED',
				'utility:ban'
			],
			[
				'SKIPPED_SEARCH',
				'utility:search'
			],
			[
				'SKIPPED_LEVEL_SCOPE',
				'utility:contrast'
			],
			[
				'SKIPPED_NON_SELECTIVE',
				'utility:warning'
			]
		])('marks the %s bar with its own icon, never colour alone', async(derivedStatus, iconName) =>
		{
			wireMockResponses(withStatus(derivedStatus));
			const element = await createComponent();

			const icon = element.shadowRoot.querySelector('[data-testid="grouping-status-bar"] lightning-icon');
			expect(icon).not.toBeNull();
			expect(icon.iconName).toBe(iconName);
		});

		it('explains a switched-off fold, and drops the caption while a bar is up', async() =>
		{
			wireMockResponses(withStatus('DISABLED'));
			const element = await createComponent();

			const bar = element.shadowRoot.querySelector('[data-testid="grouping-status-bar"]');
			expect(bar).not.toBeNull();
			expect(bar.textContent).toContain('Problem grouping is off');
			// Caption and bar are mutually exclusive by construction, not by a suppression rule: the caption
			// requires COMPLETE and every bar requires a status that is not COMPLETE.
			expect(element.shadowRoot.querySelector('[data-testid="grouping-scope-caption"]')).toBeNull();
		});

		it('joins the levels with a plain comma when the platform cannot format a list in the reader\'s language', async() =>
		{
			// The join runs inside a render getter. A RangeError (an unrecognised tag) or a TypeError (a runtime
			// without Intl.ListFormat) there would take the whole problems view down over a caption.
			const listFormat = jest.spyOn(Intl, 'ListFormat').mockImplementation(() =>
			{
				throw new RangeError('Incorrect locale information provided');
			});
			try
			{
				wireMockResponses(withStatus('COMPLETE'));
				const element = await createComponent();

				expect(element.shadowRoot.querySelector('[data-testid="grouping-scope-caption"]').textContent).toContain('ERROR, WARN');
			}
			finally
			{
				listFormat.mockRestore();
			}
		});

		it('says nothing about a scope the server did not send', async() =>
		{
			wireMockResponses({problems: {...MOCK_PROBLEM_PAGE, derivedStatus: 'COMPLETE', derivedLevelScope: []}});
			const element = await createComponent();

			// Better silent than "Problem grouping covers ." — the caption is the sentence, not a frame for it.
			expect(element.shadowRoot.querySelector('[data-testid="grouping-scope-caption"]')).toBeNull();
		});

		it('names the configured levels in the level-scope bar', async() =>
		{
			wireMockResponses(withStatus('SKIPPED_LEVEL_SCOPE'));
			const element = await createComponent();

			const bar = element.shadowRoot.querySelector('[data-testid="grouping-status-bar"]');
			expect(bar.textContent).toContain('ERROR and WARN');
		});

		it('marks a declined scan as needing attention, unlike a configured skip', async() =>
		{
			wireMockResponses(withStatus('SKIPPED_NON_SELECTIVE'));
			const element = await createComponent();

			const bar = element.shadowRoot.querySelector('[data-testid="grouping-status-bar"]');
			// Amber, not blue: this list really is missing problems that exist.
			expect(bar.className).toContain('grouping-bar_attention');

			wireMockResponses(withStatus('DISABLED'));
			const configured = await createComponent();
			expect(configured.shadowRoot.querySelector('[data-testid="grouping-status-bar"]').className).toContain('grouping-bar_info');
		});

		it('keeps both the bar and the caption out of the entries view', async() =>
		{
			wireMockResponses(withStatus('DISABLED'));
			const element = await createComponent();
			buttonByLabel(element, 'Individual entries').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			// Grouping does not apply to individual entries, so saying anything about it there is a non-sequitur.
			expect(element.shadowRoot.querySelector('[data-testid="grouping-status-bar"]')).toBeNull();
			expect(element.shadowRoot.querySelector('[data-testid="grouping-scope-caption"]')).toBeNull();
		});

		it('tells the reader which kind of empty list they are looking at', async() =>
		{
			wireMockResponses({
				problems: {
					...MOCK_PROBLEM_PAGE, records: [], totalCount: 0, derivedStatus: 'COMPLETE', derivedLevelScope: [
						'ERROR',
						'WARN'
					]
				}
			});
			const complete = await createComponent();
			expect(complete.shadowRoot.querySelector('[data-testid="empty-state"]').textContent).toContain('No repeating problems match these filters.');

			wireMockResponses({
				problems: {
					...MOCK_PROBLEM_PAGE, records: [], totalCount: 0, derivedStatus: 'DISABLED', derivedLevelScope: [
						'ERROR',
						'WARN'
					]
				}
			});
			const stopped = await createComponent();
			// A list that is empty because grouping never ran must not claim nothing repeats.
			expect(stopped.shadowRoot.querySelector('[data-testid="empty-state"]').textContent).toContain('No problems match these filters.');
		});

		it('sends a configured skip to the Log Settings page itself rather than flipping the switch', async() =>
		{
			wireMockResponses(withStatus('DISABLED'));
			const element = await createComponent();
			getLogSettingsSetupUrl.emit(LOG_SETTINGS_MANAGE_URL);
			await flushAll();
			mockNavigate.mockClear();

			element.shadowRoot.querySelector('[data-testid="grouping-status-action"]').click();

			// A link, not a toggle: whoever is reading a read-only console may not be allowed to change an
			// org-wide setting, and flipping it for them silently would be worse than showing them where it is.
			// The manage page, not the Custom Settings index: the index lists every custom setting in the org
			// and leaves the reader to find Log Settings and press Manage before they see a single value.
			expect(mockNavigate).toHaveBeenCalled();
			expect(mockNavigate.mock.calls[0][0].attributes.url).toBe(LOG_SETTINGS_MANAGE_URL);
		});

		it('falls back to the Custom Settings list when the Log Settings page has not resolved', async() =>
		{
			wireMockResponses(withStatus('DISABLED'));
			const element = await createComponent();
			mockNavigate.mockClear();

			// The wire has not answered yet (or the org cannot resolve the entity). The action still has to
			// go somewhere the setting can be reached from, rather than doing nothing.
			element.shadowRoot.querySelector('[data-testid="grouping-status-action"]').click();

			expect(mockNavigate.mock.calls[0][0].attributes.url).toBe(CUSTOM_SETTINGS_HOME_PATH);
		});

		it('hands a suppressed search over to the view that can run it', async() =>
		{
			wireMockResponses(withStatus('SKIPPED_SEARCH'));
			const element = await createComponent();
			jest.useFakeTimers();
			try
			{
				const search = element.shadowRoot.querySelector('.filter-search');
				search.value = 'timeout';
				search.dispatchEvent(new CustomEvent('change'));
				jest.advanceTimersByTime(300);
				await flushAll();
			}
			finally
			{
				jest.useRealTimers();
			}
			mockCallControllerMethod.mockClear();

			element.shadowRoot.querySelector('[data-testid="grouping-status-action"]').click();
			await flushAll();

			// Grouping cannot apply a free-text term, but Individual entries searches every word of every log —
			// so the term has to travel with the reader, or the action hands them an unfiltered list instead.
			expect(callCountFor(getLogEntries)).toBe(1);
			expect(lastRequestFor(getLogEntries).searchTerm).toBe('timeout');
			expect(element.shadowRoot.querySelector('[data-testid="grouping-status-bar"]')).toBeNull();
		});

		it('does not yank focus when the action button is clicked twice', async() =>
		{
			wireMockResponses(withStatus('SKIPPED_SEARCH'));
			const element = await createComponent();
			const range = element.shadowRoot.querySelector('.date-range-combobox');
			range.focus = jest.fn();

			// The view changes synchronously but re-renders a microtask later, so the button is still live for
			// a second click — an ordinary thing to do with something styled like a link.
			const action = element.shadowRoot.querySelector('[data-testid="grouping-status-action"]');
			action.click();
			action.click();
			await flushAll();

			expect(range.focus).not.toHaveBeenCalled();
		});

		it('puts the reader on the date range when the window was too large to fold', async() =>
		{
			wireMockResponses(withStatus('SKIPPED_NON_SELECTIVE'));
			const element = await createComponent();
			const range = element.shadowRoot.querySelector('.date-range-combobox');
			range.focus = jest.fn();
			mockNavigate.mockClear();

			element.shadowRoot.querySelector('[data-testid="grouping-status-action"]').click();

			// Narrowing the range is the one thing a subscriber can actually do about a scan ceiling.
			expect(range.focus).toHaveBeenCalled();
			expect(mockNavigate).not.toHaveBeenCalled();
			// This branch must not also change view — that is what distinguishes it from the search action.
			expect(element.shadowRoot.querySelector('[data-testid="grouping-status-bar"]')).not.toBeNull();
		});

		it('keeps the entries view on its own empty copy', async() =>
		{
			wireMockResponses({entries: {...MOCK_ENTRY_PAGE, records: [], totalCount: 0}});
			const element = await createComponent();
			buttonByLabel(element, 'Individual entries').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			const empty = element.shadowRoot.querySelector('[data-testid="empty-state"]');
			expect(empty.textContent).toContain('No logs match these filters.');
			expect(empty.textContent).toContain('Widen the date range');
		});

		it('clears the status when the view comes back carrying none', async() =>
		{
			wireMockResponses(withStatus('DISABLED'));
			const element = await createComponent();
			expect(element.shadowRoot.querySelector('[data-testid="grouping-status-bar"]')).not.toBeNull();

			// Round-tripping through the entries view and back on a page with no status: the render gate on
			// isProblemsView hides the bar while away, so only clearing the STATE keeps it gone on return.
			wireMockResponses({problems: {...MOCK_PROBLEM_PAGE}});
			buttonByLabel(element, 'Individual entries').dispatchEvent(new CustomEvent('click'));
			await flushAll();
			buttonByLabel(element, 'Problem summary').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			expect(element.shadowRoot.querySelector('[data-testid="grouping-status-bar"]')).toBeNull();
			expect(element.shadowRoot.querySelector('[data-testid="grouping-scope-caption"]')).toBeNull();
		});

		it('lets the page now on screen carry its own grouping status', async() =>
		{
			wireMockResponses({
				problems: {
					...MOCK_PROBLEM_PAGE, hasMorePages: true, derivedStatus: 'COMPLETE', derivedLevelScope: [
						'ERROR',
						'WARN'
					]
				}
			});
			const element = await createComponent();

			expect(element.shadowRoot.querySelector('[data-testid="grouping-status-bar"]')).toBeNull();
			expect(element.shadowRoot.querySelector('[data-testid="grouping-scope-caption"]')).not.toBeNull();

			// The fold re-runs per page against a rolling window, so page two can decline a scan page one
			// completed. A page turn replaces the rows, so the status belongs to the page now on screen:
			// these rows were not grouped, and the bar saying so is the truth about them.
			wireMockResponses({
				problems: {
					...MOCK_PROBLEM_PAGE, pageNumber: 2, hasMorePages: false, derivedStatus: 'SKIPPED_NON_SELECTIVE', derivedLevelScope: [
						'ERROR',
						'WARN'
					]
				}
			});
			await turnToNextPage(element);

			expect(element.shadowRoot.querySelector('[data-testid="grouping-status-bar"]')).not.toBeNull();
			expect(element.shadowRoot.querySelector('[data-testid="grouping-scope-caption"]')).toBeNull();
		});

		it('says the read failed when the page never arrived, instead of blaming the filters', async() =>
		{
			// A failed console read logs and resolves undefined, which lands in the same empty list as a
			// genuine no-match. Every no-match sentence is false there: "no repeating problems" asserts a
			// fold that never ran, and "no logs match these filters" sends the reader off to widen filters
			// that were never the problem — over a ribbon still counting six figures of entries.
			mockCallControllerMethod.mockImplementation((apexFn) => Promise.resolve(apexFn === getLogProblems ? undefined : MOCK_SUMMARY));
			const element = await createComponent();

			const failed = element.shadowRoot.querySelector('[data-testid="list-load-failed"]');
			expect(failed).not.toBeNull();
			expect(failed.textContent).toContain('The log list couldn\'t be loaded.');
			expect(failed.textContent).not.toContain('No logs match these filters.');
			expect(failed.textContent).not.toContain('No repeating problems');
			expect(element.shadowRoot.querySelector('[data-testid="empty-state"]')).toBeNull();
		});

		it('takes the failure state back down once a load succeeds', async() =>
		{
			mockCallControllerMethod.mockImplementation((apexFn) => Promise.resolve(apexFn === getLogProblems ? undefined : MOCK_SUMMARY));
			const element = await createComponent();
			expect(element.shadowRoot.querySelector('[data-testid="list-load-failed"]')).not.toBeNull();

			wireMockResponses();
			buttonByLabel(element, 'Refresh').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			expect(element.shadowRoot.querySelector('[data-testid="list-load-failed"]')).toBeNull();
			expect(table(element)).not.toBeNull();
		});

		it('keeps the no-match copy for a page that arrived and was genuinely empty', async() =>
		{
			// The distinction is the whole fix: a page that came back with no rows is a real no-match, and
			// telling that reader the read failed would be the same lie in the other direction.
			wireMockResponses({problems: {...MOCK_PROBLEM_PAGE, records: [], totalCount: 0}});
			const element = await createComponent();

			expect(element.shadowRoot.querySelector('[data-testid="list-load-failed"]')).toBeNull();
			expect(element.shadowRoot.querySelector('[data-testid="empty-state"]').textContent).toContain('No logs match these filters.');
		});

		it('explains approximate totals differently when a whole leg is missing', async() =>
		{
			wireMockResponses({summary: {...MOCK_SUMMARY, totalsApproximate: true, totalsApproximateCause: 'PARTIAL'}});
			const element = await createComponent();

			// "the most recent groups" is truncation language, and false when a leg never ran at all.
			expect(element.shadowRoot.querySelector('[data-testid="totals-approximate-help"]').content).toContain('could not be worked out');

			wireMockResponses({summary: {...MOCK_SUMMARY, totalsApproximate: true, totalsApproximateCause: 'TRUNCATED'}});
			const trimmed = await createComponent();
			expect(trimmed.shadowRoot.querySelector('[data-testid="totals-approximate-help"]').content).toContain('most recent activity groups');
		});
	});

	describe('empty, capped and error states', () =>
	{
		it('shows the empty state when there are no results', async() =>
		{
			wireMockResponses({problems: {records: [], totalCount: 0, pageNumber: 1, totalPages: 0, hasMorePages: false, resultsTruncated: false}});
			const element = await createComponent();

			expect(element.shadowRoot.querySelector('[data-testid="empty-state"]')).not.toBeNull();
			expect(table(element)).toBeNull();
		});

		it('renders the capped banner when the candidate cap was hit', async() =>
		{
			wireMockResponses({problems: {...MOCK_PROBLEM_PAGE, totalCount: 2000, resultsTruncated: true}});
			const element = await createComponent();

			const banner = element.shadowRoot.querySelector('[data-testid="capped-banner"]');
			expect(banner).not.toBeNull();
			expect(banner.getAttribute('aria-live')).toBe('polite');
			// Grouped like the ribbon's own number beside it, which renders through lightning-formatted-number.
			expect(banner.textContent).toContain('2,000');
		});

		it('renders the capped banner when only the derived leg hit its cap', async() =>
		{
			// capped is the OR of both legs; resultsTruncated is the rollup leg alone. Binding the banner to
			// resultsTruncated leaves a derived-leg cap entirely unannounced — the list is short and says nothing.
			wireMockResponses({problems: {...MOCK_PROBLEM_PAGE, totalCount: 2000, resultsTruncated: false, capped: true}});
			const element = await createComponent();

			const banner = element.shadowRoot.querySelector('[data-testid="capped-banner"]');
			expect(banner).not.toBeNull();
			expect(banner.textContent).toContain('2,000');
		});

		it('still banners the entries view, whose page carries no capped flag at all', async() =>
		{
			// The entries page has resultsTruncated and nothing else, and both views share one load path, so the
			// binding has to fall back rather than swap.
			wireMockResponses({entries: {...MOCK_ENTRY_PAGE, totalCount: 500, resultsTruncated: true}});
			const element = await createComponent();
			buttonByLabel(element, 'Individual entries').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			const banner = element.shadowRoot.querySelector('[data-testid="capped-banner"]');
			expect(banner).not.toBeNull();
			expect(banner.textContent).toContain('500');
		});

		it('does not banner an empty list as "the first 0", however the page came to be capped', async() =>
		{
			// A wide window on a big org: the rollup scan throws (degraded → capped) and the derived fold declines,
			// so the page is empty AND capped. The status bar and the empty state already say what happened; an
			// amber banner claiming the first 0 rows are showing would be a second surface saying something false.
			wireMockResponses({problems: {...MOCK_PROBLEM_PAGE, records: [], totalCount: 0, capped: true, derivedStatus: 'SKIPPED_NON_SELECTIVE', derivedLevelScope: ['ERROR']}});
			const element = await createComponent();

			expect(element.shadowRoot.querySelector('[data-testid="capped-banner"]')).toBeNull();
			expect(element.shadowRoot.querySelector('[data-testid="grouping-status-bar"]')).not.toBeNull();
			expect(element.shadowRoot.querySelector('[data-testid="empty-state"]')).not.toBeNull();
		});

		it('clears the list and selection when the controller returns nothing', async() =>
		{
			mockCallControllerMethod.mockImplementation((apexFn) => Promise.resolve(apexFn === getLogSummary ? MOCK_SUMMARY : null));
			const element = await createComponent();

			expect(element.shadowRoot.querySelector('[data-testid="empty-state"]')).not.toBeNull();
			expect(element.shadowRoot.querySelector('[data-testid="detail-panel"]')).toBeNull();
		});

		it('drops a banner from an earlier page when a reload returns nothing', async() =>
		{
			wireMockResponses({problems: {...MOCK_PROBLEM_PAGE, totalCount: 2000, capped: true}});
			const element = await createComponent();
			expect(element.shadowRoot.querySelector('[data-testid="capped-banner"]')).not.toBeNull();

			mockCallControllerMethod.mockImplementation((apexFn) => Promise.resolve(apexFn === getLogSummary ? MOCK_SUMMARY : null));
			buttonByLabel(element, 'Refresh').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			// A failed load leaves nothing on screen to be capped; the banner from the page before it must go too.
			expect(element.shadowRoot.querySelector('[data-testid="capped-banner"]')).toBeNull();
		});
	});

	describe('paging and refresh', () =>
	{
		const PAGE_ONE = {records: PROBLEM_ROWS, totalCount: 4, pageNumber: 1, totalPages: 2, hasMorePages: true, resultsTruncated: false};
		const PAGE_TWO_ROWS = [
			{...PROBLEM_ROWS[0], id: '001p3', logNumber: 'L-003'},
			{...PROBLEM_ROWS[1], id: '001p4', logNumber: 'L-004'}
		];
		const PAGE_TWO = {records: PAGE_TWO_ROWS, totalCount: 4, pageNumber: 2, totalPages: 2, hasMorePages: false, resultsTruncated: false};

		function wirePagedProblems()
		{
			mockCallControllerMethod.mockImplementation((apexFn, params) =>
			{
				if(apexFn === getLogProblems)
				{
					return Promise.resolve(JSON.parse(params.requestJson).pageNumber >= 2 ? PAGE_TWO : PAGE_ONE);
				}
				return Promise.resolve(apexFn === getLogSummary ? MOCK_SUMMARY : null);
			});
		}

		it('shows the next page in place of the one before it when the pager turns', async() =>
		{
			wirePagedProblems();
			const element = await createComponent();
			expect(table(element).data.map((row) => row.logNumber)).toEqual([
				'L-001',
				'L-002'
			]);
			mockCallControllerMethod.mockClear();

			await turnToNextPage(element);

			expect(lastRequestFor(getLogProblems).pageNumber).toBe(2);
			// The page replaces the rows: page one's two rows are gone, not scrolled past.
			expect(table(element).data.map((row) => row.logNumber)).toEqual([
				'L-003',
				'L-004'
			]);
			// The window-scoped ribbon is not re-fetched on a page turn: it counts the window, and the window has not moved.
			expect(mockCallControllerMethod.mock.calls.some((call) => call[0] === getLogSummary)).toBe(false);
		});

		it('does not ask for another page once the last page is on screen', async() =>
		{
			const element = await createComponent();
			mockCallControllerMethod.mockClear();

			// Next is disabled on the last page; a click that reaches the handler anyway must not walk
			// past the end and ask the server for a page that does not exist.
			await turnToNextPage(element);

			expect(mockCallControllerMethod.mock.calls.some((call) => call[0] === getLogProblems)).toBe(false);
		});

		it('returns to the first page when a filter changes on a later page', async() =>
		{
			wirePagedProblems();
			const element = await createComponent();
			await turnToNextPage(element);
			expect(lastRequestFor(getLogProblems).pageNumber).toBe(2);
			mockCallControllerMethod.mockClear();

			levelButton(element, 'INFO').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			expect(lastRequestFor(getLogProblems).pageNumber).toBe(1);
			expect(table(element).data.map((row) => row.logNumber)).toEqual([
				'L-001',
				'L-002'
			]);
		});

		it('re-requests when Refresh is clicked', async() =>
		{
			const element = await createComponent();
			mockCallControllerMethod.mockClear();

			buttonByLabel(element, 'Refresh').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			expect(mockCallControllerMethod.mock.calls.some((call) => call[0] === getLogProblems)).toBe(true);
		});

		it('refreshes from the first page after the reader has turned to another one', async() =>
		{
			wirePagedProblems();
			const element = await createComponent();
			await turnToNextPage(element);
			expect(lastRequestFor(getLogProblems).pageNumber).toBe(2);
			mockCallControllerMethod.mockClear();

			buttonByLabel(element, 'Refresh').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			// Refresh is a fresh look at the list, so it starts where the list starts: page one, the same
			// model a filter change follows.
			expect(lastRequestFor(getLogProblems).pageNumber).toBe(1);
			expect(table(element).data.map((row) => row.logNumber)).toEqual([
				'L-001',
				'L-002'
			]);
			// The window-scoped ribbon still reloads with the refresh.
			expect(mockCallControllerMethod.mock.calls.some((call) => call[0] === getLogSummary)).toBe(true);
		});
	});

	describe('detail drawer and selection', () =>
	{
		it('loads the detail and the correlated trace, and opens the drawer when a row is selected', async() =>
		{
			const element = await createComponent();

			await selectRow(element, '001p1');

			expect(mockCallControllerMethod.mock.calls.some((call) => call[0] === getLogEntryDetail)).toBe(true);
			expect(mockCallControllerMethod.mock.calls.some((call) => call[0] === getCorrelatedTrace)).toBe(true);
			expect(element.shadowRoot.querySelector('[data-testid="detail-panel"]')).not.toBeNull();
			const detail = element.shadowRoot.querySelector('c-log-console-detail');
			expect(detail).not.toBeNull();
			expect(detail.trace).toEqual(MOCK_TRACE);
			expect(detail.traceTruncated).toBe(false);
		});

		it('hands the drawer the row occurrence count, and none for a row that is not in the loaded list', async() =>
		{
			const element = await createComponent();

			await selectRow(element, '001p1');
			expect(element.shadowRoot.querySelector('c-log-console-detail').occurrenceCount).toBe(1284);

			await selectRow(element, '001p9');

			expect(element.shadowRoot.querySelector('c-log-console-detail').occurrenceCount).toBeNull();
		});

		it('closes the drawer when the next selected entry detail does not load', async() =>
		{
			const element = await createComponent();
			await selectRow(element, '001p1');
			expect(element.shadowRoot.querySelector('[data-testid="detail-panel"]')).not.toBeNull();

			mockCallControllerMethod.mockImplementation((apexFn) => Promise.resolve(apexFn === getLogEntryDetail ? undefined : {entries: MOCK_TRACE, truncated: false}));
			await selectRow(element, '001p2');

			// A failed detail load must not leave the previously opened entry on screen under the new selection.
			expect(element.shadowRoot.querySelector('[data-testid="detail-panel"]')).toBeNull();
			expect(table(element).data.length).toBe(2);
		});

		it('takes the highlight off a row whose detail does not load, so the reader can select it again', async() =>
		{
			const element = await createComponent();
			mockCallControllerMethod.mockImplementation((apexFn) => Promise.resolve(apexFn === getLogEntryDetail ? undefined : {entries: MOCK_TRACE, truncated: false}));

			await selectRow(element, '001p1');

			expect(element.shadowRoot.querySelector('[data-testid="detail-panel"]')).toBeNull();
			expect(table(element).selectedRows).toEqual([]);
		});

		it('empties the timeline when the next selected entry has no correlated trace', async() =>
		{
			const element = await createComponent();
			mockCallControllerMethod.mockImplementation((apexFn) => Promise.resolve(apexFn === getCorrelatedTrace ? {entries: MOCK_TRACE, truncated: true} : MOCK_DETAIL));
			await selectRow(element, '001p1');
			expect(element.shadowRoot.querySelector('c-log-console-detail').trace).toEqual(MOCK_TRACE);
			expect(element.shadowRoot.querySelector('c-log-console-detail').traceTruncated).toBe(true);

			mockCallControllerMethod.mockImplementation((apexFn) => Promise.resolve(apexFn === getCorrelatedTrace ? null : MOCK_DETAIL));
			await selectRow(element, '001p2');

			const detail = element.shadowRoot.querySelector('c-log-console-detail');
			expect(detail.trace).toEqual([]);
			expect(detail.traceTruncated).toBe(false);
		});

		it('empties the timeline but keeps the truncation flag when a truncated trace carries no hops', async() =>
		{
			const element = await createComponent();
			await selectRow(element, '001p1');
			expect(element.shadowRoot.querySelector('c-log-console-detail').trace).toEqual(MOCK_TRACE);

			mockCallControllerMethod.mockImplementation((apexFn) => Promise.resolve(apexFn === getCorrelatedTrace ? {truncated: true} : MOCK_DETAIL));
			await selectRow(element, '001p2');

			const detail = element.shadowRoot.querySelector('c-log-console-detail');
			expect(detail.trace).toEqual([]);
			expect(detail.traceTruncated).toBe(true);
		});

		it('loads a focused hop detail on entryfocus and leaves the list selection unchanged', async() =>
		{
			const element = await createComponent();
			await selectRow(element, '001p1');
			const detail = element.shadowRoot.querySelector('c-log-console-detail');
			const before = mockCallControllerMethod.mock.calls.filter((call) => call[0] === getLogEntryDetail).length;

			detail.dispatchEvent(new CustomEvent('entryfocus', {detail: {entryId: '001p0'}}));
			await flushAll();

			const after = mockCallControllerMethod.mock.calls.filter((call) => call[0] === getLogEntryDetail);
			expect(after.length).toBe(before + 1);
			expect(after[after.length - 1][1].entryId).toBe('001p0');
			expect(detail.focusedDetail).toEqual(MOCK_DETAIL);
			expect(element.shadowRoot.querySelector('c-log-console-table').selectedRows).toEqual(['001p1']);
		});

		it('uses the opened detail with no Apex call when the focused hop is the opened entry', async() =>
		{
			const element = await createComponent();
			await selectRow(element, '001p1');
			const detail = element.shadowRoot.querySelector('c-log-console-detail');
			const before = mockCallControllerMethod.mock.calls.filter((call) => call[0] === getLogEntryDetail).length;

			detail.dispatchEvent(new CustomEvent('entryfocus', {detail: {entryId: '001p1'}}));
			await flushAll();

			expect(mockCallControllerMethod.mock.calls.filter((call) => call[0] === getLogEntryDetail).length).toBe(before);
			expect(detail.focusedDetail).toEqual(MOCK_DETAIL);
		});

		it('serves a repeat focus from cache without a second Apex call', async() =>
		{
			const element = await createComponent();
			await selectRow(element, '001p1');
			const detail = element.shadowRoot.querySelector('c-log-console-detail');
			detail.dispatchEvent(new CustomEvent('entryfocus', {detail: {entryId: '001p0'}}));
			await flushAll();
			const afterFirst = mockCallControllerMethod.mock.calls.filter((call) => call[0] === getLogEntryDetail).length;

			detail.dispatchEvent(new CustomEvent('entryfocus', {detail: {entryId: '001p0'}}));
			await flushAll();

			expect(mockCallControllerMethod.mock.calls.filter((call) => call[0] === getLogEntryDetail).length).toBe(afterFirst);
		});

		it('shows the loaded focus card when a hop is focused again after the opened entry was focused in between', async() =>
		{
			const element = await createComponent();
			await selectRow(element, '001p1');
			const defaultAnswer = mockCallControllerMethod.getMockImplementation();
			const hopDetail = {id: '001p0', message: 'begin', stackTrace: 'Class.OrderService.begin', contextJson: ''};
			mockCallControllerMethod.mockImplementation(
					(apexFn, params) => (apexFn === getLogEntryDetail && params.entryId === '001p0' ? Promise.resolve(hopDetail) : defaultAnswer(apexFn, params)));
			const drawer = element.shadowRoot.querySelector('c-log-console-detail');
			const timelineEntry = (entryId) => Array.from(drawer.shadowRoot.querySelectorAll('[data-testid="timeline-entry"]')).find((entry) => entry.dataset.entryId === entryId);

			timelineEntry('001p0').click();
			await flushAll();
			expect(drawer.shadowRoot.querySelector('[data-testid="focus-stack"]').textContent).toContain('Class.OrderService.begin');
			timelineEntry('001p1').click();
			await flushAll();
			timelineEntry('001p0').click();
			await flushAll();

			expect(drawer.shadowRoot.querySelector('[data-testid="focus-loading"]')).toBeNull();
			expect(drawer.shadowRoot.querySelector('[data-testid="focus-stack"]').textContent).toContain('Class.OrderService.begin');
		});

		it('surfaces a load-failed sentinel when the focused hop detail does not load', async() =>
		{
			const element = await createComponent();
			await selectRow(element, '001p1');
			const detail = element.shadowRoot.querySelector('c-log-console-detail');

			mockCallControllerMethod.mockResolvedValueOnce(null);
			detail.dispatchEvent(new CustomEvent('entryfocus', {detail: {entryId: '001p9'}}));
			await flushAll();

			expect(detail.focusedDetail).toEqual({loadFailed: true});
		});

		it('navigates to the LogEntry record when the detail asks to open it', async() =>
		{
			const element = await createComponent();
			await selectRow(element, '001p1');

			element.shadowRoot.querySelector('c-log-console-detail').dispatchEvent(new CustomEvent('openrecord', {detail: {entryId: '001p1'}}));

			expect(mockNavigate).toHaveBeenCalled();
			expect(mockNavigate.mock.calls[0][0].attributes.recordId).toBe('001p1');
		});

		it('navigates to Chain Monitor with the correlation id', async() =>
		{
			const element = await createComponent();
			await selectRow(element, '001p1');

			element.shadowRoot.querySelector('c-log-console-detail').dispatchEvent(new CustomEvent('navigatechain', {detail: {correlationId: 'c1'}}));

			expect(mockNavigate).toHaveBeenCalled();
			const target = mockNavigate.mock.calls[0][0];
			expect(target.attributes.apiName).toBe('ChainMonitor');
			expect(target.state.c__correlationId).toBe('c1');
		});

		it('closes the drawer when the detail dispatches close', async() =>
		{
			const element = await createComponent();
			await selectRow(element, '001p1');
			expect(element.shadowRoot.querySelector('[data-testid="detail-panel"]')).not.toBeNull();

			element.shadowRoot.querySelector('c-log-console-detail').dispatchEvent(new CustomEvent('close'));
			await flushAll();

			expect(element.shadowRoot.querySelector('[data-testid="detail-panel"]')).toBeNull();
		});

		it('closes the drawer when the selected row leaves the result set after a reload', async() =>
		{
			const element = await createComponent();
			await selectRow(element, '001p1');
			expect(element.shadowRoot.querySelector('[data-testid="detail-panel"]')).not.toBeNull();

			wireMockResponses({problems: {records: [PROBLEM_ROWS[1]], totalCount: 1, pageNumber: 1, totalPages: 1, hasMorePages: false, resultsTruncated: false}});
			buttonByLabel(element, 'Refresh').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			expect(element.shadowRoot.querySelector('[data-testid="detail-panel"]')).toBeNull();
		});

		it('ignores a row de-selection that carries no rows', async() =>
		{
			const element = await createComponent();

			table(element).dispatchEvent(new CustomEvent('rowselection', {detail: {selectedRows: []}}));
			await flushAll();

			expect(mockCallControllerMethod.mock.calls.some((call) => call[0] === getLogEntryDetail)).toBe(false);
			expect(element.shadowRoot.querySelector('[data-testid="detail-panel"]')).toBeNull();
		});

		it('pins the entries view to the drilled problem\'s own source and level, not a search for its class name', async() =>
		{
			const element = await createComponent();
			await selectRow(element, '001p1');
			mockCallControllerMethod.mockClear();

			element.shadowRoot.querySelector('c-log-console-detail').dispatchEvent(new CustomEvent('viewoccurrences', {detail: {searchTerm: 'AcctHandler'}}));
			await flushAll();

			// Searching for the class name also matches every entry that merely mentions it in a message or
			// a stack trace, which is how a problem counted 1,284 times opened a list of unrelated rows from
			// other classes. The class and method the problem was grouped under is the exact handle.
			const request = lastRequestFor(getLogEntries);
			expect(request.classMethod).toBe('AcctHandler.run');
			expect(request.searchTerm).toBeNull();
			expect(request.levels).toEqual(['ERROR']);
			expect(request.sortField).toBe('createdDate');
			expect(request.sortAscending).toBe(false);
			expect(request.pageNumber).toBe(1);
			// The entries columns prove the view actually switched, and the pin is visible and removable.
			expect(columnFieldNames(element)).toContain('chainDisplay');
			// A problem that stored no writer has only its class and method to name the pin by, which is exactly
			// what its Source cells still read.
			expect(element.shadowRoot.querySelector('[data-testid="source-filter-pill"]').label).toBe('Source: AcctHandler.run');
		});

		it('names the pinned writer the way the Source cells name it, without changing what it asks the server for', async() =>
		{
			// The class-method the wire sends for a packaged writer carries its namespace prefix; the location the
			// entry stored does not, so the pill and the Source cells below it would otherwise read differently and
			// the drill would look like it had listed somebody else's rows.
			const namespacePrefix = 'example';
			const drilled = {
				...PROBLEM_ROWS[0],
				classMethod: `${namespacePrefix}.UTIL_AsyncChain.run`,
				writerName: 'UTIL_AsyncChain',
				writerOrigin: 'FRAMEWORK',
				writerLocation: 'UTIL_AsyncChain.run:214'
			};
			// The rows behind that problem: two lines inside the one method, so the pill's text has to sit
			// inside what the Source cells read rather than match one of them.
			const occurrences = {
				...MOCK_ENTRY_PAGE, records: [
					{...MOCK_ENTRY_PAGE.records[0], writerName: 'UTIL_AsyncChain', writerOrigin: 'FRAMEWORK', writerLocation: 'UTIL_AsyncChain.run:214'},
					{...MOCK_ENTRY_PAGE.records[0], id: '001e2', writerName: 'UTIL_AsyncChain', writerOrigin: 'FRAMEWORK', writerLocation: 'UTIL_AsyncChain.run:230'}
				]
			};
			wireMockResponses({problems: {...MOCK_PROBLEM_PAGE, records: [drilled]}, entries: occurrences});
			const element = await createComponent();
			await selectRow(element, '001p1');
			mockCallControllerMethod.mockClear();

			element.shadowRoot.querySelector('c-log-console-detail').dispatchEvent(new CustomEvent('viewoccurrences', {detail: {searchTerm: 'UTIL_AsyncChain'}}));
			await flushAll();
			const request = lastRequestFor(getLogEntries);

			// The line number goes: a pin is the writer and its method, not one line inside it. Every row the
			// drill listed carries that text in its own Source cell, which is what makes the pill read as the
			// heading of the list beneath it rather than as a filter on something else.
			const pill = element.shadowRoot.querySelector('[data-spec-id="source-filter-pill"]');
			expect(pill.label).toBe('Source: UTIL_AsyncChain.run');
			const pinned = pill.label.replace('Source: ', '');
			expect(table(element).data.map((row) => row.sourceDisplay)).toEqual([
				'UTIL_AsyncChain.run:214',
				'UTIL_AsyncChain.run:230'
			]);
			table(element).data.forEach((row) => expect(row.sourceDisplay).toContain(pinned));

			// Only the wording follows the column. The same problem with no stored writer at all asks the server
			// for exactly the same thing, which is the whole request compared, not a chosen field or two.
			const withoutWriter = {...PROBLEM_ROWS[0], classMethod: `${namespacePrefix}.UTIL_AsyncChain.run`};
			wireMockResponses({problems: {...MOCK_PROBLEM_PAGE, records: [withoutWriter]}, entries: occurrences});
			const bare = await createComponent();
			await selectRow(bare, '001p1');
			mockCallControllerMethod.mockClear();

			bare.shadowRoot.querySelector('c-log-console-detail').dispatchEvent(new CustomEvent('viewoccurrences', {detail: {searchTerm: 'UTIL_AsyncChain'}}));
			await flushAll();

			expect(request).toEqual(lastRequestFor(getLogEntries));
			expect(request.classMethod).toBe(`${namespacePrefix}.UTIL_AsyncChain.run`);
			expect(request).not.toHaveProperty('label');
			// And the pill of the problem that stored nothing falls back to the class and method.
			expect(bare.shadowRoot.querySelector('[data-spec-id="source-filter-pill"]').label).toBe(`Source: ${namespacePrefix}.UTIL_AsyncChain.run`);
		});

		it('reconciles the problem\'s occurrence count with the entries still on file', async() =>
		{
			const element = await createComponent();
			await selectRow(element, '001p1');

			element.shadowRoot.querySelector('c-log-console-detail').dispatchEvent(new CustomEvent('viewoccurrences', {detail: {searchTerm: 'AcctHandler'}}));
			await flushAll();

			// A count outlives the rows it counted, so the two numbers on screen genuinely differ. Left
			// unexplained, "1,284 occurrences" over a handful of rows reads as a broken drill.
			const note = element.shadowRoot.querySelector('[data-testid="occurrences-reconciliation"]');
			expect(note.textContent).toContain('1,284');
			expect(note.textContent).toContain(String(MOCK_ENTRY_PAGE.totalCount));
		});

		it('drops the count of entries on file when the next read of the list fails', async() =>
		{
			const element = await createComponent();
			await selectRow(element, '001p1');
			element.shadowRoot.querySelector('c-log-console-detail').dispatchEvent(new CustomEvent('viewoccurrences', {detail: {searchTerm: 'AcctHandler'}}));
			await flushAll();
			expect(element.shadowRoot.querySelector('[data-testid="occurrences-reconciliation"]')).not.toBeNull();

			// The list read fails. The sentence must not go on quoting the count of the list that was on screen before.
			const pageAnswer = mockCallControllerMethod.getMockImplementation();
			mockCallControllerMethod.mockImplementation((apexFn, params) => (apexFn === getLogEntries ? Promise.resolve(undefined) : pageAnswer(apexFn, params)));
			buttonByLabel(element, 'Refresh').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			expect(element.shadowRoot.querySelector('[data-testid="list-load-failed"]')).not.toBeNull();
			expect(element.shadowRoot.querySelector('[data-testid="occurrences-reconciliation"]')).toBeNull();
		});

		it('clears the pinned source and reloads when its pill is removed', async() =>
		{
			const element = await createComponent();
			await selectRow(element, '001p1');
			element.shadowRoot.querySelector('c-log-console-detail').dispatchEvent(new CustomEvent('viewoccurrences', {detail: {searchTerm: 'AcctHandler'}}));
			await flushAll();
			mockCallControllerMethod.mockClear();

			element.shadowRoot.querySelector('[data-testid="source-filter-pill"]').dispatchEvent(new CustomEvent('remove'));
			await flushAll();

			expect(lastRequestFor(getLogEntries).classMethod).toBeNull();
			expect(element.shadowRoot.querySelector('[data-testid="source-filter-pill"]')).toBeNull();
			expect(element.shadowRoot.querySelector('[data-testid="occurrences-reconciliation"]')).toBeNull();
		});

		it('pins a source with no level and no count without inventing either', async() =>
		{
			// A problem the fold produced no level or count for still has a source worth listing, so the pin
			// applies; there is simply nothing to narrow the levels to and nothing to reconcile against.
			const bare = {...PROBLEM_ROWS[0], level: null, occurrenceCount: null};
			wireMockResponses({problems: {...MOCK_PROBLEM_PAGE, records: [bare]}});
			const element = await createComponent();
			await selectRow(element, '001p1');
			mockCallControllerMethod.mockClear();

			element.shadowRoot.querySelector('c-log-console-detail').dispatchEvent(new CustomEvent('viewoccurrences', {detail: {searchTerm: 'AcctHandler'}}));
			await flushAll();

			const request = lastRequestFor(getLogEntries);
			expect(request.classMethod).toBe('AcctHandler.run');
			expect(request.levels).toEqual([
				'ERROR',
				'WARN',
				'INFO',
				'DEBUG'
			]);
			expect(element.shadowRoot.querySelector('[data-testid="occurrences-reconciliation"]')).toBeNull();
		});

		it('falls back to the drawer\'s search term for a problem that records no source at all', async() =>
		{
			// A problem logged with no class has only its message to group on, so the message is the only
			// handle the drill has; pinning a source it does not have would list nothing.
			const sourceless = {...PROBLEM_ROWS[0], classMethod: null, className: null, methodLine: null};
			wireMockResponses({problems: {...MOCK_PROBLEM_PAGE, records: [sourceless]}});
			const element = await createComponent();
			await selectRow(element, '001p1');
			mockCallControllerMethod.mockClear();

			element.shadowRoot.querySelector('c-log-console-detail').dispatchEvent(new CustomEvent('viewoccurrences', {detail: {searchTerm: 'NPE'}}));
			await flushAll();

			expect(lastRequestFor(getLogEntries).classMethod).toBeNull();
			expect(lastRequestFor(getLogEntries).searchTerm).toBe('NPE');
			expect(element.shadowRoot.querySelector('[data-testid="source-filter-pill"]')).toBeNull();
		});
	});

	describe('filter group labelling', () =>
	{
		it('labels the view, level and context groups with visible eyebrow labels', async() =>
		{
			const element = await createComponent();

			const eyebrows = Array.from(element.shadowRoot.querySelectorAll('.eyebrow')).map((node) => node.textContent);
			expect(eyebrows).toEqual([
				'View',
				'Levels',
				'Context',
				'Origin'
			]);
		});

		it('names the view segmented control for assistive technology', async() =>
		{
			const element = await createComponent();

			const viewGroup = element.shadowRoot.querySelector('[data-testid="view-group"]');
			expect(viewGroup.getAttribute('role')).toBe('group');
			expect(viewGroup.getAttribute('aria-label')).toBe('View');
			// The two view buttons live inside the named group, so the name applies to both.
			expect(viewGroup.querySelectorAll('lightning-button').length).toBe(2);
		});
	});

	// A grouped problem is folded at read time and owns no LogEntry__c: no id, no log number, and the only
	// handle on it is the JSON signature the fold emitted. Everything here follows from that one fact.
	describe('opening a grouped problem', () =>
	{
		const DERIVED_SIGNATURE = JSON.stringify({exceptionType: 'NullPointerException', classMethod: 'AcctHandler.run', logLevel: 'ERROR', label: 'NPE'});
		const derivedRow = {...PROBLEM_ROWS[0], id: null, logNumber: null, source: 'derived', signature: DERIVED_SIGNATURE};
		const taggedRow = {...PROBLEM_ROWS[1], source: 'rollup', signature: null};
		const derivedPage = {
			...MOCK_PROBLEM_PAGE, records: [
				derivedRow,
				taggedRow
			]
		};

		// The real datatable hands back whole row objects; the shared selectRow helper passes an id only,
		// which is all the by-id path ever needed.
		async function selectFullRow(element, row)
		{
			table(element).dispatchEvent(new CustomEvent('rowselection', {detail: {selectedRows: [row]}}));
			await flushAll();
		}

		it('keys a grouped row on what it was grouped on, since it has no record id to key on', async() =>
		{
			wireMockResponses({problems: derivedPage});
			const element = await createComponent();

			// Keying on id would collapse every grouped row onto the same undefined key, and the datatable
			// would treat them as one row for selection and for its own diffing. The key is the grouping
			// identity rather than the signature JSON, which also carries the mutable group label.
			expect(table(element).keyField).toBe('rowKey');
			expect(table(element).data[0].rowKey).toBe('System.NullPointerException|AcctHandler|run:42|ERROR');
			expect(table(element).data[1].rowKey).toBe('001p2');
		});

		it('opens a grouped problem through its signature rather than a null id', async() =>
		{
			wireMockResponses({problems: derivedPage});
			const element = await createComponent();
			await selectFullRow(element, table(element).data[0]);

			const call = mockCallControllerMethod.mock.calls.filter((entry) => entry[0] === getDerivedProblemDetail).pop();
			expect(call).toBeDefined();
			expect(call[1].signatureJson).toBe(DERIVED_SIGNATURE);
			// The window matters: the representative is the newest occurrence INSIDE the range being viewed,
			// so the same signature opens a different entry under a different filter.
			expect(JSON.parse(call[1].requestJson).pageNumber).toBe(1);
			expect(callCountFor(getLogEntryDetail)).toBe(0);
		});

		it('still opens a tagged problem by its own record id', async() =>
		{
			wireMockResponses({problems: derivedPage});
			const element = await createComponent();
			await selectFullRow(element, table(element).data[1]);

			expect(callCountFor(getDerivedProblemDetail)).toBe(0);
			const call = mockCallControllerMethod.mock.calls.filter((entry) => entry[0] === getLogEntryDetail).pop();
			expect(call[1].entryId).toBe('001p2');
		});

		it('traces the representative entry a group resolves to, not the group', async() =>
		{
			wireMockResponses({problems: derivedPage, derivedDetail: {...MOCK_DETAIL, id: '001rep'}});
			const element = await createComponent();
			await selectFullRow(element, table(element).data[0]);

			// The trace is keyed on a real entry, and a group has none until the server picks its representative.
			const call = mockCallControllerMethod.mock.calls.filter((entry) => entry[0] === getCorrelatedTrace).pop();
			expect(call[1].entryId).toBe('001rep');
		});

		// The shape buildDerivedFallbackDetail actually returns when every occurrence was purged between the
		// fold and the click: FIVE fields and nothing else. Spreading MOCK_DETAIL here instead would hand the
		// drawer an id, a limit-bar list and a stack trace the server never sends on this path, and the test
		// would prove nothing about it.
		const PURGED_FALLBACK_DETAIL = {level: 'ERROR', shortMessage: 'NPE', exceptionType: 'NullPointerException', className: 'AcctHandler', methodLine: 'run'};

		it('asks for no trace when every entry behind a group has been purged', async() =>
		{
			wireMockResponses({problems: derivedPage, derivedDetail: PURGED_FALLBACK_DETAIL});
			const element = await createComponent();
			await selectFullRow(element, table(element).data[0]);

			// There is no longer a row to point at, so a trace call would query on null.
			expect(callCountFor(getCorrelatedTrace)).toBe(0);
		});

		it('renders the drawer for a purged group instead of throwing on the absent detail fields', async() =>
		{
			wireMockResponses({problems: derivedPage, derivedDetail: PURGED_FALLBACK_DETAIL});
			const element = await createComponent();
			await selectFullRow(element, table(element).data[0]);

			// The fallback omits every collection the drawer reads. A getter that reaches through one of them
			// takes the whole drawer down on a click the console itself offers.
			const panel = element.shadowRoot.querySelector('[data-testid="detail-panel"]');
			expect(panel).not.toBeNull();
			expect(panel.querySelector('c-log-console-detail')).not.toBeNull();
		});

		it('names a grouped row grouped where a log number would go, and marks the cell for the pill', async() =>
		{
			wireMockResponses({problems: derivedPage});
			const element = await createComponent();

			// An empty Log Number cell reads as a missing value and a dash reads as one that went missing;
			// this row never had a number because it owns no record, and the cell says exactly that.
			expect(table(element).data[0].logNumberDisplay).toBe('Grouped');
			expect(table(element).data[0].isGrouped).toBe(true);
			expect(table(element).data[1].logNumberDisplay).toBe('L-002');
			expect(table(element).data[1].isGrouped).toBe(false);
		});

		it('highlights the grouped row it opened, and keeps its count pill', async() =>
		{
			wireMockResponses({problems: derivedPage});
			const element = await createComponent();
			await selectFullRow(element, table(element).data[0]);

			// Selection is carried by the key field, so a grouped row selects nothing at all if the console
			// records an id it does not have.
			expect(table(element).selectedRows).toEqual([table(element).data[0].rowKey]);
			expect(element.shadowRoot.querySelector('[data-testid="detail-panel"] c-log-console-detail').occurrenceCount).toBe(1284);
		});

		it('keeps a grouped problem open across a reload that still lists it', async() =>
		{
			wireMockResponses({problems: derivedPage});
			const element = await createComponent();
			await selectFullRow(element, table(element).data[0]);

			buttonByLabel(element, 'Refresh').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			// Reconciliation compares row keys. Comparing ids instead closes the drawer on every refresh for
			// every grouped problem, since neither side has one.
			expect(element.shadowRoot.querySelector('[data-testid="detail-panel"]')).not.toBeNull();
		});

		it('survives the group label changing under it, which is not part of its identity', async() =>
		{
			wireMockResponses({problems: derivedPage});
			const element = await createComponent();
			await selectFullRow(element, table(element).data[0]);

			// The signature the server round-trips also carries the group's label — the widest message seen in
			// the window, which moves as new rows arrive. It is not what the rows were grouped on, so a longer
			// message must not re-identify the row and close the drawer.
			const relabelled = {
				...derivedRow,
				shortMessage: 'NPE on Order 2',
				signature: JSON.stringify({exceptionType: 'NullPointerException', classMethod: 'AcctHandler.run', logLevel: 'ERROR', label: 'NPE on Order 2'})
			};
			wireMockResponses({
				problems: {
					...derivedPage, records: [
						relabelled,
						taggedRow
					]
				}
			});
			buttonByLabel(element, 'Refresh').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			expect(element.shadowRoot.querySelector('[data-testid="detail-panel"]')).not.toBeNull();
		});

		it('lets the newest selection win when an earlier one is still in flight', async() =>
		{
			// The grouped path costs two sequential round trips where the tagged path costs one parallel pair,
			// so a grouped-then-tagged click order lands out of order as a matter of course. Without a guard the
			// drawer ends up showing the first problem under the second one's count and highlight.
			const resolvers = [];
			mockCallControllerMethod.mockImplementation((apexFn) =>
			{
				if(apexFn === getDerivedProblemDetail)
				{
					return new Promise((resolve) => resolvers.push(() => resolve({...MOCK_DETAIL, shortMessage: 'STALE GROUPED'})));
				}
				if(apexFn === getLogProblems)
				{
					return Promise.resolve(derivedPage);
				}
				return Promise.resolve(apexFn === getLogSummary ? MOCK_SUMMARY : MOCK_DETAIL);
			});
			const element = await createComponent();

			table(element).dispatchEvent(new CustomEvent('rowselection', {detail: {selectedRows: [table(element).data[0]]}}));
			await Promise.resolve();
			await selectFullRow(element, table(element).data[1]);
			resolvers.forEach((resolve) => resolve());
			await flushAll();

			expect(table(element).selectedRows).toEqual(['001p2']);
			expect(element.shadowRoot.querySelector('[data-testid="detail-panel"] c-log-console-detail').detail.shortMessage).not.toBe('STALE GROUPED');
		});

		it('does not re-open a drawer for a row a filter change has already dropped', async() =>
		{
			let releaseDetail;
			let problemsCallCount = 0;
			mockCallControllerMethod.mockImplementation((apexFn) =>
			{
				if(apexFn === getDerivedProblemDetail)
				{
					return new Promise((resolve) => (releaseDetail = () => resolve(MOCK_DETAIL)));
				}
				if(apexFn === getLogProblems)
				{
					// The reload answers with a page the grouped row is no longer on, which is what a level
					// filter that excludes it actually does.
					problemsCallCount++;
					return Promise.resolve(problemsCallCount === 1 ? derivedPage : {...derivedPage, records: [taggedRow]});
				}
				return Promise.resolve(apexFn === getLogSummary ? MOCK_SUMMARY : MOCK_DETAIL);
			});
			const element = await createComponent();

			table(element).dispatchEvent(new CustomEvent('rowselection', {detail: {selectedRows: [table(element).data[0]]}}));
			await Promise.resolve();
			levelButton(element, 'WARN').dispatchEvent(new CustomEvent('click'));
			await flushAll();
			releaseDetail();
			await flushAll();

			// The reload cleared the selection; a response arriving afterwards must not resurrect a drawer over
			// a row that is no longer selected.
			expect(element.shadowRoot.querySelector('[data-testid="detail-panel"]')).toBeNull();
		});

		it('keeps the log-number column readable in the entries view too', async() =>
		{
			const element = await createComponent();
			buttonByLabel(element, 'Individual entries').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			const logNumberColumn = table(element).columns.find((column) => column.fieldName === 'logNumberDisplay');
			expect(logNumberColumn.type).toBe('logNumber');
			expect(logNumberColumn.typeAttributes.recordUrl.fieldName).toBe('recordUrl');
		});

		it('reads the focused hop against the opened entry, not against the row key', async() =>
		{
			wireMockResponses({problems: derivedPage, derivedDetail: {...MOCK_DETAIL, id: '001rep'}});
			const element = await createComponent();
			await selectFullRow(element, table(element).data[0]);
			mockCallControllerMethod.mockClear();

			const drawer = element.shadowRoot.querySelector('c-log-console-detail');
			drawer.dispatchEvent(new CustomEvent('entryfocus', {detail: {entryId: '001rep'}}));
			await flushAll();

			// The opened entry's detail is already loaded; comparing against the row key (a signature) instead
			// would miss that and fetch it again.
			expect(callCountFor(getLogEntryDetail)).toBe(0);
		});

		it('says what a grouped problem has instead of a context, and dashes a source it truly lacks', async() =>
		{
			// A problem is grouped on exception type, source and level — never on execution context — so the
			// wire sends no context for ANY grouped row, and a group folded from rows with no recorded source
			// has no source either. Both cells would otherwise be silently blank. The context is a value this
			// kind of row never has, so it is named; the source really is absent, so it keeps the dash.
			const contextless = {...derivedRow, executionEvent: null, className: null, methodLine: null};
			// The zero-config shape: no class recorded, but the exception's line number still travels — on its
			// own. Joined to the absent class that would read "null.42"; a line is not a source.
			const bareLine = {...taggedRow, className: null, methodLine: '42'};
			// A row that owns a record, carries no log number and reports a context the console has no label
			// for: both cells fall back rather than rendering the grouped wording or nothing at all.
			const unlabelled = {...taggedRow, id: '001p9', logNumber: null, executionEvent: 'SOME_NEW_QUIDDITY'};
			// And a row that owns a record but recorded no context at all: that is a value that went missing.
			const contextlessTagged = {...taggedRow, id: '001p8', executionEvent: null};
			wireMockResponses({
				problems: {
					...derivedPage, records: [
						contextless,
						bareLine,
						unlabelled,
						contextlessTagged
					]
				}
			});
			const element = await createComponent();

			expect(table(element).data[0].contextDisplay).toBe('Any context');
			expect(table(element).data[0].sourceDisplay).toBe('—');
			expect(table(element).data[1].sourceDisplay).toBe('—');
			// The grouped wording is for grouped rows alone: a row that owns a record still shows the
			// display label its own context maps to.
			expect(table(element).data[1].contextDisplay).toBe('Queueable');
			// And a context the console has no label for shows the raw value rather than disappearing.
			expect(table(element).data[2].contextDisplay).toBe('SOME_NEW_QUIDDITY');
			// A row that owns a record but carries no number keeps the dash: that value really is missing.
			expect(table(element).data[2].logNumberDisplay).toBe('—');
			expect(table(element).data[3].contextDisplay).toBe('—');
		});

		it('hands the drawer the row provenance, which the detail alone cannot tell it', async() =>
		{
			wireMockResponses({problems: derivedPage});
			const element = await createComponent();
			await selectFullRow(element, table(element).data[0]);

			// A grouped and a tagged problem open on the same DTO, so the drawer can only know which it has
			// from the row the container held.
			expect(element.shadowRoot.querySelector('c-log-console-detail').provenance).toBe('derived');

			await selectFullRow(element, table(element).data[1]);
			expect(element.shadowRoot.querySelector('c-log-console-detail').provenance).toBe('rollup');
		});

		it('keeps the previous problem whole in the drawer while the next one loads, then swaps everything at once', async() =>
		{
			// A tagged detail left standing under a grouped row's provenance renders as a grouped drawer — record
			// button hidden, an offer to tag a problem that is already tagged, and a copyable snippet built from
			// the wrong row — for the whole round trip. So the drawer's row (provenance, count, span) and its detail
			// change together: the table highlights the new row at once, the drawer follows when the detail lands.
			let releaseGrouped;
			mockCallControllerMethod.mockImplementation((apexFn) =>
			{
				if(apexFn === getDerivedProblemDetail)
				{
					return new Promise((resolve) => (releaseGrouped = () => resolve({...MOCK_DETAIL, shortMessage: 'GROUPED'})));
				}
				if(apexFn === getLogProblems)
				{
					return Promise.resolve(derivedPage);
				}
				return Promise.resolve(apexFn === getLogSummary ? MOCK_SUMMARY : MOCK_DETAIL);
			});
			const element = await createComponent();
			await selectFullRow(element, table(element).data[1]);
			const drawer = () => element.shadowRoot.querySelector('c-log-console-detail');
			expect(drawer().detail.shortMessage).toBe('NPE');

			table(element).dispatchEvent(new CustomEvent('rowselection', {detail: {selectedRows: [table(element).data[0]]}}));
			await flushAll();
			// In flight: the new row is highlighted, but the drawer still describes the previous one — as a whole.
			expect(table(element).selectedRows).toEqual([table(element).data[0].rowKey]);
			expect(drawer().detail.shortMessage).toBe('NPE');
			expect(drawer().provenance).toBe('rollup');
			expect(drawer().occurrenceCount).toBe(96);

			releaseGrouped();
			await flushAll();
			expect(drawer().detail.shortMessage).toBe('GROUPED');
			expect(drawer().provenance).toBe('derived');
			expect(drawer().occurrenceCount).toBe(1284);
		});

		it('keeps describing the previous row through a reload that lands while the next row is still in flight', async() =>
		{
			// A refresh or an appended page reconciles the selection. Re-pointing the drawer at the NEW selection's
			// record there — before its detail has landed — would dress the old detail in the new row's provenance a
			// page load early: the tagged detail under a grouped provenance again, snippet and all.
			let releaseGrouped;
			mockCallControllerMethod.mockImplementation((apexFn) =>
			{
				if(apexFn === getDerivedProblemDetail)
				{
					return new Promise((resolve) => (releaseGrouped = () => resolve({...MOCK_DETAIL, shortMessage: 'GROUPED'})));
				}
				if(apexFn === getLogProblems)
				{
					return Promise.resolve(derivedPage);
				}
				return Promise.resolve(apexFn === getLogSummary ? MOCK_SUMMARY : MOCK_DETAIL);
			});
			const element = await createComponent();
			await selectFullRow(element, table(element).data[1]);
			table(element).dispatchEvent(new CustomEvent('rowselection', {detail: {selectedRows: [table(element).data[0]]}}));
			await flushAll();

			buttonByLabel(element, 'Refresh').dispatchEvent(new CustomEvent('click'));
			await flushAll();
			const drawer = () => element.shadowRoot.querySelector('c-log-console-detail');
			expect(drawer().detail.shortMessage).toBe('NPE');
			expect(drawer().provenance).toBe('rollup');
			expect(drawer().occurrenceCount).toBe(96);

			releaseGrouped();
			await flushAll();
			expect(drawer().provenance).toBe('derived');
			expect(drawer().occurrenceCount).toBe(1284);
		});

		it('re-reads the provenance of a selection that survives a switch to the other view', async() =>
		{
			// The same record id is an entry in one view and a tagged problem in the other. Carried across the
			// switch, the selection would otherwise keep the provenance of the view it was made in — and the
			// drawer would then show a tagged problem's count with none of the tagged-problem explanation.
			const entriesPage = {...MOCK_ENTRY_PAGE, records: [{...MOCK_ENTRY_PAGE.records[0], id: '001p2', logNumber: 'L-002'}]};
			wireMockResponses({problems: derivedPage, entries: entriesPage});
			const element = await createComponent();
			buttonByLabel(element, 'Individual entries').dispatchEvent(new CustomEvent('click'));
			await flushAll();
			await selectFullRow(element, table(element).data[0]);
			expect(element.shadowRoot.querySelector('c-log-console-detail').provenance).toBeNull();

			buttonByLabel(element, 'Problem summary').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			expect(table(element).selectedRows).toEqual(['001p2']);
			expect(element.shadowRoot.querySelector('c-log-console-detail').provenance).toBe('rollup');
		});

		it('hands the drawer the problem\'s own span, and none in the entries view', async() =>
		{
			// The detail is one entry — for a grouped problem the most recent occurrence — so its timestamps cannot
			// say when the problem was first seen; the row can.
			wireMockResponses({problems: derivedPage});
			const element = await createComponent();
			await selectFullRow(element, table(element).data[0]);
			const drawer = element.shadowRoot.querySelector('c-log-console-detail');
			expect(drawer.problemFirstSeen).toBe(derivedRow.firstSeen);
			expect(drawer.problemLastSeen).toBe(derivedRow.lastSeen);

			buttonByLabel(element, 'Individual entries').dispatchEvent(new CustomEvent('click'));
			await flushAll();
			await selectFullRow(element, table(element).data[0]);
			expect(element.shadowRoot.querySelector('c-log-console-detail').problemFirstSeen).toBeNull();
		});

		it('hands the drawer the namespace prefix the org needs, through the framework wire handler', async() =>
		{
			wireMockResponses({problems: derivedPage});
			const element = await createComponent();
			getApexNamespacePrefix.emit('kern.');
			await flushAll();
			await selectFullRow(element, table(element).data[0]);

			// Copy-to-compile: in a managed subscriber the snippet must read kern.LOG_Builder, and this is the
			// only cheap place to prove the prefix actually reaches the drawer.
			expect(element.shadowRoot.querySelector('c-log-console-detail').namespacePrefix).toBe('kern.');
		});

		it('toasts a namespace-prefix failure instead of swallowing it, and falls back to no prefix', async() =>
		{
			// A swallowed failure would hand a managed subscriber a snippet that fails on paste, with no sign
			// anything went wrong — the one defect a no-namespace development org can never show.
			wireMockResponses({problems: derivedPage});
			const element = await createComponent();
			getApexNamespacePrefix.error({body: {message: 'no namespace for you'}});
			await flushAll();
			await selectFullRow(element, table(element).data[0]);

			expect(mockShowErrorToast).toHaveBeenCalled();
			expect(element.shadowRoot.querySelector('c-log-console-detail').namespacePrefix).toBe('');
		});

		it('marks a tagged problem as tagged and leaves a grouped one unbadged', async() =>
		{
			wireMockResponses({problems: derivedPage});
			const element = await createComponent();

			// One pill, not two: grouping is the default, so badging every grouped row dilutes the badge.
			// Tagging is deliberate developer intent, and that is the exception worth marking.
			expect(table(element).data[0].isTagged).toBe(false);
			expect(table(element).data[1].isTagged).toBe(true);
		});
	});

});

describe('c-log-console whole action', () =>
{
	beforeEach(() => wireMockResponses());

	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
		jest.clearAllMocks();
	});

	const query = (element, testId) => element.shadowRoot.querySelector(`[data-testid="${testId}"]`);
	const queryAll = (element, testId) => Array.from(element.shadowRoot.querySelectorAll(`[data-testid="${testId}"]`));

	async function openActionByDeepLink(element, state = {c__rootCorrelationId: ACTION_ID, c__viewLogsAt: '1000'})
	{
		CurrentPageReference.emit({state});
		await flushAll();
		await flushAll();
	}

	it('opens an action from the deep link: entries view, ERROR WARN INFO on, oldest first, page 1, the action on every request', async() =>
	{
		const element = await createComponent();
		mockCallControllerMethod.mockClear();

		await openActionByDeepLink(element);

		expect(lastRequestFor(getActionSummary).rootCorrelationId).toBe(ACTION_ID);
		const request = lastRequestFor(getLogEntries);
		expect(request.rootCorrelationId).toBe(ACTION_ID);
		expect(request.levels).toEqual([
			'ERROR',
			'WARN',
			'INFO'
		]);
		expect(request.sortField).toBe('createdDate');
		expect(request.sortAscending).toBe(true);
		expect(request.pageNumber).toBe(1);
		expect(request.correlationId).toBeNull();
		expect(request.searchTerm).toBeNull();
		expect(lastRequestFor(getEntrySummary).rootCorrelationId).toBe(ACTION_ID);
		expect(query(element, 'action-pill').label).toBe('Action: a7d2f4c1…f13a');
	});

	it('keeps DEBUG on when it was on, and sets the range to the action\'s lifetime with the note', async() =>
	{
		const element = await createComponent();
		levelButton(element, 'DEBUG').click();
		await flushAll();

		await openActionByDeepLink(element);

		expect(lastRequestFor(getLogEntries).levels).toEqual([
			'ERROR',
			'WARN',
			'INFO',
			'DEBUG'
		]);
		expect(dateRangeCombobox(element).value).toBe('custom');
		const request = lastRequestFor(getLogEntries);
		expect(new Date(request.customStart).getTime()).toBe(new Date(ACTION_START).getTime() - ACTION_RANGE_MARGIN_MILLISECONDS);
		expect(new Date(request.customEnd).getTime()).toBe(new Date(ACTION_END).getTime() + ACTION_RANGE_MARGIN_MILLISECONDS);
		expect(query(element, 'action-range-note').textContent).toBe('Date range set to this action\'s lifetime.');
	});

	it('ends the range now while the action is still running, and falls back to the widest preset when the summary fails', async() =>
	{
		wireMockResponses({actionSummary: RUNNING_ACTION_SUMMARY});
		const element = await createComponent();
		const before = Date.now();
		await openActionByDeepLink(element);
		expect(new Date(lastRequestFor(getLogEntries).customEnd).getTime()).toBeGreaterThanOrEqual(before);

		mockCallControllerMethod.mockImplementation((apexFn) => Promise.resolve(apexFn === getActionSummary ? undefined : MOCK_ENTRY_PAGE));
		const failed = await createComponent();
		await openActionByDeepLink(failed);
		expect(lastRequestFor(getLogEntries).windowMinutes).toBe(43200);
		expect(query(failed, 'action-banner')).toBeNull();
		expect(query(failed, 'action-range-note')).toBeNull();
		expect(query(failed, 'action-pill')).toBeTruthy();
	});

	it('applies the same action once per stamp, a new stamp again, and an action followed by a run as two hand-offs', async() =>
	{
		const element = await createComponent();
		mockCallControllerMethod.mockClear();

		await openActionByDeepLink(element, {c__rootCorrelationId: ACTION_ID, c__viewLogsAt: '1000'});
		await openActionByDeepLink(element, {c__rootCorrelationId: ACTION_ID, c__viewLogsAt: '1000'});
		expect(callCountFor(getActionSummary)).toBe(1);

		await openActionByDeepLink(element, {c__rootCorrelationId: ACTION_ID, c__viewLogsAt: '2000'});
		expect(callCountFor(getActionSummary)).toBe(2);

		await openActionByDeepLink(element, {c__correlationId: 'run-a', c__viewLogsAt: '3000'});
		const request = lastRequestFor(getLogEntries);
		expect(request.correlationId).toBe('run-a');
		expect(request.rootCorrelationId).toBeNull();
		// The run link brings its own window, so the note that said the range was an action's lifetime goes with it.
		expect(query(element, 'action-range-note')).toBeNull();
	});

	it('opening an action clears the execution context, the source pin and the pinned run', async() =>
	{
		const element = await createComponent();
		// The run link is followed first, because it resets these filters itself; what is set after it is what the
		// action has to clear.
		await openActionByDeepLink(element, {c__correlationId: 'run-a', c__viewLogsAt: '1000'});
		buttonByLabel(element, 'Problem summary').dispatchEvent(new CustomEvent('click'));
		await flushAll();
		element.shadowRoot.querySelector('.filter-combobox').dispatchEvent(new CustomEvent('change', {detail: {value: 'QUEUEABLE'}}));
		await flushAll();
		await selectRow(element, '001p1');
		element.shadowRoot.querySelector('c-log-console-detail').dispatchEvent(new CustomEvent('viewoccurrences', {detail: {searchTerm: 'AcctHandler'}}));
		await flushAll();
		expect(element.shadowRoot.querySelector('[data-testid="source-filter-pill"]')).toBeTruthy();
		mockCallControllerMethod.mockClear();

		await openActionByDeepLink(element, {c__rootCorrelationId: ACTION_ID, c__viewLogsAt: '2000'});

		const firstActionRequest = lastRequestFor(getLogEntries);
		expect(firstActionRequest.rootCorrelationId).toBe(ACTION_ID);
		expect(firstActionRequest.executionEvents).toEqual([]);
		expect(firstActionRequest.classMethod).toBeNull();
		expect(firstActionRequest.correlationId).toBeNull();
		expect(element.shadowRoot.querySelector('.filter-combobox').value).toBe('');
		expect(query(element, 'source-filter-pill')).toBeNull();
		expect(query(element, 'correlation-pill')).toBeNull();

		// A chain pinned under the action is the action's own filter, and opening the next action drops that too.
		queryAll(element, 'action-chain-chip')[1].click();
		await flushAll();
		expect(query(element, 'correlation-pill')).toBeTruthy();

		await openActionByDeepLink(element, {c__rootCorrelationId: ACTION_ID, c__viewLogsAt: '3000'});

		const nextActionRequest = lastRequestFor(getLogEntries);
		expect(nextActionRequest.correlationId).toBeNull();
		expect(query(element, 'correlation-pill')).toBeNull();
	});

	it('composes the banner sentence from fragments around a formatted date, with chips failed first and the rest as a number', async() =>
	{
		const element = await createComponent();
		await openActionByDeepLink(element);

		const sentence = query(element, 'action-banner-sentence');
		expect(sentence.textContent).toContain('This action started on');
		expect(sentence.querySelector('lightning-formatted-date-time').value).toBe(ACTION_START);
		expect(sentence.textContent).toContain('and ran for 3m.');
		expect(sentence.textContent).toContain('It ran 7 chains, 1 of them failed.');
		const chips = queryAll(element, 'action-chain-chip');
		expect(chips.map((chip) => chip.dataset.correlationId)).toEqual([
			'run-a',
			'run-b'
		]);
		expect(chips[0].textContent).toContain('Failed');
		expect(chips[0].textContent).toContain('OrderSync · CHAIN-00214');
		expect(chips[1].textContent).toContain('launched by OrderSync · CHAIN-00214');
		expect(query(element, 'action-more-chains').textContent).toBe('and 5 more chains');
		expect(query(element, 'action-open-chains')).toBeTruthy();
	});

	it('reads still running with no chains, and the legacy sentence with the adopting chain and no monitor button', async() =>
	{
		wireMockResponses({actionSummary: RUNNING_ACTION_SUMMARY});
		const running = await createComponent();
		await openActionByDeepLink(running);
		expect(query(running, 'action-banner-sentence').textContent).toContain('and is still running after 8s.');
		expect(query(running, 'action-banner-sentence').textContent).toContain('No chains ran under it.');
		expect(query(running, 'action-open-chains')).toBeNull();

		wireMockResponses({actionSummary: LEGACY_ACTION_SUMMARY});
		const legacy = await createComponent();
		await openActionByDeepLink(legacy);
		expect(query(legacy, 'action-banner-sentence').textContent).toBe('This action was recorded before chains were tracked by action.');
		expect(queryAll(legacy, 'action-chain-chip')).toHaveLength(1);
		expect(query(legacy, 'action-open-chains')).toBeNull();
	});

	it('narrows to one chain from a chip, worded as the chain pill, and removing the chain pill returns to the whole action', async() =>
	{
		const element = await createComponent();
		await openActionByDeepLink(element);
		mockCallControllerMethod.mockClear();

		queryAll(element, 'action-chain-chip')[1].click();
		await flushAll();

		const pinnedRequest = lastRequestFor(getLogEntries);
		expect(pinnedRequest.correlationId).toBe('run-b');
		expect(pinnedRequest.rootCorrelationId).toBe(ACTION_ID);
		expect(pinnedRequest.pageNumber).toBe(1);
		expect(query(element, 'correlation-pill').label).toBe('Chain: Ledger · CHAIN-00215');

		query(element, 'correlation-pill').dispatchEvent(new CustomEvent('remove'));
		await flushAll();
		const unpinnedRequest = lastRequestFor(getLogEntries);
		expect(unpinnedRequest.correlationId).toBeNull();
		expect(unpinnedRequest.rootCorrelationId).toBe(ACTION_ID);
	});

	it('opens the chains in the Chain Monitor with the action and a stamp only', async() =>
	{
		const element = await createComponent();
		await openActionByDeepLink(element);
		// The hand-off's arrival has already rewritten the console's own address once; this test is about the
		// cross-link the button raises.
		mockNavigate.mockClear();

		query(element, 'action-open-chains').click();

		expect(mockNavigate).toHaveBeenCalledTimes(1);
		const reference = mockNavigate.mock.calls[0][0];
		expect(reference.attributes.apiName).toBe('ChainMonitor');
		expect(reference.state.c__rootCorrelationId).toBe(ACTION_ID);
		expect(reference.state.c__viewLogsAt).toEqual(expect.any(String));
		expect(Object.keys(reference.state).sort()).toEqual([
			'c__rootCorrelationId',
			'c__viewLogsAt'
		]);
	});

	it('opens the whole action when the drawer asks, and hands the drawer the pinned action', async() =>
	{
		const element = await createComponent();
		await selectRow(element, '001p1');
		mockCallControllerMethod.mockClear();

		element.shadowRoot.querySelector('c-log-console-detail').dispatchEvent(new CustomEvent('showwholeaction', {detail: {rootCorrelationId: ACTION_ID}}));
		await flushAll();
		await flushAll();

		expect(lastRequestFor(getActionSummary).rootCorrelationId).toBe(ACTION_ID);
		expect(lastRequestFor(getLogEntries).rootCorrelationId).toBe(ACTION_ID);
		await selectRow(element, '001e1');
		expect(element.shadowRoot.querySelector('c-log-console-detail').pinnedActionRootCorrelationId).toBe(ACTION_ID);
	});

	it('removing the pill restores the levels and the sort, keeps the range and the note; Clear all drops everything', async() =>
	{
		const element = await createComponent();
		await openActionByDeepLink(element);
		mockCallControllerMethod.mockClear();

		query(element, 'action-pill').dispatchEvent(new CustomEvent('remove'));
		await flushAll();

		const rangeRequest = lastRequestFor(getLogEntries);
		expect(rangeRequest.rootCorrelationId).toBeNull();
		expect(rangeRequest.levels).toEqual([
			'ERROR',
			'WARN'
		]);
		expect(rangeRequest.sortAscending).toBe(false);
		expect(rangeRequest.customStart).not.toBeNull();
		expect(query(element, 'action-range-note')).toBeTruthy();
		expect(query(element, 'action-banner')).toBeNull();

		buttonByLabel(element, 'Clear all').click();
		await flushAll();
		// Still the entries view: Clear all empties the filters, and the view is the reader's own choice, so the
		// list it reloads is the entries list the action was opened on.
		const clearedRequest = lastRequestFor(getLogEntries);
		expect(clearedRequest.customStart).toBeNull();
		expect(clearedRequest.windowMinutes).toBe(DEFAULT_WINDOW_MINUTES);
		expect(query(element, 'action-range-note')).toBeNull();
	});

	it('Clear all while a chain is pinned under an action returns every filter to its default', async() =>
	{
		const element = await createComponent();
		await openActionByDeepLink(element);
		queryAll(element, 'action-chain-chip')[1].click();
		await flushAll();
		mockCallControllerMethod.mockClear();

		buttonByLabel(element, 'Clear all').click();
		await flushAll();

		const request = lastRequestFor(getLogEntries);
		expect(request.rootCorrelationId).toBeNull();
		expect(request.correlationId).toBeNull();
		expect(request.levels).toEqual([
			'ERROR',
			'WARN'
		]);
		expect(request.customStart).toBeNull();
		expect(request.windowMinutes).toBe(DEFAULT_WINDOW_MINUTES);
		// The oldest-first sort belongs to the opened action, so it goes back with everything else.
		expect(request.sortAscending).toBe(false);
		expect(query(element, 'action-pill')).toBeNull();
		expect(query(element, 'correlation-pill')).toBeNull();
		expect(query(element, 'action-banner')).toBeNull();
		expect(query(element, 'action-range-note')).toBeNull();
	});

	it('drops a page turn that answers while an action\'s summary is being read', async() =>
	{
		const FIRST_PAGE = {records: [{...MOCK_ENTRY_PAGE.records[0], logNumber: 'L-010'}], totalCount: 4, pageNumber: 1, totalPages: 4, hasMorePages: true};
		const STALE_PAGE = {records: [{...MOCK_ENTRY_PAGE.records[0], id: '001e9', logNumber: 'L-099'}], totalCount: 4, pageNumber: 4, totalPages: 4, hasMorePages: false};
		const ACTION_PAGE = {records: [{...MOCK_ENTRY_PAGE.records[0], logNumber: 'L-010'}], totalCount: 1, pageNumber: 1, totalPages: 1, hasMorePages: false};
		let releaseTurn = null;
		let releaseSummary = null;
		let entriesCallCount = 0;
		mockCallControllerMethod.mockImplementation((apexFn) =>
		{
			if(apexFn === getLogEntries)
			{
				entriesCallCount++;
				if(entriesCallCount === 2)
				{
					return new Promise((resolve) =>
					{
						releaseTurn = () => resolve(STALE_PAGE);
					});
				}
				return Promise.resolve(entriesCallCount === 1 ? FIRST_PAGE : ACTION_PAGE);
			}
			if(apexFn === getActionSummary)
			{
				return new Promise((resolve) =>
				{
					releaseSummary = () => resolve(MOCK_ACTION_SUMMARY);
				});
			}
			if(apexFn === getLogProblems)
			{
				return Promise.resolve(MOCK_PROBLEM_PAGE);
			}
			if(apexFn === getLogSummary)
			{
				return Promise.resolve(MOCK_SUMMARY);
			}
			return Promise.resolve(apexFn === getEntrySummary ? MOCK_ENTRY_SUMMARY : null);
		});
		const element = await createComponent();
		buttonByLabel(element, 'Individual entries').dispatchEvent(new CustomEvent('click'));
		await flushAll();
		// The turn is left in flight: its answer is still owed when the action arrives.
		await turnToNextPage(element);

		CurrentPageReference.emit({state: {c__rootCorrelationId: ACTION_ID, c__viewLogsAt: '2000'}});
		await Promise.resolve();
		releaseTurn();
		await flushAll();
		releaseSummary();
		await flushAll();
		await flushAll();

		const request = lastRequestFor(getLogEntries);
		expect(request.rootCorrelationId).toBe(ACTION_ID);
		expect(request.pageNumber).toBe(1);
		expect(table(element).data.map((row) => row.logNumber)).toEqual(['L-010']);
	});

	it('clears the range note once the reader changes the range', async() =>
	{
		const element = await createComponent();
		await openActionByDeepLink(element);
		expect(query(element, 'action-range-note')).toBeTruthy();

		dateRangeCombobox(element).dispatchEvent(new CustomEvent('change', {detail: {value: '60'}}));
		await flushAll();

		expect(query(element, 'action-range-note')).toBeNull();
		expect(lastRequestFor(getLogEntries).rootCorrelationId).toBe(ACTION_ID);
	});

	it('words a restarted chain as a restart of the run it repeats, and says nothing about more chains when there are none', async() =>
	{
		const restartChip = {...CHIP_A, launchKind: 'RESTART', launcherName: 'OrderSync · CHAIN-00213'};
		wireMockResponses({actionSummary: {...MOCK_ACTION_SUMMARY, chains: [restartChip], moreChainCount: 0}});
		const element = await createComponent();

		await openActionByDeepLink(element);

		expect(queryAll(element, 'action-chain-chip')[0].textContent).toContain('restart of OrderSync · CHAIN-00213');
		expect(query(element, 'action-more-chains')).toBeNull();
	});

	it('drops a summary whose action was replaced before it landed, so the newer action is the one on screen', async() =>
	{
		const SECOND_ACTION_ID = 'b8e3a5d2-2222-4222-8222-00000000f14b';
		const element = await createComponent();
		mockCallControllerMethod.mockClear();

		// Two hand-offs in one turn: the first action's summary resolves after the second has already been pinned,
		// and applying it would set the range and the banner of an action the reader has left behind.
		CurrentPageReference.emit({state: {c__rootCorrelationId: ACTION_ID, c__viewLogsAt: '1000'}});
		CurrentPageReference.emit({state: {c__rootCorrelationId: SECOND_ACTION_ID, c__viewLogsAt: '2000'}});
		await flushAll();
		await flushAll();

		expect(query(element, 'action-pill').label).toBe('Action: b8e3a5d2…f14b');
		expect(lastRequestFor(getLogEntries).rootCorrelationId).toBe(SECOND_ACTION_ID);
		// One list load, not two: the abandoned action never reaches the list at all.
		expect(callCountFor(getLogEntries)).toBe(1);
	});

	it('refreshes the banner as well as the list while an action is pinned, and leaves the range the reader chose alone', async() =>
	{
		const READER_WINDOW_MINUTES = 60;
		const element = await createComponent();
		await openActionByDeepLink(element);
		// The reader picks their own range after opening the action, which clears the note that explained the lifetime one.
		dateRangeCombobox(element).dispatchEvent(new CustomEvent('change', {detail: {value: String(READER_WINDOW_MINUTES)}}));
		await flushAll();
		mockCallControllerMethod.mockClear();

		buttonByLabel(element, 'Refresh').click();
		await flushAll();
		await flushAll();

		expect(callCountFor(getActionSummary)).toBe(1);
		expect(query(element, 'action-banner')).toBeTruthy();
		const request = lastRequestFor(getLogEntries);
		expect(request.rootCorrelationId).toBe(ACTION_ID);
		// Refresh re-reads the banner and nothing else: pulling the reader back to the action's lifetime, and putting the
		// note back up over a range they had chosen themselves, is what this guards against.
		expect(request.windowMinutes).toBe(READER_WINDOW_MINUTES);
		expect(request.customStart).toBeNull();
		expect(query(element, 'action-range-note')).toBeNull();
	});

	it('moves the end of a running action\'s range on every refresh, to its real end once it has one, and then stops', async() =>
	{
		const OPENED_AT = new Date('2026-09-01T10:01:00.000Z');
		const FIRST_REFRESH_AT = new Date('2026-09-01T10:02:00.000Z');
		const SECOND_REFRESH_AT = new Date('2026-09-01T10:05:00.000Z');
		const THIRD_REFRESH_AT = new Date('2026-09-01T10:09:00.000Z');
		const ENDED_RANGE_END = new Date(new Date(ACTION_END).getTime() + ACTION_RANGE_MARGIN_MILLISECONDS).toISOString();
		const refreshAt = async(element, instant) =>
		{
			jest.setSystemTime(instant);
			buttonByLabel(element, 'Refresh').click();
			await flushAll();
			await flushAll();
			return lastRequestFor(getLogEntries);
		};
		jest.useFakeTimers();
		try
		{
			jest.setSystemTime(OPENED_AT);
			wireMockResponses({actionSummary: RUNNING_ACTION_SUMMARY});
			const element = await createComponent();
			await openActionByDeepLink(element);
			expect(lastRequestFor(getLogEntries).customEnd).toBe(OPENED_AT.toISOString());

			const stillRunning = await refreshAt(element, FIRST_REFRESH_AT);
			expect(stillRunning.customEnd).toBe(FIRST_REFRESH_AT.toISOString());
			expect(customRangeInstant(element, 'toDate', 'toTime')).toBe(FIRST_REFRESH_AT.getTime());
			expect(query(element, 'action-range-note').textContent).toBe('Date range set to this action\'s lifetime.');

			wireMockResponses({actionSummary: MOCK_ACTION_SUMMARY});
			const ended = await refreshAt(element, SECOND_REFRESH_AT);
			expect(ended.customEnd).toBe(ENDED_RANGE_END);
			expect(query(element, 'action-range-note').textContent).toBe('Date range set to this action\'s lifetime.');

			const afterEnd = await refreshAt(element, THIRD_REFRESH_AT);
			expect(afterEnd.customEnd).toBe(ENDED_RANGE_END);
		}
		finally
		{
			jest.useRealTimers();
		}
	});

	it('keeps a running action\'s range, its note and its following when a refresh cannot read the summary', async() =>
	{
		const OPENED_AT = new Date('2026-09-01T10:01:00.000Z');
		const FAILED_REFRESH_AT = new Date('2026-09-01T10:02:00.000Z');
		const RECOVERED_REFRESH_AT = new Date('2026-09-01T10:03:00.000Z');
		const refreshAt = async(element, instant) =>
		{
			jest.setSystemTime(instant);
			mockCallControllerMethod.mockClear();
			buttonByLabel(element, 'Refresh').click();
			await flushAll();
			await flushAll();
		};
		jest.useFakeTimers();
		try
		{
			jest.setSystemTime(OPENED_AT);
			wireMockResponses({actionSummary: RUNNING_ACTION_SUMMARY});
			const element = await createComponent();
			await openActionByDeepLink(element);

			mockCallControllerMethod.mockImplementation((apexFn) => Promise.resolve(apexFn === getActionSummary ? undefined : MOCK_ENTRY_PAGE));
			await refreshAt(element, FAILED_REFRESH_AT);

			expect(callCountFor(getLogEntries)).toBe(1);
			expect(dateRangeCombobox(element).value).toBe('custom');
			expect(lastRequestFor(getLogEntries).customEnd).toBe(OPENED_AT.toISOString());
			expect(query(element, 'action-range-note').textContent).toBe('Date range set to this action\'s lifetime.');

			// Still following: the next refresh that reads the summary moves the end again.
			wireMockResponses({actionSummary: RUNNING_ACTION_SUMMARY});
			await refreshAt(element, RECOVERED_REFRESH_AT);

			expect(lastRequestFor(getLogEntries).customEnd).toBe(RECOVERED_REFRESH_AT.toISOString());
		}
		finally
		{
			jest.useRealTimers();
		}
	});

	it('keeps the range the reader picks while a refresh is still reading a running action\'s summary', async() =>
	{
		const OPENED_AT = new Date('2026-09-01T10:01:00.000Z');
		const REFRESHED_AT = new Date('2026-09-01T10:02:00.000Z');
		const READER_WINDOW_MINUTES = 60;
		jest.useFakeTimers();
		try
		{
			jest.setSystemTime(OPENED_AT);
			wireMockResponses({actionSummary: RUNNING_ACTION_SUMMARY});
			const element = await createComponent();
			await openActionByDeepLink(element);
			let answerSummary;
			const pendingSummary = new Promise((resolve) =>
			{
				answerSummary = resolve;
			});
			mockCallControllerMethod.mockImplementation((apexFn) => (apexFn === getActionSummary ? pendingSummary : Promise.resolve(MOCK_ENTRY_PAGE)));

			jest.setSystemTime(REFRESHED_AT);
			buttonByLabel(element, 'Refresh').click();
			await flushAll();
			// The reader picks their own range while the summary is still on its way.
			dateRangeCombobox(element).dispatchEvent(new CustomEvent('change', {detail: {value: String(READER_WINDOW_MINUTES)}}));
			await flushAll();
			answerSummary(RUNNING_ACTION_SUMMARY);
			await flushAll();
			await flushAll();

			expect(dateRangeCombobox(element).value).toBe(String(READER_WINDOW_MINUTES));
			const request = lastRequestFor(getLogEntries);
			expect(request.windowMinutes).toBe(READER_WINDOW_MINUTES);
			expect(request.customEnd).toBeNull();
			expect(query(element, 'action-range-note')).toBeNull();
		}
		finally
		{
			jest.useRealTimers();
		}
	});

	it('keeps following a running action after the reader narrows it to one chain and widens it back', async() =>
	{
		const OPENED_AT = new Date('2026-09-01T10:01:00.000Z');
		const REFRESHED_AT = new Date('2026-09-01T10:02:00.000Z');
		jest.useFakeTimers();
		try
		{
			jest.setSystemTime(OPENED_AT);
			wireMockResponses({actionSummary: {...RUNNING_ACTION_SUMMARY, chainCount: 1, chains: [CHIP_A]}});
			const element = await createComponent();
			await openActionByDeepLink(element);
			queryAll(element, 'action-chain-chip')[0].click();
			await flushAll();
			element.shadowRoot.querySelector('[data-testid="correlation-pill"]').dispatchEvent(new CustomEvent('remove'));
			await flushAll();

			jest.setSystemTime(REFRESHED_AT);
			buttonByLabel(element, 'Refresh').click();
			await flushAll();
			await flushAll();

			// The chain pill came and went inside the action, so the range still follows the action, which is still running.
			const request = lastRequestFor(getLogEntries);
			expect(request.correlationId).toBeNull();
			expect(request.rootCorrelationId).toBe(ACTION_ID);
			expect(request.customEnd).toBe(REFRESHED_AT.toISOString());
		}
		finally
		{
			jest.useRealTimers();
		}
	});

	it('returns the problems view to its own sort when the pill is removed there', async() =>
	{
		const element = await createComponent();
		await openActionByDeepLink(element);
		buttonByLabel(element, 'Problem summary').click();
		await flushAll();
		mockCallControllerMethod.mockClear();

		query(element, 'action-pill').dispatchEvent(new CustomEvent('remove'));
		await flushAll();

		// The pill spans both views, so removing it on the problems view must not send the entries list's sort key to
		// the problems query, where it means nothing.
		const request = lastRequestFor(getLogProblems);
		expect(request.sortField).toBe('level');
		expect(request.rootCorrelationId).toBeNull();
	});

	it('shows a tracking id too short to abbreviate whole in the pill', async() =>
	{
		const SHORT_ACTION_ID = 'run-42';
		const element = await createComponent();
		await selectRow(element, '001p1');

		element.shadowRoot.querySelector('c-log-console-detail').dispatchEvent(new CustomEvent('showwholeaction', {detail: {rootCorrelationId: SHORT_ACTION_ID}}));
		await flushAll();
		await flushAll();

		expect(query(element, 'action-pill').label).toBe('Action: run-42');
	});

	it('offers the chips and a shorter range as the way to narrow a capped list under an action', async() =>
	{
		const CAPPED_TOTAL = 500;
		wireMockResponses({entries: {...MOCK_ENTRY_PAGE, totalCount: CAPPED_TOTAL, resultsTruncated: true}});
		const element = await createComponent();

		await openActionByDeepLink(element);

		// Under an action "narrow the filters" is no help: the chips and the range are what there is to narrow.
		expect(query(element, 'capped-banner').textContent).toContain('Narrow to one chain or a shorter range to see the rest.');
	});

	it('reads a summary that carries only what it has: no counts, no chains, no duration', async() =>
	{
		// The server leaves a value out rather than sending null, so every count and list on the banner has to
		// read as its own empty rather than as "undefined".
		wireMockResponses({actionSummary: {rootCorrelationId: ACTION_ID, startedAt: ACTION_START, endedAt: ACTION_END, stillRunning: false, recordedBeforeRoots: false}});
		const element = await createComponent();

		await openActionByDeepLink(element);

		const sentence = query(element, 'action-banner-sentence');
		expect(sentence.textContent).toContain('and ran for .');
		expect(sentence.textContent).toContain('No chains ran under it.');
		expect(queryAll(element, 'action-chain-chip')).toHaveLength(0);
		expect(query(element, 'action-more-chains')).toBeNull();
		expect(query(element, 'action-open-chains')).toBeNull();
	});

	it('shows a status it has no wording for as the server sent it, and a launcher the server did not name as nothing', async() =>
	{
		const UNKNOWN_STATUS = 'Superseded';
		wireMockResponses({
			actionSummary: {
				rootCorrelationId: ACTION_ID,
				startedAt: ACTION_START,
				endedAt: ACTION_END,
				stillRunning: false,
				recordedBeforeRoots: false,
				chainCount: 2,
				durationLabel: '9s',
				chains: [
					{executionId: 'a00C', chainName: 'Ledger', chainNumber: 'CHAIN-00216', correlationId: 'run-c', status: UNKNOWN_STATUS, launchKind: 'CHAIN'},
					{executionId: 'a00D', chainName: 'Ledger', chainNumber: 'CHAIN-00217', correlationId: 'run-d', status: 'Running', launchKind: 'RESTART'}
				]
			}
		});
		const element = await createComponent();

		await openActionByDeepLink(element);

		// A failed count the server left out is none failed, not an unreadable sentence.
		expect(query(element, 'action-banner-sentence').textContent).toContain('It ran 2 chains, 0 of them failed.');
		const chips = queryAll(element, 'action-chain-chip');
		expect(chips[0].textContent).toContain(UNKNOWN_STATUS);
		expect(chips[0].textContent).toContain('launched by');
		expect(chips[1].textContent).toContain('restart of');
	});

	describe('the search resolver', () =>
	{
		const searchInput = (element) => element.shadowRoot.querySelector('.filter-search');

		// The shipped debounce idiom (the "filters by search term after the debounce settles" test above): set the input's
		// value, dispatch change, advance past the 300 ms debounce under fake timers, then flush the resolver's promise chain.
		async function typeAndSettle(element, term)
		{
			jest.useFakeTimers();
			try
			{
				const search = searchInput(element);
				search.value = term;
				search.dispatchEvent(new CustomEvent('change'));
				jest.advanceTimersByTime(300);
				await flushAll();
				await flushAll();
			}
			finally
			{
				jest.useRealTimers();
			}
		}

		it('opens the action a pasted action id names and clears the box', async() =>
		{
			wireMockResponses({resolvedSearchId: {kind: 'ACTION', id: ACTION_ID}});
			const element = await createComponent();
			mockCallControllerMethod.mockClear();

			await typeAndSettle(element, ACTION_ID);

			expect(mockCallControllerMethod.mock.calls.find((call) => call[0] === resolveSearchId)[1]).toEqual({term: ACTION_ID});
			expect(lastRequestFor(getLogEntries).rootCorrelationId).toBe(ACTION_ID);
			expect(lastRequestFor(getLogEntries).searchTerm).toBeNull();
			expect(searchInput(element).value).toBe('');
		});

		it('pins a pasted chain id as the chain pill, never as an action, and pushes it into the address', async() =>
		{
			const SECOND_CHAIN_ID = 'run-c';
			wireMockResponses({resolvedSearchId: {kind: 'CHAIN', id: 'run-b', chainName: 'Ledger', chainNumber: 'CHAIN-00215'}});
			const element = await createComponent();
			mockNavigate.mockClear();

			await typeAndSettle(element, ACTION_ID);

			const request = lastRequestFor(getLogEntries);
			expect(request.correlationId).toBe('run-b');
			expect(request.rootCorrelationId).toBeNull();
			expect(query(element, 'correlation-pill').label).toBe('Chain: Ledger · CHAIN-00215');
			expect(callCountFor(getActionSummary)).toBe(0);
			// The resolver has already said what this run is called, so the pill is worded from that answer rather
			// than from a second read of the same id.
			expect(callCountFor(resolveSearchId)).toBe(1);
			// The pin is a drill-in the reader made in place, so it goes into the address as a new history entry Back
			// can pop, exactly once.
			expect(mockNavigate).toHaveBeenCalledTimes(1);
			expect(mockNavigate.mock.calls[0][0].state).toEqual({c__correlationId: 'run-b'});
			expect(mockNavigate.mock.calls[0][1]).toBe(false);

			// The same paste under a pinned action pins the run alone: a run pasted from elsewhere need not belong to
			// the action on screen, so the action's pill and banner go rather than claim a narrowing that is not one.
			await openActionByDeepLink(element);
			wireMockResponses({resolvedSearchId: {kind: 'CHAIN', id: SECOND_CHAIN_ID, chainName: 'Ledger', chainNumber: 'CHAIN-00216'}});
			mockNavigate.mockClear();

			await typeAndSettle(element, ACTION_ID);

			expect(query(element, 'action-pill')).toBeNull();
			expect(query(element, 'action-banner')).toBeNull();
			expect(query(element, 'correlation-pill').label).toBe('Chain: Ledger · CHAIN-00216');
			const pastedRequest = lastRequestFor(getLogEntries);
			expect(pastedRequest.correlationId).toBe(SECOND_CHAIN_ID);
			expect(pastedRequest.rootCorrelationId).toBeNull();
			expect(mockNavigate).toHaveBeenCalledTimes(1);
			expect(mockNavigate.mock.calls[0][0].state).toEqual({c__correlationId: SECOND_CHAIN_ID});
			expect(mockNavigate.mock.calls[0][1]).toBe(false);

			// Back lands on the address the paste left behind, the action key alone, and re-pins the action whole: one
			// Back out of the drill-in, which is what makes the paste's history entry worth having.
			CurrentPageReference.emit({state: {c__rootCorrelationId: ACTION_ID}});
			await flushAll();
			await flushAll();
			await flushAll();

			expect(query(element, 'action-pill')).toBeTruthy();
			expect(query(element, 'correlation-pill')).toBeNull();
			expect(lastRequestFor(getLogEntries).rootCorrelationId).toBe(ACTION_ID);
		});

		it('ignores an answer about an id the reader has already cleared, and reads a box reporting no value as no search', async() =>
		{
			wireMockResponses({resolvedSearchId: {kind: 'ACTION', id: ACTION_ID}});
			const element = await createComponent();
			jest.useFakeTimers();
			try
			{
				const search = searchInput(element);
				search.value = ACTION_ID;
				search.dispatchEvent(new CustomEvent('change'));
				jest.advanceTimersByTime(300);

				// The reader empties the box while the server is still being asked about the pasted id — and a
				// cleared input reports no value at all. Opening that action now would pin a filter nobody asked
				// for any more.
				search.value = null;
				search.dispatchEvent(new CustomEvent('change'));
				await flushAll();
				await flushAll();

				expect(query(element, 'action-pill')).toBeNull();

				jest.advanceTimersByTime(300);
				await flushAll();
				expect(lastRequestFor(getLogProblems).searchTerm).toBeNull();
			}
			finally
			{
				jest.useRealTimers();
			}
		});

		it('searches an unrecognised id as text, and never asks about a term that is not shaped like an id', async() =>
		{
			const element = await createComponent();
			mockCallControllerMethod.mockClear();

			await typeAndSettle(element, ACTION_ID);
			expect(callCountFor(resolveSearchId)).toBe(1);
			expect(lastRequestFor(getLogProblems).searchTerm).toBe(ACTION_ID);

			await typeAndSettle(element, 'timeout');
			expect(callCountFor(resolveSearchId)).toBe(1);
			expect(lastRequestFor(getLogProblems).searchTerm).toBe('timeout');
		});
	});
});

describe('c-log-console list', () =>
{
	// More pages than the pager will ever offer as numbers, and enough of them that numbering would be a fiction.
	const MANY_PAGES = 3529;
	// A list one row longer than a page of twenty-five, so the position line can be read against real arithmetic: a full
	// page and then a page holding the last row.
	const CONSISTENT_TOTAL = 26;
	const SMALLEST_PAGE_SIZE = 25;

	let compactMedia;

	beforeEach(() =>
	{
		wireMockResponses();
		// jsdom has no matchMedia; the console reads it defensively, and this stub lets a test flip the width.
		compactMedia = {
			matches: false,
			listeners: new Set(),
			addEventListener: jest.fn((type, listener) => compactMedia.listeners.add(listener)),
			removeEventListener: jest.fn((type, listener) => compactMedia.listeners.delete(listener))
		};
		window.matchMedia = jest.fn(() => compactMedia);
	});

	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
		delete window.matchMedia;
		jest.clearAllMocks();
	});

	const query = (element, testId) => element.shadowRoot.querySelector(`[data-testid="${testId}"]`);
	const queryAll = (element, testId) => Array.from(element.shadowRoot.querySelectorAll(`[data-testid="${testId}"]`));

	async function entriesView(element)
	{
		element.shadowRoot.querySelector('lightning-button[data-view="entries"]').click();
		await flushAll();
	}

	// A server that fills its pages the way a real one does: pages of exactly the size the request asked for, the last
	// one holding what is left, and a page count derived from the same two numbers. That is what makes the position
	// line's arithmetic assertable rather than a fixture's fiction.
	function wireConsistentPages()
	{
		mockCallControllerMethod.mockImplementation((apexFn, params) =>
		{
			if(apexFn === getLogEntries)
			{
				const request = JSON.parse(params.requestJson);
				const rowsBefore = (request.pageNumber - 1) * request.pageSize;
				const rowsOnPage = Math.max(Math.min(request.pageSize, CONSISTENT_TOTAL - rowsBefore), 0);
				return Promise.resolve({
					records: Array.from({length: rowsOnPage}, (unused, index) => ({
						...MOCK_ENTRY_PAGE.records[0], id: `row-${rowsBefore + index}`, logNumber: `L-${rowsBefore + index}`
					})),
					totalCount: CONSISTENT_TOTAL,
					pageNumber: request.pageNumber,
					totalPages: Math.ceil(CONSISTENT_TOTAL / request.pageSize),
					hasMorePages: rowsBefore + rowsOnPage < CONSISTENT_TOTAL,
					resultsTruncated: false
				});
			}
			return Promise.resolve(apexFn === getEntrySummary ? MOCK_ENTRY_SUMMARY : null);
		});
	}

	it('names the chain behind each row, says "this action" for the action\'s own entry, and dashes a row with no correlation', async() =>
	{
		wireMockResponses({
			entries: {
				...MOCK_ENTRY_PAGE, records: [
					{...MOCK_ENTRY_PAGE.records[0], id: 'r1', correlationId: 'run-a', chainName: 'OrderSync', chainNumber: 'CHAIN-00214', isActionOwn: false},
					{...MOCK_ENTRY_PAGE.records[0], id: 'r2', correlationId: 'act', chainName: null, chainNumber: null, isActionOwn: true},
					{...MOCK_ENTRY_PAGE.records[0], id: 'r3', correlationId: null, chainName: null, chainNumber: null, isActionOwn: false}
				], totalCount: 3
			}
		});
		const element = await createComponent();
		await entriesView(element);

		expect(columnFieldNames(element)).toEqual([
			'logNumberDisplay',
			'createdDate',
			'level',
			'shortMessage',
			'sourceDisplay',
			'contextDisplay',
			'chainDisplay'
		]);
		const chainColumn = table(element).columns.find((column) => column.fieldName === 'chainDisplay');
		expect(chainColumn.label).toBe('Chain');
		expect(chainColumn.sortable).toBe(false);
		expect(table(element).data.map((row) => row.chainDisplay)).toEqual([
			'OrderSync · CHAIN-00214',
			'this action',
			'—'
		]);
	});

	it('pages instead of appending: the position line, the page sizes, Previous and Next, and page numbers while there are few enough', async() =>
	{
		wireConsistentPages();
		const element = await createComponent();
		await entriesView(element);

		expect(table(element).enableInfiniteLoading).toBeFalsy();
		// Twenty-six rows fit one page of fifty, so the position line covers the lot and there is nowhere to go.
		expect(query(element, 'entries-position').textContent).toBe('Rows 1 to 26 of 26');
		expect(query(element, 'pager-size').options.map((option) => option.label)).toEqual([
			'25 per page',
			'50 per page',
			'100 per page'
		]);

		query(element, 'pager-size').dispatchEvent(new CustomEvent('change', {detail: {value: String(SMALLEST_PAGE_SIZE)}}));
		await flushAll();
		expect(query(element, 'entries-position').textContent).toBe('Rows 1 to 25 of 26');
		expect(queryAll(element, 'pager-page').map((button) => button.label)).toEqual([
			'1',
			'2'
		]);
		expect(query(element, 'pager-previous').disabled).toBe(true);

		// The guard behind the disabled button: a click that reaches it anyway must not walk off the front.
		query(element, 'pager-previous').click();
		await flushAll();
		expect(lastRequestFor(getLogEntries).pageNumber).toBe(1);

		query(element, 'pager-next').click();
		await flushAll();
		expect(lastRequestFor(getLogEntries).pageNumber).toBe(2);
		// The last page holds the twenty-sixth row alone, and it replaces the twenty-five before it.
		expect(table(element).data).toHaveLength(1);
		expect(query(element, 'entries-position').textContent).toBe('Rows 26 to 26 of 26');
		expect(query(element, 'pager-previous').disabled).toBe(false);
		expect(query(element, 'pager-next').disabled).toBe(true);

		// The same guard at the other end of the list.
		query(element, 'pager-next').click();
		await flushAll();
		expect(lastRequestFor(getLogEntries).pageNumber).toBe(2);
	});

	it('walks back with Previous and forward by number, and ignores a click on the page already on screen', async() =>
	{
		wireConsistentPages();
		const element = await createComponent();
		await entriesView(element);
		query(element, 'pager-size').dispatchEvent(new CustomEvent('change', {detail: {value: String(SMALLEST_PAGE_SIZE)}}));
		await flushAll();
		query(element, 'pager-next').click();
		await flushAll();
		expect(lastRequestFor(getLogEntries).pageNumber).toBe(2);

		// The page already on screen is where the reader is; clicking its own number costs nothing.
		const readsAtPageTwo = callCountFor(getLogEntries);
		queryAll(element, 'pager-page')[1].click();
		await flushAll();
		expect(callCountFor(getLogEntries)).toBe(readsAtPageTwo);

		query(element, 'pager-previous').click();
		await flushAll();
		expect(lastRequestFor(getLogEntries).pageNumber).toBe(1);
		expect(query(element, 'entries-position').textContent).toBe('Rows 1 to 25 of 26');

		queryAll(element, 'pager-page')[1].click();
		await flushAll();
		expect(lastRequestFor(getLogEntries).pageNumber).toBe(2);
		expect(query(element, 'entries-position').textContent).toBe('Rows 26 to 26 of 26');
	});

	it('turns the page without re-reading the ribbon, and keeps the rows and the pager on screen while the next page is in flight', async() =>
	{
		wireConsistentPages();
		const element = await createComponent();
		await entriesView(element);
		query(element, 'pager-size').dispatchEvent(new CustomEvent('change', {detail: {value: String(SMALLEST_PAGE_SIZE)}}));
		await flushAll();
		const ribbonReads = callCountFor(getEntrySummary);

		let releasePage = null;
		mockCallControllerMethod.mockImplementation((apexFn) =>
		{
			if(apexFn === getLogEntries)
			{
				return new Promise((resolve) =>
				{
					releasePage = resolve;
				});
			}
			return Promise.resolve(apexFn === getEntrySummary ? MOCK_ENTRY_SUMMARY : null);
		});

		query(element, 'pager-next').click();
		await flushAll();

		// In flight: the rows the reader was reading are still there under the datatable's own spinner, and so is the
		// pager, still saying where they are. A whole reload would have taken all three away.
		expect(table(element).isLoading).toBe(true);
		expect(table(element).data).toHaveLength(SMALLEST_PAGE_SIZE);
		expect(query(element, 'entries-pager')).not.toBeNull();
		expect(query(element, 'entries-position').textContent).toBe('Rows 1 to 25 of 26');

		releasePage({
			records: [{...MOCK_ENTRY_PAGE.records[0], id: 'row-25', logNumber: 'L-25'}],
			totalCount: CONSISTENT_TOTAL,
			pageNumber: 2,
			totalPages: 2,
			hasMorePages: false,
			resultsTruncated: false
		});
		await flushAll();

		expect(table(element).isLoading).toBe(false);
		expect(query(element, 'entries-position').textContent).toBe('Rows 26 to 26 of 26');
		// The ribbon counts the window, not the page, so a turn never asks for it again.
		expect(callCountFor(getEntrySummary)).toBe(ribbonReads);
	});

	it('shows no page numbers past seven pages, keeps Previous and Next, and a page-size change returns to page one', async() =>
	{
		wirePagedResponses(MANY_PAGES);
		const element = await createComponent();
		await entriesView(element);

		expect(queryAll(element, 'pager-page')).toHaveLength(0);
		expect(query(element, 'pager-next')).toBeTruthy();
		query(element, 'pager-next').click();
		await flushAll();
		expect(lastRequestFor(getLogEntries).pageNumber).toBe(2);

		query(element, 'pager-size').dispatchEvent(new CustomEvent('change', {detail: {value: '100'}}));
		await flushAll();
		const request = lastRequestFor(getLogEntries);
		expect(request.pageSize).toBe(100);
		expect(request.pageNumber).toBe(1);
	});

	it('hides the pager over an empty list and pages the problems view the same way', async() =>
	{
		wireMockResponses({problems: {...MOCK_PROBLEM_PAGE, records: [], totalCount: 0, totalPages: 0}});
		const empty = await createComponent();
		expect(query(empty, 'entries-pager')).toBeNull();

		wirePagedResponses(2);
		const problems = await createComponent();
		expect(query(problems, 'entries-position').textContent).toBe('Rows 1 to 1 of 2');
		query(problems, 'pager-next').click();
		await flushAll();
		expect(lastRequestFor(getLogProblems).pageNumber).toBe(2);
	});

	it('keeps four columns with the drawer open at a compact width, restores them when the drawer closes or the width grows, and keeps the sort', async() =>
	{
		compactMedia.matches = true;
		const element = await createComponent();
		await entriesView(element);
		expect(columnFieldNames(element)).toHaveLength(7);

		table(element).dispatchEvent(new CustomEvent('sort', {detail: {fieldName: 'createdDate', sortDirection: 'asc'}}));
		await flushAll();
		await selectRow(element, '001e1');
		expect(columnFieldNames(element)).toEqual([
			'createdDate',
			'level',
			'shortMessage',
			'chainDisplay'
		]);
		expect(table(element).sortedBy).toBe('createdDate');
		expect(table(element).sortedDirection).toBe('asc');

		element.shadowRoot.querySelector('c-log-console-detail').dispatchEvent(new CustomEvent('close'));
		await flushAll();
		expect(columnFieldNames(element)).toHaveLength(7);

		await selectRow(element, '001e1');
		compactMedia.listeners.forEach((listener) => listener({matches: false}));
		await flushAll();
		expect(columnFieldNames(element)).toHaveLength(7);
	});

	it('keeps Level, Problem, Count and Last seen in Problems with the drawer open at a compact width, and all seven otherwise', async() =>
	{
		compactMedia.matches = true;
		const element = await createComponent();
		const labelsOf = () => table(element).columns.map((column) => column.label);
		expect(labelsOf()).toHaveLength(7);

		await selectRow(element, '001p1');
		expect(labelsOf()).toEqual([
			'Level',
			'Problem',
			'Count',
			'Last seen'
		]);

		compactMedia.listeners.forEach((listener) => listener({matches: false}));
		await flushAll();
		expect(labelsOf()).toHaveLength(7);
	});

	it('offers Back to the list on the drawer and closes it, and works without matchMedia', async() =>
	{
		const element = await createComponent();
		await entriesView(element);
		await selectRow(element, '001e1');

		expect(query(element, 'back-to-list').label).toBe('Back to the list');
		query(element, 'back-to-list').click();
		await flushAll();
		expect(query(element, 'detail-panel')).toBeNull();

		delete window.matchMedia;
		const bare = await createComponent();
		await entriesView(bare);
		await selectRow(bare, '001e1');
		expect(columnFieldNames(bare)).toHaveLength(7);
	});

	it('runs a teardown registered through the base when disconnected, and still stops listening to the width', async() =>
	{
		const element = await createComponent();
		const operation = jest.fn();
		element.addTearDownOperation(operation);

		document.body.removeChild(element);

		expect(operation).toHaveBeenCalledTimes(1);
		expect(compactMedia.removeEventListener).toHaveBeenCalledTimes(1);
	});
});

describe('c-log-console address', () =>
{
	const HOST_PAGE = {type: 'standard__navItemPage', attributes: {apiName: 'My_Operations_Workspace'}};
	const LATER_WINDOW_START = '2026-06-01T09:01:00.000Z';

	beforeEach(() => wireMockResponses());

	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
		jest.clearAllMocks();
	});

	const query = (element, testId) => element.shadowRoot.querySelector(`[data-testid="${testId}"]`);
	const queryAll = (element, testId) => Array.from(element.shadowRoot.querySelectorAll(`[data-testid="${testId}"]`));

	// The wire delivering an address to a live console: the page it is hosted on, carrying the state given. Three
	// flushes, because mirroring an address can cost a summary read, a chain-naming read and then the list.
	async function deliver(state, reference = HOST_PAGE)
	{
		CurrentPageReference.emit({...reference, state});
		await flushAll();
		await flushAll();
		await flushAll();
	}

	// The drawer raises showwholeaction, so the drawer has to be open for the event to come from where it comes from.
	async function showWholeActionFromDrawer(element, rowId)
	{
		await selectRow(element, rowId);
		element.shadowRoot.querySelector('c-log-console-detail').dispatchEvent(new CustomEvent('showwholeaction', {detail: {rootCorrelationId: ACTION_ID}}));
		await flushAll();
		await flushAll();
	}

	const lastNavigation = () => mockNavigate.mock.calls[mockNavigate.mock.calls.length - 1];

	it('pins the action a plain address names, and a second delivery of the same address changes nothing', async() =>
	{
		const element = await createComponent();
		mockCallControllerMethod.mockClear();

		await deliver({c__rootCorrelationId: ACTION_ID});
		expect(query(element, 'action-pill').label).toBe('Action: a7d2f4c1…f13a');
		expect(lastRequestFor(getLogEntries).rootCorrelationId).toBe(ACTION_ID);
		expect(mockNavigate).not.toHaveBeenCalled();

		mockCallControllerMethod.mockClear();
		await deliver({c__rootCorrelationId: ACTION_ID});
		expect(mockCallControllerMethod).not.toHaveBeenCalled();
	});

	it('unpins the action when every key leaves the address, putting the levels and the sort back', async() =>
	{
		const element = await createComponent();
		await deliver({c__rootCorrelationId: ACTION_ID});
		expect(query(element, 'action-pill')).toBeTruthy();

		await deliver({});

		expect(query(element, 'action-pill')).toBeNull();
		expect(query(element, 'action-banner')).toBeNull();
		const request = lastRequestFor(getLogEntries);
		expect(request.rootCorrelationId).toBeNull();
		expect(request.levels).toEqual([
			'ERROR',
			'WARN'
		]);
		expect(request.sortAscending).toBe(false);
		// Mirroring an address writes nothing back: the address is already what it says, and a write here would
		// rewrite a history entry the reader is standing on.
		expect(mockNavigate).not.toHaveBeenCalled();
	});

	it('narrows the pinned action to the chain beside it, named from the chips, and widens when the chain key leaves', async() =>
	{
		const element = await createComponent();

		await deliver({c__rootCorrelationId: ACTION_ID, c__correlationId: 'run-a'});
		expect(query(element, 'action-pill')).toBeTruthy();
		expect(query(element, 'correlation-pill').label).toBe('Chain: OrderSync · CHAIN-00214');
		expect(lastRequestFor(getLogEntries).correlationId).toBe('run-a');
		expect(callCountFor(resolveSearchId)).toBe(0);

		await deliver({c__rootCorrelationId: ACTION_ID});
		expect(query(element, 'correlation-pill')).toBeNull();
		expect(query(element, 'action-pill')).toBeTruthy();
		expect(lastRequestFor(getLogEntries).correlationId).toBeNull();
		expect(lastRequestFor(getLogEntries).rootCorrelationId).toBe(ACTION_ID);

		// Forward onto a chip's address again: the action is the one already pinned, so only the chain changes, and it
		// is named from the chips the console is still holding.
		await deliver({c__rootCorrelationId: ACTION_ID, c__correlationId: 'run-b'});
		expect(query(element, 'correlation-pill').label).toBe('Chain: Ledger · CHAIN-00215');
		expect(lastRequestFor(getLogEntries).correlationId).toBe('run-b');
		expect(lastRequestFor(getLogEntries).rootCorrelationId).toBe(ACTION_ID);
		expect(callCountFor(resolveSearchId)).toBe(0);
		// Narrowing and widening to follow an address writes no address of its own: Back and Forward would otherwise
		// rewrite the very entries they landed on.
		expect(mockNavigate).not.toHaveBeenCalled();
	});

	it('lets a later address win while the chain beside an action is still being read', async() =>
	{
		const element = await createComponent();
		let releaseSummary = null;
		// The first controller call the delivery makes is the action's summary, so a single one-shot implementation
		// holds exactly that read; nothing else can reach the list until it answers.
		mockCallControllerMethod.mockImplementationOnce(() => new Promise((resolve) =>
		{
			releaseSummary = () => resolve(MOCK_ACTION_SUMMARY);
		}));

		CurrentPageReference.emit({...HOST_PAGE, state: {c__rootCorrelationId: ACTION_ID, c__correlationId: 'run-a'}});
		await flushAll();
		// The reader widens back to the whole action before the summary answers. The address says the whole action, so
		// the summary landing afterwards must not narrow the console to the chain the address has left behind.
		await deliver({c__rootCorrelationId: ACTION_ID});
		releaseSummary();
		await flushAll();
		await flushAll();
		await flushAll();

		expect(query(element, 'correlation-pill')).toBeNull();
		expect(query(element, 'action-pill')).toBeTruthy();
		expect(lastRequestFor(getLogEntries).correlationId).toBeNull();
		expect(lastRequestFor(getLogEntries).rootCorrelationId).toBe(ACTION_ID);
	});

	it('names a chain the chips do not list through the resolver, and keeps the raw id when the resolver knows no run', async() =>
	{
		wireMockResponses({resolvedSearchId: {kind: 'CHAIN', id: 'run-z', chainName: 'Ledger', chainNumber: 'CHAIN-00215'}});
		const element = await createComponent();

		await deliver({c__rootCorrelationId: ACTION_ID, c__correlationId: 'run-z'});
		expect(mockCallControllerMethod.mock.calls.find((call) => call[0] === resolveSearchId)[1]).toEqual({term: 'run-z'});
		expect(query(element, 'correlation-pill').label).toBe('Chain: Ledger · CHAIN-00215');

		wireMockResponses({resolvedSearchId: {kind: 'NONE'}});
		await deliver({c__correlationId: 'run-unknown'});
		expect(query(element, 'correlation-pill').label).toContain('run-unknown');
		expect(query(element, 'action-pill')).toBeNull();
	});

	it('names the pill after the run now pinned, never after a slower answer for the run before it', async() =>
	{
		const SLOW_RUN = 'run-slow';
		const FAST_RUN = 'run-fast';
		const element = await createComponent();
		let releaseFirstName = null;
		const answerFor = mockCallControllerMethod.getMockImplementation();
		mockCallControllerMethod.mockImplementation((apexFunction, parameters) =>
		{
			if(apexFunction === resolveSearchId)
			{
				return parameters.term === SLOW_RUN ? new Promise((resolve) =>
				{
					releaseFirstName = () => resolve({kind: 'CHAIN', id: SLOW_RUN, chainName: 'OrderSync', chainNumber: 'CHAIN-00214'});
				}) : Promise.resolve({kind: 'CHAIN', id: FAST_RUN, chainName: 'Ledger', chainNumber: 'CHAIN-00215'});
			}
			return answerFor(apexFunction, parameters);
		});

		CurrentPageReference.emit({...HOST_PAGE, state: {c__correlationId: SLOW_RUN}});
		await flushAll();
		await deliver({c__correlationId: FAST_RUN});
		expect(query(element, 'correlation-pill').label).toBe('Chain: Ledger · CHAIN-00215');

		// The first run's name arrives after the second run is the one pinned; wording the pill after it would name
		// one chain over another chain's rows.
		releaseFirstName();
		await flushAll();
		await flushAll();

		expect(query(element, 'correlation-pill').label).toBe('Chain: Ledger · CHAIN-00215');
		expect(lastRequestFor(getLogEntries).correlationId).toBe(FAST_RUN);
	});

	it('asks for the rows while the pill is still being named, so the wait shows the spinner and not an empty list', async() =>
	{
		let releaseName = null;
		let releaseRows = null;
		const answerFor = mockCallControllerMethod.getMockImplementation();
		mockCallControllerMethod.mockImplementation((apexFunction, parameters) =>
		{
			if(apexFunction === resolveSearchId)
			{
				return new Promise((resolve) =>
				{
					releaseName = () => resolve({kind: 'CHAIN', id: 'deep-1', chainName: 'OrderSync', chainNumber: 'CHAIN-00214'});
				});
			}
			// The first page of rows is held too, so the wait itself can be read: with both reads in flight the
			// console has to be showing the spinner.
			if(apexFunction === getLogEntries && !releaseRows)
			{
				return new Promise((resolve) =>
				{
					releaseRows = () => resolve(answerFor(apexFunction, parameters));
				});
			}
			return answerFor(apexFunction, parameters);
		});
		const element = createElement('c-log-console', {is: LogConsole});

		// The hand-off's address reaches the wire before the console mounts, which is how a View logs click arrives.
		CurrentPageReference.emit({...HOST_PAGE, state: {c__correlationId: 'deep-1', c__viewLogsAt: '1000'}});
		document.body.appendChild(element);
		await flushAll();
		await flushAll();

		// The resolver has still not answered, and the rows have been asked for anyway: the reader waits on the
		// spinner rather than on "no logs match these filters", which is the worst thing to say about a list that
		// was never read.
		expect(releaseName).not.toBeNull();
		expect(lastRequestFor(getLogEntries).correlationId).toBe('deep-1');
		expect(element.shadowRoot.querySelector('lightning-spinner')).toBeTruthy();
		expect(query(element, 'empty-state')).toBeNull();

		releaseRows();
		releaseName();
		await flushAll();
		await flushAll();

		expect(query(element, 'correlation-pill').label).toBe('Chain: OrderSync · CHAIN-00214');
		expect(query(element, 'empty-state')).toBeNull();
	});

	it('drops a stale chain name under a pinned action as well, and the reload that came with it', async() =>
	{
		const SLOW_RUN = 'run-slow';
		const FAST_RUN = 'run-fast';
		const element = await createComponent();
		await deliver({c__rootCorrelationId: ACTION_ID});
		let releaseFirstName = null;
		const answerFor = mockCallControllerMethod.getMockImplementation();
		mockCallControllerMethod.mockImplementation((apexFunction, parameters) =>
		{
			if(apexFunction === resolveSearchId)
			{
				return parameters.term === SLOW_RUN ? new Promise((resolve) =>
				{
					releaseFirstName = () => resolve({kind: 'CHAIN', id: SLOW_RUN, chainName: 'OrderSync', chainNumber: 'CHAIN-00214'});
				}) : Promise.resolve({kind: 'CHAIN', id: FAST_RUN, chainName: 'Ledger', chainNumber: 'CHAIN-00215'});
			}
			return answerFor(apexFunction, parameters);
		});

		CurrentPageReference.emit({...HOST_PAGE, state: {c__rootCorrelationId: ACTION_ID, c__correlationId: SLOW_RUN}});
		await flushAll();
		await deliver({c__rootCorrelationId: ACTION_ID, c__correlationId: FAST_RUN});
		mockCallControllerMethod.mockClear();

		releaseFirstName();
		await flushAll();
		await flushAll();

		expect(query(element, 'correlation-pill').label).toBe('Chain: Ledger · CHAIN-00215');
		// The narrowing that lost the race reloads nothing either: the list already answers the address.
		expect(mockCallControllerMethod).not.toHaveBeenCalled();
	});

	it('drops a stale chain name while the action is being opened, keeping the name of the chain now narrowed to', async() =>
	{
		const UNLISTED_RUN = 'run-unlisted';
		const element = await createComponent();
		let releaseFirstName = null;
		const answerFor = mockCallControllerMethod.getMockImplementation();
		mockCallControllerMethod.mockImplementation((apexFunction, parameters) =>
		{
			if(apexFunction === resolveSearchId && parameters.term === UNLISTED_RUN)
			{
				return new Promise((resolve) =>
				{
					releaseFirstName = () => resolve({kind: 'CHAIN', id: UNLISTED_RUN, chainName: 'Ledger', chainNumber: 'CHAIN-00215'});
				});
			}
			return answerFor(apexFunction, parameters);
		});

		// Nothing is pinned yet, so opening the action owns the naming; the chain beside it is not one the banner's
		// chips list, so its name has to be read through the resolver.
		CurrentPageReference.emit({...HOST_PAGE, state: {c__rootCorrelationId: ACTION_ID, c__correlationId: UNLISTED_RUN}});
		await flushAll();
		await deliver({c__rootCorrelationId: ACTION_ID, c__correlationId: 'run-a'});
		expect(query(element, 'correlation-pill').label).toBe('Chain: OrderSync · CHAIN-00214');

		// The first chain's name arrives once the address has moved to another chain of the same action: wording the
		// pill after it would name one chain over another chain's rows.
		releaseFirstName();
		await flushAll();
		await flushAll();

		expect(query(element, 'correlation-pill').label).toBe('Chain: OrderSync · CHAIN-00214');
		expect(lastRequestFor(getLogEntries).correlationId).toBe('run-a');
	});

	it('pins a run with the window beside it from a plain address, dropping a pinned action, and unpins when every key leaves', async() =>
	{
		const element = await createComponent();
		await deliver({c__rootCorrelationId: ACTION_ID});

		await deliver({c__correlationId: 'deep-1', c__windowStart: DEEP_LINK_START, c__windowEnd: DEEP_LINK_END});
		expect(query(element, 'action-pill')).toBeNull();
		expect(query(element, 'correlation-pill')).toBeTruthy();
		const request = lastRequestFor(getLogEntries);
		expect(request.correlationId).toBe('deep-1');
		expect(request.rootCorrelationId).toBeNull();
		expect(request.customStart).toBe(DEEP_LINK_START);
		expect(request.customEnd).toBe(DEEP_LINK_END);

		await deliver({});
		expect(query(element, 'correlation-pill')).toBeNull();
		expect(lastRequestFor(getLogEntries).correlationId).toBeNull();
	});

	it('re-applies the window when the same chain key arrives with a different one, and does nothing on an identical address', async() =>
	{
		const element = await createComponent();
		await deliver({c__correlationId: 'deep-1', c__windowStart: DEEP_LINK_START, c__windowEnd: DEEP_LINK_END});
		expect(lastRequestFor(getLogEntries).customStart).toBe(DEEP_LINK_START);

		// Back and Forward between two normalised hand-offs of the same run: same chain key, a different window. The
		// window is part of what the address records, so it is re-applied.
		await deliver({c__correlationId: 'deep-1', c__windowStart: LATER_WINDOW_START, c__windowEnd: DEEP_LINK_END});
		expect(lastRequestFor(getLogEntries).customStart).toBe(LATER_WINDOW_START);
		expect(query(element, 'correlation-pill')).toBeTruthy();

		mockCallControllerMethod.mockClear();
		await deliver({c__correlationId: 'deep-1', c__windowStart: LATER_WINDOW_START, c__windowEnd: DEEP_LINK_END});
		expect(mockCallControllerMethod).not.toHaveBeenCalled();
	});

	// A pasted id pushes the same way: the bare-reference test in the filtering describe proves that one, because a
	// console with no action pinned has no chips to click.
	it('pushes the address on Show the whole action and on a chip, on the host page, never with replace', async() =>
	{
		const element = await createComponent();
		await deliver({c__hostTab: 'monitoring'});
		mockNavigate.mockClear();

		await showWholeActionFromDrawer(element, '001p1');
		expect(query(element, 'action-pill')).toBeTruthy();
		expect(mockNavigate).toHaveBeenCalledTimes(1);
		expect(lastNavigation()[0]).toEqual({...HOST_PAGE, state: {c__hostTab: 'monitoring', c__rootCorrelationId: ACTION_ID}});
		expect(lastNavigation()[1]).toBe(false);

		mockNavigate.mockClear();
		queryAll(element, 'action-chain-chip')[0].click();
		await flushAll();
		await flushAll();
		expect(mockNavigate).toHaveBeenCalledTimes(1);
		expect(lastNavigation()[0].state).toEqual({c__hostTab: 'monitoring', c__rootCorrelationId: ACTION_ID, c__correlationId: 'run-a'});
		expect(lastNavigation()[1]).toBe(false);
	});

	it('writes nothing when a pin repeats what the address already records', async() =>
	{
		const element = await createComponent();
		await deliver({c__rootCorrelationId: ACTION_ID});
		mockNavigate.mockClear();

		queryAll(element, 'action-chain-chip')[0].click();
		await flushAll();
		await flushAll();
		expect(mockNavigate).toHaveBeenCalledTimes(1);

		// The platform hands the pushed address back, and the reader clicks the same chip again: the address already
		// records that narrowing, so a second entry would only buy them a Back that appears to do nothing.
		await deliver(lastNavigation()[0].state);
		mockNavigate.mockClear();
		queryAll(element, 'action-chain-chip')[0].click();
		await flushAll();
		await flushAll();

		expect(mockNavigate).not.toHaveBeenCalled();
		expect(query(element, 'correlation-pill').label).toBe('Chain: OrderSync · CHAIN-00214');
		expect(query(element, 'action-pill')).toBeTruthy();
	});

	it('pushes again when the pin that follows the echoed address is a different chain', async() =>
	{
		const element = await createComponent();
		await deliver({c__rootCorrelationId: ACTION_ID});
		queryAll(element, 'action-chain-chip')[0].click();
		await flushAll();
		await flushAll();
		await deliver(lastNavigation()[0].state);
		mockNavigate.mockClear();

		queryAll(element, 'action-chain-chip')[1].click();
		await flushAll();
		await flushAll();

		expect(mockNavigate).toHaveBeenCalledTimes(1);
		expect(lastNavigation()[0].state).toEqual({c__rootCorrelationId: ACTION_ID, c__correlationId: 'run-b'});
		expect(lastNavigation()[1]).toBe(false);
	});

	it('drops the key it pushed when the pill closes, even though the pushed address was never delivered back', async() =>
	{
		const element = await createComponent();
		// The only address the console has been handed carries no key of its own; the pin below is made in place, and
		// the wire never delivers that push back. The close control has to drop the key all the same, or the action
		// stays in the URL and the next refresh re-pins what the reader just cleared.
		await deliver({c__hostTab: 'monitoring'});
		await showWholeActionFromDrawer(element, '001p1');
		expect(query(element, 'action-pill')).toBeTruthy();
		mockNavigate.mockClear();

		query(element, 'action-pill').dispatchEvent(new CustomEvent('remove'));
		await flushAll();

		expect(mockNavigate).toHaveBeenCalledTimes(1);
		expect(lastNavigation()[0]).toEqual({...HOST_PAGE, state: {c__hostTab: 'monitoring'}});
		expect(lastNavigation()[1]).toBe(true);
		expect(query(element, 'action-pill')).toBeNull();
	});

	it('rewrites the address in place on the close controls and Clear all, keeping the action key when only the chain pill goes', async() =>
	{
		const element = await createComponent();
		await deliver({c__rootCorrelationId: ACTION_ID, c__correlationId: 'run-a'});
		mockNavigate.mockClear();

		query(element, 'correlation-pill').dispatchEvent(new CustomEvent('remove'));
		await flushAll();
		expect(mockNavigate).toHaveBeenCalledTimes(1);
		expect(lastNavigation()[0]).toEqual({...HOST_PAGE, state: {c__rootCorrelationId: ACTION_ID}});
		expect(lastNavigation()[1]).toBe(true);
		expect(query(element, 'action-pill')).toBeTruthy();

		mockNavigate.mockClear();
		query(element, 'action-pill').dispatchEvent(new CustomEvent('remove'));
		await flushAll();
		expect(mockNavigate).toHaveBeenCalledTimes(1);
		expect(lastNavigation()[0]).toEqual({...HOST_PAGE, state: {}});
		expect(lastNavigation()[1]).toBe(true);
		expect(query(element, 'correlation-pill')).toBeNull();

		mockNavigate.mockClear();
		buttonByLabel(element, 'Clear all').click();
		await flushAll();
		expect(mockNavigate).toHaveBeenCalledTimes(1);
		expect(lastNavigation()[0]).toEqual({...HOST_PAGE, state: {}});
		expect(lastNavigation()[1]).toBe(true);
	});

	it('applies a stamped action hand-off once, rewrites the address without the stamp, and lets a new stamp apply again', async() =>
	{
		const element = await createComponent();
		mockNavigate.mockClear();

		await deliver({c__rootCorrelationId: ACTION_ID, c__viewLogsAt: '1000'});
		expect(query(element, 'action-pill')).toBeTruthy();
		expect(mockNavigate).toHaveBeenCalledTimes(1);
		expect(lastNavigation()[0]).toEqual({...HOST_PAGE, state: {c__rootCorrelationId: ACTION_ID}});
		expect(lastNavigation()[1]).toBe(true);
		expect(callCountFor(getActionSummary)).toBe(1);

		await deliver({c__rootCorrelationId: ACTION_ID, c__viewLogsAt: '1000'});
		expect(callCountFor(getActionSummary)).toBe(1);

		await deliver({c__rootCorrelationId: ACTION_ID, c__viewLogsAt: '2000'});
		expect(callCountFor(getActionSummary)).toBe(2);
		expect(mockNavigate).toHaveBeenCalledTimes(2);
	});

	it('applies a stamped run hand-off once and keeps its window in the rewritten address', async() =>
	{
		const element = await createComponent();
		mockNavigate.mockClear();

		await deliver({c__correlationId: 'deep-1', c__windowStart: DEEP_LINK_START, c__windowEnd: DEEP_LINK_END, c__viewLogsAt: '1000'});
		expect(query(element, 'correlation-pill')).toBeTruthy();
		expect(mockNavigate).toHaveBeenCalledTimes(1);
		expect(lastNavigation()[0]).toEqual({...HOST_PAGE, state: {c__correlationId: 'deep-1', c__windowStart: DEEP_LINK_START, c__windowEnd: DEEP_LINK_END}});
		expect(lastNavigation()[1]).toBe(true);
	});

	it('writes a run hand-off that ran to now with its start alone, so the address says what the link said', async() =>
	{
		const element = await createComponent();
		mockNavigate.mockClear();

		await deliver({c__correlationId: 'deep-open-ended', c__windowStart: DEEP_LINK_START, c__viewLogsAt: '1000'});
		expect(query(element, 'correlation-pill')).toBeTruthy();
		expect(mockNavigate).toHaveBeenCalledTimes(1);
		expect(lastNavigation()[0]).toEqual({...HOST_PAGE, state: {c__correlationId: 'deep-open-ended', c__windowStart: DEEP_LINK_START}});
		expect(lastNavigation()[1]).toBe(true);
	});

	it('sets the pin before the rewrite, so the plain address the rewrite delivers changes nothing', async() =>
	{
		const element = await createComponent();
		let stateDeliveredBack = null;
		// Once, not for the rest of the file: a stamped hand-off issues exactly one navigation, and clearAllMocks
		// between tests resets the calls but not the implementation.
		mockNavigate.mockImplementationOnce((reference) =>
		{
			stateDeliveredBack = reference.state;
		});

		await deliver({c__rootCorrelationId: ACTION_ID, c__viewLogsAt: '1000'});
		mockCallControllerMethod.mockClear();
		await deliver(stateDeliveredBack);
		expect(mockCallControllerMethod).not.toHaveBeenCalled();
		expect(query(element, 'action-pill')).toBeTruthy();
	});

	it('forgets the consumed hand-off on an in-place pin, so Back onto the hand-off applies it again', async() =>
	{
		const element = await createComponent();
		await deliver({c__correlationId: 'deep-1', c__windowStart: DEEP_LINK_START, c__windowEnd: DEEP_LINK_END, c__viewLogsAt: '1000'});
		await showWholeActionFromDrawer(element, '001e1');
		expect(query(element, 'action-pill')).toBeTruthy();
		mockCallControllerMethod.mockClear();

		await deliver({c__correlationId: 'deep-1', c__windowStart: DEEP_LINK_START, c__windowEnd: DEEP_LINK_END, c__viewLogsAt: '1000'});
		expect(query(element, 'action-pill')).toBeNull();
		expect(lastRequestFor(getLogEntries).correlationId).toBe('deep-1');
	});

	it('ignores an empty delivery and keeps its host page', async() =>
	{
		const element = await createComponent();
		await deliver({c__rootCorrelationId: ACTION_ID});
		CurrentPageReference.emit(undefined);
		await flushAll();
		expect(query(element, 'action-pill')).toBeTruthy();
		mockNavigate.mockClear();

		query(element, 'action-pill').dispatchEvent(new CustomEvent('remove'));
		await flushAll();
		expect(lastNavigation()[0]).toEqual({...HOST_PAGE, state: {}});
	});
});
