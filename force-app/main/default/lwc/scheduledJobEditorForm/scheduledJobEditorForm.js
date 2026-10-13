// SPDX-License-Identifier: BUSL-1.1
/**
 * @description The form the two ScheduledJob__c editors share: the record-page editor and the modal that Health
 *              Check opens. The two editors build on different base classes (ComponentBuilder and LightningModal),
 *              so the shared form is a class factory: give it the base class and it returns a class that carries
 *              the form's state, labels, getters, loaders, change handlers and the save path. The editor that
 *              extends the result adds only what it alone does: where errors show, what follows a save, and in
 *              the record-page editor the job runner fields.
 *
 *              An editor keeps its own getRecord wire, because the fields it reads are its own, and hands the
 *              record to applyRecord. It supplies the two members the shared save path calls: completeSave, which
 *              runs once the record is saved, and reportSaveFailure, which shows a failed save where that editor
 *              shows errors. It may extend buildSaveRequest with fields of its own.
 *
 * @author Jason van Beukering
 *
 * @date October 2026
 */
import {api} from 'lwc';
import {getFieldValue} from 'lightning/uiRecordApi';
import {reduceErrors} from 'c/utilitySystem';
import {formatTemplateString} from 'c/utilityString';
import {getTimezoneDisplayName, parseAttributes} from 'c/utilityScheduledJob';
import getSchedulableClasses from '@salesforce/apex/CTRL_ScheduledJob.getSchedulableClasses';
import getParameterDefinitions from '@salesforce/apex/CTRL_ScheduledJob.getParameterDefinitions';
import getUserTimezone from '@salesforce/apex/CTRL_ScheduledJob.getUserTimezone';
import saveRecord from '@salesforce/apex/CTRL_ScheduledJob.saveRecord';
import SCHEDULER_NAME_FIELD from '@salesforce/schema/ScheduledJob__c.SchedulerName__c';
import CLASS_NAME_FIELD from '@salesforce/schema/ScheduledJob__c.ClassName__c';
import CRON_EXPRESSION_FIELD from '@salesforce/schema/ScheduledJob__c.CronExpression__c';
import IS_ACTIVE_FIELD from '@salesforce/schema/ScheduledJob__c.IsActive__c';
import DESCRIPTION_FIELD from '@salesforce/schema/ScheduledJob__c.Description__c';
import PARAMETERS_FIELD from '@salesforce/schema/ScheduledJob__c.Parameters__c';
import TIMEZONE_FIELD from '@salesforce/schema/ScheduledJob__c.Timezone__c';
import CREATE_TITLE from '@salesforce/label/c.ScheduledJob_NewTitle';
import EDIT_TITLE from '@salesforce/label/c.ScheduledJob_EditTitle';
import SCHEDULE from '@salesforce/label/c.ScheduledJob_Schedule';
import SCHEDULE_WITH_TIMEZONE from '@salesforce/label/c.ScheduledJob_ScheduleWithTimezone';
import CLASS_NAME_NOT_SCHEDULABLE from '@salesforce/label/c.ScheduledJob_ClassNameNotSchedulable';
import SAVE_FAILED from '@salesforce/label/c.ScheduledJob_SaveFailed';
import SCHEDULER_NAME_LABEL from '@salesforce/label/c.ScheduledJob_SchedulerName';
import CLASS_NAME_LABEL from '@salesforce/label/c.ScheduledJob_ClassName';
import CLASS_NAME_PLACEHOLDER from '@salesforce/label/c.ScheduledJob_ClassNamePlaceholder';
import ACTIVE_LABEL from '@salesforce/label/c.ScheduledJob_Active';
import INACTIVE_LABEL from '@salesforce/label/c.ScheduledJob_Inactive';
import PARAMETERS_HEADING from '@salesforce/label/c.ScheduledJob_Parameters';
import YES_LABEL from '@salesforce/label/c.ScheduledJob_Yes';
import NO_LABEL from '@salesforce/label/c.ScheduledJob_No';
import DESCRIPTION_LABEL from '@salesforce/label/c.ScheduledJob_Description';
import CANCEL_LABEL from '@salesforce/label/c.ScheduledJob_Cancel';
import SAVE_LABEL from '@salesforce/label/c.ScheduledJob_Save';

