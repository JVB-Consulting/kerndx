// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Pure functions for parsing, building, and describing Salesforce cron expressions.
 *              Supports the 7-field Salesforce format: Seconds Minutes Hours DayOfMonth Month DayOfWeek [Year]
 */
import {
	MODE_PRESET, MODE_ADVANCED, MODE_CUSTOM, DEFAULT_CRON_EXPRESSION, NUMBER_TO_DAY_NAME
} from './constants';

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
	'SUN': 'Sunday', 'MON': 'Monday', 'TUE': 'Tuesday', 'WED': 'Wednesday', 'THU': 'Thursday', 'FRI': 'Friday', 'SAT': 'Saturday'
};

const ORDINAL_NAMES = {
	'1': 'First', '2': 'Second', '3': 'Third', '4': 'Fourth', '5': 'Fifth'
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
 * @description Normalises a comma-separated or range day-of-week value to day names.
 */
function normaliseDayOfWeek(value)
{
	if(isWildcard(value))
	{
		return value;
	}

	if(value.includes('-'))
	{
		let parts = value.split('-');
		return parts.map(normaliseDayToken).join('-');
	}

	if(value.includes(','))
	{
		return value.split(',').map(normaliseDayToken).join(',');
	}

	return normaliseDayToken(value);
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
	let trimmed = expression.trim();

	if(trimmed === '')
	{
		return null;
	}

	let parts = trimmed.split(/\s+/);

	if(parts.length < 6 || parts.length > 7)
	{
		return null;
	}

	return parts;
}

/**
 * @description Extracts the day list from a day-of-week value, expanding ranges as needed.
 */
function parseDayList(dayOfWeek)
{
	if(dayOfWeek.includes('-'))
	{
		return expandDayRange(dayOfWeek);
	}

	return dayOfWeek.split(',');
}

/**
 * @description Matcher definitions for mapping parsed cron fields to preset configurations.
 *              Each entry specifies a match predicate and a factory that builds the preset result.
 */
const PRESET_MATCHERS = [
	{
		match: (fields) => fields.minutes.startsWith('*/') && VALID_MINUTE_INTERVALS.includes(fields.minutes.substring(2)) && fields.hours === '*' && isWildcard(fields.dayOfMonth)
				&& isWildcard(fields.dayOfWeek), build: (fields) => ({frequency: 'everyNMinutes', minuteInterval: fields.minutes.substring(2)})
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
				&& !fields.dayOfWeek.includes('#') && !fields.dayOfWeek.endsWith('L'),
		build: (fields) => ({frequency: 'weekly', hour: fields.hours, minute: fields.minutes, daysOfWeek: parseDayList(fields.dayOfWeek)})
	},
	{
		match: (fields) => isSingleNumber(fields.minutes) && isSingleNumber(fields.hours) && isSingleNumber(fields.dayOfMonth) && isWildcard(fields.dayOfWeek),
		build: (fields) => ({frequency: 'monthly', hour: fields.hours, minute: fields.minutes, dayOfMonth: fields.dayOfMonth})
	}
];

/**
 * @description Attempts to match a parsed expression against preset patterns.
 */
function matchPreset(parts)
{
	if(parts.length > 6)
	{
		return null;
	}

	let [seconds, minutes, hours, dayOfMonth, month, dayOfWeek] = parts;

	if(seconds !== '0' || month !== '*')
	{
		return null;
	}

	let normalisedMinutes = /^0\/\d+$/.test(minutes) ? '*/' + minutes.substring(2) : minutes;
	let fields = {minutes: normalisedMinutes, hours, dayOfMonth, month, dayOfWeek: normaliseDayOfWeek(dayOfWeek)};

	for(const {match, build} of PRESET_MATCHERS)
	{
		if(match(fields))
		{
			return {mode: MODE_PRESET, preset: build(fields), isValid: true};
		}
	}

	return null;
}

/**
 * @description Expands a day range like MON-FRI into an array of day names.
 */
function expandDayRange(range)
{
	let [start, end] = range.split('-');
	let startIndex = DAY_NAMES_ORDERED.indexOf(start);
	let endIndex = DAY_NAMES_ORDERED.indexOf(end);

	if(startIndex === -1 || endIndex === -1)
	{
		return [range];
	}

	let result = [];
	for(let i = startIndex; i <= endIndex; i++)
	{
		result.push(DAY_NAMES_ORDERED[i]);
	}
	return result;
}

/**
 * @description Parses a cron expression string into a structured result.
 * @param {string} expression - The cron expression to parse
 * @returns {Object} Parsed result with mode, preset/advanced state, and isValid flag
 */
export function parseCronExpression(expression)
{
	if(!expression || typeof expression !== 'string')
	{
		return {mode: MODE_PRESET, preset: {frequency: 'daily', hour: '12', minute: '0'}, isValid: true};
	}

	let parts = splitCronExpression(expression);

	if(!parts)
	{
		if(expression.trim() === '')
		{
			return {mode: MODE_PRESET, preset: {frequency: 'daily', hour: '12', minute: '0'}, isValid: true};
		}
		return {mode: MODE_CUSTOM, raw: expression, isValid: false};
	}

	let presetResult = matchPreset(parts);
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
			let days = preset.daysOfWeek && preset.daysOfWeek.length > 0 ? preset.daysOfWeek.join(',') : 'MON';
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
	let seconds = advanced.seconds || '0';
	let minutes = advanced.minutes || '0';
	let hours = advanced.hours || '0';
	let dayOfMonth = advanced.dayOfMonth || '*';
	let month = advanced.month || '*';
	let dayOfWeek = advanced.dayOfWeek || '?';
	let year = advanced.year || '';

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
	let hourNum = parseInt(hours, 10);
	let minuteNum = parseInt(minutes, 10);
	let period = hourNum < 12 ? 'AM' : 'PM';
	let displayHour = hourNum % 12 || 12;
	let displayMinute = String(minuteNum).padStart(2, '0');

	return `${displayHour}:${displayMinute} ${period}`;
}

/**
 * @description Describes a list of day names in human-readable format.
 */
function describeDayList(days)
{
	let fullNames = days.map((day) => DAY_FULL_NAMES[day] || day);

	if(fullNames.length === 1)
	{
		return fullNames[0];
	}

	if(fullNames.length === 2)
	{
		return `${fullNames[0]} and ${fullNames[1]}`;
	}

	return fullNames.slice(0, -1).join(', ') + ', and ' + fullNames[fullNames.length - 1];
}

/**
 * @description Describes an interval-based minutes pattern into a readable string.
 */
function describeIntervalMinutes(minutes)
{
	let interval = minutes.substring(2);
	return `Every ${interval} minutes`;
}

/**
 * @description Describes an hourly pattern with a specific minute value.
 */
function describeHourlyPattern(minuteNum)
{
	return `Every hour at minute ${minuteNum}`;
}

/**
 * @description Describes a daily pattern with optional month qualification.
 */
function describeDailyPattern(time, month)
{
	if(month === '*')
	{
		return `Every day at ${time}`;
	}

	return `Every day in month ${month} at ${time}`;
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

	let minuteNum = parseInt(minutes, 10);

	if(hours === '*')
	{
		return describeHourlyPattern(minuteNum);
	}

	if(!isSingleNumber(hours))
	{
		return expression;
	}

	let time = formatTime(hours, minutes);

	if(dayOfMonth === '?' && !isWildcard(dayOfWeek))
	{
		return describeDayOfWeekPattern(dayOfWeek, time);
	}

	if(!isWildcard(dayOfMonth) && isWildcard(dayOfWeek))
	{
		return describeDayOfMonthPattern(dayOfMonth, time, month);
	}

	if(isWildcard(dayOfMonth) && isWildcard(dayOfWeek))
	{
		return describeDailyPattern(time, month);
	}

	return expression;
}

/**
 * @description Generates a human-readable description of a cron expression.
 * @param {string} expression - The cron expression to describe
 * @returns {string} Human-readable description, or the raw expression if unparseable
 */
export function describeCronExpression(expression)
{
	if(!expression || typeof expression !== 'string')
	{
		return '';
	}

	let parts = splitCronExpression(expression);

	if(!parts)
	{
		return expression.trim() === '' ? '' : expression;
	}

	let [seconds, minutes, hours, dayOfMonth, month, dayOfWeek] = parts;
	dayOfWeek = normaliseDayOfWeek(dayOfWeek);

	if(seconds !== '0')
	{
		return expression;
	}

	if(minutes.startsWith('*/') || /^0\/\d+$/.test(minutes))
	{
		let normalised = minutes.startsWith('0/') ? '*/' + minutes.substring(2) : minutes;
		return describeIntervalMinutes(normalised);
	}

	return describeTimeBasedPattern(hours, minutes, dayOfMonth, month, dayOfWeek, expression);
}

/**
 * @description Describes a day-of-week cron pattern.
 */
function describeDayOfWeekPattern(dayOfWeek, time)
{
	if(dayOfWeek.includes('#'))
	{
		let [day, occurrence] = dayOfWeek.split('#');
		let normalisedDay = normaliseDayToken(day);
		let dayName = DAY_FULL_NAMES[normalisedDay] || normalisedDay;
		let ordinal = ORDINAL_NAMES[occurrence] || `#${occurrence}`;
		return `${ordinal} ${dayName} of every month at ${time}`;
	}

	if(dayOfWeek.endsWith('L'))
	{
		let day = normaliseDayToken(dayOfWeek.slice(0, -1));
		let dayName = DAY_FULL_NAMES[day] || day;
		return `Last ${dayName} of every month at ${time}`;
	}

	if(dayOfWeek.includes('-'))
	{
		let [start, end] = dayOfWeek.split('-');
		if(start === 'MON' && end === 'FRI')
		{
			return `Every weekday (Monday through Friday) at ${time}`;
		}
		let startName = DAY_FULL_NAMES[start] || start;
		let endName = DAY_FULL_NAMES[end] || end;
		return `Every ${startName} through ${endName} at ${time}`;
	}

	let days = dayOfWeek.includes(',') ? dayOfWeek.split(',') : [dayOfWeek];
	return `Every ${describeDayList(days)} at ${time}`;
}

const CRON_FIELD_PATTERNS = {
	seconds: {pattern: /^(\d{1,2})$/, message: 'Enter 0-59', min: 0, max: 59},
	minutes: {pattern: /^(\*|\d{1,2}|\*\/\d{1,2}|\d{1,2}\/\d{1,2}|\d{1,2}([,\-]\d{1,2})+)$/, message: 'Enter 0-59, *, */N, N/N, or comma/range lists', min: 0, max: 59},
	hours: {pattern: /^(\*|\d{1,2}|\*\/\d{1,2}|\d{1,2}\/\d{1,2}|\d{1,2}([,\-]\d{1,2})+)$/, message: 'Enter 0-23, *, */N, N/N, or comma/range lists', min: 0, max: 23},
	dayOfMonth: {
		pattern: /^(\*|\?|L|LW|\d{1,2}W?|\*\/\d{1,2}|\d{1,2}\/\d{1,2}|\d{1,2}([,\-]\d{1,2})+)$/,
		message: 'Enter 1-31, *, ?, L, W, LW, */N, N/N, or comma/range lists',
		min: 1,
		max: 31
	},
	month: {
		pattern: /^(\*|\d{1,2}|JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC|[\dA-Z]{1,3}([,\-][\dA-Z]{1,3})+)$/,
		message: 'Enter 1-12, *, JAN-DEC, or comma/range lists',
		min: 1,
		max: 12
	},
	dayOfWeek: {pattern: /^(\*|\?|\d(L|#\d)?|[A-Za-z]{3}(L|#\d)?|[\dA-Za-z]{1,3}([,\-][\dA-Za-z]{1,3})*)$/, message: 'Enter 1-7, SUN-SAT, ?, L, or # patterns', min: 1, max: 7},
	year: {pattern: /^(\d{4})?$/, message: 'Enter a year (1970-2099) or leave empty', min: 1970, max: 2099, isPastAware: true}
};

/**
 * @description Validates the semantic correctness of a cron field value after regex passes.
 *              Checks step values, list element ranges, reversed ranges, and # occurrences.
 * @param {string} fieldName - The field name
 * @param {string} value - The value to validate
 * @param {Object} field - The field definition with min/max
 * @returns {string|null} Error message or null if valid
 */
function validateFieldSemantics(fieldName, value, field)
{
	if(field.isPastAware && /^\d{4}$/.test(value))
	{
		let year = parseInt(value, 10);
		if(year < new Date().getFullYear())
		{
			return `Year ${year} is in the past \u2014 the job will never fire`;
		}
	}

	if(value === '*' || value === '?' || value === 'L' || value === 'LW')
	{
		return null;
	}

	if(value.length > 1 && value.endsWith('L'))
	{
		return null;
	}

	if(/^\d+W$/.test(value))
	{
		let digit = parseInt(value.slice(0, -1), 10);
		if(digit < field.min || digit > field.max)
		{
			return `Value ${digit} is out of range (${field.min}-${field.max})`;
		}
		return null;
	}

	if(value.includes('#'))
	{
		let [dayPart, occurrencePart] = value.split('#');
		let dayNum = parseInt(dayPart, 10);
		if(!isNaN(dayNum) && (dayNum < 1 || dayNum > 7))
		{
			return 'Day in # expression must be 1-7';
		}
		let occurrence = parseInt(occurrencePart, 10);
		if(isNaN(occurrence) || occurrence < 1 || occurrence > 5)
		{
			return 'Occurrence in # expression must be 1-5';
		}
		return null;
	}

	if(value.includes('/'))
	{
		let [base, step] = value.split('/');
		let stepNum = parseInt(step, 10);
		if(isNaN(stepNum) || stepNum < 1)
		{
			return 'Step value must be at least 1';
		}
		if(stepNum > field.max)
		{
			return `Step value ${stepNum} exceeds maximum ${field.max}`;
		}
		if(base !== '*' && /^\d+$/.test(base))
		{
			let baseNum = parseInt(base, 10);
			if(baseNum < field.min || baseNum > field.max)
			{
				return `Base value ${baseNum} is out of range (${field.min}-${field.max})`;
			}
		}
		return null;
	}

	let tokens = value.split(',');
	for(let token of tokens)
	{
		if(token.includes('-'))
		{
			let [startStr, endStr] = token.split('-');
			if(/^\d+$/.test(startStr) && /^\d+$/.test(endStr))
			{
				let start = parseInt(startStr, 10);
				let end = parseInt(endStr, 10);
				if(start < field.min || start > field.max)
				{
					return `Value ${start} is out of range (${field.min}-${field.max})`;
				}
				if(end < field.min || end > field.max)
				{
					return `Value ${end} is out of range (${field.min}-${field.max})`;
				}
				if(start > end)
				{
					return `Range ${start}-${end} is invalid \u2014 start must not exceed end`;
				}
			}
		}
		else if(/^\d+$/.test(token))
		{
			let num = parseInt(token, 10);
			if(num < field.min || num > field.max)
			{
				return `Value ${num} is out of range (${field.min}-${field.max})`;
			}
		}
	}

	return null;
}

/**
 * @description Validates a single cron field value against its expected pattern.
 * @param {string} fieldName - The field name (minutes, hours, dayOfMonth, month, dayOfWeek, year)
 * @param {string} value - The value to validate
 * @returns {Object} Result with isValid boolean and errorMessage string
 */
export function validateCronField(fieldName, value)
{
	let field = CRON_FIELD_PATTERNS[fieldName];

	if(!field)
	{
		return {isValid: true, errorMessage: ''};
	}

	let isValid = field.pattern.test(value || '');

	if(isValid && field.min !== undefined && /^\d+$/.test(value))
	{
		let num = parseInt(value, 10);
		isValid = num >= field.min && num <= field.max;
	}

	if(isValid && field.min !== undefined)
	{
		let semanticError = validateFieldSemantics(fieldName, value || '', field);
		if(semanticError)
		{
			return {isValid: false, errorMessage: semanticError};
		}
	}

	return {isValid, errorMessage: isValid ? '' : field.message};
}

const MONTH_NAME_TO_NUMBER = {
	'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, 'MAY': 5, 'JUN': 6, 'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12
};

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

	let monthNum = MONTH_NAME_TO_NUMBER[value.toUpperCase()];

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

	let dayValue = value.endsWith('W') ? value.slice(0, -1) : value;
	let days = dayValue.split(',').flatMap((token) =>
	{
		if(token.includes('-'))
		{
			let [start, end] = token.split('-');
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
	let monthNum = resolveMonthNumber(month);
	let maxDay = resolveMaxDay(dayOfMonth);

	if(monthNum === null || maxDay === null)
	{
		return null;
	}

	let monthLimit = MAX_DAYS_PER_MONTH[monthNum];

	if(monthLimit !== undefined && maxDay > monthLimit)
	{
		let monthNames = Object.keys(MONTH_NAME_TO_NUMBER);
		let monthName = monthNames[monthNum - 1] || `month ${monthNum}`;
		return `Day ${maxDay} does not exist in ${monthName} (max ${monthLimit} days)`;
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
	let dayOfMonth = parts[3];
	let month = parts[4];
	let dayOfWeek = parts[5];

	if(dayOfMonth === '?' && dayOfWeek === '?')
	{
		return 'Exactly one of Day of Month or Day of Week must be ? \u2014 both cannot be ?';
	}

	if(dayOfMonth !== '?' && dayOfWeek !== '?')
	{
		return 'Exactly one of Day of Month or Day of Week must be ? \u2014 set one field to ?';
	}

	let dayMonthError = validateDayMonthCombination(dayOfMonth, month);
	if(dayMonthError)
	{
		return dayMonthError;
	}

	return null;
}

/**
 * @description Validates a complete cron expression including structural, per-field, and cross-field rules.
 * @param {string} expression - The cron expression to validate
 * @returns {Object} Result with isValid boolean and errorMessage string
 */
export function validateCronExpression(expression)
{
	let parts = splitCronExpression(expression || '');
	if(!parts || !parts.every((part) => part.length > 0))
	{
		return {isValid: false, errorMessage: 'Invalid cron expression \u2014 must have 6 or 7 space-separated fields'};
	}

	let fieldNames = [
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
		let result = validateCronField(fieldNames[i], parts[i]);
		if(!result.isValid)
		{
			return {isValid: false, errorMessage: `${fieldNames[i]}: ${result.errorMessage}`};
		}
	}

	let crossFieldError = validateCronCrossFields(parts);
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
	let monthSuffix = month === '*' ? '' : ` in month ${month}`;

	if(dayOfMonth === 'L')
	{
		return `Last day of every month at ${time}`;
	}

	if(dayOfMonth === 'LW')
	{
		return `Last weekday of every month at ${time}`;
	}

	if(dayOfMonth.endsWith('W'))
	{
		let day = dayOfMonth.slice(0, -1);
		return `Nearest weekday to day ${day} of every month${monthSuffix} at ${time}`;
	}

	return `Monthly on day ${dayOfMonth}${monthSuffix} at ${time}`;
}