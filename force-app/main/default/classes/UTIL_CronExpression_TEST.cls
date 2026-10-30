// SPDX-License-Identifier: Apache-2.0
/**
 * @description Unit tests for UTIL_CronExpression timezone shifting utility and next-fire-time evaluator. The four
 * quarter-hourly walks cover the whole of 2026 in New York between them, one quarter at a time, and their four sizes
 * are the year's 35,040 quarter hours: one hour short in the quarter that loses an hour, one hour over in the quarter
 * that gains one.
 *
 * @see UTIL_CronExpression
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date March 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.ApexUnitTestClassShouldHaveAsserts,PMD.CyclomaticComplexity')
@IsTest(seeAllData=false isParallel=true)
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

	/**
	 * @description Japan time, a zone with a whole-hour offset and no daylight-saving changes.
	 */
	private static final String TIMEZONE_TOKYO = 'Asia/Tokyo';

	/**
	 * @description New Zealand time, a zone twelve and thirteen hours ahead of UTC. Its clock changes land on the far
	 * side of the raw wall clock read as UTC, which is the case a first guess at the instant has to get right.
	 */
	private static final String TIMEZONE_AUCKLAND = 'Pacific/Auckland';

	/**
	 * @description A time zone key the platform does not recognise, because of the space.
	 */
	private static final String TIMEZONE_UNKNOWN = 'America/New York';

	/**
	 * @description An expression that fires once a day at 02:00 local.
	 */
	private static final String NIGHTLY_AT_TWO = '0 0 2 * * ?';

	/**
	 * @description An expression that fires on every quarter hour, so its hours field is a wildcard.
	 */
	private static final String EVERY_FIFTEEN_MINUTES = '0 */15 * * * ?';

	/**
	 * @description An expression that fires on every even local hour.
	 */
	private static final String EVERY_TWO_HOURS = '0 0 */2 * * ?';

	/**
	 * @description An expression that fires once a day at 01:30 local, the time that happens twice when the clocks go back.
	 */
	private static final String HALF_PAST_ONE = '0 30 1 * * ?';

	/**
	 * @description The number of days in 2026, the year the walks cover.
	 */
	private static final Integer DAYS_IN_2026 = 365;

	/**
	 * @description The number of minutes in a day.
	 */
	private static final Integer MINUTES_PER_DAY = 1440;

	/**
	 * @description The number of minutes in an hour, the size of a daylight-saving change.
	 */
	private static final Integer MINUTES_PER_HOUR = 60;

	/**
	 * @description Fifteen minutes in milliseconds, the smallest gap the quarter-hourly walk may show between two fires.
	 */
	private static final Integer FIFTEEN_MINUTES_IN_MILLISECONDS = 15 * 60 * 1000;

	/**
	 * @description One minute in milliseconds, the smallest gap the nightly walk may show between two fires.
	 */
	private static final Integer ONE_MINUTE_IN_MILLISECONDS = 60 * 1000;

	/**
	 * @description Quarter hours in the first quarter of 2026 in New York: 90 days, less the hour the spring-forward day loses.
	 */
	private static final Integer FIRES_IN_FIRST_QUARTER = (90 * MINUTES_PER_DAY - MINUTES_PER_HOUR) / 15;

	/**
	 * @description Quarter hours in the second quarter of 2026 in New York: 91 days with no clock change.
	 */
	private static final Integer FIRES_IN_SECOND_QUARTER = 91 * MINUTES_PER_DAY / 15;

	/**
	 * @description Quarter hours in the third quarter of 2026 in New York: 92 days with no clock change.
	 */
	private static final Integer FIRES_IN_THIRD_QUARTER = 92 * MINUTES_PER_DAY / 15;

	/**
	 * @description Quarter hours in the fourth quarter of 2026 in New York: 92 days, plus the hour the autumn day gains.
	 */
	private static final Integer FIRES_IN_FOURTH_QUARTER = (92 * MINUTES_PER_DAY + MINUTES_PER_HOUR) / 15;

	/**
	 * @description The format used to read the local date of a fire.
	 */
	private static final String LOCAL_DATE_FORMAT = 'yyyy-MM-dd';

	/**
	 * @description The format used to read the local time of a fire.
	 */
	private static final String LOCAL_TIME_FORMAT = 'HH:mm';

	/**
	 * @description A daily 14:00 schedule written for South Africa, which is two hours ahead of GMT, becomes 12:00 when it
	 * is rewritten for GMT. The hour changes so that the job still fires at the same moment.
	 */
	@IsTest
	private static void shouldShiftHoursBackward()
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

	/**
	 * @description The opposite direction also works: a daily 12:00 schedule written for GMT becomes 14:00 when it is
	 * rewritten for South Africa, two hours ahead.
	 */
	@IsTest
	private static void shouldShiftHoursForward()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 12 * * ?', TIMEZONE_GMT, TIMEZONE_SAST);

		Assert.areEqual('0 0 14 * * ?', result, 'UTC 12:00 should shift to SAST 14:00');
	}

	/**
	 * @description When the shift takes the hour past midnight, the hour wraps round the clock instead of going negative:
	 * 02:00 in Brisbane, ten hours ahead of GMT, becomes 16:00 GMT. The schedule runs every day, so the day fields stay
	 * as wildcards.
	 */
	@IsTest
	private static void shouldWrapHoursAcrossMidnight()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 2 * * ?', TIMEZONE_AEST, TIMEZONE_GMT);

		Assert.areEqual('0 0 16 * * ?', result, 'AEST 02:00 should shift to UTC 16:00 (previous day, but day is wildcard)');
	}

	/**
	 * @description When the shift moves the time onto the day before, a named weekday moves with it: Monday 01:00 in
	 * Brisbane becomes Sunday 15:00 GMT. Without this the job would fire a day late.
	 */
	@IsTest
	private static void shouldShiftDayOfWeekOnRollover()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 1 ? * MON', TIMEZONE_AEST, TIMEZONE_GMT);

		Assert.areEqual('0 0 15 ? * SUN', result, 'AEST Monday 01:00 should shift to UTC Sunday 15:00');
	}

	/**
	 * @description A schedule that fires every hour (a wildcard in the hours field) comes back unchanged when the two time
	 * zones are a whole number of hours apart, as South Africa and GMT are. "Every hour, on the hour" is the same set of
	 * moments in both.
	 */
	@IsTest
	private static void shouldNotShiftWildcardHours()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 * * * ?', TIMEZONE_SAST, TIMEZONE_GMT);

		Assert.areEqual('0 0 * * * ?', result, 'Wildcard hours should pass through unshifted');
	}

	/**
	 * @description A schedule whose hours field is a step (every second hour, written as a star, a slash and 2) comes
	 * back unchanged. The step is left as written and is not turned into a list of shifted hours.
	 */
	@IsTest
	private static void shouldNotShiftStepHours()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 */2 * * ?', TIMEZONE_SAST, TIMEZONE_GMT);

		Assert.areEqual('0 0 */2 * * ?', result, 'Step hours should pass through unshifted');
	}

	/**
	 * @description When the hours field is a list, every hour in the list is shifted: 8, 12 and 17 in South Africa become
	 * 6, 10 and 15 in GMT. A schedule that fires several times a day keeps all of its fire times.
	 */
	@IsTest
	private static void shouldShiftCommaListHours()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 8,12,17 * * ?', TIMEZONE_SAST, TIMEZONE_GMT);

		Assert.areEqual('0 0 6,10,15 * * ?', result, 'Comma list hours should each be shifted by -2');
	}

	/**
	 * @description When the hours field is a range, both ends of the range are shifted: 9 to 17 in South Africa becomes
	 * 7 to 15 in GMT, and the result is still written as a range.
	 */
	@IsTest
	private static void shouldShiftHourRange()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 9-17 * * ?', TIMEZONE_SAST, TIMEZONE_GMT);

		Assert.areEqual('0 0 7-15 * * ?', result, 'Hour range should shift both endpoints by -2');
	}

	/**
	 * @description When the schedule is already written for the time zone it is being moved to, it comes back exactly as
	 * it went in.
	 */
	@IsTest
	private static void shouldReturnUnchangedWhenSameTimezone()
	{
		String cron = '0 0 12 * * ?';

		String result = UTIL_CronExpression.shiftTimezone(cron, TIMEZONE_SAST, TIMEZONE_SAST);

		Assert.areEqual(cron, result, 'Same timezone should return unchanged cron');
	}

	/**
	 * @description When no source time zone is given, the schedule comes back exactly as it went in. A caller that has no
	 * time zone to pass gets the schedule as written, not an error.
	 */
	@IsTest
	private static void shouldReturnUnchangedWhenSourceTimezoneNull()
	{
		String cron = '0 0 12 * * ?';

		String result = UTIL_CronExpression.shiftTimezone(cron, null, TIMEZONE_GMT);

		Assert.areEqual(cron, result, 'Null source timezone should return unchanged cron');
	}

	/**
	 * @description A time zone that is not a whole number of hours from GMT changes the minutes as well as the hour: 14:00
	 * in India, five and a half hours ahead, becomes 08:30 GMT.
	 */
	@IsTest
	private static void shouldHandleHalfHourTimezoneOffset()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 14 * * ?', TIMEZONE_IST, TIMEZONE_GMT);

		Assert.areEqual('0 30 8 * * ?', result, 'IST 14:00 should shift to UTC 08:30');
	}

	/**
	 * @description A time zone the platform knows gives back some display name. The test checks only that the name is not
	 * blank, because the exact wording belongs to the platform.
	 */
	@IsTest
	private static void shouldReturnDisplayName()
	{
		String result = UTIL_CronExpression.getDisplayName(TIMEZONE_SAST);

		Assert.isTrue(String.isNotBlank(result), 'Display name should not be blank');
	}

	/**
	 * @description Asking for the display name of an empty time zone gives back an empty text, not null and not an error,
	 * so a caller can show the result without checking it first.
	 */
	@IsTest
	private static void shouldReturnEmptyDisplayNameWhenBlank()
	{
		String result = UTIL_CronExpression.getDisplayName('');

		Assert.areEqual('', result, 'Blank timezone should return empty display name');
	}

	/**
	 * @description When the shift moves the time onto the day before, a fixed day of the month moves with it: 01:00 on the
	 * 15th in Brisbane becomes 15:00 on the 14th in GMT.
	 */
	@IsTest
	private static void shouldHandleDayOfMonthRollover()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 1 15 * ?', TIMEZONE_AEST, TIMEZONE_GMT);

		Assert.areEqual('0 0 15 14 * ?', result, 'AEST 01:00 on 15th should shift to UTC 15:00 on 14th');
	}

	/**
	 * @description A day-of-month field of L, which means the last day of the month, is left as L even when the shift
	 * moves the time onto the day before. Only the hour changes, because "last day" has no number to take one from.
	 */
	@IsTest
	private static void shouldNotShiftDayOfMonthWithLastDaySuffix()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 1 L * ?', TIMEZONE_AEST, TIMEZONE_GMT);

		Assert.areEqual('0 0 15 L * ?', result, 'L suffix day-of-month should remain unchanged despite day rollover');
	}

	/**
	 * @description A weekday written with a hash and a number, such as MON#2 for the second Monday of the month, has its
	 * day moved and its number kept: it becomes SUN#2 when the shift moves the time onto the day before.
	 */
	@IsTest
	private static void shouldShiftDayOfWeekHashPattern()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 1 ? * MON#2', TIMEZONE_AEST, TIMEZONE_GMT);

		Assert.areEqual('0 0 15 ? * SUN#2', result, 'Hash pattern should shift day name while preserving occurrence number');
	}

	/**
	 * @description A weekday written with an L, such as FRIL for the last Friday of the month, has its day moved and its
	 * L kept: it becomes THUL when the shift moves the time onto the day before.
	 */
	@IsTest
	private static void shouldShiftDayOfWeekLastSuffix()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 1 ? * FRIL', TIMEZONE_AEST, TIMEZONE_GMT);

		Assert.areEqual('0 0 15 ? * THUL', result, 'L suffix should shift day name while preserving L');
	}

	/**
	 * @description An hour range that lands wholly on the next day after the shift is still written as a range: 20 to 23
	 * in GMT becomes 6 to 9 in Brisbane. Only a range that is split by midnight has to become a list (see
	 * shouldExpandWrappingRangeToCommaList).
	 */
	@IsTest
	private static void shouldKeepRangeThatLandsWhollyOnNextDay()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 20-23 * * ?', TIMEZONE_GMT, TIMEZONE_AEST);

		Assert.areEqual('0 0 6-9 * * ?', result, 'Range shifted entirely into next day should remain a valid range');
	}

	/**
	 * @description When the weekday field is a list and the shift moves the time onto the day before, every day in the
	 * list moves: Monday, Wednesday and Friday become Sunday, Tuesday and Thursday.
	 */
	@IsTest
	private static void shouldShiftDayOfWeekCommaList()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 1 ? * MON,WED,FRI', TIMEZONE_AEST, TIMEZONE_GMT);

		Assert.areEqual('0 0 15 ? * SUN,TUE,THU', result, 'Day-of-week comma list should shift each day');
	}

	/**
	 * @description When the weekday field is a range and the shift moves the time onto the day before, both ends of the
	 * range move: Monday to Friday becomes Sunday to Thursday.
	 */
	@IsTest
	private static void shouldShiftDayOfWeekRange()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 1 ? * MON-FRI', TIMEZONE_AEST, TIMEZONE_GMT);

		Assert.areEqual('0 0 15 ? * SUN-THU', result, 'Day-of-week range should shift both endpoints');
	}

	/**
	 * @description When the day-of-month field is a list and the shift moves the time onto the day before, every day in
	 * the list moves: the 5th and 15th become the 4th and 14th.
	 */
	@IsTest
	private static void shouldShiftDayOfMonthCommaList()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 1 5,15 * ?', TIMEZONE_AEST, TIMEZONE_GMT);

		Assert.areEqual('0 0 15 4,14 * ?', result, 'Day-of-month comma list should shift each value');
	}

	/**
	 * @description A weekday written as a number is moved and stays a number: 2, which is Monday, becomes 1, which is
	 * Sunday, when the shift moves the time onto the day before.
	 */
	@IsTest
	private static void shouldShiftNumericDayOfWeek()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 1 ? * 2', TIMEZONE_AEST, TIMEZONE_GMT);

		Assert.areEqual('0 0 15 ? * 1', result, 'Numeric day-of-week 2 (MON) should shift to 1 (SUN)');
	}

	/**
	 * @description A shift that moves the time onto the next day moves a named weekday forward too: Sunday 23:00 GMT
	 * becomes Monday 01:00 in South Africa. This is the forward case; the other weekday tests all move a day back.
	 */
	@IsTest
	private static void shouldWrapDayOfWeekFromSundayToMonday()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 23 ? * SUN', TIMEZONE_GMT, TIMEZONE_SAST);

		Assert.areEqual('0 0 1 ? * MON', result, 'UTC Sunday 23:00 should shift to SAST Monday 01:00');
	}

	/**
	 * @description When adding a half-hour offset takes the minutes past 60, the extra hour is carried into the hours
	 * field: 14:45 GMT becomes 20:15 in India, not 19:15.
	 */
	@IsTest
	private static void shouldHandleHalfHourTimezoneWithMinuteCarryForward()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 45 14 * * ?', TIMEZONE_GMT, TIMEZONE_IST);

		Assert.areEqual('0 15 20 * * ?', result, 'UTC 14:45 shifted to IST should be 20:15');
	}

	/**
	 * @description When taking off a half-hour offset leaves the minutes at exactly zero, nothing is borrowed from the
	 * hours field: 14:30 in India becomes 09:00 GMT.
	 */
	@IsTest
	private static void shouldShiftMinutesWithoutCarryForHalfHourTimezone()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 30 14 * * ?', TIMEZONE_IST, TIMEZONE_GMT);

		Assert.areEqual('0 0 9 * * ?', result, 'IST 14:30 should shift to UTC 09:00 with no minute carry');
	}

	/**
	 * @description Two time zones with different names but the same offset, here GMT and UTC, leave the schedule exactly
	 * as it went in. The shift depends on the difference in offset, not on whether the names match.
	 */
	@IsTest
	private static void shouldReturnUnchangedWhenDifferentTimezonesHaveSameOffset()
	{
		String cron = '0 0 12 * * ?';

		String result = UTIL_CronExpression.shiftTimezone(cron, TIMEZONE_GMT, TIMEZONE_UTC);

		Assert.areEqual(cron, result, 'GMT and UTC have the same offset, cron should be unchanged');
	}

	/**
	 * @description Records that a schedule which fires every minute of an hour keeps its wildcard in the minutes field and
	 * only the hour moves. Between two time zones that are half an hour apart, the half hour is dropped, so the job runs
	 * thirty minutes late. In the test, 14:00 to 14:59 in India becomes 09:00 to 09:59 GMT, where the true window is
	 * 08:30 to 09:29 GMT. This is a known limit of the conversion: one schedule cannot describe an hour that starts on the
	 * half hour.
	 */
	@IsTest
	private static void shouldPassThroughWildcardMinutesForHalfHourTimezone()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 * 14 * * ?', TIMEZONE_IST, TIMEZONE_GMT);

		Assert.areEqual('0 * 9 * * ?', result, 'Wildcard minutes should pass through unshifted even with half-hour timezone');
	}

	/**
	 * @description Records what the conversion gives back for a list of minutes between two time zones that are half an
	 * hour apart, and that result is wrong for one of the minutes. Every minute in the list is shifted by thirty minutes,
	 * but the hours field holds one hour for the whole list, and that hour is worked out from the first minute. The first
	 * minute lands on the right time. The second is given the first one's hour, so it fires an hour early. In the test,
	 * 14:00 and 14:30 in India become 08:30 and 08:00 GMT, where 14:30 in India is really 09:00 GMT. This is a known limit
	 * of the conversion: one schedule cannot hold both 08:30 and 09:00. The expected value in this test will change when
	 * the conversion is corrected.
	 */
	@IsTest
	private static void shouldShiftCommaListMinutesForHalfHourTimezone()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0,30 14 * * ?', TIMEZONE_IST, TIMEZONE_GMT);

		Assert.areEqual('0 30,0 8 * * ?', result, 'Comma-list minutes should each shift by -30 for half-hour timezone');
	}

	/**
	 * @description When the day-of-month field is a range and the shift moves the time onto the day before, both ends of
	 * the range move: the 10th to the 20th becomes the 9th to the 19th.
	 */
	@IsTest
	private static void shouldShiftDayOfMonthRange()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 1 10-20 * ?', TIMEZONE_AEST, TIMEZONE_GMT);

		Assert.areEqual('0 0 15 9-19 * ?', result, 'Day-of-month range should shift both endpoints');
	}

	/**
	 * @description The 1st of the month is never moved back to a day 0, which does not exist. When the shift would move
	 * the time onto the day before, the hour still changes but the day stays the 1st, so the result names a real day.
	 * The job then fires one day later than the schedule as written, because the day before the 1st depends on the month.
	 */
	@IsTest
	private static void shouldNotShiftDayOfMonthBelowOne()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 1 1 * ?', TIMEZONE_AEST, TIMEZONE_GMT);

		Assert.areEqual('0 0 15 1 * ?', result, 'Day-of-month should not shift below 1');
	}

	/**
	 * @description The 31st of the month is never moved forward to a day 32, which does not exist. When the shift would
	 * move the time onto the next day, the hour still changes but the day stays the 31st. The job then fires one day
	 * earlier than the schedule as written.
	 */
	@IsTest
	private static void shouldNotShiftDayOfMonthAboveThirtyOne()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 23 31 * ?', TIMEZONE_GMT, TIMEZONE_SAST);

		Assert.areEqual('0 0 1 31 * ?', result, 'Day-of-month should not shift above 31');
	}

	/**
	 * @description A day-of-month list is shifted as a whole or not at all. The list 1,15 holds the 1st, which cannot move
	 * a day back, so the whole list is left as written and the 15th does not become the 14th. Only the hour changes, so
	 * both days fire one day later than the schedule as written.
	 */
	@IsTest
	private static void shouldNotShiftDayOfMonthCommaListOnBoundary()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 1 1,15 * ?', TIMEZONE_AEST, TIMEZONE_GMT);

		Assert.areEqual('0 0 15 1,15 * ?', result, 'Day-of-month comma list should not shift when any value would cross boundary');
	}

	/**
	 * @description A day-of-month range is shifted as a whole or not at all. The range 1-15 starts on the 1st, which
	 * cannot move a day back, so the whole range is left as written. Only the hour changes, so every day in the range
	 * fires one day later than the schedule as written.
	 */
	@IsTest
	private static void shouldNotShiftDayOfMonthRangeOnBoundary()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 1 1-15 * ?', TIMEZONE_AEST, TIMEZONE_GMT);

		Assert.areEqual('0 0 15 1-15 * ?', result, 'Day-of-month range should not shift when start would cross boundary');
	}

	/**
	 * @description An hour range that is split by midnight after the shift cannot stay a range, so it is written out as a
	 * list: 14 to 16 in South Africa becomes 22, 23 and 0 in Brisbane, eight hours further ahead.
	 */
	@IsTest
	private static void shouldExpandWrappingRangeToCommaList()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 14-16 * * ?', TIMEZONE_SAST, TIMEZONE_AEST);

		Assert.areEqual('0 0 22,23,0 * * ?', result, 'Range crossing midnight should expand to comma list');
	}

	/**
	 * @description A wildcard in the day-of-week field is left as a wildcard when the shift moves the time onto the day
	 * before. "Every day of the week" has no single day to move, so only the hour changes.
	 */
	@IsTest
	private static void shouldPassThroughWildcardDayOfWeekOnRollover()
	{
		String result = UTIL_CronExpression.shiftTimezone('0 0 1 ? * *', TIMEZONE_AEST, TIMEZONE_GMT);

		Assert.areEqual('0 0 15 ? * *', result, 'Wildcard day-of-week should pass through unshifted on rollover');
	}

	/**
	 * @description Builds the instant of a local wall-clock moment in a zone, for walk boundaries that never sit on a
	 * transition (1 January). Tests never use the evaluator's own conversion to define their own boundaries.
	 *
	 * @param year The local year.
	 * @param month The local month.
	 * @param day The local day of the month.
	 * @param zoneId The time zone the wall clock is read in; blank means UTC, because TimeZone.getTimeZone throws on a null identifier.
	 *
	 * @return The instant of local midnight on that date.
	 */
	private static Datetime localInstant(Integer year, Integer month, Integer day, String zoneId)
	{
		Datetime asIfUtc = Datetime.newInstanceGmt(year, month, day, 0, 0, 0);
		TimeZone zone = TimeZone.getTimeZone(String.isBlank(zoneId) ? TIMEZONE_UTC : zoneId);
		return Datetime.newInstance(asIfUtc.getTime() - zone.getOffset(asIfUtc));
	}

	/**
	 * @description Walks an expression from 2026-01-01T00:00 local to 2027-01-01T00:00 local, feeding each fire back in as
	 * the next `after`, and returns every fire in order.
	 *
	 * @param expression The cron expression to walk.
	 * @param zoneId The time zone the expression is read in.
	 *
	 * @return Every fire in the year, in order.
	 */
	private static List<Datetime> walkYear2026(String expression, String zoneId)
	{
		return walkLocalRange(expression, zoneId, localInstant(2026, 1, 1, zoneId), localInstant(2027, 1, 1, zoneId));
	}

	/**
	 * @description Walks an expression from one local midnight up to another, feeding each fire back in as the next
	 * `after`, and returns every fire in order.
	 *
	 * @param expression The cron expression to walk.
	 * @param zoneId The time zone the expression is read in.
	 * @param fromLocalMidnight The local midnight the walk starts at.
	 * @param toLocalMidnight The local midnight the walk stops before.
	 *
	 * @return Every fire in the range, in order.
	 */
	private static List<Datetime> walkLocalRange(String expression, String zoneId, Datetime fromLocalMidnight, Datetime toLocalMidnight)
	{
		List<Datetime> fires = new List<Datetime>();
		Datetime fire = UTIL_CronExpression.nextFireTime(expression, fromLocalMidnight.addMinutes(-1), zoneId);
		while(fire != null && fire < toLocalMidnight)
		{
			fires.add(fire);
			fire = UTIL_CronExpression.nextFireTime(expression, fire, zoneId);
		}
		return fires;
	}

	/**
	 * @description Counts how many of the given fires land on one local date in a zone.
	 *
	 * @param fires The fires to count.
	 * @param zoneId The time zone the local date is read in.
	 * @param localDate The local date, as yyyy-MM-dd.
	 *
	 * @return The number of fires on that local date.
	 */
	private static Integer countOnLocalDate(List<Datetime> fires, String zoneId, String localDate)
	{
		Integer count = 0;
		for(Datetime fire : fires)
		{
			if(fire.format(LOCAL_DATE_FORMAT, zoneId) == localDate)
			{
				count++;
			}
		}
		return count;
	}

	/**
	 * @description Counts how many times one exact instant appears among the fires.
	 *
	 * @param fires The fires to count.
	 * @param instant The instant to look for.
	 *
	 * @return The number of fires at that instant.
	 */
	private static Integer countOfInstant(List<Datetime> fires, Datetime instant)
	{
		Integer count = 0;
		for(Datetime fire : fires)
		{
			if(fire == instant)
			{
				count++;
			}
		}
		return count;
	}

	/**
	 * @description Asserts the fires rise in order and never sit closer together than the given gap.
	 *
	 * @param fires The fires to check.
	 * @param minimumGapMilliseconds The smallest gap allowed between two fires.
	 */
	private static void assertStrictlyIncreasing(List<Datetime> fires, Integer minimumGapMilliseconds)
	{
		for(Integer index = 1; index < fires.size(); index++)
		{
			String failureMessage = 'fires rise and keep the gap: ' + fires[index - 1] + ' then ' + fires[index];
			Assert.isTrue(fires[index].getTime() - fires[index - 1].getTime() >= minimumGapMilliseconds, failureMessage);
		}
	}

	/**
	 * @description Proves a nightly 02:00 job in New York fires once on every local day of the year, including the day
	 * the clocks go forward, when 02:00 does not exist and the fire lands at 03:00 instead.
	 */
	@IsTest
	private static void nightlyInNewYorkFiresOncePerLocalDayAcrossBothTransitions()
	{
		List<Datetime> fires = walkYear2026(NIGHTLY_AT_TWO, TIMEZONE_NYC);

		Assert.areEqual(DAYS_IN_2026, fires.size(), 'one fire per local day, none missed, none repeated');
		assertStrictlyIncreasing(fires, ONE_MINUTE_IN_MILLISECONDS);
		Integer atTwo = 0;
		Integer atThree = 0;
		for(Datetime fire : fires)
		{
			String localTime = fire.format(LOCAL_TIME_FORMAT, TIMEZONE_NYC);
			if(localTime == '02:00')
			{
				atTwo++;
			}
			else if(localTime == '03:00')
			{
				atThree++;
				Assert.areEqual('2026-03-08', fire.format(LOCAL_DATE_FORMAT, TIMEZONE_NYC), 'the only 03:00 fire is the spring-forward day, when 02:00 does not exist');
			}
		}
		Assert.areEqual(DAYS_IN_2026 - 1, atTwo, 'every other night fires at 02:00 local');
		Assert.areEqual(1, atThree, 'the gap night fires at the transition boundary');
	}

	/**
	 * @description Proves a nightly 02:00 job fires at 02:00 local every day of the year in a zone whose clocks never
	 * change.
	 */
	@IsTest
	private static void nightlyInTokyoFiresAtTwoEveryDay()
	{
		List<Datetime> fires = walkYear2026(NIGHTLY_AT_TWO, TIMEZONE_TOKYO);

		Assert.areEqual(DAYS_IN_2026, fires.size(), 'one fire per day in a zone without transitions');
		for(Datetime fire : fires)
		{
			Assert.areEqual('02:00', fire.format(LOCAL_TIME_FORMAT, TIMEZONE_TOKYO), 'always 02:00 local');
		}
	}

	/**
	 * @description Proves a nightly 02:00 job fires at 02:00 local every day in a zone half an hour off UTC, and that
	 * the half hour shows up in the minute of the UTC instant.
	 */
	@IsTest
	private static void nightlyInKolkataHonoursTheHalfHourOffset()
	{
		List<Datetime> fires = walkYear2026(NIGHTLY_AT_TWO, TIMEZONE_IST);

		Assert.areEqual(DAYS_IN_2026, fires.size(), 'one fire per day in a half-hour-offset zone');
		for(Datetime fire : fires)
		{
			Assert.areEqual('02:00', fire.format(LOCAL_TIME_FORMAT, TIMEZONE_IST), 'always 02:00 local, so the UTC instant sits at 20:30');
			Assert.areEqual(30, fire.minuteGmt(), 'the UTC minute carries the half hour');
		}
	}

	/**
	 * @description Proves a blank time zone is read as UTC: every fire of the year matches a baseline of 02:00 UTC on
	 * each day in turn, written out here rather than taken from the evaluator.
	 */
	@IsTest
	private static void blankZoneReproducesTheUtcGoldenBaseline()
	{
		List<Datetime> fires = walkYear2026(NIGHTLY_AT_TWO, null);

		Assert.areEqual(DAYS_IN_2026, fires.size(), 'a blank zone means UTC');
		for(Integer index = 0; index < fires.size(); index++)
		{
			Assert.areEqual(Datetime.newInstanceGmt(2026, 1, 1, 2, 0, 0).addDays(index), fires[index], 'element ' + index + ' of the golden baseline');
		}
	}

	/**
	 * @description Proves a local time that happens twice on the day the clocks go back fires once, at the earlier of
	 * the two moments.
	 */
	@IsTest
	private static void fallBackOverlapFiresAtTheEarliestOccurrenceOnly()
	{
		List<Datetime> fires = walkYear2026(HALF_PAST_ONE, TIMEZONE_NYC);

		Assert.areEqual(1, countOnLocalDate(fires, TIMEZONE_NYC, '2026-11-01'), 'the repeated 01:30 fires once');
		Assert.isTrue(fires.contains(Datetime.newInstanceGmt(2026, 11, 1, 5, 30, 0)), 'the fire is 01:30 EDT (05:30Z), the earliest occurrence');
		Assert.isFalse(fires.contains(Datetime.newInstanceGmt(2026, 11, 1, 6, 30, 0)), 'never 01:30 EST (06:30Z)');
	}

	/**
	 * @description Proves a quarter-hourly job follows instants rather than the local clock through the quarter that
	 * loses an hour: the quarter is one hour of quarter hours short, and the 23-hour day holds 92 of them.
	 */
	@IsTest
	private static void everyFifteenMinutesFollowsInstantsThroughTheFirstQuarter()
	{
		Datetime quarterStart = localInstant(2026, 1, 1, TIMEZONE_NYC);
		Datetime quarterEnd = localInstant(2026, 4, 1, TIMEZONE_NYC);
		List<Datetime> fires = walkLocalRange(EVERY_FIFTEEN_MINUTES, TIMEZONE_NYC, quarterStart, quarterEnd);

		Assert.areEqual(FIRES_IN_FIRST_QUARTER, fires.size(), 'the quarter that loses an hour is one hour of quarter hours short');
		Assert.areEqual(92, countOnLocalDate(fires, TIMEZONE_NYC, '2026-03-08'), 'a 23-hour day has 92 quarter hours');
		assertStrictlyIncreasing(fires, FIFTEEN_MINUTES_IN_MILLISECONDS);
	}

	/**
	 * @description Proves a quarter-hourly job holds every quarter hour of the second quarter, which has no clock
	 * change, and that the fires rise in order.
	 */
	@IsTest
	private static void everyFifteenMinutesFollowsInstantsThroughTheSecondQuarter()
	{
		Datetime quarterStart = localInstant(2026, 4, 1, TIMEZONE_NYC);
		Datetime quarterEnd = localInstant(2026, 7, 1, TIMEZONE_NYC);
		List<Datetime> fires = walkLocalRange(EVERY_FIFTEEN_MINUTES, TIMEZONE_NYC, quarterStart, quarterEnd);

		Assert.areEqual(FIRES_IN_SECOND_QUARTER, fires.size(), 'a quarter without a clock change holds every quarter hour');
		assertStrictlyIncreasing(fires, FIFTEEN_MINUTES_IN_MILLISECONDS);
	}

	/**
	 * @description Proves a quarter-hourly job holds every quarter hour of the third quarter, which has no clock
	 * change, and that the fires rise in order.
	 */
	@IsTest
	private static void everyFifteenMinutesFollowsInstantsThroughTheThirdQuarter()
	{
		Datetime quarterStart = localInstant(2026, 7, 1, TIMEZONE_NYC);
		Datetime quarterEnd = localInstant(2026, 10, 1, TIMEZONE_NYC);
		List<Datetime> fires = walkLocalRange(EVERY_FIFTEEN_MINUTES, TIMEZONE_NYC, quarterStart, quarterEnd);

		Assert.areEqual(FIRES_IN_THIRD_QUARTER, fires.size(), 'a quarter without a clock change holds every quarter hour');
		assertStrictlyIncreasing(fires, FIFTEEN_MINUTES_IN_MILLISECONDS);
	}

	/**
	 * @description Proves a quarter-hourly job follows instants through the quarter that gains an hour: the quarter
	 * holds one hour of quarter hours more, and the 25-hour day holds 100 of them.
	 */
	@IsTest
	private static void everyFifteenMinutesFollowsInstantsThroughTheFourthQuarter()
	{
		Datetime quarterStart = localInstant(2026, 10, 1, TIMEZONE_NYC);
		Datetime quarterEnd = localInstant(2027, 1, 1, TIMEZONE_NYC);
		List<Datetime> fires = walkLocalRange(EVERY_FIFTEEN_MINUTES, TIMEZONE_NYC, quarterStart, quarterEnd);

		Assert.areEqual(FIRES_IN_FOURTH_QUARTER, fires.size(), 'the quarter that gains an hour holds one hour of quarter hours more');
		Assert.areEqual(100, countOnLocalDate(fires, TIMEZONE_NYC, '2026-11-01'), 'a 25-hour day has 100 quarter hours');
		assertStrictlyIncreasing(fires, FIFTEEN_MINUTES_IN_MILLISECONDS);
	}

	/**
	 * @description Proves an every-two-hours job follows the local clock: twelve fires on each of the two days the
	 * clocks change, the hour that does not exist firing when the clocks jump and the hour that happens twice firing
	 * once.
	 */
	@IsTest
	private static void everyTwoHoursFollowsTheLocalClockAndFiresOncePerMatchingLocalHour()
	{
		List<Datetime> fires = walkYear2026(EVERY_TWO_HOURS, TIMEZONE_NYC);

		Assert.areEqual(12, countOnLocalDate(fires, TIMEZONE_NYC, '2026-03-08'), 'twelve even local hours; the 02:00 that does not exist fires at the 03:00 boundary');
		Assert.areEqual(12, countOnLocalDate(fires, TIMEZONE_NYC, '2026-11-01'), 'twelve even local hours; 02:00 exists once, as EST');
		Assert.isTrue(fires.contains(Datetime.newInstanceGmt(2026, 3, 8, 7, 0, 0)), 'the gap hour fires at the moment the clocks jump (07:00Z)');
		Assert.isTrue(fires.contains(Datetime.newInstanceGmt(2026, 3, 8, 8, 0, 0)), 'and 04:00 EDT follows one hour later, the once-a-year one-hour shift');
		assertStrictlyIncreasing(fires, ONE_MINUTE_IN_MILLISECONDS);
		Assert.areEqual(1, countOfInstant(fires, Datetime.newInstanceGmt(2026, 11, 1, 7, 0, 0)), '02:00 on the autumn day is 07:00Z, EST, and it fires exactly once');
	}

	/**
	 * @description Asserts an expression fires on the given local dates in turn, each at the given local time, in New York.
	 *
	 * @param expression The cron expression to walk.
	 * @param expectedLocalDates The local dates the expression is expected to fire on, in order.
	 * @param expectedLocalTime The local time every fire is expected to sit at, as HH:mm.
	 */
	private static void assertConsecutiveFires(String expression, List<Date> expectedLocalDates, String expectedLocalTime)
	{
		Datetime cursor = localInstant(2026, 1, 1, TIMEZONE_NYC).addMinutes(-1);
		for(Date expected : expectedLocalDates)
		{
			Datetime fire = UTIL_CronExpression.nextFireTime(expression, cursor, TIMEZONE_NYC);
			Assert.isNotNull(fire, expression + ' fires after ' + cursor);
			Assert.areEqual(String.valueOf(expected), fire.format(LOCAL_DATE_FORMAT, TIMEZONE_NYC), expression + ' next local date after ' + cursor);
			Assert.areEqual(expectedLocalTime, fire.format(LOCAL_TIME_FORMAT, TIMEZONE_NYC), expression + ' local time');
			cursor = fire;
		}
	}

	/**
	 * @description Proves LW fires on the last weekday of every month of the year, against dates worked out by hand.
	 */
	@IsTest
	private static void lastWeekdayOfMonthFiresOnHandComputedDates()
	{
		assertConsecutiveFires('0 0 6 LW * ?', new List<Date>
		{
				Date.newInstance(2026, 1, 30), Date.newInstance(2026, 2, 27), Date.newInstance(2026, 3, 31), Date.newInstance(2026, 4, 30),
				Date.newInstance(2026, 5, 29), Date.newInstance(2026, 6, 30), Date.newInstance(2026, 7, 31), Date.newInstance(2026, 8, 31),
				Date.newInstance(2026, 9, 30), Date.newInstance(2026, 10, 30), Date.newInstance(2026, 11, 30), Date.newInstance(2026, 12, 31)
		}, '06:00');
	}

	/**
	 * @description Proves 15W fires on the weekday nearest the fifteenth, moving back from a Saturday and on from a
	 * Sunday, and never leaves the month.
	 */
	@IsTest
	private static void nearestWeekdayToTheFifteenthStaysInsideTheMonth()
	{
		assertConsecutiveFires('0 0 6 15W * ?', new List<Date>
		{
				Date.newInstance(2026, 1, 15), Date.newInstance(2026, 2, 16), Date.newInstance(2026, 3, 16), Date.newInstance(2026, 4, 15),
				Date.newInstance(2026, 5, 15), Date.newInstance(2026, 6, 15), Date.newInstance(2026, 7, 15), Date.newInstance(2026, 8, 14),
				Date.newInstance(2026, 9, 15), Date.newInstance(2026, 10, 15), Date.newInstance(2026, 11, 16), Date.newInstance(2026, 12, 15)
		}, '06:00');
	}

	/**
	 * @description Proves 6L fires on the last Friday of every month of the year, against dates worked out by hand.
	 */
	@IsTest
	private static void lastFridayOfMonthFiresOnHandComputedDates()
	{
		assertConsecutiveFires('0 0 6 ? * 6L', new List<Date>
		{
				Date.newInstance(2026, 1, 30), Date.newInstance(2026, 2, 27), Date.newInstance(2026, 3, 27), Date.newInstance(2026, 4, 24),
				Date.newInstance(2026, 5, 29), Date.newInstance(2026, 6, 26), Date.newInstance(2026, 7, 31), Date.newInstance(2026, 8, 28),
				Date.newInstance(2026, 9, 25), Date.newInstance(2026, 10, 30), Date.newInstance(2026, 11, 27), Date.newInstance(2026, 12, 25)
		}, '06:00');
	}

	/**
	 * @description Proves 2#5 fires on the fifth Monday of a month and passes over every month that has only four.
	 */
	@IsTest
	private static void fifthMondayOfMonthSkipsMonthsWithoutOne()
	{
		assertConsecutiveFires('0 0 6 ? * 2#5', new List<Date>
		{
				Date.newInstance(2026, 3, 30), Date.newInstance(2026, 6, 29), Date.newInstance(2026, 8, 31), Date.newInstance(2026, 11, 30),
				Date.newInstance(2027, 3, 29), Date.newInstance(2027, 5, 31), Date.newInstance(2027, 8, 30), Date.newInstance(2027, 11, 29),
				Date.newInstance(2028, 1, 31), Date.newInstance(2028, 5, 29), Date.newInstance(2028, 7, 31), Date.newInstance(2028, 10, 30)
		}, '06:00');
	}

	/**
	 * @description Proves 29 February is found four years at a time, and that a fire sitting exactly on the last day
	 * the search looks at is still returned rather than given up on.
	 */
	@IsTest
	private static void leapDayFiresEveryFourYearsAndTheHorizonIsInclusive()
	{
		Datetime cursor = Datetime.newInstanceGmt(2026, 1, 1, 0, 0, 0);
		for(Integer leapYear = 2028; leapYear <= 2072; leapYear += 4)
		{
			Datetime fire = UTIL_CronExpression.nextFireTime('0 0 0 29 2 ?', cursor, null);
			Assert.areEqual(Datetime.newInstanceGmt(leapYear, 2, 29, 0, 0, 0), fire, 'the next 29 February after ' + cursor);
			cursor = fire;
		}
		Datetime fromLeapDay = Datetime.newInstanceGmt(2028, 2, 29, 0, 0, 0);
		Assert.areEqual(1461, Date.newInstance(2028, 2, 29).daysBetween(Date.newInstance(2032, 2, 29)), 'the next leap day is exactly 1,461 days out');
		Datetime fireAtHorizon = UTIL_CronExpression.nextFireTime('0 0 0 29 2 ?', fromLeapDay, null);
		Assert.areEqual(Datetime.newInstanceGmt(2032, 2, 29, 0, 0, 0), fireAtHorizon, 'a fire exactly at the horizon is found, not parked');
	}

	/**
	 * @description Proves a day of month of 31 fires only in the months that have a 31st, passing over the others.
	 */
	@IsTest
	private static void thirtyFirstSkipsTheShortMonths()
	{
		assertConsecutiveFires('0 0 0 31 * ?', new List<Date>
		{
				Date.newInstance(2026, 1, 31), Date.newInstance(2026, 3, 31), Date.newInstance(2026, 5, 31), Date.newInstance(2026, 7, 31),
				Date.newInstance(2026, 8, 31), Date.newInstance(2026, 10, 31), Date.newInstance(2026, 12, 31), Date.newInstance(2027, 1, 31),
				Date.newInstance(2027, 3, 31), Date.newInstance(2027, 5, 31), Date.newInstance(2027, 7, 31), Date.newInstance(2027, 8, 31)
		}, '00:00');
	}

	/**
	 * @description Proves that each way of writing an expression wrongly, from an out-of-range minute to a blank one,
	 * is refused with the typed exception whose message names the token that could not be read.
	 */
	@IsTest
	private static void malformedExpressionsThrowTheTypedException()
	{
		List<String> malformedExpressions = new List<String>
		{
				'0 61 * * * ?', '0 0 12 * * *', '0 0 12 ? * ?', '5 0 12 * * ?', 'banana',
				'0 0 12 * * ? 1999 extra', '0 */0 * * * ?', '0 0 12 32 * ?', '', null,
				'0 , * * * ?', '0 0 ,, * * ?', '0 0 2147483648 * * ?'
		};
		for(String malformed : malformedExpressions)
		{
			try
			{
				UTIL_CronExpression.nextFireTime(malformed, Datetime.newInstanceGmt(2026, 1, 1, 0, 0, 0), null);
				Assert.fail('a malformed expression must throw: [' + malformed + ']');
			}
			catch(IllegalArgumentException error)
			{
				Assert.isTrue(error.getMessage().contains('could not be read'), 'the message is the label text for [' + malformed + ']: ' + error.getMessage());
			}
		}
	}

	/**
	 * @description Proves an expression that can never fire, a year already past or a date that does not exist,
	 * answers null rather than throwing, which is how the runner knows to set the job aside.
	 */
	@IsTest
	private static void unplaceableExpressionsReturnNull()
	{
		Datetime after = Datetime.newInstanceGmt(2026, 1, 1, 0, 0, 0);
		Assert.isNull(UTIL_CronExpression.nextFireTime('0 0 12 * * ? 2020', after, null), 'a year in the past never fires');
		Assert.isNull(UTIL_CronExpression.nextFireTime('0 0 0 30 2 ?', after, null), '30 February never exists');
	}

	/**
	 * @description Proves the answer is always later than the moment asked about and always on a whole minute: the
	 * minute the caller is already in is never returned, and a moment part way through a minute moves to the next one.
	 */
	@IsTest
	private static void nextFireIsStrictlyAfterTheGivenInstantAndMinuteAligned()
	{
		Datetime onTheMinute = Datetime.newInstanceGmt(2026, 5, 4, 7, 35, 0);
		Assert.areEqual(Datetime.newInstanceGmt(2026, 5, 4, 8, 35, 0), UTIL_CronExpression.nextFireTime('0 35 * * * ?', onTheMinute, null), 'the current minute is never returned');
		Datetime midMinute = Datetime.newInstanceGmt(2026, 5, 4, 7, 35, 12);
		Datetime afterMidMinute = UTIL_CronExpression.nextFireTime('0 * * * * ?', midMinute, null);
		Assert.areEqual(Datetime.newInstanceGmt(2026, 5, 4, 7, 36, 0), afterMidMinute, 'the next whole minute after a mid-minute instant');
	}

	/**
	 * @description Proves a missing moment to fire after is refused with the typed exception rather than read as now.
	 */
	@IsTest
	private static void aMissingInstantIsRejected()
	{
		try
		{
			UTIL_CronExpression.nextFireTime(NIGHTLY_AT_TWO, null, null);
			Assert.fail('a missing instant must throw');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'a missing instant is rejected with the typed exception');
			Assert.isTrue(error.getMessage().contains('could not be read'), 'the message is the label text: ' + error.getMessage());
		}
	}

	/**
	 * @description Proves that when the hours field is a wildcard the search jumps to the next local midnight on a date
	 * the expression cannot match, instead of stepping a minute at a time through the whole day.
	 */
	@IsTest
	private static void theInstantRuleSkipsWholeDaysThatDoNotMatchTheDate()
	{
		Datetime midJanuary = Datetime.newInstanceGmt(2026, 1, 15, 9, 0, 0);
		Datetime fire = UTIL_CronExpression.nextFireTime('0 0 * 1 * ?', midJanuary, null);

		Assert.areEqual(Datetime.newInstanceGmt(2026, 2, 1, 0, 0, 0), fire, 'the walk jumps whole days to the first of the next month');
	}

	/**
	 * @description Proves that a wildcard-hours expression naming a date that never comes answers null once the search
	 * has run out of days to look at.
	 */
	@IsTest
	private static void theInstantRuleReturnsNullWhenNoDateEverMatches()
	{
		Datetime after = Datetime.newInstanceGmt(2026, 1, 1, 0, 0, 0);
		Datetime fire = UTIL_CronExpression.nextFireTime('0 0 * 30 2 ?', after, null);

		Assert.isNull(fire, '30 February never exists, so the hourly walk runs out of horizon');
	}

	/**
	 * @description Proves a local time that does not happen at all on the day the New York clocks go forward fires at
	 * the moment they jump.
	 */
	@IsTest
	private static void aWallClockTimeInsideTheSpringForwardGapFiresWhenTheClocksJump()
	{
		Datetime beforeTheGap = Datetime.newInstanceGmt(2026, 3, 8, 0, 0, 0);
		Datetime fire = UTIL_CronExpression.nextFireTime('0 30 2 * * ?', beforeTheGap, TIMEZONE_NYC);

		Assert.areEqual(Datetime.newInstanceGmt(2026, 3, 8, 7, 0, 0), fire, '02:30 does not exist that day, so the job fires at the moment the clocks jump');
	}

	/**
	 * @description Proves that a fire inside the spring-forward gap is still found when the moment to fire after sits in
	 * the last minute before the clocks jump. The New York clocks jump at 2026-03-08T07:00Z, so that instant already
	 * reads as 03:00 local and the 02:00 the expression names never happens that day: the fire is the jump itself, not
	 * the following night.
	 */
	@IsTest
	private static void aGapFireIsStillFoundFromTheMinuteBeforeTheNewYorkClocksJump()
	{
		Datetime theMinuteBeforeTheJump = Datetime.newInstanceGmt(2026, 3, 8, 6, 59, 0);
		Datetime fire = UTIL_CronExpression.nextFireTime(NIGHTLY_AT_TWO, theMinuteBeforeTheJump, TIMEZONE_NYC);

		Assert.areEqual(Datetime.newInstanceGmt(2026, 3, 8, 7, 0, 0), fire, 'the fire is the moment the clocks jump, not 02:00 the following night');
	}

	/**
	 * @description Proves a field whose shape cannot be read, a doubled step, a range with three ends, a range written
	 * backwards or a doubled occurrence mark, is refused with the typed exception.
	 */
	@IsTest
	private static void malformedFieldStructuresThrowTheTypedException()
	{
		List<String> malformedExpressions = new List<String>
		{
				'0 0/1/2 * * * ?', '0 0 1-2-3 * * ?', '0 0 17-9 * * ?', '0 0 6 ? * 2#3#4'
		};
		for(String malformed : malformedExpressions)
		{
			try
			{
				UTIL_CronExpression.nextFireTime(malformed, Datetime.newInstanceGmt(2026, 1, 1, 0, 0, 0), null);
				Assert.fail('a malformed field must throw: [' + malformed + ']');
			}
			catch(IllegalArgumentException error)
			{
				Assert.isTrue(error.getMessage().contains('could not be read'), 'the message is the label text for [' + malformed + ']: ' + error.getMessage());
			}
		}
	}

	/**
	 * @description Proves a range of hours fires on every hour it covers, one after another.
	 */
	@IsTest
	private static void anHourRangeFiresOnEveryHourItNames()
	{
		Datetime cursor = localInstant(2026, 1, 1, TIMEZONE_NYC).addMinutes(-1);
		for(String expectedLocalTime : new List<String> {'09:00', '10:00', '11:00'})
		{
			Datetime fire = UTIL_CronExpression.nextFireTime('0 0 9-11 * * ?', cursor, TIMEZONE_NYC);
			Assert.areEqual(expectedLocalTime, fire.format(LOCAL_TIME_FORMAT, TIMEZONE_NYC), 'the range fires on every hour it names');
			cursor = fire;
		}
	}

	/**
	 * @description Proves L in the day-of-month field fires on the last day of each month, against dates worked out by
	 * hand, including February's 28th.
	 */
	@IsTest
	private static void lastDayOfMonthFiresOnHandComputedDates()
	{
		assertConsecutiveFires('0 0 6 L * ?', new List<Date>
		{
				Date.newInstance(2026, 1, 31), Date.newInstance(2026, 2, 28), Date.newInstance(2026, 3, 31), Date.newInstance(2026, 4, 30)
		}, '06:00');
	}

	/**
	 * @description Proves a day of the week written by name fires on every such day, week after week.
	 */
	@IsTest
	private static void aNamedDayOfWeekFiresOnEveryMatchingDay()
	{
		assertConsecutiveFires('0 0 6 ? * MON', new List<Date>
		{
				Date.newInstance(2026, 1, 5), Date.newInstance(2026, 1, 12), Date.newInstance(2026, 1, 19), Date.newInstance(2026, 1, 26)
		}, '06:00');
	}

	/**
	 * @description Proves 1W fires on the weekday nearest the first of the month and never steps back into the month
	 * before, moving on to the Monday when the first is a weekend day.
	 */
	@IsTest
	private static void nearestWeekdayToTheFirstStaysInsideTheMonth()
	{
		assertConsecutiveFires('0 0 6 1W * ?', new List<Date>
		{
				Date.newInstance(2026, 1, 1), Date.newInstance(2026, 2, 2), Date.newInstance(2026, 3, 2), Date.newInstance(2026, 4, 1),
				Date.newInstance(2026, 5, 1), Date.newInstance(2026, 6, 1), Date.newInstance(2026, 7, 1), Date.newInstance(2026, 8, 3),
				Date.newInstance(2026, 9, 1), Date.newInstance(2026, 10, 1), Date.newInstance(2026, 11, 2), Date.newInstance(2026, 12, 1)
		}, '06:00');
	}

	/**
	 * @description Proves a month written by name is read as that month's number, so FEB fires in February.
	 */
	@IsTest
	private static void aMonthByNameFiresOnlyInThatMonth()
	{
		Datetime after = Datetime.newInstanceGmt(2026, 1, 1, 0, 0, 0);
		Datetime fire = UTIL_CronExpression.nextFireTime('0 0 6 15 FEB ?', after, null);

		Assert.areEqual(Datetime.newInstanceGmt(2026, 2, 15, 6, 0, 0), fire, 'a month named FEB is read as month 2');
	}

	/**
	 * @description Auckland is twelve hours ahead of UTC in winter (NZST) and thirteen in summer (NZDT). In 2026 the
	 * clocks go forward on Sunday 27 September, 02:00 NZST becoming 03:00 NZDT, which is the instant
	 * 2026-09-27 02:00 minus 12 hours = 2026-09-26T14:00Z; and back on Sunday 5 April, 03:00 NZDT becoming
	 * 02:00 NZST, which is 2026-04-05 03:00 minus 13 hours = 2026-04-04T14:00Z. So on 5 April the local time 02:00
	 * happens twice: first at 2026-04-05 02:00 minus 13 hours = 2026-04-04T13:00Z (still NZDT), then at
	 * 2026-04-05 02:00 minus 12 hours = 2026-04-04T14:00Z (NZST). The rule takes the earlier.
	 */
	@IsTest
	private static void nightlyInAucklandFiresOncePerLocalDayAcrossBothTransitions()
	{
		List<Datetime> fires = walkYear2026(NIGHTLY_AT_TWO, TIMEZONE_AUCKLAND);

		Assert.areEqual(DAYS_IN_2026, fires.size(), 'one fire per local day in a zone twelve and thirteen hours ahead of UTC');
		assertStrictlyIncreasing(fires, ONE_MINUTE_IN_MILLISECONDS);
		Integer atTwo = 0;
		Integer atThree = 0;
		for(Datetime fire : fires)
		{
			String localTime = fire.format(LOCAL_TIME_FORMAT, TIMEZONE_AUCKLAND);
			if(localTime == '02:00')
			{
				atTwo++;
			}
			else if(localTime == '03:00')
			{
				atThree++;
				Assert.areEqual('2026-09-27', fire.format(LOCAL_DATE_FORMAT, TIMEZONE_AUCKLAND), 'the only 03:00 fire is the spring-forward day, when 02:00 does not exist');
			}
		}
		Assert.areEqual(DAYS_IN_2026 - 1, atTwo, 'every other night fires at 02:00 local');
		Assert.areEqual(1, atThree, 'the gap night fires at the transition boundary');
		Assert.isTrue(fires.contains(Datetime.newInstanceGmt(2026, 4, 4, 13, 0, 0)), 'the repeated 02:00 fires at 13:00Z, the earlier NZDT occurrence');
		Assert.isFalse(fires.contains(Datetime.newInstanceGmt(2026, 4, 4, 14, 0, 0)), 'never at 14:00Z, the later NZST occurrence');
	}

	/**
	 * @description On 2026-09-27 the Auckland clocks jump from 02:00 NZST straight to 03:00 NZDT at 2026-09-26T14:00Z,
	 * so local 02:30 does not exist that day and the job fires at the jump. The wall clock 2026-09-27 02:30 read as
	 * UTC is 2026-09-27T02:30Z; the offset there is +13 hours, so the first guess at the instant is
	 * 2026-09-27T02:30Z minus 13 hours = 2026-09-26T13:30Z, which sits half an hour before the change and keeps both
	 * twelve-hour samples (2026-09-26T01:30Z at +12, 2026-09-27T01:30Z at +13) clear of it.
	 */
	@IsTest
	private static void aWallClockTimeInsideTheAucklandSpringForwardGapFiresWhenTheClocksJump()
	{
		Datetime localMidnightOnTheGapDay = Datetime.newInstanceGmt(2026, 9, 26, 12, 0, 0);
		Datetime fire = UTIL_CronExpression.nextFireTime('0 30 2 * * ?', localMidnightOnTheGapDay, TIMEZONE_AUCKLAND);

		Assert.areEqual(Datetime.newInstanceGmt(2026, 9, 26, 14, 0, 0), fire, '02:30 does not exist that day, so the job fires at the moment the clocks jump');
	}

	/**
	 * @description Proves the same for Auckland, a zone twelve and thirteen hours ahead of UTC: the clocks jump at
	 * 2026-09-26T14:00Z, so a moment to fire after in the minute before that still yields the jump itself, not 02:00
	 * the following night.
	 */
	@IsTest
	private static void aGapFireIsStillFoundFromTheMinuteBeforeTheAucklandClocksJump()
	{
		Datetime theMinuteBeforeTheJump = Datetime.newInstanceGmt(2026, 9, 26, 13, 59, 0);
		Datetime fire = UTIL_CronExpression.nextFireTime(NIGHTLY_AT_TWO, theMinuteBeforeTheJump, TIMEZONE_AUCKLAND);

		Assert.areEqual(Datetime.newInstanceGmt(2026, 9, 26, 14, 0, 0), fire, 'the fire is the moment the clocks jump, not 02:00 the following night');
	}

	/**
	 * @description Proves that a lone L in the day-of-week field is read as Saturday, the meaning the platform's own
	 * scheduler gives it, so an expression the scheduler accepts is not refused here. 1 January 2026 is a Thursday, so
	 * the first Saturday after it is the 3rd.
	 */
	@IsTest
	private static void aLoneLastTokenInTheDayOfWeekFieldMeansSaturday()
	{
		Datetime after = Datetime.newInstanceGmt(2026, 1, 1, 0, 0, 0);
		Datetime fire = UTIL_CronExpression.nextFireTime('0 0 12 ? * L', after, null);

		Assert.areEqual(Datetime.newInstanceGmt(2026, 1, 3, 12, 0, 0), fire, 'a lone L means Saturday, so the first fire is Saturday the 3rd at noon');
	}

	/**
	 * @description January in New York is Eastern Standard Time, five hours behind UTC, so 09:00 local is 14:00Z and
	 * 17:00 local is 22:00Z on the same date.
	 */
	@IsTest
	private static void anHourListFiresOnEveryHourItNames()
	{
		Datetime cursor = localInstant(2026, 1, 1, TIMEZONE_NYC).addMinutes(-1);
		List<Datetime> expected = new List<Datetime>
		{
				Datetime.newInstanceGmt(2026, 1, 1, 14, 0, 0), Datetime.newInstanceGmt(2026, 1, 1, 22, 0, 0), Datetime.newInstanceGmt(2026, 1, 2, 14, 0, 0)
		};
		for(Datetime expectedFire : expected)
		{
			Datetime fire = UTIL_CronExpression.nextFireTime('0 0 9,17 * * ?', cursor, TIMEZONE_NYC);
			Assert.areEqual(expectedFire, fire, 'the list fires on both hours it names, then rolls to the next day');
			cursor = fire;
		}
	}

	/**
	 * @description 1 January 2026 is a Thursday, so the Mondays, Wednesdays and Fridays that follow are Friday the
	 * 2nd, Monday the 5th, Wednesday the 7th, Friday the 9th and Monday the 12th. Each fires at 06:00 Eastern
	 * Standard Time, which is 11:00Z.
	 */
	@IsTest
	private static void aDayOfWeekListFiresOnEveryDayItNames()
	{
		Datetime cursor = localInstant(2026, 1, 1, TIMEZONE_NYC).addMinutes(-1);
		List<Datetime> expected = new List<Datetime>
		{
				Datetime.newInstanceGmt(2026, 1, 2, 11, 0, 0), Datetime.newInstanceGmt(2026, 1, 5, 11, 0, 0), Datetime.newInstanceGmt(2026, 1, 7, 11, 0, 0),
				Datetime.newInstanceGmt(2026, 1, 9, 11, 0, 0), Datetime.newInstanceGmt(2026, 1, 12, 11, 0, 0)
		};
		for(Datetime expectedFire : expected)
		{
			Datetime fire = UTIL_CronExpression.nextFireTime('0 0 6 ? * MON,WED,FRI', cursor, TIMEZONE_NYC);
			Assert.areEqual(expectedFire, fire, 'the named weekdays fire in calendar order');
			cursor = fire;
		}
	}

	/**
	 * @description A twenty-minute step under a single named hour gives three fires a day, at 09:00, 09:20 and 09:40
	 * local, and nothing at 10:00. In January in New York, five hours behind UTC, those are 14:00Z, 14:20Z and
	 * 14:40Z, and the next fire is 14:00Z the following day.
	 */
	@IsTest
	private static void aMinuteStepUnderOneNamedHourFiresThreeTimesADay()
	{
		Datetime cursor = localInstant(2026, 1, 1, TIMEZONE_NYC).addMinutes(-1);
		List<Datetime> expected = new List<Datetime>
		{
				Datetime.newInstanceGmt(2026, 1, 1, 14, 0, 0), Datetime.newInstanceGmt(2026, 1, 1, 14, 20, 0),
				Datetime.newInstanceGmt(2026, 1, 1, 14, 40, 0), Datetime.newInstanceGmt(2026, 1, 2, 14, 0, 0)
		};
		for(Datetime expectedFire : expected)
		{
			Datetime fire = UTIL_CronExpression.nextFireTime('0 */20 9 * * ?', cursor, TIMEZONE_NYC);
			Assert.areEqual(expectedFire, fire, 'the step stays inside the one hour the expression names');
			cursor = fire;
		}
	}

	/**
	 * @description The wall-clock rule must round a part-minute instant up, not down. In January in New York, five
	 * hours behind UTC, 08:59:30 local is 13:59:30Z and the 09:00 fire that follows it is 14:00Z the same day, while
	 * 09:00:30 local is 14:00:30Z, half a minute past the fire, so the next one is 14:00Z the following day.
	 */
	@IsTest
	private static void aPartMinuteInstantRoundsUpUnderTheWallClockRule()
	{
		Datetime justBeforeTheFire = Datetime.newInstanceGmt(2026, 1, 15, 13, 59, 30);
		Datetime justAfterTheFire = Datetime.newInstanceGmt(2026, 1, 15, 14, 0, 30);

		Datetime fireFromBefore = UTIL_CronExpression.nextFireTime('0 0 9 * * ?', justBeforeTheFire, TIMEZONE_NYC);
		Datetime fireFromAfter = UTIL_CronExpression.nextFireTime('0 0 9 * * ?', justAfterTheFire, TIMEZONE_NYC);

		Assert.areEqual(Datetime.newInstanceGmt(2026, 1, 15, 14, 0, 0), fireFromBefore, 'half a minute before the fire still catches it');
		Assert.areEqual(Datetime.newInstanceGmt(2026, 1, 16, 14, 0, 0), fireFromAfter, 'half a minute after the fire moves to the next day');
	}

	/**
	 * @description Proves a time zone the platform does not know is refused with the typed exception rather than read
	 * quietly as GMT, which would answer with the wrong hour.
	 */
	@IsTest
	private static void anUnknownTimeZoneKeyIsRejected()
	{
		try
		{
			UTIL_CronExpression.nextFireTime(NIGHTLY_AT_TWO, Datetime.newInstanceGmt(2026, 1, 1, 0, 0, 0), TIMEZONE_UNKNOWN);
			Assert.fail('an unrecognised time zone key must throw rather than read as GMT');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'an unrecognised time zone key is rejected with the typed exception');
			Assert.isTrue(error.getMessage().contains('could not be read'), 'the message is the label text: ' + error.getMessage());
		}
	}

	/**
	 * @description The named zones still resolve. Kolkata is five and a half hours ahead of UTC all year, so the next
	 * 02:00 local after 2026-06-15T00:00Z (which is already 05:30 local that day) is 02:00 on the 16th, that is
	 * 2026-06-16 02:00 minus 5 hours 30 minutes = 2026-06-15T20:30Z. UTC needs no shift at all.
	 */
	@IsTest
	private static void namedTimeZoneKeysStillResolve()
	{
		Datetime after = Datetime.newInstanceGmt(2026, 6, 15, 0, 0, 0);

		Datetime inKolkata = UTIL_CronExpression.nextFireTime(NIGHTLY_AT_TWO, after, TIMEZONE_IST);
		Datetime inUtc = UTIL_CronExpression.nextFireTime(NIGHTLY_AT_TWO, after, TIMEZONE_UTC);

		Assert.areEqual(Datetime.newInstanceGmt(2026, 6, 15, 20, 30, 0), inKolkata, 'Asia/Kolkata resolves and keeps its half hour');
		Assert.areEqual(Datetime.newInstanceGmt(2026, 6, 15, 2, 0, 0), inUtc, 'UTC resolves and needs no shift');
	}

	/**
	 * @description April 2027 has thirty days, so `31W` is capped to the 30th, which is a Friday (1 January 2027 is a
	 * Friday and 30 April is 119 days later, and 119 is a whole number of weeks). The platform was measured doing the
	 * same: see the note on nearestWeekdayTo.
	 */
	@IsTest
	private static void nearestWeekdayToADayTheMonthDoesNotHaveCapsToTheMonthEnd()
	{
		Datetime after = Datetime.newInstanceGmt(2027, 1, 1, 0, 0, 0);
		Datetime fire = UTIL_CronExpression.nextFireTime('0 0 6 31W 4 ? 2027', after, null);

		Assert.areEqual(Datetime.newInstanceGmt(2027, 4, 30, 6, 0, 0), fire, '31W in a thirty-day month fires on the last weekday of that month, as the platform does');
	}
}