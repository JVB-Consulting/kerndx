// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) Philippe Ozil (CC0-1.0 — rights waived)
// Adapted from streaming-monitor (https://github.com/pozil/streaming-monitor)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description Jest unit tests for streamingSidebar LWC component
 * @author Jason van Beukering
 * @date December 2025, May 2026
 */

import {createElement} from 'lwc';
import LwcSidebar from 'c/streamingSidebar';

jest.mock('@salesforce/label/c.StreamingSidebar_ToggleTitle', () => ({default: 'Toggle sidebar'}), {virtual: true});

describe('c-streaming-sidebar', () =>
{
	let element;

	beforeEach(() =>
	{
		element = createElement('c-streaming-sidebar', {
			is: LwcSidebar
		});
		document.body.appendChild(element);
	});

	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
	});

	describe('initial state', () =>
	{
		it('should render component successfully', () =>
		{
			expect(element).toBeTruthy();
		});

		it('should have sidebar visible by default (article not hidden)', () =>
		{
			const article = element.shadowRoot.querySelector('article');
			expect(article.getAttribute('aria-hidden')).toBe('false');
		});

		it('should have selectedItem default to monitor', () =>
		{
			expect(element.selectedItem).toBe('monitor');
		});

		it('should have split view container with open class', () =>
		{
			const container = element.shadowRoot.querySelector('.slds-split-view_container');
			expect(container.classList.contains('slds-is-open')).toBe(true);
		});

		it('should have toggle button with open class', () =>
		{
			const button = element.shadowRoot.querySelector('button');
			expect(button.classList.contains('slds-is-open')).toBe(true);
		});
	});

	describe('selectedItem @api property', () =>
	{
		it('should accept custom selectedItem value', async() =>
		{
			element.selectedItem = 'subscriptions';

			await Promise.resolve(); // Wait for re-render

			const navigation = element.shadowRoot.querySelector('lightning-vertical-navigation');
			expect(navigation.selectedItem).toBe('subscriptions');
		});
	});

	describe('toggle button click (handleToggleSidebar)', () =>
	{
		it('should toggle sidebar visibility when button is clicked', async() =>
		{
			const button = element.shadowRoot.querySelector('button');
			button.click();

			await Promise.resolve();

			const article = element.shadowRoot.querySelector('article');
			expect(article.getAttribute('aria-hidden')).toBe('true');
		});

		it('should toggle back to visible on second click', async() =>
		{
			const button = element.shadowRoot.querySelector('button');
			button.click(); // First click: visible -> hidden

			await Promise.resolve();

			button.click(); // Second click: hidden -> visible

			await Promise.resolve();

			const article = element.shadowRoot.querySelector('article');
			expect(article.getAttribute('aria-hidden')).toBe('false');
		});

		it('should dispatch toggle event with false when hiding', async() =>
		{
			const toggleHandler = jest.fn();
			element.addEventListener('toggle', toggleHandler);

			const button = element.shadowRoot.querySelector('button');
			button.click();

			await Promise.resolve();

			expect(toggleHandler).toHaveBeenCalledTimes(1);
			expect(toggleHandler.mock.calls[0][0].detail).toBe(false);
		});

		it('should dispatch toggle event with true when showing', async() =>
		{
			const toggleHandler = jest.fn();
			element.addEventListener('toggle', toggleHandler);

			const button = element.shadowRoot.querySelector('button');
			button.click(); // Hide
			await Promise.resolve();

			button.click(); // Show
			await Promise.resolve();

			expect(toggleHandler).toHaveBeenCalledTimes(2);
			expect(toggleHandler.mock.calls[1][0].detail).toBe(true);
		});

		it('should update container classes to closed when toggled', async() =>
		{
			const button = element.shadowRoot.querySelector('button');
			button.click();

			await Promise.resolve();

			const container = element.shadowRoot.querySelector('.slds-split-view_container');
			expect(container.classList.contains('slds-is-closed')).toBe(true);
			expect(container.classList.contains('slds-is-open')).toBe(false);
		});

		it('should update toggle button classes to closed when toggled', async() =>
		{
			const button = element.shadowRoot.querySelector('button');
			button.click();

			await Promise.resolve();

			expect(button.classList.contains('slds-is-closed')).toBe(true);
			expect(button.classList.contains('slds-is-open')).toBe(false);
		});
	});

	describe('navigation select (handleMenuSelect)', () =>
	{
		it('should dispatch navigate event when selecting different item', async() =>
		{
			const navigateHandler = jest.fn();
			element.addEventListener('navigate', navigateHandler);

			const navigation = element.shadowRoot.querySelector('lightning-vertical-navigation');
			navigation.dispatchEvent(new CustomEvent('select', {
				detail: {name: 'subscriptions'}
			}));

			await Promise.resolve();

			expect(navigateHandler).toHaveBeenCalledTimes(1);
			expect(navigateHandler.mock.calls[0][0].detail).toBe('subscriptions');
		});

		it('should not dispatch navigate event when selecting same item twice', async() =>
		{
			const navigateHandler = jest.fn();
			element.addEventListener('navigate', navigateHandler);

			const navigation = element.shadowRoot.querySelector('lightning-vertical-navigation');

			navigation.dispatchEvent(new CustomEvent('select', {
				detail: {name: 'monitor'}
			}));
			await Promise.resolve();

			navigation.dispatchEvent(new CustomEvent('select', {
				detail: {name: 'monitor'}
			}));
			await Promise.resolve();

			expect(navigateHandler).toHaveBeenCalledTimes(1);
		});

		it('should dispatch navigate for each different selection', async() =>
		{
			const navigateHandler = jest.fn();
			element.addEventListener('navigate', navigateHandler);

			const navigation = element.shadowRoot.querySelector('lightning-vertical-navigation');

			navigation.dispatchEvent(new CustomEvent('select', {detail: {name: 'monitor'}}));
			await Promise.resolve();

			navigation.dispatchEvent(new CustomEvent('select', {detail: {name: 'subscribe'}}));
			await Promise.resolve();

			navigation.dispatchEvent(new CustomEvent('select', {detail: {name: 'publish'}}));
			await Promise.resolve();

			expect(navigateHandler).toHaveBeenCalledTimes(3);
			expect(navigateHandler.mock.calls[0][0].detail).toBe('monitor');
			expect(navigateHandler.mock.calls[1][0].detail).toBe('subscribe');
			expect(navigateHandler.mock.calls[2][0].detail).toBe('publish');
		});
	});

	describe('DOM structure', () =>
	{
		it('should render lightning-vertical-navigation', () =>
		{
			const navigation = element.shadowRoot.querySelector('lightning-vertical-navigation');
			expect(navigation).toBeTruthy();
		});

		it('should render toggle button with correct title', () =>
		{
			const button = element.shadowRoot.querySelector('button');
			expect(button.title).toBe('Toggle sidebar');
		});

		it('should render slot for content', () =>
		{
			const slot = element.shadowRoot.querySelector('slot');
			expect(slot).toBeTruthy();
		});
	});
});
