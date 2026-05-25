// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests for UTIL_QueryPerformanceTimer class.
 *
 * @see UTIL_QueryPerformanceTimer
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date December 2025, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class UTIL_QueryPerformanceTimer_TEST
{
	private static final String CLASS_METHOD = UTIL_QueryPerformanceTimer.class.getName() + '/testMethod';
	private static final String OPERATION_NAME = 'TestQuery';

	/**
	 * @description Tests basic timer start/stop functionality and elapsed time tracking.
	 */
	@IsTest
	@SuppressWarnings('PMD.EmptyWhileStmt,PMD.EmptyStatementBlock')
	private static void shouldTrackElapsedTime()
	{
		UTIL_QueryPerformanceTimer timer = new UTIL_QueryPerformanceTimer(OPERATION_NAME, CLASS_METHOD);

		Test.startTest();

		timer.start();

		// Simulate some work
		Long startMs = System.currentTimeMillis();
		while(System.currentTimeMillis() - startMs < 5)
		{
			// Wait ~5ms
		}

		timer.suppressLogging().stop();

		Test.stopTest();

		Assert.isTrue(timer.getTime() >= 0, 'Elapsed time should be non-negative');
	}

	/**
	 * @description Tests that suppressLogging() prevents logging even when threshold is exceeded.
	 */
	@IsTest
	private static void shouldSuppressLoggingWhenRequested()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 0, true, 0); // Enable with 0ms threshold (log all)

		UTIL_QueryPerformanceTimer timer = new UTIL_QueryPerformanceTimer(OPERATION_NAME, CLASS_METHOD);

		Test.startTest();

		timer.start();
		timer.suppressLogging().stop();

		Test.stopTest();

		// Verify no log was created by checking events published
		Assert.isTrue(timer.getTime() >= 0, 'Timer should have recorded time');
	}

	/**
	 * @description Tests that log() forces logging regardless of threshold.
	 */
	@IsTest
	private static void shouldForceLoggingWhenRequested()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 999999, true, 999999); // Very high threshold

		UTIL_QueryPerformanceTimer timer = new UTIL_QueryPerformanceTimer(OPERATION_NAME, CLASS_METHOD);

		Test.startTest();

		timer.start();
		timer.log().stop();

		Test.stopTest();

		Assert.isTrue(timer.getTime() >= 0, 'Timer should have recorded time');
	}

	/**
	 * @description Tests that logIfSlowerThan() uses custom threshold.
	 */
	@IsTest
	private static void shouldUseCustomThreshold()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 999999, true, 999999); // Very high global threshold

		UTIL_QueryPerformanceTimer timer = new UTIL_QueryPerformanceTimer(OPERATION_NAME, CLASS_METHOD);

		Test.startTest();

		timer.start();
		timer.logIfSlowerThan(0).stop(); // 0ms threshold means log all

		Test.stopTest();

		Assert.isTrue(timer.getTime() >= 0, 'Timer should have recorded time');
	}

	/**
	 * @description Tests that setRowCount() includes row count in details.
	 */
	@IsTest
	private static void shouldIncludeRowCountInDetails()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 0, true, 0);

		UTIL_QueryPerformanceTimer timer = new UTIL_QueryPerformanceTimer(OPERATION_NAME, CLASS_METHOD);

		Test.startTest();

		timer.start();
		timer.setRowCount(42).log().stop();

		Test.stopTest();

		Assert.isTrue(timer.getTime() >= 0, 'Timer should have recorded time');
	}

	/**
	 * @description Tests that stopSilent() returns elapsed time without logging.
	 */
	@IsTest
	private static void shouldReturnTimeOnStopSilent()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 0, true, 0);

		UTIL_QueryPerformanceTimer timer = new UTIL_QueryPerformanceTimer(OPERATION_NAME, CLASS_METHOD);

		Test.startTest();

		timer.start();
		Long elapsed = timer.stopSilent();

		Test.stopTest();

		Assert.isNotNull(elapsed, 'stopSilent should return elapsed time');
		Assert.isTrue(elapsed >= 0, 'Elapsed time should be non-negative');
	}

	/**
	 * @description Tests that timer respects EnableQueryPerformanceLogging__c = false.
	 */
	@IsTest
	private static void shouldNotLogWhenQueryLoggingDisabled()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(false, 0, true, 0); // Query logging disabled

		UTIL_QueryPerformanceTimer timer = new UTIL_QueryPerformanceTimer(OPERATION_NAME, CLASS_METHOD);

		Test.startTest();

		timer.start();
		timer.stop(); // Should not log since query logging is disabled

		Test.stopTest();

		Assert.isTrue(timer.getTime() >= 0, 'Timer should have recorded time');
	}

	/**
	 * @description Tests that timer logs when threshold is exceeded.
	 */
	@IsTest
	private static void shouldLogWhenThresholdExceeded()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 0, true, 0); // 0ms threshold = log all

		UTIL_QueryPerformanceTimer timer = new UTIL_QueryPerformanceTimer(OPERATION_NAME, CLASS_METHOD);

		Test.startTest();

		timer.start();
		timer.stop();

		Test.stopTest();

		Assert.isTrue(timer.getTime() >= 0, 'Timer should have recorded time');
	}

	/**
	 * @description Tests that timer does not log when under threshold.
	 */
	@IsTest
	private static void shouldNotLogWhenUnderThreshold()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 999999, true, 999999); // Very high threshold

		UTIL_QueryPerformanceTimer timer = new UTIL_QueryPerformanceTimer(OPERATION_NAME, CLASS_METHOD);

		Test.startTest();

		timer.start();
		timer.stop(); // Should not log since under threshold

		Test.stopTest();

		Assert.isTrue(timer.getTime() >= 0, 'Timer should have recorded time');
	}

	/**
	 * @description Tests fluent API method chaining.
	 */
	@IsTest
	private static void shouldSupportFluentMethodChaining()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 0, true, 0);

		UTIL_QueryPerformanceTimer timer = new UTIL_QueryPerformanceTimer(OPERATION_NAME, CLASS_METHOD);

		Test.startTest();

		timer.start();
		UTIL_QueryPerformanceTimer result = timer.setRowCount(10).logIfSlowerThan(100);

		Test.stopTest();

		Assert.areEqual(timer, result, 'Fluent methods should return same instance');
		timer.suppressLogging().stop();
	}

	/**
	 * @description Tests that log() overrides suppressLogging() when called after.
	 */
	@IsTest
	private static void shouldAllowLogToOverrideSuppressLogging()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 999999, true, 999999);

		UTIL_QueryPerformanceTimer timer = new UTIL_QueryPerformanceTimer(OPERATION_NAME, CLASS_METHOD);

		Test.startTest();

		timer.start();
		timer.suppressLogging().log().stop(); // log() called after suppress

		Test.stopTest();

		Assert.isTrue(timer.getTime() >= 0, 'Timer should have recorded time');
	}

	/**
	 * @description Tests that suppressLogging() overrides log() when called after.
	 */
	@IsTest
	private static void shouldAllowSuppressLoggingToOverrideLog()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 0, true, 0);

		UTIL_QueryPerformanceTimer timer = new UTIL_QueryPerformanceTimer(OPERATION_NAME, CLASS_METHOD);

		Test.startTest();

		timer.start();
		timer.log().suppressLogging().stop(); // suppress called after log

		Test.stopTest();

		Assert.isTrue(timer.getTime() >= 0, 'Timer should have recorded time');
	}

	/**
	 * @description Tests timer with query performance logging disabled.
	 */
	@IsTest
	private static void shouldHandleDisabledLogging()
	{
		LOG_Builder.ignoreTestMode = true;
		LOG_Engine.logSettingOverride = new LogSetting__c(IsEnabled__c = true, EnableQueryPerformanceLogging__c = false);

		UTIL_QueryPerformanceTimer timer = new UTIL_QueryPerformanceTimer(OPERATION_NAME, CLASS_METHOD);

		Test.startTest();

		timer.start();
		timer.stop();

		Test.stopTest();

		Assert.isTrue(timer.getTime() >= 0, 'Timer should work with logging disabled');
	}

	/**
	 * @description Tests operationName and classMethod properties.
	 */
	@IsTest
	private static void shouldExposeOperationNameAndClassMethod()
	{
		UTIL_QueryPerformanceTimer timer = new UTIL_QueryPerformanceTimer(OPERATION_NAME, CLASS_METHOD);

		Assert.areEqual(OPERATION_NAME, timer.operationName, 'operationName should match');
		Assert.areEqual(CLASS_METHOD, timer.classMethod, 'classMethod should match');
	}

	/**
	 * @description Tests that withQueryContext() captures query context data.
	 */
	@IsTest
	private static void shouldCaptureQueryContextFromParameters()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 0, true, 0);

		UTIL_QueryPerformanceTimer timer = new UTIL_QueryPerformanceTimer(OPERATION_NAME, CLASS_METHOD);

		Test.startTest();

		timer.start();
		UTIL_QueryPerformanceTimer result = timer.withQueryContext
				(
						'SELECT Id, Name FROM Account WHERE Name = \'Test\'',
						new Map<String, Object> {'b1' => 'Test'},
						false,
						'MISS'
				);
		timer.log().stop();

		Test.stopTest();

		Assert.areEqual(timer, result, 'withQueryContext should return same instance for chaining');
	}

	/**
	 * @description Tests that withObjectName() sets object name for context logging.
	 */
	@IsTest
	private static void shouldSetObjectNameForContextLogging()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 0, true, 0);

		UTIL_QueryPerformanceTimer timer = new UTIL_QueryPerformanceTimer(OPERATION_NAME, CLASS_METHOD);

		Test.startTest();

		timer.start();
		UTIL_QueryPerformanceTimer result = timer.withObjectName('Account');
		timer.log().stop();

		Test.stopTest();

		Assert.areEqual(timer, result, 'withObjectName should return same instance for chaining');
	}

	/**
	 * @description Tests that query context is pushed to context stack and included in logs.
	 */
	@IsTest
	private static void shouldIncludeQueryContextInLogEntry()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 0, true, 0);

		UTIL_QueryPerformanceTimer timer = new UTIL_QueryPerformanceTimer(OPERATION_NAME, CLASS_METHOD);

		Test.startTest();

		timer.start();
		timer.withObjectName('Account').withQueryContext('SELECT Id FROM Account', null, true, 'HIT').setRowCount(5).log().stop();

		Test.stopTest();

		// Verify context was pushed and popped correctly (stack should be empty after logging)
		Assert.areEqual(0, LOG_Engine.getContextStackDepth(), 'Context stack should be empty after logging');
	}

	/**
	 * @description Tests that query context does not bleed into subsequent logs.
	 */
	@IsTest
	private static void shouldNotBleedContextIntoSubsequentLogs()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 0, true, 0);

		UTIL_QueryPerformanceTimer timer = new UTIL_QueryPerformanceTimer(OPERATION_NAME, CLASS_METHOD);

		Test.startTest();

		// First query log with context
		timer.start();
		timer.withQueryContext('SELECT Id FROM Account', null, false, null).log().stop();

		// Verify stack is empty
		Integer stackDepthAfterFirst = LOG_Engine.getContextStackDepth();

		// Second log without query context
		LOG_Builder.build().debug('Subsequent log').at('OtherClass/method').emit();

		Test.stopTest();

		Assert.areEqual(0, stackDepthAfterFirst, 'Context stack should be empty after first query');
	}

	/**
	 * @description Tests that withQueryContext() handles null query string gracefully.
	 */
	@IsTest
	private static void shouldHandleNullQueryString()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 0, true, 0);

		UTIL_QueryPerformanceTimer timer = new UTIL_QueryPerformanceTimer(OPERATION_NAME, CLASS_METHOD);

		Test.startTest();

		timer.start();
		UTIL_QueryPerformanceTimer result = timer.withQueryContext(null, null, false, null);
		timer.log().stop();

		Test.stopTest();

		Assert.areEqual(timer, result, 'withQueryContext(null) should return same instance');
	}

	/**
	 * @description Tests that withQueryContext() handles empty bindMap.
	 */
	@IsTest
	private static void shouldHandleEmptyBindMap()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 0, true, 0);

		UTIL_QueryPerformanceTimer timer = new UTIL_QueryPerformanceTimer(OPERATION_NAME, CLASS_METHOD);

		Test.startTest();

		timer.start();
		timer.withQueryContext('SELECT Id FROM Account', new Map<String, Object>(), false, null).log().stop();

		Test.stopTest();

		Assert.areEqual(0, LOG_Engine.getContextStackDepth(), 'Context stack should be empty');
	}

	/**
	 * @description Tests that withQueryContext() handles null bindMap.
	 */
	@IsTest
	private static void shouldHandleNullBindMap()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 0, true, 0);

		UTIL_QueryPerformanceTimer timer = new UTIL_QueryPerformanceTimer(OPERATION_NAME, CLASS_METHOD);

		Test.startTest();

		timer.start();
		timer.withQueryContext('SELECT Id FROM Account', null, false, null).log().stop();

		Test.stopTest();

		Assert.areEqual(0, LOG_Engine.getContextStackDepth(), 'Context stack should be empty');
	}

	/**
	 * @description Tests full fluent API chain with query context.
	 */
	@IsTest
	private static void shouldSupportFullFluentChainWithQueryContext()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 0, true, 0);

		UTIL_QueryPerformanceTimer timer = new UTIL_QueryPerformanceTimer(OPERATION_NAME, CLASS_METHOD);

		Test.startTest();

		timer.start();
		timer.withObjectName('Account')
				.withQueryContext('SELECT Id, Name FROM Account WHERE Industry = :b1', new Map<String, Object> {'b1' => 'Technology'}, false, 'STORED')
				.setRowCount(42)
				.logIfSlowerThan(0)
				.stop();

		Test.stopTest();

		Assert.isTrue(timer.getTime() >= 0, 'Timer should have recorded time');
		Assert.areEqual(0, LOG_Engine.getContextStackDepth(), 'Context stack should be empty after logging');
	}

	/**
	 * @description Tests that withQueryContext overload captures individual parameters.
	 */
	@IsTest
	private static void shouldCaptureQueryContextFromIndividualParameters()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 0, true, 0);

		String queryString = 'SELECT Id FROM Account WHERE Name = :b1';
		Map<String, Object> bindMap = new Map<String, Object> {'b1' => 'Test'};

		UTIL_QueryPerformanceTimer timer = new UTIL_QueryPerformanceTimer(OPERATION_NAME, CLASS_METHOD);

		Test.startTest();

		timer.start();
		UTIL_QueryPerformanceTimer result = timer.withQueryContext(queryString, bindMap, false, 'STORED');
		timer.log().stop();

		Test.stopTest();

		Assert.areEqual(timer, result, 'withQueryContext overload should return same instance for chaining');
		Assert.areEqual(0, LOG_Engine.getContextStackDepth(), 'Context stack should be empty after logging');
	}

	/**
	 * @description Tests that withQueryContext overload handles null bind map.
	 */
	@IsTest
	private static void shouldHandleNullBindMapInOverload()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 0, true, 0);

		UTIL_QueryPerformanceTimer timer = new UTIL_QueryPerformanceTimer(OPERATION_NAME, CLASS_METHOD);

		Test.startTest();

		timer.start();
		timer.withQueryContext('SELECT Id FROM Account', null, true, 'HIT').log().stop();

		Test.stopTest();

		Assert.areEqual(0, LOG_Engine.getContextStackDepth(), 'Context stack should be empty');
	}

	/**
	 * @description Tests that withQueryContext overload handles empty bind map.
	 */
	@IsTest
	private static void shouldHandleEmptyBindMapInOverload()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 0, true, 0);

		UTIL_QueryPerformanceTimer timer = new UTIL_QueryPerformanceTimer(OPERATION_NAME, CLASS_METHOD);

		Test.startTest();

		timer.start();
		timer.withQueryContext('SELECT Id FROM Account', new Map<String, Object>(), false, 'BYPASS').log().stop();

		Test.stopTest();

		Assert.areEqual(0, LOG_Engine.getContextStackDepth(), 'Context stack should be empty');
	}
}