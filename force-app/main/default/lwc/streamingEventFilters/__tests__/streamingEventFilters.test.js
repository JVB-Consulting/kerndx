// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) Philippe Ozil (CC0-1.0 — rights waived)
// Adapted from streaming-monitor (https://github.com/pozil/streaming-monitor)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description Jest unit tests for streamingEventFilters LWC component
 * @author Jason van Beukering
 * @date December 2025, May 2026
 */

import {createElement} from 'lwc';
import LwcEventFilters from 'c/streamingEventFilters';

// Mock each filter label to its real value so the findInputByLabel helpers keep locating
// controls by their rendered label and the assertions stay byte-faithful.
jest.mock('@salesforce/label/c.EventMonitor_Filter_ChannelLabel', () => ({default: 'Include channel'}), {virtual: true});
jest.mock('@salesforce/label/c.EventMonitor_Filter_ChannelPlaceholder', () => ({default: 'Select channel'}), {virtual: true});
jest.mock('@salesforce/label/c.EventMonitor_Filter_PayloadLabel', () => ({default: 'Include payload with keyword'}), {virtual: true});
jest.mock('@salesforce/label/c.EventMonitor_Filter_PayloadPlaceholder', () => ({default: 'Search in payload content'}), {virtual: true});
jest.mock('@salesforce/label/c.EventMonitor_Filter_MatchCase', () => ({default: 'Match case'}), {virtual: true});
jest.mock('@salesforce/label/c.EventMonitor_Filter_AfterToggle', () => ({default: 'Include events after'}), {virtual: true});
jest.mock('@salesforce/label/c.EventMonitor_Filter_AfterTimeLabel', () => ({default: 'After time'}), {virtual: true});
jest.mock('@salesforce/label/c.EventMonitor_Filter_BeforeToggle', () => ({default: 'Include events before'}), {virtual: true});
jest.mock('@salesforce/label/c.EventMonitor_Filter_BeforeTimeLabel', () => ({default: 'Before time'}), {virtual: true});
jest.mock('@salesforce/label/c.EventMonitor_Filter_ClearButton', () => ({default: 'Clear filters'}), {virtual: true});

