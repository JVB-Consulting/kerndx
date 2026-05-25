// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) Philippe Ozil (CC0-1.0 — rights waived)
// Adapted from streaming-monitor (https://github.com/pozil/streaming-monitor)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description LWC component that manages filter controls for Event Usage Metrics.
 * Provides UI and reactive logic for filtering event data based on:
 * - Before timestamp
 * - After timestamp
 * - Event type selections with color-coded chips
 *
 * The component exposes a public `eventTypes` API property that accepts
 * an array of objects containing event type metadata. Each type is internally
 * transformed into a selectable option with color styling and default checked state.
 *
 * Whenever a filter value changes, the component emits a `filter change` event
 * containing a normalized filter object:
 * {
 *    beforeTime: <epoch ms | undefined>,
 *    afterTime: <epoch ms | undefined>,
 *    eventTypes: <boolean[] representing checkbox states>
 * }
 *
 * This component is intended to be used inside dashboards or analytics pages
 * that require client-side filtering of metric datasets.
 */
import {LightningElement, api, track} from 'lwc';

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
export default class StreamingUsageFilters extends LightningElement
{
	// ── Internal State ───────────────────────────────────────────────────

	/**
	 * @description Indicates if the "before" time filter is active/enabled.
	 * When false, `beforeTime` is ignored.
	 * @type {boolean}
	 */
	beforeTimeEnabled = false;

	/**
	 * @description Indicates if the "after" time filter is active/enabled.
	 * When false, `afterTime` is ignored.
	 * @type {boolean}
	 */
	afterTimeEnabled = false;

	/**
	 * @description Holds ISO timestamp value used for the "before" time filter.
	 * Managed via UI input events.
	 * @type {string}
	 */
	beforeTime;

	/**
	 * @description Holds ISO timestamp value used for the "after" time filter.
	 * Managed via UI input events.
	 * @type {string}
	 */
	afterTime;

	/**
	 * @description Internal representation of event types. Each item contains:
	 * - label / value from API
	 * - assigned color
	 * - dynamically created CSS background-color styling
	 * - checked (boolean) selection state
	 * @type {Array<Object>}
	 */
	@track eventTypeOptions = [];

	// ── @api Properties ──────────────────────────────────────────────────

	/**
	 * @description Getter for the event types list.
	 * @returns {Array<Object>}
	 */
	// noinspection JSUnusedGlobalSymbols
	get eventTypes()
	{
		return this.eventTypeOptions;
	}

	/**
	 * @description Public API property to receive event type metadata from parent.
	 * Each type is converted into an option with default checked=true and
	 * color styling included.
	 */
	@api set eventTypes(value)
	{
		this.eventTypeOptions = value.map((e) =>
		{
			const option = {...e};
			option.style = `background-color: ${option.color};`;
			option.checked = true;
			return option;
		});
	}

	// ── Computed Properties ──────────────────────────────────────────────

	/**
	 * @description Whether the "after" timestamp input field should be disabled.
	 * @returns {boolean}
	 */
	get afterTimeDisabled()
	{
		return !this.afterTimeEnabled;
	}

	/**
	 * @description Whether the "before" timestamp input field should be disabled.
	 * @returns {boolean}
	 */
	get beforeTimeDisabled()
	{
		return !this.beforeTimeEnabled;
	}

	// ── Lifecycle ────────────────────────────────────────────────────────

	/**
	 * @description Lifecycle hook that initializes default timestamp ranges.
	 * Sets:
	 * - `beforeTime` to the current top-of-hour
	 * - `afterTime` to exactly 24 hours before `beforeTime`
	 */
	connectedCallback()
	{
		const now = new Date();
		now.setMinutes(0);
		const yesterday = new Date(now.getTime() - MS_PER_DAY);
		this.beforeTime = now.toISOString();
		this.afterTime = yesterday.toISOString();
	}

	// ── Event Handlers ───────────────────────────────────────────────────

	/**
	 * @description Toggles whether the "after" timestamp filter is active.
	 * @param {Event} event Change event from checkbox
	 */
	handleAfterTimeToggle(event)
	{
		this.afterTimeEnabled = event.target.checked;
		this.notifyFilterChange();
	}

	/**
	 * @description Toggles whether the "before" timestamp filter is active.
	 * @param {Event} event Change event from checkbox
	 */
	handleBeforeTimeToggle(event)
	{
		this.beforeTimeEnabled = event.target.checked;
		this.notifyFilterChange();
	}

	/**
	 * @description Handler for updating the "after" timestamp value.
	 * @param {CustomEvent} event Change event with detail value
	 */
	handleAfterTimeChange(event)
	{
		this.afterTime = event.detail.value;
		this.notifyFilterChange();
	}

	/**
	 * @description Handler for updating the "before" timestamp value.
	 * @param {CustomEvent} event Change event with detail.value
	 */
	handleBeforeTimeChange(event)
	{
		this.beforeTime = event.detail.value;
		this.notifyFilterChange();
	}

	/**
	 * @description Handles toggling of event type checkbox states.
	 * Determines the index from the dataset property and updates selection.
	 * @param {Event} event Change event from checkbox
	 */
	handleEventTypeToggle(event)
	{
		const {checked} = event.target;
		const {index} = event.target.dataset;
		this.eventTypeOptions[index].checked = checked;
		this.notifyFilterChange();
	}

	/**
	 * @description Clears all filter controls, resets timestamps and event type selections,
	 * and re-emits a filter change event.
	 */
	handleClearFilters()
	{
		this.beforeTimeEnabled = false;
		this.afterTimeEnabled = false;
		this.beforeTime = undefined;
		this.afterTime = undefined;

		this.eventTypeOptions = this.eventTypeOptions.map((option) => ({...option, checked: true}));

		this.notifyFilterChange();
	}

	// ── Internal Helpers ─────────────────────────────────────────────────

	/**
	 * @description Dispatches a unified `filter change` event whenever any filter changes.
	 * Converts ISO timestamps to epoch milliseconds and builds the filter payload.
	 * The parent component is expected to listen and re-filter its dataset.
	 */
	notifyFilterChange()
	{
		const beforeTime = this.beforeTimeEnabled && this.beforeTime ? convertIsoToEpochMs(this.beforeTime) : undefined;
		const afterTime = this.afterTimeEnabled && this.afterTime ? convertIsoToEpochMs(this.afterTime) : undefined;
		const eventTypes = this.eventTypeOptions.map((e) => e.checked);

		const filters = {beforeTime, afterTime, eventTypes};

		this.dispatchEvent(new CustomEvent('filterchange', {detail: filters}));
	}
}