// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for `UTIL_MaskerPerformanceTimer` — the self-emitting timer that
 * wraps the data-masking framework's trigger invocation. Exercises each of the five gates
 * that stand between a timer `stop()` call and an actual log entry emission: emission cap,
 * re-entrance guard, settings enable flag, threshold check, and recursion guard.
 *
 * @see UTIL_MaskerPerformanceTimer
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date April 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class UTIL_MaskerPerformanceTimer_TEST
{
	/**
	 * @description The API name used for trigger-batch records under test.
	 */
	private static final String TEST_SOBJECT_NAME = SEL_Foobar.OBJECT_NAME;

	/**
	 * @description Canonical record count for aggregate-emission assertions.
	 */
	private static final Integer TEST_RECORD_COUNT = 5;

	/**
	 * @description Tests that a timer which stops after exceeding the configured threshold
	 * emits a single aggregate log entry when masker performance logging is enabled.
	 */
	@IsTest
	private static void shouldEmitLogWhenEnabledAndAboveThreshold()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(false, 0, false, 0, false, 500);
		LOG_Engine.logSettingOverride.EnableMaskerPerformanceLogging__c = true;
		LOG_Engine.logSettingOverride.MaskerPerformanceThresholdMs__c = 0;

		UTIL_MaskerPerformanceTimer.logCountThisTransaction = 0;

		UTIL_MaskerPerformanceTimer timer = new UTIL_MaskerPerformanceTimer(TEST_SOBJECT_NAME, TEST_RECORD_COUNT);
		timer.start();
		timer.stop();

		Assert.areEqual(1, UTIL_MaskerPerformanceTimer.logCountThisTransaction, 'Log should emit once when logging enabled and elapsed meets threshold');
	}

	/**
	 * @description Tests the default-off behaviour — when `EnableMaskerPerformanceLogging__c`
	 * is false, no log entry is emitted regardless of elapsed time. Guards subscribers
	 * against paying log volume by default.
	 */
	@IsTest
	private static void shouldNotEmitWhenDisabled()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(false, 0, false, 0, false, 500);
		LOG_Engine.logSettingOverride.EnableMaskerPerformanceLogging__c = false;
		LOG_Engine.logSettingOverride.MaskerPerformanceThresholdMs__c = 0;

		UTIL_MaskerPerformanceTimer.logCountThisTransaction = 0;

		UTIL_MaskerPerformanceTimer timer = new UTIL_MaskerPerformanceTimer(TEST_SOBJECT_NAME, TEST_RECORD_COUNT);
		timer.start();
		timer.stop();

		Assert.areEqual(0, UTIL_MaskerPerformanceTimer.logCountThisTransaction, 'No emission when EnableMaskerPerformanceLogging is false');
	}

	/**
	 * @description Tests the threshold gate — a timer whose elapsed duration is below the
	 * configured threshold does not emit. The threshold is the primary mechanism for keeping
	 * fast (common-case) masking invocations silent.
	 */
	@IsTest
	private static void shouldNotEmitBelowThreshold()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(false, 0, false, 0, false, 500);
		LOG_Engine.logSettingOverride.EnableMaskerPerformanceLogging__c = true;
		LOG_Engine.logSettingOverride.MaskerPerformanceThresholdMs__c = 999999;

		UTIL_MaskerPerformanceTimer.logCountThisTransaction = 0;

		UTIL_MaskerPerformanceTimer timer = new UTIL_MaskerPerformanceTimer(TEST_SOBJECT_NAME, TEST_RECORD_COUNT);
		timer.start();
		timer.stop();

		Assert.areEqual(0, UTIL_MaskerPerformanceTimer.logCountThisTransaction, 'No emission when elapsed is below the configured threshold');
	}

	/**
	 * @description Tests the re-entrance guard — a timer bound to `LogEntryEvent__e` must
	 * never emit because the emitted log would itself be a `LogEntryEvent__e`, which the
	 * framework masker would pass through, looping.
	 */
	@IsTest
	private static void shouldSkipEmissionOnLogEntryEventReentrance()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(false, 0, false, 0, false, 500);
		LOG_Engine.logSettingOverride.EnableMaskerPerformanceLogging__c = true;
		LOG_Engine.logSettingOverride.MaskerPerformanceThresholdMs__c = 0;

		UTIL_MaskerPerformanceTimer.logCountThisTransaction = 0;

		String logEntryEventName = UTIL_SObjectDescribe.getObjectNameFromType(LogEntryEvent__e.SObjectType);
		UTIL_MaskerPerformanceTimer timer = new UTIL_MaskerPerformanceTimer(logEntryEventName, TEST_RECORD_COUNT);
		timer.start();
		timer.stop();

		Assert.areEqual(0, UTIL_MaskerPerformanceTimer.logCountThisTransaction, 'No emission when masking LogEntryEvent__e — re-entrance guard');
	}

	/**
	 * @description Tests the per-transaction emission cap — once `MAX_LOGS_PER_TRANSACTION`
	 * entries have been emitted, subsequent timer `stop()` calls skip emission. Protects
	 * against runaway log volume from trigger-handler loops.
	 */
	@IsTest
	private static void shouldCapEmissionPerTransaction()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(false, 0, false, 0, false, 500);
		LOG_Engine.logSettingOverride.EnableMaskerPerformanceLogging__c = true;
		LOG_Engine.logSettingOverride.MaskerPerformanceThresholdMs__c = 0;

		UTIL_MaskerPerformanceTimer.logCountThisTransaction = UTIL_MaskerPerformanceTimer.MAX_LOGS_PER_TRANSACTION;

		UTIL_MaskerPerformanceTimer timer = new UTIL_MaskerPerformanceTimer(TEST_SOBJECT_NAME, TEST_RECORD_COUNT);
		timer.start();
		timer.stop();

		Assert.areEqual
				(
						UTIL_MaskerPerformanceTimer.MAX_LOGS_PER_TRANSACTION,
						UTIL_MaskerPerformanceTimer.logCountThisTransaction,
						'Counter must not increment past the per-transaction cap'
				);
	}

	/**
	 * @description Tests the recursion guard — a timer whose `emitIfApplicable` is entered
	 * while `isLogging` is true must return immediately without emitting. Mirrors the
	 * recursion guard on `UTIL_TriggerPerformanceTimer.isLogging`.
	 */
	@IsTest
	private static void shouldSkipEmissionWhenRecursionGuardEngaged()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(false, 0, false, 0, false, 500);
		LOG_Engine.logSettingOverride.EnableMaskerPerformanceLogging__c = true;
		LOG_Engine.logSettingOverride.MaskerPerformanceThresholdMs__c = 0;

		UTIL_MaskerPerformanceTimer.logCountThisTransaction = 0;
		UTIL_MaskerPerformanceTimer.isLogging = true;

		try
		{
			UTIL_MaskerPerformanceTimer timer = new UTIL_MaskerPerformanceTimer(TEST_SOBJECT_NAME, TEST_RECORD_COUNT);
			timer.start();
			timer.stop();

			Assert.areEqual(0, UTIL_MaskerPerformanceTimer.logCountThisTransaction, 'Recursion guard must suppress emission');
		}
		finally
		{
			UTIL_MaskerPerformanceTimer.isLogging = false;
		}
	}

	/**
	 * @description Tests that a zero-record batch (empty `triggerNew`) does not divide by
	 * zero when computing `avgMsPerRecord` — the timer's internal arithmetic falls back to
	 * `elapsedMs` when `recordCount` is zero.
	 */
	@IsTest
	private static void shouldNotDivideByZeroOnEmptyBatch()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(false, 0, false, 0, false, 500);
		LOG_Engine.logSettingOverride.EnableMaskerPerformanceLogging__c = true;
		LOG_Engine.logSettingOverride.MaskerPerformanceThresholdMs__c = 0;

		UTIL_MaskerPerformanceTimer.logCountThisTransaction = 0;

		UTIL_MaskerPerformanceTimer timer = new UTIL_MaskerPerformanceTimer(TEST_SOBJECT_NAME, 0);
		timer.start();
		timer.stop();

		Assert.areEqual(1, UTIL_MaskerPerformanceTimer.logCountThisTransaction, 'Zero-record batch should still emit without dividing by zero');
	}

	/**
	 * @description Tests the defensive catch block — if `emitPerformanceLog` throws (e.g., the
	 * platform event bus is saturated), the exception is swallowed so telemetry never breaks
	 * the masking pipeline. The per-transaction counter still increments so the cap is honoured
	 * even on emit failure.
	 */
	@IsTest
	private static void shouldSwallowExceptionsFromEmitPerformanceLog()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(false, 0, false, 0, false, 500);
		LOG_Engine.logSettingOverride.EnableMaskerPerformanceLogging__c = true;
		LOG_Engine.logSettingOverride.MaskerPerformanceThresholdMs__c = 0;

		UTIL_MaskerPerformanceTimer.logCountThisTransaction = 0;
		UTIL_MaskerPerformanceTimer.forceEmitFailureForTest = true;

		try
		{
			UTIL_MaskerPerformanceTimer timer = new UTIL_MaskerPerformanceTimer(TEST_SOBJECT_NAME, TEST_RECORD_COUNT);
			timer.start();
			timer.stop();

			Assert.areEqual(1, UTIL_MaskerPerformanceTimer.logCountThisTransaction, 'Counter must increment before emit so cap is honoured when emit throws');
			Assert.isFalse(UTIL_MaskerPerformanceTimer.isLogging, 'Recursion guard must reset in finally even when emit throws');
		}
		finally
		{
			UTIL_MaskerPerformanceTimer.forceEmitFailureForTest = false;
		}
	}
}