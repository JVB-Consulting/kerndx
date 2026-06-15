// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) Philippe Ozil (CC0-1.0 — rights waived)
// Adapted from streaming-monitor (https://github.com/pozil/streaming-monitor)
// Modifications copyright (c) 2026 JVB Consulting

//noinspection FunctionWithMultipleReturnPointsJS

/**
 * @description Lightning Web Component that displays and manages a list of streaming events.
 * Supports both Table and Timeline views with client-side filtering and event selection.
 *
 * Features:
 *   - Maintains a list of incoming streaming events (`addStreamingEvent`)
 *   - Provides filters by channel, payload, and time ranges
 *   - Supports case-sensitive and case-insensitive payload searches
 *   - Dynamically updates channels list based on incoming events
 *   - Allows toggling between Table and Timeline view modes
 *   - Supports clearing and downloading events
 *   - Handles event selection and modal display
 *
 * @date March 2026, May 2026
 */
import {LightningElement, api, wire} from 'lwc';
import {getRecord, getFieldValue} from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import TIMEZONE_FIELD from '@salesforce/schema/User.TimeZoneSidKey';
import LOCALE_FIELD from '@salesforce/schema/User.LocaleSidKey';
import {
	VIEW_MODE_TABLE, VIEW_MODE_TIMELINE, TABLE_COLUMNS, DEFAULT_EVENT_DATA
} from './constants';
import {timestampSort, getTimeLabel} from 'c/utilityStreaming';

// ── Helpers ──────────────────────────────────────────────────────────────

/**
 * @description Tests whether a single event matches all active filter criteria.
 * Consolidates channel, time range, and payload filters into a single-pass predicate.
 *
 * @param {Object} event - The event object to test.
 * @param {Object} filters - The active filter criteria.
 * @returns {boolean} True if the event passes all filters.
 */
function matchesFilter(event, filters)
{
	const {channel, payload, isCaseSensitive, afterTime, beforeTime} = filters;
	if(channel && event.channel !== channel)
	{
		return false;
	}
	if(afterTime && (!event.timestamp || event.timestamp < afterTime))
	{
		return false;
	}
	if(beforeTime && (!event.timestamp || event.timestamp > beforeTime))
	{
		return false;
	}
	if(payload)
	{
		if(isCaseSensitive)
		{
			if(!event.payload || !event.payload.includes(payload))
			{
				return false;
			}
		}
		else
		{
			const cleanFilter = payload.toLowerCase();
			if(!event.payload || !event.payload.toLowerCase().includes(cleanFilter))
			{
				return false;
			}
		}
	}
	return true;
}

// ── Component ────────────────────────────────────────────────────────────

// eslint-disable-next-line kerndx/use-component-builder -- framework component extends LightningElement directly (no ComponentBuilder wrapper needed for this layer)
export default class StreamingEvents extends LightningElement
{
	// ── Internal State ───────────────────────────────────────────────────

	channels = [];
	events = [];
	filters = {
		channel: undefined, payload: undefined, isCaseSensitive: false, beforeTime: undefined, afterTime: undefined
	};
	filteredEvents = [];
	selectedEvent = DEFAULT_EVENT_DATA;
	emptyStateMessage;
	activeSubscriptions = [];

	isFiltersDisplayed = true;
	viewMode = VIEW_MODE_TIMELINE;

	tableColumns = TABLE_COLUMNS;

	userId = USER_ID;
	userTimezone;
	userLocale;

	// ── @api Properties ──────────────────────────────────────────────────

	// noinspection JSUnusedGlobalSymbols
	get subscriptions()
	{
		return this.activeSubscriptions;
	}

