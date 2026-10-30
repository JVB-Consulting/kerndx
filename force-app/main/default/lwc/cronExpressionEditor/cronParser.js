// SPDX-License-Identifier: Apache-2.0
/**
 * @description Pure functions for parsing, building, and describing Salesforce cron expressions.
 *              Supports the 7-field Salesforce format: Seconds Minutes Hours DayOfMonth Month DayOfWeek [Year]
 *
 * @date March 2026, October 2026
 */
import {
	MODE_PRESET, MODE_ADVANCED, MODE_CUSTOM, DEFAULT_CRON_EXPRESSION, NUMBER_TO_DAY_NAME
} from './constants';
import {formatTemplateString} from 'c/utilityString';
import DAY_SUNDAY from '@salesforce/label/c.CronExpressionEditor_DaySunday';
import DAY_MONDAY from '@salesforce/label/c.CronExpressionEditor_DayMonday';
import DAY_TUESDAY from '@salesforce/label/c.CronExpressionEditor_DayTuesday';
import DAY_WEDNESDAY from '@salesforce/label/c.CronExpressionEditor_DayWednesday';
import DAY_THURSDAY from '@salesforce/label/c.CronExpressionEditor_DayThursday';
import DAY_FRIDAY from '@salesforce/label/c.CronExpressionEditor_DayFriday';
import DAY_SATURDAY from '@salesforce/label/c.CronExpressionEditor_DaySaturday';
import ORDINAL_FIRST from '@salesforce/label/c.CronExpressionEditor_OrdinalFirst';
import ORDINAL_SECOND from '@salesforce/label/c.CronExpressionEditor_OrdinalSecond';
import ORDINAL_THIRD from '@salesforce/label/c.CronExpressionEditor_OrdinalThird';
import ORDINAL_FOURTH from '@salesforce/label/c.CronExpressionEditor_OrdinalFourth';
import ORDINAL_FIFTH from '@salesforce/label/c.CronExpressionEditor_OrdinalFifth';
import DAY_LIST_TWO from '@salesforce/label/c.CronExpressionEditor_DayListTwo';
import DAY_LIST_CONJUNCTION from '@salesforce/label/c.CronExpressionEditor_DayListConjunction';
import DESC_EVERY_N_MINUTES from '@salesforce/label/c.CronExpressionEditor_DescEveryNMinutes';
import DESC_EVERY_N_MINUTES_ON_RUNNER from '@salesforce/label/c.CronExpressionEditor_DescEveryNMinutesOnRunner';
import DESC_FIRST_CHECK_ON_OR_AFTER from '@salesforce/label/c.CronExpressionEditor_DescFirstCheckOnOrAfter';
import DESC_HOURLY from '@salesforce/label/c.CronExpressionEditor_DescHourly';
import DESC_MINUTE_OF_EVERY_HOUR from '@salesforce/label/c.CronExpressionEditor_DescMinuteOfEveryHour';
import DESC_MINUTE_INTERVALS from '@salesforce/label/c.CronExpressionEditor_DescMinuteIntervals';
import DESC_MINUTE_INTERVALS_FROM_TO from '@salesforce/label/c.CronExpressionEditor_DescMinuteIntervalsFromTo';
import DESC_DAILY from '@salesforce/label/c.CronExpressionEditor_DescDaily';
import DESC_DAILY_IN_MONTH from '@salesforce/label/c.CronExpressionEditor_DescDailyInMonth';
import DESC_NTH_WEEKDAY from '@salesforce/label/c.CronExpressionEditor_DescNthWeekday';
import DESC_LAST_WEEKDAY from '@salesforce/label/c.CronExpressionEditor_DescLastWeekday';
import DESC_WEEKDAYS from '@salesforce/label/c.CronExpressionEditor_DescWeekdays';
import DESC_DAY_RANGE from '@salesforce/label/c.CronExpressionEditor_DescDayRange';
import DESC_DAY_LIST from '@salesforce/label/c.CronExpressionEditor_DescDayList';
import DESC_LAST_DAY from '@salesforce/label/c.CronExpressionEditor_DescLastDay';
import DESC_LAST_WEEKDAY_OF_MONTH from '@salesforce/label/c.CronExpressionEditor_DescLastWeekdayOfMonth';
import DESC_IN_MONTH_SUFFIX from '@salesforce/label/c.CronExpressionEditor_DescInMonthSuffix';
import DESC_IN_YEAR_SUFFIX from '@salesforce/label/c.CronExpressionEditor_DescInYearSuffix';
import DESC_NEAREST_WEEKDAY from '@salesforce/label/c.CronExpressionEditor_DescNearestWeekday';
import DESC_MONTHLY_ON_DAY from '@salesforce/label/c.CronExpressionEditor_DescMonthlyOnDay';
import VAL_SECONDS from '@salesforce/label/c.CronExpressionEditor_ValSeconds';
import VAL_MINUTES from '@salesforce/label/c.CronExpressionEditor_ValMinutes';
import VAL_MINUTES_JOB_RUNNER from '@salesforce/label/c.CronExpressionEditor_ValMinutesJobRunner';
import VAL_HOURS from '@salesforce/label/c.CronExpressionEditor_ValHours';
import VAL_DAY_OF_MONTH from '@salesforce/label/c.CronExpressionEditor_ValDayOfMonth';
import VAL_MONTH from '@salesforce/label/c.CronExpressionEditor_ValMonth';
import VAL_DAY_OF_WEEK from '@salesforce/label/c.CronExpressionEditor_ValDayOfWeek';
import VAL_YEAR from '@salesforce/label/c.CronExpressionEditor_ValYear';
import VAL_YEAR_IN_PAST from '@salesforce/label/c.CronExpressionEditor_ValYearInPast';
import VAL_OUT_OF_RANGE from '@salesforce/label/c.CronExpressionEditor_ValOutOfRange';
import VAL_HASH_DAY from '@salesforce/label/c.CronExpressionEditor_ValHashDay';
import VAL_HASH_OCCURRENCE from '@salesforce/label/c.CronExpressionEditor_ValHashOccurrence';
import VAL_STEP_MIN from '@salesforce/label/c.CronExpressionEditor_ValStepMin';
import VAL_STEP_MAX from '@salesforce/label/c.CronExpressionEditor_ValStepMax';
import VAL_BASE_OUT_OF_RANGE from '@salesforce/label/c.CronExpressionEditor_ValBaseOutOfRange';
import VAL_RANGE_REVERSED from '@salesforce/label/c.CronExpressionEditor_ValRangeReversed';
import VAL_DAY_NOT_IN_MONTH from '@salesforce/label/c.CronExpressionEditor_ValDayNotInMonth';
import VAL_BOTH_QUESTION from '@salesforce/label/c.CronExpressionEditor_ValBothQuestion';
import VAL_NEITHER_QUESTION from '@salesforce/label/c.CronExpressionEditor_ValNeitherQuestion';
import VAL_STRUCTURE from '@salesforce/label/c.CronExpressionEditor_ValStructure';

