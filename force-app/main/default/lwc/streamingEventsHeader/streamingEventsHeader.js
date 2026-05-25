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
 */
import {LightningElement} from 'lwc';

// ── Constants ────────────────────────────────────────────────────────────

const VIEW_MODE_TABLE = 'table';
const VIEW_MODE_TIMELINE = 'timeline';
const VIEW_MODES = [
	{label: 'Table', value: VIEW_MODE_TABLE, iconName: 'utility:table'},
	{label: 'Timeline', value: VIEW_MODE_TIMELINE, iconName: 'utility:metrics'}
];

// ── Component ────────────────────────────────────────────────────────────

// eslint-disable-next-line kerndx/use-component-builder -- framework component extends LightningElement directly (no ComponentBuilder wrapper needed for this layer)
export default class StreamingEventsHeader extends LightningElement
{
	// ── Internal State ───────────────────────────────────────────────────

	viewMode = VIEW_MODE_TABLE;
	viewModes = VIEW_MODES;
	isFiltersDisplayed = true;

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