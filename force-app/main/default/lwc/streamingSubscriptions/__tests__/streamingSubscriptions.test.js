// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) Philippe Ozil (CC0-1.0 — rights waived)
// Adapted from streaming-monitor (https://github.com/pozil/streaming-monitor)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description Jest unit tests for streamingSubscriptions LWC component
 * @author Jason van Beukering
 * @date December 2025, May 2026
 */

import {createElement} from 'lwc';
import LwcSubscriptions from 'c/streamingSubscriptions';

jest.mock('@salesforce/label/c.EventMonitor_Subscriptions_Heading', () => ({default: 'Subscriptions'}), {virtual: true});

describe('c-streaming-subscriptions', () =>
{
	let element;

	beforeEach(() =>
	{
		element = createElement('c-streaming-subscriptions', {
			is: LwcSubscriptions
		});
	});

	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
	});

	/**
	 * Helper to create component with subscriptions
	 */
	async function createComponent(subscriptions = [])
	{
		element.subscriptions = subscriptions;
		document.body.appendChild(element);
		await Promise.resolve();
		return element;
	}

	/**
	 * Helper to find button icon by icon name
	 */
	function findButtonByIcon(root, iconName)
	{
		const buttons = root.querySelectorAll('lightning-button-icon');
		for(const button of buttons)
		{
			if(button.iconName === iconName)
			{
				return button;
			}
		}
		return null;
	}

	describe('initial rendering', () =>
	{
		it('should render component successfully', async() =>
		{
			await createComponent([]);

			expect(element).toBeTruthy();
		});

		it('should render subscriptions title', async() =>
		{
			await createComponent([]);

			const title = element.shadowRoot.querySelector('h2');
			expect(title.textContent).toBe('Subscriptions');
		});

		it('should render unsubscribe all button', async() =>
		{
			await createComponent([]);

			const deleteButton = findButtonByIcon(element.shadowRoot, 'utility:delete');
			expect(deleteButton).toBeTruthy();
			expect(deleteButton.alternativeText).toBe('Unsubscribe all');
		});
	});

	describe('@api subscriptions', () =>
	{
		it('should display subscription count in badge', async() =>
		{
			await createComponent([
				{channel: 'channel1'},
				{channel: 'channel2'},
				{channel: 'channel3'}
			]);

			const badge = element.shadowRoot.querySelector('lightning-badge');
			expect(badge.label).toBe(3);
		});

		it('should display zero count when no subscriptions', async() =>
		{
			await createComponent([]);

			const badge = element.shadowRoot.querySelector('lightning-badge');
			expect(badge.label).toBe(0);
		});

		it('should render subscription items for each subscription', async() =>
		{
			await createComponent([
				{channel: '/event/MyEvent__e'},
				{channel: '/event/OtherEvent__e'}
			]);

			const subscriptionDivs = element.shadowRoot.querySelectorAll('.subscription');
			expect(subscriptionDivs.length).toBe(2);
		});

		it('should display channel name for each subscription', async() =>
		{
			await createComponent([
				{channel: '/event/TestChannel__e'}
			]);

			const channelText = element.shadowRoot.querySelector('.slds-truncate');
			expect(channelText.textContent).toBe('/event/TestChannel__e');
		});

		it('should render unsubscribe button for each subscription', async() =>
		{
			await createComponent([
				{channel: 'channel1'},
				{channel: 'channel2'}
			]);

			const closeButtons = findAllButtonsByIcon(element.shadowRoot, 'utility:close');
			expect(closeButtons.length).toBe(2);
		});
	});

	/**
	 * Helper to find all button icons by icon name
	 */
	function findAllButtonsByIcon(root, iconName)
	{
		const buttons = root.querySelectorAll('lightning-button-icon');
		const result = [];
		for(const button of buttons)
		{
			if(button.iconName === iconName)
			{
				result.push(button);
			}
		}
		return result;
	}

	describe('subscriptionCount getter', () =>
	{
		it('should return correct count for multiple subscriptions via badge', async() =>
		{
			await createComponent([
				{channel: 'a'},
				{channel: 'b'},
				{channel: 'c'},
				{channel: 'd'}
			]);

			const badge = element.shadowRoot.querySelector('lightning-badge');
			expect(badge.label).toBe(4);
		});

		it('should return zero for empty array via badge', async() =>
		{
			await createComponent([]);

			const badge = element.shadowRoot.querySelector('lightning-badge');
			expect(badge.label).toBe(0);
		});

		it('should update count when subscriptions change', async() =>
		{
			await createComponent([{channel: 'a'}]);
			expect(element.shadowRoot.querySelector('lightning-badge').label).toBe(1);

			element.subscriptions = [
				{channel: 'a'},
				{channel: 'b'}
			];
			await Promise.resolve();
			expect(element.shadowRoot.querySelector('lightning-badge').label).toBe(2);
		});
	});

	describe('handleUnsubscribe', () =>
	{
		it('should dispatch unsubscribe event when close button clicked', async() =>
		{
			await createComponent([
				{channel: '/event/MyChannel__e'}
			]);

			const unsubscribeHandler = jest.fn();
			element.addEventListener('unsubscribe', unsubscribeHandler);

			const closeButton = findButtonByIcon(element.shadowRoot, 'utility:close');
			closeButton.click();
			await Promise.resolve();

			expect(unsubscribeHandler).toHaveBeenCalledTimes(1);
		});

		it('should include channel name in unsubscribe event detail', async() =>
		{
			await createComponent([
				{channel: '/event/SpecificChannel__e'}
			]);

			const unsubscribeHandler = jest.fn();
			element.addEventListener('unsubscribe', unsubscribeHandler);

			const closeButton = findButtonByIcon(element.shadowRoot, 'utility:close');
			closeButton.click();
			await Promise.resolve();

			expect(unsubscribeHandler.mock.calls[0][0].detail).toEqual({
				channel: '/event/SpecificChannel__e'
			});
		});

		it('should dispatch correct channel when multiple subscriptions', async() =>
		{
			await createComponent([
				{channel: 'channel1'},
				{channel: 'channel2'},
				{channel: 'channel3'}
			]);

			const unsubscribeHandler = jest.fn();
			element.addEventListener('unsubscribe', unsubscribeHandler);

			// Click the second subscription's close button
			const closeButtons = findAllButtonsByIcon(element.shadowRoot, 'utility:close');
			closeButtons[1].click();
			await Promise.resolve();

			expect(unsubscribeHandler.mock.calls[0][0].detail.channel).toBe('channel2');
		});
	});

	describe('handleUnsubscribeAll', () =>
	{
		it('should dispatch unsubscribeall event when delete all button clicked', async() =>
		{
			await createComponent([
				{channel: 'channel1'},
				{channel: 'channel2'}
			]);

			const unsubscribeAllHandler = jest.fn();
			element.addEventListener('unsubscribeall', unsubscribeAllHandler);

			const deleteButton = findButtonByIcon(element.shadowRoot, 'utility:delete');
			deleteButton.click();
			await Promise.resolve();

			expect(unsubscribeAllHandler).toHaveBeenCalledTimes(1);
		});

		it('should dispatch unsubscribeall event even with empty subscriptions', async() =>
		{
			await createComponent([]);

			const unsubscribeAllHandler = jest.fn();
			element.addEventListener('unsubscribeall', unsubscribeAllHandler);

			const deleteButton = findButtonByIcon(element.shadowRoot, 'utility:delete');
			deleteButton.click();
			await Promise.resolve();

			expect(unsubscribeAllHandler).toHaveBeenCalledTimes(1);
		});
	});

	describe('DOM structure', () =>
	{
		it('should have grid layout for header', async() =>
		{
			await createComponent([]);

			const headerGrid = element.shadowRoot.querySelector('.slds-grid');
			expect(headerGrid).toBeTruthy();
			expect(headerGrid.classList.contains('slds-grid_align-spread')).toBe(true);
		});

		it('should have subscription class on each subscription item', async() =>
		{
			await createComponent([{channel: 'test'}]);

			const subscription = element.shadowRoot.querySelector('.subscription');
			expect(subscription).toBeTruthy();
		});

		it('should have truncate class on channel text', async() =>
		{
			await createComponent([{channel: 'test'}]);

			const truncate = element.shadowRoot.querySelector('.slds-truncate');
			expect(truncate).toBeTruthy();
		});
	});
});