/**
 * @description How the editor reads an expression when the caller says nothing: its own mode, where a
 *              scheduled job runs at most once an hour and no job runner is checking for due jobs, and a year that
 *              has already passed is refused.
 */
const OWN_MODE_OPTIONS = Object.freeze({jobRunnerMode: false, activeCheckIntervalMinutes: null, ignorePastYear: false});

/** @description Hours on a 12-hour clock: the hour number that starts the PM half of the day, and the label of hour zero. */
const HOURS_ON_TWELVE_HOUR_CLOCK = 12;

/** @description The last minute of an hour, used to find the last run of a minute interval. */
const LAST_MINUTE_OF_HOUR = 59;

/**
 * @description Fills in the reading options a caller left out, so every function below can read them plainly.
 * @param {Object} [options] - Caller options: jobRunnerMode, activeCheckIntervalMinutes, ignorePastYear
 * @returns {Object} The options with every value filled in
 */
function resolveOptions(options)
{
	return {...OWN_MODE_OPTIONS, ...(options || {})};
}

const VALID_MINUTE_INTERVALS = [
	'5',
	'10',
	'15',
	'30'
];

const DAY_NAMES_ORDERED = [
	'SUN',
	'MON',
	'TUE',
	'WED',
	'THU',
	'FRI',
	'SAT'
];

const DAY_FULL_NAMES = {
	'SUN': DAY_SUNDAY, 'MON': DAY_MONDAY, 'TUE': DAY_TUESDAY, 'WED': DAY_WEDNESDAY, 'THU': DAY_THURSDAY, 'FRI': DAY_FRIDAY, 'SAT': DAY_SATURDAY
};

const ORDINAL_NAMES = {
	'1': ORDINAL_FIRST, '2': ORDINAL_SECOND, '3': ORDINAL_THIRD, '4': ORDINAL_FOURTH, '5': ORDINAL_FIFTH
};

/**
 * @description Checks if a field value is a wildcard (covers both day and standard fields).
 */
function isWildcard(value)
{
	return value === '*' || value === '?';
}

/**
 * @description Normalises a day-of-week token from numeric (1-7) to name (SUN-SAT).
 */
function normaliseDayToken(token)
{
	return NUMBER_TO_DAY_NAME[token] || token;
}

/**
 * @description Normalises a day-of-week value to upper-case day names. The value is split at each comma first and
 *              then at each hyphen, so a list that holds a range, such as 2-4,6, becomes MON-WED,FRI.
 */
function normaliseDayOfWeek(value)
{
	if(isWildcard(value))
	{
		return value;
	}

	return value.toUpperCase().split(',').map((token) => token.split('-').map(normaliseDayToken).join('-')).join(',');
}

/**
 * @description Checks if a string is a single integer (no commas, ranges, or special chars).
 */
function isSingleNumber(value)
{
	return /^\d+$/.test(value);
}

/**
 * @description Splits a cron expression string into its constituent parts after trimming whitespace.
 *              Returns null if the expression is empty or has an invalid number of fields.
 * @param {string} expression - The raw cron expression string
 * @returns {Array|null} Array of cron field strings, or null if invalid structure
 */
export function splitCronExpression(expression)
{
	const trimmed = expression.trim();

	if(trimmed === '')
	{
		return null;
	}

	const parts = trimmed.split(/\s+/);

	if(parts.length < 6 || parts.length > 7)
	{
		return null;
	}

	return parts;
}

/**
 * @description Extracts the day list from a day-of-week value, expanding each range in the list, so MON-WED,FRI
 *              gives MON, TUE, WED and FRI.
 */
function parseDayList(dayOfWeek)
{
	return dayOfWeek.split(',').flatMap((token) => (token.includes('-') ? expandDayRange(token) : [token]));
}

/**
 * @description Matcher definitions for mapping parsed cron fields to preset configurations.
 *              Each entry specifies a match predicate and a factory that builds the preset result.
 *              A matcher marked jobRunnerOnly is skipped unless the record runs on the job runner. The weekly preset takes
 *              only a day field the validator accepts.
 */
