// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Live activity stream for one chain execution: seeds the recent persisted log
 * entries for the chain, then appends matching LogEntryEvent__e deliveries live. Entries render
 * newest first (the live tail on top, seeded history beneath), capped to a rolling window.
 * Only errors are guaranteed to stream; other levels depend on the org's log settings, and the
 * caveat line says so. A broken event feed flips the visible disconnected notice in place of the
 * caveat; entries still persist server-side. The component reads only; it performs no writes.
 *
 * @author Jason van Beukering
 *
 * @date August 2026, October 2026
 */
import {api} from 'lwc';
import {ComponentBuilder} from 'c/componentBuilder';
import {subscribe, unsubscribe, onError} from 'lightning/empApi';
import getChainLogEntries from '@salesforce/apex/CTRL_ChainMonitor.getChainLogEntries';
import getNamespacePrefix from '@salesforce/apex/CTRL_ChainMonitor.getNamespacePrefix';
import streamTitle from '@salesforce/label/c.ChainMonitor_LogStreamTitle';
import streamEmpty from '@salesforce/label/c.ChainMonitor_LogStreamEmpty';
import streamCaveat from '@salesforce/label/c.ChainMonitor_LogStreamCaveat';
import streamDisconnected from '@salesforce/label/c.ChainMonitor_LogStreamDisconnected';
import streamLastEvent from '@salesforce/label/c.ChainMonitor_LogStreamLastEvent';

const LOG_ENTRY_EVENT_OBJECT_NAME = 'LogEntryEvent__e';
const RECORD_ID_FIELD_NAME = 'RecordId__c';
const CORRELATION_ID_FIELD_NAME = 'CorrelationId__c';
const SHORT_MESSAGE_FIELD_NAME = 'ShortMessage__c';
const MESSAGE_FIELD_NAME = 'Message__c';
const LOG_LEVEL_FIELD_NAME = 'LogLevel__c';
const MAXIMUM_RENDERED_ENTRIES = 100;
const ERROR_LOG_LEVEL = 'ERROR';
const FAILED_CHAIN_STATUS = 'Failed';

// The acknowledgement the platform requires when a subscription is dropped: empApi hands its second
// argument on as the callback, and called with one argument it raises "Invalid or missing callback"
// while the page is being torn down. Nothing is left to do once the subscription is gone, so the
// platform's answer is taken and dropped.
const acknowledgeUnsubscribe = () => null;

// An instant as epoch milliseconds for `lightning-relative-date-time`, which does not parse the
// ISO-8601 string an Apex Datetime (and a platform-event CreatedDate) arrives as; null stays null.
function toEpochMilliseconds(instant)
{
	return instant ? new Date(instant).getTime() : null;
}

export default class ChainLogStream extends ComponentBuilder('controller', 'notification')
{
	currentExecutionId = null;
	liveEntries = [];
	seedEntries = [];
	isDisconnected = false;
	subscription = null;
	connectionGeneration = 0;
	namespacePrefix = '';
	collapsedOverride = null;
	liveEntryCounter = 0;

	label = {
		streamTitle, streamEmpty, streamCaveat, streamDisconnected, lastEvent: streamLastEvent
	};

	/**
	 * @description The chain's current status; a Failed chain collapses the stream by default so
	 * the error section keeps the operator's attention (the validated prototype's P12 decision).
	 *
	 * @type {string}
	 */
	@api chainStatus;

	/**
	 * @description The chain's correlation ID: the stream's second matching key, so entries
	 * logged by the chain's steps stream even when they carry no record reference.
	 *
	 * @type {string}
	 */
	@api correlationId;

	@api get executionId()
	{
		return this.currentExecutionId;
	}

	set executionId(value)
	{
		if(value === this.currentExecutionId)
		{
			return;
		}
		this.currentExecutionId = value;
		this.liveEntries = [];
		this.seedEntries = [];
		this.collapsedOverride = null;
		if(value)
		{
			// noinspection JSIgnoredPromiseFromCall
			this.loadSeedEntries();
		}
	}

	get isCollapsed()
	{
		return this.collapsedOverride ?? (this.chainStatus === FAILED_CHAIN_STATUS);
	}

	get isExpandedText()
	{
		return String(!this.isCollapsed);
	}

	get chevronIconName()
	{
		return this.isCollapsed ? 'utility:chevronright' : 'utility:chevrondown';
	}

	get renderedEntries()
	{
		return [
			...this.liveEntries,
			...this.seedEntries
		].slice(0, MAXIMUM_RENDERED_ENTRIES);
	}

	get hasEntries()
	{
		return this.renderedEntries.length > 0;
	}

	get lastEventEpochMilliseconds()
	{
		return this.renderedEntries[0]?.epochMilliseconds;
	}

	handleToggle()
	{
		this.collapsedOverride = !this.isCollapsed;
	}

