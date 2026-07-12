// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) Philippe Ozil (CC0-1.0 — rights waived)
// Adapted from streaming-monitor (https://github.com/pozil/streaming-monitor)
// Modifications copyright (c) 2026 JVB Consulting

//noinspection FunctionWithMultipleReturnPointsJS

/**
 * @description Lightning Web Component that provides a unified interface for subscribing,
 * publishing, and registering events in a Salesforce streaming/Platform Event environment.
 *
 * The component supports four actions, dynamically rendered based on the `action` API property:
 *   - `subscribeAll`    — Subscribe to all or filtered events
 *   - `subscribe`       — Subscribe to a specific event or channel
 *   - `publish`         — Publish a payload to a specified event
 *   - `register`        — Register to receive specific event types
 *
 * @date March 2026, June 2026
 **/
import {LightningElement, api} from 'lwc';
import {
	EVENT_TYPES, PUBLISHABLE_EVENT_TYPES, EVT_PUSH_TOPIC, EVT_GENERIC, EVT_STD_PLATFORM_EVENT, EVT_PLATFORM_EVENT, EVT_CDC, EVT_CUSTOM_CHANNEL_CDC, EVT_CUSTOM_CHANNEL_PE,
	EVT_MONITORING, FILTER_ALL, FILTER_CUSTOM, getChannelPrefix
} from 'c/utilityStreaming';
import utilityLogger from 'c/utilityLogger';
import {formatTemplateString} from 'c/utilityString';

import getBlankPlatformEvent from '@salesforce/apex/CTRL_EventMonitor.getInitialisedEvent';
import PUBLISH_SCOPE_NOTE from '@salesforce/label/c.EventMonitor_PublishScopeNote';
import FORM_EVENT_TYPE from '@salesforce/label/c.EventMonitor_Form_EventType';
import FORM_SELECT_TYPE_PLACEHOLDER from '@salesforce/label/c.EventMonitor_Form_SelectTypePlaceholder';
import FORM_EVENT_NAME from '@salesforce/label/c.EventMonitor_Form_EventName';
import FORM_STREAMING_CHANNEL from '@salesforce/label/c.EventMonitor_Form_StreamingChannel';
import FORM_REPLAY_OPTION from '@salesforce/label/c.EventMonitor_Form_ReplayOption';
import FORM_REPLAY_ID from '@salesforce/label/c.EventMonitor_Form_ReplayId';
import FORM_FILTER from '@salesforce/label/c.EventMonitor_Form_Filter';
import FORM_EVENT_PAYLOAD from '@salesforce/label/c.EventMonitor_Form_EventPayload';
import SUBSCRIBE_BUTTON from '@salesforce/label/c.EventMonitor_SubscribeButton';
import PUBLISH_BUTTON from '@salesforce/label/c.EventMonitor_PublishButton';
import REGISTER_SOURCE_TITLE from '@salesforce/label/c.EventMonitor_RegisterSourceTitle';
import SUBSCRIBE_CHANNEL_TITLE from '@salesforce/label/c.EventMonitor_SubscribeChannelTitle';
import SUBSCRIBE_ALL_TITLE from '@salesforce/label/c.EventMonitor_SubscribeAllTitle';
import PUBLISH_EVENT_TITLE from '@salesforce/label/c.EventMonitor_PublishEventTitle';
import SUBSCRIBE_ALL_NOTE from '@salesforce/label/c.EventMonitor_SubscribeAll_Note';
import REG_PUSH_TOPIC_INTRO from '@salesforce/label/c.EventMonitor_Reg_PushTopicIntro';
import REG_GENERIC from '@salesforce/label/c.EventMonitor_Reg_Generic';
import REG_PLATFORM_EVENT from '@salesforce/label/c.EventMonitor_Reg_PlatformEvent';
import REG_STANDARD_PLATFORM_EVENT from '@salesforce/label/c.EventMonitor_Reg_StandardPlatformEvent';
import REG_CHANGE_DATA_CAPTURE from '@salesforce/label/c.EventMonitor_Reg_ChangeDataCapture';
import REG_CUSTOM_CHANNEL_PE from '@salesforce/label/c.EventMonitor_Reg_CustomChannelPE';
import REG_CUSTOM_CHANNEL_CDC from '@salesforce/label/c.EventMonitor_Reg_CustomChannelCDC';
import NOTICE_MONITORING_ENABLEMENT from '@salesforce/label/c.EventMonitor_Notice_MonitoringEnablement';
import NOTICE_CDC_ENABLEMENT from '@salesforce/label/c.EventMonitor_Notice_CdcEnablement';
import PLACEHOLDER_SELECT_EVENT from '@salesforce/label/c.EventMonitor_Placeholder_SelectEvent';
import PLACEHOLDER_WAITING_EVENT_TYPE from '@salesforce/label/c.EventMonitor_Placeholder_WaitingEventType';
import PLACEHOLDER_CDC_MANUAL_CHANNEL from '@salesforce/label/c.EventMonitor_Placeholder_CdcManualChannel';
import PLACEHOLDER_CUSTOM_MANUAL_CHANNEL from '@salesforce/label/c.EventMonitor_Placeholder_CustomManualChannel';
import PLACEHOLDER_NO_EVENTS_AVAILABLE from '@salesforce/label/c.EventMonitor_Placeholder_NoEventsAvailable';
import VALIDATION_INVALID_JSON from '@salesforce/label/c.EventMonitor_Validation_InvalidJson';
import REPLAY_NONE from '@salesforce/label/c.EventMonitor_Replay_None';
import REPLAY_PAST from '@salesforce/label/c.EventMonitor_Replay_Past';
import REPLAY_CUSTOM from '@salesforce/label/c.EventMonitor_Replay_Custom';
import FILTER_OPTION_ALL_EVENTS from '@salesforce/label/c.EventMonitor_FilterOption_AllEvents';
import FILTER_OPTION_ALL_CUSTOM_EVENTS from '@salesforce/label/c.EventMonitor_FilterOption_AllCustomEvents';
import FILTER_OPTION_ONLY_TYPE from '@salesforce/label/c.EventMonitor_FilterOption_OnlyType';
import PAYLOAD_HELP_GENERIC from '@salesforce/label/c.EventMonitor_PayloadHelp_Generic';
import PAYLOAD_HELP_JSON from '@salesforce/label/c.EventMonitor_PayloadHelp_Json';