const PRESET_MATCHERS = [
	{
		jobRunnerOnly: true,
		match: (fields) => fields.minutes.startsWith('*/') && VALID_MINUTE_INTERVALS.includes(fields.minutes.substring(2)) && fields.hours === '*' && isWildcard(fields.dayOfMonth)
				&& isWildcard(fields.dayOfWeek),
		build: (fields) => ({frequency: 'everyNMinutes', minuteInterval: fields.minutes.substring(2)})
	},
	{
		match: (fields) => isSingleNumber(fields.minutes) && fields.hours === '*' && isWildcard(fields.dayOfMonth) && isWildcard(fields.dayOfWeek),
		build: (fields) => ({frequency: 'hourly', minute: fields.minutes})
	},
	{
		match: (fields) => isSingleNumber(fields.minutes) && isSingleNumber(fields.hours) && isWildcard(fields.dayOfMonth) && isWildcard(fields.dayOfWeek),
		build: (fields) => ({frequency: 'daily', hour: fields.hours, minute: fields.minutes})
	},
	{
		match: (fields) => isSingleNumber(fields.minutes) && isSingleNumber(fields.hours) && fields.dayOfMonth === '?' && !isWildcard(fields.dayOfWeek)
				&& !fields.dayOfWeek.includes('#') && !fields.dayOfWeek.endsWith('L') && validateCronField('dayOfWeek', fields.enteredDayOfWeek).isValid,
		build: (fields) => ({frequency: 'weekly', hour: fields.hours, minute: fields.minutes, daysOfWeek: parseDayList(fields.dayOfWeek)})
	},
	{
		match: (fields) => isSingleNumber(fields.minutes) && isSingleNumber(fields.hours) && isSingleNumber(fields.dayOfMonth) && isWildcard(fields.dayOfWeek),
		build: (fields) => ({frequency: 'monthly', hour: fields.hours, minute: fields.minutes, dayOfMonth: fields.dayOfMonth})
	}
];

/**
 * @description Attempts to match a parsed expression against preset patterns.
 * @param {Array} parts - The split cron expression parts
 * @param {Object} options - Resolved reading options
 * @returns {Object|null} The preset result, or null when no preset matches
 */
function matchPreset(parts, options)
{
	if(parts.length > 6)
	{
		return null;
	}

	const [seconds, minutes, hours, dayOfMonth, month, dayOfWeek] = parts;

	if(seconds !== '0' || month !== '*')
	{
		return null;
	}

	const normalisedMinutes = options.jobRunnerMode && /^0\/\d+$/.test(minutes) ? '*/' + minutes.substring(2) : minutes;
	// The weekly preset checks the day field as entered: once numbers become names, a range the validator refuses,
	// such as 6-2, reads as FRI-MON, which runs on past Saturday.
	const fields = {minutes: normalisedMinutes, hours, dayOfMonth, month, dayOfWeek: normaliseDayOfWeek(dayOfWeek), enteredDayOfWeek: dayOfWeek};

	for(const matcher of PRESET_MATCHERS)
	{
		if(matcher.jobRunnerOnly && !options.jobRunnerMode)
		{
			continue;
		}

		if(matcher.match(fields))
		{
			return {mode: MODE_PRESET, preset: matcher.build(fields), isValid: true};
		}
	}

	return null;
}

/**
 * @description Expands a day range like MON-FRI into an array of day names. A range whose last day comes before its
 *              first day in the week, such as FRI-MON, runs on past Saturday: Friday, Saturday, Sunday and Monday. Only a
 *              day field the validator accepts reaches it, through the weekly preset or the description, so both ends are
 *              day names.
 */
function expandDayRange(range)
{
	const [start, end] = range.split('-');
	const startIndex = DAY_NAMES_ORDERED.indexOf(start);
	const endIndex = DAY_NAMES_ORDERED.indexOf(end);
	const dayCount = DAY_NAMES_ORDERED.length;
	const daysAfterStart = (endIndex - startIndex + dayCount) % dayCount;
	const result = [];
	for(let offset = 0; offset <= daysAfterStart; offset++)
	{
		result.push(DAY_NAMES_ORDERED[(startIndex + offset) % dayCount]);
	}
	return result;
}

/**
 * @description Parses a cron expression string into a structured result.
 * @param {string} expression - The cron expression to parse
 * @param {Object} [options] - jobRunnerMode true reads the expression the way the job runner does,
 *                             where the minutes field may carry a step and the Every N Minutes preset exists
 * @returns {Object} Parsed result with mode, preset/advanced state, and isValid flag
 */
export function parseCronExpression(expression, options)
{
	const resolved = resolveOptions(options);

	if(!expression || typeof expression !== 'string')
	{
		return {mode: MODE_PRESET, preset: {frequency: 'daily', hour: '12', minute: '0'}, isValid: true};
	}

	const parts = splitCronExpression(expression);

	if(!parts)
	{
		if(expression.trim() === '')
		{
			return {mode: MODE_PRESET, preset: {frequency: 'daily', hour: '12', minute: '0'}, isValid: true};
		}
		return {mode: MODE_CUSTOM, raw: expression, isValid: false};
	}

	const presetResult = matchPreset(parts, resolved);
	if(presetResult)
	{
		return presetResult;
	}

	return {
		mode: MODE_ADVANCED, advanced: {
			seconds: parts[0], minutes: parts[1], hours: parts[2], dayOfMonth: parts[3], month: parts[4], dayOfWeek: parts[5], year: parts[6] || ''
		}, isValid: true
	};
}

/**
 * @description Builds a cron expression string from mode and state.
 * @param {string} mode - The editor mode (preset, advanced, custom)
 * @param {Object} state - The state object for the given mode
 * @returns {string} The built cron expression
 */
