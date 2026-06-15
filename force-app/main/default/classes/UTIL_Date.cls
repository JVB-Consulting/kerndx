// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Provides date and datetime helper operations such as business day arithmetic, weekday/weekend checks, ISO 8601 serialization, cron generation, and date formatting.
 *
 * @see UTIL_Date_TEST
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date February 2026, June 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * Date nextBusinessDay = UTIL_Date.addBusinessDays(Date.today(), 5);
 * Boolean weekend = UTIL_Date.isWeekend(Date.today());
 * String cron = UTIL_Date.getCronExpression(Datetime.now().addHours(1));
 * String iso = UTIL_Date.toIso8601(Date.today());
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier,PMD.CognitiveComplexity')
global inherited sharing class UTIL_Date
{
	/**
	 * @description Cron expression format template (`{seconds} {minutes} {hours} {day-of-month} {month} ? {year}`).
	 */
	@TestVisible
	private static final String CRON_FMT = '{0} {1} {2} {3} {4} ? {5}';

	/**
	 * @description Milliseconds in one hour, for duration arithmetic.
	 */
	private static final Long MILLISECONDS_PER_HOUR = 3600000;

	/**
	 * @description Milliseconds in one minute, for converting minute-based windows into epoch-time arithmetic.
	 */
	public static final Long MILLISECONDS_PER_MINUTE = 60000;

	/**
	 * @description Milliseconds in one second, for duration arithmetic.
	 */
	private static final Long MILLISECONDS_PER_SECOND = 1000;

	/**
	 * @description ISO 8601 separator marking the presence of a time component in a datetime string.
	 */
	private static final String DATETIME_CONTAINS_TIME = 'T';

	/**
	 * @description ISO 8601 date-only format pattern.
	 */
	private static final String ISO_DATE_PATTERN = 'yyyy-MM-dd';

	/**
	 * @description Compact GMT day-bucket format pattern (`yyyyMMdd`).
	 */
	private static final String DAY_BUCKET_PATTERN = 'yyyyMMdd';

	/**
	 * @description Saturday weekday abbreviation used by weekend detection.
	 */
	private static final String SAT_ABBREVIATION = 'Sat';

	/**
	 * @description Sunday weekday abbreviation used by weekend detection.
	 */
	private static final String SUN_ABBREVIATION = 'Sun';

	/**
	 * @description Date format pattern producing the three-letter weekday abbreviation (e.g. `Mon`).
	 */
	private static final String WEEKDAY_ABBREVIATION_FORMAT = 'E';

	/**
	 * @description Retrieves the Unix epoch as a `Datetime` value (1970-01-01 00:00:00 UTC).
	 *
	 * @return The epoch `Datetime` representing the start of Unix time.
	 *
	 * @example
	 * ```apex
	 * Datetime epoch = UTIL_Date.getEpochDateTime();
	 * ```
	 */
	public static Datetime getEpochDateTime()
	{
		return Datetime.newInstance(0);
	}

	/**
	 * @description Retrieves the Unix epoch as a `Date` value (1970-01-01).
	 *
	 * @return The epoch `Date` representing the start of Unix time.
	 *
	 * @example
	 * ```apex
	 * Date epoch = UTIL_Date.getEpochDate();
	 * ```
	 */
	public static Date getEpochDate()
	{
		return getEpochDateTime().date();
	}

	/**
	 * @description Serializes a `Datetime` into its ISO 8601 string representation, stripping surrounding quotes.
	 *
	 * @param inputDatetime The `Datetime` to serialize. When `null`, the epoch datetime is used.
	 *
	 * @return An ISO 8601 formatted string such as `2026-02-18T10:00:00.000Z`.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Datetime scheduled = Datetime.newInstance(2026, 3, 15, 9, 0, 0);
	 * String iso = UTIL_Date.toIso8601(scheduled);
	 * ```
	 */
	global static String toIso8601(Datetime inputDatetime)
	{
		Datetime valueToSerialize = inputDatetime != null ? inputDatetime : getEpochDateTime();
		String serialized = JSON.serialize(valueToSerialize);
		return UTIL_String.remove(serialized, UTIL_String.DOUBLE_QUOTE);
	}

	/**
	 * @description Serializes a `Date` into its ISO 8601 string representation (date portion only).
	 *
	 * @param inputDate The `Date` to serialize. When `null`, the epoch date is used.
	 *
	 * @return An ISO 8601 date string such as `2026-02-18`.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Date invoiceDate = Date.newInstance(2026, 6, 1);
	 * String iso = UTIL_Date.toIso8601(invoiceDate);
	 * ```
	 */
	global static String toIso8601(Date inputDate)
	{
		Date valueToFormat = inputDate != null ? inputDate : getEpochDate();
		return toDatetimeAtMidnight(valueToFormat).format(ISO_DATE_PATTERN);
	}

	/**
	 * @description Formats the GMT calendar date of the supplied timestamp as a compact
	 * `yyyyMMdd` bucket string, so day-boundary bucketing follows the UTC day regardless of
	 * the running user's timezone.
	 *
	 * @param inputDatetime The timestamp to bucket.
	 *
	 * @return The GMT day bucket (e.g. `20260607`), or `null` when input is `null`.
	 *
	 * @example
	 * ```apex
	 * String bucket = UTIL_Date.toUtcDayBucket(Datetime.now());
	 * ```
	 */
	public static String toUtcDayBucket(Datetime inputDatetime)
	{
		return inputDatetime?.formatGmt(DAY_BUCKET_PATTERN);
	}

	/**
	 * @description Parses an ISO 8601 string into a `Datetime` instance via JSON deserialization.
	 *
	 * @param isoText The ISO 8601 string to parse (e.g. `2026-02-18T14:30:00.000Z`).
	 *
	 * @return The parsed `Datetime`, or `null` when the input is blank.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Datetime parsed = UTIL_Date.dateTimeFromIso8601('2026-02-18T14:30:00.000Z');
	 * ```
	 */
	global static Datetime dateTimeFromIso8601(String isoText)
	{
		if(String.isBlank(isoText))
		{
			return null;
		}

		return (Datetime)JSON.deserialize(UTIL_String.DOUBLE_QUOTE + isoText + UTIL_String.DOUBLE_QUOTE, Datetime.class);
	}

	/**
	 * @description Parses an ISO 8601 string into a `Date` instance. When the string contains a time component, the local date is used; otherwise the GMT date is returned.
	 *
	 * @param isoText The ISO 8601 string to parse (e.g. `2026-02-18` or `2026-02-18T14:30:00.000Z`).
	 *
	 * @return The parsed `Date`, or `null` when the input is blank.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Date parsed = UTIL_Date.dateFromIso8601('2026-02-18');
	 * ```
	 */
	global static Date dateFromIso8601(String isoText)
	{
		if(String.isBlank(isoText))
		{
			return null;
		}

		Datetime parsed = dateTimeFromIso8601(isoText);
		Boolean includesTimeComponent = isoText.contains(DATETIME_CONTAINS_TIME);
		return includesTimeComponent ? parsed.date() : parsed.dateGmt();
	}

	/**
	 * @description Determines whether the supplied `Datetime` falls on a Saturday or Sunday.
	 *
	 * @param inputDatetime The `Datetime` to inspect.
	 *
	 * @return `true` when the day is Saturday or Sunday; `false` for Monday through Friday.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Datetime saturday = Datetime.newInstance(2026, 2, 21, 8, 0, 0);
	 * Boolean weekend = UTIL_Date.isWeekend(saturday);
	 * ```
	 */
	global static Boolean isWeekend(Datetime inputDatetime)
	{
		String dayAbbreviation = inputDatetime.format(WEEKDAY_ABBREVIATION_FORMAT);
		return dayAbbreviation == SAT_ABBREVIATION || dayAbbreviation == SUN_ABBREVIATION;
	}

	/**
	 * @description Determines whether the supplied `Date` falls on a Saturday or Sunday.
	 *
	 * @param inputDate The `Date` to inspect.
	 *
	 * @return `true` when the day is Saturday or Sunday; `false` for Monday through Friday.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Date sunday = Date.newInstance(2026, 2, 22);
	 * Boolean weekend = UTIL_Date.isWeekend(sunday);
	 * ```
	 */
	global static Boolean isWeekend(Date inputDate)
	{
		return isWeekend(toDatetimeAtMidnight(inputDate));
	}

	/**
	 * @description Determines whether the supplied `Datetime` falls on a weekday (Monday through Friday).
	 *
	 * @param inputDatetime The `Datetime` to inspect.
	 *
	 * @return `true` when the day is Monday through Friday; `false` for Saturday and Sunday.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Datetime tuesday = Datetime.newInstance(2026, 2, 17, 12, 0, 0);
	 * Boolean weekday = UTIL_Date.isWeekDay(tuesday);
	 * ```
	 */
	global static Boolean isWeekDay(Datetime inputDatetime)
	{
		return !isWeekend(inputDatetime);
	}

	/**
	 * @description Determines whether the supplied `Date` falls on a weekday (Monday through Friday).
	 *
	 * @param inputDate The `Date` to inspect.
	 *
	 * @return `true` when the day is Monday through Friday; `false` for Saturday and Sunday.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Date monday = Date.newInstance(2026, 2, 16);
	 * Boolean weekday = UTIL_Date.isWeekDay(monday);
	 * ```
	 */
	global static Boolean isWeekDay(Date inputDate)
	{
		return isWeekDay(toDatetimeAtMidnight(inputDate));
	}

	/**
	 * @description Advances or retreats a date by the given number of business days, skipping weekends. Negative values move the date backwards.
	 *
	 * @param origin The starting date.
	 * @param workingDaysToAdd The number of business days to add (positive) or subtract (negative).
	 *
	 * @return The resulting date after traversing the specified business days.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Date monday = Date.newInstance(2026, 2, 16);
	 * Date result = UTIL_Date.addBusinessDays(monday, 5);
	 * ```
	 */
	global static Date addBusinessDays(Date origin, Integer workingDaysToAdd)
	{
		Integer remaining = Math.abs(workingDaysToAdd);
		Integer step = workingDaysToAdd < 0 ? -1 : 1;
		Date cursor = origin;

		while(remaining > 0)
		{
			cursor = cursor.addDays(step);

			if(isWeekDay(cursor))
			{
				remaining--;
			}
		}

		return cursor;
	}

	/**
	 * @description Resolves the most recent weekday on or before the supplied date. If the date is already a weekday it is returned unchanged.
	 *
	 * @param referenceDate The date to evaluate.
	 *
	 * @return The same date when it is a weekday, or the preceding Friday when it is a weekend.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Date saturday = Date.newInstance(2026, 2, 21);
	 * Date friday = UTIL_Date.lastWeekDay(saturday);
	 * ```
	 */
	global static Date lastWeekDay(Date referenceDate)
	{
		Date candidate = referenceDate;

		while(isWeekend(candidate))
		{
			candidate = candidate.addDays(-1);
		}

		return candidate;
	}

	/**
	 * @description Resolves the most recent weekday on or before today.
	 *
	 * @return Today when it is a weekday, or the preceding Friday when today is a weekend.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Date recentWeekday = UTIL_Date.lastWeekDay();
	 * ```
	 */
	global static Date lastWeekDay()
	{
		return lastWeekDay(Date.today());
	}

	/**
	 * @description Resolves the next weekday on or after the supplied date. If the date is already a weekday it is returned unchanged.
	 *
	 * @param referenceDate The date to evaluate.
	 *
	 * @return The same date when it is a weekday, or the following Monday when it is a weekend.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Date sunday = Date.newInstance(2026, 2, 22);
	 * Date monday = UTIL_Date.firstWeekDay(sunday);
	 * ```
	 */
	global static Date firstWeekDay(Date referenceDate)
	{
		Date candidate = referenceDate;

		while(isWeekend(candidate))
		{
			candidate = candidate.addDays(1);
		}

		return candidate;
	}

	/**
	 * @description Builds a Salesforce-compatible cron expression from the supplied `Datetime` for use with `System.schedule`.
	 *
	 * @param scheduledTime The `Datetime` to convert into a cron string.
	 *
	 * @return A cron expression such as `0 30 14 18 2 ? 2026`, or `null` when the input is `null`.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Datetime runAt = Datetime.newInstance(2026, 3, 1, 6, 0, 0);
	 * String cron = UTIL_Date.getCronExpression(runAt);
	 * ```
	 */
	global static String getCronExpression(Datetime scheduledTime)
	{
		if(scheduledTime == null)
		{
			return null;
		}

		return String.format
				(
						CRON_FMT,
						new List<Object>
						{
								scheduledTime.second(),
								scheduledTime.minute(),
								scheduledTime.hour(),
								scheduledTime.day(),
								scheduledTime.month(),
								scheduledTime.year()
						}
				);
	}

	/**
	 * @description Formats a `Date` according to a Java SimpleDateFormat pattern string.
	 *
	 * @param inputDate The date to format.
	 * @param pattern The SimpleDateFormat pattern (e.g. `yyyy-MM-dd`, `dd/MM/yyyy`).
	 *
	 * @return The formatted date string, or `null` when the input date is `null`.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Date target = Date.newInstance(2026, 12, 25);
	 * String formatted = UTIL_Date.formatDate(target, 'dd MMMM yyyy');
	 * ```
	 */
	global static String formatDate(Date inputDate, String pattern)
	{
		if(inputDate == null)
		{
			return null;
		}

		return toDatetimeAtMidnight(inputDate).format(pattern);
	}

	/**
	 * @description Converts a `Date` to a `Datetime` set to midnight (00:00:00) on the same calendar day.
	 *
	 * @param inputDate The date to convert.
	 *
	 * @return A `Datetime` at midnight for the given date.
	 */
	private static Datetime toDatetimeAtMidnight(Date inputDate)
	{
		return Datetime.newInstance(inputDate.year(), inputDate.month(), inputDate.day());
	}

	/**
	 * @description Formats a duration in milliseconds to a human-readable string.
	 * Returns compact labels: "500ms", "2.1s", "1m 30s", "1h 5m".
	 *
	 * @param milliseconds The duration in milliseconds. Null returns null.
	 *
	 * @return Formatted duration string, or null if input is null.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String label = UTIL_Date.formatDuration(1500);   // "1.5s"
	 * String label = UTIL_Date.formatDuration(90000);  // "1m 30s"
	 * String label = UTIL_Date.formatDuration(500);    // "500ms"
	 * ```
	 */
	global static String formatDuration(Long milliseconds)
	{
		if(milliseconds == null)
		{
			return null;
		}

		if(milliseconds < MILLISECONDS_PER_SECOND)
		{
			return milliseconds + 'ms';
		}

		if(milliseconds < MILLISECONDS_PER_MINUTE)
		{
			Decimal seconds = Decimal.valueOf(milliseconds).divide(MILLISECONDS_PER_SECOND, 1);
			return seconds.stripTrailingZeros().toPlainString() + 's';
		}

		if(milliseconds < MILLISECONDS_PER_HOUR)
		{
			Long minutes = milliseconds / MILLISECONDS_PER_MINUTE;
			Long remainingSeconds = Math.mod(milliseconds, MILLISECONDS_PER_MINUTE) / MILLISECONDS_PER_SECOND;
			return remainingSeconds > 0 ? minutes + 'm ' + remainingSeconds + 's' : minutes + 'm';
		}

		Long hours = milliseconds / MILLISECONDS_PER_HOUR;
		Long remainingMinutes = Math.mod(milliseconds, MILLISECONDS_PER_HOUR) / MILLISECONDS_PER_MINUTE;
		return remainingMinutes > 0 ? hours + 'h ' + remainingMinutes + 'm' : hours + 'h';
	}
}