	/**
	 * @description Updates internal subscription list and illustration message.
	 */
	@api set subscriptions(values)
	{
		this.activeSubscriptions = values;

		const activeChannels = this.activeSubscriptions.map(sub => sub.channel);
		const filterElement = this.template.querySelector('c-streaming-event-filters');
		if(filterElement)
		{
			filterElement.clearInvalidChannelFilter(activeChannels);
		}

		this.updateEmptyStateMessage();
		this.updateChannelsList();
		this.applyFilters();
	}

	// ── Computed Properties ──────────────────────────────────────────────

	get eventCountLabel()
	{
		const totalEvents = this.events.length;
		const filteredEvents = this.filteredEvents.length;
		if(totalEvents === filteredEvents)
		{
			return `Showing ${totalEvents} events`;
		}
		return `Showing ${filteredEvents} of ${totalEvents} events`;
	}

	get selectedEventPayload()
	{
		const {payload} = this.selectedEvent;
		if(payload)
		{
			return JSON.stringify(JSON.parse(payload), null, 2);
		}
		return '';
	}

	get isTableViewMode()
	{
		return this.viewMode === VIEW_MODE_TABLE;
	}

	get isTimelineViewMode()
	{
		return this.viewMode === VIEW_MODE_TIMELINE;
	}

	get hasData()
	{
		return this.events.length > 0;
	}

	get hasVisibleData()
	{
		return this.filteredEvents.length > 0;
	}

	get hasActiveSubscriptions()
	{
		return this.activeSubscriptions && this.activeSubscriptions.length > 0;
	}

	get filterClasses()
	{
		return this.isFiltersDisplayed ? 'slds-show slds-border_bottom' : 'slds-hide';
	}

	get hasActiveFilters()
	{
		const {channel, payload, afterTime, beforeTime} = this.filters;
		return channel || payload || afterTime || beforeTime;
	}

	get tableData()
	{
		return this.filteredEvents.map(event =>
		{
			return {
				...event, timeLabel: getTimeLabel(event.timestamp, this.userTimezone, this.userLocale)
			};
		});
	}

	// ── Wire Adapters ────────────────────────────────────────────────────

	@wire(getRecord, {
		recordId: '$userId', fields: [
			TIMEZONE_FIELD,
			LOCALE_FIELD
		]
	}) wiredUser({data})
	{
		if(data)
		{
			this.userTimezone = getFieldValue(data, TIMEZONE_FIELD);
			this.userLocale = getFieldValue(data, LOCALE_FIELD);
		}
	}

	// ── Lifecycle ────────────────────────────────────────────────────────

	/**
	 * @description Updates illustration message on component initialization.
	 */
	connectedCallback()
	{
		this.updateEmptyStateMessage();
	}

	// ── @api Methods ─────────────────────────────────────────────────────

	/**
	 * @description Adds a new streaming event to the list, sorts events by timestamp,
	 * applies current filters, and updates channels list if necessary.
	 */
	@api addStreamingEvent(eventData)
	{
		this.events.push(eventData);
		this.events.sort(timestampSort);
		this.applyFilters();
		this.updateChannelsList();
	}

	/**
	 * @description Removes all events for a specific channel from the events list.
	 *
	 * @param {string} channel - The channel to remove events for.
	 */
	@api removeEventsForChannel(channel)
	{
		this.events = this.events.filter((e) => e.channel !== channel);
		this.applyFilters();
		this.updateChannelsList();
		this.updateEmptyStateMessage();
	}

	/**
	 * @description Forces rerender to fix datatable responsiveness.
	 */
	@api forceRerender()
	{
		const viewMode = this.viewMode;
		this.viewMode = null;
		// eslint-disable-next-line @lwc/lwc/no-async-operation
		setTimeout(() =>
		{
			this.viewMode = viewMode;
		}, 1);
	}

	/**
	 * @description Clears all events and filteredEvents, and updates illustration message.
	 */
	@api handleClearEvents()
	{
		this.events = [];
		this.filteredEvents = [];
		this.updateEmptyStateMessage();
	}

	// ── Event Handlers ───────────────────────────────────────────────────

