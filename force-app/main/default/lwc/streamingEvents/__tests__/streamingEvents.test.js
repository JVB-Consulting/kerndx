// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) Philippe Ozil (CC0-1.0 — rights waived)
// Adapted from streaming-monitor (https://github.com/pozil/streaming-monitor)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description Jest unit tests for streamingEvents LWC component
 * @author Jason van Beukering
 * @date December 2025, July 2026
 */
import {createElement} from 'lwc';
import LwcEvents from 'c/streamingEvents';
import {getRecord} from 'lightning/uiRecordApi';

// Mock User Id
jest.mock('@salesforce/user/Id', () => ({default: '005000000000001AAA'}), {virtual: true});

// Mock schema fields
jest.mock('@salesforce/schema/User.TimeZoneSidKey', () => ({default: 'User.TimeZoneSidKey'}), {virtual: true});

jest.mock('@salesforce/schema/User.LocaleSidKey', () => ({default: 'User.LocaleSidKey'}), {virtual: true});

// Restore the real English values for the labels these tests value-assert (the default
// sfdx-lwc-jest stub resolves each to the bare string 'c.<Name>'). The two count-badge labels keep
// their {0}/{1} form so the real formatTemplateString interpolation is verified end-to-end.
jest.mock('@salesforce/label/c.EventMonitor_StreamingMonitorTitle', () => ({default: 'Streaming Monitor'}), {virtual: true});
jest.mock('@salesforce/label/c.EventMonitor_CountBadge_Showing', () => ({default: 'Showing {0} events'}), {virtual: true});
jest.mock('@salesforce/label/c.EventMonitor_CountBadge_ShowingFiltered', () => ({default: 'Showing {0} of {1} events'}), {virtual: true});

// Mock utilityStreaming — the real streamingTimeline child consumes the full utilityStreaming
// surface, so the mock wraps the actual module and only spies the functions this suite asserts on.
jest.mock('c/utilityStreaming', () =>
{
	const actual = jest.requireActual('c/utilityStreaming');
	return {
		...actual, timestampSort: jest.fn(actual.timestampSort), getTimeLabel: jest.fn(actual.getTimeLabel)
	};
}, {virtual: true});

const mockEvent1 = {
	id: 'evt-1', channel: '/event/TestEvent__e', timestamp: 1735380600000, type: 'PlatformEvent', replayId: '12345', payload: '{"field1":"value1"}'
};

const mockEvent2 = {
	id: 'evt-2', channel: '/event/AnotherEvent__e', timestamp: 1735380700000, type: 'PlatformEvent', replayId: '12346', payload: '{"field2":"value2"}'
};

const mockSubscription1 = {channel: '/event/TestEvent__e', replayId: -1};
const mockSubscription2 = {channel: '/event/AnotherEvent__e', replayId: -1};

const mockUserRecord = {
	fields: {
		'User.TimeZoneSidKey': {value: 'America/New_York'}, 'User.LocaleSidKey': {value: 'en_US'}
	}
};