export function buildCronExpression(mode, state)
{
	if(mode === MODE_CUSTOM)
	{
		return state.raw || DEFAULT_CRON_EXPRESSION;
	}

	if(mode === MODE_PRESET)
	{
		return buildPresetExpression(state);
	}

	if(mode === MODE_ADVANCED)
	{
		return buildAdvancedExpression(state);
	}

	return DEFAULT_CRON_EXPRESSION;
}

/**
 * @description Builds a cron expression from preset state.
 */
function buildPresetExpression(preset)
{
	switch(preset.frequency)
	{
		case 'everyNMinutes':
			return `0 */${preset.minuteInterval || '5'} * * * ?`;
		case 'hourly':
			return `0 ${preset.minute || '0'} * * * ?`;
		case 'daily':
			return `0 ${preset.minute || '0'} ${preset.hour || '12'} * * ?`;
		case 'weekly':
		{
			const days = preset.daysOfWeek && preset.daysOfWeek.length > 0 ? preset.daysOfWeek.join(',') : 'MON';
			return `0 ${preset.minute || '0'} ${preset.hour || '9'} ? * ${days}`;
		}
		case 'monthly':
			return `0 ${preset.minute || '0'} ${preset.hour || '8'} ${preset.dayOfMonth || '1'} * ?`;
		default:
			return DEFAULT_CRON_EXPRESSION;
	}
}

/**
 * @description Builds a cron expression from advanced field state.
 */
function buildAdvancedExpression(advanced)
{
	const seconds = advanced.seconds || '0';
	const minutes = advanced.minutes || '0';
	const hours = advanced.hours || '0';
	const dayOfMonth = advanced.dayOfMonth || '*';
	const month = advanced.month || '*';
	const dayOfWeek = advanced.dayOfWeek || '?';
	const year = advanced.year || '';

	let expression = `${seconds} ${minutes} ${hours} ${dayOfMonth} ${month} ${dayOfWeek}`;

	if(year)
	{
		expression += ` ${year}`;
	}

	return expression;
}

/**
 * @description Formats an hour number (0-23) into 12-hour AM/PM format.
 */
function formatTime(hours, minutes)
{
	const hourNum = parseInt(hours, 10);
	const minuteNum = parseInt(minutes, 10);
	const period = hourNum < HOURS_ON_TWELVE_HOUR_CLOCK ? 'AM' : 'PM';
	const displayHour = hourNum % HOURS_ON_TWELVE_HOUR_CLOCK || HOURS_ON_TWELVE_HOUR_CLOCK;
	const displayMinute = String(minuteNum).padStart(2, '0');

	return `${displayHour}:${displayMinute} ${period}`;
}

/**
 * @description Describes a list of day names in human-readable format. Only a valid expression is described, so every
 *              entry is a day name.
 */
function describeDayList(days)
{
	const fullNames = days.map((day) => DAY_FULL_NAMES[day]);

	if(fullNames.length === 1)
	{
		return fullNames[0];
	}

	if(fullNames.length === 2)
	{
		return formatTemplateString(DAY_LIST_TWO, [
			fullNames[0],
			fullNames[1]
		]);
	}

	// The ', ' list separator stays a literal: it is pure punctuation, and Salesforce strips
	// leading/trailing whitespace from Custom Label values, so a ', ' label cannot round-trip.
	// The translatable conjunction carries the final day as a {0} placeholder to keep its
	// internal spacing (which Salesforce does preserve).
	return fullNames.slice(0, -1).join(', ') + formatTemplateString(DAY_LIST_CONJUNCTION, [fullNames[fullNames.length - 1]]);
}

/**
 * @description Describes an hourly pattern with a specific minute value.
 */
function describeHourlyPattern(minuteNum)
{
	return formatTemplateString(DESC_HOURLY, [minuteNum]);
}

/**
 * @description Describes a daily pattern with optional month qualification.
 */
function describeDailyPattern(time, month)
{
	if(month === '*')
	{
		return formatTemplateString(DESC_DAILY, [time]);
	}

	return formatTemplateString(DESC_DAILY_IN_MONTH, [
		month,
		time
	]);
}

/**
 * @description Resolves a time-based description from parsed cron fields.
 *              Handles daily, day-of-week, and day-of-month patterns.
 */
function describeTimeBasedPattern(hours, minutes, dayOfMonth, month, dayOfWeek, expression)
{
	if(!isSingleNumber(minutes))
	{
		return expression;
	}

	const minuteNum = parseInt(minutes, 10);

	if(hours === '*')
	{
		if(isEveryDayOfEveryMonth(dayOfMonth, month, dayOfWeek))
		{
			return describeHourlyPattern(minuteNum);
		}

		return describeDaysPattern(formatTemplateString(DESC_MINUTE_OF_EVERY_HOUR, [minuteNum]), dayOfMonth, month, dayOfWeek);
	}

	if(!isSingleNumber(hours))
	{
		return expression;
	}

	return describeDaysPattern(formatTime(hours, minutes), dayOfMonth, month, dayOfWeek);
}

/**
 * @description Whether the day of month, month and day of week fields all allow every value, so the job runs on every day.
 */
function isEveryDayOfEveryMonth(dayOfMonth, month, dayOfWeek)
{
	return isWildcard(dayOfMonth) && isWildcard(dayOfWeek) && month === '*';
}

