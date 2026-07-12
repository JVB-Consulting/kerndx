// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Constants and option arrays for the cron expression editor.
 *              All values constrained to what Salesforce System.schedule() accepts.
 *
 * @date March 2026, May 2026
 */
import FREQ_EVERY_N_MINUTES from '@salesforce/label/c.CronExpressionEditor_FreqEveryNMinutes';
import FREQ_HOURLY from '@salesforce/label/c.CronExpressionEditor_FreqHourly';
import FREQ_DAILY from '@salesforce/label/c.CronExpressionEditor_FreqDaily';
import FREQ_WEEKLY from '@salesforce/label/c.CronExpressionEditor_FreqWeekly';
import FREQ_MONTHLY from '@salesforce/label/c.CronExpressionEditor_FreqMonthly';
import INTERVAL_EVERY_5 from '@salesforce/label/c.CronExpressionEditor_IntervalEvery5';
import INTERVAL_EVERY_10 from '@salesforce/label/c.CronExpressionEditor_IntervalEvery10';
import INTERVAL_EVERY_15 from '@salesforce/label/c.CronExpressionEditor_IntervalEvery15';
import INTERVAL_EVERY_30 from '@salesforce/label/c.CronExpressionEditor_IntervalEvery30';
import DAY_SUNDAY from '@salesforce/label/c.CronExpressionEditor_DaySunday';
import DAY_MONDAY from '@salesforce/label/c.CronExpressionEditor_DayMonday';
import DAY_TUESDAY from '@salesforce/label/c.CronExpressionEditor_DayTuesday';
import DAY_WEDNESDAY from '@salesforce/label/c.CronExpressionEditor_DayWednesday';
import DAY_THURSDAY from '@salesforce/label/c.CronExpressionEditor_DayThursday';
import DAY_FRIDAY from '@salesforce/label/c.CronExpressionEditor_DayFriday';
import DAY_SATURDAY from '@salesforce/label/c.CronExpressionEditor_DaySaturday';
import MODE_PRESET_LABEL from '@salesforce/label/c.CronExpressionEditor_ModePreset';
import MODE_ADVANCED_LABEL from '@salesforce/label/c.CronExpressionEditor_ModeAdvanced';
import MODE_CUSTOM_LABEL from '@salesforce/label/c.CronExpressionEditor_ModeCustom';

export const MODE_PRESET = 'preset';
export const MODE_ADVANCED = 'advanced';
export const MODE_CUSTOM = 'custom';

export const DEFAULT_CRON_EXPRESSION = '0 0 12 * * ?';

export const PRESET_FREQUENCIES = [
	{label: FREQ_EVERY_N_MINUTES, value: 'everyNMinutes'},
	{label: FREQ_HOURLY, value: 'hourly'},
	{label: FREQ_DAILY, value: 'daily'},
	{label: FREQ_WEEKLY, value: 'weekly'},
	{label: FREQ_MONTHLY, value: 'monthly'}
];

export const MINUTE_INTERVALS = [
	{label: INTERVAL_EVERY_5, value: '5'},
	{label: INTERVAL_EVERY_10, value: '10'},
	{label: INTERVAL_EVERY_15, value: '15'},
	{label: INTERVAL_EVERY_30, value: '30'}
];

export const DAYS_OF_WEEK = [
	{label: DAY_SUNDAY, value: 'SUN'},
	{label: DAY_MONDAY, value: 'MON'},
	{label: DAY_TUESDAY, value: 'TUE'},
	{label: DAY_WEDNESDAY, value: 'WED'},
	{label: DAY_THURSDAY, value: 'THU'},
	{label: DAY_FRIDAY, value: 'FRI'},
	{label: DAY_SATURDAY, value: 'SAT'}
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
	{label: MODE_PRESET_LABEL, value: MODE_PRESET},
	{label: MODE_ADVANCED_LABEL, value: MODE_ADVANCED},
	{label: MODE_CUSTOM_LABEL, value: MODE_CUSTOM}
];

export const NUMBER_TO_DAY_NAME = {
	'1': 'SUN', '2': 'MON', '3': 'TUE', '4': 'WED', '5': 'THU', '6': 'FRI', '7': 'SAT'
};