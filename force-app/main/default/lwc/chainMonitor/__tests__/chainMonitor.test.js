// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for chainMonitor container LWC component
 * @author Jason van Beukering
 * @date April 2026, May 2026, July 2026
 */

import {createElement} from 'lwc';
import ChainMonitor from 'c/chainMonitor';
import {subscribe, unsubscribe} from 'lightning/empApi';
import {CurrentPageReference} from 'lightning/navigation';
import {mockCallControllerMethod} from 'c/componentBuilder';

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

	it('should refresh list when streaming event received with recordId', async() =>
	{
		const element = await createComponent();
		const list = element.shadowRoot.querySelector('c-chain-monitor-list');
		const detail = element.shadowRoot.querySelector('c-chain-monitor-detail');
		const listRefresh = jest.fn();
		const detailRefresh = jest.fn();
		list.refresh = listRefresh;
		detail.refresh = detailRefresh;

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

		expect(getResolveCalls()).toEqual([[expect.anything(), {correlationId: 'corr-9'}]]);
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
			totalCount: 21, pageNumber: 1, totalPages: 2, hasMorePages: true
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
				return new Promise((resolve) => { resolveDeepLink = resolve; });
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
