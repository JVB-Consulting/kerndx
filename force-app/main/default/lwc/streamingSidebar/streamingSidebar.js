// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) Philippe Ozil (CC0-1.0 — rights waived)
// Adapted from streaming-monitor (https://github.com/pozil/streaming-monitor)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description Lightning Web Component representing the sidebar navigation panel
 * used within the Streaming Monitor application.
 * It controls visibility of the sidebar and dispatches navigation
 * and toggle events to the parent component.
 *
 * @date March 2026, May 2026
 */
import {LightningElement, api} from 'lwc';

// eslint-disable-next-line kerndx/use-component-builder -- framework component extends LightningElement directly (no ComponentBuilder wrapper needed for this layer)
export default class StreamingSidebar extends LightningElement
{
	// ── Internal State ───────────────────────────────────────────────────

	isSidebarVisible = true;
	lastSelectedItem;

	// ── @api Properties ──────────────────────────────────────────────────

	/**
	 * @description Represents the currently selected navigation item.
	 * Passed from the parent component.
	 * @type {string}
	 */
	@api selectedItem = 'monitor';

	// ── Computed Properties ──────────────────────────────────────────────

	/**
	 * @description Returns whether the sidebar is currently hidden.
	 * Useful for conditionally rendering UI logic.
	 * @returns {boolean}
	 */
	get isSidebarHidden()
	{
		return !this.isSidebarVisible;
	}

	/**
	 * @description Computes the CSS classes for the split view container
	 * based on whether the sidebar is open or closed.
	 *
	 * @returns {string} - CSS classes for layout control.
	 */
	get splitViewContainerClasses()
	{
		return `slds-split-view_container slds-is-${this.isSidebarVisible ? 'open' : 'closed'}`;
	}

	/**
	 * @description Computes the classes for the toggle button icon,
	 * switching between open/closed states.
	 *
	 * @returns {string} - CSS classes for the toggle button.
	 */
	get toggleButtonClasses()
	{
		return `slds-button slds-button_icon slds-button_icon slds-split-view__toggle-button slds-is-${this.isSidebarVisible ? 'open' : 'closed'}`;
	}

	// ── Event Handlers ───────────────────────────────────────────────────

	/**
	 * @description Toggles the visibility of the sidebar.
	 * Dispatches a 'toggle' CustomEvent notifying the parent
	 * whether the sidebar is now visible or hidden.
	 */
	handleToggleSidebar()
	{
		this.isSidebarVisible = !this.isSidebarVisible;
		const toggleEvent = new CustomEvent('toggle', {
			detail: this.isSidebarVisible
		});
		this.dispatchEvent(toggleEvent);
	}

	/**
	 * @description Handles user selection from the sidebar navigation menu.
	 * If the selected item differs from the current active item,
	 * emits a 'navigate' event to the parent component with the
	 * selected menu name.
	 *
	 * @param {CustomEvent} event - The selection event from the menu item.
	 */
	handleMenuSelect(event)
	{
		const selection = event.detail.name;
		if(selection !== this.lastSelectedItem)
		{
			const navigateEvent = new CustomEvent('navigate', {
				detail: selection
			});
			this.dispatchEvent(navigateEvent);
			this.lastSelectedItem = selection;
		}
	}
}