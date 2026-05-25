// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) Philippe Ozil (CC0-1.0 — rights waived)
// Adapted from streaming-monitor (https://github.com/pozil/streaming-monitor)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description Jest unit tests for streamingEventsHeader LWC component
 * @author Jason van Beukering
 * @date December 2025, May 2026
 */

import {createElement} from 'lwc';
import LwcEventsHeaderControls from 'c/streamingEventsHeader';

describe('c-streaming-events-header', () =>
{
	let element;

	beforeEach(() =>
	{
		element = createElement('c-streaming-events-header', {
			is: LwcEventsHeaderControls
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

	describe('initial rendering', () =>
	{
		it('should render component successfully', () =>
		{
			expect(element).toBeTruthy();
		});

		it('should render button group', () =>
		{
			const buttonGroup = element.shadowRoot.querySelector('lightning-button-group');
			expect(buttonGroup).toBeTruthy();
		});

		it('should render clear button with delete icon', async() =>
		{
			await Promise.resolve();

			const clearButton = element.shadowRoot.querySelector('lightning-button');
			expect(clearButton).toBeTruthy();
			expect(clearButton.label).toBe('Clear events');
			expect(clearButton.iconName).toBe('utility:delete');
		});

		it('should render filter toggle button with filterList icon', async() =>
		{
			await Promise.resolve();

			const filterButton = element.shadowRoot.querySelector('lightning-button-icon-stateful');
			expect(filterButton).toBeTruthy();
			expect(filterButton.iconName).toBe('utility:filterList');
		});

		it('should render view mode menu with table icon initially', async() =>
		{
			await Promise.resolve();

			const viewModeMenu = element.shadowRoot.querySelector('lightning-button-menu');
			expect(viewModeMenu).toBeTruthy();
			expect(viewModeMenu.iconName).toBe('utility:table');
		});

		it('should render download button', async() =>
		{
			await Promise.resolve();

			const buttons = element.shadowRoot.querySelectorAll('lightning-button-icon');
			const downloadButton = Array.from(buttons).find(btn => btn.iconName === 'utility:download');
			expect(downloadButton).toBeTruthy();
			expect(downloadButton.alternativeText).toBe('Download events data');
		});

		it('should have filters displayed by default', async() =>
		{
			await Promise.resolve();

			const filterButton = element.shadowRoot.querySelector('lightning-button-icon-stateful');
			expect(filterButton.selected).toBe(true);
		});

		it('should render menu items for view modes', async() =>
		{
			await Promise.resolve();

			const menuItems = element.shadowRoot.querySelectorAll('lightning-menu-item');
			expect(menuItems.length).toBe(2);
		});
	});

	describe('handleClear', () =>
	{
		it('should dispatch clear event when clear button clicked', async() =>
		{
			await Promise.resolve();

			const clearHandler = jest.fn();
			element.addEventListener('clear', clearHandler);

			const clearButton = element.shadowRoot.querySelector('lightning-button');
			clearButton.click();
			await Promise.resolve();

			expect(clearHandler).toHaveBeenCalledTimes(1);
		});
	});

	describe('handleDownload', () =>
	{
		it('should dispatch download event when download button clicked', async() =>
		{
			await Promise.resolve();

			const downloadHandler = jest.fn();
			element.addEventListener('download', downloadHandler);

			const buttons = element.shadowRoot.querySelectorAll('lightning-button-icon');
			const downloadButton = Array.from(buttons).find(btn => btn.iconName === 'utility:download');
			downloadButton.click();
			await Promise.resolve();

			expect(downloadHandler).toHaveBeenCalledTimes(1);
		});
	});

	describe('handleFiltersDisplayToggle', () =>
	{
		it('should dispatch filtertoggle event when filter button clicked', async() =>
		{
			await Promise.resolve();

			const filterToggleHandler = jest.fn();
			element.addEventListener('filtertoggle', filterToggleHandler);

			const filterButton = element.shadowRoot.querySelector('lightning-button-icon-stateful');
			filterButton.click();
			await Promise.resolve();

			expect(filterToggleHandler).toHaveBeenCalledTimes(1);
		});

		it('should dispatch event with false when toggling from true', async() =>
		{
			await Promise.resolve();

			const filterToggleHandler = jest.fn();
			element.addEventListener('filtertoggle', filterToggleHandler);

			const filterButton = element.shadowRoot.querySelector('lightning-button-icon-stateful');
			filterButton.click();
			await Promise.resolve();

			expect(filterToggleHandler.mock.calls[0][0].detail.value).toBe(false);
		});

		it('should dispatch event with true when toggling from false', async() =>
		{
			await Promise.resolve();

			const filterToggleHandler = jest.fn();
			element.addEventListener('filtertoggle', filterToggleHandler);

			const filterButton = element.shadowRoot.querySelector('lightning-button-icon-stateful');
			filterButton.click(); // false
			await Promise.resolve();
			filterButton.click(); // true
			await Promise.resolve();

			expect(filterToggleHandler.mock.calls[1][0].detail.value).toBe(true);
		});

		it('should update selected state on toggle', async() =>
		{
			await Promise.resolve();

			const filterButton = element.shadowRoot.querySelector('lightning-button-icon-stateful');
			expect(filterButton.selected).toBe(true);

			filterButton.click();
			await Promise.resolve();

			expect(filterButton.selected).toBe(false);
		});
	});

	describe('handleViewModeSelect', () =>
	{
		it('should dispatch viewmodechange event when menu item selected', async() =>
		{
			await Promise.resolve();

			const viewModeHandler = jest.fn();
			element.addEventListener('viewmodechange', viewModeHandler);

			const menu = element.shadowRoot.querySelector('lightning-button-menu');
			menu.dispatchEvent(new CustomEvent('select', {
				detail: {value: 'timeline'}
			}));
			await Promise.resolve();

			expect(viewModeHandler).toHaveBeenCalledTimes(1);
		});

		it('should include selected value in event detail', async() =>
		{
			await Promise.resolve();

			const viewModeHandler = jest.fn();
			element.addEventListener('viewmodechange', viewModeHandler);

			const menu = element.shadowRoot.querySelector('lightning-button-menu');
			menu.dispatchEvent(new CustomEvent('select', {
				detail: {value: 'timeline'}
			}));
			await Promise.resolve();

			expect(viewModeHandler.mock.calls[0][0].detail.value).toBe('timeline');
		});

		it('should update menu icon when timeline selected', async() =>
		{
			await Promise.resolve();

			const menu = element.shadowRoot.querySelector('lightning-button-menu');
			menu.dispatchEvent(new CustomEvent('select', {
				detail: {value: 'timeline'}
			}));
			await Promise.resolve();

			expect(menu.iconName).toBe('utility:metrics');
		});

		it('should update menu icon when table selected', async() =>
		{
			await Promise.resolve();

			const menu = element.shadowRoot.querySelector('lightning-button-menu');

			// First select timeline
			menu.dispatchEvent(new CustomEvent('select', {
				detail: {value: 'timeline'}
			}));
			await Promise.resolve();

			// Then select table
			menu.dispatchEvent(new CustomEvent('select', {
				detail: {value: 'table'}
			}));
			await Promise.resolve();

			expect(menu.iconName).toBe('utility:table');
		});
	});

	describe('viewModeIconName getter', () =>
	{
		it('should return table icon for default view mode', async() =>
		{
			await Promise.resolve();

			const menu = element.shadowRoot.querySelector('lightning-button-menu');
			expect(menu.iconName).toBe('utility:table');
		});

		it('should return metrics icon when timeline mode is active', async() =>
		{
			await Promise.resolve();

			const menu = element.shadowRoot.querySelector('lightning-button-menu');
			menu.dispatchEvent(new CustomEvent('select', {
				detail: {value: 'timeline'}
			}));
			await Promise.resolve();

			expect(menu.iconName).toBe('utility:metrics');
		});
	});

	describe('view modes menu structure', () =>
	{
		it('should have Display as subheader', async() =>
		{
			await Promise.resolve();

			const subheader = element.shadowRoot.querySelector('lightning-menu-subheader');
			expect(subheader).toBeTruthy();
			expect(subheader.label).toBe('Display as');
		});

		it('should have Table menu item', async() =>
		{
			await Promise.resolve();

			const menuItems = element.shadowRoot.querySelectorAll('lightning-menu-item');
			const tableItem = Array.from(menuItems).find(item => item.value === 'table');
			expect(tableItem).toBeTruthy();
			expect(tableItem.label).toBe('Table');
			expect(tableItem.iconName).toBe('utility:table');
		});

		it('should have Timeline menu item', async() =>
		{
			await Promise.resolve();

			const menuItems = element.shadowRoot.querySelectorAll('lightning-menu-item');
			const timelineItem = Array.from(menuItems).find(item => item.value === 'timeline');
			expect(timelineItem).toBeTruthy();
			expect(timelineItem.label).toBe('Timeline');
			expect(timelineItem.iconName).toBe('utility:metrics');
		});
	});
});
