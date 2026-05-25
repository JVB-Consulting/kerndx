// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) Philippe Ozil (CC0-1.0 — rights waived)
// Adapted from streaming-monitor (https://github.com/pozil/streaming-monitor)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description Jest unit tests for streamingUsageFilters LWC component
 * @author Jason van Beukering
 * @date December 2025, May 2026
 */

import {createElement} from 'lwc';
import LwcEventUsageMetricsFilters from 'c/streamingUsageFilters';

describe('streamingUsageFilters', () =>
{
	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
		jest.clearAllMocks();
	});

	/**
	 * @description Helper to find lightning-input by label
	 * @param {Element} root
	 * @param {string} label
	 * @returns {Element|null}
	 */
	function findInputByLabel(root, label)
	{
		const inputs = root.querySelectorAll('lightning-input');
		for(const input of inputs)
		{
			if(input.label === label)
			{
				return input;
			}
		}
		return null;
	}

	/**
	 * @description Simulate toggle change event
	 * @param {Element} toggleInput
	 * @param {boolean} checked
	 */
	function simulateToggle(toggleInput, checked)
	{
		// Mock the target.checked for the handler
		Object.defineProperty(toggleInput, 'checked', {value: checked, writable: true});
		toggleInput.dispatchEvent(new CustomEvent('change', {
			bubbles: true, composed: true
		}));
	}

	/**
	 * @description Simulate datetime change event
	 * @param {Element} datetimeInput
	 * @param {string} value
	 */
	function simulateDatetimeChange(datetimeInput, value)
	{
		datetimeInput.dispatchEvent(new CustomEvent('change', {
			bubbles: true, composed: true, detail: {value}
		}));
	}

	describe('connectedCallback', () =>
	{
		it('should initialize beforeTime to current top-of-hour', async() =>
		{
			const element = createElement('c-streaming-usage-filters', {
				is: LwcEventUsageMetricsFilters
			});
			document.body.appendChild(element);
			await Promise.resolve();

			// beforeTime should be set to current hour (minutes = 0)
			const beforeTimeInput = findInputByLabel(element.shadowRoot, 'Before time');
			expect(beforeTimeInput.value).toBeDefined();
			const beforeDate = new Date(beforeTimeInput.value);
			expect(beforeDate.getMinutes()).toBe(0);
		});

		it('should initialize afterTime to 24 hours before beforeTime', async() =>
		{
			const element = createElement('c-streaming-usage-filters', {
				is: LwcEventUsageMetricsFilters
			});
			document.body.appendChild(element);
			await Promise.resolve();

			const beforeTimeInput = findInputByLabel(element.shadowRoot, 'Before time');
			const afterTimeInput = findInputByLabel(element.shadowRoot, 'After time');

			const beforeDate = new Date(beforeTimeInput.value);
			const afterDate = new Date(afterTimeInput.value);

			// afterTime should be exactly 24 hours before beforeTime
			const diffMs = beforeDate.getTime() - afterDate.getTime();
			expect(diffMs).toBe(24 * 60 * 60 * 1000);
		});

		it('should start with both time toggles unchecked', async() =>
		{
			const element = createElement('c-streaming-usage-filters', {
				is: LwcEventUsageMetricsFilters
			});
			document.body.appendChild(element);
			await Promise.resolve();

			const afterToggle = findInputByLabel(element.shadowRoot, 'Include events after');
			const beforeToggle = findInputByLabel(element.shadowRoot, 'Include events before');

			expect(afterToggle.checked).toBeFalsy();
			expect(beforeToggle.checked).toBeFalsy();
		});
	});

	describe('eventTypes API', () =>
	{
		it('should transform event types with style and checked=true', async() =>
		{
			const element = createElement('c-streaming-usage-filters', {
				is: LwcEventUsageMetricsFilters
			});
			document.body.appendChild(element);

			element.eventTypes = [
				{label: 'Type A', value: 'type_a', color: '#FF0000', index: 0},
				{label: 'Type B', value: 'type_b', color: '#00FF00', index: 1}
			];
			await Promise.resolve();

			// Check that event type toggles are rendered
			const eventTypeToggles = element.shadowRoot.querySelectorAll('.event-type lightning-input');
			expect(eventTypeToggles.length).toBe(2);
			expect(eventTypeToggles[0].label).toBe('Type A');
			expect(eventTypeToggles[0].checked).toBe(true);
			expect(eventTypeToggles[1].label).toBe('Type B');
			expect(eventTypeToggles[1].checked).toBe(true);
		});

		it('should apply color as background-color style', async() =>
		{
			const element = createElement('c-streaming-usage-filters', {
				is: LwcEventUsageMetricsFilters
			});
			document.body.appendChild(element);

			element.eventTypes = [{label: 'Test', value: 'test', color: '#123456', index: 0}];
			await Promise.resolve();

			const colorDot = element.shadowRoot.querySelector('.dot');
			expect(colorDot.style.cssText).toContain('background-color');
		});

		it('should return eventTypeOptions from getter', async() =>
		{
			const element = createElement('c-streaming-usage-filters', {
				is: LwcEventUsageMetricsFilters
			});
			document.body.appendChild(element);

			element.eventTypes = [{label: 'Test', value: 'test', color: '#123456', index: 0}];
			await Promise.resolve();

			const result = element.eventTypes;
			expect(result.length).toBe(1);
			expect(result[0].label).toBe('Test');
			expect(result[0].checked).toBe(true);
			expect(result[0].style).toBe('background-color: #123456;');
		});
	});

	describe('time toggle handlers', () =>
	{
		it('should enable afterTime filter when toggle is checked', async() =>
		{
			const element = createElement('c-streaming-usage-filters', {
				is: LwcEventUsageMetricsFilters
			});

			const filterChangeHandler = jest.fn();
			element.addEventListener('filterchange', filterChangeHandler);
			document.body.appendChild(element);
			await Promise.resolve();

			const afterToggle = findInputByLabel(element.shadowRoot, 'Include events after');
			simulateToggle(afterToggle, true);
			await Promise.resolve();

			expect(filterChangeHandler).toHaveBeenCalled();
			const detail = filterChangeHandler.mock.calls[0][0].detail;
			expect(detail.afterTime).toBeDefined();
		});

		it('should enable beforeTime filter when toggle is checked', async() =>
		{
			const element = createElement('c-streaming-usage-filters', {
				is: LwcEventUsageMetricsFilters
			});

			const filterChangeHandler = jest.fn();
			element.addEventListener('filterchange', filterChangeHandler);
			document.body.appendChild(element);
			await Promise.resolve();

			const beforeToggle = findInputByLabel(element.shadowRoot, 'Include events before');
			simulateToggle(beforeToggle, true);
			await Promise.resolve();

			expect(filterChangeHandler).toHaveBeenCalled();
			const detail = filterChangeHandler.mock.calls[0][0].detail;
			expect(detail.beforeTime).toBeDefined();
		});

		it('should return undefined afterTime when toggle is unchecked', async() =>
		{
			const element = createElement('c-streaming-usage-filters', {
				is: LwcEventUsageMetricsFilters
			});

			const filterChangeHandler = jest.fn();
			element.addEventListener('filterchange', filterChangeHandler);
			document.body.appendChild(element);
			await Promise.resolve();

			const afterToggle = findInputByLabel(element.shadowRoot, 'Include events after');

			// First enable then disable
			simulateToggle(afterToggle, true);
			await Promise.resolve();
			simulateToggle(afterToggle, false);
			await Promise.resolve();

			const lastCall = filterChangeHandler.mock.calls[filterChangeHandler.mock.calls.length - 1][0];
			expect(lastCall.detail.afterTime).toBeUndefined();
		});

		it('should return undefined beforeTime when toggle is unchecked', async() =>
		{
			const element = createElement('c-streaming-usage-filters', {
				is: LwcEventUsageMetricsFilters
			});

			const filterChangeHandler = jest.fn();
			element.addEventListener('filterchange', filterChangeHandler);
			document.body.appendChild(element);
			await Promise.resolve();

			const beforeToggle = findInputByLabel(element.shadowRoot, 'Include events before');

			simulateToggle(beforeToggle, true);
			await Promise.resolve();
			simulateToggle(beforeToggle, false);
			await Promise.resolve();

			const lastCall = filterChangeHandler.mock.calls[filterChangeHandler.mock.calls.length - 1][0];
			expect(lastCall.detail.beforeTime).toBeUndefined();
		});
	});

	describe('time change handlers', () =>
	{
		it('should update afterTime on change', async() =>
		{
			const element = createElement('c-streaming-usage-filters', {
				is: LwcEventUsageMetricsFilters
			});

			const filterChangeHandler = jest.fn();
			element.addEventListener('filterchange', filterChangeHandler);
			document.body.appendChild(element);
			await Promise.resolve();

			// Enable afterTime filter first
			const afterToggle = findInputByLabel(element.shadowRoot, 'Include events after');
			simulateToggle(afterToggle, true);
			await Promise.resolve();

			const afterTimeInput = findInputByLabel(element.shadowRoot, 'After time');
			const newTime = '2025-01-15T10:00:00.000Z';
			simulateDatetimeChange(afterTimeInput, newTime);
			await Promise.resolve();

			const lastCall = filterChangeHandler.mock.calls[filterChangeHandler.mock.calls.length - 1][0];
			expect(lastCall.detail.afterTime).toBe(new Date(newTime).getTime());
		});

		it('should update beforeTime on change', async() =>
		{
			const element = createElement('c-streaming-usage-filters', {
				is: LwcEventUsageMetricsFilters
			});

			const filterChangeHandler = jest.fn();
			element.addEventListener('filterchange', filterChangeHandler);
			document.body.appendChild(element);
			await Promise.resolve();

			// Enable beforeTime filter first
			const beforeToggle = findInputByLabel(element.shadowRoot, 'Include events before');
			simulateToggle(beforeToggle, true);
			await Promise.resolve();

			const beforeTimeInput = findInputByLabel(element.shadowRoot, 'Before time');
			const newTime = '2025-01-20T15:00:00.000Z';
			simulateDatetimeChange(beforeTimeInput, newTime);
			await Promise.resolve();

			const lastCall = filterChangeHandler.mock.calls[filterChangeHandler.mock.calls.length - 1][0];
			expect(lastCall.detail.beforeTime).toBe(new Date(newTime).getTime());
		});
	});

	describe('event type toggle handler', () =>
	{
		it('should toggle event type selection', async() =>
		{
			const element = createElement('c-streaming-usage-filters', {
				is: LwcEventUsageMetricsFilters
			});

			const filterChangeHandler = jest.fn();
			element.addEventListener('filterchange', filterChangeHandler);
			document.body.appendChild(element);

			element.eventTypes = [
				{label: 'Type A', value: 'type_a', color: '#FF0000', index: 0},
				{label: 'Type B', value: 'type_b', color: '#00FF00', index: 1}
			];
			await Promise.resolve();

			// Toggle first event type off
			const eventTypeToggles = element.shadowRoot.querySelectorAll('.event-type lightning-input');
			const firstToggle = eventTypeToggles[0];
			Object.defineProperty(firstToggle, 'checked', {value: false, writable: true});
			Object.defineProperty(firstToggle, 'dataset', {value: {index: '0'}, writable: true});
			firstToggle.dispatchEvent(new CustomEvent('change', {bubbles: true, composed: true}));
			await Promise.resolve();

			const lastCall = filterChangeHandler.mock.calls[filterChangeHandler.mock.calls.length - 1][0];
			expect(lastCall.detail.eventTypes).toEqual([
				false,
				true
			]);
		});

		it('should maintain other event types when one is toggled', async() =>
		{
			const element = createElement('c-streaming-usage-filters', {
				is: LwcEventUsageMetricsFilters
			});

			const filterChangeHandler = jest.fn();
			element.addEventListener('filterchange', filterChangeHandler);
			document.body.appendChild(element);

			element.eventTypes = [
				{label: 'Type A', value: 'type_a', color: '#FF0000', index: 0},
				{label: 'Type B', value: 'type_b', color: '#00FF00', index: 1},
				{label: 'Type C', value: 'type_c', color: '#0000FF', index: 2}
			];
			await Promise.resolve();

			// Toggle second event type off
			const eventTypeToggles = element.shadowRoot.querySelectorAll('.event-type lightning-input');
			const secondToggle = eventTypeToggles[1];
			Object.defineProperty(secondToggle, 'checked', {value: false, writable: true});
			Object.defineProperty(secondToggle, 'dataset', {value: {index: '1'}, writable: true});
			secondToggle.dispatchEvent(new CustomEvent('change', {bubbles: true, composed: true}));
			await Promise.resolve();

			const lastCall = filterChangeHandler.mock.calls[filterChangeHandler.mock.calls.length - 1][0];
			expect(lastCall.detail.eventTypes).toEqual([
				true,
				false,
				true
			]);
		});
	});

	describe('handleClearFilters', () =>
	{
		it('should reset hasBeforeTime and hasAfterTime to false', async() =>
		{
			const element = createElement('c-streaming-usage-filters', {
				is: LwcEventUsageMetricsFilters
			});
			document.body.appendChild(element);
			await Promise.resolve();

			// Enable both toggles first
			const beforeToggle = findInputByLabel(element.shadowRoot, 'Include events before');
			const afterToggle = findInputByLabel(element.shadowRoot, 'Include events after');
			simulateToggle(beforeToggle, true);
			simulateToggle(afterToggle, true);
			await Promise.resolve();

			// Clear filters via button click
			const clearButton = element.shadowRoot.querySelector('lightning-button');
			clearButton.click();
			await Promise.resolve();

			// Time inputs should be disabled
			const afterTimeInput = findInputByLabel(element.shadowRoot, 'After time');
			const beforeTimeInput = findInputByLabel(element.shadowRoot, 'Before time');
			expect(afterTimeInput.disabled).toBe(true);
			expect(beforeTimeInput.disabled).toBe(true);
		});

		it('should reset beforeTime and afterTime to undefined', async() =>
		{
			const element = createElement('c-streaming-usage-filters', {
				is: LwcEventUsageMetricsFilters
			});

			const filterChangeHandler = jest.fn();
			element.addEventListener('filterchange', filterChangeHandler);
			document.body.appendChild(element);
			await Promise.resolve();

			const clearButton = element.shadowRoot.querySelector('lightning-button');
			clearButton.click();
			await Promise.resolve();

			const lastCall = filterChangeHandler.mock.calls[filterChangeHandler.mock.calls.length - 1][0];
			expect(lastCall.detail.beforeTime).toBeUndefined();
			expect(lastCall.detail.afterTime).toBeUndefined();
		});

		it('should reset all event types to checked=true', async() =>
		{
			const element = createElement('c-streaming-usage-filters', {
				is: LwcEventUsageMetricsFilters
			});

			const filterChangeHandler = jest.fn();
			element.addEventListener('filterchange', filterChangeHandler);
			document.body.appendChild(element);

			element.eventTypes = [
				{label: 'Type A', value: 'type_a', color: '#FF0000', index: 0},
				{label: 'Type B', value: 'type_b', color: '#00FF00', index: 1}
			];
			await Promise.resolve();

			// Toggle both off via DOM
			const eventTypeToggles = element.shadowRoot.querySelectorAll('.event-type lightning-input');
			for(let i = 0; i < eventTypeToggles.length; i++)
			{
				const toggle = eventTypeToggles[i];
				Object.defineProperty(toggle, 'checked', {value: false, writable: true});
				Object.defineProperty(toggle, 'dataset', {value: {index: String(i)}, writable: true});
				toggle.dispatchEvent(new CustomEvent('change', {bubbles: true, composed: true}));
			}
			await Promise.resolve();

			// Clear filters
			const clearButton = element.shadowRoot.querySelector('lightning-button');
			clearButton.click();
			await Promise.resolve();

			const lastCall = filterChangeHandler.mock.calls[filterChangeHandler.mock.calls.length - 1][0];
			expect(lastCall.detail.eventTypes).toEqual([
				true,
				true
			]);
		});

		it('should dispatch filterchange event', async() =>
		{
			const element = createElement('c-streaming-usage-filters', {
				is: LwcEventUsageMetricsFilters
			});

			const filterChangeHandler = jest.fn();
			element.addEventListener('filterchange', filterChangeHandler);
			document.body.appendChild(element);
			await Promise.resolve();

			const clearButton = element.shadowRoot.querySelector('lightning-button');
			clearButton.click();
			await Promise.resolve();

			expect(filterChangeHandler).toHaveBeenCalled();
		});
	});

	describe('disabled getters', () =>
	{
		it('should return true for afterTimeDisabled when hasAfterTime is false', async() =>
		{
			const element = createElement('c-streaming-usage-filters', {
				is: LwcEventUsageMetricsFilters
			});
			document.body.appendChild(element);
			await Promise.resolve();

			const afterTimeInput = findInputByLabel(element.shadowRoot, 'After time');
			expect(afterTimeInput.disabled).toBe(true);
		});

		it('should return false for afterTimeDisabled when hasAfterTime is true', async() =>
		{
			const element = createElement('c-streaming-usage-filters', {
				is: LwcEventUsageMetricsFilters
			});
			document.body.appendChild(element);
			await Promise.resolve();

			const afterToggle = findInputByLabel(element.shadowRoot, 'Include events after');
			simulateToggle(afterToggle, true);
			await Promise.resolve();

			const afterTimeInput = findInputByLabel(element.shadowRoot, 'After time');
			expect(afterTimeInput.disabled).toBe(false);
		});

		it('should return true for beforeTimeDisabled when hasBeforeTime is false', async() =>
		{
			const element = createElement('c-streaming-usage-filters', {
				is: LwcEventUsageMetricsFilters
			});
			document.body.appendChild(element);
			await Promise.resolve();

			const beforeTimeInput = findInputByLabel(element.shadowRoot, 'Before time');
			expect(beforeTimeInput.disabled).toBe(true);
		});

		it('should return false for beforeTimeDisabled when hasBeforeTime is true', async() =>
		{
			const element = createElement('c-streaming-usage-filters', {
				is: LwcEventUsageMetricsFilters
			});
			document.body.appendChild(element);
			await Promise.resolve();

			const beforeToggle = findInputByLabel(element.shadowRoot, 'Include events before');
			simulateToggle(beforeToggle, true);
			await Promise.resolve();

			const beforeTimeInput = findInputByLabel(element.shadowRoot, 'Before time');
			expect(beforeTimeInput.disabled).toBe(false);
		});
	});

	describe('filterchange event', () =>
	{
		it('should include all filter properties in event detail', async() =>
		{
			const element = createElement('c-streaming-usage-filters', {
				is: LwcEventUsageMetricsFilters
			});

			const filterChangeHandler = jest.fn();
			element.addEventListener('filterchange', filterChangeHandler);
			document.body.appendChild(element);

			element.eventTypes = [{label: 'Test', value: 'test', color: '#FF0000', index: 0}];
			await Promise.resolve();

			// Enable both time filters
			const beforeToggle = findInputByLabel(element.shadowRoot, 'Include events before');
			const afterToggle = findInputByLabel(element.shadowRoot, 'Include events after');
			simulateToggle(beforeToggle, true);
			await Promise.resolve();
			simulateToggle(afterToggle, true);
			await Promise.resolve();

			const lastCall = filterChangeHandler.mock.calls[filterChangeHandler.mock.calls.length - 1][0];
			expect(lastCall.detail).toHaveProperty('beforeTime');
			expect(lastCall.detail).toHaveProperty('afterTime');
			expect(lastCall.detail).toHaveProperty('eventTypes');
			expect(lastCall.detail.eventTypes).toEqual([true]);
		});

		it('should convert ISO timestamp to epoch milliseconds', async() =>
		{
			const element = createElement('c-streaming-usage-filters', {
				is: LwcEventUsageMetricsFilters
			});

			const filterChangeHandler = jest.fn();
			element.addEventListener('filterchange', filterChangeHandler);
			document.body.appendChild(element);
			await Promise.resolve();

			// Enable and set time
			const beforeToggle = findInputByLabel(element.shadowRoot, 'Include events before');
			simulateToggle(beforeToggle, true);
			await Promise.resolve();

			const beforeTimeInput = findInputByLabel(element.shadowRoot, 'Before time');
			const isoTime = '2025-01-15T12:00:00.000Z';
			simulateDatetimeChange(beforeTimeInput, isoTime);
			await Promise.resolve();

			const lastCall = filterChangeHandler.mock.calls[filterChangeHandler.mock.calls.length - 1][0];
			expect(lastCall.detail.beforeTime).toBe(new Date(isoTime).getTime());
		});

		it('should return empty eventTypes array when none set', async() =>
		{
			const element = createElement('c-streaming-usage-filters', {
				is: LwcEventUsageMetricsFilters
			});

			const filterChangeHandler = jest.fn();
			element.addEventListener('filterchange', filterChangeHandler);
			document.body.appendChild(element);
			await Promise.resolve();

			// Trigger a filter change
			const clearButton = element.shadowRoot.querySelector('lightning-button');
			clearButton.click();
			await Promise.resolve();

			const lastCall = filterChangeHandler.mock.calls[filterChangeHandler.mock.calls.length - 1][0];
			expect(lastCall.detail.eventTypes).toEqual([]);
		});
	});

	describe('clear filters button', () =>
	{
		it('should render clear filters button', async() =>
		{
			const element = createElement('c-streaming-usage-filters', {
				is: LwcEventUsageMetricsFilters
			});
			document.body.appendChild(element);
			await Promise.resolve();

			const clearButton = element.shadowRoot.querySelector('lightning-button');
			expect(clearButton).not.toBeNull();
			expect(clearButton.label).toBe('Clear filters');
		});

		it('should call handleClearFilters when clicked', async() =>
		{
			const element = createElement('c-streaming-usage-filters', {
				is: LwcEventUsageMetricsFilters
			});

			const filterChangeHandler = jest.fn();
			element.addEventListener('filterchange', filterChangeHandler);
			document.body.appendChild(element);
			await Promise.resolve();

			const clearButton = element.shadowRoot.querySelector('lightning-button');
			clearButton.click();
			await Promise.resolve();

			expect(filterChangeHandler).toHaveBeenCalled();
		});
	});

	describe('rendering', () =>
	{
		it('should render all toggle inputs', async() =>
		{
			const element = createElement('c-streaming-usage-filters', {
				is: LwcEventUsageMetricsFilters
			});
			document.body.appendChild(element);
			await Promise.resolve();

			expect(findInputByLabel(element.shadowRoot, 'Include events after')).not.toBeNull();
			expect(findInputByLabel(element.shadowRoot, 'Include events before')).not.toBeNull();
		});

		it('should render datetime inputs', async() =>
		{
			const element = createElement('c-streaming-usage-filters', {
				is: LwcEventUsageMetricsFilters
			});
			document.body.appendChild(element);
			await Promise.resolve();

			expect(findInputByLabel(element.shadowRoot, 'After time')).not.toBeNull();
			expect(findInputByLabel(element.shadowRoot, 'Before time')).not.toBeNull();
		});

		it('should render event type toggles with color dots', async() =>
		{
			const element = createElement('c-streaming-usage-filters', {
				is: LwcEventUsageMetricsFilters
			});
			document.body.appendChild(element);

			element.eventTypes = [
				{label: 'Type A', value: 'type_a', color: '#FF0000', index: 0}
			];
			await Promise.resolve();

			const dots = element.shadowRoot.querySelectorAll('.dot');
			expect(dots.length).toBe(1);
		});

		it('should render grid layout', async() =>
		{
			const element = createElement('c-streaming-usage-filters', {
				is: LwcEventUsageMetricsFilters
			});
			document.body.appendChild(element);
			await Promise.resolve();

			const grid = element.shadowRoot.querySelector('.slds-grid');
			expect(grid).not.toBeNull();
		});
	});
});
