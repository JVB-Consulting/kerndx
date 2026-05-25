// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) Philippe Ozil (CC0-1.0 — rights waived)
// Adapted from streaming-monitor (https://github.com/pozil/streaming-monitor)
// Modifications copyright (c) 2026 JVB Consulting

/* eslint-disable @lwc/lwc/no-async-operation */
//noinspection FunctionWithMultipleReturnPointsJS

/**
 * @description
 * Main controller component for the Streaming API Monitor app.
 * Handles subscribing, publishing, tracking events,
 * UI navigation, error handling and rendering logic.
 */
import {LightningElement, track} from 'lwc';
import {
	subscribe, unsubscribe, onError, setDebugFlag
} from 'lightning/empApi';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';
import getAllEventChannels from '@salesforce/apex/CTRL_EventMonitor.getAllEventChannels';
import publishStreamingEvent from '@salesforce/apex/CTRL_EventMonitor.publishStreamingEvent';
import {
	EVENT_TYPES, EVT_CDC, CHANNEL_ALL_CDC, FILTER_CUSTOM, FILTER_ALL, isCDCChannel, getChannelPrefix, normalizeEvent, channelSort, isCustomChannel
} from 'c/utilityStreaming';
import utilityLogger from 'c/utilityLogger';

// ── Constants ────────────────────────────────────────────────────────────

const RESIZE_DEBOUNCE_MS = 200;
const SUBSCRIBE_ERROR_SUPPRESSION_MS = 4000;

const VIEW_MODES = {
	MONITOR: 'monitor',
	SUBSCRIBE_ALL: 'subscribeAll',
	SUBSCRIBE: 'subscribe',
	PUBLISH: 'publish',
	REGISTER: 'register',
	ORG_LIMITS: 'view-org-limits',
	EVENT_USAGE_METRICS: 'view-event-usage-metrics'
};

const ACTION_VIEWS = new Set([
	VIEW_MODES.SUBSCRIBE_ALL,
	VIEW_MODES.SUBSCRIBE,
	VIEW_MODES.PUBLISH,
	VIEW_MODES.REGISTER
]);

// ── Helpers ──────────────────────────────────────────────────────────────

/**
 * @description Classifies a streaming error and determines the appropriate error message
 * and whether a toast notification should be shown.
 *
 * @param {Object} error - The EMP API error payload.
 * @param {boolean} isErrorSuppressed - Whether subscribe error toasts are temporarily suppressed.
 * @returns {{showToast: boolean, errorMessage: string}} Classification result.
 */
function classifyStreamingError(error, isErrorSuppressed)
{
	const defaultMessage = (error.subscription ? error.subscription + ' - ' : '') + (error.error ? error.error : 'See browser\'s dev console for details');

	if(error.channel !== '/meta/subscribe' || !error.error)
	{
		return {showToast: true, errorMessage: defaultMessage};
	}

	const rawErrorMessage = error.error;
	if(rawErrorMessage.startsWith('400::The channel specified is not valid'))
	{
		return {
			showToast: !isErrorSuppressed && isCDCChannel(error.subscription),
			errorMessage: `Failed to subscribe to ${error.subscription}. Is the Change Data Capture event active?`
		};
	}
	if(rawErrorMessage.startsWith('403:denied_by_security_policy'))
	{
		return {
			showToast: !isErrorSuppressed, errorMessage: `Failed to subscribe to ${error.subscription}: ${rawErrorMessage}`
		};
	}

	return {showToast: true, errorMessage: defaultMessage};
}

// ── Component ────────────────────────────────────────────────────────────

// eslint-disable-next-line kerndx/use-component-builder -- framework component extends LightningElement directly (no ComponentBuilder wrapper needed for this layer)
export default class StreamingMonitor extends LightningElement
{
	// ── Internal State ───────────────────────────────────────────────────

	/** @description Available streaming channels loaded from Apex. */
	@track channels;

	/** @description Active EMP API subscriptions. */
	@track subscriptions = [];

	/** @description Current navigation view identifier. */
	view = VIEW_MODES.MONITOR;

	/** @description Flag to temporarily suppress subscription error toasts. */
	isSubscribeErrorSuppressed = false;

	/** @description Cached reference to the streaming events child component. */
	cachedEventsComponent;

	/** @description Debounce timeout ID for window resize handling. */
	resizeDebounceTimer;

	// ── Computed Properties ──────────────────────────────────────────────

