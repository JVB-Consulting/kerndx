// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for chainMonitor container LWC component
 * @author Jason van Beukering
 * @date April 2026, July 2026
 */

// The prefix wrapper defaults to the managed-install value so the existing channel and
// payload-key tests double as the managed-path regression; no-namespace tests override it.
jest.mock('@salesforce/apex/CTRL_ChainMonitor.getNamespacePrefix', () => ({
	default: jest.fn().mockResolvedValue('kern__')
}), {virtual: true});

import {createElement} from 'lwc';
import ChainMonitor from 'c/chainMonitor';
import {subscribe, unsubscribe} from 'lightning/empApi';
import {CurrentPageReference} from 'lightning/navigation';
import {mockCallControllerMethod, mockConsoleError, mockShowErrorToast} from 'c/componentBuilder';
import getNamespacePrefix from '@salesforce/apex/CTRL_ChainMonitor.getNamespacePrefix';
import CHAIN_MONITOR_TITLE from '@salesforce/label/c.ChainMonitor_Title';

describe('c-chain-monitor', () =>
{
	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
		jest.clearAllMocks();
	});

	async function createComponent()
	{
		const element = createElement('c-chain-monitor', {is: ChainMonitor});
		document.body.appendChild(element);
		await Promise.resolve();
		await Promise.resolve();
		return element;
	}

	it('should render list and detail panels', async() =>
	{
		const element = await createComponent();

		const list = element.shadowRoot.querySelector('c-chain-monitor-list');
		const detail = element.shadowRoot.querySelector('c-chain-monitor-detail');
		expect(list).toBeTruthy();
		expect(detail).toBeTruthy();
	});

	it('should title the card from the custom label', async() =>
	{
		const element = await createComponent();

		const card = element.shadowRoot.querySelector('lightning-card');
		expect(card.title).toBe(CHAIN_MONITOR_TITLE);
	});

	it('should subscribe to empApi on connected callback', async() =>
	{
		await createComponent();

		expect(subscribe).toHaveBeenCalledWith('/event/kern__LogEntryEvent__e', -1, expect.any(Function));
	});

	it('should unsubscribe from empApi on disconnected callback', async() =>
	{
		const element = await createComponent();

		document.body.removeChild(element);
		await Promise.resolve();

		expect(unsubscribe).toHaveBeenCalled();
	});

	it('should pass selected execution id to detail panel', async() =>
	{
		const element = await createComponent();
		const list = element.shadowRoot.querySelector('c-chain-monitor-list');

		list.dispatchEvent(new CustomEvent('select', {detail: {executionId: 'test-id'}}));
		await Promise.resolve();

		const detail = element.shadowRoot.querySelector('c-chain-monitor-detail');
		expect(detail.executionId).toBe('test-id');
	});

	it('should refresh list for any record event until a chain has been in view', async() =>
	{
		const element = await createComponent();
		const list = element.shadowRoot.querySelector('c-chain-monitor-list');
		const detail = element.shadowRoot.querySelector('c-chain-monitor-detail');
		const listRefresh = jest.fn();
		const detailRefresh = jest.fn();
		list.refresh = listRefresh;
		detail.refresh = detailRefresh;

		// No chain has been in view yet, so the key prefix is unknown and the streaming filter
		// deliberately passes every record event; on an empty monitor the first chain still
		// appears live rather than being filtered out.
		const streamingCallback = subscribe.mock.calls[0][2];
		streamingCallback({data: {payload: {kern__RecordId__c: 'some-chain-id'}}});
		await Promise.resolve();

		expect(listRefresh).toHaveBeenCalledTimes(1);
		expect(detailRefresh).not.toHaveBeenCalled();
	});

	it('should refresh detail when streaming event matches selected execution', async() =>
	{
		const element = await createComponent();

		const list = element.shadowRoot.querySelector('c-chain-monitor-list');
		list.dispatchEvent(new CustomEvent('select', {detail: {executionId: 'matching-id'}}));
		await Promise.resolve();

		const detail = element.shadowRoot.querySelector('c-chain-monitor-detail');
		const listRefresh = jest.fn();
		const detailRefresh = jest.fn();
		list.refresh = listRefresh;
		detail.refresh = detailRefresh;

		const streamingCallback = subscribe.mock.calls[0][2];
		streamingCallback({data: {payload: {kern__RecordId__c: 'matching-id'}}});
		await Promise.resolve();

		expect(listRefresh).toHaveBeenCalledTimes(1);
		expect(detailRefresh).toHaveBeenCalledTimes(1);
	});

	it('should not re-query when the streaming event record does not match the chains in view', async() =>
	{
		const element = await createComponent();
		const list = element.shadowRoot.querySelector('c-chain-monitor-list');
		list.dispatchEvent(new CustomEvent('select', {detail: {executionId: 'a05000000000001AAA'}}));
		await Promise.resolve();
		const listRefresh = jest.fn();
		const detailRefresh = jest.fn();
		list.refresh = listRefresh;
		element.shadowRoot.querySelector('c-chain-monitor-detail').refresh = detailRefresh;

		// An org-wide LogEntryEvent about an unrelated record (an Account here) must no longer
		// trigger a full re-query of the chain list.
		const streamingCallback = subscribe.mock.calls[0][2];
		streamingCallback({data: {payload: {kern__RecordId__c: '001000000000001AAA'}}});
		await Promise.resolve();

		expect(listRefresh).not.toHaveBeenCalled();
		expect(detailRefresh).not.toHaveBeenCalled();
	});

	it('should re-query for a chain execution event even when it is not the selected chain', async() =>
	{
		const element = await createComponent();
		const list = element.shadowRoot.querySelector('c-chain-monitor-list');
		list.dispatchEvent(new CustomEvent('select', {detail: {executionId: 'a05000000000001AAA'}}));
		await Promise.resolve();
		const listRefresh = jest.fn();
		const detailRefresh = jest.fn();
		list.refresh = listRefresh;
		element.shadowRoot.querySelector('c-chain-monitor-detail').refresh = detailRefresh;

		// A different chain execution (same org-specific key prefix) still refreshes the list so
		// newly started or re-sorted chains keep appearing live; only the detail stays put.
		const streamingCallback = subscribe.mock.calls[0][2];
		streamingCallback({data: {payload: {kern__RecordId__c: 'a05000000000777AAA'}}});
		await Promise.resolve();

		expect(listRefresh).toHaveBeenCalledTimes(1);
		expect(detailRefresh).not.toHaveBeenCalled();
	});

	it('should subscribe on the unprefixed channel in an unmanaged (no-namespace) deploy', async() =>
	{
		getNamespacePrefix.mockResolvedValueOnce('');

		await createComponent();

		expect(subscribe).toHaveBeenCalledWith('/event/LogEntryEvent__e', -1, expect.any(Function));
	});

	it('should refresh from the unprefixed payload key in an unmanaged (no-namespace) deploy', async() =>
	{
		getNamespacePrefix.mockResolvedValueOnce('');
		const element = await createComponent();
		const list = element.shadowRoot.querySelector('c-chain-monitor-list');
		const listRefresh = jest.fn();
		list.refresh = listRefresh;

		const streamingCallback = subscribe.mock.calls[0][2];
		streamingCallback({data: {payload: {RecordId__c: 'some-chain-id'}}});
		await Promise.resolve();

		expect(listRefresh).toHaveBeenCalledTimes(1);
	});

	it('should treat a nullish prefix as unprefixed rather than corrupting the channel', async() =>
	{
		getNamespacePrefix.mockResolvedValueOnce(undefined);

		await createComponent();

		expect(subscribe).toHaveBeenCalledWith('/event/LogEntryEvent__e', -1, expect.any(Function));
	});

	it('should degrade silently without subscribing when the prefix resolution fails', async() =>
	{
		getNamespacePrefix.mockRejectedValueOnce(new Error('apex unavailable'));
		const element = createElement('c-chain-monitor', {is: ChainMonitor});
		document.body.appendChild(element);
		await Promise.resolve();
		await Promise.resolve();

		expect(subscribe).not.toHaveBeenCalled();
		expect(mockShowErrorToast).not.toHaveBeenCalled();
		// Silent means no toast; the failure is still logged so real-time breakage is visible.
		expect(mockConsoleError).toHaveBeenCalledWith(expect.any(Error), 'ChainMonitor.subscribeToEvents');
		expect(element.shadowRoot.querySelector('c-chain-monitor-list')).toBeTruthy();
	});

	it('should not subscribe when the component disconnects during prefix resolution', async() =>
	{
		let resolvePrefix;
		getNamespacePrefix.mockReturnValueOnce(new Promise((resolve) =>
		{
			resolvePrefix = resolve;
		}));
		const element = createElement('c-chain-monitor', {is: ChainMonitor});
		document.body.appendChild(element);
		document.body.removeChild(element);

		resolvePrefix('kern__');
		await Promise.resolve();
		await Promise.resolve();

		expect(subscribe).not.toHaveBeenCalled();
	});

	it('should release a subscription that resolves after the component disconnects', async() =>
	{
		let resolveSubscribe;
		subscribe.mockReturnValueOnce(new Promise((resolve) =>
		{
			resolveSubscribe = resolve;
		}));
		const element = createElement('c-chain-monitor', {is: ChainMonitor});
		document.body.appendChild(element);
		await Promise.resolve();
		await Promise.resolve();
		document.body.removeChild(element);

		const lateSubscription = {id: 'late-subscription'};
		resolveSubscribe(lateSubscription);
		await Promise.resolve();
		await Promise.resolve();

		expect(unsubscribe).toHaveBeenCalledWith(lateSubscription);
	});

	it('should not start a second subscription when the component reconnects during prefix resolution', async() =>
	{
		let resolveFirstPrefix;
		getNamespacePrefix.mockReturnValueOnce(new Promise((resolve) =>
		{
			resolveFirstPrefix = resolve;
		}));
		subscribe.mockResolvedValueOnce({id: 'live-subscription'});
		const element = createElement('c-chain-monitor', {is: ChainMonitor});
		document.body.appendChild(element);
		document.body.removeChild(element);
		document.body.appendChild(element);
		await Promise.resolve();
		await Promise.resolve();
		expect(subscribe).toHaveBeenCalledTimes(1);

		// The first connection's subscribe run resumes while the component is connected again; a
		// stale run must stand down instead of registering a second, orphaned subscription.
		resolveFirstPrefix('kern__');
		await Promise.resolve();
		await Promise.resolve();

		expect(subscribe).toHaveBeenCalledTimes(1);

		document.body.removeChild(element);
		expect(unsubscribe).toHaveBeenCalledWith({id: 'live-subscription'});
	});

	it('should release a stale subscription that resolves after the component reconnects', async() =>
	{
		let resolveFirstSubscribe;
		subscribe.mockReturnValueOnce(new Promise((resolve) =>
		{
			resolveFirstSubscribe = resolve;
		}));
		subscribe.mockResolvedValueOnce({id: 'second-subscription'});
		const element = createElement('c-chain-monitor', {is: ChainMonitor});
		document.body.appendChild(element);
		await Promise.resolve();
		await Promise.resolve();
		expect(subscribe).toHaveBeenCalledTimes(1);
		document.body.removeChild(element);
		document.body.appendChild(element);
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();

		const staleSubscription = {id: 'first-subscription'};
		resolveFirstSubscribe(staleSubscription);
		await Promise.resolve();
		await Promise.resolve();

		expect(unsubscribe).toHaveBeenCalledWith(staleSubscription);

		unsubscribe.mockClear();
		document.body.removeChild(element);
		expect(unsubscribe).toHaveBeenCalledWith({id: 'second-subscription'});
	});

	it('should log the failure through consoleError when the subscription cannot be established', async() =>
	{
		const failure = new Error('403::Handshake denied');
		subscribe.mockRejectedValueOnce(failure);
		const element = createElement('c-chain-monitor', {is: ChainMonitor});
		document.body.appendChild(element);
		await Promise.resolve();
		await Promise.resolve();
		await Promise.resolve();

		expect(mockConsoleError).toHaveBeenCalledWith(failure, 'ChainMonitor.subscribeToEvents');
	});

	it('should handle subscribe failure gracefully', async() =>
	{
		subscribe.mockRejectedValueOnce(new Error('403:denied_by_security_policy'));
		const element = createElement('c-chain-monitor', {is: ChainMonitor});
		document.body.appendChild(element);
		await Promise.resolve();
		await Promise.resolve();

		const list = element.shadowRoot.querySelector('c-chain-monitor-list');
		expect(list).toBeTruthy();
	});

	it('should handle streaming event without recordId gracefully', async() =>
	{
		await createComponent();

		const streamingCallback = subscribe.mock.calls[0][2];
		expect(() => streamingCallback({data: {payload: {}}})).not.toThrow();
		expect(() => streamingCallback({data: {}})).not.toThrow();
		expect(() => streamingCallback({})).not.toThrow();
	});

	// The container hosts the real chainMonitorList child, whose loadData also calls the
	// controller mock — deep-link assertions therefore filter to calls carrying correlationId.
	function getResolveCalls()
	{
		return mockCallControllerMethod.mock.calls.filter((call) => call[1] && 'correlationId' in call[1]);
	}

	function stubResolveResult(executionId)
	{
		mockCallControllerMethod.mockImplementation((controller, params) =>
		{
			if(typeof controller === 'function')
			{
				controller(params);
			}
			return Promise.resolve(params && 'correlationId' in params ? executionId : {});
		});
	}

	it('should select the deep-linked chain when the correlation resolves', async() =>
	{
		stubResolveResult('resolved-chain-id');
		const element = await createComponent();
		const list = element.shadowRoot.querySelector('c-chain-monitor-list');
		const selectById = jest.fn();
		list.selectById = selectById;

		CurrentPageReference.emit({state: {c__correlationId: 'corr-9'}});
		await Promise.resolve();
		await Promise.resolve();

		expect(getResolveCalls()).toEqual([
			[
				expect.anything(),
				{correlationId: 'corr-9'}
			]
		]);
		const detail = element.shadowRoot.querySelector('c-chain-monitor-detail');
		expect(detail.executionId).toBe('resolved-chain-id');
		expect(selectById).toHaveBeenCalledWith('resolved-chain-id');
	});

	it('should leave the default selection when the correlation resolves to no chain', async() =>
	{
		stubResolveResult(null);
		const element = await createComponent();
		const list = element.shadowRoot.querySelector('c-chain-monitor-list');
		const selectById = jest.fn();
		list.selectById = selectById;

		CurrentPageReference.emit({state: {c__correlationId: 'corr-unknown'}});
		await Promise.resolve();
		await Promise.resolve();

		const detail = element.shadowRoot.querySelector('c-chain-monitor-detail');
		expect(detail.executionId).toBeNull();
		expect(selectById).not.toHaveBeenCalled();
	});

	it('should resolve a repeated correlation only once', async() =>
	{
		stubResolveResult('resolved-chain-id');
		await createComponent();

		CurrentPageReference.emit({state: {c__correlationId: 'corr-9'}});
		await Promise.resolve();
		CurrentPageReference.emit({state: {c__correlationId: 'corr-9'}});
		await Promise.resolve();

		expect(getResolveCalls()).toHaveLength(1);
	});

	it('should ignore page references without a correlation', async() =>
	{
		await createComponent();

		CurrentPageReference.emit({state: {}});
		CurrentPageReference.emit({});
		await Promise.resolve();

		expect(getResolveCalls()).toHaveLength(0);
	});

	it('should keep the deep-linked chain when the list reconciles without it', async() =>
	{
		const offPagePayload = {
			records: [{executionId: 'other-1', chainName: 'Other', status: 'Running', completedSteps: 0, totalSteps: 1}],
			totalCount: 21,
			pageNumber: 1,
			totalPages: 2,
			hasMorePages: true
		};
		mockCallControllerMethod.mockImplementation((controller, params) =>
		{
			if(typeof controller === 'function')
			{
				controller(params);
			}
			return Promise.resolve(params && 'correlationId' in params ? 'off-page-chain-id' : offPagePayload);
		});
		const element = await createComponent();
		const list = element.shadowRoot.querySelector('c-chain-monitor-list');

		CurrentPageReference.emit({state: {c__correlationId: 'corr-off-page'}});
		await Promise.resolve();
		await Promise.resolve();
		await list.refresh();
		await Promise.resolve();

		const detail = element.shadowRoot.querySelector('c-chain-monitor-detail');
		expect(detail.executionId).toBe('off-page-chain-id');
	});

	it('should not stomp a selection the user made during the resolve', async() =>
	{
		let resolveDeepLink;
		mockCallControllerMethod.mockImplementation((controller, params) =>
		{
			if(typeof controller === 'function')
			{
				controller(params);
			}
			if(params && 'correlationId' in params)
			{
				return new Promise((resolve) =>
				{
					resolveDeepLink = resolve;
				});
			}
			return Promise.resolve({});
		});
		const element = await createComponent();
		const list = element.shadowRoot.querySelector('c-chain-monitor-list');
		const selectById = jest.fn();
		list.selectById = selectById;

		CurrentPageReference.emit({state: {c__correlationId: 'corr-slow'}});
		await Promise.resolve();
		list.dispatchEvent(new CustomEvent('select', {detail: {executionId: 'user-pick', isUserSelection: true}}));
		await Promise.resolve();
		resolveDeepLink('late-chain-id');
		await Promise.resolve();
		await Promise.resolve();

		const detail = element.shadowRoot.querySelector('c-chain-monitor-detail');
		expect(detail.executionId).toBe('user-pick');
		expect(selectById).not.toHaveBeenCalled();
	});
});