describe('c-streaming-event-filters', () =>
{
	let element;

	beforeEach(() =>
	{
		element = createElement('c-streaming-event-filters', {
			is: LwcEventFilters
		});
	});

	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
		jest.clearAllMocks();
	});

	/**
	 * Helper to append element and wait for render
	 */
	async function createComponent()
	{
		document.body.appendChild(element);
		await Promise.resolve();
		return element;
	}

	/**
	 * Helper to find input by label
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

	describe('initial rendering', () =>
	{
		it('should render component successfully', async() =>
		{
			await createComponent();

			expect(element).toBeTruthy();
		});

		it('should render channel combobox', async() =>
		{
			await createComponent();

			const combobox = element.shadowRoot.querySelector('lightning-combobox');
			expect(combobox).toBeTruthy();
			expect(combobox.label).toBe('Include channel');
		});

		it('should render payload search input', async() =>
		{
			await createComponent();

			const payloadInput = findInputByLabel(element.shadowRoot, 'Include payload with keyword');
			expect(payloadInput).toBeTruthy();
			expect(payloadInput.type).toBe('search');
		});

		it('should render case sensitivity checkbox', async() =>
		{
			await createComponent();

			const caseInput = findInputByLabel(element.shadowRoot, 'Match case');
			expect(caseInput).toBeTruthy();
			expect(caseInput.type).toBe('checkbox');
		});

		it('should render after time toggle', async() =>
		{
			await createComponent();

			const afterToggle = findInputByLabel(element.shadowRoot, 'Include events after');
			expect(afterToggle).toBeTruthy();
			expect(afterToggle.type).toBe('toggle');
		});

		it('should render before time toggle', async() =>
		{
			await createComponent();

			const beforeToggle = findInputByLabel(element.shadowRoot, 'Include events before');
			expect(beforeToggle).toBeTruthy();
			expect(beforeToggle.type).toBe('toggle');
		});

		it('should render clear filters button', async() =>
		{
			await createComponent();

			const button = element.shadowRoot.querySelector('lightning-button');
			expect(button).toBeTruthy();
			expect(button.label).toBe('Clear filters');
		});

		it('should have datetime inputs disabled by default', async() =>
		{
			await createComponent();

			const afterTimeInput = findInputByLabel(element.shadowRoot, 'After time');
			const beforeTimeInput = findInputByLabel(element.shadowRoot, 'Before time');

			expect(afterTimeInput.disabled).toBe(true);
			expect(beforeTimeInput.disabled).toBe(true);
		});
	});

	describe('@api channels', () =>
	{
		it('should set channel options from channels array', async() =>
		{
			element.channels = [
				'channel1',
				'channel2',
				'channel3'
			];
			await createComponent();

			const combobox = element.shadowRoot.querySelector('lightning-combobox');
			expect(combobox.options).toEqual([
				{label: 'channel1', value: 'channel1'},
				{label: 'channel2', value: 'channel2'},
				{label: 'channel3', value: 'channel3'}
			]);
		});

		it('should return channels from getter', async() =>
		{
			element.channels = [
				'a',
				'b',
				'c'
			];
			await createComponent();

			expect(element.channels).toEqual([
				'a',
				'b',
				'c'
			]);
		});

		it('should handle empty channels array', async() =>
		{
			element.channels = [];
			await createComponent();

			const combobox = element.shadowRoot.querySelector('lightning-combobox');
			expect(combobox.options).toEqual([]);
		});
	});

	describe('connectedCallback initialization', () =>
	{
		it('should initialize beforeTime to current time', async() =>
		{
			const before = Date.now();
			await createComponent();
			const after = Date.now();

			const beforeTimeInput = findInputByLabel(element.shadowRoot, 'Before time');
			const beforeTimeValue = new Date(beforeTimeInput.value).getTime();

			expect(beforeTimeValue).toBeGreaterThanOrEqual(before);
			expect(beforeTimeValue).toBeLessThanOrEqual(after);
		});

		it('should initialize afterTime to 24 hours ago', async() =>
		{
			const expectedAfterTime = Date.now() - 24 * 60 * 60 * 1000;
			await createComponent();

			const afterTimeInput = findInputByLabel(element.shadowRoot, 'After time');
			const afterTimeValue = new Date(afterTimeInput.value).getTime();

			// Allow 1 second tolerance for test execution time
			expect(Math.abs(afterTimeValue - expectedAfterTime)).toBeLessThan(1000);
		});
	});

	describe('handleChannelChange', () =>
	{
		it('should dispatch filterchange event when channel changes', async() =>
		{
			await createComponent();

			const filterChangeHandler = jest.fn();
			element.addEventListener('filterchange', filterChangeHandler);

			const combobox = element.shadowRoot.querySelector('lightning-combobox');
			combobox.dispatchEvent(new CustomEvent('change', {
				detail: {value: '/event/TestEvent__e'}
			}));
			await Promise.resolve();

			expect(filterChangeHandler).toHaveBeenCalledTimes(1);
			expect(filterChangeHandler.mock.calls[0][0].detail.channel).toBe('/event/TestEvent__e');
		});
	});

	describe('handlePayloadChange', () =>
	{
		it('should dispatch filterchange event when payload changes', async() =>
		{
			await createComponent();

			const filterChangeHandler = jest.fn();
			element.addEventListener('filterchange', filterChangeHandler);

			const payloadInput = findInputByLabel(element.shadowRoot, 'Include payload with keyword');
			payloadInput.dispatchEvent(new CustomEvent('change', {
				detail: {value: 'searchterm'}
			}));
			await Promise.resolve();

			expect(filterChangeHandler).toHaveBeenCalledTimes(1);
			expect(filterChangeHandler.mock.calls[0][0].detail.payload).toBe('searchterm');
		});

		it('should trim whitespace from payload', async() =>
		{
			await createComponent();

			const filterChangeHandler = jest.fn();
			element.addEventListener('filterchange', filterChangeHandler);

			const payloadInput = findInputByLabel(element.shadowRoot, 'Include payload with keyword');
			payloadInput.dispatchEvent(new CustomEvent('change', {
				detail: {value: '  searchterm  '}
			}));
			await Promise.resolve();

			expect(filterChangeHandler.mock.calls[0][0].detail.payload).toBe('searchterm');
		});

		it('should convert whitespace-only payload to undefined', async() =>
		{
			await createComponent();

			const filterChangeHandler = jest.fn();
			element.addEventListener('filterchange', filterChangeHandler);

			const payloadInput = findInputByLabel(element.shadowRoot, 'Include payload with keyword');
			payloadInput.dispatchEvent(new CustomEvent('change', {
				detail: {value: '   '}
			}));
			await Promise.resolve();

			// Whitespace-only input is trimmed to empty string, then converted to undefined
			expect(filterChangeHandler.mock.calls[0][0].detail.payload).toBeUndefined();
		});

		it('should set payload to undefined when null', async() =>
		{
			await createComponent();

			const filterChangeHandler = jest.fn();
			element.addEventListener('filterchange', filterChangeHandler);

			const payloadInput = findInputByLabel(element.shadowRoot, 'Include payload with keyword');
			payloadInput.dispatchEvent(new CustomEvent('change', {
				detail: {value: null}
			}));
			await Promise.resolve();

			expect(filterChangeHandler.mock.calls[0][0].detail.payload).toBeUndefined();
		});
	});

	describe('handleIsCaseSensitiveChange', () =>
	{
		it('should dispatch filterchange event when case sensitivity changes', async() =>
		{
			await createComponent();

			const filterChangeHandler = jest.fn();
			element.addEventListener('filterchange', filterChangeHandler);

			const caseInput = findInputByLabel(element.shadowRoot, 'Match case');
			caseInput.checked = true;
			caseInput.dispatchEvent(new CustomEvent('change'));
			await Promise.resolve();

			expect(filterChangeHandler).toHaveBeenCalledTimes(1);
			expect(filterChangeHandler.mock.calls[0][0].detail.isCaseSensitive).toBe(true);
		});

		it('should toggle case sensitivity off', async() =>
		{
			await createComponent();

			const filterChangeHandler = jest.fn();
			element.addEventListener('filterchange', filterChangeHandler);

			const caseInput = findInputByLabel(element.shadowRoot, 'Match case');

			// Toggle on
			caseInput.checked = true;
			caseInput.dispatchEvent(new CustomEvent('change'));
			await Promise.resolve();

			// Toggle off
			caseInput.checked = false;
			caseInput.dispatchEvent(new CustomEvent('change'));
			await Promise.resolve();

			expect(filterChangeHandler.mock.calls[1][0].detail.isCaseSensitive).toBe(false);
		});
	});

	describe('handleAfterTimeToggle', () =>
	{
		it('should enable after time input when toggled on', async() =>
		{
			await createComponent();

			const afterToggle = findInputByLabel(element.shadowRoot, 'Include events after');
			afterToggle.checked = true;
			afterToggle.dispatchEvent(new CustomEvent('change'));
			await Promise.resolve();

			const afterTimeInput = findInputByLabel(element.shadowRoot, 'After time');
			expect(afterTimeInput.disabled).toBe(false);
		});

		it('should dispatch filterchange with afterTime when enabled', async() =>
		{
			await createComponent();

			const filterChangeHandler = jest.fn();
			element.addEventListener('filterchange', filterChangeHandler);

			const afterToggle = findInputByLabel(element.shadowRoot, 'Include events after');
			afterToggle.checked = true;
			afterToggle.dispatchEvent(new CustomEvent('change'));
			await Promise.resolve();

			expect(filterChangeHandler.mock.calls[0][0].detail.afterTime).toBeDefined();
			expect(typeof filterChangeHandler.mock.calls[0][0].detail.afterTime).toBe('number');
		});

		it('should dispatch filterchange with undefined afterTime when disabled', async() =>
		{
			await createComponent();

			const filterChangeHandler = jest.fn();
			element.addEventListener('filterchange', filterChangeHandler);

			const afterToggle = findInputByLabel(element.shadowRoot, 'Include events after');
			afterToggle.checked = false;
			afterToggle.dispatchEvent(new CustomEvent('change'));
			await Promise.resolve();

			expect(filterChangeHandler.mock.calls[0][0].detail.afterTime).toBeUndefined();
		});
	});

	describe('handleBeforeTimeToggle', () =>
	{
		it('should enable before time input when toggled on', async() =>
		{
			await createComponent();

			const beforeToggle = findInputByLabel(element.shadowRoot, 'Include events before');
			beforeToggle.checked = true;
			beforeToggle.dispatchEvent(new CustomEvent('change'));
			await Promise.resolve();

			const beforeTimeInput = findInputByLabel(element.shadowRoot, 'Before time');
			expect(beforeTimeInput.disabled).toBe(false);
		});

		it('should dispatch filterchange with beforeTime when enabled', async() =>
		{
			await createComponent();

			const filterChangeHandler = jest.fn();
			element.addEventListener('filterchange', filterChangeHandler);

			const beforeToggle = findInputByLabel(element.shadowRoot, 'Include events before');
			beforeToggle.checked = true;
			beforeToggle.dispatchEvent(new CustomEvent('change'));
			await Promise.resolve();

			expect(filterChangeHandler.mock.calls[0][0].detail.beforeTime).toBeDefined();
			expect(typeof filterChangeHandler.mock.calls[0][0].detail.beforeTime).toBe('number');
		});
	});

	describe('handleAfterTimeChange', () =>
	{
		it('should update afterTime and dispatch filterchange', async() =>
		{
			await createComponent();

			const filterChangeHandler = jest.fn();
			element.addEventListener('filterchange', filterChangeHandler);

			// Enable after time first
			const afterToggle = findInputByLabel(element.shadowRoot, 'Include events after');
			afterToggle.checked = true;
			afterToggle.dispatchEvent(new CustomEvent('change'));
			await Promise.resolve();

			// Change the time
			const afterTimeInput = findInputByLabel(element.shadowRoot, 'After time');
			const testDate = '2025-01-15T10:30:00.000Z';
			afterTimeInput.dispatchEvent(new CustomEvent('change', {
				detail: {value: testDate}
			}));
			await Promise.resolve();

			expect(filterChangeHandler.mock.calls[1][0].detail.afterTime).toBe(new Date(testDate).getTime());
		});
	});

	describe('handleBeforeTimeChange', () =>
	{
		it('should update beforeTime and dispatch filterchange', async() =>
		{
			await createComponent();

			const filterChangeHandler = jest.fn();
			element.addEventListener('filterchange', filterChangeHandler);

			// Enable before time first
			const beforeToggle = findInputByLabel(element.shadowRoot, 'Include events before');
			beforeToggle.checked = true;
			beforeToggle.dispatchEvent(new CustomEvent('change'));
			await Promise.resolve();

			// Change the time
			const beforeTimeInput = findInputByLabel(element.shadowRoot, 'Before time');
			const testDate = '2025-01-20T14:00:00.000Z';
			beforeTimeInput.dispatchEvent(new CustomEvent('change', {
				detail: {value: testDate}
			}));
			await Promise.resolve();

			expect(filterChangeHandler.mock.calls[1][0].detail.beforeTime).toBe(new Date(testDate).getTime());
		});
	});

	describe('handleClearFilters', () =>
	{
		it('should clear all filters and dispatch filterchange', async() =>
		{
			element.channels = ['channel1'];
			await createComponent();

			const filterChangeHandler = jest.fn();

			// Set some filter values first
			const combobox = element.shadowRoot.querySelector('lightning-combobox');
			combobox.dispatchEvent(new CustomEvent('change', {
				detail: {value: 'channel1'}
			}));
			await Promise.resolve();

			element.addEventListener('filterchange', filterChangeHandler);

			// Click clear filters button
			const clearButton = element.shadowRoot.querySelector('lightning-button');
			clearButton.click();
			await Promise.resolve();

			const detail = filterChangeHandler.mock.calls[0][0].detail;
			expect(detail.channel).toBeUndefined();
			expect(detail.payload).toBeUndefined();
			expect(detail.isCaseSensitive).toBe(false);
			expect(detail.beforeTime).toBeUndefined();
			expect(detail.afterTime).toBeUndefined();
		});

		it('should reset time toggles', async() =>
		{
			await createComponent();

			// Enable both time toggles
			const afterToggle = findInputByLabel(element.shadowRoot, 'Include events after');
			afterToggle.checked = true;
			afterToggle.dispatchEvent(new CustomEvent('change'));

			const beforeToggle = findInputByLabel(element.shadowRoot, 'Include events before');
			beforeToggle.checked = true;
			beforeToggle.dispatchEvent(new CustomEvent('change'));
			await Promise.resolve();

			// Click clear filters button
			const clearButton = element.shadowRoot.querySelector('lightning-button');
			clearButton.click();
			await Promise.resolve();

			// Verify time inputs are disabled again
			const afterTimeInput = findInputByLabel(element.shadowRoot, 'After time');
			const beforeTimeInput = findInputByLabel(element.shadowRoot, 'Before time');
			expect(afterTimeInput.disabled).toBe(true);
			expect(beforeTimeInput.disabled).toBe(true);
		});
	});

	describe('@api clearInvalidChannelFilter', () =>
	{
		it('should clear channel if not in active channels list', async() =>
		{
			element.channels = [
				'channel1',
				'channel2'
			];
			await createComponent();

			const filterChangeHandler = jest.fn();

			// Set channel filter
			const combobox = element.shadowRoot.querySelector('lightning-combobox');
			combobox.dispatchEvent(new CustomEvent('change', {
				detail: {value: 'channel1'}
			}));
			await Promise.resolve();

			element.addEventListener('filterchange', filterChangeHandler);

			// Call clearInvalidChannelFilter without channel1
			element.clearInvalidChannelFilter([
				'channel2',
				'channel3'
			]);
			await Promise.resolve();

			expect(filterChangeHandler).toHaveBeenCalledTimes(1);
			expect(filterChangeHandler.mock.calls[0][0].detail.channel).toBeUndefined();
		});

		it('should not clear channel if still in active channels list', async() =>
		{
			element.channels = [
				'channel1',
				'channel2'
			];
			await createComponent();

			const filterChangeHandler = jest.fn();

			// Set channel filter
			const combobox = element.shadowRoot.querySelector('lightning-combobox');
			combobox.dispatchEvent(new CustomEvent('change', {
				detail: {value: 'channel1'}
			}));
			await Promise.resolve();

			element.addEventListener('filterchange', filterChangeHandler);

			// Call clearInvalidChannelFilter with channel1 still present
			element.clearInvalidChannelFilter([
				'channel1',
				'channel3'
			]);
			await Promise.resolve();

			expect(filterChangeHandler).not.toHaveBeenCalled();
		});

		it('should not dispatch event if channel is not set', async() =>
		{
			await createComponent();

			const filterChangeHandler = jest.fn();
			element.addEventListener('filterchange', filterChangeHandler);

			element.clearInvalidChannelFilter(['channel1']);
			await Promise.resolve();

			expect(filterChangeHandler).not.toHaveBeenCalled();
		});
	});

	describe('afterTimeDisabled getter', () =>
	{
		it('should return true when hasAfterTime is false', async() =>
		{
			await createComponent();

			const afterTimeInput = findInputByLabel(element.shadowRoot, 'After time');
			expect(afterTimeInput.disabled).toBe(true);
		});

		it('should return false when hasAfterTime is true', async() =>
		{
			await createComponent();

			const afterToggle = findInputByLabel(element.shadowRoot, 'Include events after');
			afterToggle.checked = true;
			afterToggle.dispatchEvent(new CustomEvent('change'));
			await Promise.resolve();

			const afterTimeInput = findInputByLabel(element.shadowRoot, 'After time');
			expect(afterTimeInput.disabled).toBe(false);
		});
	});

	describe('beforeTimeDisabled getter', () =>
	{
		it('should return true when hasBeforeTime is false', async() =>
		{
			await createComponent();

			const beforeTimeInput = findInputByLabel(element.shadowRoot, 'Before time');
			expect(beforeTimeInput.disabled).toBe(true);
		});

		it('should return false when hasBeforeTime is true', async() =>
		{
			await createComponent();

			const beforeToggle = findInputByLabel(element.shadowRoot, 'Include events before');
			beforeToggle.checked = true;
			beforeToggle.dispatchEvent(new CustomEvent('change'));
			await Promise.resolve();

			const beforeTimeInput = findInputByLabel(element.shadowRoot, 'Before time');
			expect(beforeTimeInput.disabled).toBe(false);
		});
	});

	describe('filterchange event detail structure', () =>
	{
		it('should include all filter properties in event detail', async() =>
		{
			element.channels = ['testChannel'];
			await createComponent();

			const filterChangeHandler = jest.fn();
			element.addEventListener('filterchange', filterChangeHandler);

			// Set all filters
			const combobox = element.shadowRoot.querySelector('lightning-combobox');
			combobox.dispatchEvent(new CustomEvent('change', {
				detail: {value: 'testChannel'}
			}));

			const payloadInput = findInputByLabel(element.shadowRoot, 'Include payload with keyword');
			payloadInput.dispatchEvent(new CustomEvent('change', {
				detail: {value: 'keyword'}
			}));

			const caseInput = findInputByLabel(element.shadowRoot, 'Match case');
			caseInput.checked = true;
			caseInput.dispatchEvent(new CustomEvent('change'));

			const afterToggle = findInputByLabel(element.shadowRoot, 'Include events after');
			afterToggle.checked = true;
			afterToggle.dispatchEvent(new CustomEvent('change'));

			const beforeToggle = findInputByLabel(element.shadowRoot, 'Include events before');
			beforeToggle.checked = true;
			beforeToggle.dispatchEvent(new CustomEvent('change'));
			await Promise.resolve();

			const lastCall = filterChangeHandler.mock.calls[filterChangeHandler.mock.calls.length - 1][0];
			const detail = lastCall.detail;

			expect(detail).toHaveProperty('channel');
			expect(detail).toHaveProperty('payload');
			expect(detail).toHaveProperty('isCaseSensitive');
			expect(detail).toHaveProperty('beforeTime');
			expect(detail).toHaveProperty('afterTime');
		});
	});
});
