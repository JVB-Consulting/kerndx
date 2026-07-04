// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for logConsole LWC container
 * @author Jason van Beukering
 * @date June 2026
 */
import {createElement} from 'lwc';
import LogConsole from 'c/logConsole';
// noinspection JSUnresolvedReference - mock helpers are provided by the c/componentBuilder jest mock at run time
import {mockCallControllerMethod, mockNavigate} from 'c/componentBuilder';
import {CurrentPageReference} from 'lightning/navigation';
import getLogProblems from '@salesforce/apex/CTRL_LogConsole.getLogProblems';
import getLogEntries from '@salesforce/apex/CTRL_LogConsole.getLogEntries';
import getLogSummary from '@salesforce/apex/CTRL_LogConsole.getLogSummary';
import getEntrySummary from '@salesforce/apex/CTRL_LogConsole.getEntrySummary';
import getLogEntryDetail from '@salesforce/apex/CTRL_LogConsole.getLogEntryDetail';
import getCorrelatedTrace from '@salesforce/apex/CTRL_LogConsole.getCorrelatedTrace';

jest.mock('@salesforce/label/c.LogConsole_Title', () => ({default: 'Log Console'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ViewProblems', () => ({default: 'Problem summary'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ViewEntries', () => ({default: 'Individual entries'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_Refresh', () => ({default: 'Refresh'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ClearAll', () => ({default: 'Clear all'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_SearchPlaceholder', () => ({default: 'Search'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_AllContexts', () => ({default: 'All contexts'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ContextFilter', () => ({default: 'Execution context'}), {virtual: true});
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
jest.mock('@salesforce/label/c.LogConsole_EmptyState', () => ({default: 'No logs match these filters.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_CappedBanner', () => ({default: 'Showing the first {0}. Narrow the filters to see the rest.'}), {virtual: true});
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
jest.mock('@salesforce/label/c.LogConsole_LevelGroupLabel', () => ({default: 'Log levels'}), {virtual: true});
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

const DEFAULT_WINDOW_MINUTES = 1440;
const SEVEN_DAY_WINDOW_MINUTES = 10080;

const PROBLEM_ROWS = [
	{
		id: '001p1',
		logNumber: 'L-001',
		level: 'ERROR',
		shortMessage: 'NPE',
		exceptionType: 'System.NullPointerException',
		className: 'AcctHandler',
		methodLine: 'run:42',
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
		executionEvent: 'QUEUEABLE',
		correlationId: 'c2',
		occurrenceCount: 96,
		firstSeen: '2026-06-28T08:00:00.000Z',
		lastSeen: '2026-06-28T10:00:00.000Z'
	}
];
const MOCK_PROBLEM_PAGE = {records: PROBLEM_ROWS, totalCount: 2, pageNumber: 1, totalPages: 1, hasMorePages: false, resultsTruncated: false};
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
		{name: 'AcctHandler', count: 1284, percent: 93},
		{name: 'Breaker', count: 96, percent: 7}
	]
};
const MOCK_ENTRY_SUMMARY = {
	totalRows: 42, perLevel: [
		{level: 'ERROR', rowCount: 30},
		{level: 'WARN', rowCount: 12}
	], topSources: [
		{name: 'Chain', count: 30, percent: 71},
		{name: 'Breaker', count: 12, percent: 29}
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
			getCorrelatedTrace,
			overrides.trace ?? {entries: MOCK_TRACE, truncated: false}
		]
	]);
	mockCallControllerMethod.mockImplementation((apexFn) => Promise.resolve(responseByMethod.has(apexFn) ? responseByMethod.get(apexFn) : null));
}

function lastRequestFor(apexFn)
{
	const calls = mockCallControllerMethod.mock.calls.filter((call) => call[0] === apexFn);
	return JSON.parse(calls[calls.length - 1][1].requestJson);
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
	const input = Array.from(element.shadowRoot.querySelectorAll('.customrange-field')).find((candidate) => candidate.dataset.field === field);
	input.dispatchEvent(new CustomEvent('change', {detail: {value}}));
}

function columnFieldNames(element)
{
	return element.shadowRoot.querySelector('c-log-console-table').columns.map((column) => column.fieldName);
}

async function selectRow(element, id)
{
	table(element).dispatchEvent(new CustomEvent('rowselection', {detail: {selectedRows: [{id}]}}));
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

			expect(mockCallControllerMethod.mock.calls.some((call) => call[0] === getLogProblems)).toBe(true);
			expect(mockCallControllerMethod.mock.calls.some((call) => call[0] === getLogSummary)).toBe(true);
			expect(table(element).data.length).toBe(2);
		});

		it('requests the problems view with the documented defaults', async() =>
		{
			await createComponent();

			const request = lastRequestFor(getLogProblems);
			expect(request.windowMinutes).toBe(DEFAULT_WINDOW_MINUTES);
			expect(request.sortField).toBe('occurrenceCount');
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

		it('does not reload when the already-active view is clicked', async() =>
		{
			const element = await createComponent();
			mockCallControllerMethod.mockClear();

			buttonByLabel(element, 'Problem summary').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			expect(mockCallControllerMethod).not.toHaveBeenCalled();
		});
	});

	describe('filtering', () =>
	{
		it('resets to page one when a level filter is toggled', async() =>
		{
			const element = await createComponent();
			element.pageNumber = 3;
			mockCallControllerMethod.mockClear();

			levelButton(element, 'INFO').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			const request = lastRequestFor(getLogProblems);
			expect(request.pageNumber).toBe(1);
			expect(request.levels).toContain('INFO');
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
	});

	describe('columns and row decoration', () =>
	{
		it('exposes the documented column set for each view', async() =>
		{
			const element = await createComponent();

			expect(columnFieldNames(element)).toEqual([
				'recordUrl',
				'level',
				'shortMessage',
				'source',
				'contextDisplay',
				'occurrenceCount',
				'lastSeen'
			]);

			buttonByLabel(element, 'Individual entries').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			const entryColumns = table(element).columns;
			const entryCols = entryColumns.map((column) => column.fieldName);
			expect(entryCols).toEqual([
				'recordUrl',
				'createdDate',
				'level',
				'shortMessage',
				'source',
				'contextDisplay',
				'correlationId'
			]);
			expect(entryCols).not.toContain('userId');
			expect(entryCols).not.toContain('occurrenceCount');
			// context and correlation resolve to server-side sort keys (executionEvent / correlationId), so both advertise sortability
			expect(entryColumns.find((column) => column.fieldName === 'contextDisplay').sortable).toBe(true);
			expect(entryColumns.find((column) => column.fieldName === 'correlationId').sortable).toBe(true);
		});

		it('renders the log-number column as a record link', async() =>
		{
			const element = await createComponent();

			const logNumberColumn = table(element).columns.find((column) => column.fieldName === 'recordUrl');
			expect(logNumberColumn.type).toBe('url');
			expect(logNumberColumn.typeAttributes.label.fieldName).toBe('logNumber');
		});

		it('humanises the execution context and builds the source and record link per row', async() =>
		{
			const element = await createComponent();

			const firstRow = table(element).data[0];
			expect(firstRow.contextDisplay).toBe('Batch Apex');
			expect(firstRow.source).toBe('AcctHandler.run:42');
			expect(firstRow.recordUrl).toBe('/lightning/r/001p1/view');
		});

		it('decorates a class-only row (no method line) with the bare class name', async() =>
		{
			wireMockResponses({problems: {...MOCK_PROBLEM_PAGE, records: [{...PROBLEM_ROWS[0], methodLine: null}]}});
			const element = await createComponent();

			expect(table(element).data[0].source).toBe('AcctHandler');
		});

		it('maps synthesised/url columns back to their real controller sort keys', async() =>
		{
			const element = await createComponent();

			mockCallControllerMethod.mockClear();
			table(element).dispatchEvent(new CustomEvent('sort', {detail: {fieldName: 'source', sortDirection: 'asc'}}));
			await flushAll();
			expect(lastRequestFor(getLogProblems).sortField).toBe('className');
			// the sort-arrow indicator stays on the Source column, not the wire key
			expect(table(element).sortedBy).toBe('source');

			mockCallControllerMethod.mockClear();
			table(element).dispatchEvent(new CustomEvent('sort', {detail: {fieldName: 'recordUrl', sortDirection: 'desc'}}));
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
			expect(badge.textContent).toBe('Totals approximate');
			expect(badge.getAttribute('title')).toContain('may be higher');
		});

		it('renders no approximate badge when the summary totals are exact', async() =>
		{
			const element = await createComponent();

			expect(element.shadowRoot.querySelector('[data-testid="totals-approximate"]')).toBeNull();
		});

		it('renders the ranked top sources as click-to-drill rows', async() =>
		{
			const element = await createComponent();

			const sourceRows = element.shadowRoot.querySelectorAll('[data-testid="source-row"]');
			expect(sourceRows.length).toBe(MOCK_SUMMARY.topSources.length);
			expect(sourceRows[0].textContent).toContain('AcctHandler');
			expect(sourceRows[0].textContent).toContain('93%');
		});

		it('drills into a source when a top-source row is clicked', async() =>
		{
			const element = await createComponent();
			mockCallControllerMethod.mockClear();

			element.shadowRoot.querySelector('[data-testid="source-row"]').click();
			await flushAll();

			expect(lastRequestFor(getLogProblems).searchTerm).toBe('AcctHandler');
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
			// Total card plus the (empty) top-sources card; no per-level cards without a perLevel list.
			expect(cards.length).toBe(2);
			expect(cards[0].querySelector('lightning-formatted-number').value).toBe(0);
			expect(element.shadowRoot.querySelectorAll('[data-testid="source-row"]').length).toBe(0);
		});

		it('renders the entries ribbon safely when the row-count aggregate omits its fields', async() =>
		{
			wireMockResponses({entrySummary: {}});
			const element = await createComponent();
			buttonByLabel(element, 'Individual entries').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			const cards = element.shadowRoot.querySelectorAll('[data-testid="summary-card"]');
			expect(cards.length).toBe(2);
			expect(cards[0].querySelector('lightning-formatted-number').value).toBe(0);
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
			expect(banner.textContent).toContain('2000');
		});

		it('clears the list and selection when the controller returns nothing', async() =>
		{
			mockCallControllerMethod.mockImplementation((apexFn) => Promise.resolve(apexFn === getLogSummary ? MOCK_SUMMARY : null));
			const element = await createComponent();

			expect(element.shadowRoot.querySelector('[data-testid="empty-state"]')).not.toBeNull();
			expect(element.shadowRoot.querySelector('[data-testid="detail-panel"]')).toBeNull();
		});
	});

	describe('infinite scroll and refresh', () =>
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

		it('appends the next page of rows when the datatable requests more', async() =>
		{
			wirePagedProblems();
			const element = await createComponent();
			expect(table(element).data.length).toBe(2);
			mockCallControllerMethod.mockClear();

			table(element).dispatchEvent(new CustomEvent('loadmore'));
			await flushAll();

			expect(lastRequestFor(getLogProblems).pageNumber).toBe(2);
			expect(table(element).data.length).toBe(4);
			// The window-scoped ribbon is not re-fetched on load-more.
			expect(mockCallControllerMethod.mock.calls.some((call) => call[0] === getLogSummary)).toBe(false);
		});

		it('does not request more rows once the last page has loaded', async() =>
		{
			const element = await createComponent();
			mockCallControllerMethod.mockClear();

			table(element).dispatchEvent(new CustomEvent('loadmore'));
			await flushAll();

			expect(mockCallControllerMethod.mock.calls.some((call) => call[0] === getLogProblems)).toBe(false);
		});

		it('replaces the rows and resets to the first page when a filter changes after loading more', async() =>
		{
			wirePagedProblems();
			const element = await createComponent();
			table(element).dispatchEvent(new CustomEvent('loadmore'));
			await flushAll();
			expect(table(element).data.length).toBe(4);
			mockCallControllerMethod.mockClear();

			levelButton(element, 'INFO').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			expect(lastRequestFor(getLogProblems).pageNumber).toBe(1);
			expect(table(element).data.length).toBe(2);
		});

		it('re-requests when Refresh is clicked', async() =>
		{
			const element = await createComponent();
			mockCallControllerMethod.mockClear();

			buttonByLabel(element, 'Refresh').dispatchEvent(new CustomEvent('click'));
			await flushAll();

			expect(mockCallControllerMethod.mock.calls.some((call) => call[0] === getLogProblems)).toBe(true);
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
	});

});
