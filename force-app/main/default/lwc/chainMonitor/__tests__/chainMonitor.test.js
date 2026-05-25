// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for chainMonitor container LWC component
 * @author Jason van Beukering
 * @date April 2026, May 2026
 */

import {createElement} from 'lwc';
import ChainMonitor from 'c/chainMonitor';
import {subscribe, unsubscribe} from 'lightning/empApi';

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
});
