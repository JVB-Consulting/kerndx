// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for cronParser pure functions.
 *              Tests parseCronExpression, buildCronExpression, and describeCronExpression.
 *
 * @author Jason van Beukering
 * @date February 2026, May 2026
 */
import {parseCronExpression, buildCronExpression, describeCronExpression, validateCronField, validateCronExpression} from '../cronParser';

describe('cronParser', () =>
{
	describe('parseCronExpression', () =>
	{
		describe('every N minutes preset', () =>
		{
			it('parses */5 minute interval', () =>
			{
				let result = parseCronExpression('0 */5 * * * ?');
				expect(result.mode).toBe('preset');
				expect(result.preset.frequency).toBe('everyNMinutes');
				expect(result.preset.minuteInterval).toBe('5');
				expect(result.isValid).toBe(true);
			});

			it('parses */10 minute interval', () =>
			{
				let result = parseCronExpression('0 */10 * * * ?');
				expect(result.preset.minuteInterval).toBe('10');
			});

			it('parses */15 minute interval', () =>
			{
				let result = parseCronExpression('0 */15 * * * ?');
				expect(result.preset.minuteInterval).toBe('15');
			});

			it('parses */30 minute interval', () =>
			{
				let result = parseCronExpression('0 */30 * * * ?');
				expect(result.preset.minuteInterval).toBe('30');
			});

			it('parses everyNMinutes with dayOfMonth as ? and dayOfWeek as *', () =>
			{
				let result = parseCronExpression('0 */5 * ? * *');
				expect(result.mode).toBe('preset');
				expect(result.preset.frequency).toBe('everyNMinutes');
			});

			it('normalises 0/5 to */5 and matches everyNMinutes preset', () =>
			{
				let result = parseCronExpression('0 0/5 * * * ?');
				expect(result.mode).toBe('preset');
				expect(result.preset.frequency).toBe('everyNMinutes');
				expect(result.preset.minuteInterval).toBe('5');
			});

			it('normalises 0/15 to */15 and matches everyNMinutes preset', () =>
			{
				let result = parseCronExpression('0 0/15 * * * ?');
				expect(result.mode).toBe('preset');
				expect(result.preset.frequency).toBe('everyNMinutes');
				expect(result.preset.minuteInterval).toBe('15');
			});

			it('falls back to advanced for unsupported interval like */7', () =>
			{
				let result = parseCronExpression('0 */7 * * * ?');
				expect(result.mode).toBe('advanced');
			});
		});

		describe('hourly preset', () =>
		{
			it('parses hourly pattern', () =>
			{
				let result = parseCronExpression('0 30 * * * ?');
				expect(result.mode).toBe('preset');
				expect(result.preset.frequency).toBe('hourly');
				expect(result.preset.minute).toBe('30');
				expect(result.isValid).toBe(true);
			});

			it('parses hourly at minute 0', () =>
			{
				let result = parseCronExpression('0 0 * * * ?');
				expect(result.preset.frequency).toBe('hourly');
				expect(result.preset.minute).toBe('0');
			});
		});

		describe('daily preset', () =>
		{
			it('parses daily pattern with wildcard dayOfMonth and dayOfWeek', () =>
			{
				let result = parseCronExpression('0 0 12 * * ?');
				expect(result.mode).toBe('preset');
				expect(result.preset.frequency).toBe('daily');
				expect(result.preset.hour).toBe('12');
				expect(result.preset.minute).toBe('0');
				expect(result.isValid).toBe(true);
			});

			it('parses daily with ? for dayOfMonth and * for dayOfWeek', () =>
			{
				let result = parseCronExpression('0 30 9 ? * *');
				expect(result.mode).toBe('preset');
				expect(result.preset.frequency).toBe('daily');
			});
		});

		describe('weekly preset', () =>
		{
			it('parses weekly with comma-separated day names', () =>
			{
				let result = parseCronExpression('0 0 9 ? * MON,WED,FRI');
				expect(result.mode).toBe('preset');
				expect(result.preset.frequency).toBe('weekly');
				expect(result.preset.daysOfWeek).toEqual([
					'MON',
					'WED',
					'FRI'
				]);
				expect(result.preset.hour).toBe('9');
				expect(result.preset.minute).toBe('0');
			});

			it('parses weekly with day range', () =>
			{
				let result = parseCronExpression('0 0 9 ? * MON-FRI');
				expect(result.preset.frequency).toBe('weekly');
				expect(result.preset.daysOfWeek).toEqual([
					'MON',
					'TUE',
					'WED',
					'THU',
					'FRI'
				]);
			});

			it('parses weekly with single day', () =>
			{
				let result = parseCronExpression('0 0 9 ? * MON');
				expect(result.preset.frequency).toBe('weekly');
				expect(result.preset.daysOfWeek).toEqual(['MON']);
			});

			it('parses weekly with numeric day-of-week values', () =>
			{
				let result = parseCronExpression('0 0 9 ? * 2,4,6');
				expect(result.preset.frequency).toBe('weekly');
				expect(result.preset.daysOfWeek).toEqual([
					'MON',
					'WED',
					'FRI'
				]);
			});

			it('parses weekly with numeric day range', () =>
			{
				let result = parseCronExpression('0 0 9 ? * 2-6');
				expect(result.preset.frequency).toBe('weekly');
				expect(result.preset.daysOfWeek).toEqual([
					'MON',
					'TUE',
					'WED',
					'THU',
					'FRI'
				]);
			});
		});

		describe('monthly preset', () =>
		{
			it('parses monthly pattern', () =>
			{
				let result = parseCronExpression('0 0 8 15 * ?');
				expect(result.mode).toBe('preset');
				expect(result.preset.frequency).toBe('monthly');
				expect(result.preset.dayOfMonth).toBe('15');
				expect(result.preset.hour).toBe('8');
				expect(result.preset.minute).toBe('0');
			});

			it('parses monthly on day 1', () =>
			{
				let result = parseCronExpression('0 30 17 1 * ?');
				expect(result.preset.frequency).toBe('monthly');
				expect(result.preset.dayOfMonth).toBe('1');
			});
		});

		describe('advanced mode fallback', () =>
		{
			it('falls back to advanced for L in day-of-month', () =>
			{
				let result = parseCronExpression('0 0 12 L * ?');
				expect(result.mode).toBe('advanced');
				expect(result.advanced.dayOfMonth).toBe('L');
				expect(result.isValid).toBe(true);
			});

			it('falls back to advanced for # in day-of-week', () =>
			{
				let result = parseCronExpression('0 0 3 ? * FRI#1');
				expect(result.mode).toBe('advanced');
				expect(result.advanced.dayOfWeek).toBe('FRI#1');
			});

			it('falls back to advanced for W in day-of-month', () =>
			{
				let result = parseCronExpression('0 0 17 15W * ?');
				expect(result.mode).toBe('advanced');
				expect(result.advanced.dayOfMonth).toBe('15W');
			});

			it('falls back to advanced for LW in day-of-month', () =>
			{
				let result = parseCronExpression('0 0 17 LW * ?');
				expect(result.mode).toBe('advanced');
				expect(result.advanced.dayOfMonth).toBe('LW');
			});

			it('falls back to advanced for non-standard minute pattern', () =>
			{
				let result = parseCronExpression('0 0,30 * * * ?');
				expect(result.mode).toBe('advanced');
			});

			it('falls back to advanced for specific month', () =>
			{
				let result = parseCronExpression('0 0 12 1 6 ?');
				expect(result.mode).toBe('advanced');
			});

			it('falls back to advanced for non-zero seconds', () =>
			{
				let result = parseCronExpression('30 0 12 * * ?');
				expect(result.mode).toBe('advanced');
				expect(result.advanced.seconds).toBe('30');
			});

			it('falls back to advanced for non-numeric minutes with hours', () =>
			{
				let result = parseCronExpression('0 0,15,30,45 12 * * ?');
				expect(result.mode).toBe('advanced');
			});

			it('falls back to advanced for non-numeric hours', () =>
			{
				let result = parseCronExpression('0 0 1-5 * * ?');
				expect(result.mode).toBe('advanced');
			});
		});

		describe('7-part expressions (with year)', () =>
		{
			it('handles expression with year field', () =>
			{
				let result = parseCronExpression('0 0 12 * * ? 2026');
				expect(result.mode).toBe('advanced');
				expect(result.advanced.year).toBe('2026');
				expect(result.isValid).toBe(true);
			});
		});

		describe('custom mode fallback', () =>
		{
			it('falls back to custom for too few parts', () =>
			{
				let result = parseCronExpression('0 0 12');
				expect(result.mode).toBe('custom');
				expect(result.isValid).toBe(false);
			});

			it('falls back to custom for too many parts', () =>
			{
				let result = parseCronExpression('0 0 12 * * ? 2026 extra');
				expect(result.mode).toBe('custom');
				expect(result.isValid).toBe(false);
			});

			it('preserves raw expression in custom mode', () =>
			{
				let result = parseCronExpression('invalid');
				expect(result.mode).toBe('custom');
				expect(result.raw).toBe('invalid');
			});
		});

		describe('null, undefined, and empty input', () =>
		{
			it('handles null input with default preset', () =>
			{
				let result = parseCronExpression(null);
				expect(result.mode).toBe('preset');
				expect(result.preset.frequency).toBe('daily');
				expect(result.isValid).toBe(true);
			});

			it('handles undefined input with default preset', () =>
			{
				let result = parseCronExpression(undefined);
				expect(result.mode).toBe('preset');
			});

			it('handles empty string with default preset', () =>
			{
				let result = parseCronExpression('');
				expect(result.mode).toBe('preset');
			});

			it('handles whitespace-only string with default preset', () =>
			{
				let result = parseCronExpression('   ');
				expect(result.mode).toBe('preset');
			});
		});

		describe('extra whitespace handling', () =>
		{
			it('handles extra whitespace between parts', () =>
			{
				let result = parseCronExpression('0  0  12  *  *  ?');
				expect(result.mode).toBe('preset');
				expect(result.preset.frequency).toBe('daily');
			});

			it('handles leading and trailing whitespace', () =>
			{
				let result = parseCronExpression('  0 0 12 * * ?  ');
				expect(result.mode).toBe('preset');
			});
		});

		describe('day range edge cases', () =>
		{
			it('handles invalid day range tokens gracefully', () =>
			{
				let result = parseCronExpression('0 0 9 ? * XYZ-ABC');
				expect(result.mode).toBe('preset');
				expect(result.preset.frequency).toBe('weekly');
			});
		});
	});

	describe('buildCronExpression', () =>
	{
		describe('preset mode', () =>
		{
			it('builds everyNMinutes expression', () =>
			{
				let result = buildCronExpression('preset', {frequency: 'everyNMinutes', minuteInterval: '15'});
				expect(result).toBe('0 */15 * * * ?');
			});

			it('builds everyNMinutes with default interval', () =>
			{
				let result = buildCronExpression('preset', {frequency: 'everyNMinutes'});
				expect(result).toBe('0 */5 * * * ?');
			});

			it('builds hourly expression', () =>
			{
				let result = buildCronExpression('preset', {frequency: 'hourly', minute: '30'});
				expect(result).toBe('0 30 * * * ?');
			});

			it('builds hourly with default minute', () =>
			{
				let result = buildCronExpression('preset', {frequency: 'hourly'});
				expect(result).toBe('0 0 * * * ?');
			});

			it('builds daily expression', () =>
			{
				let result = buildCronExpression('preset', {frequency: 'daily', hour: '9', minute: '30'});
				expect(result).toBe('0 30 9 * * ?');
			});

			it('builds daily with defaults', () =>
			{
				let result = buildCronExpression('preset', {frequency: 'daily'});
				expect(result).toBe('0 0 12 * * ?');
			});

			it('builds weekly expression', () =>
			{
				let result = buildCronExpression('preset', {
					frequency: 'weekly', hour: '9', minute: '0', daysOfWeek: [
						'MON',
						'WED',
						'FRI'
					]
				});
				expect(result).toBe('0 0 9 ? * MON,WED,FRI');
			});

			it('builds weekly with defaults when no days specified', () =>
			{
				let result = buildCronExpression('preset', {frequency: 'weekly', daysOfWeek: []});
				expect(result).toBe('0 0 9 ? * MON');
			});

			it('builds weekly with null daysOfWeek', () =>
			{
				let result = buildCronExpression('preset', {frequency: 'weekly'});
				expect(result).toBe('0 0 9 ? * MON');
			});

			it('builds monthly expression', () =>
			{
				let result = buildCronExpression('preset', {frequency: 'monthly', hour: '8', minute: '0', dayOfMonth: '15'});
				expect(result).toBe('0 0 8 15 * ?');
			});

			it('builds monthly with defaults', () =>
			{
				let result = buildCronExpression('preset', {frequency: 'monthly'});
				expect(result).toBe('0 0 8 1 * ?');
			});

			it('returns default for unknown frequency', () =>
			{
				let result = buildCronExpression('preset', {frequency: 'unknown'});
				expect(result).toBe('0 0 12 * * ?');
			});
		});

		describe('advanced mode', () =>
		{
			it('builds expression from advanced state', () =>
			{
				let result = buildCronExpression('advanced', {
					seconds: '0', minutes: '30', hours: '9', dayOfMonth: '?', month: '*', dayOfWeek: 'MON-FRI'
				});
				expect(result).toBe('0 30 9 ? * MON-FRI');
			});

			it('preserves both day fields without silent normalization', () =>
			{
				let result = buildCronExpression('advanced', {
					seconds: '0', minutes: '0', hours: '12', dayOfMonth: '15', month: '*', dayOfWeek: 'MON'
				});
				expect(result).toBe('0 0 12 15 * MON');
			});

			it('includes year when provided', () =>
			{
				let result = buildCronExpression('advanced', {
					seconds: '0', minutes: '0', hours: '12', dayOfMonth: '*', month: '*', dayOfWeek: '?', year: '2026'
				});
				expect(result).toBe('0 0 12 * * ? 2026');
			});

			it('omits year when empty', () =>
			{
				let result = buildCronExpression('advanced', {
					seconds: '0', minutes: '0', hours: '12', dayOfMonth: '*', month: '*', dayOfWeek: '?', year: ''
				});
				expect(result).toBe('0 0 12 * * ?');
			});

			it('uses defaults for missing fields', () =>
			{
				let result = buildCronExpression('advanced', {});
				expect(result).toBe('0 0 0 * * ?');
			});
		});

		describe('custom mode', () =>
		{
			it('passes through raw text', () =>
			{
				let result = buildCronExpression('custom', {raw: '0 0 3 ? * FRI#1'});
				expect(result).toBe('0 0 3 ? * FRI#1');
			});

			it('returns default when raw is empty', () =>
			{
				let result = buildCronExpression('custom', {});
				expect(result).toBe('0 0 12 * * ?');
			});
		});

		describe('unknown mode', () =>
		{
			it('returns default expression for unknown mode', () =>
			{
				let result = buildCronExpression('unknown', {});
				expect(result).toBe('0 0 12 * * ?');
			});
		});
	});

	describe('describeCronExpression', () =>
	{
		describe('every N minutes patterns', () =>
		{
			it('describes */5 pattern', () =>
			{
				expect(describeCronExpression('0 */5 * * * ?')).toBe('Every 5 minutes');
			});

			it('describes */15 pattern', () =>
			{
				expect(describeCronExpression('0 */15 * * * ?')).toBe('Every 15 minutes');
			});

			it('describes 0/5 pattern same as */5', () =>
			{
				expect(describeCronExpression('0 0/5 * * * ?')).toBe('Every 5 minutes');
			});

			it('describes 0/15 pattern same as */15', () =>
			{
				expect(describeCronExpression('0 0/15 * * * ?')).toBe('Every 15 minutes');
			});
		});

		describe('hourly pattern', () =>
		{
			it('describes hourly at minute 30', () =>
			{
				expect(describeCronExpression('0 30 * * * ?')).toBe('Every hour at minute 30');
			});

			it('describes hourly at minute 0', () =>
			{
				expect(describeCronExpression('0 0 * * * ?')).toBe('Every hour at minute 0');
			});
		});

		describe('daily pattern', () =>
		{
			it('describes daily at noon', () =>
			{
				expect(describeCronExpression('0 0 12 * * ?')).toBe('Every day at 12:00 PM');
			});

			it('describes daily at midnight', () =>
			{
				expect(describeCronExpression('0 0 0 * * ?')).toBe('Every day at 12:00 AM');
			});

			it('describes daily at 9:30 AM', () =>
			{
				expect(describeCronExpression('0 30 9 * * ?')).toBe('Every day at 9:30 AM');
			});

			it('describes daily at 5:00 PM', () =>
			{
				expect(describeCronExpression('0 0 17 * * ?')).toBe('Every day at 5:00 PM');
			});
		});

		describe('weekly patterns', () =>
		{
			it('describes multiple days', () =>
			{
				expect(describeCronExpression('0 30 9 ? * MON,WED,FRI')).toBe('Every Monday, Wednesday, and Friday at 9:30 AM');
			});

			it('describes weekday range MON-FRI', () =>
			{
				expect(describeCronExpression('0 0 0 ? * MON-FRI')).toBe('Every weekday (Monday through Friday) at 12:00 AM');
			});

			it('describes non-standard range', () =>
			{
				expect(describeCronExpression('0 0 9 ? * TUE-THU')).toBe('Every Tuesday through Thursday at 9:00 AM');
			});

			it('describes range with unrecognised day tokens', () =>
			{
				expect(describeCronExpression('0 0 9 ? * XYZ-ABC')).toBe('Every XYZ through ABC at 9:00 AM');
			});

			it('describes single day', () =>
			{
				expect(describeCronExpression('0 0 9 ? * MON')).toBe('Every Monday at 9:00 AM');
			});

			it('describes two days', () =>
			{
				expect(describeCronExpression('0 0 9 ? * MON,FRI')).toBe('Every Monday and Friday at 9:00 AM');
			});

			it('describes numeric day-of-week values', () =>
			{
				expect(describeCronExpression('0 0 9 ? * 2')).toBe('Every Monday at 9:00 AM');
			});

			it('describes single unrecognised day token', () =>
			{
				expect(describeCronExpression('0 0 9 ? * XYZ')).toBe('Every XYZ at 9:00 AM');
			});
		});

		describe('monthly patterns', () =>
		{
			it('describes monthly on specific day', () =>
			{
				expect(describeCronExpression('0 0 8 15 * ?')).toBe('Monthly on day 15 at 8:00 AM');
			});

			it('describes last day of month', () =>
			{
				expect(describeCronExpression('0 0 0 L * ?')).toBe('Last day of every month at 12:00 AM');
			});

			it('describes last weekday of month', () =>
			{
				expect(describeCronExpression('0 0 17 LW * ?')).toBe('Last weekday of every month at 5:00 PM');
			});

			it('describes nearest weekday', () =>
			{
				expect(describeCronExpression('0 0 9 15W * ?')).toBe('Nearest weekday to day 15 of every month at 9:00 AM');
			});
		});

		describe('hash patterns (nth weekday)', () =>
		{
			it('describes first Friday', () =>
			{
				expect(describeCronExpression('0 0 3 ? * FRI#1')).toBe('First Friday of every month at 3:00 AM');
			});

			it('describes second Monday', () =>
			{
				expect(describeCronExpression('0 0 9 ? * MON#2')).toBe('Second Monday of every month at 9:00 AM');
			});

			it('describes third Wednesday', () =>
			{
				expect(describeCronExpression('0 0 12 ? * WED#3')).toBe('Third Wednesday of every month at 12:00 PM');
			});

			it('describes hash with unrecognised day token', () =>
			{
				expect(describeCronExpression('0 0 9 ? * XYZ#1')).toBe('First XYZ of every month at 9:00 AM');
			});

			it('describes hash with unrecognised ordinal', () =>
			{
				expect(describeCronExpression('0 0 9 ? * FRI#6')).toBe('#6 Friday of every month at 9:00 AM');
			});

			it('describes numeric day-of-week with hash', () =>
			{
				expect(describeCronExpression('0 0 3 ? * 6#1')).toBe('First Friday of every month at 3:00 AM');
			});

			it('describes numeric day 2 with hash as Monday', () =>
			{
				expect(describeCronExpression('0 0 9 ? * 2#2')).toBe('Second Monday of every month at 9:00 AM');
			});
		});

		describe('last day-of-week patterns', () =>
		{
			it('describes last Friday', () =>
			{
				expect(describeCronExpression('0 0 9 ? * FRIL')).toBe('Last Friday of every month at 9:00 AM');
			});

			it('describes numeric day-of-week with L suffix', () =>
			{
				expect(describeCronExpression('0 0 9 ? * 6L')).toBe('Last Friday of every month at 9:00 AM');
			});

			it('describes numeric day 2 with L as last Monday', () =>
			{
				expect(describeCronExpression('0 30 8 ? * 2L')).toBe('Last Monday of every month at 8:30 AM');
			});

			it('describes last day-of-week with unrecognised token', () =>
			{
				expect(describeCronExpression('0 0 9 ? * XYZL')).toBe('Last XYZ of every month at 9:00 AM');
			});
		});

		describe('specific month', () =>
		{
			it('describes daily in specific month', () =>
			{
				expect(describeCronExpression('0 0 12 * 6 ?')).toBe('Every day in month 6 at 12:00 PM');
			});

			it('describes monthly on day with specific month', () =>
			{
				expect(describeCronExpression('0 0 12 15 6 ?')).toBe('Monthly on day 15 in month 6 at 12:00 PM');
			});
		});

		describe('edge cases', () =>
		{
			it('returns empty string for null', () =>
			{
				expect(describeCronExpression(null)).toBe('');
			});

			it('returns empty string for undefined', () =>
			{
				expect(describeCronExpression(undefined)).toBe('');
			});

			it('returns empty string for empty string', () =>
			{
				expect(describeCronExpression('')).toBe('');
			});

			it('returns empty string for whitespace-only string', () =>
			{
				expect(describeCronExpression('   ')).toBe('');
			});

			it('returns raw expression for too few parts', () =>
			{
				expect(describeCronExpression('0 0 12')).toBe('0 0 12');
			});

			it('returns raw expression for too many parts', () =>
			{
				expect(describeCronExpression('0 0 12 * * ? 2026 extra')).toBe('0 0 12 * * ? 2026 extra');
			});

			it('returns raw expression for non-zero seconds', () =>
			{
				expect(describeCronExpression('30 0 12 * * ?')).toBe('30 0 12 * * ?');
			});

			it('returns raw expression for non-numeric minutes', () =>
			{
				expect(describeCronExpression('0 abc 12 * * ?')).toBe('0 abc 12 * * ?');
			});

			it('returns raw expression for non-numeric hours (not *)', () =>
			{
				expect(describeCronExpression('0 0 abc * * ?')).toBe('0 0 abc * * ?');
			});

			it('returns raw expression for non-string input', () =>
			{
				expect(describeCronExpression(42)).toBe('');
			});

			it('returns raw expression when both dayOfMonth and dayOfWeek are specified', () =>
			{
				expect(describeCronExpression('0 0 12 15 * MON')).toBe('0 0 12 15 * MON');
			});
		});

		describe('AM/PM formatting', () =>
		{
			it('formats 0 hours as 12:00 AM', () =>
			{
				expect(describeCronExpression('0 0 0 * * ?')).toContain('12:00 AM');
			});

			it('formats 11 hours as 11:00 AM', () =>
			{
				expect(describeCronExpression('0 0 11 * * ?')).toContain('11:00 AM');
			});

			it('formats 12 hours as 12:00 PM', () =>
			{
				expect(describeCronExpression('0 0 12 * * ?')).toContain('12:00 PM');
			});

			it('formats 23 hours as 11:00 PM', () =>
			{
				expect(describeCronExpression('0 0 23 * * ?')).toContain('11:00 PM');
			});
		});
	});

	describe('validateCronField semantic validation', () =>
	{
		describe('step validation (Bug 1)', () =>
		{
			it('rejects */0 step in hours', () =>
			{
				let result = validateCronField('hours', '*/0');
				expect(result.isValid).toBe(false);
				expect(result.errorMessage).toContain('Step value must be at least 1');
			});

			it('rejects */0 step in minutes', () =>
			{
				let result = validateCronField('minutes', '*/0');
				expect(result.isValid).toBe(false);
				expect(result.errorMessage).toContain('Step value must be at least 1');
			});

			it('rejects 5/0 step', () =>
			{
				let result = validateCronField('minutes', '5/0');
				expect(result.isValid).toBe(false);
				expect(result.errorMessage).toContain('Step value must be at least 1');
			});

			it('accepts */1 step', () =>
			{
				expect(validateCronField('hours', '*/1').isValid).toBe(true);
			});

			it('accepts */12 step', () =>
			{
				expect(validateCronField('hours', '*/12').isValid).toBe(true);
			});

			it('rejects step exceeding max for hours', () =>
			{
				let result = validateCronField('hours', '*/24');
				expect(result.isValid).toBe(false);
				expect(result.errorMessage).toContain('exceeds maximum');
			});

			it('rejects step exceeding max for minutes', () =>
			{
				let result = validateCronField('minutes', '*/60');
				expect(result.isValid).toBe(false);
				expect(result.errorMessage).toContain('exceeds maximum');
			});

			it('rejects out-of-range base in step expression', () =>
			{
				let result = validateCronField('minutes', '60/2');
				expect(result.isValid).toBe(false);
				expect(result.errorMessage).toContain('out of range');
			});
		});

		describe('list range validation (Bug 2)', () =>
		{
			it('rejects out-of-range value in hours list', () =>
			{
				let result = validateCronField('hours', '1,2,3,99');
				expect(result.isValid).toBe(false);
				expect(result.errorMessage).toContain('out of range');
			});

			it('rejects out-of-range value in minutes list', () =>
			{
				let result = validateCronField('minutes', '0,1,2,60');
				expect(result.isValid).toBe(false);
				expect(result.errorMessage).toContain('out of range');
			});

			it('rejects out-of-range value in dayOfMonth list', () =>
			{
				let result = validateCronField('dayOfMonth', '1,32');
				expect(result.isValid).toBe(false);
				expect(result.errorMessage).toContain('out of range');
			});

			it('accepts all-in-range hours list', () =>
			{
				expect(validateCronField('hours', '0,6,12,23').isValid).toBe(true);
			});

			it('accepts all-in-range minutes list', () =>
			{
				expect(validateCronField('minutes', '0,15,30,45').isValid).toBe(true);
			});

			it('accepts all-in-range dayOfMonth list', () =>
			{
				expect(validateCronField('dayOfMonth', '1,15,31').isValid).toBe(true);
			});
		});

		describe('empty comma elements (Bug 3)', () =>
		{
			it('rejects comma-only input in hours', () =>
			{
				let result = validateCronField('hours', ',,,,');
				expect(result.isValid).toBe(false);
			});

			it('rejects leading comma in minutes', () =>
			{
				let result = validateCronField('minutes', ',5');
				expect(result.isValid).toBe(false);
			});

			it('rejects trailing comma in minutes', () =>
			{
				let result = validateCronField('minutes', '5,');
				expect(result.isValid).toBe(false);
			});

			it('rejects empty element between commas', () =>
			{
				let result = validateCronField('minutes', '1,,3');
				expect(result.isValid).toBe(false);
			});
		});

		describe('reversed ranges (Bug 8)', () =>
		{
			it('rejects reversed range in minutes', () =>
			{
				let result = validateCronField('minutes', '59-0');
				expect(result.isValid).toBe(false);
				expect(result.errorMessage).toContain('start must not exceed end');
			});

			it('rejects reversed range in hours', () =>
			{
				let result = validateCronField('hours', '23-5');
				expect(result.isValid).toBe(false);
				expect(result.errorMessage).toContain('start must not exceed end');
			});

			it('rejects reversed range in dayOfMonth', () =>
			{
				let result = validateCronField('dayOfMonth', '31-1');
				expect(result.isValid).toBe(false);
				expect(result.errorMessage).toContain('start must not exceed end');
			});

			it('accepts valid range in minutes', () =>
			{
				expect(validateCronField('minutes', '0-30').isValid).toBe(true);
			});

			it('accepts equal endpoints in range', () =>
			{
				expect(validateCronField('minutes', '5-5').isValid).toBe(true);
			});
		});

		describe('N/M step syntax for hours', () =>
		{
			it('accepts 5/2 in hours (every 2 hours starting at hour 5)', () =>
			{
				expect(validateCronField('hours', '5/2').isValid).toBe(true);
			});

			it('accepts 0/4 in hours', () =>
			{
				expect(validateCronField('hours', '0/4').isValid).toBe(true);
			});

			it('accepts 8/3 in hours', () =>
			{
				expect(validateCronField('hours', '8/3').isValid).toBe(true);
			});

			it('rejects out-of-range base in hours step', () =>
			{
				let result = validateCronField('hours', '24/2');
				expect(result.isValid).toBe(false);
				expect(result.errorMessage).toContain('out of range');
			});
		});

		describe('step syntax for dayOfMonth', () =>
		{
			it('accepts */3 in dayOfMonth', () =>
			{
				expect(validateCronField('dayOfMonth', '*/3').isValid).toBe(true);
			});

			it('accepts 1/7 in dayOfMonth', () =>
			{
				expect(validateCronField('dayOfMonth', '1/7').isValid).toBe(true);
			});

			it('rejects step with 0 in dayOfMonth', () =>
			{
				let result = validateCronField('dayOfMonth', '1/0');
				expect(result.isValid).toBe(false);
				expect(result.errorMessage).toContain('Step value must be at least 1');
			});
		});

		describe('# occurrence validation', () =>
		{
			it('rejects FRI#6 (occurrence > 5)', () =>
			{
				let result = validateCronField('dayOfWeek', 'FRI#6');
				expect(result.isValid).toBe(false);
				expect(result.errorMessage).toContain('1-5');
			});

			it('rejects MON#0 (occurrence < 1)', () =>
			{
				let result = validateCronField('dayOfWeek', 'MON#0');
				expect(result.isValid).toBe(false);
				expect(result.errorMessage).toContain('1-5');
			});

			it('accepts FRI#1', () =>
			{
				expect(validateCronField('dayOfWeek', 'FRI#1').isValid).toBe(true);
			});

			it('accepts MON#5', () =>
			{
				expect(validateCronField('dayOfWeek', 'MON#5').isValid).toBe(true);
			});
		});

		describe('special values pass through', () =>
		{
			it('accepts * for hours', () =>
			{
				expect(validateCronField('hours', '*').isValid).toBe(true);
			});

			it('accepts ? for dayOfMonth', () =>
			{
				expect(validateCronField('dayOfMonth', '?').isValid).toBe(true);
			});

			it('accepts L for dayOfMonth', () =>
			{
				expect(validateCronField('dayOfMonth', 'L').isValid).toBe(true);
			});

			it('accepts LW for dayOfMonth', () =>
			{
				expect(validateCronField('dayOfMonth', 'LW').isValid).toBe(true);
			});

			it('accepts FRIL for dayOfWeek', () =>
			{
				expect(validateCronField('dayOfWeek', 'FRIL').isValid).toBe(true);
			});

			it('accepts 15W for dayOfMonth', () =>
			{
				expect(validateCronField('dayOfMonth', '15W').isValid).toBe(true);
			});

			it('rejects out-of-range W value', () =>
			{
				let result = validateCronField('dayOfMonth', '32W');
				expect(result.isValid).toBe(false);
				expect(result.errorMessage).toContain('out of range');
			});
		});
	});

	describe('validateCronExpression', () =>
	{
		describe('structural validation', () =>
		{
			it('rejects too few fields', () =>
			{
				let result = validateCronExpression('0 0 12');
				expect(result.isValid).toBe(false);
				expect(result.errorMessage).toContain('6 or 7 space-separated fields');
			});

			it('rejects empty expression', () =>
			{
				let result = validateCronExpression('');
				expect(result.isValid).toBe(false);
				expect(result.errorMessage).toContain('6 or 7 space-separated fields');
			});

			it('rejects null expression', () =>
			{
				let result = validateCronExpression(null);
				expect(result.isValid).toBe(false);
				expect(result.errorMessage).toContain('6 or 7 space-separated fields');
			});

			it('rejects too many fields', () =>
			{
				let result = validateCronExpression('0 0 12 * * ? 2026 extra');
				expect(result.isValid).toBe(false);
				expect(result.errorMessage).toContain('6 or 7 space-separated fields');
			});
		});

		describe('per-field validation', () =>
		{
			it('rejects out-of-range hour', () =>
			{
				let result = validateCronExpression('0 0 25 * * ?');
				expect(result.isValid).toBe(false);
				expect(result.errorMessage).toContain('hours');
			});

			it('rejects */0 step', () =>
			{
				let result = validateCronExpression('0 0 */0 * * ?');
				expect(result.isValid).toBe(false);
				expect(result.errorMessage).toContain('Step value must be at least 1');
			});

			it('rejects out-of-range list element', () =>
			{
				let result = validateCronExpression('0 0 1,2,3,99 * * ?');
				expect(result.isValid).toBe(false);
				expect(result.errorMessage).toContain('out of range');
			});

			it('rejects reversed range', () =>
			{
				let result = validateCronExpression('0 59-0 12 * * ?');
				expect(result.isValid).toBe(false);
				expect(result.errorMessage).toContain('start must not exceed end');
			});
		});

		describe('cross-field validation (Bugs 4, 5, 6)', () =>
		{
			it('rejects both day fields as ? (Bug 4)', () =>
			{
				let result = validateCronExpression('0 0 9 ? * ?');
				expect(result.isValid).toBe(false);
				expect(result.errorMessage).toContain('both cannot be ?');
			});

			it('rejects both day fields as * (Bug 5)', () =>
			{
				let result = validateCronExpression('0 0 9 * * *');
				expect(result.isValid).toBe(false);
				expect(result.errorMessage).toContain('set one field to ?');
			});

			it('rejects both day fields with concrete values — named day (Bug 6)', () =>
			{
				let result = validateCronExpression('0 0 12 15 * MON');
				expect(result.isValid).toBe(false);
				expect(result.errorMessage).toContain('set one field to ?');
			});

			it('rejects both day fields with concrete values — numeric day (Bug 6)', () =>
			{
				let result = validateCronExpression('0 0 12 15 * 2');
				expect(result.isValid).toBe(false);
				expect(result.errorMessage).toContain('set one field to ?');
			});
		});

		describe('impossible date validation', () =>
		{
			it('rejects Feb 31', () =>
			{
				let result = validateCronExpression('0 0 9 31 2 ?');
				expect(result.isValid).toBe(false);
				expect(result.errorMessage).toContain('does not exist in FEB');
			});

			it('rejects Feb 30', () =>
			{
				let result = validateCronExpression('0 0 9 30 2 ?');
				expect(result.isValid).toBe(false);
				expect(result.errorMessage).toContain('does not exist in FEB');
			});

			it('rejects Apr 31', () =>
			{
				let result = validateCronExpression('0 0 9 31 4 ?');
				expect(result.isValid).toBe(false);
				expect(result.errorMessage).toContain('does not exist in APR');
			});

			it('rejects Jun 31', () =>
			{
				let result = validateCronExpression('0 0 9 31 6 ?');
				expect(result.isValid).toBe(false);
				expect(result.errorMessage).toContain('does not exist in JUN');
			});

			it('rejects Sep 31', () =>
			{
				let result = validateCronExpression('0 0 9 31 9 ?');
				expect(result.isValid).toBe(false);
				expect(result.errorMessage).toContain('does not exist in SEP');
			});

			it('rejects Nov 31', () =>
			{
				let result = validateCronExpression('0 0 9 31 11 ?');
				expect(result.isValid).toBe(false);
				expect(result.errorMessage).toContain('does not exist in NOV');
			});

			it('rejects 31W in Feb', () =>
			{
				let result = validateCronExpression('0 0 9 31W 2 ?');
				expect(result.isValid).toBe(false);
				expect(result.errorMessage).toContain('does not exist in FEB');
			});

			it('rejects Feb 31 with month name', () =>
			{
				let result = validateCronExpression('0 0 9 31 FEB ?');
				expect(result.isValid).toBe(false);
				expect(result.errorMessage).toContain('does not exist in FEB');
			});

			it('accepts Jan 31', () =>
			{
				let result = validateCronExpression('0 0 9 31 1 ?');
				expect(result.isValid).toBe(true);
			});

			it('accepts Feb 28', () =>
			{
				let result = validateCronExpression('0 0 9 28 2 ?');
				expect(result.isValid).toBe(true);
			});

			it('accepts Feb 29 (leap year possible)', () =>
			{
				let result = validateCronExpression('0 0 9 29 2 ?');
				expect(result.isValid).toBe(true);
			});

			it('skips validation when month is wildcard', () =>
			{
				let result = validateCronExpression('0 0 9 31 * ?');
				expect(result.isValid).toBe(true);
			});

			it('skips validation when dayOfMonth is wildcard', () =>
			{
				let result = validateCronExpression('0 0 9 * 2 ?');
				expect(result.isValid).toBe(true);
			});

			it('skips validation when dayOfMonth uses step syntax', () =>
			{
				let result = validateCronExpression('0 0 9 */3 2 ?');
				expect(result.isValid).toBe(true);
			});
		});

		describe('past year validation', () =>
		{
			it('rejects year 2020 as past', () =>
			{
				let result = validateCronExpression('0 0 9 * * ? 2020');
				expect(result.isValid).toBe(false);
				expect(result.errorMessage).toContain('in the past');
			});

			it('rejects year 2000 as past', () =>
			{
				let result = validateCronExpression('0 0 9 * * ? 2000');
				expect(result.isValid).toBe(false);
				expect(result.errorMessage).toContain('in the past');
			});

			it('accepts current or future year', () =>
			{
				let currentYear = new Date().getFullYear();
				let result = validateCronExpression(`0 0 9 * * ? ${currentYear}`);
				expect(result.isValid).toBe(true);
			});

			it('accepts year 2099', () =>
			{
				let result = validateCronExpression('0 0 9 * * ? 2099');
				expect(result.isValid).toBe(true);
			});
		});

		describe('N/M step syntax in full expressions', () =>
		{
			it('accepts 5/2 in hours field', () =>
			{
				let result = validateCronExpression('0 0 5/2 * * ?');
				expect(result.isValid).toBe(true);
			});

			it('accepts 1/7 in dayOfMonth field', () =>
			{
				let result = validateCronExpression('0 0 9 1/7 * ?');
				expect(result.isValid).toBe(true);
			});

			it('accepts */3 in dayOfMonth field', () =>
			{
				let result = validateCronExpression('0 0 9 */3 * ?');
				expect(result.isValid).toBe(true);
			});
		});

		describe('valid expressions', () =>
		{
			it('accepts daily expression', () =>
			{
				let result = validateCronExpression('0 0 12 * * ?');
				expect(result.isValid).toBe(true);
				expect(result.errorMessage).toBe('');
			});

			it('accepts weekly expression', () =>
			{
				let result = validateCronExpression('0 0 9 ? * MON,WED,FRI');
				expect(result.isValid).toBe(true);
			});

			it('accepts monthly expression', () =>
			{
				let result = validateCronExpression('0 0 8 15 * ?');
				expect(result.isValid).toBe(true);
			});

			it('accepts L with ? dayOfWeek', () =>
			{
				let result = validateCronExpression('0 0 12 L * ?');
				expect(result.isValid).toBe(true);
			});

			it('accepts FRI#1 with ? dayOfMonth', () =>
			{
				let result = validateCronExpression('0 0 3 ? * FRI#1');
				expect(result.isValid).toBe(true);
			});

			it('accepts expression with year', () =>
			{
				let result = validateCronExpression('0 0 12 * * ? 2026');
				expect(result.isValid).toBe(true);
			});
		});
	});
});
