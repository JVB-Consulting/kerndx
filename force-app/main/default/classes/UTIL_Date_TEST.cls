// SPDX-License-Identifier: Apache-2.0
/**
 * @description Validates the behavior of UTIL_Date utility operations including ISO 8601 conversions, weekend and weekday detection, business day arithmetic,
 * cron expression generation, and date formatting.
 *
 * @see UTIL_Date
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date February 2026, November 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=false)
private class UTIL_Date_TEST
{
	/**
	 * @description A time zone west of GMT, where the epoch moment falls on the last day of 1969.
	 */
	private static final String WESTERN_TIME_ZONE = 'America/Los_Angeles';

	/**
	 * @description The year of the epoch date.
	 */
	private static final Integer EPOCH_YEAR = 1970;

	/**
	 * @description The month of the epoch date.
	 */
	private static final Integer EPOCH_MONTH = 1;

	/**
	 * @description The day of the epoch date.
	 */
	private static final Integer EPOCH_DAY = 1;

	/**
	 * @description The epoch date written as ISO 8601 text.
	 */
	private static final String EPOCH_DATE_TEXT = '1970-01-01';

	/**
	 * @description Assertion text for mismatched datetime results.
	 */
	private static final String ASSERT_DATETIME_MATCH = 'Datetime result should match expected value';

	/**
	 * @description Assertion text for mismatched date results.
	 */
	private static final String ASSERT_DATE_MATCH = 'Date result should match expected value';

	/**
	 * @description Assertion text for incorrect cron output.
	 */
	private static final String ASSERT_CRON_MATCH = 'Cron expression should match expected output';

	/**
	 * @description Assertion text for incorrect formatted date string.
	 */
	private static final String ASSERT_FORMAT_MATCH = 'Formatted date string should match expected pattern';

	/**
	 * @description The hour of the sample time used by the tests that cut a time down to whole seconds.
	 */
	private static final Integer SAMPLE_HOUR = 9;

	/**
	 * @description The minute of the sample time used by the tests that cut a time down to whole seconds.
	 */
	private static final Integer SAMPLE_MINUTE = 30;

	/**
	 * @description The second of the sample time used by the tests that cut a time down to whole seconds.
	 */
	private static final Integer SAMPLE_SECOND = 45;

	/**
	 * @description The milliseconds added to the sample time, so there is something to cut away.
	 */
	private static final Integer SAMPLE_MILLISECOND = 789;

	/**
	 * @description The end of an ISO 8601 time that has zero milliseconds.
	 */
	private static final String ZERO_MILLISECONDS_ENDING = '.000Z';

	/**
	 * @description Builds the sample time for today in GMT, with the given milliseconds.
	 *
	 * @param millisecond The milliseconds of the sample time.
	 *
	 * @return The sample time.
	 */
	private static Datetime buildSampleTime(Integer millisecond)
	{
		return Datetime.newInstanceGmt(Date.today(), Time.newInstance(SAMPLE_HOUR, SAMPLE_MINUTE, SAMPLE_SECOND, millisecond));
	}

	/**
	 * @description A time with milliseconds comes back with zero milliseconds and the same seconds.
	 */
	@IsTest
	private static void shouldDropTheMillisecondsWhenTheTimeHasThem()
	{
		Datetime withMilliseconds = buildSampleTime(SAMPLE_MILLISECOND);

		Test.startTest();
		Datetime result = UTIL_Date.truncateToSeconds(withMilliseconds);
		Test.stopTest();

		Assert.areEqual(buildSampleTime(0).getTime(), result.getTime(), 'Expected the same moment with the milliseconds set to zero.');
		Assert.areEqual(withMilliseconds.secondGmt(), result.secondGmt(), 'Expected the seconds to stay the same.');
		Assert.isTrue(UTIL_Date.toIso8601(result).endsWith(ZERO_MILLISECONDS_ENDING), 'Expected the ISO 8601 text to end in zero milliseconds.');
	}

	/**
	 * @description A time already on a whole second comes back unchanged.
	 */
	@IsTest
	private static void shouldKeepATimeThatIsAlreadyOnAWholeSecond()
	{
		Datetime wholeSecond = buildSampleTime(0);

		Test.startTest();
		Datetime result = UTIL_Date.truncateToSeconds(wholeSecond);
		Test.stopTest();

		Assert.areEqual(wholeSecond.getTime(), result.getTime(), 'Expected a time on a whole second to come back unchanged.');
	}

	/**
	 * @description A null time gives null.
	 */
	@IsTest
	private static void shouldReturnNullWhenTheTimeIsNull()
	{
		Test.startTest();
		Datetime result = UTIL_Date.truncateToSeconds(null);
		Test.stopTest();

		Assert.isNull(result, 'Expected null when the time is null.');
	}

	/**
	 * @description Tests that a `Datetime` serializes to an ISO 8601 string correctly.
	 */
	@IsTest
	private static void shouldSerializeDatetimeToIso8601()
	{
		Datetime source = Datetime.now();
		String expected = source.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');

		Test.startTest();
		String actual = UTIL_Date.toIso8601(source);
		Test.stopTest();

		Assert.areEqual(expected, actual, 'ISO 8601 datetime string should reflect the source datetime');
	}

	/**
	 * @description Tests that a `Date` serializes to an ISO 8601 date-only string correctly.
	 */
	@IsTest
	private static void shouldSerializeDateToIso8601()
	{
		Date source = Date.today();
		Datetime sourceMidnight = Datetime.newInstance(source.year(), source.month(), source.day());
		String expected = sourceMidnight.format('yyyy-MM-dd');

		Test.startTest();
		String actual = UTIL_Date.toIso8601(source);
		Test.stopTest();

		Assert.areEqual(expected, actual, 'ISO 8601 date string should reflect the source date');
	}

	/**
	 * @description Tests that a null `Datetime` defaults to the epoch when serialized to ISO 8601.
	 */
	@IsTest
	private static void shouldDefaultToEpochWhenDatetimeIsNull()
	{
		Datetime nullDatetime = null;

		Test.startTest();
		String isoResult = UTIL_Date.toIso8601(nullDatetime);
		Test.stopTest();

		Datetime roundTripped = UTIL_Date.dateTimeFromIso8601(isoResult);
		Assert.areEqual(UTIL_Date.getEpochDateTime(), roundTripped, ASSERT_DATETIME_MATCH);
	}

	/**
	 * @description Tests that a null `Date` defaults to the epoch when serialized to ISO 8601.
	 */
	@IsTest
	private static void shouldDefaultToEpochWhenDateIsNull()
	{
		Date nullDate = null;

		Test.startTest();
		String isoResult = UTIL_Date.toIso8601(nullDate);
		Test.stopTest();

		Date roundTripped = UTIL_Date.dateFromIso8601(isoResult);
		Assert.areEqual(Date.newInstance(EPOCH_YEAR, EPOCH_MONTH, EPOCH_DAY), roundTripped, ASSERT_DATE_MATCH);
	}

	/**
	 * @description Tests that an ISO 8601 datetime string parses back to the original `Datetime`.
	 */
	@IsTest
	private static void shouldParseDatetimeFromIso8601()
	{
		Datetime original = Datetime.now();
		String serialized = UTIL_Date.toIso8601(original);

		Test.startTest();
		Datetime restored = UTIL_Date.dateTimeFromIso8601(serialized);
		Test.stopTest();

		Assert.areEqual(original, restored, ASSERT_DATETIME_MATCH);
	}

	/**
	 * @description Tests that an ISO 8601 datetime string parses to the correct `Date` portion.
	 */
	@IsTest
	private static void shouldParseDateFromIso8601WithTimePortion()
	{
		Datetime original = Datetime.now();
		Date expectedDate = original.date();
		String serialized = UTIL_Date.toIso8601(original);

		Test.startTest();
		Date restored = UTIL_Date.dateFromIso8601(serialized);
		Test.stopTest();

		Assert.areEqual(expectedDate, restored, ASSERT_DATE_MATCH);
	}

	/**
	 * @description Tests that a Saturday is correctly identified as a weekend day.
	 */
	@IsTest
	private static void shouldIdentifySaturdayAsWeekend()
	{
		Date saturday = Date.newInstance(2026, 2, 21);

		Test.startTest();
		Boolean result = UTIL_Date.isWeekend(saturday);
		Test.stopTest();

		Assert.isTrue(result, 'Saturday should be identified as a weekend');
	}

	/**
	 * @description Tests that a Wednesday is correctly identified as a weekday.
	 */
	@IsTest
	private static void shouldIdentifyWednesdayAsWeekday()
	{
		Date wednesday = Date.newInstance(2026, 2, 18);

		Test.startTest();
		Boolean result = UTIL_Date.isWeekDay(wednesday);
		Test.stopTest();

		Assert.isTrue(result, 'Wednesday should be identified as a weekday');
	}

	/**
	 * @description Tests that `lastWeekDay` without arguments returns a weekday on or before today.
	 */
	@IsTest
	private static void shouldReturnRecentWeekdayFromToday()
	{
		Test.startTest();
		Date recentWeekday = UTIL_Date.lastWeekDay();
		Test.stopTest();

		Assert.isTrue(UTIL_Date.isWeekDay(recentWeekday), 'Result of lastWeekDay should be a weekday');
	}

	/**
	 * @description Tests that adding business days correctly skips weekends.
	 */
	@IsTest
	private static void shouldAddBusinessDaysSkippingWeekends()
	{
		Date monday = Date.newInstance(2026, 2, 16);
		Integer daysToAdd = 7;
		Date expectedResult = Date.newInstance(2026, 2, 25);

		Test.startTest();
		Date actual = UTIL_Date.addBusinessDays(monday, daysToAdd);
		Test.stopTest();

		Assert.areEqual(expectedResult, actual, 'Adding 7 business days from Monday should skip one weekend');
	}

	/**
	 * @description Tests that `lastWeekDay` returns the preceding Friday when given a Saturday.
	 */
	@IsTest
	private static void shouldReturnFridayWhenLastWeekDayCalledOnSaturday()
	{
		Date saturday = Date.newInstance(2026, 3, 7);
		Date expectedFriday = Date.newInstance(2026, 3, 6);

		Test.startTest();
		Date actual = UTIL_Date.lastWeekDay(saturday);
		Test.stopTest();

		Assert.areEqual(expectedFriday, actual, 'Last weekday before Saturday should be Friday');
	}

	/**
	 * @description Tests that `lastWeekDay` returns the input date unchanged when it is already a weekday.
	 */
	@IsTest
	private static void shouldReturnSameDateWhenLastWeekDayCalledOnWeekday()
	{
		Date thursday = Date.newInstance(2026, 3, 5);

		Test.startTest();
		Date actual = UTIL_Date.lastWeekDay(thursday);
		Test.stopTest();

		Assert.areEqual(thursday, actual, 'Weekday input should be returned as-is');
	}

	/**
	 * @description Tests that `firstWeekDay` returns the following Monday when given a Sunday.
	 */
	@IsTest
	private static void shouldReturnMondayWhenFirstWeekDayCalledOnSunday()
	{
		Date sunday = Date.newInstance(2026, 3, 8);
		Date expectedMonday = Date.newInstance(2026, 3, 9);

		Test.startTest();
		Date actual = UTIL_Date.firstWeekDay(sunday);
		Test.stopTest();

		Assert.areEqual(expectedMonday, actual, 'First weekday after Sunday should be Monday');
	}

	/**
	 * @description Tests that `firstWeekDay` returns the input date unchanged when it is already a weekday.
	 */
	@IsTest
	private static void shouldReturnSameDateWhenFirstWeekDayCalledOnWeekday()
	{
		Date tuesday = Date.newInstance(2026, 3, 10);

		Test.startTest();
		Date actual = UTIL_Date.firstWeekDay(tuesday);
		Test.stopTest();

		Assert.areEqual(tuesday, actual, 'Weekday input should be returned as-is');
	}

	/**
	 * @description Tests that an ISO 8601 date string round-trips through serialization and parsing.
	 */
	@IsTest
	private static void shouldRoundTripDateThroughIso8601()
	{
		Date saturday = Date.newInstance(2026, 3, 7);

		Test.startTest();
		String isoText = UTIL_Date.toIso8601(saturday);
		Test.stopTest();

		Assert.areEqual('2026-03-07', isoText, 'ISO 8601 date string should match expected value');
	}

	/**
	 * @description Tests that epoch datetime and date accessors return the correct Unix epoch values.
	 */
	@IsTest
	private static void shouldReturnCorrectEpochValues()
	{
		Test.startTest();
		Datetime epochDatetime = UTIL_Date.getEpochDateTime();
		Date epochDate = UTIL_Date.getEpochDate();
		Test.stopTest();

		Assert.areEqual(Datetime.newInstance(0), epochDatetime, ASSERT_DATETIME_MATCH);
		Assert.areEqual(Date.newInstance(EPOCH_YEAR, EPOCH_MONTH, EPOCH_DAY), epochDate, ASSERT_DATE_MATCH);
	}

	/**
	 * @description Tests that the epoch date is 1970-01-01 for a user whose time zone is west of GMT, and that a null
	 * `Date` is written as that day.
	 */
	@IsTest
	private static void shouldReturnEpochDateForUserWestOfGmt()
	{
		User westernUser = TST_Factory.newUser(SEL_Profile.PROFILE_STANDARD_USER);
		westernUser.TimeZoneSidKey = WESTERN_TIME_ZONE;
		TST_Factory.insertUsers(new List<User> {westernUser});
		Date nullDate = null;

		Date epochDate;
		String isoText;
		System.runAs(westernUser)
		{
			Assert.areEqual(WESTERN_TIME_ZONE, UserInfo.getTimeZone().getID(), 'Expected the test to run in the western time zone');
			Test.startTest();
			epochDate = UTIL_Date.getEpochDate();
			isoText = UTIL_Date.toIso8601(nullDate);
			Test.stopTest();
		}

		Assert.areEqual(Date.newInstance(EPOCH_YEAR, EPOCH_MONTH, EPOCH_DAY), epochDate, 'Expected the epoch date to be 1970-01-01 west of GMT.');
		Assert.areEqual(EPOCH_DATE_TEXT, isoText, 'Expected a null date to be written as 1970-01-01 west of GMT.');
	}

	/**
	 * @description Tests that `getCronExpression` produces the expected cron string from a known datetime.
	 */
	@IsTest
	private static void shouldBuildCronExpressionFromDatetime()
	{
		Datetime epochDatetime = UTIL_Date.getEpochDateTime();

		Test.startTest();
		String cronResult = UTIL_Date.getCronExpression(epochDatetime);
		Test.stopTest();

		String expectedCron = String.format
				(
						UTIL_Date.CRON_FMT,
						new List<String>
						{
								String.valueOf(epochDatetime.second()),
								String.valueOf(epochDatetime.minute()),
								String.valueOf(epochDatetime.hour()),
								String.valueOf(epochDatetime.day()),
								String.valueOf(epochDatetime.month()),
								String.valueOf(epochDatetime.year())
						}
				);

		Assert.areEqual(expectedCron, cronResult, ASSERT_CRON_MATCH);
	}

	/**
	 * @description Tests that `formatDate` renders a date according to the supplied pattern.
	 */
	@IsTest
	private static void shouldFormatDateWithCustomPattern()
	{
		Date target = Date.newInstance(1985, 11, 21);
		String pattern = 'ddd yyyy MM';

		Test.startTest();
		String formatted = UTIL_Date.formatDate(target, pattern);
		Test.stopTest();

		Assert.areEqual('021 1985 11', formatted, ASSERT_FORMAT_MATCH);
	}

	/**
	 * @description Tests that `dateTimeFromIso8601` returns null when given a blank string.
	 */
	@IsTest
	private static void shouldReturnNullWhenParsingBlankDatetimeString()
	{
		Test.startTest();
		Datetime result = UTIL_Date.dateTimeFromIso8601('');
		Test.stopTest();

		Assert.isNull(result, 'Blank input should produce null Datetime');
	}

	/**
	 * @description Tests that `dateFromIso8601` returns null when given a blank string.
	 */
	@IsTest
	private static void shouldReturnNullWhenParsingBlankDateString()
	{
		Test.startTest();
		Date result = UTIL_Date.dateFromIso8601('');
		Test.stopTest();

		Assert.isNull(result, 'Blank input should produce null Date');
	}

	/**
	 * @description Tests that `getCronExpression` returns null when given a null datetime.
	 */
	@IsTest
	private static void shouldReturnNullCronWhenDatetimeIsNull()
	{
		Test.startTest();
		String result = UTIL_Date.getCronExpression(null);
		Test.stopTest();

		Assert.isNull(result, 'Null datetime should produce null cron expression');
	}

	/**
	 * @description Tests that `formatDate` returns null when given a null date.
	 */
	@IsTest
	private static void shouldReturnNullWhenFormattingNullDate()
	{
		Test.startTest();
		String result = UTIL_Date.formatDate(null, 'yyyy-MM-dd');
		Test.stopTest();

		Assert.isNull(result, 'Null date should produce null formatted string');
	}

	/**
	 * @description Verifies formatDuration returns null for null input.
	 */
	@IsTest
	private static void shouldReturnNullDurationForNullInput()
	{
		Assert.isNull(UTIL_Date.formatDuration(null), 'Null should return null');
	}

	/**
	 * @description Verifies formatDuration formats sub-second durations as milliseconds.
	 */
	@IsTest
	private static void shouldFormatSubSecondDurationsAsMilliseconds()
	{
		Assert.areEqual('0ms', UTIL_Date.formatDuration(0), 'Zero should format as 0ms');
		Assert.areEqual('500ms', UTIL_Date.formatDuration(500), 'Sub-second should use ms');
		Assert.areEqual('999ms', UTIL_Date.formatDuration(999), 'Just under 1s should still use ms');
	}

	/**
	 * @description Verifies formatDuration formats second-range durations with one decimal.
	 */
	@IsTest
	private static void shouldFormatSecondRangeDurationsWithDecimal()
	{
		Assert.areEqual('1s', UTIL_Date.formatDuration(1000), 'Whole seconds should not have decimal');
		Assert.areEqual('1.5s', UTIL_Date.formatDuration(1500), 'Half-seconds should show .5');
		Assert.areEqual('2.1s', UTIL_Date.formatDuration(2100), 'Should show one decimal');
		Assert.areEqual('59.9s', UTIL_Date.formatDuration(59900), 'Just under 1 minute');
	}

	/**
	 * @description Verifies formatDuration formats minute-range durations with optional seconds.
	 */
	@IsTest
	private static void shouldFormatMinuteRangeDurations()
	{
		Assert.areEqual('1m', UTIL_Date.formatDuration(60000), 'Even minutes should not show 0s');
		Assert.areEqual('1m 30s', UTIL_Date.formatDuration(90000), 'Minutes with seconds');
		Assert.areEqual('2m', UTIL_Date.formatDuration(120000), 'Even 2 minutes');
		Assert.areEqual('59m 59s', UTIL_Date.formatDuration(3599000), 'Just under 1 hour');
	}

	/**
	 * @description Verifies formatDuration formats hour-range durations with optional minutes.
	 */
	@IsTest
	private static void shouldFormatHourRangeDurations()
	{
		Assert.areEqual('1h', UTIL_Date.formatDuration(3600000), 'Even hours should not show 0m');
		Assert.areEqual('1h 5m', UTIL_Date.formatDuration(3900000), 'Hours with minutes');
		Assert.areEqual('24h', UTIL_Date.formatDuration(86400000), '24 hours');
	}

	/**
	 * @description Tests that toUtcDayBucket formats the GMT calendar date as yyyyMMdd,
	 * independent of the running user's timezone.
	 */
	@IsTest
	private static void shouldFormatUtcDayBucket()
	{
		Datetime gmtMidday = Datetime.newInstanceGmt(2026, 6, 7, 12, 0, 0);

		Assert.areEqual('20260607', UTIL_Date.toUtcDayBucket(gmtMidday), 'Bucket should be the GMT calendar date as yyyyMMdd');
	}

	/**
	 * @description Tests that toUtcDayBucket buckets by the GMT date even when the local
	 * date differs (a GMT timestamp just past midnight belongs to the GMT day).
	 */
	@IsTest
	private static void shouldBucketByGmtDateAcrossMidnight()
	{
		Datetime justPastGmtMidnight = Datetime.newInstanceGmt(2026, 6, 8, 0, 0, 1);

		Assert.areEqual('20260608', UTIL_Date.toUtcDayBucket(justPastGmtMidnight), 'Bucket must follow the GMT day boundary');
	}

	/**
	 * @description Tests that toUtcDayBucket returns null for null input rather than throwing.
	 */
	@IsTest
	private static void shouldReturnNullBucketForNullInput()
	{
		Assert.isNull(UTIL_Date.toUtcDayBucket(null), 'Null input should yield null, not an exception');
	}
}