// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) Philippe Ozil (CC0-1.0 — rights waived)
// Adapted from streaming-monitor (https://github.com/pozil/streaming-monitor)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description Streaming API utilities for LWC — event type registry, channel classification,
 * payload normalisation, timestamp formatting, and sort comparators.
 *
 * @author Jason van Beukering
 *
 * @date March 2026, May 2026
 */

// ── Channel Constants ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

/** @description Subscribes to all standard and custom Change Data Capture events. */
export const CHANNEL_ALL_CDC = '/data/ChangeEvents';

// ── Event Type Constants ────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

export const EVT_CDC = 'ChangeDataCaptureEvent';
export const EVT_CUSTOM_CHANNEL_CDC = 'CustomChannelCDC';
export const EVT_CUSTOM_CHANNEL_PE = 'CustomChannelPE';
export const EVT_GENERIC = 'GenericEvent';
export const EVT_MONITORING = 'MonitoringEvent';
export const EVT_PLATFORM_EVENT = 'PlatformEvent';
export const EVT_PUSH_TOPIC = 'PushTopicEvent';
export const EVT_STD_PLATFORM_EVENT = 'StandardPlatformEvent';

// ── Filter Constants ────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

export const FILTER_ALL = 'all';
export const FILTER_CUSTOM = 'custom';

// ── Event Registry ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

/**
 * @description Central lookup for streaming event type metadata. Each entry provides a
 * human-readable label, the CometD channel prefix, and a predicate that determines
 * whether a given channel is subscriber-created (custom) or platform-provided.
 *
 * @private
 * @type {Readonly<Object<string, {label: string, channelPrefix: string, isCustom: function(string): boolean}>>}
 */
const REGISTRY = Object.freeze({
	[EVT_PUSH_TOPIC]: {label: 'PushTopic event', channelPrefix: '/topic/', isCustom: () => true},
	[EVT_GENERIC]: {label: 'Generic event', channelPrefix: '/u/', isCustom: () => true},
	[EVT_STD_PLATFORM_EVENT]: {label: 'Standard Platform event', channelPrefix: '/event/', isCustom: () => false},
	[EVT_PLATFORM_EVENT]: {label: 'Custom Platform event', channelPrefix: '/event/', isCustom: (ch) => typeof ch === 'string' && ch.endsWith('__e')},
	[EVT_CDC]: {label: 'Change Data Capture event', channelPrefix: '/data/', isCustom: (ch) => typeof ch === 'string' && ch.endsWith('__ChangeEvent')},
	[EVT_CUSTOM_CHANNEL_PE]: {label: 'Custom Channel - Platform event', channelPrefix: '/event/', isCustom: () => true},
	[EVT_CUSTOM_CHANNEL_CDC]: {label: 'Custom Channel - Change event', channelPrefix: '/data/', isCustom: () => true},
	[EVT_MONITORING]: {label: 'Monitoring event', channelPrefix: '/event/', isCustom: () => false}
});

/**
 * @description Flat array of event types for populating combo-boxes.
 * Each entry includes `label`, `value` (the EVT_* constant), and `channelPrefix`.
 * @type {ReadonlyArray<{label: string, value: string, channelPrefix: string}>}
 */
export const EVENT_TYPES = Object.freeze(Object.entries(REGISTRY).map(([key, definition]) => ({
	label: definition.label, value: key, channelPrefix: definition.channelPrefix
})));

// ── Channel Helpers ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

/**
 * @description Resolves the registry entry for an event type, throwing if not found.
 * @param {string} eventType - One of the EVT_* constants
 * @returns {{label: string, channelPrefix: string, isCustom: function(string): boolean}}
 * @throws {Error} When the event type is unrecognised
 * @private
 */
function resolveDefinition(eventType)
{
	const definition = REGISTRY[eventType];
	if(!definition)
	{
		throw new Error(`Unsupported event type: ${eventType}`);
	}
	return definition;
}

/**
 * @description Returns the CometD channel prefix for the given event type.
 * @param {string} eventType - One of the EVT_* constants
 * @returns {string} Channel prefix (e.g. '/topic/')
 * @throws {Error} When the event type is unrecognised
 */
export function getChannelPrefix(eventType)
{
	return resolveDefinition(eventType).channelPrefix;
}

/**
 * @description Tests whether a channel path represents a CDC subscription.
 * @param {string} channel - Full channel path (e.g. '/data/AccountChangeEvent')
 * @returns {boolean}
 */
export function isCDCChannel(channel)
{
	return typeof channel === 'string' && channel.startsWith('/data/');
}

/**
 * @description Determines whether a channel is subscriber-defined (custom) based on
 * the event type's classification rules.
 *
 * @param {string} eventType - One of the EVT_* constants
 * @param {string} channel - Full channel name
 * @returns {boolean}
 * @throws {Error} When the event type is unrecognised
 */
export function isCustomChannel(eventType, channel)
{
	return resolveDefinition(eventType).isCustom(channel);
}

// ── Event Normalisation ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