/**
 * @description Adds the days a job runs on to a description of when it runs during the day.
 *              The time text is placed after "at" in the day text, for example "Every Monday at 9:00 AM".
 *              Only a valid expression reaches it, so exactly one of the day of month and the day of week is ?.
 * @param {string} time - When the job runs during the day, for example "9:00 AM" or "minute 30 of every hour"
 * @param {string} dayOfMonth - The day of month field
 * @param {string} month - The month field
 * @param {string} dayOfWeek - The day of week field, with day names in upper case
 * @returns {string} The full description
 */
function describeDaysPattern(time, dayOfMonth, month, dayOfWeek)
{
	if(dayOfMonth === '?' && !isWildcard(dayOfWeek))
	{
		return describeDayOfWeekPattern(dayOfWeek, time);
	}

	if(!isWildcard(dayOfMonth))
	{
		return describeDayOfMonthPattern(dayOfMonth, time, month);
	}

	return describeDailyPattern(time, month);
}

/**
 * @description Describes a job that runs every few minutes, with the hours and the days it runs on.
 *              The hours field can be every hour (*), one hour such as 9, or a range of hours such as 9-17.
 * @param {number} interval - How many minutes pass between two runs
 * @param {string} hours - The hours field
 * @param {string} dayOfMonth - The day of month field
 * @param {string} month - The month field
 * @param {string} dayOfWeek - The day of week field, with day names in upper case
 * @param {string} expression - The whole expression, returned when this cannot describe it
 * @returns {string} The description, or the raw expression when the hours field has a shape this cannot describe
 */
function describeMinuteIntervalPattern(interval, hours, dayOfMonth, month, dayOfWeek, expression)
{
	if(hours === '*')
	{
		if(isEveryDayOfEveryMonth(dayOfMonth, month, dayOfWeek))
		{
			return formatTemplateString(DESC_EVERY_N_MINUTES, [interval]);
		}

		return describeDaysPattern(formatTemplateString(DESC_MINUTE_INTERVALS, [interval]), dayOfMonth, month, dayOfWeek);
	}

	const hourRange = hours.split('-');

	if(hourRange.length > 2 || !hourRange.every(isSingleNumber))
	{
		return expression;
	}

	const firstHour = hourRange[0];
	const lastHour = hourRange[hourRange.length - 1];
	const lastMinute = Math.floor(LAST_MINUTE_OF_HOUR / interval) * interval;
	const time = formatTemplateString(DESC_MINUTE_INTERVALS_FROM_TO, [
		interval,
		formatTime(firstHour, 0),
		formatTime(lastHour, lastMinute)
	]);

	return describeDaysPattern(time, dayOfMonth, month, dayOfWeek);
}

/**
 * @description Whether a scheduled minute falls between two of an active job runner's checks, so the job runs late.
 */
function isOffCheckInterval(minutes, checkInterval)
{
	return Boolean(checkInterval) && isSingleNumber(minutes) && parseInt(minutes, 10) % checkInterval !== 0;
}

/**
 * @description Generates a human-readable description of a cron expression.
 * @param {string} expression - The cron expression to describe
 * @param {Object} [options] - jobRunnerMode true describes what the job runner will do, and
 *                             activeCheckIntervalMinutes says how often the active runner checks for due jobs
 * @returns {string} Human-readable description. A blank or non-text value gives an empty text. An expression that cannot be read, or that
 *                   validation refuses, comes back as it was written. A year that has already passed is not a refusal here, so
 *                   such an expression is still described.
 */
export function describeCronExpression(expression, options)
{
	const resolved = resolveOptions(options);

	if(!expression || typeof expression !== 'string')
	{
		return '';
	}

	const parts = splitCronExpression(expression);

	if(!parts)
	{
		return expression.trim() === '' ? '' : expression;
	}

	// An expression that validation refuses is shown as it is, beside the validation error, and never described.
	// A year that has passed does not stop the description: that rule only keeps a new save from using such a year.
	if(!validateCronExpression(expression, {...resolved, ignorePastYear: true}).isValid)
	{
		return expression;
	}

	const [seconds, minutes, hours, dayOfMonth, month, dayOfWeekToken, year] = parts;
	const dayOfWeek = normaliseDayOfWeek(dayOfWeekToken);
	// The leading space is added here, not in the label: Salesforce strips leading and trailing spaces from Custom Label values.
	const yearSuffix = year ? ' ' + formatTemplateString(DESC_IN_YEAR_SUFFIX, [year]) : '';

	if(seconds !== '0')
	{
		return expression;
	}

	// Validation accepts a minute step only on the job runner, so only a job runner expression reaches this branch.
	if(minutes.startsWith('*/') || /^0\/\d+$/.test(minutes))
	{
		const interval = parseInt(minutes.substring(2), 10);
		const checkInterval = resolved.activeCheckIntervalMinutes ? Math.max(interval, resolved.activeCheckIntervalMinutes) : interval;
		let described = describeMinuteIntervalPattern(checkInterval, hours, dayOfMonth, month, dayOfWeek, expression);

		if(described === expression)
		{
			return expression;
		}

		described += yearSuffix;
		return resolved.activeCheckIntervalMinutes ? formatTemplateString(DESC_EVERY_N_MINUTES_ON_RUNNER, [described]) : described;
	}

	let description = describeTimeBasedPattern(hours, minutes, dayOfMonth, month, dayOfWeek, expression);

	if(description === expression)
	{
		return expression;
	}

	description += yearSuffix;

	if(resolved.jobRunnerMode && isOffCheckInterval(minutes, resolved.activeCheckIntervalMinutes))
	{
		return description + '. ' + DESC_FIRST_CHECK_ON_OR_AFTER;
	}

	return description;
}

/**
 * @description Describes a day-of-week cron pattern. Only a valid expression reaches it, so the occurrence after # is
 *              1 to 5, and every day in the field, including the day before # or L, is a day of the week.
 */
