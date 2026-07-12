// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) Philippe Ozil (CC0-1.0 — rights waived)
// Adapted from streaming-monitor (https://github.com/pozil/streaming-monitor)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description Lightning Web Component providing header controls for event management pages.
 * Allows users to:
 *   - Switch between view modes (Table or Timeline)
 *   - Toggle visibility of filters
 *   - Clear all filters
 *   - Trigger data download
 *
 * The component emits events to communicate user actions to parent components.
 *
 * @date March 2026, July 2026
 */
import {LightningElement} from 'lwc';
import viewTable from '@salesforce/label/c.EventUsageMetrics_View_Table';
import viewTimeline from '@salesforce/label/c.EventMonitor_View_Timeline';
import clearEvents from '@salesforce/label/c.EventMonitor_Header_ClearEvents';
import displayAs from '@salesforce/label/c.EventMonitor_Header_DisplayAs';

// ── Constants ────────────────────────────────────────────────────────────

const VIEW_MODE_TABLE = 'table';
const VIEW_MODE_TIMELINE = 'timeline';
const VIEW_MODES = [
	{label: viewTable, value: VIEW_MODE_TABLE, iconName: 'utility:table'},
	{label: viewTimeline, value: VIEW_MODE_TIMELINE, iconName: 'utility:metrics'}
];

// ── Component ────────────────────────────────────────────────────────────

// eslint-disable-next-line kerndx/use-component-builder -- framework component extends LightningElement directly (no ComponentBuilder wrapper needed for this layer)
export default class StreamingEventsHeader extends LightningElement
{
	// ── Internal State ───────────────────────────────────────────────────

	// The default must match the parent's (c-streaming-events) initial view, which renders the
	// timeline first, so the 'Display as' icon is correct on first load.
	viewMode = VIEW_MODE_TIMELINE;
	viewModes = VIEW_MODES;
	isFiltersDisplayed = true;

	label = {
		clearEvents, displayAs
	};

	// ── Computed Properties ──────────────────────────────────────────────

	/**
	 * @description Returns the icon name for the currently selected view mode.
	 *
	 * @returns {string} The SLDS icon name for the active view mode.
	 */
	get viewModeIconName()
	{
		const selectedOption = this.viewModes.find((option) => option.value === this.viewMode);
		return selectedOption.iconName;
	}

	// ── Event Handlers ───────────────────────────────────────────────────

	/**
	 * @description Dispatches a 'clear' event to notify the parent to clear all filters.
	 */
	handleClear()
	{
		this.dispatchEvent(new CustomEvent('clear'));
	}

	/**
	 * @description Dispatches a 'download' event to trigger data export.
	 */
	handleDownload()
	{
		this.dispatchEvent(new CustomEvent('download'));
	}

	/**
	 * @description Toggles the `isFiltersDisplayed` state and emits a 'filtertoggle' event.
	 */
	handleFiltersDisplayToggle()
	{
		this.isFiltersDisplayed = !this.isFiltersDisplayed;
		const event = new CustomEvent('filtertoggle', {
			detail: {value: this.isFiltersDisplayed}
		});
		this.dispatchEvent(event);
	}

	/**
	 * @description Updates the selected `viewMode` and emits a 'viewmodechange' event.
	 *
	 * @param {CustomEvent} event - The selection event from the button menu.
	 */
	handleViewModeSelect(event)
	{
		this.viewMode = event.detail.value;
		this.updateViewModeSelection();
		const changeEvent = new CustomEvent('viewmodechange', {
			detail: {value: this.viewMode}
		});
		this.dispatchEvent(changeEvent);
	}

	// ── Internal Helpers ─────────────────────────────────────────────────

	/**
	 * @description Updates the `checked` property on each view mode option
	 * using immutable spread to avoid mutating existing objects.
	 */
	updateViewModeSelection()
	{
		this.viewModes = this.viewModes.map((option) => ({...option, checked: option.value === this.viewMode}));
	}
}