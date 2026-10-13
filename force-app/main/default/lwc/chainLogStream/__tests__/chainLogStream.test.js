// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for chainLogStream LWC component: seeded history, live appends
 *              through the empApi stub, the chain-match filter, seed/live deduplication, the
 *              rolling cap, the disconnected notice, and the Failed-chain default collapse.
 *
 * @author Jason van Beukering
 * @date August 2026, October 2026
 */

// The prefix wrapper defaults to the managed-install value so the channel and payload-key tests
// double as the managed-path regression; no-namespace tests override it.
jest.mock('@salesforce/apex/CTRL_ChainMonitor.getNamespacePrefix', () => ({
	default: jest.fn().mockResolvedValue('kern__')
}), {virtual: true});

jest.mock('@salesforce/label/c.ChainMonitor_LogStreamTitle', () => ({default: 'Live activity'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_LogStreamEmpty', () => ({default: 'Nothing streamed yet for this chain.'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_LogStreamCaveat', () => ({default: 'Only errors always stream. Other levels depend on the org\'s log settings.'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_LogStreamDisconnected', () => ({default: 'Live stream disconnected. Entries still record; refresh to catch up.'}), {virtual: true});
jest.mock('@salesforce/label/c.ChainMonitor_LogStreamLastEvent', () => ({default: 'Last event'}), {virtual: true});

import {createElement} from 'lwc';
import ChainLogStream from 'c/chainLogStream';
import {subscribe, unsubscribe, onError} from 'lightning/empApi';
import {mockCallControllerMethod, mockConsoleError} from 'c/componentBuilder';
import getNamespacePrefix from '@salesforce/apex/CTRL_ChainMonitor.getNamespacePrefix';

const EXECUTION_ID = 'a00000000000001AAA';
const CORRELATION_ID = 'stream-correlation-0001';
// The seed endpoint's contract order: OLDEST first (the correlated trace, read in ascending order).
const SEED_ROWS = [
	{timestamp: '2026-08-09T10:00:01.000Z', logLevel: 'INFO', message: 'Seeded info entry'},
	{timestamp: '2026-08-09T10:00:05.000Z', logLevel: 'ERROR', message: 'Seeded failure entry'}
];

describe('c-chain-log-stream', () =>
{
	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
		jest.clearAllMocks();
		getNamespacePrefix.mockResolvedValue('kern__');
	});

	async function createComponent({executionId = EXECUTION_ID, correlationId = CORRELATION_ID, chainStatus = 'Running', seedRows = SEED_ROWS} = {})
	{
		// Invoking the apex function mirrors the shared mock's default contract so the
		// transformer's import stub stays exercised.
		mockCallControllerMethod.mockImplementation((apexFunction, parameters) =>
		{
			if(typeof apexFunction === 'function')
			{
				apexFunction(parameters);
			}
			return Promise.resolve(seedRows);
		});

		const element = createElement('c-chain-log-stream', {is: ChainLogStream});
		element.chainStatus = chainStatus;
		element.correlationId = correlationId;
		if(executionId)
		{
			element.executionId = executionId;
		}
		document.body.appendChild(element);
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();
		return element;
	}

	function streamEntries(element)
	{
		return element.shadowRoot.querySelectorAll('[data-testid="log-stream-entry"]');
	}

	function deliverEvent(payload)
	{
		const streamingCallback = subscribe.mock.calls[0][2];
		streamingCallback({data: {payload}});
	}

	it('subscribes to the namespaced log event channel on connected callback', async() =>
	{
		await createComponent();

		expect(subscribe).toHaveBeenCalledWith('/event/kern__LogEntryEvent__e', -1, expect.any(Function));
	});

	it('unsubscribes on disconnected callback, with the acknowledgement the platform requires', async() =>
	{
		const element = await createComponent();

		document.body.removeChild(element);
		await Promise.resolve();

		// empApi hands its second argument on as the callback: called with one argument, it raises
		// "Invalid or missing callback" in the middle of the page being torn down.
		expect(unsubscribe.mock.calls[0]).toEqual([
			expect.anything(),
			expect.any(Function)
		]);
		expect(unsubscribe.mock.calls[0][1]({successful: true})).toBeNull();
	});

	it('seeds the persisted history newest-first from the endpoint\'s oldest-first contract order', async() =>
	{
		const element = await createComponent();

		expect(mockCallControllerMethod).toHaveBeenCalledWith(expect.anything(), {executionId: EXECUTION_ID});
		const entries = streamEntries(element);
		expect(entries.length).toBe(2);
		expect(entries[0].textContent).toContain('Seeded failure entry');
		expect(entries[1].textContent).toContain('Seeded info entry');
		// Each row carries the muted absolute time beside the relative one (P11).
		expect(entries[0].querySelector('.stream-time-absolute lightning-formatted-date-time').value).toBe('2026-08-09T10:00:05.000Z');
		expect(element.shadowRoot.querySelector('[data-testid="log-stream-empty"]')).toBeFalsy();
		expect(element.shadowRoot.querySelector('[data-testid="log-stream-caveat"]').textContent)
		.toBe('Only errors always stream. Other levels depend on the org\'s log settings.');
	});

	it('reports the NEWEST entry\'s time in the last-event header indicator on a fresh seed', async() =>
	{
		const element = await createComponent();

		// The indicator renders a relative time for renderedEntries[0]; a reversed seed would put
		// the oldest row first and make the header lie about the last event's age. The value is epoch
		// milliseconds: lightning-relative-date-time renders "Invalid date" for the ISO string the seed carries.
		const lastEvent = element.shadowRoot.querySelector('[data-testid="stream-last-event"]');
		expect(lastEvent).toBeTruthy();
		expect(lastEvent.querySelector('lightning-relative-date-time').value).toBe(Date.parse('2026-08-09T10:00:05.000Z'));
	});

	it('hands every relative-time binding epoch milliseconds while the row title keeps the ISO timestamp', async() =>
	{
		const element = await createComponent();

		const rows = element.shadowRoot.querySelectorAll('[data-testid="log-stream-entry"]');
		const newestFirst = [...SEED_ROWS].reverse();
		expect(rows.length).toBe(newestFirst.length);
		rows.forEach((row, index) =>
		{
			const relative = row.querySelector('lightning-relative-date-time');
			expect(Number.isFinite(relative.value)).toBe(true);
			expect(relative.value).toBe(Date.parse(newestFirst[index].timestamp));
			expect(row.getAttribute('title')).toBe(newestFirst[index].timestamp);
			expect(row.querySelector('lightning-formatted-date-time').value).toBe(newestFirst[index].timestamp);
		});
	});

	it('leaves the relative time empty rather than at the epoch when a live event carries no CreatedDate', async() =>
	{
		const element = await createComponent({seedRows: []});

		deliverEvent({kern__RecordId__c: EXECUTION_ID, kern__LogLevel__c: 'ERROR', kern__ShortMessage__c: 'Undated live entry'});
		await Promise.resolve();

		// new Date(null).getTime() is 0, which shows as "56 years ago"; the entry hands the component null instead.
		const entry = streamEntries(element)[0];
		expect(entry.textContent).toContain('Undated live entry');
		expect(entry.querySelector('lightning-relative-date-time').value).toBeNull();
		expect(element.shadowRoot.querySelector('[data-testid="stream-last-event"] lightning-relative-date-time').value).toBeNull();
	});

	it('shows the empty state alongside the caveat when nothing has streamed', async() =>
	{
		const element = await createComponent({seedRows: []});

		expect(element.shadowRoot.querySelector('[data-testid="log-stream-empty"]').textContent).toBe('Nothing streamed yet for this chain.');
		expect(element.shadowRoot.querySelector('[data-testid="log-stream-caveat"]')).toBeTruthy();
		expect(element.shadowRoot.querySelector('[data-testid="stream-last-event"]')).toBeFalsy();
	});

	it('appends a live entry above the seeded history when the event references the chain record', async() =>
	{
		const element = await createComponent();

		deliverEvent({
			CreatedDate: '2026-08-09T10:01:00.000Z', kern__RecordId__c: EXECUTION_ID, kern__LogLevel__c: 'ERROR', kern__ShortMessage__c: 'Live error entry'
		});
		await Promise.resolve();

		const entries = streamEntries(element);
		expect(entries.length).toBe(3);
		expect(entries[0].textContent).toContain('Live error entry');
		// The live row and the header caption both convert the event's CreatedDate to epoch milliseconds.
		// The live path shares the seed path's entry builder, and this check keeps it that way.
		expect(entries[0].querySelector('lightning-relative-date-time').value).toBe(Date.parse('2026-08-09T10:01:00.000Z'));
		const lastEvent = element.shadowRoot.querySelector('[data-testid="stream-last-event"]');
		expect(lastEvent.textContent).toContain('Last event');
		expect(lastEvent.querySelector('lightning-relative-date-time').value).toBe(Date.parse('2026-08-09T10:01:00.000Z'));
	});

	it('appends a live entry matched by correlation id when the event carries no record reference', async() =>
	{
		const element = await createComponent();

		deliverEvent({
			CreatedDate: '2026-08-09T10:01:01.000Z', kern__CorrelationId__c: CORRELATION_ID, kern__LogLevel__c: 'WARN', kern__Message__c: 'Correlated warn entry'
		});
		await Promise.resolve();

		expect(streamEntries(element)[0].textContent).toContain('Correlated warn entry');
	});

	it('falls back to the full message when the event has no short message', async() =>
	{
		const element = await createComponent({seedRows: []});

		deliverEvent({
			CreatedDate: '2026-08-09T10:01:02.000Z', kern__RecordId__c: EXECUTION_ID, kern__LogLevel__c: 'ERROR', kern__Message__c: 'Full message body'
		});
		await Promise.resolve();

		expect(streamEntries(element)[0].textContent).toContain('Full message body');
	});

	it('ignores events for other records and other correlations', async() =>
	{
		const element = await createComponent();

		deliverEvent({
			CreatedDate: '2026-08-09T10:01:03.000Z',
			kern__RecordId__c: 'a00000000000999AAA',
			kern__CorrelationId__c: 'some-other-correlation',
			kern__LogLevel__c: 'ERROR',
			kern__ShortMessage__c: 'Unrelated entry'
		});
		deliverEvent(null);
		await Promise.resolve();

		expect(streamEntries(element).length).toBe(2);
	});

	it('drops a live delivery that duplicates a seeded row by timestamp and message', async() =>
	{
		const element = await createComponent();

		deliverEvent({
			CreatedDate: SEED_ROWS[0].timestamp, kern__RecordId__c: EXECUTION_ID, kern__LogLevel__c: 'ERROR', kern__ShortMessage__c: SEED_ROWS[0].message
		});
		await Promise.resolve();

		expect(streamEntries(element).length).toBe(2);
	});

	it('caps the rendered list at 100 entries, dropping the oldest', async() =>
	{
		const element = await createComponent({seedRows: []});

		for(let eventIndex = 0; eventIndex < 101; eventIndex++)
		{
			deliverEvent({
				CreatedDate: `2026-08-09T11:00:${String(eventIndex % 60).padStart(2, '0')}.${String(eventIndex).padStart(3, '0')}Z`,
				kern__RecordId__c: EXECUTION_ID,
				kern__LogLevel__c: 'INFO',
				kern__ShortMessage__c: `Entry ${eventIndex}`
			});
		}
		await Promise.resolve();

		const entries = streamEntries(element);
		expect(entries.length).toBe(100);
		expect(entries[0].textContent).toContain('Entry 100');
	});

	it('replaces the caveat with the disconnected notice when the event feed errors', async() =>
	{
		const element = await createComponent();

		const errorCallback = onError.mock.calls[0][0];
		errorCallback({error: 'stream broke'});
		await Promise.resolve();

		expect(element.shadowRoot.querySelector('[data-testid="log-stream-disconnected"]').textContent)
		.toBe('Live stream disconnected. Entries still record; refresh to catch up.');
		expect(element.shadowRoot.querySelector('[data-testid="log-stream-caveat"]')).toBeFalsy();
	});

	it('flips the disconnected notice and logs when the subscribe itself fails', async() =>
	{
		subscribe.mockRejectedValueOnce(new Error('cold org'));

		const element = await createComponent();
		await Promise.resolve();

		expect(mockConsoleError).toHaveBeenCalled();
		expect(element.shadowRoot.querySelector('[data-testid="log-stream-disconnected"]')).toBeTruthy();
	});

	it('collapses by default while the chain is Failed and expands on toggle', async() =>
	{
		const element = await createComponent({chainStatus: 'Failed'});

		expect(streamEntries(element).length).toBe(0);
		expect(element.shadowRoot.querySelector('[data-testid="log-stream-title"]').textContent).toBe('Live activity');

		element.shadowRoot.querySelector('.stream-toggle').dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();

		expect(streamEntries(element).length).toBe(2);
	});

	it('starts expanded for a non-Failed chain and collapses on toggle', async() =>
	{
		const element = await createComponent();

		expect(streamEntries(element).length).toBe(2);

		element.shadowRoot.querySelector('.stream-toggle').dispatchEvent(new CustomEvent('click'));
		await Promise.resolve();

		expect(streamEntries(element).length).toBe(0);
	});

	it('reseeds and clears the live tail when the selection moves to another chain', async() =>
	{
		const element = await createComponent();
		deliverEvent({
			CreatedDate: '2026-08-09T10:02:00.000Z', kern__RecordId__c: EXECUTION_ID, kern__LogLevel__c: 'ERROR', kern__ShortMessage__c: 'Old chain live entry'
		});
		await Promise.resolve();
		mockCallControllerMethod.mockResolvedValue([SEED_ROWS[0]]);

		element.executionId = 'a00000000000002AAA';
		await Promise.resolve();
		await Promise.resolve();

		expect(mockCallControllerMethod).toHaveBeenLastCalledWith(expect.anything(), {executionId: 'a00000000000002AAA'});
		const entries = streamEntries(element);
		expect(entries.length).toBe(1);
		expect(entries[0].textContent).toContain('Seeded info entry');
	});

	it('ignores a re-assignment of the same execution id without reseeding', async() =>
	{
		const element = await createComponent();
		mockCallControllerMethod.mockClear();

		element.executionId = EXECUTION_ID;
		await Promise.resolve();

		expect(mockCallControllerMethod).not.toHaveBeenCalled();
		expect(element.executionId).toBe(EXECUTION_ID);
	});

	it('discards a stale seed response when the selection moved during the read', async() =>
	{
		let resolveFirstSeed;
		mockCallControllerMethod.mockImplementationOnce(() => new Promise((resolve) =>
		{
			resolveFirstSeed = resolve;
		}));

		const element = createElement('c-chain-log-stream', {is: ChainLogStream});
		element.chainStatus = 'Running';
		element.executionId = EXECUTION_ID;
		document.body.appendChild(element);
		await Promise.resolve();

		mockCallControllerMethod.mockResolvedValue([SEED_ROWS[0]]);
		element.executionId = 'a00000000000002AAA';
		resolveFirstSeed(SEED_ROWS);
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();

		const entries = streamEntries(element);
		expect(entries.length).toBe(1);
		expect(entries[0].textContent).toContain('Seeded info entry');
	});

	it('renders an entry with empty level and message when the event carries neither', async() =>
	{
		const element = await createComponent({seedRows: []});

		deliverEvent({
			CreatedDate: '2026-08-09T10:04:00.000Z', kern__RecordId__c: EXECUTION_ID
		});
		await Promise.resolve();

		const entries = streamEntries(element);
		expect(entries.length).toBe(1);
		// The row title carries the full timestamp (P11); the message span renders empty.
		expect(entries[0].title).toBe('2026-08-09T10:04:00.000Z');
		expect(entries[0].querySelector('.stream-message').textContent).toBe('');
	});

	it('treats a nullish prefix as unprefixed rather than corrupting the channel', async() =>
	{
		getNamespacePrefix.mockResolvedValueOnce(null);

		await createComponent({seedRows: []});

		expect(subscribe).toHaveBeenCalledWith('/event/LogEntryEvent__e', -1, expect.any(Function));
	});

	it('does not subscribe when the component disconnects during prefix resolution', async() =>
	{
		let resolvePrefix;
		getNamespacePrefix.mockReturnValueOnce(new Promise((resolve) =>
		{
			resolvePrefix = resolve;
		}));
		const element = createElement('c-chain-log-stream', {is: ChainLogStream});
		document.body.appendChild(element);
		document.body.removeChild(element);

		resolvePrefix('kern__');
		await Promise.resolve();
		await Promise.resolve();

		expect(subscribe).not.toHaveBeenCalled();
	});

	it('releases a subscription that resolves after the component disconnects', async() =>
	{
		let resolveSubscribe;
		subscribe.mockReturnValueOnce(new Promise((resolve) =>
		{
			resolveSubscribe = resolve;
		}));
		const element = createElement('c-chain-log-stream', {is: ChainLogStream});
		document.body.appendChild(element);
		await Promise.resolve();
		await Promise.resolve();
		document.body.removeChild(element);

		const lateSubscription = {id: 'late-subscription'};
		resolveSubscribe(lateSubscription);
		await Promise.resolve();
		await Promise.resolve();

		expect(unsubscribe).toHaveBeenCalledWith(lateSubscription, expect.any(Function));
	});

	it('builds the unprefixed channel and payload keys on a no-namespace deploy', async() =>
	{
		getNamespacePrefix.mockResolvedValue('');

		const element = await createComponent({seedRows: []});
		expect(subscribe).toHaveBeenCalledWith('/event/LogEntryEvent__e', -1, expect.any(Function));

		deliverEvent({
			CreatedDate: '2026-08-09T10:03:00.000Z', RecordId__c: EXECUTION_ID, LogLevel__c: 'ERROR', ShortMessage__c: 'Unprefixed entry'
		});
		await Promise.resolve();

		expect(streamEntries(element)[0].textContent).toContain('Unprefixed entry');
	});
});