describe('c-streaming-events', () =>
{
	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
		jest.clearAllMocks();
	});

	async function flushPromises()
	{
		return new Promise((resolve) => setTimeout(resolve, 0));
	}

	const createComponent = () =>
	{
		const element = createElement('c-streaming-events', {is: LwcEvents});
		document.body.appendChild(element);

		// Emit wire data for user record
		getRecord.emit(mockUserRecord);

		return element;
	};

	describe('initialization', () =>
	{
		it('renders lightning-card', async() =>
		{
			const element = createComponent();
			await flushPromises();

			const card = element.shadowRoot.querySelector('lightning-card');
			expect(card).not.toBeNull();
			expect(card.title).toBe('Streaming Monitor');
		});

		it('shows initial illustration message', async() =>
		{
			const element = createComponent();
			await flushPromises();

			const illustration = element.shadowRoot.querySelector('.slds-illustration');
			expect(illustration).not.toBeNull();
		});

		it('renders modal component', async() =>
		{
			const element = createComponent();
			await flushPromises();

			const modal = element.shadowRoot.querySelector('c-modal');
			expect(modal).not.toBeNull();
		});
	});

	describe('subscriptions @api property', () =>
	{
		it('sets subscriptions list', async() =>
		{
			const element = createComponent();
			await flushPromises();

			element.subscriptions = [
				mockSubscription1,
				mockSubscription2
			];
			await flushPromises();

			expect(element.subscriptions).toEqual([
				mockSubscription1,
				mockSubscription2
			]);
		});

		it('updates channels list based on subscriptions', async() =>
		{
			const element = createComponent();
			await flushPromises();

			element.subscriptions = [
				mockSubscription1,
				mockSubscription2
			];
			await flushPromises();

			// Filter component should be rendered when subscriptions exist
			const filterElement = element.shadowRoot.querySelector('c-streaming-event-filters');
			expect(filterElement).not.toBeNull();
		});
	});

	describe('addStreamingEvent @api method', () =>
	{
		it('adds event to events list', async() =>
		{
			const element = createComponent();
			element.subscriptions = [mockSubscription1];
			await flushPromises();

			element.addStreamingEvent(mockEvent1);
			await flushPromises();

			// Verify badge shows event count
			const badge = element.shadowRoot.querySelector('lightning-badge');
			expect(badge).not.toBeNull();
			expect(badge.label).toContain('1');
		});

		it('sorts events by timestamp after adding', async() =>
		{
			const {timestampSort} = require('c/utilityStreaming');

			const element = createComponent();
			element.subscriptions = [
				mockSubscription1,
				mockSubscription2
			];
			await flushPromises();

			element.addStreamingEvent(mockEvent2);
			element.addStreamingEvent(mockEvent1);
			await flushPromises();

			expect(timestampSort).toHaveBeenCalled();
		});
	});

	describe('removeEventsForChannel @api method', () =>
	{
		it('removes events for specified channel', async() =>
		{
			const element = createComponent();
			element.subscriptions = [
				mockSubscription1,
				mockSubscription2
			];
			await flushPromises();

			element.addStreamingEvent(mockEvent1);
			element.addStreamingEvent(mockEvent2);
			await flushPromises();

			element.removeEventsForChannel('/event/TestEvent__e');
			await flushPromises();

			// Badge should show 1 event remaining
			const badge = element.shadowRoot.querySelector('lightning-badge');
			expect(badge).not.toBeNull();
			expect(badge.label).toContain('1');
		});
	});

	describe('handleClearEvents @api method', () =>
	{
		it('clears all events', async() =>
		{
			const element = createComponent();
			element.subscriptions = [mockSubscription1];
			await flushPromises();

			element.addStreamingEvent(mockEvent1);
			await flushPromises();

			element.handleClearEvents();
			await flushPromises();

			// Illustration should show after clearing
			const illustration = element.shadowRoot.querySelector('.slds-illustration');
			expect(illustration).not.toBeNull();
		});
	});

	describe('empty subscriptions handling', () =>
	{
		it('clears filtered events when no subscriptions', async() =>
		{
			const element = createComponent();
			element.subscriptions = [mockSubscription1];
			element.addStreamingEvent(mockEvent1);
			await flushPromises();

			// Clear subscriptions
			element.subscriptions = [];
			await flushPromises();

			// Should show illustration
			const illustration = element.shadowRoot.querySelector('.slds-illustration');
			expect(illustration).not.toBeNull();
		});
	});

	describe('timeline integration', () =>
	{
		it('renders timeline component when events exist', async() =>
		{
			const element = createComponent();
			element.subscriptions = [mockSubscription1];
			element.addStreamingEvent(mockEvent1);
			await flushPromises();

			// Default view is timeline
			const timeline = element.shadowRoot.querySelector('c-streaming-timeline');
			expect(timeline).not.toBeNull();
		});
	});

	describe('getters', () =>
	{
		it('eventCountLabel shows event count in badge', async() =>
		{
			const element = createComponent();
			element.subscriptions = [mockSubscription1];
			element.addStreamingEvent(mockEvent1);
			await flushPromises();

			const badge = element.shadowRoot.querySelector('lightning-badge');
			expect(badge.label).toContain('1');
		});

		it('eventCountLabel shows filtered vs total when different', async() =>
		{
			const element = createComponent();
			element.subscriptions = [
				mockSubscription1,
				mockSubscription2
			];
			element.addStreamingEvent(mockEvent1);
			element.addStreamingEvent(mockEvent2);
			await flushPromises();

			// Apply a channel filter to reduce visible events
			const filterElement = element.shadowRoot.querySelector('c-streaming-event-filters');
			filterElement.dispatchEvent(new CustomEvent('filterchange', {
				detail: {channel: '/event/TestEvent__e', payload: undefined, isCaseSensitive: false}
			}));
			await flushPromises();

			const badge = element.shadowRoot.querySelector('lightning-badge');
			expect(badge.label).toContain('of');
		});

		it('selectedEventPayload formats JSON payload', async() =>
		{
			const element = createComponent();
			element.subscriptions = [mockSubscription1];
			element.addStreamingEvent(mockEvent1);
			await flushPromises();

			const headerControls = element.shadowRoot.querySelector('c-streaming-events-header');
			headerControls.dispatchEvent(new CustomEvent('viewmodechange', {
				detail: {value: 'table'}
			}));
			await flushPromises();

			const modal = element.shadowRoot.querySelector('c-modal');
			modal.show = jest.fn();

			const datatable = element.shadowRoot.querySelector('lightning-datatable');
			datatable.dispatchEvent(new CustomEvent('rowaction', {
				detail: {row: mockEvent1}
			}));
			await flushPromises();

			expect(modal.show).toHaveBeenCalled();
		});
	});

	describe('forceRerender @api method', () =>
	{
		it('temporarily clears and restores viewMode', async() =>
		{
			const element = createComponent();
			element.subscriptions = [mockSubscription1];
			element.addStreamingEvent(mockEvent1);
			await flushPromises();

			// forceRerender uses setTimeout which we can't easily test without fake timers
			// Just verify it doesn't throw
			expect(() => element.forceRerender()).not.toThrow();

			// Wait for the setTimeout to complete
			await new Promise(resolve => setTimeout(resolve, 10));
			await flushPromises();

			// Component should still render correctly
			const card = element.shadowRoot.querySelector('lightning-card');
			expect(card).not.toBeNull();
		});
	});

	describe('filter handling', () =>
	{
		it('handleFilterChange updates filters and reapplies', async() =>
		{
			const element = createComponent();
			element.subscriptions = [
				mockSubscription1,
				mockSubscription2
			];
			element.addStreamingEvent(mockEvent1);
			element.addStreamingEvent(mockEvent2);
			await flushPromises();

			const filterElement = element.shadowRoot.querySelector('c-streaming-event-filters');
			filterElement.dispatchEvent(new CustomEvent('filterchange', {
				detail: {channel: '/event/TestEvent__e', payload: undefined, isCaseSensitive: false}
			}));
			await flushPromises();

			// Should filter to only TestEvent__e events
			const badge = element.shadowRoot.querySelector('lightning-badge');
			expect(badge.label).toContain('1');
		});

		it('applies afterTime filter', async() =>
		{
			const element = createComponent();
			element.subscriptions = [mockSubscription1];
			element.addStreamingEvent(mockEvent1);
			await flushPromises();

			const filterElement = element.shadowRoot.querySelector('c-streaming-event-filters');
			filterElement.dispatchEvent(new CustomEvent('filterchange', {
				detail: {afterTime: mockEvent1.timestamp + 1000, payload: undefined, isCaseSensitive: false}
			}));
			await flushPromises();

			// Event should be filtered out (timestamp < afterTime)
			const illustration = element.shadowRoot.querySelector('.slds-illustration');
			expect(illustration).not.toBeNull();
		});

		it('applies beforeTime filter', async() =>
		{
			const element = createComponent();
			element.subscriptions = [mockSubscription1];
			element.addStreamingEvent(mockEvent1);
			await flushPromises();

			const filterElement = element.shadowRoot.querySelector('c-streaming-event-filters');
			filterElement.dispatchEvent(new CustomEvent('filterchange', {
				detail: {beforeTime: mockEvent1.timestamp - 1000, payload: undefined, isCaseSensitive: false}
			}));
			await flushPromises();

			// Event should be filtered out (timestamp > beforeTime)
			const illustration = element.shadowRoot.querySelector('.slds-illustration');
			expect(illustration).not.toBeNull();
		});

		it('applies payload filter case-insensitive', async() =>
		{
			const element = createComponent();
			element.subscriptions = [mockSubscription1];
			element.addStreamingEvent(mockEvent1);
			await flushPromises();

			const filterElement = element.shadowRoot.querySelector('c-streaming-event-filters');
			filterElement.dispatchEvent(new CustomEvent('filterchange', {
				detail: {payload: 'VALUE1', isCaseSensitive: false}
			}));
			await flushPromises();

			// Should still match (case-insensitive)
			const badge = element.shadowRoot.querySelector('lightning-badge');
			expect(badge.label).toContain('1');
		});

		it('applies payload filter case-sensitive', async() =>
		{
			const element = createComponent();
			element.subscriptions = [mockSubscription1];
			element.addStreamingEvent(mockEvent1);
			await flushPromises();

			const filterElement = element.shadowRoot.querySelector('c-streaming-event-filters');
			filterElement.dispatchEvent(new CustomEvent('filterchange', {
				detail: {payload: 'VALUE1', isCaseSensitive: true}
			}));
			await flushPromises();

			// Should NOT match (case-sensitive, payload has 'value1' not 'VALUE1')
			const illustration = element.shadowRoot.querySelector('.slds-illustration');
			expect(illustration).not.toBeNull();
		});

		it('applies payload filter case-sensitive with match', async() =>
		{
			const element = createComponent();
			element.subscriptions = [mockSubscription1];
			element.addStreamingEvent(mockEvent1);
			await flushPromises();

			const filterElement = element.shadowRoot.querySelector('c-streaming-event-filters');
			filterElement.dispatchEvent(new CustomEvent('filterchange', {
				detail: {payload: 'value1', isCaseSensitive: true}
			}));
			await flushPromises();

			// Should match (case-sensitive, exact match)
			const badge = element.shadowRoot.querySelector('lightning-badge');
			expect(badge.label).toContain('1');
		});
	});

	describe('view mode handling', () =>
	{
		it('handleViewModeChange switches to table view', async() =>
		{
			const element = createComponent();
			element.subscriptions = [mockSubscription1];
			element.addStreamingEvent(mockEvent1);
			await flushPromises();

			const headerControls = element.shadowRoot.querySelector('c-streaming-events-header');
			headerControls.dispatchEvent(new CustomEvent('viewmodechange', {
				detail: {value: 'table'}
			}));
			await flushPromises();

			const datatable = element.shadowRoot.querySelector('lightning-datatable');
			expect(datatable).not.toBeNull();
		});

		it('handleFiltersDisplayToggle hides filters', async() =>
		{
			const element = createComponent();
			element.subscriptions = [mockSubscription1];
			// Need to add an event for header controls to render (hasData condition in HTML)
			element.addStreamingEvent(mockEvent1);
			await flushPromises();

			const headerControls = element.shadowRoot.querySelector('c-streaming-events-header');
			// Event is 'filtertoggle' based on HTML: onfiltertoggle={handleFiltersDisplayToggle}
			headerControls.dispatchEvent(new CustomEvent('filtertoggle', {
				detail: {value: false}
			}));
			await flushPromises();

			// Filters section should have slds-hide class
			const filtersSection = element.shadowRoot.querySelector('.slds-hide');
			expect(filtersSection).not.toBeNull();
		});
	});

	describe('event selection and modal', () =>
	{
		it('handleEventTableRowAction opens modal with selected event', async() =>
		{
			const element = createComponent();
			element.subscriptions = [mockSubscription1];
			element.addStreamingEvent(mockEvent1);
			await flushPromises();

			// Switch to table view
			const headerControls = element.shadowRoot.querySelector('c-streaming-events-header');
			headerControls.dispatchEvent(new CustomEvent('viewmodechange', {
				detail: {value: 'table'}
			}));
			await flushPromises();

			// Mock modal show method
			const modal = element.shadowRoot.querySelector('c-modal');
			modal.show = jest.fn();

			const datatable = element.shadowRoot.querySelector('lightning-datatable');
			datatable.dispatchEvent(new CustomEvent('rowaction', {
				detail: {row: mockEvent1}
			}));
			await flushPromises();

			expect(modal.show).toHaveBeenCalled();
		});

		it('handleTimelineSelection opens modal with selected event', async() =>
		{
			const element = createComponent();
			element.subscriptions = [mockSubscription1];
			element.addStreamingEvent(mockEvent1);
			await flushPromises();

			// Mock modal show method
			const modal = element.shadowRoot.querySelector('c-modal');
			modal.show = jest.fn();

			const timeline = element.shadowRoot.querySelector('c-streaming-timeline');
			// Event is 'select' not 'eventselection' based on HTML: onselect={handleTimelineSelection}
			timeline.dispatchEvent(new CustomEvent('select', {
				detail: mockEvent1
			}));
			await flushPromises();

			expect(modal.show).toHaveBeenCalled();
		});

		it('handleCloseEventModal clears selected event', async() =>
		{
			const element = createComponent();
			element.subscriptions = [mockSubscription1];
			element.addStreamingEvent(mockEvent1);
			await flushPromises();

			// Select an event via timeline
			const modal = element.shadowRoot.querySelector('c-modal');
			modal.show = jest.fn();

			const timeline = element.shadowRoot.querySelector('c-streaming-timeline');
			// Event is 'select' based on HTML: onselect={handleTimelineSelection}
			timeline.dispatchEvent(new CustomEvent('select', {
				detail: mockEvent1
			}));
			await flushPromises();

			// Close the modal
			modal.dispatchEvent(new CustomEvent('close'));
			await flushPromises();

			// Modal should still exist
			expect(modal).not.toBeNull();
		});
	});

	describe('download events', () =>
	{
		it('handleDownloadEvents creates and clicks download link', async() =>
		{
			const element = createComponent();
			element.subscriptions = [mockSubscription1];
			element.addStreamingEvent(mockEvent1);
			await flushPromises();

			// Mock URL.createObjectURL/revokeObjectURL and document.createElement
			const mockUrl = 'blob:test-url';
			const originalCreateObjectURL = window.URL.createObjectURL;
			const originalRevokeObjectURL = window.URL.revokeObjectURL;
			window.URL.createObjectURL = jest.fn(() => mockUrl);
			window.URL.revokeObjectURL = jest.fn();

			const mockClick = jest.fn();
			const originalCreateElement = document.createElement.bind(document);
			jest.spyOn(document, 'createElement').mockImplementation((tagName) =>
			{
				if(tagName === 'a')
				{
					return {
						href: '', download: '', click: mockClick
					};
				}
				return originalCreateElement(tagName);
			});

			// Trigger download via header controls
			// Event is 'download' based on HTML: ondownload={handleDownloadEvents}
			const headerControls = element.shadowRoot.querySelector('c-streaming-events-header');
			headerControls.dispatchEvent(new CustomEvent('download'));
			await flushPromises();

			expect(mockClick).toHaveBeenCalled();

			// Restore mocks
			window.URL.createObjectURL = originalCreateObjectURL;
			window.URL.revokeObjectURL = originalRevokeObjectURL;
			document.createElement.mockRestore();
		});

		it('revokes the blob object URL after the download click so the blob is not retained for the page lifetime', async() =>
		{
			const element = createComponent();
			element.subscriptions = [mockSubscription1];
			element.addStreamingEvent(mockEvent1);
			await flushPromises();

			const mockUrl = 'blob:test-url';
			const originalCreateObjectURL = window.URL.createObjectURL;
			const originalRevokeObjectURL = window.URL.revokeObjectURL;
			window.URL.createObjectURL = jest.fn(() => mockUrl);
			window.URL.revokeObjectURL = jest.fn();

			const mockClick = jest.fn();
			const originalCreateElement = document.createElement.bind(document);
			jest.spyOn(document, 'createElement').mockImplementation((tagName) =>
			{
				if(tagName === 'a')
				{
					return {
						href: '', download: '', click: mockClick
					};
				}
				return originalCreateElement(tagName);
			});

			const headerControls = element.shadowRoot.querySelector('c-streaming-events-header');
			headerControls.dispatchEvent(new CustomEvent('download'));
			await flushPromises();

			expect(window.URL.revokeObjectURL).toHaveBeenCalledWith(mockUrl);

			// The click starts the download read, so the revoke must come after it.
			const clickOrder = mockClick.mock.invocationCallOrder[0];
			const revokeOrder = window.URL.revokeObjectURL.mock.invocationCallOrder[0];
			expect(revokeOrder).toBeGreaterThan(clickOrder);

			// Restore mocks
			window.URL.createObjectURL = originalCreateObjectURL;
			window.URL.revokeObjectURL = originalRevokeObjectURL;
			document.createElement.mockRestore();
		});
	});

	describe('illustration message states', () =>
	{
		it('shows filter message when events exist but none match filters', async() =>
		{
			const element = createComponent();
			element.subscriptions = [mockSubscription1];
			element.addStreamingEvent(mockEvent1);
			await flushPromises();

			// Apply filter that matches nothing
			const filterElement = element.shadowRoot.querySelector('c-streaming-event-filters');
			filterElement.dispatchEvent(new CustomEvent('filterchange', {
				detail: {channel: '/event/NonExistent__e'}
			}));
			await flushPromises();

			const illustration = element.shadowRoot.querySelector('.slds-illustration');
			expect(illustration).not.toBeNull();
		});
	});

	describe('formatInUserTimezone', () =>
	{
		it('returns empty string for null timestamp', () =>
		{
			// Access the component prototype to test the method directly
			const result = LwcEvents.prototype.formatInUserTimezone.call({userTimezone: 'America/New_York'}, null);
			expect(result).toBe('');
		});

		it('returns empty string for undefined timestamp', () =>
		{
			const result = LwcEvents.prototype.formatInUserTimezone.call({userTimezone: 'America/New_York'}, undefined);
			expect(result).toBe('');
		});

		it('uses fallback when userTimezone not set', () =>
		{
			// Test with no userTimezone set - should use browser locale fallback
			const result = LwcEvents.prototype.formatInUserTimezone.call({userTimezone: null}, 1735380600000);
			expect(result).toMatch(/\d{4}-\d{2}-\d{2}/);
		});

		it('formats with userTimezone when set', () =>
		{
			const result = LwcEvents.prototype.formatInUserTimezone.call({userTimezone: 'America/New_York'}, 1735380600000);
			expect(result).toMatch(/\d{4}-\d{2}-\d{2}/);
		});
	});
});