/**
 * @description The record fields every editor reads into the form. An editor that reads more adds its own.
 *
 * @type {Object[]}
 */
export const SCHEDULED_JOB_FORM_FIELDS = [
	SCHEDULER_NAME_FIELD,
	CLASS_NAME_FIELD,
	CRON_EXPRESSION_FIELD,
	IS_ACTIVE_FIELD,
	DESCRIPTION_FIELD,
	PARAMETERS_FIELD,
	TIMEZONE_FIELD
];

/**
 * @description The labels of the form fields and buttons every editor renders.
 *
 * @type {Object<string, string>}
 */
export const SCHEDULED_JOB_FORM_LABELS = {
	schedulerName: SCHEDULER_NAME_LABEL,
	className: CLASS_NAME_LABEL,
	classPlaceholder: CLASS_NAME_PLACEHOLDER,
	active: ACTIVE_LABEL,
	inactive: INACTIVE_LABEL,
	parameters: PARAMETERS_HEADING,
	yes: YES_LABEL,
	no: NO_LABEL,
	description: DESCRIPTION_LABEL,
	cancel: CANCEL_LABEL,
	save: SAVE_LABEL
};

/**
 * @description Builds the shared scheduled job form on top of the given base class.
 *
 * @param {Function} baseComponent The class the editor would otherwise extend directly.
 *
 * @return {Function} A class extending baseComponent that carries the shared form.
 */
