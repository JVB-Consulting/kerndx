// SPDX-License-Identifier: Apache-2.0
/**
 * @description Reusable cron expression editor component with preset, advanced, and custom modes.
 *              Supports Salesforce 7-field cron syntax. Designed for embedding in any context.
 *
 * @date March 2026, October 2026
 */
import {api} from 'lwc';
import {ComponentBuilder} from 'c/componentBuilder';
import {parseCronExpression, buildCronExpression, describeCronExpression, validateCronField, validateCronExpression, splitCronExpression} from './cronParser';

export {describeCronExpression, validateCronField, validateCronExpression};
import {
	MODE_PRESET, MODE_ADVANCED, MODE_CUSTOM, DEFAULT_CRON_EXPRESSION, MODE_OPTIONS, PRESET_FREQUENCIES, MINUTE_INTERVALS, DAYS_OF_WEEK, HOURS_OPTIONS, MINUTES_OPTIONS,
	DAY_OF_MONTH_OPTIONS, SECONDS_OPTIONS
} from './constants';
import PRESET_MODE_UNREPRESENTABLE from '@salesforce/label/c.CronExpressionEditor_PresetModeUnrepresentable';
import MODE_LABEL from '@salesforce/label/c.CronExpressionEditor_ModeLabel';
import FREQUENCY_LABEL from '@salesforce/label/c.CronExpressionEditor_FrequencyLabel';
import INTERVAL_LABEL from '@salesforce/label/c.CronExpressionEditor_IntervalLabel';
import AT_MINUTE_LABEL from '@salesforce/label/c.CronExpressionEditor_AtMinuteLabel';
import HOUR_LABEL from '@salesforce/label/c.CronExpressionEditor_HourLabel';
import MINUTE_LABEL from '@salesforce/label/c.CronExpressionEditor_MinuteLabel';
import DAYS_LABEL from '@salesforce/label/c.CronExpressionEditor_DaysLabel';
import DAY_OF_MONTH_LABEL from '@salesforce/label/c.CronExpressionEditor_DayOfMonthLabel';
import SECONDS_LABEL from '@salesforce/label/c.CronExpressionEditor_SecondsLabel';
import MINUTES_LABEL from '@salesforce/label/c.CronExpressionEditor_MinutesLabel';
import HOURS_LABEL from '@salesforce/label/c.CronExpressionEditor_HoursLabel';
import MONTH_LABEL from '@salesforce/label/c.CronExpressionEditor_MonthLabel';
import DAY_OF_WEEK_HELP from '@salesforce/label/c.CronExpressionEditor_DayOfWeekHelp';
import DAY_OF_WEEK_LABEL from '@salesforce/label/c.CronExpressionEditor_DayOfWeekLabel';
import YEAR_HELP from '@salesforce/label/c.CronExpressionEditor_YearHelp';
import YEAR_OPTIONAL_LABEL from '@salesforce/label/c.CronExpressionEditor_YearOptionalLabel';
import CRON_EXPRESSION_LABEL from '@salesforce/label/c.CronExpressionEditor_CronExpressionLabel';
import PREVIEW_LABEL from '@salesforce/label/c.CronExpressionEditor_PreviewLabel';
import INTERVAL_ACTIVATE_FIRST_NOTE from '@salesforce/label/c.CronExpressionEditor_IntervalActivateFirstNote';

export default class CronExpressionEditor extends ComponentBuilder('notification')
{
	label = {
		mode: MODE_LABEL,
		frequency: FREQUENCY_LABEL,
		interval: INTERVAL_LABEL,
		atMinute: AT_MINUTE_LABEL,
		hour: HOUR_LABEL,
		minute: MINUTE_LABEL,
		days: DAYS_LABEL,
		dayOfMonth: DAY_OF_MONTH_LABEL,
		seconds: SECONDS_LABEL,
		minutes: MINUTES_LABEL,
		hours: HOURS_LABEL,
		month: MONTH_LABEL,
		dayOfWeekHelp: DAY_OF_WEEK_HELP,
		dayOfWeek: DAY_OF_WEEK_LABEL,
		yearHelp: YEAR_HELP,
		yearOptional: YEAR_OPTIONAL_LABEL,
		cronExpression: CRON_EXPRESSION_LABEL,
		preview: PREVIEW_LABEL,
		intervalActivateFirstNote: INTERVAL_ACTIVATE_FIRST_NOTE
	};

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

	/** @description Backing field for jobRunnerMode. */
	_jobRunnerMode = false;

	/** @description Whether the editor has been put on the page, so a change event now reaches the parent. */
	hasConnected = false;

	/**
	 * @description Whether the record this editor edits runs on the job runner. On the runner Kern reads the expression
	 *              itself, so the minutes field may carry steps, lists and ranges and the Every N Minutes preset is offered.
	 *              Clearing the flag while such a preset is selected re-reads the expression the own-mode way (advanced mode).
	 */
	@api get jobRunnerMode()
	{
		return this._jobRunnerMode;
	}

	set jobRunnerMode(value)
	{
		const wasOnRunner = this._jobRunnerMode;
		this._jobRunnerMode = value === true;

		if(wasOnRunner && !this._jobRunnerMode && this.mode === MODE_PRESET && this.presetFrequency === 'everyNMinutes')
		{
			this.parseAndPopulate(this.buildCurrentExpression());
		}

		// The same expression can be valid on the runner and not valid in own mode, so the parent hears the new
		// validity. The event waits for the parent to finish setting properties: a parent that sets this flag and a
		// new value together must get the new value back, not the old one. Before the editor is on the page,
		// connectedCallback sends the first event instead.
		if(this.hasConnected && wasOnRunner !== this._jobRunnerMode)
		{
			Promise.resolve().then(() => this.dispatchChangeEvent());
		}
	}

