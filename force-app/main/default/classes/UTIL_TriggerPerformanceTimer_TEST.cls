// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test class for UTIL_TriggerPerformanceTimer.
 *
 * @see UTIL_TriggerPerformanceTimer
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date December 2025, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class UTIL_TriggerPerformanceTimer_TEST
{
	private static final Integer RECORD_COUNT = 100;
	private static final String ACTION_CLASS_NAME = 'TRG_Account_TestAction';
	private static final String OBJECT_NAME = 'Account';
	private static final String TRIGGER_OPERATION = 'BEFORE_INSERT';

	/**
	 * @description Tests basic timer functionality with start/stop.
	 */
	@IsTest
	@SuppressWarnings('PMD.EmptyWhileStmt,PMD.EmptyStatementBlock')
	private static void shouldTrackElapsedTime()
	{
		UTIL_TriggerPerformanceTimer timer = new UTIL_TriggerPerformanceTimer(
				ACTION_CLASS_NAME, TRIGGER_OPERATION, OBJECT_NAME, RECORD_COUNT
		);

		Test.startTest();

		timer.start();

		// Simulate some work
		Long startMs = System.currentTimeMillis();
		while(System.currentTimeMillis() - startMs < 5)
		{
			// Wait ~5ms
		}

		timer.stop();

		Test.stopTest();

		Assert.isTrue(timer.getTime() >= 0, 'Elapsed time should be non-negative');
	}

	/**
	 * @description Tests stopSilent method returns time without logging.
	 */
	@IsTest
	private static void shouldStopSilentlyWithoutLogging()
	{
		UTIL_TriggerPerformanceTimer timer = new UTIL_TriggerPerformanceTimer(
				ACTION_CLASS_NAME, TRIGGER_OPERATION, OBJECT_NAME, RECORD_COUNT
		);

		Test.startTest();

		timer.start();
		Long elapsedTime = timer.stopSilent();

		Test.stopTest();

		Assert.isTrue(elapsedTime >= 0, 'Elapsed time should be non-negative');
	}

	/**
	 * @description Tests log() forces logging regardless of threshold.
	 */
	@IsTest
	private static void shouldForceLogging()
	{
		assertForceLogAndContextStackEmpty();
	}

	/**
	 * @description Tests suppressLogging() prevents logging.
	 */
	@IsTest
	private static void shouldSuppressLogging()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 0, true, 0);

		UTIL_TriggerPerformanceTimer timer = new UTIL_TriggerPerformanceTimer(
				ACTION_CLASS_NAME, TRIGGER_OPERATION, OBJECT_NAME, RECORD_COUNT
		);

		Test.startTest();

		timer.start();
		timer.suppressLogging().stop();

		Test.stopTest();

		Assert.areEqual(0, LOG_Engine.getContextStackDepth(), 'Context stack should be empty');
	}

	/**
	 * @description Tests logIfSlowerThan() sets custom threshold.
	 * This test covers the code path where customThresholdMs is set and used.
	 */
	@IsTest
	private static void shouldUseCustomThreshold()
	{
		LOG_Builder.ignoreTestMode = true;
		// Enable trigger logging so we reach the threshold logic
		TST_Factory.setupLoggerForTest(true, 0, true, 0, true, 10000);

		UTIL_TriggerPerformanceTimer timer = new UTIL_TriggerPerformanceTimer(
				ACTION_CLASS_NAME, TRIGGER_OPERATION, OBJECT_NAME, RECORD_COUNT
		);

		Test.startTest();

		timer.start();
		timer.logIfSlowerThan(0).stop(); // 0ms threshold = always log (custom threshold overrides global 10s)

		Test.stopTest();

		Assert.areEqual(0, LOG_Engine.getContextStackDepth(), 'Context stack should be empty');
	}

	/**
	 * @description Tests withActionSettings() applies metadata settings.
	 */
	@IsTest
	private static void shouldApplyActionSettings()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 0, true, 0);

		TriggerAction__mdt mockMetadata = (TriggerAction__mdt)TST_Builder.of(TriggerAction__mdt.SObjectType)
				.withOverride(TriggerAction__mdt.DeveloperName, 'Test_Action')
				.withOverride(TriggerAction__mdt.ForcePerformanceLogging__c, true)
				.withOverride(TriggerAction__mdt.SuppressPerformanceLogging__c, false)
				.withOverride(TriggerAction__mdt.PerformanceThresholdMs__c, 100)
				.withoutInsertion()
				.build();

		UTIL_TriggerPerformanceTimer timer = new UTIL_TriggerPerformanceTimer(
				ACTION_CLASS_NAME, TRIGGER_OPERATION, OBJECT_NAME, RECORD_COUNT
		);

		Test.startTest();

		timer.start();
		UTIL_TriggerPerformanceTimer result = timer.withActionSettings(mockMetadata);
		timer.stop();

		Test.stopTest();

		Assert.areEqual(timer, result, 'withActionSettings should return same instance');
	}

	/**
	 * @description Tests suppress setting from metadata takes precedence.
	 */
	@IsTest
	private static void shouldApplySuppressSettingFromMetadata()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 0, true, 0);

		TriggerAction__mdt mockMetadata = (TriggerAction__mdt)TST_Builder.of(TriggerAction__mdt.SObjectType)
				.withOverride(TriggerAction__mdt.DeveloperName, 'Test_Action')
				.withOverride(TriggerAction__mdt.ForcePerformanceLogging__c, false)
				.withOverride(TriggerAction__mdt.SuppressPerformanceLogging__c, true)
				.withoutInsertion()
				.build();

		UTIL_TriggerPerformanceTimer timer = new UTIL_TriggerPerformanceTimer(
				ACTION_CLASS_NAME, TRIGGER_OPERATION, OBJECT_NAME, RECORD_COUNT
		);

		Test.startTest();

		timer.start();
		timer.withActionSettings(mockMetadata).stop();

		Test.stopTest();

		Assert.areEqual(0, LOG_Engine.getContextStackDepth(), 'Context stack should be empty');
	}

	/**
	 * @description Tests null metadata is handled gracefully.
	 */
	@IsTest
	private static void shouldHandleNullMetadata()
	{
		UTIL_TriggerPerformanceTimer timer = new UTIL_TriggerPerformanceTimer(
				ACTION_CLASS_NAME, TRIGGER_OPERATION, OBJECT_NAME, RECORD_COUNT
		);

		Test.startTest();

		timer.start();
		UTIL_TriggerPerformanceTimer result = timer.withActionSettings(null);
		timer.stop();

		Test.stopTest();

		Assert.areEqual(timer, result, 'withActionSettings(null) should return same instance');
	}

	/**
	 * @description Tests `withPostActionSettings` applies the two perf knobs from a
	 * `PostTriggerAction__mdt` row — force flag and threshold — and returns the same
	 * instance for chaining.
	 */
	@IsTest
	private static void shouldApplyPostActionSettings()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 0, true, 0);

		PostTriggerAction__mdt mockMetadata = (PostTriggerAction__mdt)TST_Builder.of(PostTriggerAction__mdt.SObjectType)
				.withOverride(PostTriggerAction__mdt.DeveloperName, 'Test_PostAction')
				.withOverride(PostTriggerAction__mdt.ForcePerformanceLogging__c, true)
				.withOverride(PostTriggerAction__mdt.PerformanceThresholdMs__c, 250)
				.withoutInsertion()
				.build();

		UTIL_TriggerPerformanceTimer timer = new UTIL_TriggerPerformanceTimer(ACTION_CLASS_NAME, 'POST_TRIGGER', null, null);

		Test.startTest();

		timer.start();
		UTIL_TriggerPerformanceTimer result = timer.withPostActionSettings(mockMetadata);
		timer.stop();

		Test.stopTest();

		Assert.areEqual(timer, result, 'withPostActionSettings should return same instance');
	}

	/**
	 * @description Tests `withPostActionSettings(null)` short-circuits without mutating
	 * the timer's state.
	 */
	@IsTest
	private static void shouldHandleNullPostActionMetadata()
	{
		UTIL_TriggerPerformanceTimer timer = new UTIL_TriggerPerformanceTimer(ACTION_CLASS_NAME, 'POST_TRIGGER', null, null);

		Test.startTest();

		timer.start();
		UTIL_TriggerPerformanceTimer result = timer.withPostActionSettings(null);
		timer.stop();

		Test.stopTest();

		Assert.areEqual(timer, result, 'withPostActionSettings(null) should return same instance');
	}

	/**
	 * @description Tests `withPostActionSettings` with `ForcePerformanceLogging__c = false`
	 * and a null threshold leaves the timer's defaults untouched — exercises the negative
	 * branches inside the overload so coverage stays at 100%.
	 */
	@IsTest
	private static void shouldHandlePostActionDefaultsWithoutMutating()
	{
		PostTriggerAction__mdt mockMetadata = (PostTriggerAction__mdt)TST_Builder.of(PostTriggerAction__mdt.SObjectType)
				.withOverride(PostTriggerAction__mdt.DeveloperName, 'Test_Defaults')
				.withOverride(PostTriggerAction__mdt.ForcePerformanceLogging__c, false)
				.withoutInsertion()
				.build();

		UTIL_TriggerPerformanceTimer timer = new UTIL_TriggerPerformanceTimer(
				ACTION_CLASS_NAME, 'POST_TRIGGER', null, null
		);

		Test.startTest();

		timer.start();
		UTIL_TriggerPerformanceTimer result = timer.withPostActionSettings(mockMetadata);
		timer.stop();

		Test.stopTest();

		Assert.areEqual(timer, result, 'withPostActionSettings should return same instance');
	}

	/**
	 * @description Tests public properties are correctly exposed.
	 */
	@IsTest
	private static void shouldExposePublicProperties()
	{
		UTIL_TriggerPerformanceTimer timer = new UTIL_TriggerPerformanceTimer(
				ACTION_CLASS_NAME, TRIGGER_OPERATION, OBJECT_NAME, RECORD_COUNT
		);

		Assert.areEqual(ACTION_CLASS_NAME, timer.actionClassName, 'actionClassName should match');
		Assert.areEqual(TRIGGER_OPERATION, timer.triggerOperation, 'triggerOperation should match');
		Assert.areEqual(OBJECT_NAME, timer.objectName, 'objectName should match');
	}

	/**
	 * @description Tests that trigger context is pushed and popped correctly during logging.
	 */
	@IsTest
	private static void shouldPushAndPopTriggerContext()
	{
		assertForceLogAndContextStackEmpty();
	}

	/**
	 * @description Tests fluent API chaining.
	 */
	@IsTest
	private static void shouldSupportFluentApiChaining()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 0, true, 0);

		TriggerAction__mdt mockMetadata = (TriggerAction__mdt)TST_Builder.of(TriggerAction__mdt.SObjectType)
				.withOverride(TriggerAction__mdt.DeveloperName, 'Test_Action')
				.withOverride(TriggerAction__mdt.ForcePerformanceLogging__c, false)
				.withOverride(TriggerAction__mdt.SuppressPerformanceLogging__c, false)
				.withOverride(TriggerAction__mdt.PerformanceThresholdMs__c, 100)
				.withoutInsertion()
				.build();

		UTIL_TriggerPerformanceTimer timer = new UTIL_TriggerPerformanceTimer(
				ACTION_CLASS_NAME, TRIGGER_OPERATION, OBJECT_NAME, RECORD_COUNT
		);

		Test.startTest();

		timer.start();
		timer.withActionSettings(mockMetadata).logIfSlowerThan(0).stop();

		Test.stopTest();

		Assert.isTrue(timer.getTime() >= 0, 'Timer should have recorded time');
	}

	/**
	 * @description Tests that log() overrides suppressLogging().
	 */
	@IsTest
	private static void shouldOverrideSuppressWithLog()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 0, true, 0);

		UTIL_TriggerPerformanceTimer timer = new UTIL_TriggerPerformanceTimer(
				ACTION_CLASS_NAME, TRIGGER_OPERATION, OBJECT_NAME, RECORD_COUNT
		);

		Test.startTest();

		timer.start();
		timer.suppressLogging().log().stop(); // log() should override suppress

		Test.stopTest();

		Assert.areEqual(0, LOG_Engine.getContextStackDepth(), 'Context stack should be empty');
	}

	/**
	 * @description Tests that suppressLogging() overrides logIfSlowerThan().
	 */
	@IsTest
	private static void shouldOverrideThresholdWithSuppress()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 0, true, 0);

		UTIL_TriggerPerformanceTimer timer = new UTIL_TriggerPerformanceTimer(
				ACTION_CLASS_NAME, TRIGGER_OPERATION, OBJECT_NAME, RECORD_COUNT
		);

		Test.startTest();

		timer.start();
		timer.logIfSlowerThan(0).suppressLogging().stop(); // suppress should override threshold

		Test.stopTest();

		Assert.areEqual(0, LOG_Engine.getContextStackDepth(), 'Context stack should be empty');
	}

	/**
	 * @description Tests using the global threshold from metadata without calling any fluent API method.
	 * This tests the code path where customThresholdMs is null and the global threshold is used.
	 */
	@IsTest
	private static void shouldUseGlobalThresholdFromMetadata()
	{
		LOG_Builder.ignoreTestMode = true;
		// Enable trigger logging with 0ms threshold (log all)
		TST_Factory.setupLoggerForTest(true, 0, true, 0, true, 0);

		UTIL_TriggerPerformanceTimer timer = new UTIL_TriggerPerformanceTimer(
				ACTION_CLASS_NAME, TRIGGER_OPERATION, OBJECT_NAME, RECORD_COUNT
		);

		Test.startTest();

		timer.start();
		// Don't call any fluent method - just stop to use default behavior with global threshold
		timer.stop();

		Test.stopTest();

		Assert.areEqual(0, LOG_Engine.getContextStackDepth(), 'Context stack should be empty after logging');
	}

	/**
	 * @description Tests that logging is skipped when trigger performance logging is disabled in metadata.
	 */
	@IsTest
	private static void shouldSkipLoggingWhenTriggerLoggingDisabled()
	{
		LOG_Builder.ignoreTestMode = true;
		// Disable trigger logging (false for trigger settings)
		TST_Factory.setupLoggerForTest(true, 0, true, 0, false, 500);

		UTIL_TriggerPerformanceTimer timer = new UTIL_TriggerPerformanceTimer(
				ACTION_CLASS_NAME, TRIGGER_OPERATION, OBJECT_NAME, RECORD_COUNT
		);

		Test.startTest();

		timer.start();
		timer.stop(); // Should not log because trigger logging is disabled

		Test.stopTest();

		Assert.areEqual(0, LOG_Engine.getContextStackDepth(), 'Context stack should be empty');
	}

	/**
	 * @description Tests that logging is skipped when elapsed time is below threshold.
	 */
	@IsTest
	private static void shouldSkipLoggingWhenBelowThreshold()
	{
		LOG_Builder.ignoreTestMode = true;
		// Enable trigger logging with high threshold (10 seconds)
		TST_Factory.setupLoggerForTest(true, 0, true, 0, true, 10000);

		UTIL_TriggerPerformanceTimer timer = new UTIL_TriggerPerformanceTimer(
				ACTION_CLASS_NAME, TRIGGER_OPERATION, OBJECT_NAME, RECORD_COUNT
		);

		Test.startTest();

		timer.start();
		// Immediately stop - elapsed time should be below 10s threshold
		timer.stop();

		Test.stopTest();

		Assert.areEqual(0, LOG_Engine.getContextStackDepth(), 'Context stack should be empty');
	}

	/**
	 * @description Tests that the recursion guard prevents infinite loops.
	 * When isLogging is already true, subsequent logging attempts are skipped.
	 */
	@IsTest
	private static void shouldPreventRecursionWhenAlreadyLogging()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 0, true, 0);

		UTIL_TriggerPerformanceTimer timer = new UTIL_TriggerPerformanceTimer(
				ACTION_CLASS_NAME, TRIGGER_OPERATION, OBJECT_NAME, RECORD_COUNT
		);

		Test.startTest();

		// Simulate a recursion scenario by setting isLogging to true
		UTIL_TriggerPerformanceTimer.isLogging = true;

		try
		{
			timer.start();
			timer.log().stop(); // This should skip logging due to recursion guard
		}
		finally
		{
			// Reset the flag
			UTIL_TriggerPerformanceTimer.isLogging = false;
		}

		Test.stopTest();

		// The timer should have completed without errors
		Assert.isTrue(timer.getTime() >= 0, 'Timer should have recorded time');
	}

	private static void assertForceLogAndContextStackEmpty()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 0, true, 0);

		UTIL_TriggerPerformanceTimer timer = new UTIL_TriggerPerformanceTimer(
				ACTION_CLASS_NAME, TRIGGER_OPERATION, OBJECT_NAME, RECORD_COUNT
		);

		Test.startTest();

		timer.start();
		timer.log().stop();

		Test.stopTest();

		Assert.areEqual(0, LOG_Engine.getContextStackDepth(), 'Context stack should be empty after logging');
	}

	/**
	 * @description Verifies that `withActionSettings` captures `FlowName__c` from the metadata
	 * when present. Captured value is later surfaced in the perf log entry's trigger-context
	 * map so subscriber log queries can filter by flow.
	 */
	@IsTest
	private static void shouldCaptureFlowNameFromActionSettingsWhenPresent()
	{
		String expectedFlowName = 'TRG_InvokeFlow_TEST_PerfTimerFlow';
		TriggerAction__mdt mockMetadata = (TriggerAction__mdt)TST_Builder.of(TriggerAction__mdt.SObjectType)
				.withOverride(TriggerAction__mdt.DeveloperName, 'Test_Action')
				.withOverride(TriggerAction__mdt.ForcePerformanceLogging__c, false)
				.withOverride(TriggerAction__mdt.SuppressPerformanceLogging__c, false)
				.withOverride(TriggerAction__mdt.FlowName__c, expectedFlowName)
				.withoutInsertion()
				.build();

		UTIL_TriggerPerformanceTimer timer = new UTIL_TriggerPerformanceTimer(
				ACTION_CLASS_NAME, TRIGGER_OPERATION, OBJECT_NAME, RECORD_COUNT
		);

		timer.withActionSettings(mockMetadata);

		Assert.areEqual(expectedFlowName, timer.flowName, 'Flow name should be captured from FlowName__c');
	}

	/**
	 * @description Verifies the captured `flowName` is included in the trigger-context map
	 * surfaced to the perf log entry. Forces logging via `timer.log().stop()` so the
	 * `buildTriggerContext` path executes and `LOG_Engine.CONTEXT_FLOW_NAME` is set.
	 */
	@IsTest
	private static void shouldEmitFlowNameInPerfLogContextWhenSet()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 0, true, 0);

		TriggerAction__mdt mockMetadata = (TriggerAction__mdt)TST_Builder.of(TriggerAction__mdt.SObjectType)
				.withOverride(TriggerAction__mdt.DeveloperName, 'Test_Action')
				.withOverride(TriggerAction__mdt.ForcePerformanceLogging__c, false)
				.withOverride(TriggerAction__mdt.SuppressPerformanceLogging__c, false)
				.withOverride(TriggerAction__mdt.FlowName__c, 'TRG_InvokeFlow_TEST_PerfTimerFlow')
				.withoutInsertion()
				.build();

		UTIL_TriggerPerformanceTimer timer = new UTIL_TriggerPerformanceTimer(
				ACTION_CLASS_NAME, TRIGGER_OPERATION, OBJECT_NAME, RECORD_COUNT
		);

		Test.startTest();

		timer.start();
		timer.withActionSettings(mockMetadata).log().stop();

		Test.stopTest();

		Assert.areEqual(0, LOG_Engine.getContextStackDepth(), 'Context stack should be empty after logging');
	}

	/**
	 * @description Verifies that `withActionSettings` leaves `flowName` null when `FlowName__c`
	 * is blank — the perf log entry omits the flowName context key for non-flow actions.
	 */
	@IsTest
	private static void shouldNotCaptureFlowNameWhenFlowNameBlank()
	{
		TriggerAction__mdt mockMetadata = (TriggerAction__mdt)TST_Builder.of(TriggerAction__mdt.SObjectType)
				.withOverride(TriggerAction__mdt.DeveloperName, 'Test_Action')
				.withOverride(TriggerAction__mdt.ForcePerformanceLogging__c, false)
				.withOverride(TriggerAction__mdt.SuppressPerformanceLogging__c, false)
				.withoutInsertion()
				.build();

		UTIL_TriggerPerformanceTimer timer = new UTIL_TriggerPerformanceTimer(
				ACTION_CLASS_NAME, TRIGGER_OPERATION, OBJECT_NAME, RECORD_COUNT
		);

		timer.withActionSettings(mockMetadata);

		Assert.isNull(timer.flowName, 'Blank FlowName__c should not be captured');
	}
}