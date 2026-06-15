// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) Philippe Ozil (CC0-1.0 — rights waived)
// Adapted from streaming-monitor (https://github.com/pozil/streaming-monitor)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description
 * The Subscriptions component displays and manages a list of active
 * event-streaming subscriptions. It exposes actions that allow a parent component
 * to unsubscribe from a single channel or unsubscribe from all channels.
 *
 * @date March 2026, May 2026
 */
import {LightningElement, api} from 'lwc';

// eslint-disable-next-line kerndx/use-component-builder -- framework component extends LightningElement directly (no ComponentBuilder wrapper needed for this layer)
export default class StreamingSubscriptions extends LightningElement
{
	// ── @api Properties ──────────────────────────────────────────────────

	/**
	 * @api subscriptions
	 * @type {Array}
	 * @description
	 * A list of active subscription objects passed from the parent component.
	 * Each entry typically includes the channel name and the underlying
	 * subscription reference used by the Streaming API.
	 */
	@api subscriptions;

	// ── Computed Properties ──────────────────────────────────────────────

	/**
	 * @description
	 * Returns the number of active subscriptions.
	 *
	 * @type {number}
	 */
	get subscriptionCount()
	{
		return this.subscriptions.length;
	}

	// ── Event Handlers ───────────────────────────────────────────────────

	/**
	 * @description
	 * Handles user-triggered unsubscribe actions for a specific channel.
	 * Reads the channel name from the clicked button and dispatches an
	 * 'unsubscribe' event for the parent component to process.
	 *
	 * @param {Event} event - The click event containing the target channel name.
	 */
	handleUnsubscribe(event)
	{
		const channel = event.target.name;
		const unsubscribeEvent = new CustomEvent('unsubscribe', {
			detail: {channel}
		});
		this.dispatchEvent(unsubscribeEvent);
	}

	/**
	 * @description
	 * Dispatches an event instructing the parent component to unsubscribe from
	 * every active channel in the list. No parameters are required.
	 */
	handleUnsubscribeAll()
	{
		this.dispatchEvent(new CustomEvent('unsubscribeall'));
	}
}