function describeDayOfWeekPattern(dayOfWeek, time)
{
	if(dayOfWeek.includes('#'))
	{
		const [day, occurrence] = dayOfWeek.split('#');
		const normalisedDay = normaliseDayToken(day);
		const dayName = DAY_FULL_NAMES[normalisedDay];
		return formatTemplateString(DESC_NTH_WEEKDAY, [
			ORDINAL_NAMES[occurrence],
			dayName,
			time
		]);
	}

	if(dayOfWeek.endsWith('L'))
	{
		return formatTemplateString(DESC_LAST_WEEKDAY, [
			DAY_FULL_NAMES[normaliseDayToken(dayOfWeek.slice(0, -1))],
			time
		]);
	}

	if(dayOfWeek.includes(','))
	{
		return formatTemplateString(DESC_DAY_LIST, [
			describeDayList(parseDayList(dayOfWeek)),
			time
		]);
	}

	if(dayOfWeek.includes('-'))
	{
		const [start, end] = dayOfWeek.split('-');
		if(start === 'MON' && end === 'FRI')
		{
			return formatTemplateString(DESC_WEEKDAYS, [time]);
		}
		const startName = DAY_FULL_NAMES[start];
		const endName = DAY_FULL_NAMES[end];
		return formatTemplateString(DESC_DAY_RANGE, [
			startName,
			endName,
			time
		]);
	}

	return formatTemplateString(DESC_DAY_LIST, [
		describeDayList([dayOfWeek]),
		time
	]);
}