	/**
	 * @description Updates filters based on event payload and reapplies them.
	 */
	handleFilterChange(event)
	{
		this.filters = event.detail;
		this.applyFilters();
	}

	/**
	 * @description Triggers download of all events as a JSON file.
	 */
	handleDownloadEvents()
	{
		const downloadLink = document.createElement('a');
		const jsonBlob = new Blob([JSON.stringify(this.events)], {
			type: 'application/octet-stream'
		});
		downloadLink.href = window.URL.createObjectURL(jsonBlob);
		downloadLink.download = 'events.json';
		downloadLink.click();
	}

	/**
	 * @description Toggles visibility of the filters section.
	 */
	handleFiltersDisplayToggle(event)
	{
		this.isFiltersDisplayed = event.detail.value;
	}

	/**
	 * @description Changes the view mode between Table and Timeline.
	 */
	handleViewModeChange(event)
	{
		this.viewMode = event.detail.value;
	}

	/**
	 * @description Handles user selection of a row in the table view and shows modal.
	 */
	handleEventTableRowAction(event)
	{
		this.selectedEvent = event.detail.row;
		this.template.querySelector('c-modal').show();
	}

	/**
	 * @description Handles user selection of an event in the timeline view and shows modal.
	 */
	handleTimelineSelection(event)
	{
		this.selectedEvent = event.detail;
		this.template.querySelector('c-modal').show();
	}

	/**
	 * @description Clears the selectedEvent and hides modal.
	 */
	handleCloseEventModal()
	{
		this.selectedEvent = DEFAULT_EVENT_DATA;
	}

	// ── Internal Helpers ─────────────────────────────────────────────────

	/**
	 * @description Updates the channels list to show ALL active subscriptions
	 * (whether they have events or not).
	 */
	updateChannelsList()
	{
		if(this.activeSubscriptions && this.activeSubscriptions.length > 0)
		{
			const activeChannels = this.activeSubscriptions.map(sub => sub.channel);
			const uniqueChannels = [...new Set(activeChannels)];
			uniqueChannels.sort();
			this.channels = uniqueChannels;
		}
		else
		{
			this.channels = [];
		}
	}

	/**
	 * @description Updates the message shown when no events are visible.
	 */
	updateEmptyStateMessage()
	{
		if(this.activeSubscriptions.length === 0)
		{
			this.emptyStateMessage = 'Start by subscribing to events.';
		}
		else if(this.events.length === 0)
		{
			this.emptyStateMessage = 'Waiting for events...';
		}
		else if(!this.hasVisibleData)
		{
			this.emptyStateMessage = 'No events displayed. Try changing your filters.';
		}
		else
		{
			this.emptyStateMessage = null;
		}
	}

	/**
	 * @description Format timestamp in user's Salesforce timezone.
	 * Uses sv-SE locale for consistent YYYY-MM-DD HH:MM:SS format.
	 *
	 * @param {number} timestamp - Epoch milliseconds (UTC).
	 * @returns {string} Formatted datetime in user's Salesforce timezone.
	 */
	formatInUserTimezone(timestamp)
	{
		if(!timestamp)
		{
			return '';
		}
		if(!this.userTimezone)
		{
			const date = new Date(timestamp);
			return date.toLocaleString('sv-SE', {
				year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit'
			});
		}
		const date = new Date(timestamp);
		return date.toLocaleString('sv-SE', {
			timeZone: this.userTimezone, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit'
		});
	}

	/**
	 * @description Applies current filters to the `events` list and updates `filteredEvents`.
	 */
	applyFilters()
	{
		if(!this.activeSubscriptions || this.activeSubscriptions.length === 0)
		{
			this.filteredEvents = [];
			this.updateEmptyStateMessage();
			return;
		}

		this.filteredEvents = [...this.events].filter((event) => matchesFilter(event, this.filters));
		this.updateEmptyStateMessage();
	}
}