	/** @description True while channels are loading. */
	get isLoadingChannels()
	{
		return this.channels === undefined;
	}

	/** @description CSS class controlling visibility of the monitor view. */
	get monitorClasses()
	{
		return this.view === VIEW_MODES.MONITOR ? 'slds-show' : 'slds-hide';
	}

	/** @description Whether current view is an action view. */
	get isActionView()
	{
		return ACTION_VIEWS.has(this.view);
	}

	/** @description Whether current view is org limits panel. */
	get isOrgLimitsView()
	{
		return this.view === VIEW_MODES.ORG_LIMITS;
	}

	/** @description Whether current view shows event usage metrics. */
	get isEventUsageMetricsView()
	{
		return this.view === VIEW_MODES.EVENT_USAGE_METRICS;
	}

	// ── Lifecycle ────────────────────────────────────────────────────────

	/**
	 * @description Initializes EMP API, loads channels,
	 * registers error handler and binds resize listener.
	 */
	async connectedCallback()
	{
		setDebugFlag(true);

		onError((error) => this.handleStreamingError(error));

		try
		{
			this.channels = await getAllEventChannels();
		}
		catch(error)
		{
			utilityLogger.error('Failed to retrieve streaming channels', error);
		}
		window.addEventListener('resize', this.handleWindowResize.bind(this));
	}

	/**
	 * @description Cleanup on component removal.
	 * Unsubscribes from all channels and clears resize listener.
	 */
	disconnectedCallback()
	{
		this.handleUnsubscribeAll();
		window.removeEventListener('resize', this.handleWindowResize);
	}

	// ── Event Handlers ───────────────────────────────────────────────────

	/**
	 * @description Handles browser window resize and forces charts to rerender.
	 * Debounced to avoid excessive DOM updates.
	 */
	handleWindowResize()
	{
		if(this.resizeDebounceTimer)
		{
			clearTimeout(this.resizeDebounceTimer);
		}
		this.resizeDebounceTimer = setTimeout(() =>
		{
			const eventsElement = this.template.querySelector('c-streaming-events');
			if(eventsElement)
			{
				eventsElement.forceRerender();
			}
		}, RESIZE_DEBOUNCE_MS);
	}

	/**
	 * @description Changes current view based on navigation events.
	 * Refreshes available channels when navigating to action views
	 * so that newly created PushTopics, StreamingChannels, etc. appear.
	 *
	 * @param {CustomEvent} event - Contains new view name.
	 */
	handleNavigate(event)
	{
		this.view = event.detail;
		if(ACTION_VIEWS.has(this.view))
		{
			this.refreshChannels();
		}
	}

	/**
	 * @description Reloads available streaming channels from Apex.
	 */
	async refreshChannels()
	{
		try
		{
			this.channels = await getAllEventChannels();
		}
		catch(error)
		{
			utilityLogger.error('Failed to refresh streaming channels', error);
		}
	}

	/**
	 * @description Forces events component to rerender when sidebar toggles.
	 */
	handleSidebarToggle()
	{
		const eventsElement = this.template.querySelector('c-streaming-events');
		if(eventsElement)
		{
			eventsElement.forceRerender();
		}
	}

	/**
	 * @description Handles all runtime EMP API errors.
	 * Removes invalid subscriptions, identifies CDC issues,
	 * and conditionally shows toast messages.
	 *
	 * @param {Object} error - EMP API error payload.
	 */
	handleStreamingError(error)
	{
		utilityLogger.error('Streaming API error', error);

		if(error.channel === '/meta/subscribe' && error.error)
		{
			const subIndex = this.subscriptions.findIndex((s) => s.channel === error.subscription);
			if(subIndex !== -1)
			{
				this.subscriptions.splice(subIndex, 1);
				utilityLogger.warn(`Removing faulty subscription: ${error.subscription}`, {channel: error.subscription});
			}
		}

		const {showToast, errorMessage} = classifyStreamingError(error, this.isSubscribeErrorSuppressed);
		if(showToast)
		{
			this.notify('error', 'Streaming API error', errorMessage);
		}
	}

