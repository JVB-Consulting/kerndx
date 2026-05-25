// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Validates the timing, state transitions, and error handling of the stopwatch utility.
 *
 * @see UTIL_StopWatch
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class UTIL_StopWatch_TEST
{
	/**
	 * @description Upper bound in milliseconds for assertions that verify near-instant operations.
	 */
	private static final Long MAX_EXPECTED_DURATION = 2000;

	/**
	 * @description Verifies the core lifecycle: start, stop, consistent reads, and reset to zero.
	 *
	 * @see UTIL_StopWatch.start
	 * @see UTIL_StopWatch.stop
	 * @see UTIL_StopWatch.reset
	 * @see UTIL_StopWatch.getTime
	 */
	@IsTest
	private static void shouldReturnConsistentTimeAfterStopAndZeroAfterReset()
	{
		UTIL_StopWatch timer = new UTIL_StopWatch();
		timer.start();
		timer.stop();
		Long captured = timer.getTime();

		Assert.areEqual(captured, timer.getTime(), 'Elapsed time must remain stable once stopped');
		timer.reset();
		Assert.areEqual(0, timer.getTime(), 'Elapsed time must be zero after resetting');
	}

	/**
	 * @description Confirms an idle timer reports zero and a freshly started timer reports a small positive value.
	 *
	 * @see UTIL_StopWatch.getTime
	 * @see UTIL_StopWatch.start
	 */
	@IsTest
	private static void shouldReturnZeroBeforeStartAndSmallValueWhileRunning()
	{
		UTIL_StopWatch timer = new UTIL_StopWatch();
		Assert.areEqual(0, timer.getTime(), 'Idle timer must report zero elapsed time');
		timer.start();
		Assert.isTrue(timer.getTime() < MAX_EXPECTED_DURATION, 'Running timer must report a small elapsed value immediately after start');
	}

	/**
	 * @description Validates that stop is rejected when the timer has never been started.
	 *
	 * @see UTIL_StopWatch.stop
	 */
	@IsTest
	private static void shouldRejectStopOnIdleTimer()
	{
		UTIL_StopWatch timer = new UTIL_StopWatch();
		try
		{
			timer.stop();
			Assert.fail('stop on idle timer must throw');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, UTIL_Exceptions.IllegalStateException.class, 'stop must raise IllegalStateException');
		}
	}

	/**
	 * @description Validates that calling start a second time on an active timer is rejected.
	 *
	 * @see UTIL_StopWatch.start
	 */
	@IsTest
	private static void shouldRejectDuplicateStart()
	{
		UTIL_StopWatch timer = new UTIL_StopWatch();
		timer.start();
		try
		{
			timer.start();
			Assert.fail('duplicate start must throw');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, UTIL_Exceptions.IllegalStateException.class, 'duplicate start must raise IllegalStateException');
		}
	}

	/**
	 * @description Validates that starting a finished timer without a reset is rejected.
	 *
	 * @see UTIL_StopWatch.start
	 * @see UTIL_StopWatch.stop
	 */
	@IsTest
	private static void shouldRejectStartOnFinishedTimer()
	{
		UTIL_StopWatch timer = new UTIL_StopWatch();
		timer.start();
		timer.stop();
		try
		{
			timer.start();
			Assert.fail('start on finished timer must throw without prior reset');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, UTIL_Exceptions.IllegalStateException.class, 'start must raise IllegalStateException');
		}
	}
}