export const ScheduledJobEditorForm = (baseComponent) => class ScheduledJobEditorFormBase extends baseComponent
{
	/**
	 * @description The ScheduledJob__c record to edit. When omitted, the form creates a new record.
	 *
	 * @type {string}
	 */
	@api recordId;

	/**
	 * @description Names of parameters that render read-only. Used when a retention job is customised, to prefill
	 *              and lock the target object while leaving other parameters editable.
	 *
	 * @type {string[]}
	 */
	@api lockedFields = [];

	schedulerName = '';
	className = '';

	/**
	 * @description Why the class name cannot be scheduled, shown under the field; empty while the name is fine.
	 *
	 * @type {string}
	 */
	classNameError = '';

	/**
	 * @description The class the saved record names, so a class deleted since does not stop the record being saved,
	 *              for example to switch the job off. Empty for a new record.
	 *
	 * @type {string}
	 */
	recordClassName = '';

	classOptions = [];
	cronExpression = '';
	cronIsValid = true;
	description = '';
	isActive = false;
	isSaving = false;
	parameterDefinitions;
	parameterValues = {};
	userTimezone = '';

	/**
	 * @description The class whose parameters were last read, so a record delivered again does not read them again.
	 *
	 * @type {string}
	 */
	lastLoadedClassName;

	/**
	 * @description Whether the form creates a new record rather than editing one.
	 *
	 * @return {boolean} True when there is no record to edit.
	 */
	get isCreateMode()
	{
		return !this.recordId;
	}

	/**
	 * @description The heading of the form: one title for a new record, another for an existing one.
	 *
	 * @return {string} The title to show.
	 */
	get formTitle()
	{
		return this.isCreateMode ? CREATE_TITLE : EDIT_TITLE;
	}

	/**
	 * @description The heading of the schedule section, naming the time zone the schedule is read in once it is known.
	 *
	 * @return {string} The heading to show.
	 */
	get scheduleHeading()
	{
		if(this.userTimezone)
		{
			return formatTemplateString(SCHEDULE_WITH_TIMEZONE, [getTimezoneDisplayName(this.userTimezone)]);
		}

		return SCHEDULE;
	}

	/**
	 * @description Whether Save is closed: while saving, while the class field holds an error about a class chosen in this
	 *              edit, until the required fields are filled and the expression is valid, and while a required parameter
	 *              has been cleared.
	 *
	 * @return {boolean} True when the Save button is disabled.
	 */
	get isSaveDisabled()
	{
		if(this.isSaving || this.hasBlockingClassNameError)
		{
			return true;
		}

		let hasRequiredFields = this.cronIsValid && this.schedulerName && this.className && this.cronExpression;

		if(hasRequiredFields && this.hasParameterDefinitions)
		{
			// A parameter input renders pre-filled with its defaultValue, so an untouched default
			// satisfies the requirement; only an explicitly cleared entry ('') leaves it unmet.
			return this.parameterDefinitions.some((parameter) => parameter.isRequired && !(this.parameterValues[parameter.name] ?? parameter.defaultValue));
		}

		return !hasRequiredFields;
	}

	/**
	 * @description Whether the class field's error closes Save. It does for a class picked or typed in this edit, and not
	 *              for the class the saved record already names, which may have been deleted since and still needs
	 *              switching off.
	 *
	 * @return {boolean} True when Save stays closed because of the class name.
	 */
	get hasBlockingClassNameError()
	{
		return Boolean(this.classNameError) && this.className !== this.recordClassName;
	}

	/**
	 * @description Whether the chosen class declares any parameters.
	 *
	 * @return {boolean} True when there is at least one parameter to render.
	 */
	get hasParameterDefinitions()
	{
		return Boolean(this.parameterDefinitions && this.parameterDefinitions.length > 0);
	}

	/**
	 * @description The parameter inputs to render: one per declared parameter, typed, pre-filled with the entered value
	 *              or the default, and locked when its name is in lockedFields.
	 *
	 * @return {Object[]} The inputs in declaration order.
	 */
	get editParameterFields()
	{
		if(!this.hasParameterDefinitions)
		{
			return [];
		}

		let lockedNames = Array.isArray(this.lockedFields) ? this.lockedFields : [];

		return this.parameterDefinitions.map((parameter) =>
		{
			let value = this.parameterValues[parameter.name] ?? parameter.defaultValue ?? '';
			let type = String(parameter.dataType || '').toUpperCase();

			return {
				name: parameter.name,
				label: parameter.label,
				description: parameter.description,
				isRequired: parameter.isRequired,
				dataType: parameter.dataType,
				testId: 'param-' + parameter.name,
				value,
				isText: type === 'TEXT',
				isNumeric: type === 'NUMERIC',
				isToggle: type === 'FLAG',
				isLocked: lockedNames.indexOf(parameter.name) !== -1,
				toggleChecked: type === 'FLAG' && String(value).toLowerCase() === 'true'
			};
		});
	}

	/**
	 * @description Reads the classes on offer and the user's time zone as soon as the form is on the page.
	 */
	connectedCallback()
	{
		this.loadSchedulableClasses();
		this.loadUserTimezone();
	}

	/**
	 * @description Reads the time zone the schedule is shown in. A failure leaves the heading without a zone.
	 *
	 * @return {Promise<void>} Resolves once the zone has been read.
	 */
	async loadUserTimezone()
	{
		try
		{
			this.userTimezone = await getUserTimezone({});
		}
		catch
		{
			this.userTimezone = '';
		}
	}

	/**
	 * @description Reads the classes the class field offers. A failure leaves the list empty; a name can still be typed.
	 *
	 * @return {Promise<void>} Resolves once the list has been read.
	 */
	async loadSchedulableClasses()
	{
		try
		{
			let classes = await getSchedulableClasses({});
			this.classOptions = (classes || []).map((name) => ({label: name, value: name}));
		}
		catch
		{
			this.classOptions = [];
		}
	}

	/**
	 * @description Fills the form from the record the editor's wire delivered, and reads the parameters its class
	 *              declares the first time that class is seen.
	 *
	 * @param {Object} data The record as the getRecord wire delivers it.
	 */
	applyRecord(data)
	{
		let currentClassName = getFieldValue(data, CLASS_NAME_FIELD);

		this.schedulerName = getFieldValue(data, SCHEDULER_NAME_FIELD) || '';
		this.className = currentClassName || '';
		this.recordClassName = this.className;
		this.cronExpression = getFieldValue(data, CRON_EXPRESSION_FIELD) || '';
		this.isActive = getFieldValue(data, IS_ACTIVE_FIELD) || false;
		this.description = getFieldValue(data, DESCRIPTION_FIELD) || '';
		this.parameterValues = {...parseAttributes(getFieldValue(data, PARAMETERS_FIELD) || '')};

		if(currentClassName && currentClassName !== this.lastLoadedClassName)
		{
			this.lastLoadedClassName = currentClassName;
			this.loadParameterDefinitions(currentClassName);
		}
	}

	/**
	 * @description Reads the parameters the class declares, which also checks the name: a name that cannot be found, or
	 *              that names a class that is not Schedulable, is refused, and the field says so.
	 *
	 * @param {string} className The class name, picked, typed or prefilled.
	 *
	 * @return {Promise<boolean>} True when the class was accepted, false when the name was refused.
	 */
	async loadParameterDefinitions(className)
	{
		try
		{
			this.parameterDefinitions = await getParameterDefinitions({className});
			this.classNameError = '';
			return true;
		}
		catch
		{
			this.parameterDefinitions = null;
			this.classNameError = formatTemplateString(CLASS_NAME_NOT_SCHEDULABLE, [className]);
			return false;
		}
	}

	/**
	 * @description Keeps the scheduler name as typed.
	 *
	 * @param {CustomEvent} event The input's change event.
	 */
	handleSchedulerNameChange(event)
	{
		this.schedulerName = event.detail.value;
	}

	/**
	 * @description Keeps the picked or typed class name and checks it by reading its parameters.
	 *
	 * @param {CustomEvent} event The class field's classchange event.
	 */
	handleClassNameChange(event)
	{
		this.className = event.detail.value;
		this.classNameError = '';
		this.loadParameterDefinitions(this.className);
	}

	/**
	 * @description Keeps whether the job is active.
	 *
	 * @param {CustomEvent} event The toggle's change event.
	 */
	handleIsActiveChange(event)
	{
		this.isActive = event.detail.checked;
	}

	/**
	 * @description Keeps the description as typed.
	 *
	 * @param {CustomEvent} event The textarea's change event.
	 */
	handleDescriptionChange(event)
	{
		this.description = event.detail.value;
	}

	/**
	 * @description Keeps the cron expression and whether the cron editor found it valid.
	 *
	 * @param {CustomEvent} event The cron editor's cronchange event.
	 */
	handleCronChange(event)
	{
		this.cronExpression = event.detail.value;
		this.cronIsValid = event.detail.isValid !== false;
	}

	/**
	 * @description Keeps a parameter's entered value, as text; a toggle keeps 'true' or 'false'.
	 *
	 * @param {CustomEvent} event The parameter input's change event.
	 */
	handleParameterChange(event)
	{
		let parameterName = event.target.dataset.parameterName;
		let value = event.target.type === 'toggle' ? String(event.detail.checked) : String(event.detail.value ?? '');
		this.parameterValues = {...this.parameterValues, [parameterName]: value};
	}

	/**
	 * @description Builds the request the controller saves: the form as displayed, with every parameter the chosen class
	 *              declares carrying its entered value or its default. This prunes entries left behind by a previously
	 *              chosen class and persists untouched defaults.
	 *
	 * @return {Object} The save request.
	 */
	buildSaveRequest()
	{
		let parameters = null;

		if(this.hasParameterDefinitions)
		{
			parameters = {};

			for(let parameter of this.parameterDefinitions)
			{
				parameters[parameter.name] = String(this.parameterValues[parameter.name] ?? parameter.defaultValue ?? '');
			}
		}

		return {
			recordId: this.recordId || null,
			schedulerName: this.schedulerName,
			className: this.className,
			cronExpression: this.cronExpression,
			isActive: this.isActive === true,
			description: this.description,
			parameters,
			timezone: this.userTimezone
		};
	}

	/**
	 * @description Saves the form, then hands the saved record's id to completeSave; a failure goes to reportSaveFailure
	 *              as the message the error carries, or the save-failed label when it carries none.
	 *
	 * @return {Promise<void>} Resolves once the save has completed or failed.
	 */
	async handleSave()
	{
		try
		{
			this.isSaving = true;

			let resultId = await saveRecord({requestJson: JSON.stringify(this.buildSaveRequest())});
			await this.completeSave(resultId || this.recordId);
		}
		catch(error)
		{
			let message = SAVE_FAILED;

			try
			{
				let reduced = reduceErrors(error);
				if(reduced)
				{
					message = reduced;
				}
			}
			catch
			{
				// use default message
			}

			this.reportSaveFailure(message);
		}
		finally
		{
			this.isSaving = false;
		}
	}
};
