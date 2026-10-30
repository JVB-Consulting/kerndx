// SPDX-License-Identifier: Apache-2.0
/**
 * @description Utility for timezone-aware cron expression handling. Shifts cron expression hours
 * (and minutes for half-hour timezones) from one timezone to another so that System.schedule()
 * fires at the originally intended absolute time regardless of the running user's timezone.
 * Also evaluates an expression in a time zone for the job runner: nextFireTime returns the next moment an expression fires.
 *
 * @see UTIL_CronExpression_TEST
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date March 2026, October 2026
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.ExcessiveClassLength,PMD.NcssTypeCount')
public inherited sharing class UTIL_CronExpression
{
	/**
	 * @description Wildcard character used in cron expressions.
	 */
	private static final String WILDCARD = '*';

	/**
	 * @description Question mark character used in cron day fields.
	 */
	private static final String QUESTION_MARK = '?';

	/**
	 * @description Number of hours in a day.
	 */
	private static final Integer HOURS_PER_DAY = 24;

	/**
	 * @description Number of minutes in an hour.
	 */
	private static final Integer MINUTES_PER_HOUR = 60;

	/**
	 * @description Number of milliseconds in a minute.
	 */
	private static final Integer MILLISECONDS_PER_MINUTE = 60000;

	/**
	 * @description Number of days in a week.
	 */
	private static final Integer DAYS_PER_WEEK = 7;

	/**
	 * @description Maps Salesforce cron day-of-week names to numeric values (1=SUN through 7=SAT).
	 */
	private static final Map<String, Integer> DAY_NAME_TO_NUMBER = new Map<String, Integer>
	{
			'SUN' => 1, 'MON' => 2, 'TUE' => 3, 'WED' => 4, 'THU' => 5, 'FRI' => 6, 'SAT' => 7
	};

	/**
	 * @description Maps numeric day-of-week values to Salesforce cron day names.
	 */
	private static final Map<Integer, String> DAY_NUMBER_TO_NAME = new Map<Integer, String>
	{
			1 => 'SUN', 2 => 'MON', 3 => 'TUE', 4 => 'WED', 5 => 'THU', 6 => 'FRI', 7 => 'SAT'
	};

	/**
	 * @description How far ahead nextFireTime looks for a fire, in days: 1,461 days is four years, which covers every
	 * leap-year and day-of-month combination the grammar can express. A fire exactly this many days out is still found.
	 * Beyond it the method returns null, meaning "this expression cannot fire within the horizon".
	 *
	 * @since 1.8
	 */
	public static final Integer SEARCH_HORIZON_DAYS = 1461;

	/**
	 * @description The time zone used when a record carries no time zone.
	 */
	private static final String UTC_TIMEZONE_SID_KEY = 'UTC';

	/**
	 * @description Milliseconds in a minute, as a Long for instant arithmetic.
	 */
	private static final Long MILLISECONDS_PER_MINUTE_LONG = 60000L;

	/**
	 * @description Milliseconds in twelve hours: the window either side of a wall-clock moment inside which a time-zone
	 * transition is looked for.
	 */
	private static final Long MILLISECONDS_PER_HALF_DAY = 43200000L;

	/**
	 * @description Milliseconds in a day, as a Long for the horizon arithmetic.
	 */
	private static final Long MILLISECONDS_PER_DAY = 86400000L;

	/**
	 * @description Cron day-of-week value for Sunday.
	 */
	private static final Integer CRON_SUNDAY = 1;

	/**
	 * @description Cron day-of-week value for Saturday.
	 */
	private static final Integer CRON_SATURDAY = 7;

	/**
	 * @description A Sunday, the anchor for turning a Date into a cron day-of-week value.
	 */
	private static final Date CRON_EPOCH_SUNDAY = Date.newInstance(1970, 1, 4);

	/**
	 * @description The letter that means "last": on its own in the day-of-month field it is the last day of the month,
	 * and as a suffix in the day-of-week field it is the last such weekday of the month, as in 6L for the last Friday.
	 * On its own in the day-of-week field it means Saturday, which is how the platform's own scheduler reads it.
	 */
	private static final String LAST_DAY_TOKEN = 'L';

	/**
	 * @description The shape of a number a cron field can carry: one to four ASCII digits. Four digits is the widest
	 * legal field, the year. A longer run of digits will not fit an Integer, and Apex counts digits from other scripts
	 * as numeric even though Integer.valueOf cannot read them, so a field is matched against this rather than tested
	 * with isNumeric.
	 */
	private static final String CRON_FIELD_DIGITS_PATTERN = '[0-9]{1,4}';

	/**
	 * @description The day-of-month token for the last weekday of the month.
	 */
	private static final String LAST_WEEKDAY_TOKEN = 'LW';

	/**
	 * @description The suffix that asks for the nearest weekday to a day of the month.
	 */
	private static final String WEEKDAY_SUFFIX = 'W';

	/**
	 * @description The separator of an nth-occurrence day-of-week token such as 2#5.
	 */
	private static final String OCCURRENCE_SEPARATOR = '#';

	/**
	 * @description Maps month names to numbers for the month field.
	 */
	private static final Map<String, Integer> MONTH_NAME_TO_NUMBER = new Map<String, Integer>
	{
			'JAN' => 1, 'FEB' => 2, 'MAR' => 3, 'APR' => 4, 'MAY' => 5, 'JUN' => 6,
			'JUL' => 7, 'AUG' => 8, 'SEP' => 9, 'OCT' => 10, 'NOV' => 11, 'DEC' => 12
	};

	/**
	 * @description Expressions parsed during this request, so a year-long walk parses its expression once.
	 */
	private static final Map<String, ParsedExpression> PARSED_EXPRESSIONS = new Map<String, ParsedExpression>();

	/**
	 * @description Shifts a cron expression from one timezone to another. Adjusts the hours field
	 * (and minutes for half-hour timezones like India UTC+5:30) so that the job fires at the same
	 * absolute time regardless of which user's timezone is active when System.schedule() runs.
	 *
	 * @param cronExpression The Salesforce cron expression (Seconds Minutes Hours DayOfMonth Month DayOfWeek [Year]).
	 * @param sourceTimezoneSidKey The IANA timezone ID of the user who authored the cron expression.
	 * @param targetTimezoneSidKey The IANA timezone ID of the user who will run System.schedule().
	 *
	 * @return The adjusted cron expression, or the original if no shift is needed.
	 *
	 * @example
	 * ```apex
	 * String shifted = UTIL_CronExpression.shiftTimezone('0 0 14 * * ?', 'Africa/Johannesburg', 'GMT');
	 * ```
	 */
	public static String shiftTimezone(String cronExpression, String sourceTimezoneSidKey, String targetTimezoneSidKey)
	{
		return shiftTimezone(cronExpression, sourceTimezoneSidKey, targetTimezoneSidKey, Datetime.now());
	}

	/**
	 * @description Reference-datetime overload of `shiftTimezone`. The default overload uses
	 * `Datetime.now()` to compute the source/target offsets, which means DST cross-over cannot
	 * be exercised in tests (the cron always shifts by the current offset, not the offset that
	 * would apply at the eventual fire time). This overload accepts an explicit reference
	 * `Datetime` so tests can fix the offset calculation at a specific moment (e.g. an hour
	 * before a DST jump) and assert the resulting cron behaves correctly across the boundary.
	 *
	 * @param cronExpression The Salesforce cron expression.
	 * @param sourceTimezoneSidKey The IANA timezone ID of the user who authored the cron expression.
	 * @param targetTimezoneSidKey The IANA timezone ID of the user who will run System.schedule().
	 * @param referenceDatetime The moment used to compute the offset between the two timezones.
	 *
	 * @return The adjusted cron expression, or the original if no shift is needed.
	 *
	 * @example
	 * ```apex
	 * // 2026-11-01 05:30 GMT is 30 minutes BEFORE DST ends in America/New_York
	 * // (NYC falls back from EDT to EST at 06:00 GMT / 02:00 local). At this instant
	 * // NYC is still in EDT (UTC-4), so the offset calculation produces an EDT-shaped
	 * // cron. Use this moment in a test to assert the behaviour before the clocks fall back.
	 * Datetime preDst = Datetime.newInstanceGmt(2026, 11, 1, 5, 30, 0);
	 * String shifted = UTIL_CronExpression.shiftTimezone('0 0 14 * * ?', 'America/New_York', 'GMT', preDst);
	 * ```
	 */
	public static String shiftTimezone(String cronExpression, String sourceTimezoneSidKey, String targetTimezoneSidKey, Datetime referenceDatetime)
	{
		if(String.isBlank(sourceTimezoneSidKey) || sourceTimezoneSidKey == targetTimezoneSidKey)
		{
			return cronExpression;
		}

		Integer offsetMinutes = calculateOffset(sourceTimezoneSidKey, targetTimezoneSidKey, referenceDatetime);

		if(offsetMinutes == 0)
		{
			return cronExpression;
		}

		List<String> parts = cronExpression.split(' ');
		Integer hourOffset = offsetMinutes / MINUTES_PER_HOUR;
		Integer minuteOffset = Math.mod(offsetMinutes, MINUTES_PER_HOUR);

		Integer hourCarry = 0;

		if(minuteOffset != 0)
		{
			ShiftResult minuteResult = shiftMinutes(parts[1], minuteOffset);
			parts[1] = minuteResult.value;
			hourCarry = minuteResult.carry;
		}

		ShiftResult hourResult = shiftHours(parts[2], hourOffset + hourCarry);
		parts[2] = hourResult.value;
		Integer dayOffset = hourResult.carry;

		if(dayOffset != 0)
		{
			if(parts[5] != QUESTION_MARK)
			{
				parts[5] = shiftDayOfWeek(parts[5], dayOffset);
			}

			if(parts[3] != QUESTION_MARK && parts[3] != WILDCARD)
			{
				parts[3] = shiftDayOfMonth(parts[3], dayOffset);
			}
		}

		return String.join(parts, ' ');
	}

	/**
	 * @description Returns the human-readable display name for a timezone.
	 *
	 * @param timezoneSidKey The IANA timezone ID (e.g., Africa/Johannesburg).
	 *
	 * @return The display name from TimeZone.getDisplayName(), or empty string when blank.
	 *
	 * @example
	 * ```apex
	 * String name = UTIL_CronExpression.getDisplayName('Africa/Johannesburg');
	 * ```
	 */
	public static String getDisplayName(String timezoneSidKey)
	{
		if(String.isBlank(timezoneSidKey))
		{
			return '';
		}

		return TimeZone.getTimeZone(timezoneSidKey).getDisplayName();
	}

	/**
	 * @description Calculates the offset in minutes between two timezones at a specific moment,
	 * making the result DST-aware. Tests set `reference` to exercise DST cross-over; production
	 * call sites pass `Datetime.now()` via the public single-arg overload.
	 *
	 * @param sourceId The source IANA timezone ID.
	 * @param targetId The target IANA timezone ID.
	 * @param reference The datetime at which the offset is computed.
	 *
	 * @return The offset in minutes (target - source). Positive means target is ahead.
	 */
	private static Integer calculateOffset(String sourceId, String targetId, Datetime reference)
	{
		Integer sourceOffsetMs = TimeZone.getTimeZone(sourceId).getOffset(reference);
		Integer targetOffsetMs = TimeZone.getTimeZone(targetId).getOffset(reference);
		return (targetOffsetMs - sourceOffsetMs) / MILLISECONDS_PER_MINUTE;
	}

	/**
	 * @description Shifts the minutes field of a cron expression by the given offset. Used for
	 * half-hour timezone offsets (e.g., India UTC+5:30). Wildcards and step values pass through unshifted.
	 *
	 * @param minutesField The cron minutes field value.
	 * @param minuteOffset The number of minutes to shift (can be negative).
	 *
	 * @return A ShiftResult with the adjusted minutes string and hour carry (0, +1, or -1).
	 */
	private static ShiftResult shiftMinutes(String minutesField, Integer minuteOffset)
	{
		ShiftResult result = new ShiftResult();
		result.carry = 0;

		if(minutesField == WILDCARD || minutesField.contains('/'))
		{
			result.value = minutesField;
			return result;
		}

		if(minutesField.contains(UTIL_String.COMMA))
		{
			List<String> values = minutesField.split(UTIL_String.COMMA);
			List<String> shifted = new List<String>();

			for(String value : values)
			{
				Integer minutes = Integer.valueOf(value.trim());
				Integer shiftedMinutes = minutes + minuteOffset;

				if(shifted.isEmpty())
				{
					result.carry = calculateMinuteCarry(shiftedMinutes);
				}

				shifted.add(String.valueOf(wrapMinute(shiftedMinutes)));
			}

			result.value = String.join(shifted, UTIL_String.COMMA);
			return result;
		}

		Integer minutes = Integer.valueOf(minutesField.trim());
		Integer shiftedMinutes = minutes + minuteOffset;
		result.carry = calculateMinuteCarry(shiftedMinutes);
		result.value = String.valueOf(wrapMinute(shiftedMinutes));
		return result;
	}

	/**
	 * @description Shifts the hours field of a cron expression by the given offset. Handles single values,
	 * comma lists, ranges, wildcards, and step expressions. Wildcards and steps pass through unshifted.
	 *
	 * @param hoursField The cron hours field value.
	 * @param hourOffset The number of hours to shift (can be negative).
	 *
	 * @return A ShiftResult with the adjusted hours string and day offset (0, +1, or -1).
	 */
	private static ShiftResult shiftHours(String hoursField, Integer hourOffset)
	{
		ShiftResult result = new ShiftResult();
		result.carry = 0;

		if(hoursField == WILDCARD || hoursField.contains('/'))
		{
			result.value = hoursField;
			return result;
		}

		if(hoursField.contains(UTIL_String.COMMA))
		{
			List<String> values = hoursField.split(UTIL_String.COMMA);
			List<String> shifted = new List<String>();

			for(String value : values)
			{
				Integer hour = Integer.valueOf(value.trim());
				Integer shiftedRaw = hour + hourOffset;
				shifted.add(String.valueOf(wrapHour(shiftedRaw)));

				if(shifted.size() == 1)
				{
					result.carry = calculateDayOffset(shiftedRaw);
				}
			}

			result.value = String.join(shifted, UTIL_String.COMMA);
			return result;
		}

		if(hoursField.contains('-'))
		{
			List<String> endpoints = hoursField.split('-');
			Integer startHour = Integer.valueOf(endpoints[0].trim());
			Integer endHour = Integer.valueOf(endpoints[1].trim());

			Integer shiftedStartRaw = startHour + hourOffset;
			Integer shiftedEndRaw = endHour + hourOffset;

			Integer wrappedStart = wrapHour(shiftedStartRaw);
			Integer wrappedEnd = wrapHour(shiftedEndRaw);

			result.carry = calculateDayOffset(shiftedStartRaw);

			if(wrappedStart <= wrappedEnd)
			{
				result.value = wrappedStart + '-' + wrappedEnd;
			}
			else
			{
				List<String> hours = new List<String>();

				for(Integer h = wrappedStart; h <= 23; h++)
				{
					hours.add(String.valueOf(h));
				}

				for(Integer h = 0; h <= wrappedEnd; h++)
				{
					hours.add(String.valueOf(h));
				}

				result.value = String.join(hours, UTIL_String.COMMA);
			}

			return result;
		}

		Integer hour = Integer.valueOf(hoursField.trim());
		Integer shiftedRaw = hour + hourOffset;
		result.value = String.valueOf(wrapHour(shiftedRaw));
		result.carry = calculateDayOffset(shiftedRaw);
		return result;
	}

	/**
	 * @description Shifts a day-of-week field by the given offset. Handles single values, comma lists,
	 * ranges, hash patterns (e.g., MON#2), and L suffix (e.g., FRIL).
	 *
	 * @param field The cron day-of-week field value.
	 * @param dayOffset The number of days to shift (+1 or -1).
	 *
	 * @return The adjusted day-of-week string.
	 */
	private static String shiftDayOfWeek(String field, Integer dayOffset)
	{
		if(field == WILDCARD || field == QUESTION_MARK)
		{
			return field;
		}

		if(field.contains(UTIL_String.COMMA))
		{
			List<String> values = field.split(UTIL_String.COMMA);
			List<String> shifted = new List<String>();

			for(String value : values)
			{
				shifted.add(shiftSingleDayOfWeek(value.trim(), dayOffset));
			}

			return String.join(shifted, UTIL_String.COMMA);
		}

		if(field.contains('-'))
		{
			List<String> endpoints = field.split('-');
			String shiftedStart = shiftSingleDayOfWeek(endpoints[0].trim(), dayOffset);
			String shiftedEnd = shiftSingleDayOfWeek(endpoints[1].trim(), dayOffset);
			return shiftedStart + '-' + shiftedEnd;
		}

		return shiftSingleDayOfWeek(field, dayOffset);
	}

	/**
	 * @description Shifts a single day-of-week token, handling hash and L patterns.
	 *
	 * @param dayValue The day token (e.g., MON, 2, MON#2, FRIL).
	 * @param dayOffset The number of days to shift.
	 *
	 * @return The shifted day token.
	 */
	private static String shiftSingleDayOfWeek(String dayValue, Integer dayOffset)
	{
		if(dayValue.contains('#'))
		{
			List<String> hashParts = dayValue.split('#');
			return shiftDayToken(hashParts[0], dayOffset) + '#' + hashParts[1];
		}

		if(dayValue.endsWith('L'))
		{
			String dayPart = dayValue.removeEnd('L');
			return shiftDayToken(dayPart, dayOffset) + 'L';
		}

		return shiftDayToken(dayValue, dayOffset);
	}

	/**
	 * @description Shifts a plain day-of-week token (name or number) by the given offset. Wraps around
	 * the 1-7 range (SUN-SAT).
	 *
	 * @param token The day name (e.g., MON) or number (e.g., 2).
	 * @param dayOffset The number of days to shift.
	 *
	 * @return The shifted day token in the same format (name or number) as the input.
	 */
	private static String shiftDayToken(String token, Integer dayOffset)
	{
		Boolean isName = DAY_NAME_TO_NUMBER.containsKey(token.toUpperCase());
		Integer dayNumber;

		if(isName)
		{
			dayNumber = DAY_NAME_TO_NUMBER.get(token.toUpperCase());
		}
		else
		{
			dayNumber = Integer.valueOf(token);
		}

		Integer shifted = wrapDayOfWeek(dayNumber + dayOffset);
		return isName ? DAY_NUMBER_TO_NAME.get(shifted) : String.valueOf(shifted);
	}

	/**
	 * @description Shifts a day-of-month field by the given offset. Returns the field unchanged when
	 * the shifted value would fall outside the valid 1-31 range (month boundaries cannot be reliably
	 * resolved without knowing the specific month). Values with L or W suffixes are also returned
	 * unchanged since "last day" and "nearest weekday" are relative expressions.
	 *
	 * @param field The cron day-of-month field value.
	 * @param dayOffset The number of days to shift (+1 or -1).
	 *
	 * @return The adjusted day-of-month string, or the original if shifting would produce an invalid value.
	 */
	private static String shiftDayOfMonth(String field, Integer dayOffset)
	{
		if(field.contains('L') || field.contains('W'))
		{
			return field;
		}

		if(field.contains(UTIL_String.COMMA))
		{
			List<String> values = field.split(UTIL_String.COMMA);
			List<String> shifted = new List<String>();

			for(String value : values)
			{
				Integer shiftedDay = Integer.valueOf(value.trim()) + dayOffset;

				if(!isDayOfMonthValid(shiftedDay))
				{
					return field;
				}

				shifted.add(String.valueOf(shiftedDay));
			}

			return String.join(shifted, UTIL_String.COMMA);
		}

		if(field.contains('-'))
		{
			List<String> endpoints = field.split('-');
			Integer shiftedStart = Integer.valueOf(endpoints[0].trim()) + dayOffset;
			Integer shiftedEnd = Integer.valueOf(endpoints[1].trim()) + dayOffset;

			if(!isDayOfMonthValid(shiftedStart) || !isDayOfMonthValid(shiftedEnd))
			{
				return field;
			}

			return shiftedStart + '-' + shiftedEnd;
		}

		Integer shiftedDay = Integer.valueOf(field.trim()) + dayOffset;

		if(!isDayOfMonthValid(shiftedDay))
		{
			return field;
		}

		return String.valueOf(shiftedDay);
	}

	/**
	 * @description Checks whether a day-of-month value falls within the valid cron range of 1-31.
	 *
	 * @param day The day-of-month value to validate.
	 *
	 * @return True if the value is between 1 and 31 inclusive.
	 */
	private static Boolean isDayOfMonthValid(Integer day)
	{
		return day >= 1 && day <= 31;
	}

	/**
	 * @description Wraps an hour value into the valid 0-23 range using modular arithmetic.
	 *
	 * @param hour The raw hour value (may be negative or >= 24).
	 *
	 * @return The wrapped hour value between 0 and 23.
	 */
	@TestVisible
	private static Integer wrapHour(Integer hour)
	{
		Integer result = Math.mod(hour, HOURS_PER_DAY);
		return result < 0 ? result + HOURS_PER_DAY : result;
	}

	/**
	 * @description Wraps a minute value into the valid 0-59 range using modular arithmetic.
	 *
	 * @param minute The raw minute value (may be negative or >= 60).
	 *
	 * @return The wrapped minute value between 0 and 59.
	 */
	private static Integer wrapMinute(Integer minute)
	{
		Integer result = Math.mod(minute, MINUTES_PER_HOUR);
		return result < 0 ? result + MINUTES_PER_HOUR : result;
	}

	/**
	 * @description Wraps a day-of-week value into the valid 1-7 range (Salesforce convention: 1=SUN through 7=SAT).
	 *
	 * @param day The raw day number (may be outside 1-7).
	 *
	 * @return The wrapped day number between 1 and 7.
	 */
	private static Integer wrapDayOfWeek(Integer day)
	{
		Integer result = Math.mod(day - 1, DAYS_PER_WEEK);
		return (result < 0 ? result + DAYS_PER_WEEK : result) + 1;
	}

	/**
	 * @description Calculates the day offset when a raw shifted hour value crosses midnight.
	 *
	 * @param shiftedRawHour The hour value before wrapping (may be negative or >= 24).
	 *
	 * @return -1 if the hour crossed midnight backward, +1 if forward, 0 otherwise.
	 */
	private static Integer calculateDayOffset(Integer shiftedRawHour)
	{
		if(shiftedRawHour < 0)
		{
			return -1;
		}

		if(shiftedRawHour >= HOURS_PER_DAY)
		{
			return 1;
		}

		return 0;
	}

	/**
	 * @description Calculates the hour carry when a raw shifted minute value crosses the hour boundary.
	 *
	 * @param shiftedRawMinute The minute value before wrapping (may be negative or >= 60).
	 *
	 * @return -1 if the minute crossed backward, +1 if forward, 0 otherwise.
	 */
	private static Integer calculateMinuteCarry(Integer shiftedRawMinute)
	{
		if(shiftedRawMinute < 0)
		{
			return -1;
		}

		if(shiftedRawMinute >= MINUTES_PER_HOUR)
		{
			return 1;
		}

		return 0;
	}

	/**
	 * @description Returns the next moment a cron expression fires, strictly after a given instant, as a UTC Datetime.
	 * The expression is read in the given time zone (blank means UTC). Two rules decide how daylight-saving changes are
	 * handled: when the hours field is `*` the expression is evaluated on instants, so an every-15-minutes job fires 92
	 * times on a 23-hour day and 100 times on a 25-hour day, never skipping or doubling; when the hours field names hours,
	 * the expression follows the local wall clock and fires once per matching local hour, so a time that falls into the
	 * spring-forward gap fires at the moment the clocks jump and a time that happens twice in the autumn fires at the
	 * earlier of the two. The search stops after SEARCH_HORIZON_DAYS and returns null when nothing fires inside it.
	 *
	 * @param cronExpression A Salesforce cron expression: seconds (must be 0), minutes, hours, day of month, month, day of week, optional year.
	 * @param after The instant the fire must come after. The current minute is never returned.
	 * @param timezoneSidKey The time zone the expression is read in, such as America/New_York; blank means UTC. A key
	 * the platform does not recognise is rejected rather than read as GMT.
	 *
	 * @return The next fire instant in UTC, or null when the expression cannot fire within the horizon.
	 *
	 * @throws IllegalArgumentException When the expression or the time zone cannot be read; the message names the token that failed.
	 *
	 * @since 1.8
	 *
	 * @example
	 * ```apex
	 * Datetime next = UTIL_CronExpression.nextFireTime('0 *\/15 * * * ?', Datetime.now(), 'America/New_York');
	 * ```
	 */
	public static Datetime nextFireTime(String cronExpression, Datetime after, String timezoneSidKey)
	{
		if(after == null)
		{
			throw new IllegalArgumentException(String.format(System.Label.ScheduledJob_CronExpressionInvalid, new List<Object> {'after'}));
		}
		ParsedExpression parsed = parse(cronExpression);
		String zoneKey = String.isBlank(timezoneSidKey) ? UTC_TIMEZONE_SID_KEY : timezoneSidKey;
		TimeZone zone = TimeZone.getTimeZone(zoneKey);
		if(zone.getID() != zoneKey)
		{
			throw unreadable(timezoneSidKey);
		}
		Long afterMilliseconds = after.getTime();
		Datetime start = Datetime.newInstance(afterMilliseconds - Math.mod(afterMilliseconds, MILLISECONDS_PER_MINUTE_LONG) + MILLISECONDS_PER_MINUTE_LONG);
		return parsed.hoursUnconstrained ? nextInstantFire(parsed, start, zone) : nextWallClockFire(parsed, start, zone);
	}

	/**
	 * @description Walks whole minutes from the start instant, matching the local minute and local date of each candidate,
	 * and jumping to the next local midnight when the date does not match. Used when the hours field is `*`.
	 *
	 * @param parsed The parsed expression.
	 * @param start The first candidate minute.
	 * @param zone The time zone the local fields are read in.
	 *
	 * @return The first matching instant, or null beyond the horizon.
	 */
	private static Datetime nextInstantFire(ParsedExpression parsed, Datetime start, TimeZone zone)
	{
		Long horizonEnd = start.getTime() + SEARCH_HORIZON_DAYS * MILLISECONDS_PER_DAY;
		Datetime candidate = start;
		while(candidate.getTime() <= horizonEnd)
		{
			LocalFields local = toLocal(candidate, zone);
			if(!parsed.matchesDate(local.day))
			{
				candidate = toInstant(local.day.addDays(1), 0, 0, zone);
				continue;
			}
			if(parsed.minuteSet.contains(local.minute))
			{
				return candidate;
			}
			candidate = candidate.addMinutes(1);
		}
		return null;
	}

	/**
	 * @description Walks local days from the start instant's local date, and for each matching date tries every matching
	 * hour and minute as a local wall-clock moment converted to an instant. Used when the hours field names hours. Every
	 * candidate is converted before it is judged, and only the instant decides: a wall-clock time that reads earlier than
	 * the start of the search can still convert to an instant at or after it, because a time inside a spring-forward gap
	 * converts to the moment the clocks jump. The horizon is measured in milliseconds from the start instant, exactly as
	 * the instant rule measures it, so a candidate that lands beyond it is passed over however few local days it sits away.
	 *
	 * @param parsed The parsed expression.
	 * @param start The first candidate minute.
	 * @param zone The time zone the wall clock is read in.
	 *
	 * @return The first matching instant, or null beyond the horizon.
	 */
	private static Datetime nextWallClockFire(ParsedExpression parsed, Datetime start, TimeZone zone)
	{
		LocalFields startLocal = toLocal(start, zone);
		Long horizonEnd = start.getTime() + SEARCH_HORIZON_DAYS * MILLISECONDS_PER_DAY;
		for(Integer dayOffset = 0; dayOffset <= SEARCH_HORIZON_DAYS; dayOffset++)
		{
			Date day = startLocal.day.addDays(dayOffset);
			if(!parsed.matchesDate(day))
			{
				continue;
			}
			for(Integer hour : parsed.hours)
			{
				for(Integer minute : parsed.minutes)
				{
					Datetime instant = toInstant(day, hour, minute, zone);
					if(instant.getTime() >= start.getTime() && instant.getTime() <= horizonEnd)
					{
						return instant;
					}
				}
			}
		}
		return null;
	}

	/**
	 * @description Reads the local date, hour and minute of an instant in a zone.
	 *
	 * @param instant The UTC instant.
	 * @param zone The time zone.
	 *
	 * @return The local fields.
	 */
	private static LocalFields toLocal(Datetime instant, TimeZone zone)
	{
		Datetime shifted = Datetime.newInstance(instant.getTime() + zone.getOffset(instant));
		LocalFields local = new LocalFields();
		local.day = Date.newInstance(shifted.yearGmt(), shifted.monthGmt(), shifted.dayGmt());
		local.hour = shifted.hourGmt();
		local.minute = shifted.minuteGmt();
		return local;
	}

	/**
	 * @description Converts a local wall-clock moment to an instant.
	 *
	 * It starts with a first guess at the instant: the wall clock read as if it were UTC, minus the zone's offset at
	 * that reading. The guess is never more than one clock change (an hour at most) away from the true instant, for
	 * every zone from twelve hours behind UTC to fourteen hours ahead, so sampling the offset twelve hours either side
	 * of the guess always lands at least ten hours clear of the nearest clock change. Sampling either side of the raw
	 * wall clock instead would read a zone twelve or more hours ahead of UTC on the wrong side of its own change.
	 *
	 * When the two samples agree there is no clock change nearby and the answer is the wall clock minus that offset.
	 * When they disagree both offsets are tried: when both round-trip (the autumn overlap, where the wall clock happens
	 * twice) the earlier instant wins; when neither does (the spring gap, where the wall clock does not happen at all)
	 * the moment the clocks jump is returned.
	 *
	 * @param day The local date.
	 * @param hour The local hour.
	 * @param minute The local minute.
	 * @param zone The time zone.
	 *
	 * @return The instant.
	 */
	private static Datetime toInstant(Date day, Integer hour, Integer minute, TimeZone zone)
	{
		Long wallMilliseconds = Datetime.newInstanceGmt(day, Time.newInstance(hour, minute, 0, 0)).getTime();
		Long guessMilliseconds = wallMilliseconds - zone.getOffset(Datetime.newInstance(wallMilliseconds));
		Integer offsetBefore = zone.getOffset(Datetime.newInstance(guessMilliseconds - MILLISECONDS_PER_HALF_DAY));
		Integer offsetAfter = zone.getOffset(Datetime.newInstance(guessMilliseconds + MILLISECONDS_PER_HALF_DAY));
		if(offsetBefore == offsetAfter)
		{
			return Datetime.newInstance(wallMilliseconds - offsetBefore);
		}
		Datetime withBefore = Datetime.newInstance(wallMilliseconds - offsetBefore);
		Datetime withAfter = Datetime.newInstance(wallMilliseconds - offsetAfter);
		Boolean beforeHolds = zone.getOffset(withBefore) == offsetBefore;
		Boolean afterHolds = zone.getOffset(withAfter) == offsetAfter;
		if(beforeHolds && afterHolds)
		{
			return withBefore.getTime() <= withAfter.getTime() ? withBefore : withAfter;
		}
		if(beforeHolds)
		{
			return withBefore;
		}
		if(afterHolds)
		{
			return withAfter;
		}
		return transitionBoundary(withAfter, withBefore, zone);
	}

	/**
	 * @description Finds, to the minute, the instant at which the zone's offset changes between two instants that sit on
	 * opposite sides of a transition.
	 *
	 * @param first One side of the transition.
	 * @param second The other side.
	 * @param zone The time zone.
	 *
	 * @return The first minute that carries the later side's offset.
	 */
	private static Datetime transitionBoundary(Datetime first, Datetime second, TimeZone zone)
	{
		Long low = Math.min(first.getTime(), second.getTime());
		Long high = Math.max(first.getTime(), second.getTime());
		Integer offsetAtHigh = zone.getOffset(Datetime.newInstance(high));
		while(high - low > MILLISECONDS_PER_MINUTE_LONG)
		{
			Long middle = low + (high - low) / 2;
			if(zone.getOffset(Datetime.newInstance(middle)) == offsetAtHigh)
			{
				high = middle;
			}
			else
			{
				low = middle;
			}
		}
		return Datetime.newInstance(high - Math.mod(high, MILLISECONDS_PER_MINUTE_LONG));
	}

	/**
	 * @description Parses an expression once per request. Seconds must be 0; exactly one of day of month and day of week
	 * must be `?`, as the platform requires; every other field follows the standard Salesforce grammar.
	 *
	 * @param cronExpression The expression text.
	 *
	 * @return The parsed expression.
	 *
	 * @throws IllegalArgumentException Naming the token that could not be read.
	 */
	private static ParsedExpression parse(String cronExpression)
	{
		String key = cronExpression == null ? UTIL_String.EMPTY : cronExpression.trim();
		ParsedExpression cached = PARSED_EXPRESSIONS.get(key);
		if(cached != null)
		{
			return cached;
		}
		List<String> parts = key.split('\\s+');
		if(String.isBlank(key) || parts.size() < 6 || parts.size() > 7)
		{
			throw unreadable(key);
		}
		if(parts[0] != '0')
		{
			throw unreadable(parts[0]);
		}
		ParsedExpression parsed = new ParsedExpression();
		parsed.minutes = parseNumberSet(parts[1], 0, 59, null);
		parsed.minuteSet = new Set<Integer>(parsed.minutes);
		parsed.hoursUnconstrained = parts[2] == WILDCARD;
		parsed.hours = parseNumberSet(parts[2], 0, 23, null);
		parsed.dayOfMonth = parseDayOfMonth(parts[3].toUpperCase());
		parsed.months = new Set<Integer>(parseNumberSet(parts[4].toUpperCase(), 1, 12, MONTH_NAME_TO_NUMBER));
		parsed.dayOfWeek = parseDayOfWeek(parts[5].toUpperCase());
		parsed.years = parts.size() == 7 ? new Set<Integer>(parseNumberSet(parts[6], 1970, 2099, null)) : null;
		if(parsed.dayOfMonth.isUnspecified == parsed.dayOfWeek.isUnspecified)
		{
			throw unreadable(parts[3] + ' ' + parts[5]);
		}
		PARSED_EXPRESSIONS.put(key, parsed);
		return parsed;
	}

	/**
	 * @description Builds the typed exception for a token that could not be read.
	 *
	 * @param token The offending token.
	 *
	 * @return The exception, ready to throw.
	 */
	private static IllegalArgumentException unreadable(String token)
	{
		return new IllegalArgumentException(String.format(System.Label.ScheduledJob_CronExpressionInvalid, new List<Object> {token}));
	}

	/**
	 * @description Reads a numeric cron field into a sorted list of values: `*`, single values, names, lists, ranges and
	 * steps (`*\/n`, `a/n`, `a-b/n`). A field that names no value at all, such as a lone comma, cannot be read: the
	 * walk would have nothing to match and would run to the end of the horizon a minute at a time, so it is rejected
	 * here instead.
	 *
	 * @param field The field text, upper-cased when names are allowed.
	 * @param minimum The smallest legal value.
	 * @param maximum The largest legal value.
	 * @param names Optional names for values (months, days of week), or null.
	 *
	 * @return The values in ascending order.
	 */
	private static List<Integer> parseNumberSet(String field, Integer minimum, Integer maximum, Map<String, Integer> names)
	{
		Set<Integer> values = new Set<Integer>();
		for(String token : field.split(UTIL_String.COMMA))
		{
			String rangePart = token;
			Integer step = 1;
			if(token.contains('/'))
			{
				List<String> stepParts = token.split('/');
				if(stepParts.size() != 2)
				{
					throw unreadable(token);
				}
				rangePart = stepParts[0];
				step = parseNumber(stepParts[1], 1, maximum - minimum + 1, null, token);
			}
			Integer rangeStart;
			Integer rangeEnd;
			if(rangePart == WILDCARD)
			{
				rangeStart = minimum;
				rangeEnd = maximum;
			}
			else if(rangePart.contains('-'))
			{
				List<String> ends = rangePart.split('-');
				if(ends.size() != 2)
				{
					throw unreadable(token);
				}
				rangeStart = parseNumber(ends[0], minimum, maximum, names, token);
				rangeEnd = parseNumber(ends[1], minimum, maximum, names, token);
				if(rangeEnd < rangeStart)
				{
					throw unreadable(token);
				}
			}
			else
			{
				rangeStart = parseNumber(rangePart, minimum, maximum, names, token);
				rangeEnd = token.contains('/') ? maximum : rangeStart;
			}
			for(Integer value = rangeStart; value <= rangeEnd; value += step)
			{
				values.add(value);
			}
		}
		if(values.isEmpty())
		{
			throw unreadable(field);
		}
		List<Integer> sorted = new List<Integer>(values);
		sorted.sort();
		return sorted;
	}

	/**
	 * @description Reads one number or name and checks its bounds. The number is matched against CRON_FIELD_DIGITS_PATTERN
	 * rather than tested with isNumeric, so that a token too long to fit an Integer, or written in digits from another
	 * script, is reported as unreadable in the ruled way instead of failing inside Integer.valueOf.
	 *
	 * @param token The number or name.
	 * @param minimum The smallest legal value.
	 * @param maximum The largest legal value.
	 * @param names Optional names for values, or null.
	 * @param context The enclosing token, named in the exception.
	 *
	 * @return The value.
	 */
	private static Integer parseNumber(String token, Integer minimum, Integer maximum, Map<String, Integer> names, String context)
	{
		Boolean isReadableNumber = Pattern.matches(CRON_FIELD_DIGITS_PATTERN, token);
		Integer value = names != null && names.containsKey(token) ? names.get(token) : (isReadableNumber ? Integer.valueOf(token) : null);
		if(value == null || value < minimum || value > maximum)
		{
			throw unreadable(context);
		}
		return value;
	}

	/**
	 * @description Reads the day-of-month field: `?`, `*`, `L`, `LW`, `nW`, or numbers with lists, ranges and steps.
	 *
	 * @param field The upper-cased field text.
	 *
	 * @return The day rule.
	 */
	private static DayRule parseDayOfMonth(String field)
	{
		DayRule rule = new DayRule();
		if(field == QUESTION_MARK)
		{
			rule.isUnspecified = true;
		}
		else if(field == WILDCARD)
		{
			rule.isWildcard = true;
		}
		else if(field == LAST_DAY_TOKEN)
		{
			rule.isLastDay = true;
		}
		else if(field == LAST_WEEKDAY_TOKEN)
		{
			rule.isLastWeekday = true;
		}
		else if(field.endsWith(WEEKDAY_SUFFIX))
		{
			rule.nearestWeekdayTo = parseNumber(field.removeEnd(WEEKDAY_SUFFIX), 1, 31, null, field);
		}
		else
		{
			rule.values = new Set<Integer>(parseNumberSet(field, 1, 31, null));
		}
		return rule;
	}

	/**
	 * @description Reads the day-of-week field: `?`, `*`, `L` on its own (Saturday, the meaning the platform's own
	 * scheduler gives it), `nL` (the last n-day of the month), `n#m` (the m-th n-day), or numbers and names with lists,
	 * ranges and steps.
	 *
	 * @param field The upper-cased field text.
	 *
	 * @return The day rule.
	 */
	private static DayRule parseDayOfWeek(String field)
	{
		DayRule rule = new DayRule();
		if(field == QUESTION_MARK)
		{
			rule.isUnspecified = true;
		}
		else if(field == WILDCARD)
		{
			rule.isWildcard = true;
		}
		else if(field.contains(OCCURRENCE_SEPARATOR))
		{
			List<String> occurrenceParts = field.split(OCCURRENCE_SEPARATOR);
			if(occurrenceParts.size() != 2)
			{
				throw unreadable(field);
			}
			rule.nthDay = parseNumber(occurrenceParts[0], CRON_SUNDAY, CRON_SATURDAY, DAY_NAME_TO_NUMBER, field);
			rule.nthOccurrence = parseNumber(occurrenceParts[1], 1, 5, null, field);
		}
		else if(field == LAST_DAY_TOKEN)
		{
			rule.values = new Set<Integer> {CRON_SATURDAY};
		}
		else if(field.endsWith(LAST_DAY_TOKEN))
		{
			rule.lastOfMonthDay = parseNumber(field.removeEnd(LAST_DAY_TOKEN), CRON_SUNDAY, CRON_SATURDAY, DAY_NAME_TO_NUMBER, field);
		}
		else
		{
			rule.values = new Set<Integer>(parseNumberSet(field, CRON_SUNDAY, CRON_SATURDAY, DAY_NAME_TO_NUMBER));
		}
		return rule;
	}

	/**
	 * @description The cron day-of-week value of a date: 1 for Sunday through 7 for Saturday.
	 *
	 * @param day The date.
	 *
	 * @return The cron day-of-week value.
	 */
	private static Integer cronDayOfWeek(Date day)
	{
		return Math.mod(CRON_EPOCH_SUNDAY.daysBetween(day), DAYS_PER_WEEK) + 1;
	}

	/**
	 * @description Whether a date is a Saturday or a Sunday.
	 *
	 * @param day The date.
	 *
	 * @return True on a weekend day.
	 */
	private static Boolean isWeekend(Date day)
	{
		Integer cronDay = cronDayOfWeek(day);
		return cronDay == CRON_SUNDAY || cronDay == CRON_SATURDAY;
	}

	/**
	 * @description The last weekday (Monday to Friday) of a month.
	 *
	 * @param year The year.
	 * @param month The month.
	 *
	 * @return The date.
	 */
	private static Date lastWeekdayOf(Integer year, Integer month)
	{
		Date candidate = Date.newInstance(year, month, Date.daysInMonth(year, month));
		while(isWeekend(candidate))
		{
			candidate = candidate.addDays(-1);
		}
		return candidate;
	}

	/**
	 * @description The weekday nearest to a day of the month, staying inside the month: a Saturday moves to the Friday
	 * before unless that leaves the month, a Sunday to the Monday after unless that leaves the month.
	 *
	 * A day the month does not have is capped to the month's last day before this is called, which is what the platform
	 * itself does. Measured on 2026-09-12 by scheduling the expressions against a development org and reading the
	 * resulting CronTrigger: `0 0 6 31W 4 ? 2027` was accepted and its next fire time was 06:00 on Friday 30 April
	 * 2027, the same answer as `0 0 6 30W 4 ? 2027`, while plain `0 0 6 31 4 ? 2027` was refused outright with
	 * "Based on configured schedule, the given trigger will never fire". So `31W` caps in a 30-day month, and a plain
	 * `31` skips it.
	 *
	 * @param year The year.
	 * @param month The month.
	 * @param dayNumber The day the schedule names, already capped to the month's length.
	 *
	 * @return The date.
	 */
	private static Date nearestWeekdayTo(Integer year, Integer month, Integer dayNumber)
	{
		Date target = Date.newInstance(year, month, dayNumber);
		if(!isWeekend(target))
		{
			return target;
		}
		Boolean isSaturday = cronDayOfWeek(target) == CRON_SATURDAY;
		Date shifted = isSaturday ? target.addDays(-1) : target.addDays(1);
		if(shifted.month() != month)
		{
			shifted = isSaturday ? target.addDays(2) : target.addDays(-2);
		}
		return shifted;
	}

	/**
	 * @description The local date, hour and minute of an instant in a zone.
	 */
	private class LocalFields
	{
		/**
		 * @description The calendar date in the zone. Near midnight it can differ from the UTC date of the same instant.
		 */
		Date day;

		/**
		 * @description The local hour, 0 to 23.
		 */
		Integer hour;

		/**
		 * @description The local minute, 0 to 59.
		 */
		Integer minute;
	}

	/**
	 * @description A parsed cron expression: the minute and hour values, the month and optional year values, and the two
	 * day rules.
	 */
	private class ParsedExpression
	{
		/**
		 * @description The minute values in ascending order.
		 */
		List<Integer> minutes;

		/**
		 * @description The minute values as a set, for the instant rule's membership test.
		 */
		Set<Integer> minuteSet;

		/**
		 * @description The hour values in ascending order; every hour when the field is `*`.
		 */
		List<Integer> hours;

		/**
		 * @description True when the hours field is `*`, which selects the instant rule.
		 */
		Boolean hoursUnconstrained = false;

		/**
		 * @description The months the expression allows, from 1 (January) to 12 (December). Month names such as JAN are
		 * stored as their numbers.
		 */
		Set<Integer> months;

		/**
		 * @description The year values, or null when the expression has no year field.
		 */
		Set<Integer> years;

		/**
		 * @description The rule read from the fourth field, the day of the month. Exactly one of the two day rules is `?`:
		 * the parser refuses an expression where both are `?` or neither is.
		 */
		DayRule dayOfMonth;

		/**
		 * @description The rule read from the sixth field, the day of the week, where 1 is Sunday and 7 is Saturday. A date
		 * must match both day rules; the one that is `?` matches every date.
		 */
		DayRule dayOfWeek;

		/**
		 * @description Whether a local date satisfies the year, month, day-of-month and day-of-week fields.
		 *
		 * @param day The local date.
		 *
		 * @return True when the date matches.
		 */
		Boolean matchesDate(Date day)
		{
			if(years != null && !years.contains(day.year()))
			{
				return false;
			}
			if(!months.contains(day.month()))
			{
				return false;
			}
			return dayOfMonth.matchesDayOfMonth(day) && dayOfWeek.matchesDayOfWeek(day);
		}
	}

	/**
	 * @description One of the two day fields: either unspecified (`?`), any day (`*`), a rule token, or a set of values.
	 */
	private class DayRule
	{
		/**
		 * @description True for `?`: this field places no constraint.
		 */
		Boolean isUnspecified = false;

		/**
		 * @description True for `*`.
		 */
		Boolean isWildcard = false;

		/**
		 * @description True for `L` in the day-of-month field.
		 */
		Boolean isLastDay = false;

		/**
		 * @description True for `LW` in the day-of-month field.
		 */
		Boolean isLastWeekday = false;

		/**
		 * @description The day named by `nW` in the day-of-month field, or null.
		 */
		Integer nearestWeekdayTo;

		/**
		 * @description The day named by `nL` in the day-of-week field, or null.
		 */
		Integer lastOfMonthDay;

		/**
		 * @description The day named by `n#m` in the day-of-week field, or null.
		 */
		Integer nthDay;

		/**
		 * @description The occurrence named by `n#m` in the day-of-week field, or null.
		 */
		Integer nthOccurrence;

		/**
		 * @description The plain values, when the field is a number, name, list, range or step.
		 */
		Set<Integer> values;

		/**
		 * @description Whether a date satisfies this rule read as a day-of-month field.
		 *
		 * @param day The local date.
		 *
		 * @return True when the date matches.
		 */
		Boolean matchesDayOfMonth(Date day)
		{
			if(isUnspecified || isWildcard)
			{
				return true;
			}
			Integer daysInMonth = Date.daysInMonth(day.year(), day.month());
			if(isLastDay)
			{
				return day.day() == daysInMonth;
			}
			if(isLastWeekday)
			{
				return day == lastWeekdayOf(day.year(), day.month());
			}
			if(nearestWeekdayTo != null)
			{
				return day == nearestWeekdayTo(day.year(), day.month(), Math.min(nearestWeekdayTo, daysInMonth));
			}
			return values.contains(day.day());
		}

		/**
		 * @description Whether a date satisfies this rule read as a day-of-week field.
		 *
		 * @param day The local date.
		 *
		 * @return True when the date matches.
		 */
		Boolean matchesDayOfWeek(Date day)
		{
			if(isUnspecified || isWildcard)
			{
				return true;
			}
			Integer cronDay = cronDayOfWeek(day);
			if(lastOfMonthDay != null)
			{
				return cronDay == lastOfMonthDay && day.day() + DAYS_PER_WEEK > Date.daysInMonth(day.year(), day.month());
			}
			if(nthDay != null)
			{
				return cronDay == nthDay && ((day.day() - 1) / DAYS_PER_WEEK) + 1 == nthOccurrence;
			}
			return values.contains(cronDay);
		}
	}

	/**
	 * @description Holds the result of shifting a cron field, including the shifted value and any
	 * carry to the next higher field (minutes carry to hours, hours carry to days).
	 */
	private class ShiftResult
	{
		/**
		 * @description The shifted field value.
		 */
		String value;

		/**
		 * @description The carry to the next higher field (0, +1, or -1).
		 */
		Integer carry;
	}
}