// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) Philippe Ozil (CC0-1.0 — rights waived)
// Adapted from streaming-monitor (https://github.com/pozil/streaming-monitor)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description Unit test for related controlled class
 *
 * @see CTRL_EventMonitor
 *
 * @author Jason van Beukering
 *
 * @group Controllers
 *
 * @date February 2026, July 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CognitiveComplexity')
@IsTest(SeeAllData=false IsParallel=true)
private class CTRL_EventMonitor_TEST
{
	/**
	 * @description Tests that publishing an event throws a label-sourced AuraHandledException when
	 * the event type is unsupported, and that the thrown message names the event type.
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
			Assert.isInstanceOfType(error, AuraHandledException.class, 'Expected an AuraHandledException to be thrown');
			Assert.isTrue(error.getMessage().contains(CTRL_EventMonitor.StreamingEventTypes.PushTopicEvent.name()), 'The unsupported-type message should name the event type');
			Assert.isFalse(error.getMessage().contains('{0}'), 'The event-type placeholder should be substituted, not left literal');
		}
	}

	/**
	 * @description Tests that publishing an event throws a label-sourced AuraHandledException when
	 * the platform event type is not found (by name), and that the thrown message names the event.
	 *
	 * @see CTRL_EventMonitor.publishStreamingEvent
	 */
	@IsTest
	private static void publishStreamingEventPlatformEventUnknownName()
	{
		String unknownEventName = UTIL_Random.randomName();

		try
		{
			CTRL_EventMonitor.publishStreamingEvent
					(
							CTRL_EventMonitor.StreamingEventTypes.PlatformEvent.name(),
							unknownEventName,
							UTIL_String.EMPTY_JSON_RESPONSE
					);
			Assert.fail('Exception was expected');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, AuraHandledException.class, 'Expected an AuraHandledException to be thrown');
			Assert.isTrue(error.getMessage().contains(unknownEventName), 'The unknown-platform-event message should name the event');
			Assert.isFalse(error.getMessage().contains('{0}'), 'The event-name placeholder should be substituted, not left literal');
		}
	}

	/**
	 * @description Tests that publishing an event with an invalid JSON payload throws a label-sourced
	 * AuraHandledException — the raw parser text goes to the logger, never the UI — and that the
	 * thrown publish-failure message names the event.
	 *
	 * @see CTRL_EventMonitor.publishStreamingEvent
	 */
	@IsTest
	private static void publishStreamingPlatformEventErrorInvalidPayload()
	{
		String eventName = UTIL_SObjectDescribe.getDescribe(LogEntryEvent__e.SObjectType).getDescribe().name;

		try
		{
			CTRL_EventMonitor.publishStreamingEvent
					(
							CTRL_EventMonitor.StreamingEventTypes.PlatformEvent.name(),
							eventName,
							UTIL_Random.randomName()
					);
			Assert.fail('Exception was expected');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, AuraHandledException.class, 'Expected an AuraHandledException to be thrown');
			Assert.isTrue(error.getMessage().contains(eventName), 'The publish-failure message should name the event');
			Assert.isFalse(error.getMessage().contains('{0}'), 'The event-name placeholder should be substituted, not left literal');
		}
	}

	/**
	 * @description Tests that publishing an event throws a label-sourced AuraHandledException when
	 * the generic event type is not found (by name), and that the thrown message names the channel.
	 *
	 * @see CTRL_EventMonitor.publishStreamingEvent
	 */
	@IsTest
	private static void publishStreamingEventGenericEventUnknownName()
	{
		String unknownChannelName = UTIL_Random.randomName();

		try
		{
			CTRL_EventMonitor.publishStreamingEvent
					(
							CTRL_EventMonitor.StreamingEventTypes.GenericEvent.name(),
							unknownChannelName,
							UTIL_String.EMPTY_JSON_RESPONSE
					);
			Assert.fail('Exception was expected');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, AuraHandledException.class, 'Expected an AuraHandledException to be thrown');
			Assert.isTrue(error.getMessage().contains(unknownChannelName), 'The unknown-channel message should name the channel');
			Assert.isFalse(error.getMessage().contains('{0}'), 'The channel-name placeholder should be substituted, not left literal');
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

			Assert.fail('Expected an AuraHandledException to be thrown');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, AuraHandledException.class, 'Expected the raw DML failure to surface as a label-sourced AuraHandledException');
			Assert.isTrue(error.getMessage().contains(objectName), 'The publish-failure message should name the event');
			Assert.isFalse(error.getMessage().contains('{0}'), 'The event-name placeholder should be substituted, not left literal');
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
	 * @description Tests that a failing API call surfaces as a label-sourced AuraHandledException
	 * naming the channel — the raw API failure detail is recorded by the API framework, not rethrown.
	 *
	 * @see CTRL_EventMonitor.publishGenericEvent
	 */
	@IsTest
	private static void publishGenericEventFailed()
	{
		API_MockFactory.registerErrorMock(API_PublishGenericEvent.class.getName());

		StreamingChannel newChannel = createNewChannel();
		String publishName = newChannel.Name.removeStart(SEL_StreamingChannel.GENERIC_EVENT_NAME_PREFIX);

		try
		{
			Test.startTest();

			CTRL_EventMonitor.publishStreamingEvent
					(
							CTRL_EventMonitor.StreamingEventTypes.GenericEvent.name(),
							publishName,
							UTIL_Random.randomName()
					);

			Test.stopTest();

			Assert.fail('Expected Exception to be thrown for failing API call');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, AuraHandledException.class, 'Expected the API failure to surface as a label-sourced AuraHandledException');
			Assert.isTrue(error.getMessage().contains(publishName), 'The publish-failure message should name the channel');
			Assert.isFalse(error.getMessage().contains('{0}'), 'The channel-name placeholder should be substituted, not left literal');
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
		TST_Mock.of(EntityDefinition.SObjectType)
				.withOverride(EntityDefinition.Label, 'Change Event: Foobar')
				.withOverride(EntityDefinition.QualifiedApiName, 'Foobar__ChangeEvent')
				.build();

		Test.startTest();

		Map<String, List<CTRL_EventMonitor.ComboBoxItem>> channels = CTRL_EventMonitor.getAllEventChannels();

		Test.stopTest();

		Assert.areEqual(CTRL_EventMonitor.StreamingEventTypes.values().size(), channels.size(), 'Incorrect number of Channel types returned');
		Assert.isFalse(channels.get(CTRL_EventMonitor.StreamingEventTypes.ChangeDataCaptureEvent.name()).isEmpty(), 'Expected CDC channels from mock data');

		List<CTRL_EventMonitor.ComboBoxItem> changeDataCaptureItems = channels.get(CTRL_EventMonitor.StreamingEventTypes.ChangeDataCaptureEvent.name());

		Boolean foundStandardChangeEvent = false;
		Boolean foundCustomChangeEvent = false;

		for(CTRL_EventMonitor.ComboBoxItem item : changeDataCaptureItems)
		{
			if(item.value == 'AccountChangeEvent')
			{
				foundStandardChangeEvent = true;
				Assert.areEqual('Standard: Account Change Event', item.label, 'Standard change events should carry the Standard: group prefix');
			}
			if(item.value == 'Foobar__ChangeEvent')
			{
				foundCustomChangeEvent = true;
				Assert.areEqual('Custom: Change Event: Foobar', item.label, 'Custom change events should carry the Custom: group prefix with the api name unmodified');
			}
		}

		Assert.isTrue(foundStandardChangeEvent, 'Standard change events must appear in the CDC channel list from the single-query discovery');
		Assert.isTrue(foundCustomChangeEvent, 'Custom ChangeEvent channel should be listed without api-name rewriting');
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
	 * @description Checks that the related method throws a label-sourced AuraHandledException for an
	 * invalid event name — the raw describe failure goes to the logger, never the UI — and that the
	 * thrown payload-template message names the event.
	 *
	 * @see CTRL_EventMonitor.getInitialisedEvent
	 */
	@IsTest
	private static void getBlankPlatformEventInvalidEventName()
	{
		String invalidEventName = UTIL_Random.randomName();

		try
		{
			CTRL_EventMonitor.getInitialisedEvent(invalidEventName);
			Assert.fail('Exception was expected');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, AuraHandledException.class, 'Expected an AuraHandledException for an event whose type is invalid');
			Assert.isTrue(error.getMessage().contains(invalidEventName), 'The payload-template message should name the event');
			Assert.isFalse(error.getMessage().contains('{0}'), 'The event-name placeholder should be substituted, not left literal');
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
	 * @description Checks that usage metrics default to the Daily segment when no arguments
	 * are supplied (legacy LWC call shape).
	 *
	 * @see CTRL_EventMonitor.getEventUsageMetrics
	 */
	@IsTest
	private static void getEventUsageMetricsDefaultsToDaily()
	{
		Test.startTest();

		List<PlatformEventUsageMetric> usageMetrics = CTRL_EventMonitor.getEventUsageMetrics(null, null, null);

		Test.stopTest();

		Assert.isNotNull(usageMetrics, 'Expected Usage Metrics to be found with defaulted segment');
	}

	/**
	 * @description Checks that a valid non-default segment with an in-window date range is accepted
	 * and routed to the selector. The probe is forced on and the query is mocked so the enhanced
	 * branch is exercised regardless of org capability — the TimeSegment column only exists in orgs
	 * with Enhanced Usage Metrics, so an unmocked query would throw QueryException elsewhere.
	 *
	 * @see CTRL_EventMonitor.getEventUsageMetrics
	 */
	@IsTest
	private static void getEventUsageMetricsAcceptsValidSegmentAndRange()
	{
		SEL_PlatformEventUsageMetric.timeSegmentAvailableOverride = true;

		TST_Mock.of(PlatformEventUsageMetric.SObjectType)
				.withOverride(PlatformEventUsageMetric.Name, 'PLATFORM_EVENTS_PUBLISHED')
				.withOverride(PlatformEventUsageMetric.Value, 7)
				.build();

		Test.startTest();

		List<PlatformEventUsageMetric> usageMetrics = CTRL_EventMonitor.getEventUsageMetrics(
				SEL_PlatformEventUsageMetric.TimeSegment.Hourly.name(), Datetime.now().addHours(-12), Datetime.now());

		Test.stopTest();

		Assert.isNotNull(usageMetrics, 'Expected Usage Metrics for a valid segment and range');
	}

	/**
	 * @description Checks that an unknown segment value is rejected with an AuraHandledException.
	 *
	 * @see CTRL_EventMonitor.getEventUsageMetrics
	 */
	@IsTest
	private static void getEventUsageMetricsRejectsInvalidSegment()
	{
		Boolean threwExpected = false;

		Test.startTest();

		try
		{
			CTRL_EventMonitor.getEventUsageMetrics('Weekly', null, null);
		}
		catch(AuraHandledException error)
		{
			threwExpected = true;
			Assert.areEqual(System.Label.EventUsageMetrics_Validation_UnsupportedSegment, error.getMessage(), 'The unsupported-segment message should be the label text');
		}

		Test.stopTest();

		Assert.isTrue(threwExpected, 'Unknown time segment should throw AuraHandledException');
	}

	/**
	 * @description Checks that a date range wider than the segment's platform window is rejected
	 * with an AuraHandledException before the query reaches the platform validator.
	 *
	 * @see CTRL_EventMonitor.getEventUsageMetrics
	 */
	@IsTest
	private static void getEventUsageMetricsRejectsTooWideRange()
	{
		Boolean threwExpected = false;

		Test.startTest();

		try
		{
			CTRL_EventMonitor.getEventUsageMetrics(
					SEL_PlatformEventUsageMetric.TimeSegment.Hourly.name(), Datetime.now().addDays(-7), Datetime.now());
		}
		catch(AuraHandledException error)
		{
			threwExpected = true;
			Assert.isTrue(error.getMessage().contains(System.Label.EventUsageMetrics_Window_Hourly), 'The range-too-wide message should name the segment maximum window');
			Assert.isFalse(error.getMessage().contains('{0}'), 'The window placeholder should be substituted, not left literal');
		}

		Test.stopTest();

		Assert.isTrue(threwExpected, 'A range wider than the Hourly window should throw AuraHandledException');
	}

	/**
	 * @description Checks that a date range narrower than one segment bucket is rejected with an
	 * AuraHandledException before the query reaches the platform validator, which rejects sub-bucket
	 * ranges outright with a raw TimeSegmentValueTooLargeException (live-verified) instead of
	 * returning empty. The 51-minute Hourly range is the live repro that surfaced the gap.
	 *
	 * @see CTRL_EventMonitor.getEventUsageMetrics
	 */
	@IsTest
	private static void getEventUsageMetricsRejectsTooNarrowRange()
	{
		Boolean threwExpected = false;

		Test.startTest();

		try
		{
			CTRL_EventMonitor.getEventUsageMetrics(
					SEL_PlatformEventUsageMetric.TimeSegment.Hourly.name(),
					Datetime.newInstance(2026, 6, 5, 13, 24, 0),
					Datetime.newInstance(2026, 6, 5, 14, 15, 0));
		}
		catch(AuraHandledException error)
		{
			threwExpected = true;
			Assert.isTrue(error.getMessage().contains(System.Label.EventUsageMetrics_Minimum_Hourly), 'The range-too-narrow message should name the segment minimum range');
			Assert.isFalse(error.getMessage().contains('{0}'), 'The minimum placeholder should be substituted, not left literal');
		}

		Test.stopTest();

		Assert.isTrue(threwExpected, 'A range narrower than one Hourly bucket should throw AuraHandledException');
	}

	/**
	 * @description Checks that a range exactly one bucket wide is accepted — the platform minimum is
	 * inclusive (live-verified: a 60-minute Hourly range queries cleanly), so the boundary must not
	 * be rejected by the too-narrow guard.
	 *
	 * @see CTRL_EventMonitor.getEventUsageMetrics
	 */
	@IsTest
	private static void getEventUsageMetricsAcceptsExactBucketWidthRange()
	{
		SEL_PlatformEventUsageMetric.timeSegmentAvailableOverride = true;

		TST_Mock.of(PlatformEventUsageMetric.SObjectType)
				.withOverride(PlatformEventUsageMetric.Name, 'PLATFORM_EVENTS_PUBLISHED')
				.withOverride(PlatformEventUsageMetric.Value, 7)
				.build();

		Test.startTest();

		List<PlatformEventUsageMetric> usageMetrics = CTRL_EventMonitor.getEventUsageMetrics(
				SEL_PlatformEventUsageMetric.TimeSegment.Hourly.name(), Datetime.now().addMinutes(-60), Datetime.now());

		Test.stopTest();

		Assert.isNotNull(usageMetrics, 'Expected a range exactly one bucket wide to be accepted');
	}

	/**
	 * @description Checks that a start date after the end date is rejected with an
	 * AuraHandledException.
	 *
	 * @see CTRL_EventMonitor.getEventUsageMetrics
	 */
	@IsTest
	private static void getEventUsageMetricsRejectsStartAfterEnd()
	{
		Boolean threwExpected = false;

		Test.startTest();

		try
		{
			CTRL_EventMonitor.getEventUsageMetrics(
					SEL_PlatformEventUsageMetric.TimeSegment.Daily.name(), Datetime.now(), Datetime.now().addDays(-1));
		}
		catch(AuraHandledException error)
		{
			threwExpected = true;
			Assert.areEqual(System.Label.EventUsageMetrics_Validation_StartAfterEnd, error.getMessage(), 'The start-after-end message should be the label text');
		}

		Test.stopTest();

		Assert.isTrue(threwExpected, 'A start after the end should throw AuraHandledException');
	}

	/**
	 * @description Checks that the Enhanced Usage Metrics probe relays the selector capability.
	 *
	 * @see CTRL_EventMonitor.isEnhancedUsageMetricEnabled
	 */
	@IsTest
	private static void isEnhancedUsageMetricEnabledRelaysProbe()
	{
		SEL_PlatformEventUsageMetric.timeSegmentAvailableOverride = true;

		Assert.isTrue(CTRL_EventMonitor.isEnhancedUsageMetricEnabled(), 'Probe override true should relay as enabled');

		SEL_PlatformEventUsageMetric.timeSegmentAvailableOverride = false;

		Assert.isFalse(CTRL_EventMonitor.isEnhancedUsageMetricEnabled(), 'Probe override false should relay as disabled');
	}
}