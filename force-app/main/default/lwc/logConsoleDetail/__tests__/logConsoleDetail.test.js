// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for the logConsoleDetail timeline drawer.
 * @author Jason van Beukering
 * @date July 2026
 */
import {createElement} from 'lwc';
import LogConsoleDetail from 'c/logConsoleDetail';
import {copyToClipBoard} from 'c/utilitySystem';
// noinspection JSUnresolvedReference - mock helpers are provided by the c/componentBuilder jest mock at run time
import {mockShowErrorToast, mockShowSuccessToast} from 'c/componentBuilder';

jest.mock('c/utilitySystem', () => ({copyToClipBoard: jest.fn(() => Promise.resolve())}));

jest.mock('c/logConsoleContext', () => ({
	CONTEXT_LABEL_BY_VALUE: {
		AURA: 'Aura / LWC',
		SYNCHRONOUS: 'Synchronous',
		QUEUEABLE: 'Queueable',
		TRANSACTION_FINALIZER_QUEUEABLE: 'Queueable finalizer',
		BATCH_APEX: 'Batch Apex',
		REST: 'REST API',
		SCHEDULED: 'Scheduled',
		ANONYMOUS: 'Anonymous Apex',
		FUTURE: 'Future'
	}
}));

jest.mock('@salesforce/label/c.LogConsole_TabOverview', () => ({default: 'Overview'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_TabStackTrace', () => ({default: 'Stack trace'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_TabContext', () => ({default: 'Context'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_TabTimeline', () => ({default: 'Timeline'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_TimelineTitle', () => ({default: 'Correlation timeline'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_TimelineThisEntry', () => ({default: 'This entry'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_TimelineStandalone', () => ({default: 'No correlation id, so this entry stands alone.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_TimelineNotRegistered', () => ({default: 'Correlated by id {0}. Not a registered chain.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_TimelineOverview', () => ({default: 'Overview'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_TimelineTransaction', () => ({default: 'transaction'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_TimelineTransactions', () => ({default: 'transactions'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_TimelineEntry', () => ({default: 'entry'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_TimelineEntries', () => ({default: 'entries'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_TimelineErrorIn', () => ({default: 'error in {0}'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_TimelineAsync', () => ({default: 'Async'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_TimelineFrom', () => ({default: 'from {0}'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_TimelineGap', () => ({default: '{0} gap before this hop.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_TimelineCapOfTotal', () => ({default: 'Showing the first {0} of {1} transactions.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_TimelineCapTruncated', () => ({default: 'Truncated to the first {0} transactions.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_TimelineOpenedEntry', () => ({default: 'Opened entry'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_TimelineNoFocusDetail', () => ({default: 'No stack trace or context captured for this entry.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_TimelineLoadingFocus', () => ({default: 'Loading detail…'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_TimelineFocusLoadFailed', () => ({default: 'Couldn\'t load this entry\'s detail.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_LegendDebug', () => ({default: 'debug'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_LegendInfo', () => ({default: 'info'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_LegendWarning', () => ({default: 'warning'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_LegendError', () => ({default: 'error'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_LegendOpened', () => ({default: 'opened entry'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ChainStart', () => ({default: 'start'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ChainOffsetSeconds', () => ({default: '+{0}s'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ChainOffsetMinutes', () => ({default: '+{0}m'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ChainOffsetHours', () => ({default: '+{0}h'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_DetailsHeading', () => ({default: 'Details'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_LimitsHeading', () => ({default: 'Governor limits at capture'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_LimitsOnlyUsed', () => ({default: '(only limits used)'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_NoLimits', () => ({default: 'No governor limits consumed.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_NoStackTrace', () => ({default: 'No stack trace for this entry.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_Copy', () => ({default: 'Copy'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_Copied', () => ({default: 'Copied'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_CopyFailed', () => ({default: 'Couldn\'t copy to the clipboard. Try again or copy the text manually.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_Close', () => ({default: 'Close'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ActionOpenChain', () => ({default: 'Open in Chain Monitor'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ActionOpenRecord', () => ({default: 'Open record'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_MetaLogNumber', () => ({default: 'Log Number'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_MetaSource', () => ({default: 'Source'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_MetaContext', () => ({default: 'Context'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_MetaUser', () => ({default: 'User'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_MetaCorrelation', () => ({default: 'Correlation'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_MetaTransaction', () => ({default: 'Transaction'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_MetaParentTransaction', () => ({default: 'Parent txn'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_FirstSeen', () => ({default: 'First seen'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_LastSeen', () => ({default: 'Last seen'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_Logged', () => ({default: 'Logged'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_NoMessage', () => ({default: 'No message body'}), {virtual: true});

const OPENED_ID = '001000000000003';
const T0 = Date.parse('2026-06-30T19:30:00.000Z');
const at = (seconds) => new Date(T0 + seconds * 1000).toISOString();

const MOCK_DETAIL = {
	id: OPENED_ID,
	logNumber: 'L-04',
	level: 'ERROR',
	shortMessage: 'Read timed out',
	exceptionType: 'System.CalloutException',
	message: 'System.CalloutException: Read timed out',
	stackTrace: 'Class.PaymentGateway.capture: line 64',
	contextJson: '{"orderId":"a0H"}',
	className: 'PaymentGateway',
	methodLine: 'capture:64',
	executionEvent: 'TRANSACTION_FINALIZER_QUEUEABLE',
	userId: '005000000000001',
	userName: 'Ada Lopez',
	correlationId: 'e2e-corr-fulfil',
	transactionId: 'txn-3',
	parentTransactionId: 'txn-2',
	chainExists: true,
	firstSeen: '2026-06-30T19:30:00.000Z',
	lastSeen: '2026-06-30T19:34:00.000Z',
	durationMs: 240,
	limitBars: [
		{name: 'Queries', used: 47, maximum: 100, percentage: 47, level: 'green'},
		{name: 'Cpu Time', used: 8200, maximum: 10000, percentage: 82, level: 'amber'}
	]
};

// AURA -> QUEUEABLE -> QUEUEABLE (WARN, gap) -> FINALIZER (ERROR, opened, gap).
const MOCK_TRACE = [
	{
		id: 'a00',
		logNumber: 'L-01',
		level: 'DEBUG',
		shortMessage: 'Order submission received',
		className: 'OrderController',
		methodLine: 'submit:88',
		executionEvent: 'AURA',
		createdDate: at(0),
		isSelf: false,
		transactionId: 'txn-0',
		parentTransactionId: null,
		durationMs: 5
	},
	{
		id: 'a01',
		logNumber: 'L-02',
		level: 'INFO',
		shortMessage: 'Enqueued fulfilment',
		className: 'OrderService',
		methodLine: 'enqueue:12',
		executionEvent: 'QUEUEABLE',
		createdDate: at(24),
		isSelf: false,
		transactionId: 'txn-1',
		parentTransactionId: 'txn-0',
		durationMs: 10
	},
	{
		id: 'a02',
		logNumber: 'L-03',
		level: 'WARN',
		shortMessage: 'Low stock partial reserve',
		className: 'InventoryService',
		methodLine: 'reserve:21',
		executionEvent: 'QUEUEABLE',
		createdDate: at(120),
		isSelf: false,
		transactionId: 'txn-2',
		parentTransactionId: 'txn-1',
		durationMs: 30
	},
	{
		id: OPENED_ID,
		logNumber: 'L-04',
		level: 'ERROR',
		shortMessage: 'Read timed out',
		className: 'PaymentGateway',
		methodLine: 'capture:64',
		executionEvent: 'TRANSACTION_FINALIZER_QUEUEABLE',
		createdDate: at(240),
		isSelf: true,
		transactionId: 'txn-3',
		parentTransactionId: 'txn-2',
		durationMs: 240
	}
];

function createComponent(props = {})
{
	const element = createElement('c-log-console-detail', {is: LogConsoleDetail});
	Object.assign(element, {detail: MOCK_DETAIL, trace: MOCK_TRACE, traceTruncated: false, view: 'problems', occurrenceCount: 1284}, props);
	document.body.appendChild(element);
	return element;
}

const flush = () => Promise.resolve();
const testid = (element, id) => element.shadowRoot.querySelector(`[data-testid="${id}"]`);
const testids = (element, id) => [...element.shadowRoot.querySelectorAll(`[data-testid="${id}"]`)];

describe('c-log-console-detail', () =>
{
	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
		jest.clearAllMocks();
	});

	it('renders nothing when no detail is set', async() =>
	{
		const element = createComponent({detail: null});
		await flush();
		expect(testid(element, 'heading')).toBeNull();
	});

	it('renders the opened-entry header, count pill and the chain button when a chain exists', async() =>
	{
		const element = createComponent();
		await flush();
		expect(testid(element, 'heading').textContent).toBe('Read timed out');
		expect(testid(element, 'log-number').textContent).toBe('L-04');
		expect(testid(element, 'level-badge').textContent).toBe('ERROR');
		expect(testid(element, 'count-pill')).not.toBeNull();
		expect(testid(element, 'action-open-chain')).not.toBeNull();
	});

	it('hides the count pill in the entries view and the chain button when no chain exists', async() =>
	{
		const element = createComponent({view: 'entries', detail: {...MOCK_DETAIL, chainExists: false}});
		await flush();
		expect(testid(element, 'count-pill')).toBeNull();
		expect(testid(element, 'action-open-chain')).toBeNull();
	});

	it('applies the low-count pill class below the emphasis threshold', async() =>
	{
		const element = createComponent({occurrenceCount: 5});
		await flush();
		expect(testid(element, 'count-pill').className).toContain('count-pill_low');
	});

	it('shows the first-seen and last-seen span in the problems view', async() =>
	{
		const element = createComponent({view: 'problems'});
		await flush();
		const seenLine = testid(element, 'seen-line').textContent;
		expect(seenLine).toContain('First seen');
		expect(seenLine).toContain('Last seen');
	});

	it('collapses the seen span to a single logged label in the entries view', async() =>
	{
		const element = createComponent({view: 'entries'});
		await flush();
		const seenLine = testid(element, 'seen-line').textContent;
		expect(seenLine).toContain('Logged');
		expect(seenLine).not.toContain('First seen');
		expect(seenLine).not.toContain('Last seen');
	});

	it('renders the message code block when the entry carries a message body', async() =>
	{
		const element = createComponent();
		await flush();
		expect(testid(element, 'message-code')).not.toBeNull();
		expect(testid(element, 'no-message')).toBeNull();
	});

	it('shows a muted placeholder instead of an empty code block when the message body is blank', async() =>
	{
		const element = createComponent({detail: {...MOCK_DETAIL, message: ''}});
		await flush();
		expect(testid(element, 'message-code')).toBeNull();
		expect(testid(element, 'no-message').textContent).toBe('No message body');
	});

	it('shows the resolved user name in the details grid', async() =>
	{
		const element = createComponent();
		await flush();
		expect(testid(element, 'meta-user').textContent).toBe('Ada Lopez');
	});

	it('falls back to the raw user id when the name does not resolve', async() =>
	{
		const element = createComponent({detail: {...MOCK_DETAIL, userName: null}});
		await flush();
		expect(testid(element, 'meta-user').textContent).toBe('005000000000001');
	});

	it('renders the overview metagrid, source and limit bars', async() =>
	{
		const element = createComponent();
		await flush();
		expect(testid(element, 'meta-source').textContent).toBe('PaymentGateway.capture:64');
		expect(testids(element, 'limit-bar')).toHaveLength(2);
		expect(testids(element, 'limit-fill')[1].dataset.level).toBe('amber');
	});

	it('shows the no-limits and no-stack empty states', async() =>
	{
		const element = createComponent({detail: {...MOCK_DETAIL, limitBars: [], stackTrace: ''}});
		await flush();
		expect(testid(element, 'no-limits')).not.toBeNull();
		expect(testid(element, 'no-stack')).not.toBeNull();
	});

	it('renders the timeline overview stat, minimap collapse and legend', async() =>
	{
		const element = createComponent();
		await flush();
		expect(testid(element, 'overview-stat').textContent).toContain('4 transactions');
		expect(testid(element, 'overview-stat').textContent).toContain('4 entries');
		expect(testid(element, 'overview-stat').textContent).toContain('error in Queueable finalizer');
		// Aura, Queueable x2, Finalizer -> three segments.
		const segments = testids(element, 'minimap-segment');
		expect(segments).toHaveLength(3);
		expect(segments[1].textContent).toContain('Queueable ×2');
		expect(element.shadowRoot.querySelectorAll('.legend .lg')).toHaveLength(5);
	});

	it('renders four flat transaction groups with a breadcrumb and gap markers', async() =>
	{
		const element = createComponent();
		await flush();
		expect(testids(element, 'txn-head')).toHaveLength(4);
		// txn-2 starts 96s after txn-1 ends, txn-3 240s after txn-2 -> two gap markers.
		expect(testids(element, 'gap-note')).toHaveLength(2);
		expect(element.shadowRoot.textContent).toContain('from Queueable');
	});

	it('colours the entry node by severity and shows the level tag and opened marker', async() =>
	{
		const element = createComponent();
		await flush();
		const nodes = [...element.shadowRoot.querySelectorAll('.node')];
		expect(nodes[0].className).toContain('d-DEBUG');
		expect(nodes[3].className).toContain('node_self');
		const levelTags = [...element.shadowRoot.querySelectorAll('.elvl')].map((tag) => tag.textContent);
		expect(levelTags).toEqual([
			'DEBUG',
			'INFO',
			'WARN',
			'ERROR'
		]);
		expect(element.shadowRoot.querySelector('.youare').textContent).toBe('Opened entry');
	});

	it('shows the standalone note and no minimap for an uncorrelated single entry', async() =>
	{
		const soloDetail = {...MOCK_DETAIL, correlationId: null, chainExists: false, transactionId: null, parentTransactionId: null};
		const soloTrace = [{...MOCK_TRACE[3], correlationId: null, transactionId: null, parentTransactionId: null}];
		const element = createComponent({detail: soloDetail, trace: soloTrace});
		await flush();
		expect(testid(element, 'timeline-note').textContent).toContain('stands alone');
		expect(testid(element, 'minimap')).toBeNull();
		expect(testids(element, 'txn-head')).toHaveLength(1);
	});

	it('shows the not-registered note when correlated but no chain exists', async() =>
	{
		const element = createComponent({detail: {...MOCK_DETAIL, chainExists: false}});
		await flush();
		expect(testid(element, 'timeline-note').textContent).toContain('Not a registered chain');
		expect(testid(element, 'timeline-open-chain')).toBeNull();
	});

	it('dispatches close, navigatechain and openrecord (opened entry) from the header', async() =>
	{
		const element = createComponent();
		await flush();
		const close = jest.fn();
		const navigate = jest.fn();
		const openRecord = jest.fn();
		element.addEventListener('close', close);
		element.addEventListener('navigatechain', navigate);
		element.addEventListener('openrecord', openRecord);
		testid(element, 'close-button').click();
		testid(element, 'action-open-chain').click();
		testid(element, 'action-open-record').click();
		expect(close).toHaveBeenCalled();
		expect(navigate.mock.calls[0][0].detail.correlationId).toBe('e2e-corr-fulfil');
		expect(openRecord.mock.calls[0][0].detail.entryId).toBe(OPENED_ID);
	});

	it('focuses a non-opened hop, dispatches entryfocus, and shows a loading focus card', async() =>
	{
		const element = createComponent();
		await flush();
		const entryFocus = jest.fn();
		element.addEventListener('entryfocus', entryFocus);
		testids(element, 'timeline-entry')[0].click();
		await flush();
		expect(entryFocus.mock.calls[0][0].detail.entryId).toBe('a00');
		expect(testid(element, 'focus-loading')).not.toBeNull();
		testids(element, 'timeline-entry')[0].click();
		await flush();
		expect(entryFocus).toHaveBeenCalledTimes(1);
	});

	it('re-focuses the opened entry after another hop without dispatching entryfocus', async() =>
	{
		const element = createComponent();
		await flush();
		const entryFocus = jest.fn();
		element.addEventListener('entryfocus', entryFocus);
		testids(element, 'timeline-entry')[0].click();
		await flush();
		expect(entryFocus).toHaveBeenCalledTimes(1);
		testids(element, 'timeline-entry')[3].click();
		await flush();
		expect(entryFocus).toHaveBeenCalledTimes(1);
		expect(testid(element, 'focus-stack').textContent).toContain('PaymentGateway.capture');
		expect(testid(element, 'focus-context').textContent).toContain('orderId');
	});

	it('switches the active tab on tab activation', async() =>
	{
		const element = createComponent();
		await flush();
		const timelineTab = [...element.shadowRoot.querySelectorAll('lightning-tab')].find((tab) => tab.value === 'timeline');
		timelineTab.dispatchEvent(new CustomEvent('active', {bubbles: true}));
		await flush();
		expect(testid(element, 'overview-stat')).not.toBeNull();
	});

	it('renders the loaded focus detail with stack, context and an open-record affordance', async() =>
	{
		const element = createComponent();
		await flush();
		testids(element, 'timeline-entry')[0].click();
		await flush();
		element.focusedDetail = {id: 'a00', message: 'Order submission received', stackTrace: 'Class.OrderController.submit', contextJson: '{"a":1}'};
		await flush();
		expect(testid(element, 'focus-stack')).not.toBeNull();
		expect(testid(element, 'focus-context')).not.toBeNull();
		const openRecord = jest.fn();
		element.addEventListener('openrecord', openRecord);
		testid(element, 'focus-open-record').click();
		expect(openRecord.mock.calls[0][0].detail.entryId).toBe('a00');
	});

	it('shows the no-detail note when a focused hop has neither stack nor context', async() =>
	{
		const element = createComponent();
		await flush();
		testids(element, 'timeline-entry')[1].click();
		await flush();
		element.focusedDetail = {id: 'a01', message: 'Enqueued fulfilment', stackTrace: '', contextJson: ''};
		await flush();
		expect(testid(element, 'focus-none')).not.toBeNull();
	});

	it('shows a failed-load state when the focused hop detail resolves to a sentinel', async() =>
	{
		const element = createComponent();
		await flush();
		testids(element, 'timeline-entry')[1].click();
		await flush();
		element.focusedDetail = {loadFailed: true};
		await flush();
		expect(testid(element, 'focus-failed')).not.toBeNull();
	});

	it('collapses and expands a transaction on header click', async() =>
	{
		const element = createComponent();
		await flush();
		testids(element, 'txn-head')[0].click();
		await flush();
		expect(testids(element, 'txn-head')[0].querySelector('.chev').className).not.toContain('open');
		testids(element, 'txn-head')[0].click();
		await flush();
		expect(testids(element, 'txn-head')[0].querySelector('.chev').className).toContain('open');
	});

	it('jumps from a minimap segment to a transaction and scrolls it into view', async() =>
	{
		const element = createComponent();
		await flush();
		const scrollSpy = jest.fn();
		const originalScrollIntoView = Element.prototype.scrollIntoView;
		Element.prototype.scrollIntoView = scrollSpy;
		testids(element, 'minimap-segment')[1].click();
		await flush();
		Element.prototype.scrollIntoView = originalScrollIntoView;
		expect(scrollSpy).toHaveBeenCalled();
	});

	it('copies the message and the stack trace to the clipboard', async() =>
	{
		const element = createComponent();
		await flush();
		testid(element, 'copy-message').click();
		testid(element, 'copy-stack').click();
		expect(copyToClipBoard).toHaveBeenCalledWith('System.CalloutException: Read timed out');
		expect(copyToClipBoard).toHaveBeenCalledWith('Class.PaymentGateway.capture: line 64');
	});

	it('shows an error toast instead of an unhandled rejection when copying the message fails', async() =>
	{
		copyToClipBoard.mockRejectedValueOnce(new Error('copy denied'));

		const element = createComponent();
		await flush();
		testid(element, 'copy-message').click();
		// A macrotask flush lets the async click handler fully settle. Before the fix, the
		// un-caught copy rejection escaped the handler here and failed this test as an
		// unhandled rejection, so a regression of the catch surfaces loudly on its own.
		await new Promise((resolve) => setTimeout(resolve, 0));

		expect(mockShowSuccessToast).not.toHaveBeenCalled();
		expect(mockShowErrorToast).toHaveBeenCalledWith('Couldn\'t copy to the clipboard. Try again or copy the text manually.');
	});

	it('shows an error toast instead of an unhandled rejection when copying the stack trace fails', async() =>
	{
		copyToClipBoard.mockRejectedValueOnce(new Error('copy denied'));

		const element = createComponent();
		await flush();
		testid(element, 'copy-stack').click();
		await new Promise((resolve) => setTimeout(resolve, 0));

		expect(mockShowSuccessToast).not.toHaveBeenCalled();
		expect(mockShowErrorToast).toHaveBeenCalledWith('Couldn\'t copy to the clipboard. Try again or copy the text manually.');
	});

	it('shows the client cap row when more than the display cap of transactions exist', async() =>
	{
		const many = Array.from({length: 35}, (unused, index) => ({
			id: `m${index}`,
			logNumber: `L-${index}`,
			level: 'INFO',
			shortMessage: 'hop',
			className: 'Svc',
			methodLine: 'run:1',
			executionEvent: index % 2 ? 'TRANSACTION_FINALIZER_QUEUEABLE' : 'QUEUEABLE',
			createdDate: at(index),
			isSelf: false,
			transactionId: `mt${index}`,
			parentTransactionId: index ? `mt${index - 1}` : null,
			durationMs: 1
		}));
		const element = createComponent({detail: {...MOCK_DETAIL, id: 'm0'}, trace: many});
		await flush();
		expect(testids(element, 'txn-head')).toHaveLength(30);
		expect(testid(element, 'cap-row').textContent).toContain('first 30 of 35');
		// More than six boundaries collapse into an Async run.
		expect(element.shadowRoot.textContent).toContain('Async ×');
	});

	it('shows the truncated cap row using the shown count when the server truncated the trace', async() =>
	{
		const element = createComponent({traceTruncated: true});
		await flush();
		expect(testid(element, 'cap-row').textContent).toContain('Truncated to the first 4 transactions');
	});

	it('renders the "this entry" title with an hour-scale span in the overview stat', async() =>
	{
		const longTrace = [
			{...MOCK_TRACE[0], createdDate: at(0)},
			{...MOCK_TRACE[3], id: OPENED_ID, createdDate: at(3720), transactionId: 'txn-far', parentTransactionId: 'txn-0'}
		];
		const element = createComponent({trace: longTrace});
		await flush();
		expect(testid(element, 'overview-stat').textContent).toContain('1h');
	});

	it('renders no timeline groups for an empty trace and exposes the reactive getters', async() =>
	{
		const element = createComponent({trace: null, focusedDetail: {id: 'x'}});
		await flush();
		expect(testids(element, 'txn-head')).toHaveLength(0);
		expect(testid(element, 'minimap')).toBeNull();
		expect(element.trace).toEqual([]);
		expect(element.focusedDetail).toEqual({id: 'x'});
		expect(element.traceTruncated).toBe(false);
	});

	it('pluralises the entry count and shows a non-zero span for a multi-entry transaction', async() =>
	{
		const multi = [
			{
				id: 'b0',
				logNumber: 'L-1',
				level: 'INFO',
				shortMessage: 'first',
				className: 'Svc',
				methodLine: 'a:1',
				executionEvent: 'AURA',
				createdDate: at(0),
				isSelf: false,
				transactionId: 'bt',
				parentTransactionId: null,
				durationMs: 1
			},
			{
				id: 'b1',
				logNumber: 'L-2',
				level: 'WARN',
				shortMessage: 'second',
				className: 'Svc',
				methodLine: 'b:2',
				executionEvent: 'AURA',
				createdDate: at(75),
				isSelf: true,
				transactionId: 'bt',
				parentTransactionId: null,
				durationMs: 1
			}
		];
		const element = createComponent({detail: {...MOCK_DETAIL, id: 'b1', correlationId: 'multi', chainExists: false}, trace: multi});
		await flush();
		expect(testids(element, 'txn-head')).toHaveLength(1);
		expect(testids(element, 'txn-head')[0].textContent).toContain('2 entries');
		expect(testids(element, 'txn-head')[0].textContent).toContain('1m 15s');
	});

	it('handles a missing methodLine, absent timestamps and an unknown quiddity gracefully', async() =>
	{
		const bareDetail = {...MOCK_DETAIL, id: 'z0', methodLine: null, firstSeen: null, lastSeen: null, correlationId: 'z', chainExists: false, executionEvent: 'REST'};
		const bareTrace = [
			{
				id: 'z0',
				logNumber: 'L-Z',
				level: 'INFO',
				shortMessage: 'bare',
				className: 'BareSvc',
				methodLine: null,
				executionEvent: 'MYSTERY_EVENT',
				createdDate: null,
				isSelf: true,
				transactionId: 'zt',
				parentTransactionId: null,
				durationMs: 0
			}
		];
		const element = createComponent({detail: bareDetail, trace: bareTrace});
		await flush();
		expect(testid(element, 'meta-source').textContent).toBe('PaymentGateway');
		expect(element.shadowRoot.textContent).toContain('MYSTERY_EVENT');
		expect(element.shadowRoot.textContent).toContain('BareSvc');
	});

	it('falls back to the trace short message when the loaded focus detail has no message', async() =>
	{
		const element = createComponent();
		await flush();
		testids(element, 'timeline-entry')[0].click();
		await flush();
		element.focusedDetail = {id: 'a00', message: '', stackTrace: 'S', contextJson: ''};
		await flush();
		expect(testid(element, 'focus-card').textContent).toContain('Order submission received');
	});
});
