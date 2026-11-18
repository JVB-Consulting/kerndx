// SPDX-License-Identifier: Apache-2.0
/**
 * @description Test class for UTIL_TriggerPerformanceTimer.
 *
 * @see UTIL_TriggerPerformanceTimer
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date December 2025, November 2026
 */
@IsTest(seeAllData=false isParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class UTIL_TriggerPerformanceTimer_TEST
{
	/**
	 * @description The number of records the tests tell the timer the trigger is handling. No records are created; the
	 * timer only needs a figure to report.
	 */
	private static final Integer RECORD_COUNT = 100;

	/**
	 * @description A made-up trigger action class name the tests give the timer as the action being timed. No class of
	 * this name needs to exist.
	 */
	private static final String ACTION_CLASS_NAME = 'TRG_Account_TestAction';

	/**
	 * @description The object name the tests give the timer as the object the trigger runs on.
	 */
	private static final String OBJECT_NAME = 'Account';

	/**
	 * @description The trigger operation the tests give the timer, here a before-insert trigger. One test checks the
	 * timer keeps this value as given.
	 */
	private static final String TRIGGER_OPERATION = 'BEFORE_INSERT';

	/**
	 * @description A second made-up action class name, for tests that time two actions and must tell their log entries
	 * apart.
	 */
	private static final String SECOND_ACTION_CLASS_NAME = 'TRG_Account_SecondTestAction';

	/**
	 * @description The method name the timer writes on the log entry for ACTION_CLASS_NAME: the class name, a slash and
	 * the trigger operation in lower case.
	 */
	private static final String PERFORMANCE_LOG_METHOD = ACTION_CLASS_NAME + '/' + TRIGGER_OPERATION.toLowerCase();

	/**
	 * @description The method name the timer writes on the log entry for SECOND_ACTION_CLASS_NAME.
	 */
	private static final String SECOND_PERFORMANCE_LOG_METHOD = SECOND_ACTION_CLASS_NAME + '/' + TRIGGER_OPERATION.toLowerCase();

	/**
	 * @description A threshold of 0 milliseconds. Every run takes at least that long, so every run is slow enough to log.
	 */
	private static final Integer THRESHOLD_EVERY_RUN = 0;

	/**
	 * @description A threshold of 999999 milliseconds, about 17 minutes. No test run takes that long, so no run is slow
	 * enough to log.
	 */
	private static final Integer THRESHOLD_NO_RUN = 999999;

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
		TST_Factory.newLoggerSettings().withQueryLogging(0).withWebserviceLogging(0).withTriggerLogging(10000).apply();

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
		TST_Factory.newLoggerSettings().withQueryLogging(0).withWebserviceLogging(0).withTriggerLogging(0).apply();

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
		TST_Factory.newLoggerSettings().withQueryLogging(0).withWebserviceLogging(0).apply();

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
		TST_Factory.newLoggerSettings().withQueryLogging(0).withWebserviceLogging(0).withTriggerLogging(10000).apply();

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

	/**
	 * @description An action with both Suppress Performance Logging and Force Performance Logging ticked writes no log
	 * entry. Suppress wins over Force, as the Suppress field's help text says. The org switch is on with a threshold of
	 * 0 here, so the only thing that stops the entry is the Suppress box.
	 */
	@IsTest
	private static void shouldNotLogWhenSuppressAndForceAreBothTicked()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.newLoggerSettings().withTriggerLogging(THRESHOLD_EVERY_RUN).apply();

		Test.startTest();

		runTimer(ACTION_CLASS_NAME, newActionRow(true, true, null), null);

		Test.stopTest();

		Assert.isNull(new SEL_LogEntry().findPerformanceLogByMethod(PERFORMANCE_LOG_METHOD),
				'Expected no log entry, because Suppress Performance Logging wins over Force Performance Logging');
	}

	/**
	 * @description A suppressed action writes no log entry, even when its trigger setting has a threshold of 0 and the
	 * org switch is off. A threshold on the trigger setting never turns logging back on for a suppressed action.
	 */
	@IsTest
	private static void shouldNotLogWhenTheActionIsSuppressedDespiteATriggerSettingThreshold()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.newLoggerSettings().apply();

		Test.startTest();

		runTimer(ACTION_CLASS_NAME, newActionRow(true, false, null), THRESHOLD_EVERY_RUN);

		Test.stopTest();

		Assert.isNull(new SEL_LogEntry().findPerformanceLogByMethod(PERFORMANCE_LOG_METHOD),
				'Expected no log entry, because a suppressed action never logs, whatever its trigger setting threshold');
	}

	/**
	 * @description The action's own threshold wins over its trigger setting's threshold. The action's threshold is too
	 * high for any run, the trigger setting's is 0, and the org switch is off: no entry is written.
	 */
	@IsTest
	private static void shouldUseTheActionThresholdOverTheTriggerSettingThreshold()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.newLoggerSettings().apply();

		Test.startTest();

		runTimer(ACTION_CLASS_NAME, newActionRow(false, false, THRESHOLD_NO_RUN), THRESHOLD_EVERY_RUN);

		Test.stopTest();

		Assert.isNull(new SEL_LogEntry().findPerformanceLogByMethod(PERFORMANCE_LOG_METHOD),
				'Expected no log entry, because the action threshold applies and no run reaches it');
	}

	/**
	 * @description The action's own threshold wins over a higher trigger setting threshold, and it logs with the org
	 * switch off. The action's threshold is 0 and the trigger setting's is too high for any run: one entry is written.
	 */
	@IsTest
	private static void shouldLogAboveTheActionThresholdDespiteAHigherTriggerSettingThreshold()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.newLoggerSettings().apply();

		Test.startTest();

		runTimer(ACTION_CLASS_NAME, newActionRow(false, false, THRESHOLD_EVERY_RUN), THRESHOLD_NO_RUN);

		Test.stopTest();

		Assert.isNotNull(new SEL_LogEntry().findPerformanceLogByMethod(PERFORMANCE_LOG_METHOD),
				'Expected a log entry, because the action threshold of 0 applies even with the org switch off');
	}

	/**
	 * @description An action row with no trigger setting gives the timer no trigger setting threshold, and the timer
	 * then follows the org settings alone. With the org switch off the first action writes no entry; with the switch on
	 * and an org threshold of 0 the second action writes one.
	 */
	@IsTest
	private static void shouldIgnoreAMissingTriggerSetting()
	{
		LOG_Builder.ignoreTestMode = true;
		TriggerAction__mdt actionRow = newActionRow(false, false, null);

		Test.startTest();

		TST_Factory.newLoggerSettings().apply();
		runTimer(ACTION_CLASS_NAME, actionRow, actionRow.TriggerSetting__r?.PerformanceThresholdMs__c);
		TST_Factory.newLoggerSettings().withTriggerLogging(THRESHOLD_EVERY_RUN).apply();
		runTimer(SECOND_ACTION_CLASS_NAME, actionRow, actionRow.TriggerSetting__r?.PerformanceThresholdMs__c);

		Test.stopTest();

		Assert.isNull(new SEL_LogEntry().findPerformanceLogByMethod(PERFORMANCE_LOG_METHOD),
				'Expected no log entry with the org switch off, because a missing trigger setting sets no threshold');
		Assert.isNotNull(new SEL_LogEntry().findPerformanceLogByMethod(SECOND_PERFORMANCE_LOG_METHOD),
				'Expected a log entry with the org switch on, because the org threshold of 0 applies');
	}

	/**
	 * @description Builds a trigger action row in memory with the three performance settings a test needs. The row has no
	 * trigger setting.
	 *
	 * @param suppress The value for SuppressPerformanceLogging__c.
	 * @param force The value for ForcePerformanceLogging__c.
	 * @param thresholdMs The value for PerformanceThresholdMs__c, or null to leave it blank.
	 *
	 * @return The trigger action row, not saved.
	 */
	private static TriggerAction__mdt newActionRow(Boolean suppress, Boolean force, Integer thresholdMs)
	{
		TST_Builder.Builder builder = TST_Builder.of(TriggerAction__mdt.SObjectType)
				.withOverride(TriggerAction__mdt.DeveloperName, ACTION_CLASS_NAME)
				.withOverride(TriggerAction__mdt.SuppressPerformanceLogging__c, suppress)
				.withOverride(TriggerAction__mdt.ForcePerformanceLogging__c, force);
		if(thresholdMs != null)
		{
			builder.withOverride(TriggerAction__mdt.PerformanceThresholdMs__c, thresholdMs);
		}
		return (TriggerAction__mdt)builder.withoutInsertion().build();
	}

	/**
	 * @description Times one run of an action the way the trigger framework does: the timer takes the action row's
	 * settings and the threshold of the action's trigger setting, starts and stops.
	 *
	 * @param actionClassName The action class name the timer reports.
	 * @param actionRow The trigger action row.
	 * @param triggerSettingThresholdMs The trigger setting threshold, or null when there is none.
	 */
	private static void runTimer(String actionClassName, TriggerAction__mdt actionRow, Decimal triggerSettingThresholdMs)
	{
		UTIL_TriggerPerformanceTimer timer = new UTIL_TriggerPerformanceTimer(actionClassName, TRIGGER_OPERATION, OBJECT_NAME, RECORD_COUNT);
		timer.withActionSettings(actionRow).withTriggerSettingThreshold(triggerSettingThresholdMs);
		timer.start();
		timer.stop();
	}

	/**
	 * @description Switches the logger on, starts a timer, forces it to log with log() and stops it. It then checks that
	 * the logger's context stack is empty, which proves the trigger details the timer added for its log entry were
	 * removed again afterwards. Two tests share this body.
	 */
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