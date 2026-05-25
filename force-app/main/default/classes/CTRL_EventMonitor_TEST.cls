// SPDX-License-Identifier: BUSL-1.1
/**
*  https://github.com/pozil/streaming-monito is licensed under the Creative Commons Zero v1.0 Universal
*/

/**
 * @description Unit test for related controlled class
 *
 * @see CTRL_EventMonitor
 *
 * @author Jason van Beukering
 *
 * @group Controllers
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class CTRL_EventMonitor_TEST
{
	/**
	 * @description Tests that publishing an event throws an error when the event type is unsupported
	 *
	 * @see CTRL_EventMonitor.publishStreamingEvent
	 */
	@IsTest
	private static void publishStreamingEventErrorUnsupportedEventType()
	{
		try
		{
			CTRL_EventMonitor.publishStreamingEvent(CTRL_EventMonitor.StreamingEventTypes.PushTopicEvent.name(), UTIL_String.EMPTY, UTIL_String.EMPTY_JSON_RESPONSE);
			Assert.fail('Exception was expected');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected an IllegalArgumentException to be thrown');
		}
	}

	/**
	 * @description Tests that publishing an event throws an error when the platform event type is not found (by name)
	 *
	 * @see CTRL_EventMonitor.publishStreamingEvent
	 */
	@IsTest
	private static void publishStreamingEventPlatformEventUnknownName()
	{
		try
		{
			CTRL_EventMonitor.publishStreamingEvent
					(
							CTRL_EventMonitor.StreamingEventTypes.PlatformEvent.name(),
							UTIL_Random.randomName(),
							UTIL_String.EMPTY_JSON_RESPONSE
					);
			Assert.fail('Exception was expected');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected an IllegalArgumentException to be thrown');
		}
	}

	/**
	 * @description Tests that publishing an event throws an error when the provided JSON payload is invalid
	 *
	 * @see CTRL_EventMonitor.publishStreamingEvent
	 */
	@IsTest
	private static void publishStreamingPlatformEventErrorInvalidPayload()
	{
		try
		{
			CTRL_EventMonitor.publishStreamingEvent
					(
							CTRL_EventMonitor.StreamingEventTypes.PlatformEvent.name(),
							UTIL_SObjectDescribe.getDescribe(LogEntryEvent__e.SObjectType).getDescribe().name,
							UTIL_Random.randomName()
					);
			Assert.fail('Exception was expected');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, JSONException.class, 'Expected an JSONException to be thrown');
		}
	}

	/**
	 * @description Tests that publishing an event throws an error when the generic event type is not found (by name)
	 *
	 * @see CTRL_EventMonitor.publishStreamingEvent
	 */
	@IsTest
	private static void publishStreamingEventGenericEventUnknownName()
	{
		try
		{
			CTRL_EventMonitor.publishStreamingEvent
					(
							CTRL_EventMonitor.StreamingEventTypes.GenericEvent.name(),
							UTIL_Random.randomName(),
							UTIL_String.EMPTY_JSON_RESPONSE
					);
			Assert.fail('Exception was expected');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected an IllegalArgumentException to be thrown');
		}
	}

	/**
	 * @description Tests that publishing a generic event succeeds
	 *
	 * @see CTRL_EventMonitor.publishGenericEvent
	 */
	@IsTest
	private static void publishGenericEvent()
	{
		createChannelAndPublishGenericEvent();
		SEL_ApiCall.assertServiceCompleted(API_PublishGenericEvent.class.getName());
	}

	/**
	 * @description Tests that publishing a custom platform event succeeds
	 *
	 * @see CTRL_EventMonitor.publishCustomPlatformEvent
	 */
	@IsTest
	private static void publishCustomPlatformEvent()
	{
		String objectName = UTIL_SObjectDescribe.getDescribe(LogEntryEvent__e.SObjectType).getDescribe().name;
		LogEntryEvent__e logEntryEvent = (LogEntryEvent__e)CTRL_EventMonitor.getInitialisedEvent(objectName);
		String payload = JSON.serialize(logEntryEvent);

		Test.startTest();

		CTRL_EventMonitor.publishStreamingEvent
				(
						CTRL_EventMonitor.StreamingEventTypes.PlatformEvent.name(),
						objectName,
						payload
				);

		Test.stopTest();

		List<LogEntry__c> logs = new SEL_LogEntry().getAll();

		Assert.isFalse(logs.isEmpty(), 'Expected Log Entry Event to have been published');
		Assert.areEqual(logEntryEvent.Message__c, logs.iterator().next().Message__c, 'Expected Message to match');
	}

	/**
	 * @description Tests that publishing a custom platform event fails correctly
	 *
	 * @see CTRL_EventMonitor.publishCustomPlatformEvent
	 */
	@IsTest
	private static void publishCustomPlatformEventFailed()
	{
		String objectName = UTIL_SObjectDescribe.getDescribe(LogEntryEvent__e.SObjectType).getDescribe().name;
		LogEntryEvent__e logEntryEvent = (LogEntryEvent__e)CTRL_EventMonitor.getInitialisedEvent(objectName);
		//Will force an error on publish
		logEntryEvent.ShortMessage__c = UTIL_Random.randomAlphabetic(LogEntryEvent__e.ShortMessage__c.getDescribe().length + 1);
		String payload = JSON.serialize(logEntryEvent);

		try
		{
			Test.startTest();

			CTRL_EventMonitor.publishStreamingEvent
					(
							CTRL_EventMonitor.StreamingEventTypes.PlatformEvent.name(),
							objectName,
							payload
					);

			Test.stopTest();

			Assert.fail('Expected an DmlException to be thrown');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, DmlException.class, 'Exception thrown was not an EventObjectException');
		}
	}

	/**
	 * @description Will create a streaming channel and then attempt to publish an event via API to it
	 */
	private static void createChannelAndPublishGenericEvent()
	{
		StreamingChannel newChannel = createNewChannel();

		Test.startTest();

		CTRL_EventMonitor.publishStreamingEvent
				(
						CTRL_EventMonitor.StreamingEventTypes.GenericEvent.name(),
						newChannel.Name.removeStart(SEL_StreamingChannel.GENERIC_EVENT_NAME_PREFIX),
						UTIL_Random.randomName()
				);

		Test.stopTest();
	}

	private static StreamingChannel createNewChannel()
	{
		StreamingChannel newChannel = (StreamingChannel)TST_Builder.of(StreamingChannel.SObjectType)
				.withOverrides
						(
								new Map<SObjectField, Object>
								{
										StreamingChannel.Name => SEL_StreamingChannel.GENERIC_EVENT_NAME_PREFIX + UTIL_Random.randomName()
								}
						)
				.build();
		return newChannel;
	}

	/**
	 * @description Tests that publishing an event throws an error when the generic event type is not found (by name)
	 *
	 * @see CTRL_EventMonitor.publishGenericEvent
	 */
	@IsTest
	private static void publishGenericEventFailed()
	{
		API_MockFactory.registerErrorMock(API_PublishGenericEvent.class.getName());

		try
		{
			createChannelAndPublishGenericEvent();
			Assert.fail('Expected Exception to be thrown for failing API call');

		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected an IllegalArgumentException to be thrown');
		}
	}

	/**
	 * @description Tests that related method return all the event channels available
	 *
	 * @see CTRL_EventMonitor.getAllEventChannels
	 */
	@IsTest
	private static void getAllEventChannels()
	{
		TST_Mock.of(EntityDefinition.SObjectType)
				.withOverride(EntityDefinition.Label, 'Account Change Event')
				.withOverride(EntityDefinition.QualifiedApiName, 'AccountChangeEvent')
				.build();
		TST_Mock.of(EntityDefinition.SObjectType)
				.withOverride(EntityDefinition.Label, 'Contact Change Event')
				.withOverride(EntityDefinition.QualifiedApiName, 'ContactChangeEvent')
				.build();
		TST_Mock.of(EntityDefinition.SObjectType)
				.withOverride(EntityDefinition.Label, 'Login Event')
				.withOverride(EntityDefinition.QualifiedApiName, 'LoginEvent')
				.build();

		Test.startTest();

		Map<String, List<CTRL_EventMonitor.ComboBoxItem>> channels = CTRL_EventMonitor.getAllEventChannels();

		Test.stopTest();

		Assert.areEqual(CTRL_EventMonitor.StreamingEventTypes.values().size(), channels.size(), 'Incorrect number of Channel types returned');
		Assert.isFalse(channels.get(CTRL_EventMonitor.StreamingEventTypes.ChangeDataCaptureEvent.name()).isEmpty(), 'Expected CDC channels from mock data');
	}

	/**
	 * @description Checks that the related method retrieves existing push topic event channels
	 *
	 * @see CTRL_EventMonitor.getPushTopicEventChannels
	 */
	@IsTest
	private static void getPushTopicEventChannels()
	{
		PushTopic newTopic = (PushTopic)TST_Builder.of(PushTopic.SObjectType)
				.withOverrides
						(
								new Map<SObjectField, Object>
								{
										PushTopic.Query => QRY_Builder.selectFrom(Foobar__c.SObjectType)
												.fields(new List<String> {'Name', 'Id'})
												.toSoql(),
										PushTopic.ApiVersion => Decimal.valueOf(UTIL_System.getOrgApiVersion())
								}
						)
				.build();

		Test.startTest();

		List<CTRL_EventMonitor.ComboBoxItem> comboBoxItems = CTRL_EventMonitor.getPushTopicEventChannels();

		Test.stopTest();

		Assert.areEqual(1, comboBoxItems.size(), 'Incorrect number of Push Topics');
		Assert.areEqual(newTopic.Name, comboBoxItems.iterator().next().value, 'Combo Item name not set correctly');
	}

	/**
	 * @description Checks that the related method retrieves existing generic event channels
	 *
	 * @see CTRL_EventMonitor.getGenericEventChannels
	 */
	@IsTest
	private static void getGenericEventChannels()
	{
		StreamingChannel newChannel = createNewChannel();

		Test.startTest();

		List<CTRL_EventMonitor.ComboBoxItem> comboBoxItems = CTRL_EventMonitor.getGenericEventChannels();

		Test.stopTest();

		Assert.areEqual(1, comboBoxItems.size(), 'Incorrect number of Streaming Channels');
		Assert.areEqual(newChannel.Name, SEL_StreamingChannel.GENERIC_EVENT_NAME_PREFIX + comboBoxItems.iterator().next().value, 'Combo Item name not set correctly');
	}

	/**
	 * @description Checks that the related method returns an initialised platform event
	 *
	 * @see CTRL_EventMonitor.getInitialisedEvent
	 */
	@IsTest
	private static void getInitialisedEvent()
	{
		LogEntryEvent__e event = (LogEntryEvent__e)CTRL_EventMonitor.getInitialisedEvent(UTIL_SObjectDescribe.getDescribe(LogEntryEvent__e.SObjectType).getDescribe().name);

		Assert.isNotNull(event.ClassMethod__c, 'Field not initialised');
		Assert.isNull(event.ReplayId, 'Field should NOT be initialised');
	}

	/**
	 * @description Checks that the related method throws an exception for an invalid event name
	 *
	 * @see CTRL_EventMonitor.getInitialisedEvent
	 */
	@IsTest
	private static void getBlankPlatformEventInvalidEventName()
	{
		try
		{
			CTRL_EventMonitor.getInitialisedEvent(UTIL_Random.randomName());
			Assert.fail('Exception was expected');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, NullPointerException.class, 'Expected a NullPointerException for a event whose type is invalid');
		}
	}

	/**
	 * @description Checks that the related method returns limits
	 *
	 * @see CTRL_EventMonitor.getOrgLimits
	 */
	@IsTest
	private static void getOrgLimits()
	{
		Test.startTest();

		List<CTRL_EventMonitor.DTO_OrgLimitWrapper> orgLimits = CTRL_EventMonitor.getOrgLimits();

		Test.stopTest();

		Assert.isFalse(orgLimits.isEmpty(), 'Expected Org Limits to be Found');
		Assert.isTrue(String.isNotBlank(orgLimits.iterator().next().name), 'No Name set');
	}

	/**
	 * @description Checks that the related method returns usage metrics
	 *
	 * @see CTRL_EventMonitor.getEventUsageMetrics
	 */
	@IsTest
	private static void getEventUsageMetrics()
	{
		Test.startTest();

		List<PlatformEventUsageMetric> usageMetrics = CTRL_EventMonitor.getEventUsageMetrics();

		Test.stopTest();

		//Note: we can't actually simulate subscribing to events, so we've just added
		Assert.isNotNull(usageMetrics, 'Expected Usage Metrics to be Found');
	}
}