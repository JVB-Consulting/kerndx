// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Constants and option arrays for the cron expression editor.
 *              All values constrained to what Salesforce System.schedule() accepts.
 */

export const MODE_PRESET = 'preset';
export const MODE_ADVANCED = 'advanced';
export const MODE_CUSTOM = 'custom';

export const DEFAULT_CRON_EXPRESSION = '0 0 12 * * ?';

export const PRESET_FREQUENCIES = [
	{label: 'Every N Minutes', value: 'everyNMinutes'},
	{label: 'Hourly', value: 'hourly'},
	{label: 'Daily', value: 'daily'},
	{label: 'Weekly', value: 'weekly'},
	{label: 'Monthly', value: 'monthly'}
];

export const MINUTE_INTERVALS = [
	{label: 'Every 5 minutes', value: '5'},
	{label: 'Every 10 minutes', value: '10'},
	{label: 'Every 15 minutes', value: '15'},
	{label: 'Every 30 minutes', value: '30'}
];

export const DAYS_OF_WEEK = [
	{label: 'Sunday', value: 'SUN'},
	{label: 'Monday', value: 'MON'},
	{label: 'Tuesday', value: 'TUE'},
	{label: 'Wednesday', value: 'WED'},
	{label: 'Thursday', value: 'THU'},
	{label: 'Friday', value: 'FRI'},
	{label: 'Saturday', value: 'SAT'}
];

const HOURS_IN_HALF_DAY = 12;

export const HOURS_OPTIONS = Array.from({length: 24}, (_, index) =>
{
	let period = index < HOURS_IN_HALF_DAY ? 'AM' : 'PM';
	let displayHour = index % HOURS_IN_HALF_DAY || HOURS_IN_HALF_DAY;
	return {label: `${displayHour}:00 ${period}`, value: String(index)};
});

export const MINUTES_OPTIONS = Array.from({length: 60}, (_, index) =>
{
	return {label: String(index).padStart(2, '0'), value: String(index)};
});

export const DAY_OF_MONTH_OPTIONS = Array.from({length: 31}, (_, index) =>
{
	let day = index + 1;
	return {label: String(day), value: String(day)};
});

export const SECONDS_OPTIONS = Array.from({length: 60}, (_, index) =>
{
	return {label: String(index).padStart(2, '0'), value: String(index)};
});

export const MODE_OPTIONS = [
	{label: 'Preset', value: MODE_PRESET},
	{label: 'Advanced', value: MODE_ADVANCED},
	{label: 'Custom', value: MODE_CUSTOM}
];

export const NUMBER_TO_DAY_NAME = {
	'1': 'SUN', '2': 'MON', '3': 'TUE', '4': 'WED', '5': 'THU', '6': 'FRI', '7': 'SAT'
};