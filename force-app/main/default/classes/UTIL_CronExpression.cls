// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Utility for timezone-aware cron expression handling. Shifts cron expression hours
 * (and minutes for half-hour timezones) from one timezone to another so that System.schedule()
 * fires at the originally intended absolute time regardless of the running user's timezone.
 *
 * @see UTIL_CronExpression_TEST
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date March 2026, May 2026
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity')
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
	 * `Datetime` so tests can pin the offset calculation to a specific moment (e.g. an hour
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
	 * // cron — pin the test to this moment to assert the pre-fall-back behaviour.
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
	 * making the result DST-aware. Tests pin `reference` to exercise DST cross-over; production
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