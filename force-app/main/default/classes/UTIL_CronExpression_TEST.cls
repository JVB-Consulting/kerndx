// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for UTIL_CronExpression timezone shifting utility.
 *
 * @see UTIL_CronExpression
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date March 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class UTIL_CronExpression_TEST
{
	/**
	 * @description South Africa Standard Time (UTC+2, no DST).
	 */
	private static final String TIMEZONE_SAST = 'Africa/Johannesburg';

	/**
	 * @description Greenwich Mean Time (UTC+0, no DST).
	 */
	private static final String TIMEZONE_GMT = 'GMT';

	/**
	 * @description Coordinated Universal Time (UTC+0, no DST). Same offset as GMT, different ID.
	 */
	private static final String TIMEZONE_UTC = 'UTC';

	/**
	 * @description Australian Eastern Standard Time (UTC+10, no DST).
	 */
	private static final String TIMEZONE_AEST = 'Australia/Brisbane';

	/**
	 * @description India Standard Time (UTC+5:30, no DST).
	 */
	private static final String TIMEZONE_IST = 'Asia/Kolkata';

	/**
	 * @description America/New_York timezone — observes Daylight Saving Time. Used to exercise
	 * the reference-datetime overload across a DST cross-over.
	 */
	private static final String TIMEZONE_NYC = 'America/New_York';

	@IsTest
	private static void shouldShiftHoursForward()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 14 * * ?', TIMEZONE_SAST, TIMEZONE_GMT);

		Assert.areEqual('0 0 12 * * ?', result, 'SAST 14:00 should shift to UTC 12:00');
	}

	/**
	 * @description Verifies the reference-datetime overload uses the offset that applies at the
	 * supplied moment, not at `Datetime.now()`. America/New_York is UTC-4 during DST (EDT) and
	 * UTC-5 in winter (EST). Using a mid-summer reference forces the offset calculation to use
	 * EDT regardless of when the test actually runs, so the assertion is stable year-round.
	 */
	@IsTest
	private static void shouldRespectReferenceDatetimeForDstSensitiveTimezone()
	{
		Datetime midSummerInstant = Datetime.newInstanceGmt(2026, 7, 15, 12, 0, 0);

		String result = UTIL_CronExpression.shiftTimezone('0 0 14 * * ?', TIMEZONE_NYC, TIMEZONE_GMT, midSummerInstant);

		Assert.areEqual('0 0 18 * * ?', result, 'NYC 14:00 EDT (UTC-4) should shift to GMT 18:00 when reference falls inside DST');
	}

	/**
	 * @description Verifies the reference-datetime overload picks up the winter (EST, UTC-5)
	 * offset for the same NYC cron when the reference falls outside DST.
	 */
	@IsTest
	private static void shouldRespectReferenceDatetimeOutsideDst()
	{
		Datetime midWinterInstant = Datetime.newInstanceGmt(2026, 1, 15, 12, 0, 0);

		String result = UTIL_CronExpression.shiftTimezone('0 0 14 * * ?', TIMEZONE_NYC, TIMEZONE_GMT, midWinterInstant);

		Assert.areEqual('0 0 19 * * ?', result, 'NYC 14:00 EST (UTC-5) should shift to GMT 19:00 when reference falls outside DST');
	}

	@IsTest
	private static void shouldShiftHoursBackward()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 12 * * ?', TIMEZONE_GMT, TIMEZONE_SAST);

		Assert.areEqual('0 0 14 * * ?', result, 'UTC 12:00 should shift to SAST 14:00');
	}

	@IsTest
	private static void shouldWrapHoursAcrossMidnight()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 2 * * ?', TIMEZONE_AEST, TIMEZONE_GMT);

		Assert.areEqual('0 0 16 * * ?', result, 'AEST 02:00 should shift to UTC 16:00 (previous day, but day is wildcard)');
	}

	@IsTest
	private static void shouldShiftDayOfWeekOnRollover()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 1 ? * MON', TIMEZONE_AEST, TIMEZONE_GMT);

		Assert.areEqual('0 0 15 ? * SUN', result, 'AEST Monday 01:00 should shift to UTC Sunday 15:00');
	}

	@IsTest
	private static void shouldNotShiftWildcardHours()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 * * * ?', TIMEZONE_SAST, TIMEZONE_GMT);

		Assert.areEqual('0 0 * * * ?', result, 'Wildcard hours should pass through unshifted');
	}

	@IsTest
	private static void shouldNotShiftStepHours()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 */2 * * ?', TIMEZONE_SAST, TIMEZONE_GMT);

		Assert.areEqual('0 0 */2 * * ?', result, 'Step hours should pass through unshifted');
	}

	@IsTest
	private static void shouldShiftCommaListHours()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 8,12,17 * * ?', TIMEZONE_SAST, TIMEZONE_GMT);

		Assert.areEqual('0 0 6,10,15 * * ?', result, 'Comma list hours should each be shifted by -2');
	}

	@IsTest
	private static void shouldShiftHourRange()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 9-17 * * ?', TIMEZONE_SAST, TIMEZONE_GMT);

		Assert.areEqual('0 0 7-15 * * ?', result, 'Hour range should shift both endpoints by -2');
	}

	@IsTest
	private static void shouldReturnUnchangedWhenSameTimezone()
	{
		String cron = '0 0 12 * * ?';

		String result = UTIL_CronExpression.shiftTimezone(cron, TIMEZONE_SAST, TIMEZONE_SAST);

		Assert.areEqual(cron, result, 'Same timezone should return unchanged cron');
	}

	@IsTest
	private static void shouldReturnUnchangedWhenSourceTimezoneNull()
	{
		String cron = '0 0 12 * * ?';

		String result = UTIL_CronExpression.shiftTimezone(cron, null, TIMEZONE_GMT);

		Assert.areEqual(cron, result, 'Null source timezone should return unchanged cron');
	}

	@IsTest
	private static void shouldHandleHalfHourTimezoneOffset()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 14 * * ?', TIMEZONE_IST, TIMEZONE_GMT);

		Assert.areEqual('0 30 8 * * ?', result, 'IST 14:00 should shift to UTC 08:30');
	}

	@IsTest
	private static void shouldReturnDisplayName()
	{
		String result = UTIL_CronExpression.getDisplayName(TIMEZONE_SAST);

		Assert.isTrue(String.isNotBlank(result), 'Display name should not be blank');
	}

	@IsTest
	private static void shouldReturnEmptyDisplayNameWhenBlank()
	{
		String result = UTIL_CronExpression.getDisplayName('');

		Assert.areEqual('', result, 'Blank timezone should return empty display name');
	}

	@IsTest
	private static void shouldHandleDayOfMonthRollover()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 1 15 * ?', TIMEZONE_AEST, TIMEZONE_GMT);

		Assert.areEqual('0 0 15 14 * ?', result, 'AEST 01:00 on 15th should shift to UTC 15:00 on 14th');
	}

	@IsTest
	private static void shouldNotShiftDayOfMonthWithLastDaySuffix()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 1 L * ?', TIMEZONE_AEST, TIMEZONE_GMT);

		Assert.areEqual('0 0 15 L * ?', result, 'L suffix day-of-month should remain unchanged despite day rollover');
	}

	@IsTest
	private static void shouldShiftDayOfWeekHashPattern()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 1 ? * MON#2', TIMEZONE_AEST, TIMEZONE_GMT);

		Assert.areEqual('0 0 15 ? * SUN#2', result, 'Hash pattern should shift day name while preserving occurrence number');
	}

	@IsTest
	private static void shouldShiftDayOfWeekLastSuffix()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 1 ? * FRIL', TIMEZONE_AEST, TIMEZONE_GMT);

		Assert.areEqual('0 0 15 ? * THUL', result, 'L suffix should shift day name while preserving L');
	}

	@IsTest
	private static void shouldConvertWrappingRangeToCommaList()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 20-23 * * ?', TIMEZONE_GMT, TIMEZONE_AEST);

		Assert.areEqual('0 0 6-9 * * ?', result, 'Range shifted entirely into next day should remain a valid range');
	}

	@IsTest
	private static void shouldShiftDayOfWeekCommaList()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 1 ? * MON,WED,FRI', TIMEZONE_AEST, TIMEZONE_GMT);

		Assert.areEqual('0 0 15 ? * SUN,TUE,THU', result, 'Day-of-week comma list should shift each day');
	}

	@IsTest
	private static void shouldShiftDayOfWeekRange()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 1 ? * MON-FRI', TIMEZONE_AEST, TIMEZONE_GMT);

		Assert.areEqual('0 0 15 ? * SUN-THU', result, 'Day-of-week range should shift both endpoints');
	}

	@IsTest
	private static void shouldShiftDayOfMonthCommaList()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 1 5,15 * ?', TIMEZONE_AEST, TIMEZONE_GMT);

		Assert.areEqual('0 0 15 4,14 * ?', result, 'Day-of-month comma list should shift each value');
	}

	@IsTest
	private static void shouldShiftNumericDayOfWeek()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 1 ? * 2', TIMEZONE_AEST, TIMEZONE_GMT);

		Assert.areEqual('0 0 15 ? * 1', result, 'Numeric day-of-week 2 (MON) should shift to 1 (SUN)');
	}

	@IsTest
	private static void shouldWrapDayOfWeekFromSundayToSaturday()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 23 ? * SUN', TIMEZONE_GMT, TIMEZONE_SAST);

		Assert.areEqual('0 0 1 ? * MON', result, 'UTC Sunday 23:00 should shift to SAST Monday 01:00');
	}

	@IsTest
	private static void shouldHandleHalfHourTimezoneWithMinuteCarryForward()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 45 14 * * ?', TIMEZONE_GMT, TIMEZONE_IST);

		Assert.areEqual('0 15 20 * * ?', result, 'UTC 14:45 shifted to IST should be 20:15');
	}

	@IsTest
	private static void shouldShiftMinutesWithoutCarryForHalfHourTimezone()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 30 14 * * ?', TIMEZONE_IST, TIMEZONE_GMT);

		Assert.areEqual('0 0 9 * * ?', result, 'IST 14:30 should shift to UTC 09:00 with no minute carry');
	}

	@IsTest
	private static void shouldReturnUnchangedWhenDifferentTimezonesHaveSameOffset()
	{
		String cron = '0 0 12 * * ?';

		String result = UTIL_CronExpression.shiftTimezone(cron, TIMEZONE_GMT, TIMEZONE_UTC);

		Assert.areEqual(cron, result, 'GMT and UTC have the same offset, cron should be unchanged');
	}

	@IsTest
	private static void shouldPassThroughWildcardMinutesForHalfHourTimezone()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 * 14 * * ?', TIMEZONE_IST, TIMEZONE_GMT);

		Assert.areEqual('0 * 9 * * ?', result, 'Wildcard minutes should pass through unshifted even with half-hour timezone');
	}

	@IsTest
	private static void shouldShiftCommaListMinutesForHalfHourTimezone()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0,30 14 * * ?', TIMEZONE_IST, TIMEZONE_GMT);

		Assert.areEqual('0 30,0 8 * * ?', result, 'Comma-list minutes should each shift by -30 for half-hour timezone');
	}

	@IsTest
	private static void shouldShiftDayOfMonthRange()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 1 10-20 * ?', TIMEZONE_AEST, TIMEZONE_GMT);

		Assert.areEqual('0 0 15 9-19 * ?', result, 'Day-of-month range should shift both endpoints');
	}

	@IsTest
	private static void shouldNotShiftDayOfMonthBelowOne()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 1 1 * ?', TIMEZONE_AEST, TIMEZONE_GMT);

		Assert.areEqual('0 0 15 1 * ?', result, 'Day-of-month should not shift below 1');
	}

	@IsTest
	private static void shouldNotShiftDayOfMonthAboveThirtyOne()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 23 31 * ?', TIMEZONE_GMT, TIMEZONE_SAST);

		Assert.areEqual('0 0 1 31 * ?', result, 'Day-of-month should not shift above 31');
	}

	@IsTest
	private static void shouldNotShiftDayOfMonthCommaListOnBoundary()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 1 1,15 * ?', TIMEZONE_AEST, TIMEZONE_GMT);

		Assert.areEqual('0 0 15 1,15 * ?', result, 'Day-of-month comma list should not shift when any value would cross boundary');
	}

	@IsTest
	private static void shouldNotShiftDayOfMonthRangeOnBoundary()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 1 1-15 * ?', TIMEZONE_AEST, TIMEZONE_GMT);

		Assert.areEqual('0 0 15 1-15 * ?', result, 'Day-of-month range should not shift when start would cross boundary');
	}

	@IsTest
	private static void shouldExpandWrappingRangeToCommaList()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 14-16 * * ?', TIMEZONE_SAST, TIMEZONE_AEST);

		Assert.areEqual('0 0 22,23,0 * * ?', result, 'Range crossing midnight should expand to comma list');
	}

	@IsTest
	private static void shouldPassThroughWildcardDayOfWeekOnRollover()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 1 ? * *', TIMEZONE_AEST, TIMEZONE_GMT);

		Assert.areEqual('0 0 15 ? * *', result, 'Wildcard day-of-week should pass through unshifted on rollover');
	}
}