const CRON_FIELD_PATTERNS = {
	seconds: {pattern: /^(\d{1,2})$/, message: VAL_SECONDS, min: 0, max: 59},
	minutes: {pattern: /^(\d{1,2})$/, message: VAL_MINUTES, min: 0, max: 59},
	hours: {pattern: /^(\*|\d{1,2}|\*\/\d{1,2}|\d{1,2}\/\d{1,2}|\d{1,2}([,-]\d{1,2})+)$/, message: VAL_HOURS, min: 0, max: 23},
	dayOfMonth: {
		pattern: /^(\*|\?|L|LW|\d{1,2}W?|\*\/\d{1,2}|\d{1,2}\/\d{1,2}|\d{1,2}([,-]\d{1,2})+)$/, message: VAL_DAY_OF_MONTH, min: 1, max: 31
	},
	month: {
		pattern: /^(\*|\d{1,2}|[A-Z]{3}|\*\/\d{1,2}|\d{1,2}\/\d{1,2}|[\dA-Z]{1,3}([,-][\dA-Z]{1,3})+)$/, message: VAL_MONTH, min: 1, max: 12
	},
	dayOfWeek: {pattern: /^(\*|\?|\d(L|#\d)?|[A-Za-z]{3}(L|#\d)?|[\dA-Za-z]{1,3}([,-][\dA-Za-z]{1,3})*)$/, message: VAL_DAY_OF_WEEK, min: 1, max: 7},
	year: {pattern: /^(\d{4})?$/, message: VAL_YEAR, min: 1970, max: 2099, isPastAware: true}
};

/**
 * @description The minutes field as the job runner reads it: Kern reads the expression itself there,
 *              so a step, a range and a list all work, not the single minute a scheduled job is limited to.
 */
const JOB_RUNNER_MINUTES_PATTERN = {
	pattern: /^(\*|\d{1,2}|\*\/\d{1,2}|\d{1,2}\/\d{1,2}|\d{1,2}([,-]\d{1,2})+)$/, message: VAL_MINUTES_JOB_RUNNER, min: 0, max: 59
};

const MONTH_NAME_TO_NUMBER = {
	'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, 'MAY': 5, 'JUN': 6, 'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12
};

/**
 * @description Whether a part of a month value is a name that is not a month, such as XYZ in JAN,XYZ.
 * @param {string} fieldName - The field name
 * @param {string} part - One value of a list, or one end of a range, in upper case
 * @returns {boolean} True when the field is the month field and the part is a name not in the month list
 */
function isUnknownMonthName(fieldName, part)
{
	return fieldName === 'month' && /^[A-Z]+$/.test(part) && !MONTH_NAME_TO_NUMBER[part];
}

/**
 * @description Whether a part of a day-of-week value is a name that is not a day, such as XYZ in MON,XYZ or XYZ#1.
 * @param {string} fieldName - The field name
 * @param {string} part - One value of a list, one end of a range, or the day before #, in upper case
 * @returns {boolean} True when the field is the day-of-week field and the part is a name not in the day list
 */
function isUnknownDayName(fieldName, part)
{
	return fieldName === 'dayOfWeek' && /^[A-Z]+$/.test(part) && !DAY_NAMES_ORDERED.includes(part);
}

/**
 * @description Checks the day before the L in the day-of-week field. A day followed by L means the last such day of
 *              the month, so 6L and FRIL both mean the last Friday. The day must be one day of the week: a number
 *              from 1 to 7, or a day name such as FRI.
 * @param {string} day - The value without its final L, in upper case
 * @param {Object} field - The field definition with min/max
 * @returns {string|null} Error message or null if valid
 */
function validateLastDayOfWeek(day, field)
{
	if(/^\d+$/.test(day))
	{
		const dayNumber = parseInt(day, 10);
		return dayNumber < field.min || dayNumber > field.max ? formatTemplateString(VAL_OUT_OF_RANGE, [
			dayNumber,
			field.min,
			field.max
		]) : null;
	}

	return DAY_NAMES_ORDERED.includes(day) ? null : field.message;
}

/**
 * @description Validates the semantic correctness of a cron field value after regex passes.
 *              Checks step values, list element ranges, reversed ranges, month names, day names, a day before L, and # occurrences.
 * @param {string} fieldName - The field name
 * @param {string} value - The value to validate
 * @param {Object} field - The field definition with min/max
 * @param {boolean} [ignorePastYear] - True skips the rule that refuses a year before the current year
 * @returns {string|null} Error message or null if valid
 */
function validateFieldSemantics(fieldName, value, field, ignorePastYear)
{
	if(!ignorePastYear && field.isPastAware && /^\d{4}$/.test(value))
	{
		const year = parseInt(value, 10);
		if(year < new Date().getFullYear())
		{
			return formatTemplateString(VAL_YEAR_IN_PAST, [year]);
		}
	}

	if(value === '*' || value === '?' || value === 'L' || value === 'LW')
	{
		return null;
	}

	if(fieldName === 'dayOfWeek' && value.endsWith('L'))
	{
		return validateLastDayOfWeek(value.slice(0, -1), field);
	}

	if(/^\d+W$/.test(value))
	{
		const digit = parseInt(value.slice(0, -1), 10);
		if(digit < field.min || digit > field.max)
		{
			return formatTemplateString(VAL_OUT_OF_RANGE, [
				digit,
				field.min,
				field.max
			]);
		}
		return null;
	}

	if(value.includes('#'))
	{
		const [dayPart, occurrencePart] = value.split('#');
		if(isUnknownDayName(fieldName, dayPart))
		{
			return field.message;
		}
		const dayNum = parseInt(dayPart, 10);
		if(!isNaN(dayNum) && (dayNum < 1 || dayNum > 7))
		{
			return VAL_HASH_DAY;
		}
		const occurrence = parseInt(occurrencePart, 10);
		if(isNaN(occurrence) || occurrence < 1 || occurrence > 5)
		{
			return VAL_HASH_OCCURRENCE;
		}
		return null;
	}

	if(value.includes('/'))
	{
		const [base, step] = value.split('/');
		const stepNum = parseInt(step, 10);
		if(isNaN(stepNum) || stepNum < 1)
		{
			return VAL_STEP_MIN;
		}
		if(stepNum > field.max)
		{
			return formatTemplateString(VAL_STEP_MAX, [
				stepNum,
				field.max
			]);
		}
		if(base !== '*' && /^\d+$/.test(base))
		{
			const baseNum = parseInt(base, 10);
			if(baseNum < field.min || baseNum > field.max)
			{
				return formatTemplateString(VAL_BASE_OUT_OF_RANGE, [
					baseNum,
					field.min,
					field.max
				]);
			}
		}
		return null;
	}

	const tokens = value.split(',');
	for(const token of tokens)
	{
		if(token.split('-').some((part) => isUnknownMonthName(fieldName, part) || isUnknownDayName(fieldName, part)))
		{
			return field.message;
		}

		if(token.includes('-'))
		{
			const [startStr, endStr] = token.split('-');
			if(/^\d+$/.test(startStr) && /^\d+$/.test(endStr))
			{
				const start = parseInt(startStr, 10);
				const end = parseInt(endStr, 10);
				if(start < field.min || start > field.max)
				{
					return formatTemplateString(VAL_OUT_OF_RANGE, [
						start,
						field.min,
						field.max
					]);
				}
				if(end < field.min || end > field.max)
				{
					return formatTemplateString(VAL_OUT_OF_RANGE, [
						end,
						field.min,
						field.max
					]);
				}
				if(start > end)
				{
					return formatTemplateString(VAL_RANGE_REVERSED, [
						start,
						end
					]);
				}
			}
		}
		else if(/^\d+$/.test(token))
		{
			const num = parseInt(token, 10);
			if(num < field.min || num > field.max)
			{
				return formatTemplateString(VAL_OUT_OF_RANGE, [
					num,
					field.min,
					field.max
				]);
			}
		}
	}

	return null;
}

/**
 * @description Validates a single cron field value against its expected pattern.
 * @param {string} fieldName - The field name (minutes, hours, dayOfMonth, month, dayOfWeek, year)
 * @param {string} value - The value to validate
 * @param {Object} [options] - jobRunnerMode true reads the minutes field the way the job runner does,
 *                             and ignorePastYear true accepts a year that has already passed
 * @returns {Object} Result with isValid boolean and errorMessage string
 */
export function validateCronField(fieldName, value, options)
{
	const resolved = resolveOptions(options);
	const field = fieldName === 'minutes' && resolved.jobRunnerMode ? JOB_RUNNER_MINUTES_PATTERN : CRON_FIELD_PATTERNS[fieldName];

	if(!field)
	{
		return {isValid: true, errorMessage: ''};
	}

	// Month and day names are read in any case, as Salesforce reads them: jan is JAN.
	const checkedValue = fieldName === 'month' || fieldName === 'dayOfWeek' ? (value || '').toUpperCase() : value || '';
	let isValid = field.pattern.test(checkedValue);

	if(isValid && field.min !== undefined && /^\d+$/.test(checkedValue))
	{
		const num = parseInt(checkedValue, 10);
		isValid = num >= field.min && num <= field.max;
	}

	if(isValid && field.min !== undefined)
	{
		const semanticError = validateFieldSemantics(fieldName, checkedValue, field, resolved.ignorePastYear);
		if(semanticError)
		{
			return {isValid: false, errorMessage: semanticError};
		}
	}

	return {isValid, errorMessage: isValid ? '' : field.message};
}

const MAX_DAYS_PER_MONTH = {
	2: 29, 4: 30, 6: 30, 9: 30, 11: 30
};

/**
 * @description Resolves a month field value to a numeric month (1-12), or null if wildcard/complex.
 * @param {string} value - The month field value
 * @returns {number|null} Numeric month or null
 */
function resolveMonthNumber(value)
{
	if(value === '*' || value.includes(',') || value.includes('-') || value.includes('/'))
	{
		return null;
	}

	const monthNum = MONTH_NAME_TO_NUMBER[value.toUpperCase()];

	if(monthNum)
	{
		return monthNum;
	}

	if(/^\d{1,2}$/.test(value))
	{
		return parseInt(value, 10);
	}

	return null;
}

/**
 * @description Extracts the maximum specific day from a dayOfMonth value, or null if wildcard/complex.
 * @param {string} value - The dayOfMonth field value
 * @returns {number|null} The max day number or null
 */
function resolveMaxDay(value)
{
	if(value === '*' || value === '?' || value === 'L' || value === 'LW' || value.includes('/'))
	{
		return null;
	}

	const dayValue = value.endsWith('W') ? value.slice(0, -1) : value;
	const days = dayValue.split(',').flatMap((token) =>
	{
		if(token.includes('-'))
		{
			const [start, end] = token.split('-');
			return [
				parseInt(start, 10),
				parseInt(end, 10)
			];
		}
		return [parseInt(token, 10)];
	}).filter((n) => !isNaN(n));

	return days.length > 0 ? Math.max(...days) : null;
}

/**
 * @description Validates that a specific day-of-month is possible for a specific month.
 * @param {string} dayOfMonth - The dayOfMonth field value
 * @param {string} month - The month field value
 * @returns {string|null} Error message or null if valid
 */
function validateDayMonthCombination(dayOfMonth, month)
{
	const monthNum = resolveMonthNumber(month);
	const maxDay = resolveMaxDay(dayOfMonth);

	if(monthNum === null || maxDay === null)
	{
		return null;
	}

	const monthLimit = MAX_DAYS_PER_MONTH[monthNum];

	if(monthLimit !== undefined && maxDay > monthLimit)
	{
		const monthNames = Object.keys(MONTH_NAME_TO_NUMBER);
		const monthName = monthNames[monthNum - 1] || `month ${monthNum}`;
		return formatTemplateString(VAL_DAY_NOT_IN_MONTH, [
			maxDay,
			monthName,
			monthLimit
		]);
	}

	return null;
}

/**
 * @description Validates cross-field rules between dayOfMonth and dayOfWeek.
 *              Exactly one must be ? in a valid Salesforce cron expression.
 * @param {Array} parts - The split cron expression parts
 * @returns {string|null} Error message or null if valid
 */
function validateCronCrossFields(parts)
{
	const dayOfMonth = parts[3];
	const month = parts[4];
	const dayOfWeek = parts[5];

	if(dayOfMonth === '?' && dayOfWeek === '?')
	{
		return VAL_BOTH_QUESTION;
	}

	if(dayOfMonth !== '?' && dayOfWeek !== '?')
	{
		return VAL_NEITHER_QUESTION;
	}

	const dayMonthError = validateDayMonthCombination(dayOfMonth, month);
	if(dayMonthError)
	{
		return dayMonthError;
	}

	return null;
}

/**
 * @description Validates a complete cron expression including structural, per-field, and cross-field rules.
 * @param {string} expression - The cron expression to validate
 * @param {Object} [options] - jobRunnerMode true reads the minutes field the way the job runner does,
 *                             and ignorePastYear true accepts a year that has already passed
 * @returns {Object} Result with isValid boolean and errorMessage string
 */
export function validateCronExpression(expression, options)
{
	const parts = splitCronExpression(expression || '');
	if(!parts || !parts.every((part) => part.length > 0))
	{
		return {isValid: false, errorMessage: VAL_STRUCTURE};
	}

	const fieldNames = [
		'seconds',
		'minutes',
		'hours',
		'dayOfMonth',
		'month',
		'dayOfWeek',
		'year'
	];
	for(let i = 0; i < parts.length; i++)
	{
		const result = validateCronField(fieldNames[i], parts[i], options);
		if(!result.isValid)
		{
			return {isValid: false, errorMessage: `${fieldNames[i]}: ${result.errorMessage}`};
		}
	}

	const crossFieldError = validateCronCrossFields(parts);
	if(crossFieldError)
	{
		return {isValid: false, errorMessage: crossFieldError};
	}

	return {isValid: true, errorMessage: ''};
}

/**
 * @description Describes a day-of-month cron pattern.
 */
function describeDayOfMonthPattern(dayOfMonth, time, month)
{
	// The leading space is added here, not in the label: Salesforce strips leading/trailing
	// whitespace from Custom Label values, so DescInMonthSuffix stores 'in month {0}'.
	const monthSuffix = month === '*' ? '' : ' ' + formatTemplateString(DESC_IN_MONTH_SUFFIX, [month]);

	if(dayOfMonth === 'L')
	{
		return formatTemplateString(DESC_LAST_DAY, [time]);
	}

	if(dayOfMonth === 'LW')
	{
		return formatTemplateString(DESC_LAST_WEEKDAY_OF_MONTH, [time]);
	}

	if(dayOfMonth.endsWith('W'))
	{
		const day = dayOfMonth.slice(0, -1);
		return formatTemplateString(DESC_NEAREST_WEEKDAY, [
			day,
			monthSuffix,
			time
		]);
	}

	return formatTemplateString(DESC_MONTHLY_ON_DAY, [
		dayOfMonth,
		monthSuffix,
		time
	]);
}