/**
 * @typedef {Object} NormalizedEvent
 * @property {string} id - Unique composite key (schema/channel + replayId)
 * @property {number|null} timestamp - Epoch milliseconds
 * @property {string|null} timeLabel - Human-readable local time string
 * @property {string} channel - Source channel
 * @property {number} replayId - Streaming replay ID
 * @property {string} type - Descriptive type label
 * @property {string} payload - JSON-serialised event payload
 */

/**
 * @description Classifies a raw streaming event into a human-readable type label.
 * @param {Object} eventData - The `data` property from the CometD message
 * @param {Object|null} payload - The resolved payload object
 * @returns {string} Descriptive type string
 * @private
 */
function classifyEventType(eventData, payload)
{
	if(eventData?.event?.type)
	{
		return `PushTopic: ${eventData.event.type}`;
	}
	if(eventData?.event?.createdDate)
	{
		return 'Generic';
	}
	if(payload?.ChangeEventHeader)
	{
		return `Change Event: ${payload.ChangeEventHeader.entityName} ${payload.ChangeEventHeader.changeType}`;
	}
	if(payload?.CreatedDate)
	{
		return 'Platform Event';
	}
	return 'Unknown Event';
}

/**
 * @description Converts a raw CometD streaming event into a consistent, flat structure
 * suitable for display in data tables and timelines.
 *
 * @param {Object} event - Raw CometD event message
 * @returns {NormalizedEvent}
 */
export function normalizeEvent(event)
{
	const eventData = event?.data;
	const payload = eventData?.payload ?? eventData?.sobject ?? null;
	const replayId = eventData?.event?.replayId;
	const channel = event?.channel;
	const schema = eventData?.schema;

	const id = (schema ?? channel) + replayId;

	const rawTimestamp = eventData?.event?.createdDate ?? payload?.ChangeEventHeader?.commitTimestamp ?? payload?.CreatedDate;

	const eventTime = rawTimestamp ? new Date(rawTimestamp) : null;

	return {
		id,
		timestamp: eventTime?.getTime() ?? null,
		timeLabel: eventTime ? getTimeLabel(eventTime) : null,
		channel,
		replayId,
		type: classifyEventType(eventData, payload),
		payload: JSON.stringify(payload)
	};
}

// ── Time Formatting ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

/** @description Default locale producing YYYY-MM-DD HH:MM:SS format. */
const ISO_LIKE_LOCALE = 'sv-SE';

/** @description Base Intl.DateTimeFormat options for full timestamp display. */
const BASE_FORMAT_OPTIONS = Object.freeze({
	year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit'
});

/**
 * @description Formats a Date or epoch-ms value into a human-readable timestamp string.
 * Defaults to `sv-SE` locale (ISO-like) unless a Salesforce locale is provided, in which
 * case English is used with the locale's 12/24-hour preference.
 *
 * @param {Date|number} time - Date object or epoch milliseconds
 * @param {string} [timeZone] - IANA timezone (e.g. 'America/Los_Angeles')
 * @param {string} [locale] - Salesforce locale (e.g. 'en_US', 'en_ZA')
 * @returns {string} Formatted timestamp, or empty string if input is invalid
 */
export function getTimeLabel(time, timeZone, locale)
{
	const date = time instanceof Date ? time : typeof time === 'number' ? new Date(time) : null;

	if(!date)
	{
		return '';
	}

	const options = {...BASE_FORMAT_OPTIONS};
	let displayLocale = ISO_LIKE_LOCALE;

	if(locale)
	{
		const normalisedLocale = locale.replace('_', '-');
		const probe = new Date(2025, 0, 1, 13, 0, 0);
		const formatted = probe.toLocaleString(normalisedLocale, {hour: 'numeric'});
		const is24Hour = !formatted.includes('PM') && !formatted.includes('AM');

		displayLocale = 'en-US';
		options.hour12 = !is24Hour;
	}

	if(timeZone)
	{
		options.timeZone = timeZone;
	}

	return date.toLocaleString(displayLocale, options);
}

// ── Sort Comparators ────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

/**
 * @description Case-insensitive alphabetical comparator on the `channel` property.
 * @param {{channel?: string}} a
 * @param {{channel?: string}} b
 * @returns {number}
 */
export function channelSort(a, b)
{
	return (a?.channel ?? '').localeCompare(b?.channel ?? '', undefined, {sensitivity: 'base'});
}

/**
 * @description Numeric comparator on the `timestamp` property (ascending).
 * @param {{timestamp?: number}} a
 * @param {{timestamp?: number}} b
 * @returns {number}
 */
export function timestampSort(a, b)
{
	return (a?.timestamp ?? 0) - (b?.timestamp ?? 0);
}

// ── String Helpers ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

/**
 * @description Converts a slug-style string (underscores/hyphens) to Title Case.
 * @param {string} original - Input string (e.g. 'hello_world')
 * @returns {string} Title-cased output (e.g. 'Hello World')
 */
export function toTitleCase(original)
{
	if(typeof original !== 'string' || !original)
	{
		return '';
	}

	return original
	.replaceAll(/[-_]/g, ' ')
	.replace(/\w\S*/g, (word) => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase());
}