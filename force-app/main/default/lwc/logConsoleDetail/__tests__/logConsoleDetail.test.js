// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for the logConsoleDetail timeline drawer.
 * @author Jason van Beukering
 * @date July 2026, August 2026
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
jest.mock('@salesforce/label/c.LogConsole_TimelineFromTransaction', () => ({default: 'from transaction {0}'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_TimelineFromEarlierTransaction', () => ({default: 'from an earlier transaction'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_TimelineGap', () => ({default: '{0} gap before this hop.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_TimelineCapOfTotal', () => ({default: 'Showing the first {0} of {1} transactions. Open in Chain Monitor for the full chain.'}),
		{virtual: true});
jest.mock('@salesforce/label/c.LogConsole_TimelineCapOfTotalNoChain', () => ({default: 'Showing the first {0} of {1} transactions.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_TimelineCapTruncated',
		() => ({default: 'This trace is very long, so only its earliest entries are shown here. Open in Chain Monitor for the full chain.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_TimelineCapTruncatedNoChain', () => ({default: 'This trace is very long, so only its earliest entries are shown here.'}),
		{virtual: true});
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
jest.mock('@salesforce/label/c.LogConsole_DurationSeconds', () => ({default: '{0}s'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_DurationMinutes', () => ({default: '{0}m'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_DurationHours', () => ({default: '{0}h'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_DetailsHeading', () => ({default: 'Details'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_LimitsHeading', () => ({default: 'Governor limits at capture'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_LimitsOnlyUsed', () => ({default: '(only limits used)'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_NoLimits', () => ({default: 'No governor limits consumed.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ProvenanceTagged', () => ({default: 'Tagged'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ActionOpenLatestOccurrence', () => ({default: 'Open latest occurrence'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_DerivedNoOccurrence',
		() => ({default: 'None of the entries behind this problem can be opened right now, so only the grouped summary is shown.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_StackUnavailable', () => ({default: 'No entry is available to show a stack trace from.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_TaggedCountExplained', () => ({default: 'Why there is one entry and a count of {0}'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_TaggedCountExplainedHint', () => ({
	default: 'This problem is tagged in your code, so the first time it happened was kept in full and every repeat since has been counted rather than stored again. '
			+ 'Nothing was deleted — the count is what your code has reported, and the entry below it is the one kept for detail.'
}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_NoStackTrace', () => ({default: 'No stack trace recorded for this entry.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_NoStackTraceHint', () => ({default: 'Stack traces are captured for exceptions; this entry was logged without one.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_NoStackTraceSourceHint',
		() => ({default: 'Only an error logged with an exception carries a stack trace. This entry was logged at {0}, which is where to look in your code.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_TimelineAllLevels', () => ({default: 'This timeline shows every entry in this correlation, including any levels your filter hides.'}),
		{virtual: true});
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
jest.mock('@salesforce/label/c.LogConsole_MetaParentTransaction', () => ({default: 'Parent transaction'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_FirstSeen', () => ({default: 'First seen'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_LastSeen', () => ({default: 'Last seen'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_Logged', () => ({default: 'Logged'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_NoMessage', () => ({default: 'No message body'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_MessageCaption', () => ({default: '{0} message'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_NoContext', () => ({default: 'This entry was logged without any request details.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_NoContextHint',
		() => ({default: 'A developer can attach details like the record being worked on or the values that came in, at the point the log line is written.'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_ViewOccurrences', () => ({default: 'View occurrences'}), {virtual: true});
jest.mock('@salesforce/label/c.LogConsole_TrackProblemExceptionNote', () => ({default: 'Replace caughtException with the exception variable your catch block declares.'}),
		{virtual: true});

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
	classMethod: 'PaymentGateway.capture',
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

// A 35-transaction trace: past both the 30-transaction display cap and the minimap's boundary limit.
function manyTransactions()
{
	return Array.from({length: 35}, (unused, index) => ({
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
}

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
// Every copy affordance in the drawer is the same small icon: clipboard glyph, x-small, named Copy for the tooltip and
// assistive tech alike, bare on the light surfaces and bare-inverse on the dark code blocks (a plain bare icon is
// invisible on them).
const expectCopyIcon = (affordance, variant) =>
{
	expect(affordance).not.toBeNull();
	expect(affordance.tagName.toLowerCase()).toBe('lightning-button-icon');
	expect(affordance.iconName).toBe('utility:copy_to_clipboard');
	expect(affordance.size).toBe('x-small');
	expect(affordance.alternativeText).toBe('Copy');
	expect(affordance.title).toBe('Copy');
	expect(affordance.variant).toBe(variant);
};

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

	it('names the exact instant beside each relative time', async() =>
	{
		const problems = createComponent({view: 'problems', problemFirstSeen: '2026-06-28T09:00:00.000Z', problemLastSeen: '2026-06-30T19:34:00.000Z'});
		await flush();

		// "First seen 21 hours ago" cannot be lined up against a deployment, an integration log or another
		// system's record of the same moment. The instant it stands for has to be on screen too.
		expect(testid(problems, 'first-seen-exact').value).toBe(Date.parse('2026-06-28T09:00:00.000Z'));
		expect(testid(problems, 'last-seen-exact').value).toBe(Date.parse('2026-06-30T19:34:00.000Z'));
		// The template compiler strips the whitespace between elements, so every gap in this line is an explicit
		// no-break space, and nothing but a test notices when one goes: without them the line reads
		// "…ago(Aug 15, 2026, 4:12:03 PM EDT)· Last seen". Each bracketed instant is checked on its own rather
		// than through the line's text, because the platform date components render empty under jest: run
		// together, the label's own space would sit against the bracket and cover for the fragment that lost its.
		const exactInstants = [...problems.shadowRoot.querySelectorAll('.seen-exact')];
		expect(exactInstants).toHaveLength(2);
		exactInstants.forEach((instant) => expect(instant.textContent.slice(0, 2)).toBe('\u00A0('));
		// The separator between the two pairs has no component between its parts, so the line itself shows it.
		expect(testid(problems, 'seen-line').textContent).toContain(')\u00A0\u00B7 ');

		const entries = createComponent({view: 'entries'});
		await flush();
		const logged = testid(entries, 'logged-exact');
		expect(logged.value).toBe(Date.parse('2026-06-30T19:30:00.000Z'));
		// Seconds, because entries inside one transaction are seconds apart; the zone name, because an instant
		// with no zone beside it is not an instant.
		expect(logged.second).toBe('2-digit');
		expect(logged.timeZoneName).toBe('short');
		// The third variant carries its own space, and only its own fragment can prove it.
		expect([...entries.shadowRoot.querySelectorAll('.seen-exact')].map((instant) => instant.textContent.slice(0, 2))).toEqual(['\u00A0(']);
	});

	it('leaves the exact instant out when the drawer has none to show', async() =>
	{
		const element = createComponent({view: 'entries', detail: {...MOCK_DETAIL, firstSeen: null}});
		await flush();

		// Rather than an empty pair of brackets trailing the word "Logged".
		expect(testid(element, 'logged-exact')).toBeNull();
		expect(testid(element, 'seen-line').textContent).toContain('Logged');
	});

	it('renders the message code block when the entry carries a message body', async() =>
	{
		const element = createComponent();
		await flush();
		expect(testid(element, 'message-code')).not.toBeNull();
		expect(testid(element, 'no-message')).toBeNull();
	});

	it('renders the message in a light severity-keyed card captioned with the exception type', async() =>
	{
		const element = createComponent();
		await flush();
		const card = testid(element, 'message-card');
		expect(card.dataset.level).toBe('ERROR');
		expect(testid(element, 'message-caption').textContent).toBe('System.CalloutException');
		expect(testid(element, 'message-code').textContent).toBe('System.CalloutException: Read timed out');
		// The rejected treatment was a dark <pre class="code"> panel; the card body is a plain div.
		expect(card.querySelector('pre')).toBeNull();
	});

	it('captions the message card with the level when the entry carries no exception type', async() =>
	{
		const element = createComponent({detail: {...MOCK_DETAIL, exceptionType: null, level: 'WARN'}});
		await flush();
		expect(testid(element, 'message-caption').textContent).toBe('WARN message');
		expect(testid(element, 'message-card').dataset.level).toBe('WARN');
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
		expect(testid(element, 'meta-user').textContent.trim()).toBe('Ada Lopez');
	});

	it('falls back to the raw user id when the name does not resolve', async() =>
	{
		const element = createComponent({detail: {...MOCK_DETAIL, userName: null}});
		await flush();
		expect(testid(element, 'meta-user').textContent.trim()).toBe('005000000000001');
	});

	it('links the user to their record page', async() =>
	{
		const element = createComponent();
		await flush();
		const link = testid(element, 'meta-user-link');
		expect(link.getAttribute('href')).toBe('/lightning/r/005000000000001/view');
		expect(link.textContent.trim()).toBe('Ada Lopez');
	});

	it('renders the user as inert text when the entry carries no user id', async() =>
	{
		const element = createComponent({detail: {...MOCK_DETAIL, userId: null}});
		await flush();
		expect(testid(element, 'meta-user-link')).toBeNull();
		expect(testid(element, 'meta-user').textContent.trim()).toBe('Ada Lopez');
	});

	it('copies the correlation id from the details grid', async() =>
	{
		const element = createComponent();
		await flush();
		testid(element, 'copy-correlation').click();
		expect(copyToClipBoard).toHaveBeenCalledWith('e2e-corr-fulfil');
	});

	it('shows a dash placeholder and no copy affordance when the entry has no correlation id', async() =>
	{
		const element = createComponent({detail: {...MOCK_DETAIL, correlationId: null, chainExists: false}});
		await flush();
		expect(testid(element, 'copy-correlation')).toBeNull();
		expect(testid(element, 'meta-correlation').textContent.trim()).toBe('—');
	});

	it('renders the context json with a copy affordance', async() =>
	{
		const element = createComponent();
		await flush();
		expect(testid(element, 'no-context')).toBeNull();
		testid(element, 'copy-context').click();
		expect(copyToClipBoard).toHaveBeenCalledWith('{"orderId":"a0H"}');
	});

	it('shows the context empty state and its capture hint when no context was recorded', async() =>
	{
		const element = createComponent({detail: {...MOCK_DETAIL, contextJson: null}});
		await flush();
		expect(testid(element, 'copy-context')).toBeNull();
		const emptyPane = testid(element, 'no-context').textContent;
		// The reader here is an admin looking at an empty tab, not a developer reading an API reference: the
		// empty state says what happened and who can change it, and names no class or method to do it.
		expect(emptyPane).toContain('This entry was logged without any request details.');
		expect(emptyPane).toContain('A developer can attach details');
		expect(emptyPane).not.toContain('LOG_Builder');
	});

	it('shows an error toast instead of an unhandled rejection when copying the context fails', async() =>
	{
		copyToClipBoard.mockRejectedValueOnce(new Error('copy denied'));

		const element = createComponent();
		await flush();
		testid(element, 'copy-context').click();
		await new Promise((resolve) => setTimeout(resolve, 0));

		expect(mockShowSuccessToast).not.toHaveBeenCalled();
		expect(mockShowErrorToast).toHaveBeenCalledWith('Couldn\'t copy to the clipboard. Try again or copy the text manually.');
	});

	it('dispatches viewoccurrences carrying the entry source from the problems drawer', async() =>
	{
		const element = createComponent();
		await flush();
		const viewOccurrences = jest.fn();
		element.addEventListener('viewoccurrences', viewOccurrences);
		testid(element, 'action-view-occurrences').click();
		expect(viewOccurrences).toHaveBeenCalledTimes(1);
		expect(viewOccurrences.mock.calls[0][0].detail).toEqual({source: 'PaymentGateway'});
	});

	it('hides the view-occurrences action in the entries view', async() =>
	{
		const element = createComponent({view: 'entries'});
		await flush();
		expect(testid(element, 'action-view-occurrences')).toBeNull();
		expect(testid(element, 'action-open-record')).not.toBeNull();
	});

	it('hides the view-occurrences action when the drawer knows no occurrence count', async() =>
	{
		const element = createComponent({occurrenceCount: null});
		await flush();
		expect(testid(element, 'action-view-occurrences')).toBeNull();
	});

	it('renders the overview metagrid, source and limit bars', async() =>
	{
		const element = createComponent();
		await flush();
		expect(testid(element, 'meta-source').textContent).toBe('PaymentGateway.capture:64');
		expect(testids(element, 'limit-bar')).toHaveLength(2);
		expect(testids(element, 'limit-fill')[1].dataset.level).toBe('amber');
	});

	it('names the execution context the way the list does, not the way the wire stores it', async() =>
	{
		const element = createComponent();
		await flush();

		// The list column shows "Queueable finalizer" for this entry; the drawer used to print the stored
		// TRANSACTION_FINALIZER_QUEUEABLE, so one value wore two names a few hundred pixels apart.
		expect(testid(element, 'meta-context').textContent.trim()).toBe('Queueable finalizer');
	});

	it('dashes the details cells an entry never recorded rather than leaving them blank', async() =>
	{
		const element = createComponent({detail: {...MOCK_DETAIL, executionEvent: null, logNumber: null, transactionId: null, parentTransactionId: null}});
		await flush();

		// An empty value cell in a key/value grid reads as data that went missing, which is the one wrong
		// conclusion this console must never invite.
		expect(testid(element, 'meta-context').textContent.trim()).toBe('—');
		expect(testid(element, 'meta-log-number').textContent.trim()).toBe('—');
		expect(testid(element, 'meta-transaction').textContent.trim()).toBe('—');
		expect(testid(element, 'meta-parent-transaction').textContent.trim()).toBe('—');
	});

	it('shows the no-limits empty state and points the stack empty state at the source the entry did record', async() =>
	{
		const element = createComponent({detail: {...MOCK_DETAIL, limitBars: [], stackTrace: ''}});
		await flush();
		expect(testid(element, 'no-limits')).not.toBeNull();
		// Only an entry logged with an exception carries frames, so a DEBUG, INFO or WARN entry can never show a
		// stack. It does know where it was written, though, and naming that turns a dead end into a place to look.
		const noStack = testid(element, 'no-stack');
		expect(noStack.textContent).toContain('No stack trace recorded for this entry.');
		expect(noStack.querySelector('.hint').textContent).toContain('PaymentGateway.capture:64');
	});

	it('falls back to the general explanation when the entry recorded no source either', async() =>
	{
		const element = createComponent({detail: {...MOCK_DETAIL, stackTrace: '', className: null, methodLine: null}});
		await flush();

		// Nothing to point at, so the drawer says only what it can stand behind.
		expect(testid(element, 'no-stack').querySelector('.hint').textContent).toBe('Stack traces are captured for exceptions; this entry was logged without one.');
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

	it('cases the legend levels the way every other level affordance does', async() =>
	{
		const element = createComponent();
		await flush();

		const legendTexts = [...element.shadowRoot.querySelectorAll('.legend .lgtext')];
		expect(legendTexts).toHaveLength(5);
		// The four levels read as the ERROR and WARN badges do everywhere else in the console; "opened entry" is
		// not a level, so it stays in sentence case.
		expect(legendTexts.filter((text) => text.className.includes('lgtext_level'))).toHaveLength(4);
		expect(legendTexts[4].className).not.toContain('lgtext_level');
	});

	it('says the timeline shows every level, whatever the console filter is hiding', async() =>
	{
		const element = createComponent();
		await flush();

		// The timeline is scoped to the correlation and never applies the level filter, so its entry count can
		// exceed the list's for the same correlation. Unlabelled, the two numbers simply contradict each other.
		// Pinned whole: the caption is the only place this is said, and a reworded label would silently unsay it.
		expect(testid(element, 'all-levels-note').textContent).toBe('This timeline shows every entry in this correlation, including any levels your filter hides.');
	});

	it('leaves the every-level note off a standalone entry, which has no second count to contradict', async() =>
	{
		const element = createComponent({trace: [MOCK_TRACE[3]], detail: {...MOCK_DETAIL, correlationId: null}});
		await flush();

		expect(testid(element, 'all-levels-note')).toBeNull();
	});

	it('renders four flat transaction groups with a breadcrumb and gap markers', async() =>
	{
		const element = createComponent();
		await flush();
		expect(testids(element, 'txn-head')).toHaveLength(4);
		// txn-2 starts 96s after txn-1 ends, txn-3 240s after txn-2 -> two gap markers.
		expect(testids(element, 'gap-note')).toHaveLength(2);
		expect(element.shadowRoot.querySelectorAll('.crumb')).toHaveLength(3);
	});

	it('names each parent by its position in the time-ordered transaction list, not by its kind', async() =>
	{
		const element = createComponent();
		await flush();
		// txn-0, txn-1 and txn-2 are the 1st, 2nd and 3rd transactions; two of them are Queueables,
		// so a kind-keyed breadcrumb would read "from Queueable" twice and name no transaction at all.
		const crumbs = [...element.shadowRoot.querySelectorAll('.crumb')].map((crumb) => crumb.textContent.trim());
		expect(crumbs).toEqual([
			'↳ from transaction 1',
			'↳ from transaction 2',
			'↳ from transaction 3'
		]);
	});

	it('names the parent generically when it falls outside the loaded trace', async() =>
	{
		const element = createComponent({trace: [{...MOCK_TRACE[3], parentTransactionId: 'txn-not-loaded'}]});
		await flush();
		expect(testids(element, 'txn-head')).toHaveLength(1);
		expect(element.shadowRoot.querySelector('.crumb').textContent.trim()).toBe('↳ from an earlier transaction');
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

	it('labels the severity dots with the legend wording rather than the raw level value', async() =>
	{
		const element = createComponent();
		await flush();
		const dotLabels = [...element.shadowRoot.querySelectorAll('.node')].map((node) => node.getAttribute('aria-label'));
		expect(dotLabels).toEqual([
			'debug',
			'info',
			'warning',
			'error'
		]);
	});

	it('renders transaction spans from the duration labels, with no offset plus sign', async() =>
	{
		const element = createComponent();
		await flush();
		// Every transaction here holds a single entry, so each span is zero seconds.
		const spans = [...element.shadowRoot.querySelectorAll('.tdur')].map((span) => span.textContent.trim());
		expect(spans).toEqual([
			'· 0s',
			'· 0s',
			'· 0s',
			'· 0s'
		]);
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

	it('returns the focus card to its loading state when the container clears the focused detail', async() =>
	{
		const element = createComponent();
		await flush();
		testids(element, 'timeline-entry')[0].click();
		await flush();
		element.focusedDetail = {id: 'a00', message: 'Order submission received', stackTrace: 'Class.OrderController.submit', contextJson: ''};
		await flush();
		expect(testid(element, 'focus-stack')).not.toBeNull();
		element.focusedDetail = null;
		await flush();
		expect(testid(element, 'focus-stack')).toBeNull();
		expect(testid(element, 'focus-loading')).not.toBeNull();
		expect(element.focusedDetail).toBeNull();
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

	it('renders every copy affordance as the shared copy icon, never as a labelled button', async() =>
	{
		const element = createComponent();
		await flush();

		// One copy affordance across the whole product: the labelled button used to float over the message and
		// the code panels and hide the text beneath it, so each one is the same small icon the correlation id
		// already uses, and its name reaches assistive tech through alternative-text rather than visible text.
		expectCopyIcon(testid(element, 'copy-message'), 'bare');
		expectCopyIcon(testid(element, 'copy-stack'), 'bare-inverse');
		expectCopyIcon(testid(element, 'copy-context'), 'bare');
		expectCopyIcon(testid(element, 'copy-correlation'), 'bare');
		expect(element.shadowRoot.querySelector('lightning-button.copybtn')).toBeNull();
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
		const element = createComponent({detail: {...MOCK_DETAIL, id: 'm0'}, trace: manyTransactions()});
		await flush();
		expect(testids(element, 'txn-head')).toHaveLength(30);
		expect(testid(element, 'cap-row').textContent).toContain('Showing the first 30 of 35 transactions. Open in Chain Monitor for the full chain.');
		// More than six boundaries collapse into an Async run.
		expect(element.shadowRoot.textContent).toContain('Async ×');
	});

	it('shows the truncated cap row with the Chain Monitor pointer when a chain exists', async() =>
	{
		const element = createComponent({traceTruncated: true});
		await flush();
		expect(testid(element, 'cap-row').textContent).toContain('This trace is very long, so only its earliest entries are shown here. Open in Chain Monitor for the full chain.');
		expect(testid(element, 'cap-open-chain')).not.toBeNull();
	});

	it('drops the Chain Monitor sentence from the truncated cap row when no chain is registered', async() =>
	{
		const element = createComponent({traceTruncated: true, detail: {...MOCK_DETAIL, chainExists: false}});
		await flush();
		const capRow = testid(element, 'cap-row').textContent;
		expect(capRow).toContain('This trace is very long, so only its earliest entries are shown here.');
		expect(capRow).not.toContain('Open in Chain Monitor');
		expect(testid(element, 'cap-open-chain')).toBeNull();
	});

	it('drops the Chain Monitor sentence from the capped cap row when no chain is registered', async() =>
	{
		const element = createComponent({detail: {...MOCK_DETAIL, id: 'm0', chainExists: false}, trace: manyTransactions()});
		await flush();
		const capRow = testid(element, 'cap-row').textContent;
		expect(capRow).toContain('Showing the first 30 of 35 transactions.');
		expect(capRow).not.toContain('Open in Chain Monitor');
		expect(testid(element, 'cap-open-chain')).toBeNull();
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

	it('renders a whole-hour transaction span without a trailing minutes part', async() =>
	{
		const wholeHour = [
			{...MOCK_TRACE[0], id: 'h0', createdDate: at(0), transactionId: 'ht', parentTransactionId: null, isSelf: false},
			{...MOCK_TRACE[3], id: 'h1', createdDate: at(3600), transactionId: 'ht', parentTransactionId: null, isSelf: true}
		];
		const element = createComponent({detail: {...MOCK_DETAIL, id: 'h1', chainExists: false}, trace: wholeHour});
		await flush();
		const head = testids(element, 'txn-head')[0].textContent;
		expect(head).toContain('· 1h');
		expect(head).not.toContain('1h 0m');
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

	// A problem reaches this drawer having been either tagged in code or grouped at read time, and the two
	// need different things said about them. The detail DTO is identical for both, so the provenance is
	// supplied by the container that held the row.
	describe('grouped and tagged problems', () =>
	{
		// What the server sends for a group whose entries have all been cleaned up: what the grouping itself
		// knew, and nothing more. No id, no log number, no stack, an EMPTY limit list (never null), and the
		// method with no line, because the group was never keyed on one.
		const PURGED_GROUP = {
			level: 'ERROR',
			shortMessage: 'Attempt to de-reference a null object',
			exceptionType: 'System.NullPointerException',
			className: 'AcctHandler',
			methodLine: 'run',
			classMethod: 'AcctHandler.run',
			limitBars: []
		};
		// What the server sends for a group that resolved to a live representative: that entry's full detail,
		// log number and line-bearing location included — the same DTO a by-id open returns. The line matters:
		// it is exactly what the tagging snippet must NOT carry.
		const LIVE_GROUP = {...MOCK_DETAIL, logNumber: 'L-99', className: 'AcctHandler', methodLine: 'run:64', classMethod: 'AcctHandler.run'};
		// The zero-config shape: logged from a catch block with no source at all, so the entry carries the
		// exception's line number and nothing else — which the wire sends on its own.
		const UNATTRIBUTED_GROUP = {...LIVE_GROUP, className: null, methodLine: '64', classMethod: null};
		const SNIPPET_LIVE_GROUP = 'kern.LOG_Builder.build()\n\t.error(caughtException)\n'
				+ '\t.withFingerprint(\'AcctHandler.run:System.CalloutException\')\n\t.emitAt(\'AcctHandler.run\');';

		it('marks a tagged problem and leaves a grouped one unmarked', async() =>
		{
			const tagged = createComponent({provenance: 'rollup'});
			await flush();
			expect(testid(tagged, 'provenance-pill').textContent).toContain('Tagged');

			const grouped = createComponent({provenance: 'derived', detail: LIVE_GROUP});
			await flush();
			// Grouping is the default, so marking those rows too would badge nearly all of them and say nothing.
			expect(testid(grouped, 'provenance-pill')).toBeNull();
		});

		it('drops the log-number chip a grouped problem cannot have, even though its representative has one', async() =>
		{
			const element = createComponent({provenance: 'derived', detail: LIVE_GROUP});
			await flush();

			// Not dashed as it is in the list: an empty table cell reads as a value that went missing, but a
			// chip simply absent from a row of chips does not. The representative's own number is deliberately
			// not shown — this drawer heads the group, not that entry.
			expect(LIVE_GROUP.logNumber).toBe('L-99');
			expect(testid(element, 'log-number')).toBeNull();
			expect(testid(createComponent({provenance: 'rollup'}), 'log-number')).not.toBeNull();
		});

		it('quotes a group that carries no message at all without writing the word null into the code', async() =>
		{
			const element = createComponent({provenance: 'derived', detail: {...LIVE_GROUP, exceptionType: null, shortMessage: null}});
			await flush();

			// String(null) is "null", which would paste as a message nobody logged.
			expect(testid(element, 'track-snippet').textContent).toContain('.error(\'\')');
		});

		it('offers the latest occurrence instead of a record for a grouped problem', async() =>
		{
			const element = createComponent({provenance: 'derived', detail: LIVE_GROUP});
			await flush();

			// A group has no record of its own, so the button that opens something says what it opens.
			expect(testid(element, 'action-open-latest')).not.toBeNull();
			expect(testid(element, 'action-open-latest').disabled).toBe(false);
			expect(testid(element, 'action-open-record')).toBeNull();
		});

		it('disables that action and says why when the entries have been cleaned up', async() =>
		{
			const element = createComponent({provenance: 'derived', detail: PURGED_GROUP});
			await flush();

			expect(testid(element, 'action-open-latest').disabled).toBe(true);
			// A dead button with no explanation beside it reads as a broken console.
			expect(testid(element, 'derived-purged-note').textContent).toContain('only the grouped summary is shown');
		});

		it('separates having no stack trace from having no entry to take one from', async() =>
		{
			const element = createComponent({provenance: 'derived', detail: PURGED_GROUP});
			await flush();

			// The shipped line is a fact about an entry; this problem has no entry for it to be a fact about.
			expect(testid(element, 'stack-unavailable')).not.toBeNull();
			expect(testid(element, 'no-stack')).toBeNull();
		});

		it('keeps the entry-shaped stack empty state for an entry that simply carries none', async() =>
		{
			const element = createComponent({provenance: 'rollup', detail: {...MOCK_DETAIL, stackTrace: null}});
			await flush();

			// This entry exists and recorded where it was written; it just has no frames to show.
			expect(testid(element, 'no-stack').textContent).toContain('PaymentGateway.capture:64');
			expect(testid(element, 'stack-unavailable')).toBeNull();
		});

		it('explains a tagged problem\'s single entry against its much larger count', async() =>
		{
			const element = createComponent({provenance: 'rollup', occurrenceCount: 1284});
			await flush();

			// Without this, an admin reasonably concludes the other 1283 were deleted. The count is grouped in the
			// reader's locale, so it agrees with the formatted pill it sits under.
			const note = testid(element, 'tagged-count-note');
			expect(note.textContent).toContain('1,284');
			expect(note.textContent).not.toContain('1284');
			expect(note.textContent).toContain('Nothing was deleted');
		});

		it('says nothing about a count of one, which explains itself', async() =>
		{
			const element = createComponent({provenance: 'rollup', occurrenceCount: 1});
			await flush();

			expect(testid(element, 'tagged-count-note')).toBeNull();
		});

		it('offers a grouped problem the code that turns it into a tagged one', async() =>
		{
			const element = createComponent({provenance: 'derived', detail: LIVE_GROUP, namespacePrefix: 'kern.'});
			await flush();

			// Copy-to-compile, asserted whole: a managed subscriber must get kern.LOG_Builder, an exception type
			// means the reader logged this from a catch block and has the exception itself in scope, and the chain
			// order is part of the contract (emitAt is void, so nothing may follow it). The source is the raw
			// class.method the entry recorded, NOT the drawer's display location: the representative's line
			// (run:64) would otherwise be baked into emitAt and into the fingerprint, mis-attributing every future
			// entry and moving the key on every deploy.
			expect(testid(element, 'track-snippet').textContent).toBe(SNIPPET_LIVE_GROUP);
			expect(testid(element, 'meta-source').textContent).toContain('AcctHandler.run:64');
			// caughtException is a stand-in for the reader's own variable, and the drawer says so.
			expect(testid(element, 'track-exception-note').textContent).toContain('caughtException');
			expect(testid(element, 'name-the-source')).toBeNull();
		});

		it('drops the namespace where the package is deployed without one', async() =>
		{
			const element = createComponent({provenance: 'derived', detail: LIVE_GROUP, namespacePrefix: ''});
			await flush();

			// The same snippet must NOT carry a prefix in an unmanaged deploy, where it would not compile.
			expect(testid(element, 'track-snippet').textContent).toContain('LOG_Builder.build()');
			expect(testid(element, 'track-snippet').textContent).not.toContain('kern.');
		});

		it('asks an unattributed group to name its source before naming itself', async() =>
		{
			const element = createComponent({provenance: 'derived', detail: UNATTRIBUTED_GROUP, namespacePrefix: 'kern.'});
			await flush();

			// With no source recorded, everything throwing this error is one problem here — so tagging it would
			// name a group that is still several problems. Naming the source has to come first.
			expect(testid(element, 'name-source-snippet').textContent).toBe('kern.LOG_Builder.build()\n\t.error(caughtException)\n\t.emitAt(\'MyClass.myMethod\');');
			expect(testid(element, 'track-signature')).toBeNull();
			// Two stand-ins, two notes: this snippet names caughtException as well as MyClass.myMethod.
			expect(testid(element, 'track-exception-note').textContent).toContain('caughtException');
			// The bare line the wire sends for a source-less entry is not a source: never "undefined.64".
			expect(testid(element, 'meta-source').textContent).not.toContain('64');
			expect(testid(element, 'meta-source').textContent).toContain('—');
		});

		it('quotes the captured message when there is no exception to pass', async() =>
		{
			const element = createComponent({provenance: 'derived', detail: {...LIVE_GROUP, exceptionType: null, shortMessage: 'It\'s late', level: 'WARN'}});
			await flush();

			// The apostrophe would end the Apex literal and leave the pasted snippet uncompilable.
			const snippet = testid(element, 'track-snippet').textContent;
			expect(snippet).toContain('.warn(\'It\\\'s late\')');
			expect(snippet).toContain('.withFingerprint(\'AcctHandler.run:WARN\')');
			// No exception is passed, so there is nothing to tell the reader to replace.
			expect(testid(element, 'track-exception-note')).toBeNull();
		});

		it('passes the message, not the exception, at any level but ERROR — the builder has no warn(Exception)', async() =>
		{
			const element = createComponent({provenance: 'derived', detail: {...LIVE_GROUP, exceptionType: 'System.LimitException', shortMessage: 'Too many SOQL', level: 'WARN'}});
			await flush();

			// error(Exception) is the only exception overload LOG_Builder offers; warn(caughtException) fails to compile.
			const snippet = testid(element, 'track-snippet').textContent;
			expect(snippet).toContain('.warn(\'Too many SOQL\')');
			expect(snippet).not.toContain('caughtException');
			// The exception type still names the problem in the fingerprint — that is what the group was keyed on.
			expect(snippet).toContain('.withFingerprint(\'AcctHandler.run:System.LimitException\')');
			expect(testid(element, 'track-exception-note')).toBeNull();
		});

		it('escapes every character an Apex literal cannot hold, backslash first', async() =>
		{
			// A backslash starts an escape Apex may not know (\\d) or eats the closing quote when it is last; a
			// raw line break splits the literal. Either pasted as-is fails to compile — or worse, compiles to
			// something the reader did not log. A tab is legal but invisible, so it is written out too.
			const message = 'Regex \\d{3} failed \\\'quoted\\\' on line one\nline two\r\ttabbed, trailing \\';
			const element = createComponent({provenance: 'derived', detail: {...LIVE_GROUP, exceptionType: null, shortMessage: message, level: 'WARN'}});
			await flush();

			const snippet = testid(element, 'track-snippet').textContent;
			expect(snippet).toContain('.warn(\'Regex \\\\d{3} failed \\\\\\\'quoted\\\\\\\' on line one\\nline two\\r\\ttabbed, trailing \\\\\')');
			// No raw line break survives inside the literal: the snippet keeps its four lines, carries no raw CR, and
			// the .warn( line closes its own literal — an EVEN run of backslashes before the closing quote, so a
			// trailing backslash left unescaped (which would eat the quote) is caught too.
			expect(snippet.split('\n').length).toBe(4);
			expect(snippet).not.toContain('\r');
			expect(snippet.split('\n').find((line) => line.includes('.warn('))).toMatch(/[^\\](?:\\\\)*'\)$/);
		});

		it('offers the snippet through the same copy icon as every other block', async() =>
		{
			const element = createComponent({provenance: 'derived', detail: LIVE_GROUP, namespacePrefix: 'kern.'});
			await flush();

			// Exactly one snippet copy affordance renders for this provenance (the template carries one per snippet form).
			expect(testids(element, 'copy-snippet').length).toBe(1);
			expectCopyIcon(testid(element, 'copy-snippet'), 'bare-inverse');
		});

		it('copies the snippet, which is the point of showing it', async() =>
		{
			const element = createComponent({provenance: 'derived', detail: LIVE_GROUP, namespacePrefix: 'kern.'});
			await flush();

			testid(element, 'copy-snippet').click();
			await flush();

			expect(copyToClipBoard).toHaveBeenCalledWith(expect.stringContaining('kern.LOG_Builder.build()'));
		});

		it('opens the latest occurrence, which is the entry the group resolved to', async() =>
		{
			const element = createComponent({provenance: 'derived', detail: LIVE_GROUP});
			const opened = jest.fn();
			element.addEventListener('openrecord', opened);
			await flush();

			testid(element, 'action-open-latest').click();

			// The representative the server resolved for the group under the current filters — the same entry the
			// drawer's message, stack and limits already describe.
			expect(opened).toHaveBeenCalledTimes(1);
			expect(opened.mock.calls[0][0].detail).toEqual({entryId: LIVE_GROUP.id});
		});

		it('renders a purged group that also had no source without either explainer block throwing', async() =>
		{
			const element = createComponent({provenance: 'derived', detail: {...PURGED_GROUP, className: null, methodLine: null, classMethod: null}});
			await flush();

			// The zero-config shape after its entries aged out: nothing to open, nothing to tag, only the source to
			// name — and no source to show.
			expect(testid(element, 'action-open-latest').disabled).toBe(true);
			expect(testid(element, 'name-the-source')).not.toBeNull();
			expect(testid(element, 'track-signature')).toBeNull();
			expect(testid(element, 'meta-source').textContent).toContain('—');
			expect(testid(element, 'no-limits')).not.toBeNull();
		});

		it('shows the problem\'s own span in the problems view, not the representative entry\'s', async() =>
		{
			// The detail is the LATEST occurrence, so its own timestamps would say a two-day-old problem was first
			// seen a moment ago. The container holds the row and passes the group's real span down.
			const element = createComponent({
				provenance: 'derived', detail: LIVE_GROUP, problemFirstSeen: '2026-06-28T09:00:00.000Z', problemLastSeen: '2026-06-30T19:34:00.000Z'
			});
			await flush();

			const stamps = element.shadowRoot.querySelectorAll('lightning-relative-date-time');
			expect(stamps[0].value).toBe(Date.parse('2026-06-28T09:00:00.000Z'));
			expect(stamps[1].value).toBe(Date.parse('2026-06-30T19:34:00.000Z'));
		});

		it('keeps the span readable for a purged group, which has no entry timestamps at all', async() =>
		{
			const element = createComponent({
				provenance: 'derived', detail: PURGED_GROUP, problemFirstSeen: '2026-06-28T09:00:00.000Z', problemLastSeen: '2026-06-29T09:00:00.000Z'
			});
			await flush();

			const stamps = element.shadowRoot.querySelectorAll('lightning-relative-date-time');
			expect(stamps[0].value).toBe(Date.parse('2026-06-28T09:00:00.000Z'));
			expect(stamps[1].value).toBe(Date.parse('2026-06-29T09:00:00.000Z'));
		});

		it('ignores the problem span in the entries view, where the entry\'s own time is the truth', async() =>
		{
			const element = createComponent({view: 'entries', provenance: null, problemFirstSeen: '2026-06-28T09:00:00.000Z', problemLastSeen: '2026-06-29T09:00:00.000Z'});
			await flush();

			const stamps = element.shadowRoot.querySelectorAll('lightning-relative-date-time');
			expect(stamps[0].value).toBe(Date.parse(MOCK_DETAIL.firstSeen));
		});

		it('drills into occurrences by class, by message when there is no class, and not at all when there is neither', async() =>
		{
			const byClass = createComponent({provenance: 'derived', detail: LIVE_GROUP});
			const drilled = jest.fn();
			byClass.addEventListener('viewoccurrences', drilled);
			await flush();
			testid(byClass, 'action-view-occurrences').click();
			expect(drilled.mock.calls[0][0].detail).toEqual({source: 'AcctHandler'});

			// No source recorded: everything throwing this error is one problem here, and its message is the handle
			// the entries view can search for. Never the class, which is undefined, and never an unfiltered drill.
			const byMessage = createComponent({provenance: 'derived', detail: UNATTRIBUTED_GROUP});
			const drilledByMessage = jest.fn();
			byMessage.addEventListener('viewoccurrences', drilledByMessage);
			await flush();
			testid(byMessage, 'action-view-occurrences').click();
			expect(drilledByMessage.mock.calls[0][0].detail).toEqual({source: LIVE_GROUP.shortMessage});

			const nothingToDrillOn = createComponent({provenance: 'derived', detail: {...UNATTRIBUTED_GROUP, shortMessage: null}});
			await flush();
			expect(testid(nothingToDrillOn, 'action-view-occurrences')).toBeNull();
		});

		it('shows none of it in the individual entries view', async() =>
		{
			const element = createComponent({view: 'entries', provenance: null});
			await flush();

			// Provenance is a property of a grouped problem, not of a single log line.
			expect(testid(element, 'provenance-pill')).toBeNull();
			expect(testid(element, 'tagged-count-note')).toBeNull();
			expect(testid(element, 'track-signature')).toBeNull();
			expect(testid(element, 'action-open-latest')).toBeNull();
			expect(testid(element, 'action-open-record')).not.toBeNull();
		});
	});
});