	/**
	 * @description How often the active job runner checks for due jobs, in minutes, or null when none is active.
	 *              Narrows the interval choices to multiples of it.
	 */
	@api activeCheckIntervalMinutes;

	/**
	 * @description The options every parser call in this component passes, so the editor reads and describes an
	 *              expression the same way the record's own runner will.
	 */
	get parserOptions()
	{
		return {jobRunnerMode: this._jobRunnerMode, activeCheckIntervalMinutes: this.activeCheckIntervalMinutes ? Number(this.activeCheckIntervalMinutes) : null};
	}

	get cronDescription()
	{
		return describeCronExpression(this.buildCurrentExpression(), this.parserOptions);
	}

	get modeOptions()
	{
		return MODE_OPTIONS;
	}

	/**
	 * @description The interval choices the Every N Minutes preset offers: every interval when no job runner is
	 *              active, and otherwise those the active runner's check interval can actually hit, plus the interval an
	 *              Every N Minutes job is already saved with, so a saved job never opens on a blank choice.
	 */
	get minuteIntervals()
	{
		const checkInterval = this.parserOptions.activeCheckIntervalMinutes;

		if(!checkInterval)
		{
			return MINUTE_INTERVALS;
		}

		return MINUTE_INTERVALS.filter((option) => Number(option.value) % checkInterval === 0 || (this.isEveryNMinutes && option.value === this.presetMinuteInterval));
	}

	/**
	 * @description The frequencies the preset mode offers. Every N Minutes is offered only on the job runner, while an
	 *              interval it can hit remains or while this job is already using it.
	 */
	get presetFrequencies()
	{
		const offersIntervals = this._jobRunnerMode && (this.minuteIntervals.length > 0 || this.presetFrequency === 'everyNMinutes');
		return offersIntervals ? PRESET_FREQUENCIES : PRESET_FREQUENCIES.filter((option) => option.value !== 'everyNMinutes');
	}

	/**
	 * @description Whether to tell the reader that no job runner is active yet, so an Every N Minutes job waits
	 *              until one is activated.
	 */
	get showActivateFirstNote()
	{
		return this._jobRunnerMode && this.isEveryNMinutes && !this.parserOptions.activeCheckIntervalMinutes;
	}

	/**
	 * @description The minutes the advanced field accepts, as a list of cron tokens: one number in the editor's own
	 *              mode, and the wide grammar on the job runner.
	 */
	get minutesHelp()
	{
		// eslint-disable-next-line kerndx/no-hardcoded-user-text -- a list of cron syntax tokens, not translatable prose
		return this._jobRunnerMode ? '0-59, *, */N, N/N, N,N, N-N' : '0-59';
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
		return validateCronExpression(this.buildCurrentExpression(), this.parserOptions).isValid;
	}

	get showValidationError()
	{
		return !this.isValid;
	}

	get validationMessage()
	{
		return validateCronExpression(this.buildCurrentExpression(), this.parserOptions).errorMessage;
	}

	connectedCallback()
	{
		this.hasConnected = true;
		this.dispatchChangeEvent();
	}

	parseAndPopulate(expression)
	{
		const result = parseCronExpression(expression, this.parserOptions);
		this.mode = result.mode;

		if(result.mode === MODE_PRESET && result.preset)
		{
			this.applyPreset(result.preset);
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

	/** @description Copies a parsed preset into the preset fields the editor shows, filling in a default for anything the preset leaves out. */
	applyPreset(preset)
	{
		this.presetFrequency = preset.frequency;
		this.presetMinuteInterval = preset.minuteInterval || '5';
		this.presetMinute = preset.minute || '0';
		this.presetHour = preset.hour || '12';
		this.presetDaysOfWeek = preset.daysOfWeek || [];
		this.presetDayOfMonth = preset.dayOfMonth || '1';
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
		const currentExpression = this.buildCurrentExpression();
		const targetMode = event.detail.value;

		if(targetMode === MODE_CUSTOM)
		{
			this.customExpression = currentExpression;
		}
		else if(targetMode === MODE_ADVANCED)
		{
			const parts = splitCronExpression(currentExpression);
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
			const result = parseCronExpression(currentExpression, this.parserOptions);
			if(!result.preset)
			{
				this.showWarningToast(PRESET_MODE_UNREPRESENTABLE);
				// The mode buttons already show the refused choice. The mode itself never changed, so setting it again
				// would not redraw them: the buttons are moved back directly, and the fields and the preview stay as they are.
				event.target.value = this.mode;
				return;
			}

			this.applyPreset(result.preset);
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

		const checkInterval = this.parserOptions.activeCheckIntervalMinutes;
		const reachableIntervals = MINUTE_INTERVALS.filter((option) => Number(option.value) % checkInterval === 0);

		// A job opens on five minutes, which a runner checking every fifteen never reaches, so choosing Every N
		// Minutes moves the interval to the first one that runner's check can actually hit.
		if(this.isEveryNMinutes && reachableIntervals.length > 0 && Number(this.presetMinuteInterval) % checkInterval !== 0)
		{
			this.presetMinuteInterval = reachableIntervals[0].value;
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