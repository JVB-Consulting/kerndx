// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Reusable cron expression editor component with preset, advanced, and custom modes.
 *              Supports Salesforce 7-field cron syntax. Designed for embedding in any context.
 */
import {api} from 'lwc';
import {ComponentBuilder} from 'c/componentBuilder';
import {parseCronExpression, buildCronExpression, describeCronExpression, validateCronField, validateCronExpression, splitCronExpression} from './cronParser';

export {describeCronExpression, validateCronField, validateCronExpression};
import {
	MODE_PRESET, MODE_ADVANCED, MODE_CUSTOM, DEFAULT_CRON_EXPRESSION, MODE_OPTIONS, PRESET_FREQUENCIES, MINUTE_INTERVALS, DAYS_OF_WEEK, HOURS_OPTIONS, MINUTES_OPTIONS,
	DAY_OF_MONTH_OPTIONS, SECONDS_OPTIONS
} from './constants';

export default class CronExpressionEditor extends ComponentBuilder('notification')
{
	mode = MODE_PRESET;
	presetFrequency = 'daily';
	presetMinuteInterval = '5';
	presetMinute = '0';
	presetHour = '12';
	presetDaysOfWeek = [];
	presetDayOfMonth = '1';
	advancedSeconds = '0';
	advancedMinutes = '0';
	advancedHours = '12';
	advancedDayOfMonth = '*';
	advancedMonth = '*';
	advancedDayOfWeek = '?';
	advancedYear = '';
	customExpression = DEFAULT_CRON_EXPRESSION;

	_value;

	@api get value()
	{
		return this._value;
	}

	set value(val)
	{
		this._value = val;

		if(val !== this.buildCurrentExpression())
		{
			this.parseAndPopulate(val);
		}
	}

	@api get cronExpression()
	{
		return this.buildCurrentExpression();
	}

	get cronDescription()
	{
		return describeCronExpression(this.buildCurrentExpression());
	}

	get modeOptions()
	{
		return MODE_OPTIONS;
	}

	get presetFrequencies()
	{
		return PRESET_FREQUENCIES;
	}

	get minuteIntervals()
	{
		return MINUTE_INTERVALS;
	}

	get daysOfWeekOptions()
	{
		return DAYS_OF_WEEK;
	}

	get hoursOptions()
	{
		return HOURS_OPTIONS;
	}

	get minutesOptions()
	{
		return MINUTES_OPTIONS;
	}

	get dayOfMonthOptions()
	{
		return DAY_OF_MONTH_OPTIONS;
	}

	get secondsOptions()
	{
		return SECONDS_OPTIONS;
	}

	get isPresetMode()
	{
		return this.mode === MODE_PRESET;
	}

	get isAdvancedMode()
	{
		return this.mode === MODE_ADVANCED;
	}

	get isCustomMode()
	{
		return this.mode === MODE_CUSTOM;
	}

	get isEveryNMinutes()
	{
		return this.presetFrequency === 'everyNMinutes';
	}

	get isHourly()
	{
		return this.presetFrequency === 'hourly';
	}

	get isDaily()
	{
		return this.presetFrequency === 'daily';
	}

	get isWeekly()
	{
		return this.presetFrequency === 'weekly';
	}

	get isMonthly()
	{
		return this.presetFrequency === 'monthly';
	}

	get showHourMinute()
	{
		return this.isDaily || this.isWeekly || this.isMonthly;
	}

	get currentExpression()
	{
		return this.buildCurrentExpression();
	}

	@api get isValid()
	{
		return validateCronExpression(this.buildCurrentExpression()).isValid;
	}

	get showValidationError()
	{
		return !this.isValid;
	}

	get validationMessage()
	{
		return validateCronExpression(this.buildCurrentExpression()).errorMessage;
	}

	connectedCallback()
	{
		this.dispatchChangeEvent();
	}

	parseAndPopulate(expression)
	{
		let result = parseCronExpression(expression);
		this.mode = result.mode;

		if(result.mode === MODE_PRESET && result.preset)
		{
			this.presetFrequency = result.preset.frequency;
			this.presetMinuteInterval = result.preset.minuteInterval || '5';
			this.presetMinute = result.preset.minute || '0';
			this.presetHour = result.preset.hour || '12';
			this.presetDaysOfWeek = result.preset.daysOfWeek || [];
			this.presetDayOfMonth = result.preset.dayOfMonth || '1';
		}
		else if(result.mode === MODE_ADVANCED && result.advanced)
		{
			this.advancedSeconds = result.advanced.seconds;
			this.advancedMinutes = result.advanced.minutes;
			this.advancedHours = result.advanced.hours;
			this.advancedDayOfMonth = result.advanced.dayOfMonth;
			this.advancedMonth = result.advanced.month;
			this.advancedDayOfWeek = result.advanced.dayOfWeek;
			this.advancedYear = result.advanced.year || '';
		}
		else if(result.mode === MODE_CUSTOM)
		{
			this.customExpression = result.raw;
		}
	}

