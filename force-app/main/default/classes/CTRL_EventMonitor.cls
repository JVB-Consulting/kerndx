// SPDX-License-Identifier: BUSL-1.1
/**
* https://github.com/pozil/streaming-monito is licensed under the Creative Commons Zero v1.0 Universal
*/

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
 * @date February 2026, May 2026
 */
public inherited sharing class CTRL_EventMonitor
{
	/**
	 * @description Publishes a streaming event based on its type.This is the main
	 * entry point for publishing events from the UI.
	 *
	 * @param eventType The type of event to publish(see EVT_ constants).
	 * @param eventName The API name of the event or channel.
	 * @param eventPayload The JSON payload for the event.
	 *
	 * @throws IllegalArgumentException if the event type is unsupported.
	 */
	@AuraEnabled
	public static void publishStreamingEvent(String eventType, String eventName, String eventPayload)
	{
		try
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
				throw new IllegalArgumentException('Unsupported event type: ' + eventType);
			}
		}
		catch(Exception error)
		{
			LOG_Builder.build().error(error).at(CTRL_EventMonitor.class.getName() + '.publishStreamingEvent').emit();

			error.setMessage('Unable to publish event due to following error' + UTIL_String.LF + error.getMessage());

			throw error;
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
	 * @description Retrieves platform event usage metrics, ordered by start date.
	 *
	 * @return List of found items
	 */
	@AuraEnabled
	public static List<PlatformEventUsageMetric> getEventUsageMetrics()
	{
		return new SEL_PlatformEventUsageMetric().getAllOrderByStartDate();
	}

	/**
	 * @description Generates a blank payload map(field name -> default value)
	 * for a given platform event.This excludes standard platform event fields.
	 *
	 * @param eventName The API name of the platform event(e.g., 'MyEvent__e').
	 *
	 * @return Map<String, Object> A map representing the blank event payload.
	 */
	@AuraEnabled
	public static SObject getInitialisedEvent(String eventName)
	{
		try
		{
			UTIL_SObjectDescribe objectDescribe = UTIL_SObjectDescribe.getDescribe(eventName);

			final List<String> fieldsToIgnore = new List<String>
			{
					LogEntryEvent__e.CreatedById.getDescribe().name.toLowerCase(),
					LogEntryEvent__e.CreatedDate.getDescribe().name.toLowerCase(),
					LogEntryEvent__e.EventUuid.getDescribe().name.toLowerCase(),
					LogEntryEvent__e.ReplayId.getDescribe().name.toLowerCase()
			};

			Map<String, SObjectField> objectFieldMap = objectDescribe.getFieldsMap();

			List<SObjectField> fieldsToDefault = new List<SObjectField>();

			for(String fieldName : objectFieldMap.keySet())
			{
				if(!fieldsToIgnore.contains(fieldName))
				{
					fieldsToDefault.add(objectFieldMap.get(fieldName));
				}
			}

			return TST_Builder.of(objectDescribe.getSObjectType())
					.withoutInsertion()
					.withDefaultedFields(fieldsToDefault)
					.build();

		}
		catch(Exception error)
		{
			error.setMessage('Following error occured for event name "' + eventName + '"' + UTIL_String.LF + error.getMessage());
			throw error;
		}
	}

	/**
	 * @description Private helper to publish a specific Platform Event.
	 *
	 * @param eventName The API name of the platform event.
	 * @param eventPayload The JSON payload to deserialize and publish.
	 */
	@TestVisible
	private static void publishCustomPlatformEvent(String eventName, String eventPayload)
	{
		SObjectType objectType = UTIL_SObjectDescribe.getDescribe(eventName)?.getSObjectType();

		if(objectType == null)
		{
			throw new IllegalArgumentException('Unknown platform event type: ' + eventName);
		}

		SObject platformEvent = (SObject)JSON.deserialize(eventPayload, UTIL_System.getRuntimeType(objectType.newSObject()));

		Database.SaveResult saveResult = EventBus.publish(platformEvent);

		if(!saveResult.success)
		{
			throw new DmlException(LOG_Engine.extractErrorMessage(saveResult.errors));
		}
	}

	/**
	 * @description Private helper to publish a generic streaming event.
	 * Enqueues a Queueable job to make the necessary REST API callout.
	 *
	 * @param eventName The name of the StreamingChannel(without the '/u/').
	 * @param eventPayload The string payload to publish.
	 *
	 * @throws IllegalArgumentException if the StreamingChannel is not found.
	 */
	private static void publishGenericEvent(String eventName, String eventPayload)
	{
		StreamingChannel foundChannel = new SEL_StreamingChannel().findByName(eventName);

		if(foundChannel == null)
		{
			throw new IllegalArgumentException('Unknown generic event type: ' + eventName);
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
			throw new IllegalArgumentException(handler.errorText);
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

		addChangeEventDefinition(new SEL_EntityDefinition().getAllStandardChangeCaptureEvents(), comboBoxItems, false);
		addChangeEventDefinition(new SEL_EntityDefinition().getAllCustomChangeCaptureEvents(), comboBoxItems, true);

		comboBoxItems.sort();

		return comboBoxItems;
	}

	/**
	 * @description Will loop through definitions and add them to combo box list
	 *
	 * @param definitions The entity definitions to process
	 * @param comboBoxItems The items to which to add definition details
	 * @param isCustom Indicates if the entity definition is for a custom change capture event; requires special processing
	 */
	private static void addChangeEventDefinition(List<EntityDefinition> definitions, List<ComboBoxItem> comboBoxItems, Boolean isCustom)
	{
		for(EntityDefinition entity : definitions)
		{
			String label = isCustom ? entity.Label + ' Change Event' : entity.Label;
			String value = isCustom ? entity.QualifiedApiName.replace(UTIL_SObjectDescribe.CUSTOM_FIELD_SUFFIX, '__ChangeEvent') : entity.QualifiedApiName;
			comboBoxItems.add(new ComboBoxItem(label, value));
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
		 * @description The value for the combo box item.
		 */
		@AuraEnabled
		public String value;

		/**
		 * @description Constructor for ComboBoxItem.
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
		 * @description The name of the org limit.
		 */
		@AuraEnabled
		public String name;

		/**
		 * @description The current value of the org limit.
		 */
		@AuraEnabled
		public Integer value;

		/**
		 * @description The maximum value for the org limit.
		 */
		@AuraEnabled
		public Integer max;

		/**
		 * @description Constructor for OrgLimitWrapper.
		 *
		 * @param orgLimit The OrgLimit SObject to wrap.
		 */
		public DTO_OrgLimitWrapper(OrgLimit orgLimit)
		{
			max = orgLimit.getLimit();
			name = orgLimit.getName();
			value = orgLimit.getValue();
		}
	}

	/**
	 * @description Enum of event names available for Event Monitoring.
	 */
	@SuppressWarnings('PMD.FieldNamingConventions,ApexUnusedDeclaration')
	private enum MonitoringEvent
	{
		ApiAnomalyEvent,
		ApiEventStream,
		BulkApiResultEvent,
		ConcurLongRunApexErrEvent,
		ConsentEvent,
		CredentialStuffingEvent,
		FileEvent,
		LightningUriEventStream,
		ListviewEventStream,
		LoginAsEventStream,
		LoginEventStream,
		LogoutEventStream,
		MobileEmailEvent,
		MobileEnforcedPolicyEvent,
		MobileScreenshotEvent,
		MobileTelephonyEvent,
		PermissionSetEvent,
		ReportAnomalyEvent,
		ReportEventStream,
		SessionHijackingEvent,
		UriEventStream
	}

	/**
	 * @description Constants representing different streaming event types used by the controller to categorize channels and actions.
	 */
	@SuppressWarnings('PMD.FieldNamingConventions')
	@TestVisible
	private enum StreamingEventTypes
	{
		ChangeDataCaptureEvent,
		CustomChannelCDC,
		CustomChannelPE,
		GenericEvent,
		MonitoringEvent,
		PlatformEvent,
		PushTopicEvent,
		StandardPlatformEvent
	}
}