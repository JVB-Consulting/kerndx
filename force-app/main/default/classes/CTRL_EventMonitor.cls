// SPDX-License-Identifier: Apache-2.0
// Copyright (c) Philippe Ozil (CC0-1.0 — rights waived)
// Adapted from streaming-monitor (https://github.com/pozil/streaming-monitor)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description Controller for the Streaming Monitor component.
 * Provides methods to list streaming channels, publish events,
 * and retrieve org limits and event usage metrics.
 *
 * @see CTRL_EventMonitor_TEST
 *
 * @author Jason van Beukering
 *
 * @group Controllers
 *
 * @date February 2026, October 2026
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity')
public inherited sharing class CTRL_EventMonitor
{
	/**
	 * @description Publishes a streaming event based on its type.This is the main
	 * entry point for publishing events from the UI. Subscriber-facing failure messages are
	 * label-sourced so they stay translatable; raw failure detail is logged where the failure
	 * occurs and never reaches the UI.
	 *
	 * @param eventType The type of event to publish(see EVT_ constants).
	 * @param eventName The API name of the event or channel.
	 * @param eventPayload The JSON payload for the event.
	 *
	 * @throws AuraHandledException if the event type is unsupported, the event or channel is
	 * unknown, or the publish fails.
	 */
	@AuraEnabled
	public static void publishStreamingEvent(String eventType, String eventName, String eventPayload)
	{
		if(eventType == StreamingEventTypes.PlatformEvent.name())
		{
			publishCustomPlatformEvent(eventName, eventPayload);
		}
		else if(eventType == StreamingEventTypes.GenericEvent.name())
		{
			publishGenericEvent(eventName, eventPayload);
		}
		else
		{
			throw buildAuraHandledException(String.format(System.Label.EventMonitor_UnsupportedEventType, new List<Object> {eventType}));
		}
	}

	/**
	 * @description Retrieves all available streaming event channels, grouped by event type.
	 *
	 * @return Map<String, List<ComboBoxItem>> A map where the key is the event type
	 * (e.g., EVT_PUSH_TOPIC) and the value is a list of ComboBoxItems
	 * representing the available channels.
	 */
	@AuraEnabled
	public static Map<String, List<ComboBoxItem>> getAllEventChannels()
	{
		return new Map<String, List<ComboBoxItem>>
		{
				StreamingEventTypes.ChangeDataCaptureEvent.name() => getChangeDataCaptureEventChannels(),
				StreamingEventTypes.CustomChannelCDC.name() => new List<ComboBoxItem>(),
				StreamingEventTypes.CustomChannelPE.name() => new List<ComboBoxItem>(),
				StreamingEventTypes.GenericEvent.name() => getGenericEventChannels(),
				StreamingEventTypes.MonitoringEvent.name() => getEventMonitoringChannels(),
				StreamingEventTypes.PlatformEvent.name() => getCustomPlatformEventChannels(),
				StreamingEventTypes.PushTopicEvent.name() => getPushTopicEventChannels(),
				StreamingEventTypes.StandardPlatformEvent.name() => getStandardPlatformEventChannels()
		};
	}

	/**
	 * @description Retrieves org limits, filtering for those with defined values.
	 * Uses a wrapper class to be compatible with @AuraEnabled.
	 *
	 * @return A list of DTO objects containing limit information.
	 */
	@AuraEnabled
	public static List<DTO_OrgLimitWrapper> getOrgLimits()
	{
		// Can't orgLimitWrappers directly OrgLimit so we have to use a wrapper
		List<DTO_OrgLimitWrapper> orgLimitWrappers = new List<DTO_OrgLimitWrapper>();

		List<OrgLimit> limits = OrgLimits.getAll();

		for(OrgLimit orgLimit : limits)
		{
			if(orgLimit.getLimit() != null && orgLimit.getValue() != null)
			{
				orgLimitWrappers.add(new DTO_OrgLimitWrapper(orgLimit));
			}
		}
		return orgLimitWrappers;
	}

	/**
	 * @description Indicates whether this org exposes Enhanced Usage Metrics (the TimeSegment
	 * field on PlatformEventUsageMetric). The UI uses this to enable sub-daily granularity.
	 *
	 * @return `true` when Enhanced Usage Metrics is enabled in the org.
	 */
	@AuraEnabled
	public static Boolean isEnhancedUsageMetricEnabled()
	{
		return SEL_PlatformEventUsageMetric.isTimeSegmentAvailable();
	}

	/**
	 * @description Retrieves platform event usage metrics for a time segment and date range,
	 * ordered by start date. Blank segment defaults to Daily, preserving the pre-Enhanced-Usage-
	 * Metrics call shape. Null dates default to the segment's maximum valid window ending now. The
	 * platform rejects ranges wider than the per-segment window (Daily 30 days, Hourly 24 hours,
	 * FifteenMinutes 1 hour), so an over-window or inverted range is rejected here before the query
	 * reaches the platform's UDD metrics validator.
	 *
	 * @param timeSegment Daily, Hourly, or FifteenMinutes; blank defaults to Daily.
	 * @param startDate Inclusive lower bound on StartDate; null defaults to endDate minus the segment window.
	 * @param endDate Inclusive upper bound on EndDate; null defaults to now.
	 *
	 * @return List of found usage metric rows.
	 *
	 * @throws AuraHandledException if the segment is unsupported, the start is after the end, the
	 * range is wider than the segment allows, or the range is narrower than one segment bucket (the
	 * platform rejects sub-bucket ranges outright instead of returning empty).
	 */
	@AuraEnabled
	public static List<PlatformEventUsageMetric> getEventUsageMetrics(String timeSegment, Datetime startDate, Datetime endDate)
	{
		String requestedSegment = String.isBlank(timeSegment) ? SEL_PlatformEventUsageMetric.TimeSegment.Daily.name() : timeSegment;

		SEL_PlatformEventUsageMetric.TimeSegment segment = SEL_PlatformEventUsageMetric.toTimeSegment(requestedSegment);

		if(segment == null)
		{
			throw buildAuraHandledException(System.Label.EventUsageMetrics_Validation_UnsupportedSegment);
		}

		Integer windowMinutes = SEL_PlatformEventUsageMetric.maxRangeMinutes(segment);
		Datetime effectiveEndDate = endDate ?? Datetime.now();
		Datetime effectiveStartDate = startDate ?? effectiveEndDate.addMinutes(-windowMinutes);

		if(effectiveStartDate > effectiveEndDate)
		{
			throw buildAuraHandledException(System.Label.EventUsageMetrics_Validation_StartAfterEnd);
		}

		if((effectiveEndDate.getTime() - effectiveStartDate.getTime()) > windowMinutes * UTIL_Date.MILLISECONDS_PER_MINUTE)
		{
			throw buildAuraHandledException(String.format(
					System.Label.EventUsageMetrics_Validation_RangeTooWide,
					new List<Object> {SEL_PlatformEventUsageMetric.maxRangeHuman(segment)}));
		}

		if((effectiveEndDate.getTime() - effectiveStartDate.getTime()) < SEL_PlatformEventUsageMetric.minRangeMinutes(segment) * UTIL_Date.MILLISECONDS_PER_MINUTE)
		{
			throw buildAuraHandledException
					(
							String.format
									(
											System.Label.EventUsageMetrics_Validation_RangeTooNarrow,
											new List<Object> {SEL_PlatformEventUsageMetric.minRangeHuman(segment)}
									)
					);
		}

		return new SEL_PlatformEventUsageMetric().getBySegmentAndDateRange(segment, effectiveStartDate, effectiveEndDate);
	}

	/**
	 * @description Builds an AuraHandledException that carries the given subscriber-facing message
	 * both client-side and server-side. The bare constructor only sets the client-facing message and
	 * leaves `getMessage()` returning 'Script-thrown exception', which would make the message
	 * unreadable in logs and unassertable in tests.
	 *
	 * @param message The label-sourced, subscriber-safe message.
	 *
	 * @return The exception, ready to throw.
	 */
	private static AuraHandledException buildAuraHandledException(String message)
	{
		AuraHandledException error = new AuraHandledException(message);
		error.setMessage(message);

		return error;
	}

	/**
	 * @description Generates a blank payload map(field name -> default value)
	 * for a given platform event. Only fields a publisher can set (createable) are included;
	 * the event's read-only system fields are excluded.
	 *
	 * @param eventName The API name of the platform event(e.g., 'MyEvent__e').
	 *
	 * @return Map<String, Object> A map representing the blank event payload.
	 *
	 * @throws AuraHandledException if the payload template cannot be prepared; the raw failure
	 * detail goes to the logger only.
	 */
	@AuraEnabled
	public static SObject getInitialisedEvent(String eventName)
	{
		try
		{
			UTIL_SObjectDescribe objectDescribe = UTIL_SObjectDescribe.getDescribe(eventName);

			List<SObjectField> fieldsToDefault = new List<SObjectField>();

			for(SObjectField field : objectDescribe.getFieldsMap().values())
			{
				// Createable fields are the payload a publisher can set; the event's system fields
				// (CreatedById, CreatedDate, EventUuid, ReplayId) are read-only plumbing.
				if(UTIL_SObjectDescribe.getCachedFieldDescribe(field).isCreateable())
				{
					fieldsToDefault.add(field);
				}
			}

			return TST_Builder.of(objectDescribe.getSObjectType())
					.withoutInsertion()
					.withDefaultedFields(fieldsToDefault)
					.build();

		}
		catch(Exception error)
		{
			// Raw describe/builder detail belongs in the log, not the UI.
			LOG_Builder.build().error(error).at(CTRL_EventMonitor.class.getName() + '.getInitialisedEvent').emit();

			throw buildAuraHandledException(String.format(System.Label.EventMonitor_PayloadTemplateFailed, new List<Object> {eventName}));
		}
	}

	/**
	 * @description Private helper to publish a specific Platform Event. An unknown event name
	 * throws a label-sourced AuraHandledException; a failed parse or publish routes its raw
	 * detail (JSON parser text, DML errors) to the logger and surfaces the translated
	 * publish-failure message.
	 *
	 * @param eventName The API name of the platform event.
	 * @param eventPayload The JSON payload to deserialize and publish.
	 *
	 * @throws AuraHandledException if the event name is unknown or the publish fails.
	 */
	@TestVisible
	private static void publishCustomPlatformEvent(String eventName, String eventPayload)
	{
		SObjectType objectType = UTIL_SObjectDescribe.getDescribe(eventName)?.getSObjectType();

		if(objectType == null)
		{
			throw buildAuraHandledException(String.format(System.Label.EventMonitor_UnknownPlatformEventType, new List<Object> {eventName}));
		}

		try
		{
			SObject platformEvent = (SObject)JSON.deserialize(eventPayload, UTIL_System.getRuntimeType(objectType.newSObject()));

			Database.SaveResult saveResult = EventBus.publishWithAccessLevel(platformEvent, AccessLevel.USER_MODE);

			if(!saveResult.success)
			{
				throw new DmlException(LOG_Engine.extractErrorMessage(saveResult.errors));
			}
		}
		catch(Exception error)
		{
			// Raw detail (JSON parser text, DML errors) belongs in the log, not the UI.
			LOG_Builder.build().error(error).at(CTRL_EventMonitor.class.getName() + '.publishCustomPlatformEvent').emit();

			throw buildAuraHandledException(String.format(System.Label.EventMonitor_PublishFailed, new List<Object> {eventName}));
		}
	}

	/**
	 * @description Private helper to publish a generic streaming event.
	 * Enqueues a Queueable job to make the necessary REST API callout. An unknown channel name and
	 * a failed callout both throw a label-sourced AuraHandledException; the raw failure detail of a
	 * failed callout is already logged and persisted by the API framework, so it is not rethrown.
	 *
	 * @param eventName The name of the StreamingChannel(without the '/u/').
	 * @param eventPayload The string payload to publish.
	 *
	 * @throws AuraHandledException if the StreamingChannel is not found or the publish fails.
	 */
	private static void publishGenericEvent(String eventName, String eventPayload)
	{
		StreamingChannel foundChannel = new SEL_StreamingChannel().findByName(eventName);

		if(foundChannel == null)
		{
			throw buildAuraHandledException(String.format(System.Label.EventMonitor_UnknownGenericEventType, new List<Object> {eventName}));
		}

		API_Base handler = API_Dispatcher.execute
				(
						TST_Factory.newOutboundApiCall
								(
										API_PublishGenericEvent.class.getName(),
										foundChannel.Id,
										API_PublishGenericEvent.REQUIRED_PARAMETER_PAYLOAD,
										eventPayload
								)
				);

		if(!handler.result.isSuccess)
		{
			// The dispatcher has already logged the failure and persisted its raw detail on the API call records.
			throw buildAuraHandledException(String.format(System.Label.EventMonitor_PublishFailed, new List<Object> {eventName}));
		}
	}

	/**
	 * @description Queries for all PushTopic names.
	 *
	 * @return A list of ComboBoxItems for PushTopics.
	 */
	@TestVisible
	private static List<ComboBoxItem> getPushTopicEventChannels()
	{
		List<ComboBoxItem> comboBoxItems = new List<ComboBoxItem>();

		for(PushTopic topic : new SEL_PushTopic().getAll())
		{
			comboBoxItems.add(new ComboBoxItem(topic.Name, topic.Name));
		}

		return comboBoxItems;
	}

	/**
	 * @description Queries for all generic StreamingChannel names(prefixed with /u/).
	 *
	 * @return A list of ComboBoxItems for generic channels.
	 */
	@TestVisible
	private static List<ComboBoxItem> getGenericEventChannels()
	{
		List<ComboBoxItem> comboBoxItems = new List<ComboBoxItem>();

		for(StreamingChannel channel : new SEL_StreamingChannel().getAllOrderByName())
		{
			String name = channel.Name.removeStart(SEL_StreamingChannel.GENERIC_EVENT_NAME_PREFIX);

			comboBoxItems.add(new ComboBoxItem(name, name));
		}

		return comboBoxItems;
	}

	/**
	 * @description Queries for all Change Data Capture(CDC) event channels,
	 * including both standard and custom objects.
	 *
	 * @return A list of ComboBoxItems for CDC channels.
	 */
	@TestVisible
	private static List<ComboBoxItem> getChangeDataCaptureEventChannels()
	{
		List<ComboBoxItem> comboBoxItems = new List<ComboBoxItem>();

		addChangeEventDefinition(new SEL_EntityDefinition().getAllChangeCaptureEvents(), comboBoxItems);

		comboBoxItems.sort();

		return comboBoxItems;
	}

	/**
	 * @description Adds each Change Data Capture entity to the combo-box list, grouping the picklist
	 * with a label-sourced `Standard: ` or `Custom: ` prefix (both translatable Custom Labels) so
	 * standard and custom change events sort into consistent neighbourhoods instead of interleaving.
	 * Custom change events are told apart by the `__ChangeEvent` suffix
	 * (`UTIL_SObjectDescribe.CUSTOM_CHANGE_EVENT_SUFFIX`). The combo-box value is always the entity
	 * `QualifiedApiName` verbatim — it is the channel api name and must never be rewritten.
	 *
	 * @param definitions The change-event entity definitions to process
	 * @param comboBoxItems The items to which to add definition details
	 */
	private static void addChangeEventDefinition(List<EntityDefinition> definitions, List<ComboBoxItem> comboBoxItems)
	{
		for(EntityDefinition entity : definitions)
		{
			String labelTemplate = entity.QualifiedApiName.endsWith(UTIL_SObjectDescribe.CUSTOM_CHANGE_EVENT_SUFFIX)
					? System.Label.EventMonitor_ChangeEventChannelCustom
					: System.Label.EventMonitor_ChangeEventChannelStandard;

			String groupedLabel = String.format(labelTemplate, new List<Object> {entity.Label});

			comboBoxItems.add(new ComboBoxItem(groupedLabel, entity.QualifiedApiName));
		}
	}

	/**
	 * @description Queries for all Custom Platform Event channels
	 *
	 * @return A list of ComboBoxItems for Custom Platform Events.
	 */
	@TestVisible
	private static List<ComboBoxItem> getCustomPlatformEventChannels()
	{
		List<ComboBoxItem> comboBoxItems = new List<ComboBoxItem>();

		for(EntityDefinition entity : new SEL_EntityDefinition().getAllCustomPlatformEvents())
		{
			comboBoxItems.add(new ComboBoxItem(entity.Label, entity.QualifiedApiName));
		}

		return comboBoxItems;
	}

	/**
	 * @description Queries for all standard Platform Event channels.
	 *
	 * @return List<ComboBoxItem> A list of ComboBoxItems for standard Platform Events.
	 */
	@TestVisible
	private static List<ComboBoxItem> getStandardPlatformEventChannels()
	{
		List<ComboBoxItem> items = new List<ComboBoxItem>();

		for(EntityDefinition entity : new SEL_EntityDefinition().getAllStandardPlatformEvents())
		{
			items.add(new ComboBoxItem(entity.Label, entity.QualifiedApiName));
		}

		return items;
	}

	/**
	 * @description Returns the static list of Event Monitoring channels.
	 *
	 * @return List<ComboBoxItem> A list of ComboBoxItems for monitoring channels.
	 */
	@TestVisible
	private static List<ComboBoxItem> getEventMonitoringChannels()
	{
		List<ComboBoxItem> items = new List<ComboBoxItem>();

		for(MonitoringEvent event : MonitoringEvent.values())
		{
			String eventValue = event.name();
			String eventLabel = eventValue.replaceAll('([a-z])([A-Z])', '$1 $2');

			items.add(new ComboBoxItem(eventLabel, eventValue));
		}
		return items;
	}

	/**
	 * @description Wrapper class for use in LWC/Aura combo boxes.
	 * Implements Comparable to allow sorting by label.
	 */
	public class ComboBoxItem implements Comparable
	{
		/**
		 * @description The display label for the combo box item.
		 */
		@AuraEnabled
		public String label;

		/**
		 * @description The channel the item stands for: a push topic name, a streaming channel name without its `/u/`
		 * prefix, or an event's API name. The label may add words for display; this value is never reworded.
		 */
		@AuraEnabled
		public String value;

		/**
		 * @description Sets the text the channel picker shows and the channel it stands for. Items sort by label, see
		 * compareTo.
		 *
		 * @param label The display label.
		 * @param value The corresponding value.
		 */
		public ComboBoxItem(String label, String value)
		{
			this.label = label;
			this.value = value;
		}

		/**
		 * @description Compares this item to another for sorting based on the label.
		 *
		 * @param other The object to compare against.
		 *
		 * @return Integer The comparison result.
		 */
		public Integer compareTo(Object other)
		{
			return this.label.compareTo(((ComboBoxItem)other).label);
		}
	}

	/**
	 * @description DTO class for OrgLimit data
	 */
	@TestVisible
	private class DTO_OrgLimitWrapper
	{
		/**
		 * @description The limit's name exactly as OrgLimit.getName() returns it; the controller does not turn it into a
		 * label.
		 */
		@AuraEnabled
		public String name;

		/**
		 * @description The limit's current value, from OrgLimit.getValue(). Never null: getOrgLimits leaves out any limit
		 * whose value or maximum is null.
		 */
		@AuraEnabled
		public Integer value;

		/**
		 * @description The maximum value for the org limit.
		 */
		@AuraEnabled
		public Integer max;

		/**
		 * @description Copies the name, the current value and the maximum out of one OrgLimit into this wrapper's @AuraEnabled
		 * fields, which getOrgLimits returns to the component.
		 *
		 * @param orgLimit One limit from OrgLimits.getAll().
		 */
		public DTO_OrgLimitWrapper(OrgLimit orgLimit)
		{
			max = orgLimit.getLimit();
			name = orgLimit.getName();
			value = orgLimit.getValue();
		}
	}

	/**
	 * @description The Salesforce Real-Time Event Monitoring events the Streaming Monitor offers under the "Monitoring event" type.
	 * Each value carries the platform event's API name, because the name is used as the channel to subscribe to (`/event/` plus
	 * the name) and, split into words, as its label in the channel picker. The list is fixed in this class, so a new platform
	 * event appears only once a value is added here; an org receives an event only when streaming is switched on for it in Event
	 * Manager, which for most of these events needs the Salesforce Shield or Event Monitoring add-on.
	 */
	@SuppressWarnings('PMD.FieldNamingConventions,ApexUnusedDeclaration')
	private enum MonitoringEvent
	{
		/**
		 * @description Raised when Salesforce detects an unusual pattern in how a user makes API calls, for example far more records read than normal.
		 */
		ApiAnomalyEvent,
		/**
		 * @description Raised for each API query a user runs (SOAP, REST or Bulk), carrying the query and the number of rows it read.
		 */
		ApiEventStream,
		/**
		 * @description Raised when a user downloads the results of a Bulk API job.
		 */
		BulkApiResultEvent,
		/**
		 * @description Raised when a request is refused because the org already has its maximum number of long-running Apex requests in flight.
		 */
		ConcurLongRunApexErrEvent,
		/**
		 * @description Raised when a consent record changes, for example a contact opting in to or out of email.
		 */
		ConsentEvent,
		/**
		 * @description Raised when a user logs in successfully during an attack that tries stolen username and password pairs against the org.
		 */
		CredentialStuffingEvent,
		/**
		 * @description Raised when a user works with a file, for example previews, downloads or uploads it.
		 */
		FileEvent,
		/**
		 * @description Raised when a user creates, opens, updates or deletes a record in Lightning Experience.
		 */
		LightningUriEventStream,
		/**
		 * @description Raised when a user opens or works with a list view, carrying the records the list showed.
		 */
		ListViewEventStream,
		/**
		 * @description Raised when an administrator logs in as another user.
		 */
		LoginAsEventStream,
		/**
		 * @description Raised for each login attempt, carrying who logged in, from where and with which client.
		 */
		LoginEventStream,
		/**
		 * @description Raised when a user logs out by choosing Log Out.
		 */
		LogoutEventStream,
		/**
		 * @description Raised when a user sends an email from a mobile app protected by Enhanced Mobile Security.
		 */
		MobileEmailEvent,
		/**
		 * @description Raised when a mobile security policy is enforced on a user's device, for example a blocked operating system version.
		 */
		MobileEnforcedPolicyEvent,
		/**
		 * @description Raised when a user takes a screenshot in a mobile app protected by Enhanced Mobile Security.
		 */
		MobileScreenshotEvent,
		/**
		 * @description Raised when a user makes a phone call or sends a text message from a mobile app protected by Enhanced Mobile Security.
		 */
		MobileTelephonyEvent,
		/**
		 * @description Raised when a permission is added to or removed from a permission set or permission set group, and when one
		 * that grants a critical permission is assigned to or removed from a user.
		 */
		PermissionSetEvent,
		/**
		 * @description Raised when Salesforce detects an unusual pattern in how a user runs or exports reports.
		 */
		ReportAnomalyEvent,
		/**
		 * @description Raised when a user runs or exports a report, carrying the report and the records it returned.
		 */
		ReportEventStream,
		/**
		 * @description Raised when Salesforce detects that a user's session is being used from a second, unexpected browser, which suggests a stolen session.
		 */
		SessionHijackingEvent,
		/**
		 * @description Raised when a user creates, opens, updates or deletes a record in Salesforce Classic.
		 */
		UriEventStream
	}

	/**
	 * @description The kinds of streaming event the Streaming Monitor can list, subscribe to and publish. A value's name is the
	 * text exchanged with the browser to say which kind is meant, so each is spelt exactly as the component expects it.
	 */
	@SuppressWarnings('PMD.FieldNamingConventions')
	@TestVisible
	private enum StreamingEventTypes
	{
		/**
		 * @description Change Data Capture events, raised when a record of a tracked object is created, updated, deleted or undeleted.
		 * The channel list holds every change event in the org, standard and custom.
		 */
		ChangeDataCaptureEvent,
		/**
		 * @description A custom channel that groups several change events into one stream. No channels are listed for this kind:
		 * the user types the channel name (after `/data/`) to subscribe, and such channels are created by a metadata deployment,
		 * not from the component.
		 */
		CustomChannelCDC,
		/**
		 * @description A custom channel that groups several platform events into one stream. No channels are listed for this kind:
		 * the user types the channel name (after `/event/`) to subscribe, and such channels are created by a metadata deployment,
		 * not from the component.
		 */
		CustomChannelPE,
		/**
		 * @description Generic streaming events, free-text messages sent on a streaming channel whose name starts with `/u/`.
		 * One of the two kinds that can be published from the component; the other is custom platform events.
		 */
		GenericEvent,
		/**
		 * @description Real-Time Event Monitoring events, the security and usage events Salesforce raises as users log in, read data and
		 * change permissions.
		 */
		MonitoringEvent,
		/**
		 * @description Custom platform events, the events defined in the org with an API name ending in `__e`.
		 * One of the two kinds that can be published from the component; the other is generic streaming events.
		 */
		PlatformEvent,
		/**
		 * @description PushTopic events, raised when a record matches the query of a PushTopic defined in the org.
		 */
		PushTopicEvent,
		/**
		 * @description Standard platform events, the events Salesforce itself defines and publishes; they can be watched but not published from here.
		 */
		StandardPlatformEvent
	}
}