	/**
	 * @description Handles subscribing to all channels based on filter rules.
	 *
	 * @param {CustomEvent} event - Contains replayId and filter type.
	 */
	async handleSubscribeAll(event)
	{
		const {replayId, filter} = event.detail;
		utilityLogger.info(`Subscribing to multiple streaming channels`, {filter, replayId});

		try
		{
			let channels = this.buildChannelList(filter);

			channels = this.filterExistingChannels(channels);

			if(channels.length === 0)
			{
				this.notify('warn', 'No channels available', 'There are no channels to subscribe to with the specified filter and current subscriptions');
				return;
			}

			this.suppressSubscribeErrorsTemporarily();

			const subscriptions = await this.subscribeToChannels(channels, replayId);

			this.saveSubscriptions(subscriptions);

			this.notify('success', 'Subscribed', 'Successfully subscribed to the specified channels');
			this.view = VIEW_MODES.MONITOR;
		}
		catch(error)
		{
			utilityLogger.error('Failed to subscribe to all channels', error);
		}
	}

	/**
	 * @description Subscribes to a single channel.
	 *
	 * @param {CustomEvent} event - Contains channel and replayId.
	 */
	async handleSubscribe(event)
	{
		const {channel, replayId} = event.detail;

		if(this.subscriptions.some((sub) => sub.channel === channel))
		{
			this.notify('error', 'Cannot subscribe', `Already subscribed to channel ${channel}`);
			return;
		}

		const subscription = await subscribe(channel, replayId, (streamingEvent) =>
		{
			this.handleStreamingEvent(streamingEvent);
		});
		this.notify('success', 'Successfully subscribed', subscription.channel);
		this.saveSubscription(subscription);
		this.view = VIEW_MODES.MONITOR;
	}

	/**
	 * @description Handles messages received from EMP API.
	 *
	 * @param {Object} streamingEvent - The streaming event payload.
	 */
	handleStreamingEvent(streamingEvent)
	{
		this.notify('info', 'Received event on channel', streamingEvent.channel);
		utilityLogger.debug('Received streaming event', {channel: streamingEvent.channel, event: streamingEvent});
		const eventData = normalizeEvent(streamingEvent);
		if(!this.cachedEventsComponent)
		{
			this.cachedEventsComponent = this.template.querySelector('c-streaming-events');
		}
		this.cachedEventsComponent.addStreamingEvent(eventData);
	}

	/**
	 * @description Publishes a platform event or CDC test event.
	 *
	 * @param {CustomEvent} event - Contains eventType, eventName, and eventPayload.
	 */
	async handlePublish(event)
	{
		const eventParams = event.detail;
		try
		{
			await publishStreamingEvent(eventParams);
			this.notify('success', 'Event published', `Successfully published event ${eventParams.eventName}`);
			this.view = VIEW_MODES.MONITOR;
		}
		catch(error)
		{
			utilityLogger.error(`Failed to publish ${eventParams.eventName}`, error);
			this.notify('error', 'Publish failed', `Failed to publish ${eventParams.eventName}`);
		}
	}

	/**
	 * @description Unsubscribes from all active channels.
	 */
	handleUnsubscribeAll()
	{
		if(!this.cachedEventsComponent)
		{
			this.cachedEventsComponent = this.template.querySelector('c-streaming-events');
		}
		if(this.cachedEventsComponent)
		{
			this.cachedEventsComponent.handleClearEvents();
		}

		this.subscriptions.forEach((subscription) =>
		{
			// noinspection JSIgnoredPromiseFromCall
			unsubscribe(subscription, (response) =>
			{
				if(!response.successful)
				{
					utilityLogger.error('Failed to unsubscribe from channel', {channel: subscription.channel, response});
				}
			});
		});
		this.subscriptions = [];

		this.notify('success', 'Unsubscribed', 'Successfully unsubscribed from all channels');
	}

	/**
	 * @description Unsubscribes from a single channel.
	 *
	 * @param {CustomEvent} event - Contains the channel name.
	 */
	handleUnsubscribe(event)
	{
		const {channel} = event.detail;
		const foundIndex = this.subscriptions.findIndex((sub) => sub.channel === channel);
		if(foundIndex === -1)
		{
			return;
		}

		if(!this.cachedEventsComponent)
		{
			this.cachedEventsComponent = this.template.querySelector('c-streaming-events');
		}
		if(this.cachedEventsComponent)
		{
			this.cachedEventsComponent.removeEventsForChannel(channel);
		}

		const subscription = this.subscriptions[foundIndex];
		// noinspection JSIgnoredPromiseFromCall
		unsubscribe(subscription, (response) =>
		{
			if(response.successful)
			{
				this.notify('success', 'Successfully unsubscribed', channel);
			}
			else
			{
				this.notify('error', 'Failed to unsubscribe', channel);
				utilityLogger.error('Failed to unsubscribe from channel', {channel, response});
			}
		});

		const subscriptions = [...this.subscriptions];
		subscriptions.splice(foundIndex, 1);
		this.subscriptions = subscriptions;
	}