import subscribeAll from './subscribeAll.html';
import subscribe from './subscribe.html';
import publish from './publish.html';
import register from './register.html';

// ── Constants ────────────────────────────────────────────────────────────

const ACTIONS = {
	SUBSCRIBE_ALL: 'subscribeAll', SUBSCRIBE: 'subscribe', PUBLISH: 'publish', REGISTER: 'register'
};

// ── Helpers ──────────────────────────────────────────────────────────────

/**
 * @description Returns the appropriate placeholder text for an event name combobox
 * based on the selected event type and available channels.
 *
 * @param {string|undefined} eventType - The selected event type.
 * @param {Object} channels - Map of event types to arrays of channel/event names.
 * @returns {string} The placeholder text.
 */
function getEventNamePlaceholder(eventType, channels)
{
	if(eventType && channels[eventType]?.length > 0)
	{
		return PLACEHOLDER_SELECT_EVENT;
	}
	if(!eventType)
	{
		return PLACEHOLDER_WAITING_EVENT_TYPE;
	}
	if(eventType === EVT_CUSTOM_CHANNEL_CDC)
	{
		return PLACEHOLDER_CDC_MANUAL_CHANNEL;
	}
	if(eventType === EVT_CUSTOM_CHANNEL_PE)
	{
		return PLACEHOLDER_CUSTOM_MANUAL_CHANNEL;
	}
	const eventDefinition = EVENT_TYPES.find((e) => e.value === eventType);
	if(!eventDefinition)
	{
		// Developer-only invariant guard: `eventType` is always one of the EVT_* constants in real
		// usage, so this fires only on a programming error and never reaches an end user — it stays a
		// plain diagnostic string rather than a subscriber Custom Label.
		// eslint-disable-next-line kerndx/no-hardcoded-user-text
		throw new Error(`Unsupported event type ${eventType}`);
	}
	return formatTemplateString(PLACEHOLDER_NO_EVENTS_AVAILABLE, [eventDefinition.label]);
}

