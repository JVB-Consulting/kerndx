// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) Philippe Ozil (CC0-1.0 — rights waived)
// Adapted from streaming-monitor (https://github.com/pozil/streaming-monitor)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description Lightning Web Component that provides filtering controls for event streams.
 *
 * This component allows filtering by:
 *   - Channel
 *   - Payload (with optional case sensitivity)
 *   - Before and After timestamp ranges
 *
 * The component exposes a public API property `channels` to receive available channel names.
 * It emits a `filter change` event whenever any filter value is updated, providing the following payload:
 * {
 *   channel: <string | undefined>,
 *   payload: <string | undefined>,
 *   isCaseSensitive: <boolean>,
 *   beforeTime: <epoch ms | undefined>,
 *   afterTime: <epoch ms | undefined>
 * }
 *
 * @date March 2026, May 2026
 */
import {LightningElement, api} from 'lwc';
import channelLabel from '@salesforce/label/c.EventMonitor_Filter_ChannelLabel';
import channelPlaceholder from '@salesforce/label/c.EventMonitor_Filter_ChannelPlaceholder';
import payloadLabel from '@salesforce/label/c.EventMonitor_Filter_PayloadLabel';
import payloadPlaceholder from '@salesforce/label/c.EventMonitor_Filter_PayloadPlaceholder';
import matchCase from '@salesforce/label/c.EventMonitor_Filter_MatchCase';
import afterToggle from '@salesforce/label/c.EventMonitor_Filter_AfterToggle';
import afterTimeLabel from '@salesforce/label/c.EventMonitor_Filter_AfterTimeLabel';
import beforeToggle from '@salesforce/label/c.EventMonitor_Filter_BeforeToggle';
import beforeTimeLabel from '@salesforce/label/c.EventMonitor_Filter_BeforeTimeLabel';
import clearFilters from '@salesforce/label/c.EventMonitor_Filter_ClearButton';

// ── Constants ────────────────────────────────────────────────────────────

const MS_PER_DAY = 24 * 60 * 60 * 1000;

// ── Helpers ──────────────────────────────────────────────────────────────

/**
 * @description Converts an ISO 8601 datetime string to UTC epoch milliseconds.
 *
 * @param {string} isoString - An ISO 8601 datetime string.
 * @returns {number} The corresponding UTC epoch time in milliseconds.
 */
function convertIsoToEpochMs(isoString)
{
	return new Date(isoString).getTime();
}

// ── Component ────────────────────────────────────────────────────────────

// eslint-disable-next-line kerndx/use-component-builder -- framework component extends LightningElement directly (no ComponentBuilder wrapper needed for this layer)
export default class StreamingEventFilters extends LightningElement
{
	// ── Internal State ───────────────────────────────────────────────────

	channelOptions = [];
	channel;
	payload;
	isCaseSensitive = false;
	beforeTimeEnabled = false;
	afterTimeEnabled = false;
	beforeTime;
	afterTime;

	labels = {
		channelLabel, channelPlaceholder, payloadLabel, payloadPlaceholder, matchCase, afterToggle, afterTimeLabel, beforeToggle, beforeTimeLabel, clearFilters
	};

	// ── @api Properties ──────────────────────────────────────────────────

	// noinspection JSUnusedGlobalSymbols
	get channels()
	{
		return this.channelOptions.map((channel) => channel.value);
	}

	/**
	 * @description channels (setter/getter): Receives a list of channel names from parent and converts to dropdown options.
	 */
	@api set channels(values)
	{
		this.channelOptions = values.map((channel) => ({
			label: channel, value: channel
		}));
	}

	/**
	 * @description Returns true if afterTime filter is inactive (used to disable UI input).
	 */
	get afterTimeDisabled()
	{
		return !this.afterTimeEnabled;
	}

	// ── Computed Properties ──────────────────────────────────────────────

	/**
	 * @description Returns true if beforeTime filter is inactive (used to disable UI input).
	 */
	get beforeTimeDisabled()
	{
		return !this.beforeTimeEnabled;
	}

	/**
	 * @description Clears the channel filter if it's not in the provided list of active channels.
	 *
	 * @param {Array<string>} activeChannels - List of currently active channel names.
	 */
	@api clearInvalidChannelFilter(activeChannels)
	{
		if(this.channel && !activeChannels.includes(this.channel))
		{
			this.channel = undefined;
			this.notifyFilterChange();
		}
	}

	// ── Lifecycle ────────────────────────────────────────────────────────

	/**
	 * @description Initializes `beforeTime` to now and `afterTime` to 24 hours before now.
	 */
	connectedCallback()
	{
		const now = new Date();
		const yesterday = new Date(now.getTime() - MS_PER_DAY);
		this.beforeTime = now.toISOString();
		this.afterTime = yesterday.toISOString();
	}

	// ── Event Handlers ───────────────────────────────────────────────────

	/**
	 * @description Updates channel filter and emits `filter change`.
	 */
	handleChannelChange(event)
	{
		this.channel = event.detail.value;
		this.notifyFilterChange();
	}

	/**
	 * @description Updates payload filter and emits `filter change`.
	 */
	handlePayloadChange(event)
	{
		this.payload = event.detail.value;
		this.notifyFilterChange();
	}

	/**
	 * @description Toggles case sensitivity for payload filter and emits `filter change`.
	 */
	handleIsCaseSensitiveChange(event)
	{
		this.isCaseSensitive = event.target.checked;
		this.notifyFilterChange();
	}

	/**
	 * @description Enables/disables the afterTime filter and emits `filter change`.
	 */
	handleAfterTimeToggle(event)
	{
		this.afterTimeEnabled = event.target.checked;
		this.notifyFilterChange();
	}

	/**
	 * @description Enables/disables the beforeTime filter and emits `filter change`.
	 */
	handleBeforeTimeToggle(event)
	{
		this.beforeTimeEnabled = event.target.checked;
		this.notifyFilterChange();
	}

	/**
	 * @description Updates the afterTime value and emits `filter change`.
	 */
	handleAfterTimeChange(event)
	{
		this.afterTime = event.detail.value;
		this.notifyFilterChange();
	}

	/**
	 * @description Updates the beforeTime value and emits `filter change`.
	 */
	handleBeforeTimeChange(event)
	{
		this.beforeTime = event.detail.value;
		this.notifyFilterChange();
	}

	/**
	 * @description Clears all filters and emits a `filter change` event.
	 */
	handleClearFilters()
	{
		this.channel = undefined;
		this.payload = undefined;
		this.isCaseSensitive = false;
		this.beforeTimeEnabled = false;
		this.afterTimeEnabled = false;
		this.beforeTime = undefined;
		this.afterTime = undefined;
		this.notifyFilterChange();
	}

	// ── Internal Helpers ─────────────────────────────────────────────────

	/**
	 * @description Dispatches a `filter change` event containing the normalized filter object.
	 * Converts datetime inputs to UTC epoch milliseconds for proper filtering.
	 */
	notifyFilterChange()
	{
		const payload = this.payload?.trim() || undefined;
		const beforeTime = this.beforeTimeEnabled && this.beforeTime ? convertIsoToEpochMs(this.beforeTime) : undefined;
		const afterTime = this.afterTimeEnabled && this.afterTime ? convertIsoToEpochMs(this.afterTime) : undefined;
		const filters = {
			channel: this.channel, payload, isCaseSensitive: this.isCaseSensitive, beforeTime, afterTime
		};
		const filterEvent = new CustomEvent('filterchange', {
			detail: filters
		});
		this.dispatchEvent(filterEvent);
	}
}