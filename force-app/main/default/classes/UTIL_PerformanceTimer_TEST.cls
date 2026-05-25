// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Validates UTIL_PerformanceTimer behaviour including threshold-based logging,
 * silent stop, property access, and backward compatibility with UTIL_StopWatch.
 *
 * @see UTIL_PerformanceTimer
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class UTIL_PerformanceTimer_TEST
{
	/**
	 * @description Operation label reused across tests.
	 */
	private static final String SAMPLE_OPERATION = 'BulkSync';
	/**
	 * @description Class-method value reused across tests.
	 */
	private static final String SAMPLE_LOCATION = 'UTIL_PerformanceTimer_TEST/run';

	/**
	 * @description Verifies the timer is assignable to its UTIL_StopWatch parent.
	 */
	@IsTest
	private static void shouldBeAssignableToStopWatch()
	{
		UTIL_PerformanceTimer timer = new UTIL_PerformanceTimer(SAMPLE_OPERATION, SAMPLE_LOCATION);

		UTIL_StopWatch base = timer;
		Assert.isNotNull(base, 'Should be type-compatible with UTIL_StopWatch');

		Assert.areEqual(0, timer.getTime(), 'Elapsed should be zero before start');
		timer.start();
		timer.stop();
		Assert.isTrue(timer.getTime() >= 0, 'Elapsed should be non-negative after stop');
	}

	/**
	 * @description Verifies a log entry is emitted when the threshold is zero (always log).
	 */
	@IsTest
	private static void shouldLogWhenThresholdIsZero()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 0);

		Test.startTest();
		UTIL_PerformanceTimer timer = new UTIL_PerformanceTimer(SAMPLE_OPERATION, SAMPLE_LOCATION);
		timer.start();
		timer.stop();
		Test.stopTest();

		List<LogEntry__c> entries = new SEL_LogEntry().findAllByMethod(SAMPLE_LOCATION);
		Assert.isFalse(entries.isEmpty(), 'Log entry should be written when threshold is zero');

		Boolean found = false;
		for(LogEntry__c entry : entries)
		{
			if(entry.ShortMessage__c != null && entry.ShortMessage__c.contains(SAMPLE_OPERATION + ' completed in'))
			{
				found = true;
				Assert.isNotNull(entry.DurationMs__c, 'Duration field should be populated');
				break;
			}
		}
		Assert.isTrue(found, 'Should contain the expected performance message');
	}

	/**
	 * @description Verifies nothing is logged when performance logging is disabled.
	 */
	@IsTest
	private static void shouldNotLogWhenDisabled()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(false, 0);

		Test.startTest();
		UTIL_PerformanceTimer timer = new UTIL_PerformanceTimer(SAMPLE_OPERATION, 'UTIL_PerformanceTimer_TEST/disabled');
		timer.start();
		timer.stop();
		Test.stopTest();

		List<LogEntry__c> entries = new SEL_LogEntry().findAllByMethod('UTIL_PerformanceTimer_TEST/disabled');
		Assert.isTrue(entries.isEmpty(), 'No entry should be written when logging is disabled');
	}

	/**
	 * @description Verifies nothing is logged when the threshold exceeds the actual duration.
	 */
	@IsTest
	private static void shouldNotLogWhenUnderThreshold()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 10000);

		Test.startTest();
		UTIL_PerformanceTimer timer = new UTIL_PerformanceTimer(SAMPLE_OPERATION, 'UTIL_PerformanceTimer_TEST/high');
		timer.start();
		timer.stop();
		Test.stopTest();

		List<LogEntry__c> entries = new SEL_LogEntry().findAllByMethod('UTIL_PerformanceTimer_TEST/high');
		Assert.isTrue(entries.isEmpty(), 'No entry should be written when under threshold');
	}

	/**
	 * @description Verifies stopSilent returns elapsed time without emitting a log.
	 */
	@IsTest
	private static void shouldReturnElapsedWithoutLogging()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 0);

		Test.startTest();
		UTIL_PerformanceTimer timer = new UTIL_PerformanceTimer(SAMPLE_OPERATION, 'UTIL_PerformanceTimer_TEST/silent');
		timer.start();
		Long elapsed = timer.stopSilent();
		Test.stopTest();

		Assert.isTrue(elapsed >= 0, 'Elapsed should be non-negative');
		List<LogEntry__c> entries = new SEL_LogEntry().findAllByMethod('UTIL_PerformanceTimer_TEST/silent');
		Assert.isTrue(entries.isEmpty(), 'Silent stop should not produce a log entry');
	}

	/**
	 * @description Verifies operationName returns the constructor value.
	 */
	@IsTest
	private static void shouldExposeOperationName()
	{
		UTIL_PerformanceTimer timer = new UTIL_PerformanceTimer(SAMPLE_OPERATION, SAMPLE_LOCATION);
		Assert.areEqual(SAMPLE_OPERATION, timer.operationName, 'operationName should match constructor value');
	}

	/**
	 * @description Verifies classMethod returns the constructor value.
	 */
	@IsTest
	private static void shouldExposeClassMethod()
	{
		UTIL_PerformanceTimer timer = new UTIL_PerformanceTimer(SAMPLE_OPERATION, SAMPLE_LOCATION);
		Assert.areEqual(SAMPLE_LOCATION, timer.classMethod, 'classMethod should match constructor value');
	}

	/**
	 * @description Verifies the detail line contains CPU and Heap metrics.
	 */
	@IsTest
	private static void shouldIncludeLimitDetailsInLog()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 0);

		Test.startTest();
		UTIL_PerformanceTimer timer = new UTIL_PerformanceTimer('DetailCheck', 'UTIL_PerformanceTimer_TEST/details');
		timer.start();
		List<String> work = new List<String>();
		for(Integer i = 0; i < 100; i++)
		{
			work.add('entry ' + i);
		}
		timer.stop();
		Test.stopTest();

		List<LogEntry__c> entries = new SEL_LogEntry().findAllByMethod('UTIL_PerformanceTimer_TEST/details');
		Assert.isFalse(entries.isEmpty(), 'Log entry should be written');

		Boolean hasDetails = false;
		for(LogEntry__c entry : entries)
		{
			if(entry.Message__c != null && entry.Message__c.contains('CPU:') && entry.Message__c.contains('Heap:'))
			{
				hasDetails = true;
				break;
			}
		}
		Assert.isTrue(hasDetails, 'Detail line should contain CPU and Heap metrics');
	}

	/**
	 * @description Verifies getTime, reset and re-start work through the parent class.
	 */
	@IsTest
	private static void shouldSupportResetAndRestart()
	{
		UTIL_PerformanceTimer timer = new UTIL_PerformanceTimer(SAMPLE_OPERATION, SAMPLE_LOCATION);
		Assert.areEqual(0, timer.getTime(), 'Should be zero initially');

		timer.start();
		timer.stop();
		Long first = timer.getTime();
		Assert.isTrue(first >= 0, 'Should have a non-negative elapsed value');
		Assert.areEqual(first, timer.getTime(), 'Repeated calls should return the same value');

		timer.reset();
		Assert.areEqual(0, timer.getTime(), 'Should be zero after reset');
	}
}