/**
 * @description Validates a payload value as JSON and sets custom validity on the element.
 * Generic event types accept any string; all other types require valid JSON.
 *
 * @param {Object} element - The textarea element to set validity on.
 * @param {string} value - The payload value to validate.
 * @param {string} eventType - The selected event type.
 */
function validateJsonPayload(element, value, eventType)
{
	if(eventType === EVT_GENERIC)
	{
		element.setCustomValidity('');
		return;
	}
	//noinspection UnusedCatchParameterJS
	try
	{
		if(value)
		{
			JSON.parse(value);
		}
		element.setCustomValidity('');
	}
	catch(error /* eslint-disable-line no-unused-vars */)
	{
		element.setCustomValidity(VALIDATION_INVALID_JSON);
	}
}

// ── Component ────────────────────────────────────────────────────────────

// eslint-disable-next-line kerndx/use-component-builder -- framework component extends LightningElement directly (no ComponentBuilder wrapper needed for this layer)
export default class StreamingActions extends LightningElement
{
	// ── @api Properties ──────────────────────────────────────────────────

	/**
	 * @description Current action to render (subscribeAll | subscribe | publish | register).
	 **/
	@api action = 'subscribeAll';

	/**
	 * @description Map of event types to arrays of channel/event names.
	 **/
	@api channels = [];

	// ── Internal State ───────────────────────────────────────────────────

	subAllFilter = FILTER_ALL;
	subAllReplay = '-1';

	subEventType;
	subscribeEventName;
	subChannel;
	subReplayOption = '-1';
	subReplayId;

	pubEventType;
	publishEventName;
	publishChannel;
	publishPayload;

	registrationEventType;

	/**
	 * @description Custom-label text shown at the top of the Publish screen explaining which event
	 * types can be published manually and where to watch the rest.
	 **/
	publishScopeNote = PUBLISH_SCOPE_NOTE;

	/**
	 * @description Template-bound Custom Labels for the four action screens. The `reg*` and
	 * `notice*` entries carry inline anchor (and code) markup and are rendered through
	 * `lightning-formatted-rich-text` so the links stay clickable — a plain `{binding}` would
	 * HTML-escape them.
	 **/
	labels = {
		registerSourceTitle: REGISTER_SOURCE_TITLE,
		subscribeChannelTitle: SUBSCRIBE_CHANNEL_TITLE,
		subscribeAllTitle: SUBSCRIBE_ALL_TITLE,
		publishEventTitle: PUBLISH_EVENT_TITLE,
		eventType: FORM_EVENT_TYPE,
		selectTypePlaceholder: FORM_SELECT_TYPE_PLACEHOLDER,
		eventName: FORM_EVENT_NAME,
		streamingChannel: FORM_STREAMING_CHANNEL,
		replayOption: FORM_REPLAY_OPTION,
		replayId: FORM_REPLAY_ID,
		filter: FORM_FILTER,
		eventPayload: FORM_EVENT_PAYLOAD,
		subscribe: SUBSCRIBE_BUTTON,
		publish: PUBLISH_BUTTON,
		subscribeAllNote: SUBSCRIBE_ALL_NOTE,
		pushTopicIntro: REG_PUSH_TOPIC_INTRO,
		regGeneric: REG_GENERIC,
		regPlatformEvent: REG_PLATFORM_EVENT,
		regStandardPlatformEvent: REG_STANDARD_PLATFORM_EVENT,
		regChangeDataCapture: REG_CHANGE_DATA_CAPTURE,
		regCustomChannelPE: REG_CUSTOM_CHANNEL_PE,
		regCustomChannelCDC: REG_CUSTOM_CHANNEL_CDC,
		noticeMonitoringEnablement: NOTICE_MONITORING_ENABLEMENT,
		noticeCdcEnablement: NOTICE_CDC_ENABLEMENT
	};

