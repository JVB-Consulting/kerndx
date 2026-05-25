// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for cronExpressionEditor LWC component.
 *
 * @author Jason van Beukering
 * @date February 2026, May 2026
 */
import {createElement} from 'lwc';
import {splitCronExpression, validateCronField, validateCronExpression} from '../cronParser';

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
			const {validateCronExpression} = require('c/cronExpressionEditor');
			expect(validateCronExpression).toBeDefined();
			expect(typeof validateCronExpression).toBe('function');
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

		const createMockContext = (overrides = {}) =>
		{
			let context = {
				_value: undefined,
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
				buildCurrentExpression: prototype.buildCurrentExpression,
				dispatchChangeEvent: prototype.dispatchChangeEvent,
				connectedCallback: prototype.connectedCallback, ...overrides
			};
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

			it('populates everyNMinutes preset', () =>
			{
				let context = createMockContext();
				prototype.parseAndPopulate.call(context, '0 */15 * * * ?');
				expect(context.mode).toBe('preset');
				expect(context.presetFrequency).toBe('everyNMinutes');
				expect(context.presetMinuteInterval).toBe('15');
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

			it('presetFrequencies returns five frequencies', () =>
			{
				let context = createMockContext();
				let getter = Object.getOwnPropertyDescriptor(prototype, 'presetFrequencies').get;
				expect(getter.call(context)).toHaveLength(5);
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
				prototype.handleModeChange.call(context, {detail: {value: 'preset'}});
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

		it('handleModeChange bounces mode through null on rejected preset switch (Bug 7)', async() =>
		{
			let context = createValidationContext({
				advancedSeconds: '0', advancedMinutes: '0', advancedHours: '17', advancedDayOfMonth: 'LW', advancedMonth: '*', advancedDayOfWeek: '?', advancedYear: ''
			});
			context.showWarningToast = jest.fn();
			prototype.handleModeChange.call(context, {detail: {value: 'preset'}});
			expect(context.mode).toBeNull();
			await Promise.resolve();
			expect(context.mode).toBe('advanced');
		});
	});

	describe('validateCronField', () =>
	{
		const {validateCronField} = require('c/cronExpressionEditor');

		it('validates minutes field with valid values', () =>
		{
			expect(validateCronField('minutes', '0').isValid).toBe(true);
			expect(validateCronField('minutes', '59').isValid).toBe(true);
			expect(validateCronField('minutes', '*').isValid).toBe(true);
			expect(validateCronField('minutes', '*/5').isValid).toBe(true);
			expect(validateCronField('minutes', '0/5').isValid).toBe(true);
			expect(validateCronField('minutes', '0/15').isValid).toBe(true);
		});

		it('validates minutes field with comma-separated and range values', () =>
		{
			expect(validateCronField('minutes', '0,15,30,45').isValid).toBe(true);
			expect(validateCronField('minutes', '0-30').isValid).toBe(true);
		});

		it('rejects invalid minutes values', () =>
		{
			let result = validateCronField('minutes', '0.2');
			expect(result.isValid).toBe(false);
			expect(result.errorMessage).toContain('Enter 0-59');
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
			expect(validateCronField('minutes', '*').isValid).toBe(true);
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