	connectedCallback()
	{
		this.connectionGeneration++;
		// noinspection JSIgnoredPromiseFromCall
		this.subscribeToEvents(this.connectionGeneration);
		onError(() =>
		{
			// The empApi error callback is the only signal the feed broke; entries still record
			// server-side, so the notice tells the operator to refresh rather than to worry.
			this.isDisconnected = true;
		});
	}

	disconnectedCallback()
	{
		// Advancing the generation invalidates any subscribe still in flight from the connection
		// being torn down; a plain disconnected flag cannot, because an immediate reconnect
		// resets it and lets the stale run register a second, orphaned subscription.
		this.connectionGeneration++;
		this.unsubscribeFromEvents();
	}

	async subscribeToEvents(generation)
	{
		try
		{
			// The channel and payload keys carry the package namespace only in a managed install
			// ('kern__'), not in an unmanaged (no-namespace) deploy. It is resolved inside the try so
			// a failure degrades to the seeded-history view without surfacing a toast.
			this.namespacePrefix = await getNamespacePrefix() ?? '';
			// A disconnect, or a disconnect/reconnect cycle, can happen while either await in
			// this method is in flight; a continuation from a superseded connection would
			// register a subscription nothing tears down for the page session.
			if(generation !== this.connectionGeneration)
			{
				return;
			}
			const subscription = await subscribe(`/event/${this.namespacePrefix}${LOG_ENTRY_EVENT_OBJECT_NAME}`, -1, (event) =>
			{
				this.handleStreamingEvent(event);
			});
			if(generation !== this.connectionGeneration)
			{
				unsubscribe(subscription, acknowledgeUnsubscribe);
				return;
			}
			this.subscription = subscription;
		}
		catch(error)
		{
			this.consoleError(error, 'ChainLogStream.subscribeToEvents');
			this.isDisconnected = true;
		}
	}

	unsubscribeFromEvents()
	{
		if(this.subscription)
		{
			unsubscribe(this.subscription, acknowledgeUnsubscribe);
			this.subscription = null;
		}
	}

	handleStreamingEvent(event)
	{
		const payload = event?.data?.payload;
		if(!payload || !this.matchesThisChain(payload))
		{
			return;
		}
		const entry = this.buildEntry(payload.CreatedDate, payload[`${this.namespacePrefix}${LOG_LEVEL_FIELD_NAME}`],
				payload[`${this.namespacePrefix}${SHORT_MESSAGE_FIELD_NAME}`] ?? payload[`${this.namespacePrefix}${MESSAGE_FIELD_NAME}`], `live-${++this.liveEntryCounter}`);
		if(this.isDuplicateOfSeed(entry))
		{
			return;
		}
		this.liveEntries = [
			entry,
			...this.liveEntries
		].slice(0, MAXIMUM_RENDERED_ENTRIES);
	}

	matchesThisChain(payload)
	{
		const recordId = payload[`${this.namespacePrefix}${RECORD_ID_FIELD_NAME}`];
		const correlationId = payload[`${this.namespacePrefix}${CORRELATION_ID_FIELD_NAME}`];
		return (this.currentExecutionId != null && recordId === this.currentExecutionId) || (this.correlationId != null && correlationId === this.correlationId);
	}

	async loadSeedEntries()
	{
		const requestedExecutionId = this.currentExecutionId;
		const rows = await this.callControllerMethod(getChainLogEntries, {executionId: requestedExecutionId});
		// The selection can move on while the seed read is in flight; a stale response must not
		// replace the newer chain's history.
		if(!rows || requestedExecutionId !== this.currentExecutionId)
		{
			return;
		}
		const liveKeys = new Set(this.liveEntries.map((entry) => entry.deduplicationKey));
		// The seed endpoint returns its rows OLDEST-first (getChainLogEntries reads the correlated
		// trace in ascending order); the stream renders newest-first, so the seed reverses.
		this.seedEntries = [...rows]
		.reverse()
		.map((row, index) => this.buildEntry(row.timestamp, row.logLevel, row.message, `seed-${requestedExecutionId}-${index}`))
		.filter((entry) => !liveKeys.has(entry.deduplicationKey));
	}

	buildEntry(timestamp, logLevel, message, key)
	{
		const level = logLevel ?? '';
		return {
			key,
			timestamp,
			epochMilliseconds: toEpochMilliseconds(timestamp),
			logLevel: level,
			message: message ?? '',
			deduplicationKey: `${timestamp}|${message ?? ''}`,
			rowClass: level === ERROR_LOG_LEVEL ? 'stream-row stream-row_error' : 'stream-row',
			badgeClass: level === ERROR_LOG_LEVEL ? 'slds-theme_error' : ''
		};
	}

	isDuplicateOfSeed(entry)
	{
		return this.seedEntries.some((seedEntry) => seedEntry.deduplicationKey === entry.deduplicationKey);
	}
}