	// ── Computed Properties: Subscribe ───────────────────────────────────

	/**
	 * @description Returns list of all available event types for subscription.
	 **/
	get subscribeEventTypes()
	{
		return EVENT_TYPES;
	}

	/**
	 * @description Returns available event names based on selected subscribe event type.
	 **/
	get subscribeEventNames()
	{
		if(!this.subEventType)
		{
			return [];
		}
		return this.channels[this.subEventType];
	}

	/**
	 * @description Placeholder text for subscription event name dropdown.
	 **/
	get subEventNamePlaceholder()
	{
		return getEventNamePlaceholder(this.subEventType, this.channels);
	}

	/**
	 * @description Whether the subscription event name dropdown should be disabled. Safe-navigates the
	 * channel lookup: on slow/early load the selected type may not be in the channel map yet, and the
	 * getter must report disabled rather than throw mid-render.
	 **/
	get isSubscribeEventNameDisabled()
	{
		return (this.subEventType === undefined || (this.channels[this.subEventType]?.length ?? 0) === 0);
	}

	/**
	 * @description Whether the manual channel input should be disabled.
	 **/
	get isSubscribeChannelDisabled()
	{
		return (this.subEventType !== EVT_CUSTOM_CHANNEL_CDC && this.subEventType !== EVT_CUSTOM_CHANNEL_PE);
	}

	/**
	 * @description Whether the subscribe button should be disabled. Safe-navigates the channel value:
	 * `subChannel` can be undefined before the type handler seeds it, and the getter must report
	 * disabled rather than throw mid-render.
	 **/
	get isSubscribeDisabled()
	{
		if(this.subEventType === EVT_CUSTOM_CHANNEL_CDC || this.subEventType === EVT_CUSTOM_CHANNEL_PE)
		{
			const channel = this.subChannel?.trim() ?? '';
			return (channel === '' || channel === getChannelPrefix(this.subEventType));
		}
		return (this.subEventType !== EVT_CUSTOM_CHANNEL_CDC && this.subscribeEventName === undefined);
	}

	/**
	 * @description Whether the current subscription is a CDC type.
	 **/
	get isCDCSubscription()
	{
		return (this.subEventType === EVT_CDC || this.subEventType === EVT_CUSTOM_CHANNEL_CDC);
	}

	/**
	 * @description Whether the current subscription is a monitoring type.
	 **/
	get isEventMonitoringSubscription()
	{
		return this.subEventType === EVT_MONITORING;
	}

	/**
	 * @description Returns array of replay options for subscription.
	 **/
	get replayOptions()
	{
		const options = [
			{label: REPLAY_NONE, value: '-1'},
			{label: REPLAY_PAST, value: '-2'}
		];
		if(this.action === ACTIONS.SUBSCRIBE)
		{
			options.push({label: REPLAY_CUSTOM, value: 'custom'});
		}
		return options;
	}

	/**
	 * @description Whether the custom replay ID input should be visible.
	 **/
	get isCustomReplayIdVisible()
	{
		return (this.action === ACTIONS.SUBSCRIBE && this.subReplayOption === 'custom');
	}

	/**
	 * @description Returns list of filter options for "subscribe all" action.
	 **/
	get subscribeAllFilterOptions()
	{
		const options = [
			{label: FILTER_OPTION_ALL_EVENTS, value: FILTER_ALL},
			{label: FILTER_OPTION_ALL_CUSTOM_EVENTS, value: FILTER_CUSTOM}
		];
		EVENT_TYPES.forEach((type) =>
		{
			const {value} = type;
			if(value !== EVT_CUSTOM_CHANNEL_PE && value !== EVT_CUSTOM_CHANNEL_CDC)
			{
				const label = formatTemplateString(FILTER_OPTION_ONLY_TYPE, [type.label]);
				options.push({label, value});
			}
		});
		return options;
	}