	// ── Internal Helpers ─────────────────────────────────────────────────

	/**
	 * @description Shorthand method to show toast notifications.
	 *
	 * @param {string} variant - success|error|warning|info.
	 * @param {string} title - Toast title.
	 * @param {string} message - Toast body.
	 */
	notify(variant, title, message)
	{
		this.dispatchEvent(new ShowToastEvent({title, message, variant}));
	}

	/**
	 * @description Builds a list of channels to subscribe to based on filter.
	 *
	 * @param {string} filter - The filter type.
	 * @returns {Array<string>} Channel names to subscribe to.
	 */
	buildChannelList(filter)
	{
		if(filter === FILTER_ALL)
		{
			return EVENT_TYPES.flatMap((t) => this.getChannelsForAll(t));
		}

		if(filter === FILTER_CUSTOM)
		{
			return EVENT_TYPES.flatMap((t) => this.getCustomChannels(t));
		}

		if(filter === EVT_CDC)
		{
			return [CHANNEL_ALL_CDC];
		}

		return this.getChannelsForType(filter);
	}

	/**
	 * @description Returns every channel for a given event type.
	 *
	 * @param {Object} type - Event type definition.
	 * @returns {Array<string>} Channel names.
	 */
	getChannelsForAll(type)
	{
		const typeName = type.value;

		if(typeName === EVT_CDC)
		{
			return [CHANNEL_ALL_CDC];
		}

		return this.channels[typeName].map((c) => getChannelPrefix(typeName) + c.value);
	}

	/**
	 * @description Returns only custom-defined channels for a type.
	 *
	 * @param {Object} type - Event type definition.
	 * @returns {Array<string>} Custom channel names.
	 */
	getCustomChannels(type)
	{
		const typeName = type.value;
		const prefix = getChannelPrefix(typeName);

		return this.channels[typeName]
		.filter((c) => isCustomChannel(typeName, c.value))
		.map((c) => prefix + c.value);
	}

	/**
	 * @description Returns channels belonging to a specific event type.
	 *
	 * @param {string} typeName - The event type identifier.
	 * @returns {Array<string>} Channel names.
	 */
	getChannelsForType(typeName)
	{
		const prefix = getChannelPrefix(typeName);

		return this.channels[typeName].map((c) => prefix + c.value);
	}

	/**
	 * @description Removes channels already subscribed to.
	 *
	 * @param {Array<string>} channels - Candidate channel names.
	 * @returns {Array<string>} Channels not yet subscribed.
	 */
	filterExistingChannels(channels)
	{
		return channels.filter((ch) => !this.subscriptions.some((s) => s.channel === ch));
	}

	/**
	 * @description Temporarily suppresses subscription error toasts.
	 */
	suppressSubscribeErrorsTemporarily()
	{
		this.isSubscribeErrorSuppressed = true;
		setTimeout(() =>
		{
			this.isSubscribeErrorSuppressed = false;
		}, SUBSCRIBE_ERROR_SUPPRESSION_MS);
	}

	/**
	 * @description Calls EMP API subscribe for multiple channels.
	 *
	 * @param {Array<string>} channels - Channels to subscribe to.
	 * @param {string} replayId - Replay ID for the subscription.
	 * @returns {Promise<Array>} Array of subscription objects.
	 */
	subscribeToChannels(channels, replayId)
	{
		const subscribePromises = channels.map((channel) => subscribe(channel, replayId, (evt) => this.handleStreamingEvent(evt)));

		return Promise.all(subscribePromises);
	}

	/**
	 * @description Saves multiple subscriptions into tracked state.
	 *
	 * @param {Array<Object>} list - Subscription objects to save.
	 */
	saveSubscriptions(list)
	{
		list.forEach((s) => this.saveSubscription(s));
	}

	/**
	 * @description Adds a subscription to the tracked array.
	 *
	 * @param {Object} subscription - The EMP API subscription object.
	 */
	saveSubscription(subscription)
	{
		const subscriptions = [...this.subscriptions];
		subscriptions.push(subscription);
		subscriptions.sort(channelSort);
		this.subscriptions = subscriptions;
	}
}