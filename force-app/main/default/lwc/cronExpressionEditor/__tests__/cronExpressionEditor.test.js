// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for cronExpressionEditor LWC component.
 *
 * @author Jason van Beukering
 * @date February 2026, October 2026
 */

// Resolve every CronExpressionEditor_* label to its real value, so the exact-string
// assertions check that values are inserted into the text exactly (in jest a label otherwise
// resolves to 'c.X'). The values are copied from the CustomLabels entries.
jest.mock('@salesforce/label/c.CronExpressionEditor_FreqEveryNMinutes', () => ({default: 'Every N Minutes'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_FreqHourly', () => ({default: 'Hourly'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_FreqDaily', () => ({default: 'Daily'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_FreqWeekly', () => ({default: 'Weekly'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_FreqMonthly', () => ({default: 'Monthly'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_IntervalEvery5', () => ({default: 'Every 5 minutes'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_IntervalEvery10', () => ({default: 'Every 10 minutes'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_IntervalEvery15', () => ({default: 'Every 15 minutes'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_IntervalEvery30', () => ({default: 'Every 30 minutes'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_DaySunday', () => ({default: 'Sunday'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_DayMonday', () => ({default: 'Monday'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_DayTuesday', () => ({default: 'Tuesday'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_DayWednesday', () => ({default: 'Wednesday'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_DayThursday', () => ({default: 'Thursday'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_DayFriday', () => ({default: 'Friday'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_DaySaturday', () => ({default: 'Saturday'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_ModePreset', () => ({default: 'Preset'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_ModeAdvanced', () => ({default: 'Advanced'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_ModeCustom', () => ({default: 'Custom'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_ModeLabel', () => ({default: 'Mode'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_FrequencyLabel', () => ({default: 'Frequency'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_IntervalLabel', () => ({default: 'Interval'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_AtMinuteLabel', () => ({default: 'At Minute'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_HourLabel', () => ({default: 'Hour'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_MinuteLabel', () => ({default: 'Minute'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_DaysLabel', () => ({default: 'Days'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_DayOfMonthLabel', () => ({default: 'Day of Month'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_SecondsLabel', () => ({default: 'Seconds'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_MinutesLabel', () => ({default: 'Minutes'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_HoursLabel', () => ({default: 'Hours'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_MonthLabel', () => ({default: 'Month'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_DayOfWeekHelp', () => ({default: '1-7, SUN-SAT, ?, L, #, e.g. FRI#1'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_DayOfWeekLabel', () => ({default: 'Day of Week'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_YearHelp', () => ({default: '1970-2099 or leave empty'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_YearOptionalLabel', () => ({default: 'Year (Optional)'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_CronExpressionLabel', () => ({default: 'Cron Expression'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_PreviewLabel', () => ({default: 'Preview'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_PresetModeUnrepresentable',
		() => ({default: 'This expression cannot be represented in Preset mode. Use Advanced or Custom mode instead.'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_OrdinalFirst', () => ({default: 'First'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_OrdinalSecond', () => ({default: 'Second'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_OrdinalThird', () => ({default: 'Third'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_OrdinalFourth', () => ({default: 'Fourth'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_OrdinalFifth', () => ({default: 'Fifth'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_DayListTwo', () => ({default: '{0} and {1}'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_DayListConjunction', () => ({default: ', and {0}'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_DescEveryNMinutes', () => ({default: 'Every {0} minutes'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_DescHourly', () => ({default: 'Every hour at minute {0}'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_DescDaily', () => ({default: 'Every day at {0}'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_DescDailyInMonth', () => ({default: 'Every day in month {0} at {1}'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_DescNthWeekday', () => ({default: '{0} {1} of every month at {2}'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_DescLastWeekday', () => ({default: 'Last {0} of every month at {1}'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_DescWeekdays', () => ({default: 'Every weekday (Monday through Friday) at {0}'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_DescDayRange', () => ({default: 'Every {0} through {1} at {2}'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_DescDayList', () => ({default: 'Every {0} at {1}'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_DescLastDay', () => ({default: 'Last day of every month at {0}'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_DescLastWeekdayOfMonth', () => ({default: 'Last weekday of every month at {0}'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_DescInMonthSuffix', () => ({default: 'in month {0}'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_DescNearestWeekday', () => ({default: 'Nearest weekday to day {0} of every month{1} at {2}'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_DescMonthlyOnDay', () => ({default: 'Monthly on day {0}{1} at {2}'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_ValSeconds', () => ({default: 'Enter 0-59'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_ValMinutes',
		() => ({default: 'Enter one minute, 0 to 59. A scheduled job runs at most once an hour, so this field cannot take *, a step such as */15, or a list such as 0,30.'}),
		{virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_ValMinutesJobRunner',
		() => ({default: 'Enter minutes 0 to 59, *, a step such as */15, a range such as 0-30, or a list such as 0,30. The job runner accepts them all.'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_DescEveryNMinutesOnRunner', () => ({default: '{0} on this job runner'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_DescFirstCheckOnOrAfter', () => ({default: 'Runs at the first job runner check on or after each scheduled time'}),
		{virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_IntervalActivateFirstNote', () => ({default: 'Activate the job runner in Health Check first; until then the job waits.'}),
		{virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_ValHours', () => ({default: 'Enter 0-23, *, */N, N/N, or comma/range lists'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_ValDayOfMonth', () => ({default: 'Enter 1-31, *, ?, L, W, LW, */N, N/N, or comma/range lists'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_ValMonth', () => ({default: 'Enter 1-12, *, JAN-DEC, or comma/range lists'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_ValDayOfWeek', () => ({default: 'Enter 1-7, SUN-SAT, ?, L, or # patterns'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_ValYear', () => ({default: 'Enter a year (1970-2099) or leave empty'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_ValYearInPast', () => ({default: 'Year {0} is in the past — the job will never fire'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_ValOutOfRange', () => ({default: 'Value {0} is out of range ({1}-{2})'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_ValHashDay', () => ({default: 'Day in # expression must be 1-7'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_ValHashOccurrence', () => ({default: 'Occurrence in # expression must be 1-5'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_ValStepMin', () => ({default: 'Step value must be at least 1'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_ValStepMax', () => ({default: 'Step value {0} exceeds maximum {1}'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_ValBaseOutOfRange', () => ({default: 'Base value {0} is out of range ({1}-{2})'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_ValRangeReversed', () => ({default: 'Range {0}-{1} is invalid — start must not exceed end'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_ValDayNotInMonth', () => ({default: 'Day {0} does not exist in {1} (max {2} days)'}), {virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_ValBothQuestion', () => ({default: 'Exactly one of Day of Month or Day of Week must be ? — both cannot be ?'}),
		{virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_ValNeitherQuestion', () => ({default: 'Exactly one of Day of Month or Day of Week must be ? — set one field to ?'}),
		{virtual: true});
jest.mock('@salesforce/label/c.CronExpressionEditor_ValStructure', () => ({default: 'Invalid cron expression — must have 6 or 7 space-separated fields'}), {virtual: true});
import {createElement} from 'lwc';
import {validateCronExpression} from '../cronParser';

describe('c-cron-expression-editor', () =>
{
	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
		jest.clearAllMocks();
	});

	describe('module exports', () =>
	{
		it('exports default as a function', () =>
		{
			const CronExpressionEditor = require('c/cronExpressionEditor').default;
			expect(CronExpressionEditor).toBeDefined();
			expect(typeof CronExpressionEditor).toBe('function');
		});

		it('exports describeCronExpression function', () =>
		{
			const {describeCronExpression} = require('c/cronExpressionEditor');
			expect(describeCronExpression).toBeDefined();
			expect(typeof describeCronExpression).toBe('function');
		});

		it('exports validateCronField function', () =>
		{
			const {validateCronField} = require('c/cronExpressionEditor');
			expect(validateCronField).toBeDefined();
			expect(typeof validateCronField).toBe('function');
		});

		it('exports validateCronExpression function', () =>
		{
			const {validateCronExpression: exportedValidateCronExpression} = require('c/cronExpressionEditor');
			expect(exportedValidateCronExpression).toBeDefined();
			expect(typeof exportedValidateCronExpression).toBe('function');
		});
	});

	describe('class structure', () =>
	{
		const CronExpressionEditor = require('c/cronExpressionEditor').default;
		const prototype = CronExpressionEditor.prototype;

		it('has @api value property', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'value');
			expect(descriptor).toBeDefined();
			expect(typeof descriptor.get).toBe('function');
			expect(typeof descriptor.set).toBe('function');
		});

		it('has @api cronExpression getter', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'cronExpression');
			expect(descriptor).toBeDefined();
			expect(typeof descriptor.get).toBe('function');
		});

		it('has @api isValid getter', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'isValid');
			expect(descriptor).toBeDefined();
			expect(typeof descriptor.get).toBe('function');
		});

		it('has cronDescription getter', () =>
		{
			let descriptor = Object.getOwnPropertyDescriptor(prototype, 'cronDescription');
			expect(descriptor).toBeDefined();
			expect(typeof descriptor.get).toBe('function');
		});

		it('has mode-checking getters', () =>
		{
			let getterNames = [
				'isPresetMode',
				'isAdvancedMode',
				'isCustomMode'
			];
			getterNames.forEach((name) =>
			{
				let descriptor = Object.getOwnPropertyDescriptor(prototype, name);
				expect(descriptor).toBeDefined();
				expect(typeof descriptor.get).toBe('function');
			});
		});

		it('has preset frequency getters', () =>
		{
			let getterNames = [
				'isEveryNMinutes',
				'isHourly',
				'isDaily',
				'isWeekly',
				'isMonthly',
				'showHourMinute'
			];
			getterNames.forEach((name) =>
			{
				let descriptor = Object.getOwnPropertyDescriptor(prototype, name);
				expect(descriptor).toBeDefined();
				expect(typeof descriptor.get).toBe('function');
			});
		});

		it('has option getter properties', () =>
		{
			let getterNames = [
				'modeOptions',
				'presetFrequencies',
				'minuteIntervals',
				'daysOfWeekOptions',
				'hoursOptions',
				'minutesOptions',
				'dayOfMonthOptions',
				'secondsOptions',
				'currentExpression'
			];
			getterNames.forEach((name) =>
			{
				let descriptor = Object.getOwnPropertyDescriptor(prototype, name);
				expect(descriptor).toBeDefined();
				expect(typeof descriptor.get).toBe('function');
			});
		});

		it('has connectedCallback method', () =>
		{
			expect(typeof prototype.connectedCallback).toBe('function');
		});

		it('has handler methods', () =>
		{
			let methodNames = [
				'handleModeChange',
				'handleFrequencyChange',
				'handleMinuteIntervalChange',
				'handlePresetMinuteChange',
				'handlePresetHourChange',
				'handleDaysOfWeekChange',
				'handlePresetDayOfMonthChange',
				'handleAdvancedSecondsChange',
				'handleAdvancedMinutesChange',
				'handleAdvancedHoursChange',
				'handleAdvancedDayOfMonthChange',
				'handleAdvancedMonthChange',
				'handleAdvancedDayOfWeekChange',
				'handleAdvancedYearChange',
				'handleCustomExpressionChange'
			];
			methodNames.forEach((name) =>
			{
				expect(typeof prototype[name]).toBe('function');
			});
		});
	});

	describe('instance behavior', () =>
	{
		const CronExpressionEditor = require('c/cronExpressionEditor').default;
		const prototype = CronExpressionEditor.prototype;

		const HOURS_IN_DAY = 24;
		const MINUTES_IN_HOUR = 60;
		const SECONDS_IN_MINUTE = 60;
		const DAYS_IN_MONTH = 31;

		const getGetter = (name) =>
		{
			return Object.getOwnPropertyDescriptor(prototype, name).get;
		};

		// Accessors the mock context reads from the prototype, so a getter under test sees the same
		// chain of getters the rendered component does.
		const CONTEXT_ACCESSORS = [
			'parserOptions',
			'presetFrequencies',
			'minuteIntervals',
			'showActivateFirstNote',
			'minutesHelp',
			'isEveryNMinutes'
		];

		const createMockContext = (overrides = {}) =>
		{
			let {jobRunnerMode, ...otherOverrides} = overrides;
			let context = {
				_value: undefined,
				_jobRunnerMode: jobRunnerMode === true,
				activeCheckIntervalMinutes: null,
				mode: 'preset',
				presetFrequency: 'daily',
				presetMinuteInterval: '5',
				presetMinute: '0',
				presetHour: '12',
				presetDaysOfWeek: [],
				presetDayOfMonth: '1',
				advancedSeconds: '0',
				advancedMinutes: '0',
				advancedHours: '12',
				advancedDayOfMonth: '*',
				advancedMonth: '*',
				advancedDayOfWeek: '?',
				advancedYear: '',
				customExpression: '0 0 12 * * ?',
				dispatchEvent: jest.fn(),
				showErrorToast: jest.fn(),
				template: {querySelectorAll: jest.fn(() => [])},
				parseAndPopulate: prototype.parseAndPopulate,
				applyPreset: prototype.applyPreset,
				buildCurrentExpression: prototype.buildCurrentExpression,
				dispatchChangeEvent: prototype.dispatchChangeEvent,
				connectedCallback: prototype.connectedCallback, ...otherOverrides
			};
			CONTEXT_ACCESSORS.forEach((name) =>
			{
				Object.defineProperty(context, name, {...Object.getOwnPropertyDescriptor(prototype, name), configurable: true});
			});
			Object.defineProperty(context, 'isValid', {
				get()
				{
					return validateCronExpression(this.buildCurrentExpression()).isValid;
				}, configurable: true
			});
			return context;
		};

		describe('connectedCallback', () =>
		{
			it('dispatches initial cronchange event with default expression', () =>
			{
				let context = createMockContext();
				prototype.connectedCallback.call(context);
				expect(context.dispatchEvent).toHaveBeenCalledTimes(1);
				let event = context.dispatchEvent.mock.calls[0][0];
				expect(event.type).toBe('cronchange');
				expect(event.detail.value).toBe('0 0 12 * * ?');
				expect(event.detail.isValid).toBe(true);
			});

			it('dispatches cronchange with custom expression when value is set', () =>
			{
				let context = createMockContext({customExpression: '0 0 9 ? * MON', mode: 'custom'});
				prototype.connectedCallback.call(context);
				let event = context.dispatchEvent.mock.calls[0][0];
				expect(event.detail.value).toBe('0 0 9 ? * MON');
			});
		});

		describe('parseAndPopulate (value setter logic)', () =>
		{
			it('sets mode to preset for daily expression', () =>
			{
				let context = createMockContext();
				prototype.parseAndPopulate.call(context, '0 0 12 * * ?');
				expect(context.mode).toBe('preset');
				expect(context.presetFrequency).toBe('daily');
			});

			it('sets mode to advanced for non-preset expression', () =>
			{
				let context = createMockContext();
				prototype.parseAndPopulate.call(context, '0 0 12 L * ?');
				expect(context.mode).toBe('advanced');
			});

			it('sets mode to custom for invalid expression', () =>
			{
				let context = createMockContext();
				prototype.parseAndPopulate.call(context, 'invalid');
				expect(context.mode).toBe('custom');
			});

			it('populates weekly preset with days', () =>
			{
				let context = createMockContext();
				prototype.parseAndPopulate.call(context, '0 0 9 ? * MON,WED');
				expect(context.mode).toBe('preset');
				expect(context.presetFrequency).toBe('weekly');
				expect(context.presetDaysOfWeek).toEqual([
					'MON',
					'WED'
				]);
			});

			it('populates monthly preset', () =>
			{
				let context = createMockContext();
				prototype.parseAndPopulate.call(context, '0 0 8 15 * ?');
				expect(context.mode).toBe('preset');
				expect(context.presetFrequency).toBe('monthly');
				expect(context.presetDayOfMonth).toBe('15');
			});

			it('populates advanced mode for a stepped minutes field', () =>
			{
				let context = createMockContext();
				prototype.parseAndPopulate.call(context, '0 */15 * * * ?');
				expect(context.mode).toBe('advanced');
				expect(context.advancedMinutes).toBe('*/15');
			});

			it('populates hourly preset', () =>
			{
				let context = createMockContext();
				prototype.parseAndPopulate.call(context, '0 45 * * * ?');
				expect(context.mode).toBe('preset');
				expect(context.presetFrequency).toBe('hourly');
				expect(context.presetMinute).toBe('45');
			});

			it('populates advanced year field', () =>
			{
				let context = createMockContext();
				prototype.parseAndPopulate.call(context, '0 0 12 * * ? 2026');
				expect(context.mode).toBe('advanced');
				expect(context.advancedYear).toBe('2026');
			});

			it('defaults custom expression when null', () =>
			{
				let context = createMockContext();
				prototype.parseAndPopulate.call(context, null);
				expect(context.mode).toBe('preset');
			});
		});

		describe('currentExpression getter', () =>
		{
			it('returns built expression for preset mode', () =>
			{
				let context = createMockContext();
				let getter = getGetter('currentExpression');
				expect(getter.call(context)).toBe('0 0 12 * * ?');
			});
		});

		describe('cronDescription getter', () =>
		{
			it('returns human-readable description', () =>
			{
				let context = createMockContext();
				let getter = getGetter('cronDescription');
				expect(getter.call(context)).toBe('Every day at 12:00 PM');
			});
		});

		describe('mode getters', () =>
		{
			it('isPresetMode returns true in preset mode', () =>
			{
				let context = createMockContext({mode: 'preset'});
				let getter = getGetter('isPresetMode');
				expect(getter.call(context)).toBe(true);
			});

			it('isAdvancedMode returns true in advanced mode', () =>
			{
				let context = createMockContext({mode: 'advanced'});
				let getter = getGetter('isAdvancedMode');
				expect(getter.call(context)).toBe(true);
			});

			it('isCustomMode returns true in custom mode', () =>
			{
				let context = createMockContext({mode: 'custom'});
				let getter = getGetter('isCustomMode');
				expect(getter.call(context)).toBe(true);
			});

			it('isPresetMode returns false in advanced mode', () =>
			{
				let context = createMockContext({mode: 'advanced'});
				let getter = getGetter('isPresetMode');
				expect(getter.call(context)).toBe(false);
			});
		});

		describe('frequency getters', () =>
		{
			it('isEveryNMinutes returns true for everyNMinutes', () =>
			{
				let context = createMockContext({presetFrequency: 'everyNMinutes'});
				let getter = getGetter('isEveryNMinutes');
				expect(getter.call(context)).toBe(true);
			});

			it('isHourly returns true for hourly', () =>
			{
				let context = createMockContext({presetFrequency: 'hourly'});
				let getter = getGetter('isHourly');
				expect(getter.call(context)).toBe(true);
			});

			it('isDaily returns true for daily', () =>
			{
				let context = createMockContext({presetFrequency: 'daily'});
				let getter = getGetter('isDaily');
				expect(getter.call(context)).toBe(true);
			});

			it('isWeekly returns true for weekly', () =>
			{
				let context = createMockContext({presetFrequency: 'weekly'});
				let getter = getGetter('isWeekly');
				expect(getter.call(context)).toBe(true);
			});

			it('isMonthly returns true for monthly', () =>
			{
				let context = createMockContext({presetFrequency: 'monthly'});
				let getter = getGetter('isMonthly');
				expect(getter.call(context)).toBe(true);
			});
		});

		describe('showHourMinute getter', () =>
		{
			it('returns true for daily', () =>
			{
				let context = createMockContext({presetFrequency: 'daily'});
				Object.defineProperty(context, 'isDaily', {get: () => true});
				Object.defineProperty(context, 'isWeekly', {get: () => false});
				Object.defineProperty(context, 'isMonthly', {get: () => false});
				let getter = Object.getOwnPropertyDescriptor(prototype, 'showHourMinute').get;
				expect(getter.call(context)).toBe(true);
			});

			it('returns true for weekly', () =>
			{
				let context = createMockContext({presetFrequency: 'weekly'});
				Object.defineProperty(context, 'isDaily', {get: () => false});
				Object.defineProperty(context, 'isWeekly', {get: () => true});
				Object.defineProperty(context, 'isMonthly', {get: () => false});
				let getter = Object.getOwnPropertyDescriptor(prototype, 'showHourMinute').get;
				expect(getter.call(context)).toBe(true);
			});

			it('returns true for monthly', () =>
			{
				let context = createMockContext({presetFrequency: 'monthly'});
				Object.defineProperty(context, 'isDaily', {get: () => false});
				Object.defineProperty(context, 'isWeekly', {get: () => false});
				Object.defineProperty(context, 'isMonthly', {get: () => true});
				let getter = Object.getOwnPropertyDescriptor(prototype, 'showHourMinute').get;
				expect(getter.call(context)).toBe(true);
			});

			it('returns false for hourly', () =>
			{
				let context = createMockContext({presetFrequency: 'hourly'});
				Object.defineProperty(context, 'isDaily', {get: () => false});
				Object.defineProperty(context, 'isWeekly', {get: () => false});
				Object.defineProperty(context, 'isMonthly', {get: () => false});
				let getter = Object.getOwnPropertyDescriptor(prototype, 'showHourMinute').get;
				expect(getter.call(context)).toBe(false);
			});

			it('returns false for everyNMinutes', () =>
			{
				let context = createMockContext({presetFrequency: 'everyNMinutes'});
				Object.defineProperty(context, 'isDaily', {get: () => false});
				Object.defineProperty(context, 'isWeekly', {get: () => false});
				Object.defineProperty(context, 'isMonthly', {get: () => false});
				let getter = Object.getOwnPropertyDescriptor(prototype, 'showHourMinute').get;
				expect(getter.call(context)).toBe(false);
			});
		});

		describe('option getters', () =>
		{
			it('modeOptions returns three options', () =>
			{
				let context = createMockContext();
				let getter = Object.getOwnPropertyDescriptor(prototype, 'modeOptions').get;
				expect(getter.call(context)).toHaveLength(3);
			});

			it('presetFrequencies returns four frequencies in own mode', () =>
			{
				let context = createMockContext();
				let getter = Object.getOwnPropertyDescriptor(prototype, 'presetFrequencies').get;
				expect(getter.call(context)).toHaveLength(4);
			});

			it('minuteIntervals returns four intervals', () =>
			{
				let context = createMockContext();
				let getter = Object.getOwnPropertyDescriptor(prototype, 'minuteIntervals').get;
				expect(getter.call(context)).toHaveLength(4);
			});

			it('daysOfWeekOptions returns seven days', () =>
			{
				let context = createMockContext();
				let getter = Object.getOwnPropertyDescriptor(prototype, 'daysOfWeekOptions').get;
				expect(getter.call(context)).toHaveLength(7);
			});

			it('hoursOptions returns 24 hours', () =>
			{
				let context = createMockContext();
				let getter = Object.getOwnPropertyDescriptor(prototype, 'hoursOptions').get;
				expect(getter.call(context)).toHaveLength(HOURS_IN_DAY);
			});

			it('minutesOptions returns 60 minutes', () =>
			{
				let context = createMockContext();
				let getter = Object.getOwnPropertyDescriptor(prototype, 'minutesOptions').get;
				expect(getter.call(context)).toHaveLength(MINUTES_IN_HOUR);
			});

			it('dayOfMonthOptions returns 31 days', () =>
			{
				let context = createMockContext();
				let getter = Object.getOwnPropertyDescriptor(prototype, 'dayOfMonthOptions').get;
				expect(getter.call(context)).toHaveLength(DAYS_IN_MONTH);
			});

			it('secondsOptions returns 60 seconds', () =>
			{
				let context = createMockContext();
				let getter = Object.getOwnPropertyDescriptor(prototype, 'secondsOptions').get;
				expect(getter.call(context)).toHaveLength(SECONDS_IN_MINUTE);
			});
		});

		describe('job runner mode', () =>
		{
			it('offers Every N Minutes only on the job runner, with the intervals the check interval allows', () =>
			{
				let ownMode = createMockContext();
				expect(getGetter('presetFrequencies').call(ownMode).map((option) => option.value)).toEqual([
					'hourly',
					'daily',
					'weekly',
					'monthly'
				]);

				let onRunner = createMockContext({jobRunnerMode: true, activeCheckIntervalMinutes: 15});
				expect(getGetter('presetFrequencies').call(onRunner).map((option) => option.value)).toEqual([
					'everyNMinutes',
					'hourly',
					'daily',
					'weekly',
					'monthly'
				]);
				expect(getGetter('minuteIntervals').call(onRunner).map((option) => option.value)).toEqual([
					'15',
					'30'
				]);

				let noRunner = createMockContext({jobRunnerMode: true, activeCheckIntervalMinutes: null});
				expect(getGetter('minuteIntervals').call(noRunner).map((option) => option.value)).toEqual([
					'5',
					'10',
					'15',
					'30'
				]);
				expect(getGetter('showActivateFirstNote').call(createMockContext({jobRunnerMode: true, activeCheckIntervalMinutes: null, presetFrequency: 'everyNMinutes'})))
				.toBe(true);

				let everyHour = createMockContext({jobRunnerMode: true, activeCheckIntervalMinutes: 60});
				expect(getGetter('presetFrequencies').call(everyHour).map((option) => option.value)).toEqual([
					'hourly',
					'daily',
					'weekly',
					'monthly'
				]);
			});

			it('keeps the interval a saved job already uses, even when the runner no longer checks that often', () =>
			{
				let context = createMockContext({jobRunnerMode: true, activeCheckIntervalMinutes: 15, presetFrequency: 'everyNMinutes', presetMinuteInterval: '5'});
				expect(getGetter('minuteIntervals').call(context).map((option) => option.value)).toEqual([
					'5',
					'15',
					'30'
				]);
			});

			it('keeps Every N Minutes while a saved job is using it, even when no interval survives', () =>
			{
				let context = createMockContext({jobRunnerMode: true, activeCheckIntervalMinutes: 60, presetFrequency: 'everyNMinutes'});
				expect(getGetter('presetFrequencies').call(context).map((option) => option.value)).toEqual([
					'everyNMinutes',
					'hourly',
					'daily',
					'weekly',
					'monthly'
				]);
			});

			it('spells the minutes grammar each mode accepts in the advanced field help', () =>
			{
				expect(getGetter('minutesHelp').call(createMockContext())).toBe('0-59');
				expect(getGetter('minutesHelp').call(createMockContext({jobRunnerMode: true}))).toBe('0-59, *, */N, N/N, N,N, N-N');
			});
		});

		describe('isValid getter (tested via DOM in class instantiation)', () =>
		{
			it('exists on prototype', () =>
			{
				let descriptor = Object.getOwnPropertyDescriptor(prototype, 'isValid');
				expect(descriptor).toBeDefined();
				expect(typeof descriptor.get).toBe('function');
			});
		});

		describe('showValidationError getter', () =>
		{
			it('returns false when expression is valid', () =>
			{
				let context = createMockContext();
				let getter = getGetter('showValidationError');
				expect(getter.call(context)).toBe(false);
			});

			it('returns true when expression is invalid', () =>
			{
				let context = createMockContext({mode: 'custom', customExpression: 'invalid'});
				let getter = getGetter('showValidationError');
				expect(getter.call(context)).toBe(true);
			});
		});

		describe('validationMessage getter', () =>
		{
			it('returns empty string when valid', () =>
			{
				let context = createMockContext();
				let getter = getGetter('validationMessage');
				expect(getter.call(context)).toBe('');
			});

			it('returns structural error for invalid custom expression', () =>
			{
				let context = createMockContext({mode: 'custom', customExpression: 'invalid'});
				let getter = getGetter('validationMessage');
				expect(getter.call(context)).toContain('must have 6 or 7 space-separated fields');
			});

			it('returns field-specific error for out-of-range hour in custom mode', () =>
			{
				let context = createMockContext({mode: 'custom', customExpression: '0 0 25 * * ?'});
				let getter = getGetter('validationMessage');
				expect(getter.call(context)).toContain('hours');
			});

			it('returns field-specific error for invalid advanced field', () =>
			{
				let context = createMockContext({mode: 'advanced', advancedMinutes: 'abc'});
				let getter = getGetter('validationMessage');
				expect(getter.call(context)).toContain('minutes');
			});

			it('returns structural error for invalid preset expression', () =>
			{
				let context = createMockContext({mode: 'preset'});
				context.buildCurrentExpression = () => '0 0';
				let getter = getGetter('validationMessage');
				expect(getter.call(context)).toContain('6 or 7 space-separated fields');
			});
		});

		describe('handler methods', () =>
		{
			it('handleModeChange updates mode and dispatches cronchange', () =>
			{
				let context = createMockContext();
				prototype.handleModeChange.call(context, {detail: {value: 'advanced'}});
				expect(context.mode).toBe('advanced');
				expect(context.dispatchEvent).toHaveBeenCalledTimes(1);
			});

			it('handleModeChange preserves expression when switching to custom', () =>
			{
				let context = createMockContext({mode: 'preset', presetFrequency: 'daily', presetHour: '9', presetMinute: '30'});
				prototype.handleModeChange.call(context, {detail: {value: 'custom'}});
				expect(context.mode).toBe('custom');
				expect(context.customExpression).toBe('0 30 9 * * ?');
			});

			it('handleModeChange populates advanced fields when switching from preset', () =>
			{
				let context = createMockContext({mode: 'preset', presetFrequency: 'daily', presetHour: '9', presetMinute: '30'});
				prototype.handleModeChange.call(context, {detail: {value: 'advanced'}});
				expect(context.mode).toBe('advanced');
				expect(context.advancedSeconds).toBe('0');
				expect(context.advancedMinutes).toBe('30');
				expect(context.advancedHours).toBe('9');
			});

			it('handleModeChange populates preset fields when switching from advanced', () =>
			{
				let context = createMockContext({
					mode: 'advanced',
					advancedSeconds: '0',
					advancedMinutes: '0',
					advancedHours: '8',
					advancedDayOfMonth: '15',
					advancedMonth: '*',
					advancedDayOfWeek: '?',
					advancedYear: ''
				});
				prototype.handleModeChange.call(context, {detail: {value: 'preset'}});
				expect(context.mode).toBe('preset');
				expect(context.presetFrequency).toBe('monthly');
				expect(context.presetDayOfMonth).toBe('15');
				expect(context.presetHour).toBe('8');
			});

			it('handleModeChange does not overwrite customExpression when switching to advanced', () =>
			{
				let context = createMockContext({mode: 'preset', customExpression: 'original'});
				prototype.handleModeChange.call(context, {detail: {value: 'advanced'}});
				expect(context.customExpression).toBe('original');
			});

			it('handleModeChange warns and stays in current mode when switching to preset with incompatible expression', async() =>
			{
				let context = createMockContext({
					mode: 'advanced',
					advancedSeconds: '0',
					advancedMinutes: '0',
					advancedHours: '17',
					advancedDayOfMonth: 'LW',
					advancedMonth: '*',
					advancedDayOfWeek: '?',
					advancedYear: ''
				});
				context.showWarningToast = jest.fn();
				prototype.handleModeChange.call(context, {detail: {value: 'preset'}, target: {value: 'preset'}});
				expect(context.showWarningToast).toHaveBeenCalledTimes(1);
				expect(context.dispatchEvent).not.toHaveBeenCalled();
				await Promise.resolve();
				expect(context.mode).toBe('advanced');
			});

			it('handleModeChange switches to preset when expression is compatible', () =>
			{
				let context = createMockContext({
					mode: 'advanced',
					advancedSeconds: '0',
					advancedMinutes: '30',
					advancedHours: '9',
					advancedDayOfMonth: '*',
					advancedMonth: '*',
					advancedDayOfWeek: '?',
					advancedYear: ''
				});
				context.showWarningToast = jest.fn();
				prototype.handleModeChange.call(context, {detail: {value: 'preset'}});
				expect(context.mode).toBe('preset');
				expect(context.showWarningToast).not.toHaveBeenCalled();
				expect(context.dispatchEvent).toHaveBeenCalledTimes(1);
			});

			it('handleFrequencyChange updates frequency and dispatches cronchange', () =>
			{
				let context = createMockContext();
				prototype.handleFrequencyChange.call(context, {detail: {value: 'weekly'}});
				expect(context.presetFrequency).toBe('weekly');
				expect(context.dispatchEvent).toHaveBeenCalledTimes(1);
			});

			it('handleFrequencyChange auto-selects MON when switching to weekly with no days', () =>
			{
				let context = createMockContext({presetDaysOfWeek: []});
				prototype.handleFrequencyChange.call(context, {detail: {value: 'weekly'}});
				expect(context.presetDaysOfWeek).toEqual(['MON']);
			});

			it('handleFrequencyChange preserves existing days when switching to weekly', () =>
			{
				let context = createMockContext({
					presetDaysOfWeek: [
						'TUE',
						'THU'
					]
				});
				prototype.handleFrequencyChange.call(context, {detail: {value: 'weekly'}});
				expect(context.presetDaysOfWeek).toEqual([
					'TUE',
					'THU'
				]);
			});

			it('handleFrequencyChange moves a fresh Every N Minutes choice to an interval the active runner can hit', () =>
			{
				let context = createMockContext({jobRunnerMode: true, activeCheckIntervalMinutes: 15});
				prototype.handleFrequencyChange.call(context, {detail: {value: 'everyNMinutes'}});
				expect(context.presetMinuteInterval).toBe('15');
			});

			it('handleFrequencyChange keeps an interval the active runner already hits', () =>
			{
				let context = createMockContext({jobRunnerMode: true, activeCheckIntervalMinutes: 15, presetMinuteInterval: '30'});
				prototype.handleFrequencyChange.call(context, {detail: {value: 'everyNMinutes'}});
				expect(context.presetMinuteInterval).toBe('30');
			});

			it('handleFrequencyChange keeps the interval while no runner is active, and while none of them fits the runner', () =>
			{
				let noRunner = createMockContext({jobRunnerMode: true, activeCheckIntervalMinutes: null});
				prototype.handleFrequencyChange.call(noRunner, {detail: {value: 'everyNMinutes'}});
				expect(noRunner.presetMinuteInterval).toBe('5');

				let hourlyRunner = createMockContext({jobRunnerMode: true, activeCheckIntervalMinutes: 60});
				prototype.handleFrequencyChange.call(hourlyRunner, {detail: {value: 'everyNMinutes'}});
				expect(hourlyRunner.presetMinuteInterval).toBe('5');
			});

			it('handleMinuteIntervalChange updates interval and dispatches cronchange', () =>
			{
				let context = createMockContext();
				prototype.handleMinuteIntervalChange.call(context, {detail: {value: '15'}});
				expect(context.presetMinuteInterval).toBe('15');
				expect(context.dispatchEvent).toHaveBeenCalledTimes(1);
			});

			it('handlePresetMinuteChange updates minute and dispatches cronchange', () =>
			{
				let context = createMockContext();
				prototype.handlePresetMinuteChange.call(context, {detail: {value: '30'}});
				expect(context.presetMinute).toBe('30');
				expect(context.dispatchEvent).toHaveBeenCalledTimes(1);
			});

			it('handlePresetHourChange updates hour and dispatches cronchange', () =>
			{
				let context = createMockContext();
				prototype.handlePresetHourChange.call(context, {detail: {value: '9'}});
				expect(context.presetHour).toBe('9');
				expect(context.dispatchEvent).toHaveBeenCalledTimes(1);
			});

			it('handleDaysOfWeekChange updates days and dispatches cronchange', () =>
			{
				let context = createMockContext();
				prototype.handleDaysOfWeekChange.call(context, {
					detail: {
						value: [
							'MON',
							'FRI'
						]
					}
				});
				expect(context.presetDaysOfWeek).toEqual([
					'MON',
					'FRI'
				]);
				expect(context.dispatchEvent).toHaveBeenCalledTimes(1);
			});

			it('handlePresetDayOfMonthChange updates day and dispatches cronchange', () =>
			{
				let context = createMockContext();
				prototype.handlePresetDayOfMonthChange.call(context, {detail: {value: '15'}});
				expect(context.presetDayOfMonth).toBe('15');
				expect(context.dispatchEvent).toHaveBeenCalledTimes(1);
			});

			it('handleAdvancedSecondsChange updates seconds and dispatches cronchange', () =>
			{
				let context = createMockContext();
				prototype.handleAdvancedSecondsChange.call(context, {detail: {value: '30'}});
				expect(context.advancedSeconds).toBe('30');
				expect(context.dispatchEvent).toHaveBeenCalledTimes(1);
			});

			it('handleAdvancedMinutesChange updates minutes and dispatches cronchange', () =>
			{
				let context = createMockContext();
				prototype.handleAdvancedMinutesChange.call(context, {detail: {value: '*/5'}});
				expect(context.advancedMinutes).toBe('*/5');
				expect(context.dispatchEvent).toHaveBeenCalledTimes(1);
			});

			it('handleAdvancedHoursChange updates hours and dispatches cronchange', () =>
			{
				let context = createMockContext();
				prototype.handleAdvancedHoursChange.call(context, {detail: {value: '9'}});
				expect(context.advancedHours).toBe('9');
				expect(context.dispatchEvent).toHaveBeenCalledTimes(1);
			});

			it('handleAdvancedDayOfMonthChange updates dayOfMonth and dispatches cronchange', () =>
			{
				let context = createMockContext();
				prototype.handleAdvancedDayOfMonthChange.call(context, {detail: {value: 'L'}});
				expect(context.advancedDayOfMonth).toBe('L');
				expect(context.dispatchEvent).toHaveBeenCalledTimes(1);
			});

			it('handleAdvancedMonthChange updates month and dispatches cronchange', () =>
			{
				let context = createMockContext();
				prototype.handleAdvancedMonthChange.call(context, {detail: {value: '6'}});
				expect(context.advancedMonth).toBe('6');
				expect(context.dispatchEvent).toHaveBeenCalledTimes(1);
			});

			it('handleAdvancedDayOfWeekChange updates dayOfWeek and dispatches cronchange', () =>
			{
				let context = createMockContext();
				prototype.handleAdvancedDayOfWeekChange.call(context, {detail: {value: 'FRI#1'}});
				expect(context.advancedDayOfWeek).toBe('FRI#1');
				expect(context.dispatchEvent).toHaveBeenCalledTimes(1);
			});

			it('handleAdvancedYearChange updates year and dispatches cronchange', () =>
			{
				let context = createMockContext();
				prototype.handleAdvancedYearChange.call(context, {detail: {value: '2026'}});
				expect(context.advancedYear).toBe('2026');
				expect(context.dispatchEvent).toHaveBeenCalledTimes(1);
			});

			it('handleCustomExpressionChange updates expression and dispatches cronchange', () =>
			{
				let context = createMockContext({mode: 'custom'});
				prototype.handleCustomExpressionChange.call(context, {detail: {value: '0 0 3 ? * FRI#1'}});
				expect(context.customExpression).toBe('0 0 3 ? * FRI#1');
				expect(context.dispatchEvent).toHaveBeenCalledTimes(1);
			});
		});

		describe('dispatchChangeEvent', () =>
		{
			it('dispatches cronchange event with current expression', () =>
			{
				let context = createMockContext();
				prototype.dispatchChangeEvent.call(context);
				expect(context.dispatchEvent).toHaveBeenCalledTimes(1);
				let event = context.dispatchEvent.mock.calls[0][0];
				expect(event.type).toBe('cronchange');
				expect(event.detail.value).toBe('0 0 12 * * ?');
			});
		});

		describe('buildCurrentExpression', () =>
		{
			it('builds preset expression', () =>
			{
				let context = createMockContext({mode: 'preset', presetFrequency: 'daily', presetHour: '9', presetMinute: '30'});
				let result = prototype.buildCurrentExpression.call(context);
				expect(result).toBe('0 30 9 * * ?');
			});

			it('builds advanced expression', () =>
			{
				let context = createMockContext({
					mode: 'advanced',
					advancedSeconds: '0',
					advancedMinutes: '0',
					advancedHours: '12',
					advancedDayOfMonth: 'L',
					advancedMonth: '*',
					advancedDayOfWeek: '?',
					advancedYear: ''
				});
				let result = prototype.buildCurrentExpression.call(context);
				expect(result).toBe('0 0 12 L * ?');
			});

			it('builds custom expression', () =>
			{
				let context = createMockContext({mode: 'custom', customExpression: '0 0 3 ? * FRI#1'});
				let result = prototype.buildCurrentExpression.call(context);
				expect(result).toBe('0 0 3 ? * FRI#1');
			});
		});
	});

	describe('semantic validation via isValid and validationMessage', () =>
	{
		const CronExpressionEditor = require('c/cronExpressionEditor').default;
		const prototype = CronExpressionEditor.prototype;

		const getGetter = (name) =>
		{
			return Object.getOwnPropertyDescriptor(prototype, name).get;
		};

		const createValidationContext = (overrides = {}) =>
		{
			let context = {
				_value: undefined,
				mode: 'advanced',
				presetFrequency: 'daily',
				presetMinuteInterval: '5',
				presetMinute: '0',
				presetHour: '12',
				presetDaysOfWeek: [],
				presetDayOfMonth: '1',
				advancedSeconds: '0',
				advancedMinutes: '0',
				advancedHours: '12',
				advancedDayOfMonth: '*',
				advancedMonth: '*',
				advancedDayOfWeek: '?',
				advancedYear: '',
				customExpression: '0 0 12 * * ?',
				dispatchEvent: jest.fn(),
				showErrorToast: jest.fn(),
				template: {querySelectorAll: jest.fn(() => [])},
				parseAndPopulate: prototype.parseAndPopulate,
				applyPreset: prototype.applyPreset,
				buildCurrentExpression: prototype.buildCurrentExpression,
				dispatchChangeEvent: prototype.dispatchChangeEvent, ...overrides
			};
			Object.defineProperty(context, 'isValid', {
				get()
				{
					return validateCronExpression(this.buildCurrentExpression()).isValid;
				}, configurable: true
			});
			return context;
		};

		it('isValid returns false for */0 step', () =>
		{
			let context = createValidationContext({advancedHours: '*/0'});
			expect(context.isValid).toBe(false);
		});

		it('isValid returns false for out-of-range list element', () =>
		{
			let context = createValidationContext({advancedHours: '1,2,3,99'});
			expect(context.isValid).toBe(false);
		});

		it('isValid returns false when both day fields are ?', () =>
		{
			let context = createValidationContext({advancedDayOfMonth: '?', advancedDayOfWeek: '?'});
			expect(context.isValid).toBe(false);
		});

		it('isValid returns false when both day fields are *', () =>
		{
			let context = createValidationContext({advancedDayOfMonth: '*', advancedDayOfWeek: '*'});
			expect(context.isValid).toBe(false);
		});

		it('isValid returns false when both day fields have concrete values', () =>
		{
			let context = createValidationContext({advancedDayOfMonth: '15', advancedDayOfWeek: 'MON'});
			expect(context.isValid).toBe(false);
		});

		it('isValid returns false for reversed range', () =>
		{
			let context = createValidationContext({advancedMinutes: '59-0'});
			expect(context.isValid).toBe(false);
		});

		it('validationMessage returns cross-field error for both day fields ?', () =>
		{
			let context = createValidationContext({advancedDayOfMonth: '?', advancedDayOfWeek: '?'});
			let getter = getGetter('validationMessage');
			expect(getter.call(context)).toContain('both cannot be ?');
		});

		it('validationMessage returns field-specific error for */0', () =>
		{
			let context = createValidationContext({advancedHours: '*/0'});
			let getter = getGetter('validationMessage');
			expect(getter.call(context)).toContain('Step value must be at least 1');
		});

		it('handleModeChange keeps the mode and moves the mode buttons back on a rejected preset switch', async() =>
		{
			let context = createValidationContext({
				advancedSeconds: '0', advancedMinutes: '0', advancedHours: '17', advancedDayOfMonth: 'LW', advancedMonth: '*', advancedDayOfWeek: '?', advancedYear: ''
			});
			context.showWarningToast = jest.fn();
			let modeButtons = {value: 'preset'};
			prototype.handleModeChange.call(context, {detail: {value: 'preset'}, target: modeButtons});
			expect(context.mode).toBe('advanced');
			expect(modeButtons.value).toBe('advanced');
			await Promise.resolve();
			expect(context.mode).toBe('advanced');
		});
	});

	describe('validateCronField', () =>
	{
		const {validateCronField} = require('c/cronExpressionEditor');

		it('accepts a single minute only in own mode', () =>
		{
			expect(validateCronField('minutes', '0').isValid).toBe(true);
			expect(validateCronField('minutes', '59').isValid).toBe(true);
			let rejected = [
				'*',
				'*/5',
				'0/5',
				'0,15,30,45',
				'0-30',
				'60'
			];
			expect(rejected.map((value) => ({value, isValid: validateCronField('minutes', value).isValid})))
			.toEqual(rejected.map((value) => ({value, isValid: false})));
			expect(validateCronField('minutes', '*/15').errorMessage)
			.toBe('Enter one minute, 0 to 59. A scheduled job runs at most once an hour, so this field cannot take *, a step such as */15, or a list such as 0,30.');
		});

		it('accepts the wide minutes grammar on the job runner, with its own message', () =>
		{
			const options = {jobRunnerMode: true};
			let accepted = [
				'*',
				'*/5',
				'0/5',
				'0,15,30,45',
				'0-30',
				'7'
			];
			expect(accepted.map((value) => ({value, isValid: validateCronField('minutes', value, options).isValid})))
			.toEqual(accepted.map((value) => ({value, isValid: true})));
			expect(validateCronField('minutes', '60', options).isValid).toBe(false);
			expect(validateCronField('minutes', 'x', options).errorMessage).toContain('The job runner accepts them all');
			expect(validateCronExpression('0 */15 * * * ?').isValid).toBe(false);
			expect(validateCronExpression('0 */15 * * * ?', options).isValid).toBe(true);
		});

		it('rejects invalid minutes values', () =>
		{
			let result = validateCronField('minutes', '0.2');
			expect(result.isValid).toBe(false);
			expect(result.errorMessage).toContain('Enter one minute, 0 to 59');
		});

		it('validates hours field with valid values', () =>
		{
			expect(validateCronField('hours', '0').isValid).toBe(true);
			expect(validateCronField('hours', '23').isValid).toBe(true);
			expect(validateCronField('hours', '*').isValid).toBe(true);
			expect(validateCronField('hours', '*/2').isValid).toBe(true);
		});

		it('validates hours field with comma-separated and range values', () =>
		{
			expect(validateCronField('hours', '9-17').isValid).toBe(true);
			expect(validateCronField('hours', '8,12,18').isValid).toBe(true);
		});

		it('rejects invalid hours values', () =>
		{
			let result = validateCronField('hours', 'abc');
			expect(result.isValid).toBe(false);
			expect(result.errorMessage).toContain('Enter 0-23');
		});

		it('validates dayOfMonth field with valid values', () =>
		{
			expect(validateCronField('dayOfMonth', '1').isValid).toBe(true);
			expect(validateCronField('dayOfMonth', '31').isValid).toBe(true);
			expect(validateCronField('dayOfMonth', '*').isValid).toBe(true);
			expect(validateCronField('dayOfMonth', '?').isValid).toBe(true);
			expect(validateCronField('dayOfMonth', 'L').isValid).toBe(true);
			expect(validateCronField('dayOfMonth', 'LW').isValid).toBe(true);
			expect(validateCronField('dayOfMonth', '15W').isValid).toBe(true);
		});

		it('validates dayOfMonth field with comma-separated and range values', () =>
		{
			expect(validateCronField('dayOfMonth', '1,15').isValid).toBe(true);
			expect(validateCronField('dayOfMonth', '1-15').isValid).toBe(true);
		});

		it('rejects invalid dayOfMonth values', () =>
		{
			let result = validateCronField('dayOfMonth', 'X');
			expect(result.isValid).toBe(false);
			expect(result.errorMessage).toContain('Enter 1-31');
		});

		it('validates month field with valid values', () =>
		{
			expect(validateCronField('month', '1').isValid).toBe(true);
			expect(validateCronField('month', '12').isValid).toBe(true);
			expect(validateCronField('month', '*').isValid).toBe(true);
			expect(validateCronField('month', 'JAN').isValid).toBe(true);
			expect(validateCronField('month', 'DEC').isValid).toBe(true);
		});

		it('validates month field with comma-separated and range values', () =>
		{
			expect(validateCronField('month', '1,6,12').isValid).toBe(true);
			expect(validateCronField('month', '3-9').isValid).toBe(true);
			expect(validateCronField('month', 'JAN,MAR,MAY').isValid).toBe(true);
		});

		it('rejects invalid month values', () =>
		{
			let result = validateCronField('month', 'JANUARY');
			expect(result.isValid).toBe(false);
			expect(result.errorMessage).toContain('Enter 1-12');
		});

		it('validates dayOfWeek field with valid values', () =>
		{
			expect(validateCronField('dayOfWeek', '1').isValid).toBe(true);
			expect(validateCronField('dayOfWeek', '?').isValid).toBe(true);
			expect(validateCronField('dayOfWeek', '*').isValid).toBe(true);
			expect(validateCronField('dayOfWeek', 'MON').isValid).toBe(true);
			expect(validateCronField('dayOfWeek', 'FRI#1').isValid).toBe(true);
			expect(validateCronField('dayOfWeek', '6L').isValid).toBe(true);
			expect(validateCronField('dayOfWeek', 'MON,WED,FRI').isValid).toBe(true);
		});

		it('rejects invalid dayOfWeek values', () =>
		{
			let result = validateCronField('dayOfWeek', '');
			expect(result.isValid).toBe(false);
			expect(result.errorMessage).toBe('Enter 1-7, SUN-SAT, ?, L, or # patterns');
		});

		it('validates year field with valid values', () =>
		{
			expect(validateCronField('year', '2026').isValid).toBe(true);
			expect(validateCronField('year', '').isValid).toBe(true);
			expect(validateCronField('year', undefined).isValid).toBe(true);
		});

		it('rejects invalid year values', () =>
		{
			let result = validateCronField('year', '26');
			expect(result.isValid).toBe(false);
			expect(result.errorMessage).toBe('Enter a year (1970-2099) or leave empty');
		});

		it('returns valid for unknown field names', () =>
		{
			let result = validateCronField('unknown', 'anything');
			expect(result.isValid).toBe(true);
			expect(result.errorMessage).toBe('');
		});

		it('rejects out-of-range numeric values', () =>
		{
			expect(validateCronField('seconds', '60').isValid).toBe(false);
			expect(validateCronField('minutes', '60').isValid).toBe(false);
			expect(validateCronField('hours', '24').isValid).toBe(false);
			expect(validateCronField('hours', '25').isValid).toBe(false);
			expect(validateCronField('dayOfMonth', '0').isValid).toBe(false);
			expect(validateCronField('dayOfMonth', '32').isValid).toBe(false);
			expect(validateCronField('month', '0').isValid).toBe(false);
			expect(validateCronField('month', '13').isValid).toBe(false);
			expect(validateCronField('dayOfWeek', '0').isValid).toBe(false);
			expect(validateCronField('dayOfWeek', '8').isValid).toBe(false);
		});

		it('accepts in-range boundary values', () =>
		{
			expect(validateCronField('seconds', '0').isValid).toBe(true);
			expect(validateCronField('seconds', '59').isValid).toBe(true);
			expect(validateCronField('hours', '0').isValid).toBe(true);
			expect(validateCronField('hours', '23').isValid).toBe(true);
			expect(validateCronField('dayOfMonth', '1').isValid).toBe(true);
			expect(validateCronField('dayOfMonth', '31').isValid).toBe(true);
			expect(validateCronField('month', '1').isValid).toBe(true);
			expect(validateCronField('month', '12').isValid).toBe(true);
			expect(validateCronField('dayOfWeek', '1').isValid).toBe(true);
			expect(validateCronField('dayOfWeek', '7').isValid).toBe(true);
		});

		it('does not apply range check to non-numeric values', () =>
		{
			expect(validateCronField('minutes', '*', {jobRunnerMode: true}).isValid).toBe(true);
			expect(validateCronField('hours', '*/2').isValid).toBe(true);
			expect(validateCronField('dayOfMonth', 'L').isValid).toBe(true);
			expect(validateCronField('month', 'JAN').isValid).toBe(true);
		});
	});

	describe('class instantiation', () =>
	{
		it('can be created and renders', async() =>
		{
			const CronExpressionEditor = require('c/cronExpressionEditor').default;
			let element = createElement('c-cron-expression-editor', {is: CronExpressionEditor});
			document.body.appendChild(element);

			await Promise.resolve();

			expect(element.tagName).toBe('C-CRON-EXPRESSION-EDITOR');
			expect(element.shadowRoot).not.toBeNull();
			expect(element.shadowRoot.childElementCount).toBeGreaterThan(0);
		});

		it('renders preview section', async() =>
		{
			const CronExpressionEditor = require('c/cronExpressionEditor').default;
			let element = createElement('c-cron-expression-editor', {is: CronExpressionEditor});
			document.body.appendChild(element);

			await Promise.resolve();

			let preview = element.shadowRoot.querySelector('.slds-form-element_readonly');
			expect(preview).not.toBeNull();
		});

		it('renders expression text in preview', async() =>
		{
			const CronExpressionEditor = require('c/cronExpressionEditor').default;
			let element = createElement('c-cron-expression-editor', {is: CronExpressionEditor});
			document.body.appendChild(element);

			await Promise.resolve();

			let expressionText = element.shadowRoot.querySelector('.expression');
			expect(expressionText).toBeTruthy();
			expect(expressionText.textContent).toBeTruthy();
		});

		it('renders preset controls by default', async() =>
		{
			const CronExpressionEditor = require('c/cronExpressionEditor').default;
			let element = createElement('c-cron-expression-editor', {is: CronExpressionEditor});
			document.body.appendChild(element);

			await Promise.resolve();

			let radioGroup = element.shadowRoot.querySelector('lightning-radio-group');
			expect(radioGroup).toBeTruthy();
		});

		it('keeps showing the advanced expression while it refuses a switch to preset', async() =>
		{
			const ADVANCED_ONLY_EXPRESSION = '0 0 17 LW * ?';
			const CronExpressionEditor = require('c/cronExpressionEditor').default;
			let element = createElement('c-cron-expression-editor', {is: CronExpressionEditor});
			element.value = ADVANCED_ONLY_EXPRESSION;
			document.body.appendChild(element);
			await Promise.resolve();

			let modeButtons = element.shadowRoot.querySelector('[data-testid="cron-mode"]');
			modeButtons.value = 'preset';
			modeButtons.dispatchEvent(new CustomEvent('change', {detail: {value: 'preset'}}));

			// Every render in between must still show the advanced fields and the same expression.
			await Promise.resolve();
			expect(element.shadowRoot.querySelector('.expression').textContent).toBe(ADVANCED_ONLY_EXPRESSION);
			expect(element.shadowRoot.querySelector('lightning-input[data-testid="cron-custom-input"]')).toBeNull();
			expect(modeButtons.value).toBe('advanced');
			await Promise.resolve();
			expect(element.shadowRoot.querySelector('.expression').textContent).toBe(ADVANCED_ONLY_EXPRESSION);
			// The six advanced fields (minutes, hours, day of month, month, day of week and year) are still on the page.
			expect(element.shadowRoot.querySelectorAll('lightning-input')).toHaveLength(6);
		});

		it('sets value and parses to correct mode', async() =>
		{
			const CronExpressionEditor = require('c/cronExpressionEditor').default;
			let element = createElement('c-cron-expression-editor', {is: CronExpressionEditor});
			element.value = '0 0 12 * * ?';
			document.body.appendChild(element);

			await Promise.resolve();

			expect(element.value).toBe('0 0 12 * * ?');
			expect(element.cronExpression).toBe('0 0 12 * * ?');
		});

		it('isValid returns true in preset mode', async() =>
		{
			const CronExpressionEditor = require('c/cronExpressionEditor').default;
			let element = createElement('c-cron-expression-editor', {is: CronExpressionEditor});
			document.body.appendChild(element);

			await Promise.resolve();

			expect(element.isValid).toBe(true);
		});

		it('re-parses a runner-only preset into advanced mode when the runner flag is cleared', async() =>
		{
			const CronExpressionEditor = require('c/cronExpressionEditor').default;
			let element = createElement('c-cron-expression-editor', {is: CronExpressionEditor});
			element.jobRunnerMode = true;
			element.value = '0 */15 * * * ?';
			document.body.appendChild(element);

			await Promise.resolve();

			let intervalCombobox = [...element.shadowRoot.querySelectorAll('lightning-combobox')].find((field) => field.name === 'minuteInterval');
			expect(intervalCombobox.value).toBe('15');
			expect(element.jobRunnerMode).toBe(true);

			element.jobRunnerMode = false;

			await Promise.resolve();

			expect(element.jobRunnerMode).toBe(false);
			let minutesInput = [...element.shadowRoot.querySelectorAll('lightning-input')].find((field) => field.name === 'minutes');
			expect(minutesInput.value).toBe('*/15');
			expect(element.cronExpression).toBe('0 */15 * * * ?');
		});

		it('sends cronchange with the new validity when the runner flag changes', async() =>
		{
			const RUNNER_ONLY_EXPRESSION = '0 */15 * * * ?';
			const CronExpressionEditor = require('c/cronExpressionEditor').default;
			let element = createElement('c-cron-expression-editor', {is: CronExpressionEditor});
			element.jobRunnerMode = true;
			element.value = RUNNER_ONLY_EXPRESSION;
			let changeEvents = [];
			element.addEventListener('cronchange', (event) => changeEvents.push(event.detail));
			document.body.appendChild(element);

			await Promise.resolve();

			expect(changeEvents).toEqual([{value: RUNNER_ONLY_EXPRESSION, isValid: true}]);

			element.jobRunnerMode = false;
			await Promise.resolve();

			expect(changeEvents).toHaveLength(2);
			expect(changeEvents[1]).toEqual({value: RUNNER_ONLY_EXPRESSION, isValid: false});

			element.jobRunnerMode = false;
			await Promise.resolve();

			expect(changeEvents).toHaveLength(2);

			element.jobRunnerMode = true;
			await Promise.resolve();

			expect(changeEvents).toHaveLength(3);
			expect(changeEvents[2]).toEqual({value: RUNNER_ONLY_EXPRESSION, isValid: true});
		});

		it('sends the new value with the new validity when the runner flag and the value change together', async() =>
		{
			const RUNNER_ONLY_EXPRESSION = '0 */15 * * * ?';
			const CronExpressionEditor = require('c/cronExpressionEditor').default;
			let element = createElement('c-cron-expression-editor', {is: CronExpressionEditor});
			let changeEvents = [];
			element.addEventListener('cronchange', (event) => changeEvents.push(event.detail));
			document.body.appendChild(element);

			await Promise.resolve();

			element.jobRunnerMode = true;
			element.value = RUNNER_ONLY_EXPRESSION;
			await Promise.resolve();

			expect(changeEvents).toHaveLength(2);
			expect(changeEvents[1]).toEqual({value: RUNNER_ONLY_EXPRESSION, isValid: true});
		});

		it('isValid returns true for valid 6-field expression', async() =>
		{
			const CronExpressionEditor = require('c/cronExpressionEditor').default;
			let element = createElement('c-cron-expression-editor', {is: CronExpressionEditor});
			element.value = '0 0 12 * * ?';
			document.body.appendChild(element);

			await Promise.resolve();

			expect(element.isValid).toBe(true);
		});
	});
});