	// ── Computed Properties: Publish ─────────────────────────────────────

	/**
	 * @description Returns the event types a user can publish manually (Generic and Custom Platform
	 * events). Platform-published and record-change-driven types are intentionally excluded so the
	 * Publish picklist never offers a type that cannot be published from here.
	 **/
	get publishEventTypes()
	{
		return PUBLISHABLE_EVENT_TYPES;
	}

	/**
	 * @description Returns available event names based on selected publish event type.
	 **/
	get pubEventNames()
	{
		if(!this.pubEventType)
		{
			return [];
		}
		return this.channels[this.pubEventType];
	}

	/**
	 * @description Placeholder text for publish event name dropdown.
	 **/
	get pubEventNamePlaceholder()
	{
		return getEventNamePlaceholder(this.pubEventType, this.channels);
	}

	/**
	 * @description Whether the publish event name dropdown should be disabled. Safe-navigates the
	 * channel lookup for the same slow/early-load reason as `isSubscribeEventNameDisabled`.
	 **/
	get isPublishEventNameDisabled()
	{
		return (this.pubEventType === undefined || (this.channels[this.pubEventType]?.length ?? 0) === 0);
	}

	/**
	 * @description Whether the publish button should be disabled.
	 **/
	get isPublishDisabled()
	{
		return (this.pubEventType === undefined || this.publishEventName === undefined);
	}

	/**
	 * @description Returns contextual help text for the payload input.
	 **/
	get publishPayloadHelp()
	{
		return this.pubEventType === EVT_GENERIC ? PAYLOAD_HELP_GENERIC : PAYLOAD_HELP_JSON;
	}

	// ── Computed Properties: Register ────────────────────────────────────

	/**
	 * @description Returns list of all available event types for registration.
	 **/
	get registrationEventTypes()
	{
		return EVENT_TYPES;
	}

	/**
	 * @description Whether the selected registration type is PushTopic.
	 **/
	get isPushTopicReg()
	{
		return this.registrationEventType === EVT_PUSH_TOPIC;
	}

	/**
	 * @description Whether the selected registration type is Generic.
	 **/
	get isGenericReg()
	{
		return this.registrationEventType === EVT_GENERIC;
	}

	/**
	 * @description Whether the selected registration type is Platform Event.
	 **/
	get isPlatformEventReg()
	{
		return this.registrationEventType === EVT_PLATFORM_EVENT;
	}

	/**
	 * @description Whether the selected registration type is Standard Platform Event.
	 **/
	get isStandardPlatformEventReg()
	{
		return this.registrationEventType === EVT_STD_PLATFORM_EVENT;
	}

	/**
	 * @description Whether the selected registration type is Standard CDC.
	 **/
	get isStandardCDCReg()
	{
		return this.registrationEventType === EVT_CDC;
	}

	/**
	 * @description Whether the selected registration type is Custom Channel CDC.
	 **/
	get isCustomChannelCDCReg()
	{
		return this.registrationEventType === EVT_CUSTOM_CHANNEL_CDC;
	}

	/**
	 * @description Whether the selected registration type is Custom Channel PE.
	 **/
	get isCustomChannelPEReg()
	{
		return this.registrationEventType === EVT_CUSTOM_CHANNEL_PE;
	}

	/**
	 * @description Whether the selected registration type is Monitoring.
	 **/
	get isMonitoringReg()
	{
		return this.registrationEventType === EVT_MONITORING;
	}

	// ── Lifecycle ────────────────────────────────────────────────────────

	/**
	 * @description Overrides default LWC render method to dynamically select the HTML template based on `action`.
	 **/
	//noinspection JSCheckFunctionSignatures
	render()
	{
		switch(this.action)
		{
			case ACTIONS.SUBSCRIBE_ALL:
				return subscribeAll;
			case ACTIONS.SUBSCRIBE:
				return subscribe;
			case ACTIONS.PUBLISH:
				return publish;
			case ACTIONS.REGISTER:
				return register;
			default:
				// Developer-only invariant guard: `action` is wired by streamingMonitor to one of the
				// ACTIONS values, so this fires only on a programming error and never reaches an end
				// user — it stays a plain diagnostic string rather than a subscriber Custom Label.
				// eslint-disable-next-line kerndx/no-hardcoded-user-text
				throw new Error(`Unsupported action: ${this.action}`);
		}
	}