	buildCurrentExpression()
	{
		if(this.mode === MODE_PRESET)
		{
			return buildCronExpression(MODE_PRESET, {
				frequency: this.presetFrequency,
				minuteInterval: this.presetMinuteInterval,
				minute: this.presetMinute,
				hour: this.presetHour,
				daysOfWeek: this.presetDaysOfWeek,
				dayOfMonth: this.presetDayOfMonth
			});
		}

		if(this.mode === MODE_ADVANCED)
		{
			return buildCronExpression(MODE_ADVANCED, {
				seconds: this.advancedSeconds,
				minutes: this.advancedMinutes,
				hours: this.advancedHours,
				dayOfMonth: this.advancedDayOfMonth,
				month: this.advancedMonth,
				dayOfWeek: this.advancedDayOfWeek,
				year: this.advancedYear
			});
		}

		return buildCronExpression(MODE_CUSTOM, {raw: this.customExpression});
	}

	dispatchChangeEvent()
	{
		this.dispatchEvent(new CustomEvent('cronchange', {detail: {value: this.buildCurrentExpression(), isValid: this.isValid}}));
	}

	handleModeChange(event)
	{
		let currentExpression = this.buildCurrentExpression();
		let targetMode = event.detail.value;

		if(targetMode === MODE_CUSTOM)
		{
			this.customExpression = currentExpression;
		}
		else if(targetMode === MODE_ADVANCED)
		{
			let parts = splitCronExpression(currentExpression);
			if(parts)
			{
				this.advancedSeconds = parts[0];
				this.advancedMinutes = parts[1];
				this.advancedHours = parts[2];
				this.advancedDayOfMonth = parts[3];
				this.advancedMonth = parts[4];
				this.advancedDayOfWeek = parts[5];
				this.advancedYear = parts[6] || '';
			}
		}
		else if(targetMode === MODE_PRESET)
		{
			let result = parseCronExpression(currentExpression);
			if(!result.preset)
			{
				this.showWarningToast('This expression cannot be represented in Preset mode. Use Advanced or Custom mode instead.');
				let currentMode = this.mode;
				this.mode = null;
				// eslint-disable-next-line @lwc/lwc/no-async-operation
				Promise.resolve().then(() =>
				{
					this.mode = currentMode;
				});
				return;
			}
			this.presetFrequency = result.preset.frequency;
			this.presetMinuteInterval = result.preset.minuteInterval || '5';
			this.presetMinute = result.preset.minute || '0';
			this.presetHour = result.preset.hour || '12';
			this.presetDaysOfWeek = result.preset.daysOfWeek || [];
			this.presetDayOfMonth = result.preset.dayOfMonth || '1';
		}

		this.mode = targetMode;
		this.dispatchChangeEvent();
	}

	handleFrequencyChange(event)
	{
		this.presetFrequency = event.detail.value;

		if(this.presetFrequency === 'weekly' && this.presetDaysOfWeek.length === 0)
		{
			this.presetDaysOfWeek = ['MON'];
		}

		this.dispatchChangeEvent();
	}

	handleMinuteIntervalChange(event)
	{
		this.presetMinuteInterval = event.detail.value;
		this.dispatchChangeEvent();
	}

	handlePresetMinuteChange(event)
	{
		this.presetMinute = event.detail.value;
		this.dispatchChangeEvent();
	}

	handlePresetHourChange(event)
	{
		this.presetHour = event.detail.value;
		this.dispatchChangeEvent();
	}

	handleDaysOfWeekChange(event)
	{
		this.presetDaysOfWeek = event.detail.value;
		this.dispatchChangeEvent();
	}

	handlePresetDayOfMonthChange(event)
	{
		this.presetDayOfMonth = event.detail.value;
		this.dispatchChangeEvent();
	}

	handleAdvancedSecondsChange(event)
	{
		this.advancedSeconds = event.detail.value;
		this.dispatchChangeEvent();
	}

	handleAdvancedMinutesChange(event)
	{
		this.advancedMinutes = event.detail.value;
		this.dispatchChangeEvent();
	}

	handleAdvancedHoursChange(event)
	{
		this.advancedHours = event.detail.value;
		this.dispatchChangeEvent();
	}

	handleAdvancedDayOfMonthChange(event)
	{
		this.advancedDayOfMonth = event.detail.value;
		this.dispatchChangeEvent();
	}

	handleAdvancedMonthChange(event)
	{
		this.advancedMonth = event.detail.value;
		this.dispatchChangeEvent();
	}

	handleAdvancedDayOfWeekChange(event)
	{
		this.advancedDayOfWeek = event.detail.value;
		this.dispatchChangeEvent();
	}

	handleAdvancedYearChange(event)
	{
		this.advancedYear = event.detail.value;
		this.dispatchChangeEvent();
	}

	handleCustomExpressionChange(event)
	{
		this.customExpression = event.detail.value;
		this.dispatchChangeEvent();
	}
}