	// ── Event Handlers ───────────────────────────────────────────────────

	/**
	 * @description Generic handler to update component property by `event.target.name` and `event.detail.value`.
	 **/
	handleValueChange(event)
	{
		const {name} = event.target;
		this[name] = event.detail.value;
	}

	/**
	 * @description Dispatches a `subscribe all` event with filter and replayId details.
	 **/
	handleSubscribeAll()
	{
		const subscribeEvent = new CustomEvent('subscribeall', {
			detail: {
				filter: this.subAllFilter, replayId: this.subAllReplay
			}
		});
		this.dispatchEvent(subscribeEvent);
	}

	/**
	 * @description Updates subscription event type, resets eventName, and updates channel prefix if needed.
	 **/
	handleSubEventTypeChange(event)
	{
		this.subEventType = event.detail.value;
		this.subscribeEventName = undefined;
		if(this.subEventType === EVT_CUSTOM_CHANNEL_CDC || this.subEventType === EVT_CUSTOM_CHANNEL_PE)
		{
			this.subChannel = getChannelPrefix(this.subEventType);
		}
		else
		{
			this.subChannel = '';
		}
	}

	/**
	 * @description Updates subscription event name and calculates full channel.
	 **/
	handleSubEventNameChange(event)
	{
		this.subscribeEventName = event.detail.value;
		this.subChannel = getChannelPrefix(this.subEventType) + this.subscribeEventName;
	}

	/**
	 * @description Dispatches a `subscribe` event with channel and replayId details.
	 * Resets subscription form fields after submission.
	 **/
	handleSubscribe(event)
	{
		event.preventDefault();
		const replayId = this.subReplayOption === 'custom' ? this.subReplayId : this.subReplayOption;
		const subscribeEvent = new CustomEvent('subscribe', {
			detail: {
				channel: this.subChannel, replayId
			}
		});
		this.dispatchEvent(subscribeEvent);
		this.subscribeEventName = undefined;
		this.subChannel = '';
		this.subReplayOption = '-1';
		this.subReplayId = undefined;
	}

	/**
	 * @description Updates publish event type and resets dependent fields.
	 **/
	handlePubEventTypeChange(event)
	{
		this.pubEventType = event.detail.value;
		this.publishEventName = undefined;
		this.publishChannel = undefined;
		this.publishPayload = undefined;
	}

	/**
	 * @description Updates publish event name, calculates publish channel, and fetches blank payload for platform events.
	 **/
	async handlePubEventNameChange(event)
	{
		this.publishEventName = event.detail.value;
		this.publishChannel = getChannelPrefix(this.pubEventType) + this.publishEventName;
		if(this.pubEventType === EVT_PLATFORM_EVENT)
		{
			try
			{
				const blankEvent = await getBlankPlatformEvent({
					eventName: this.publishEventName
				});
				this.publishPayload = JSON.stringify(blankEvent, null, 2);
			}
			catch(error)
			{
				utilityLogger.error('Failed to load blank platform event', error);
			}
		}
	}

	/**
	 * @description Updates publish payload and validates JSON if event type is not generic.
	 **/
	handlePubPayloadChange(event)
	{
		this.publishPayload = event.detail.value;
		validateJsonPayload(event.target, this.publishPayload, this.pubEventType);
	}

	/**
	 * @description Dispatches a `publish` event with eventType, eventName, and eventPayload.
	 **/
	handlePublish()
	{
		const publishEvent = new CustomEvent('publish', {
			detail: {
				eventType: this.pubEventType, eventName: this.publishEventName, eventPayload: this.publishPayload
			}
		});
		this.dispatchEvent(publishEvent);
	}
}