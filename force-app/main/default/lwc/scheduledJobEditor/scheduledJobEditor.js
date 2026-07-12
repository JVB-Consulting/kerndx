// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Standalone form component for creating and editing ScheduledJob__c records.
 *              Used as the content of an Aura action override for the New and Edit standard buttons.
 *              Renders the form directly in a lightning-card with embedded cron expression editor
 *              and dynamic parameter inputs. On save, redirects to the record page.
 *
 * @author Jason van Beukering
 *
 * @date March 2026, July 2026
 */
import {api, wire} from 'lwc';
import {ComponentBuilder} from 'c/componentBuilder';
import {getRecord, getFieldValue, notifyRecordUpdateAvailable} from 'lightning/uiRecordApi';
import {reduceErrors} from 'c/utilitySystem';
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
import {formatTemplateString} from 'c/utilityString';
import CREATE_TITLE from '@salesforce/label/c.ScheduledJob_NewTitle';
import EDIT_TITLE from '@salesforce/label/c.ScheduledJob_EditTitle';
import SCHEDULE from '@salesforce/label/c.ScheduledJob_Schedule';
import SCHEDULE_WITH_TIMEZONE from '@salesforce/label/c.ScheduledJob_ScheduleWithTimezone';
import LOAD_RECORD_FAILED from '@salesforce/label/c.ScheduledJob_LoadRecordFailed';
import LOAD_PARAMETERS_FAILED from '@salesforce/label/c.ScheduledJob_LoadParameterDefinitionsFailed';
import CREATED from '@salesforce/label/c.ScheduledJob_Created';
import SAVED from '@salesforce/label/c.ScheduledJob_Saved';
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

const FIELDS = [
	SCHEDULER_NAME_FIELD,
	CLASS_NAME_FIELD,
	CRON_EXPRESSION_FIELD,
	IS_ACTIVE_FIELD,
	DESCRIPTION_FIELD,
	PARAMETERS_FIELD,
	TIMEZONE_FIELD
];

export default class ScheduledJobEditor extends ComponentBuilder('notification', 'navigation')
{
	@api recordId;
	/**
	 * @description Names of parameters that should render read-only in the editor. Used by the customize-path
	 *              retention flow to prefill and lock the target object while leaving other parameters editable.
	 *
	 * @type {string[]}
	 */
	@api lockedFields = [];

	label = {
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

	_lastLoadedClassName;
	className = '';
	classOptions = [];
	cronExpression = '';
	cronIsValid = true;
	description = '';
	isActive = false;
	isSaving = false;
	parameterDefinitions;
	parameterValues = {};
	schedulerName = '';
	userTimezone = '';

	get isCreateMode()
	{
		return !this.recordId;
	}

	get cardTitle()
	{
		return this.isCreateMode ? CREATE_TITLE : EDIT_TITLE;
	}

	get scheduleHeading()
	{
		if(this.userTimezone)
		{
			return formatTemplateString(SCHEDULE_WITH_TIMEZONE, [getTimezoneDisplayName(this.userTimezone)]);
		}

		return SCHEDULE;
	}

	get isSaveDisabled()
	{
		if(this.isSaving)
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

	get hasParameterDefinitions()
	{
		return Boolean(this.parameterDefinitions && this.parameterDefinitions.length > 0);
	}

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

	connectedCallback()
	{
		this.loadSchedulableClasses();
		this.loadUserTimezone();
	}

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

	@wire(getRecord, {recordId: '$recordId', fields: FIELDS}) wiredRecord({data, error})
	{
		if(data)
		{
			let currentClassName = getFieldValue(data, CLASS_NAME_FIELD);

			this.schedulerName = getFieldValue(data, SCHEDULER_NAME_FIELD) || '';
			this.className = currentClassName || '';
			this.cronExpression = getFieldValue(data, CRON_EXPRESSION_FIELD) || '';
			this.isActive = getFieldValue(data, IS_ACTIVE_FIELD) || false;
			this.description = getFieldValue(data, DESCRIPTION_FIELD) || '';

			let attributeMap = parseAttributes(getFieldValue(data, PARAMETERS_FIELD) || '');
			this.parameterValues = {...attributeMap};

			if(currentClassName && currentClassName !== this._lastLoadedClassName)
			{
				this._lastLoadedClassName = currentClassName;
				this.loadParameterDefinitions(currentClassName);
			}
		}

		if(error)
		{
			this.showErrorToast(reduceErrors(error) || LOAD_RECORD_FAILED);
		}
	}

	async loadParameterDefinitions(className)
	{
		try
		{
			this.parameterDefinitions = await getParameterDefinitions({className});
		}
		catch(error)
		{
			this.parameterDefinitions = null;
			this.showErrorToast(reduceErrors(error) || LOAD_PARAMETERS_FAILED);
		}
	}

	handleSchedulerNameChange(event)
	{
		this.schedulerName = event.detail.value;
	}

	handleClassNameChange(event)
	{
		this.className = event.detail.value;
		this.loadParameterDefinitions(this.className);
	}

	handleIsActiveChange(event)
	{
		this.isActive = event.detail.checked;
	}

	handleDescriptionChange(event)
	{
		this.description = event.detail.value;
	}

	handleCronChange(event)
	{
		this.cronExpression = event.detail.value;
		this.cronIsValid = event.detail.isValid !== false;
	}

	handleParameterChange(event)
	{
		let parameterName = event.target.dataset.parameterName;
		let value = event.target.type === 'toggle' ? String(event.detail.checked) : String(event.detail.value ?? '');
		this.parameterValues = {...this.parameterValues, [parameterName]: value};
	}

	async handleSave()
	{
		try
		{
			this.isSaving = true;

			let parameters = null;

			if(this.hasParameterDefinitions)
			{
				parameters = {};

				// Serialise exactly what the form displays: every parameter defined for the currently
				// selected class, using the entered value or the pre-filled defaultValue. This prunes
				// orphaned entries left behind by a previously selected class and persists untouched defaults.
				for(let parameter of this.parameterDefinitions)
				{
					parameters[parameter.name] = String(this.parameterValues[parameter.name] ?? parameter.defaultValue ?? '');
				}
			}

			let resultId = await saveRecord({
				requestJson: JSON.stringify({
					recordId: this.recordId || null,
					schedulerName: this.schedulerName,
					className: this.className,
					cronExpression: this.cronExpression,
					isActive: this.isActive === true,
					description: this.description,
					parameters,
					timezone: this.userTimezone
				})
			});

			let savedRecordId = resultId || this.recordId;
			await notifyRecordUpdateAvailable([{recordId: savedRecordId}]);
			this.showSuccessToast(this.isCreateMode ? CREATED : SAVED);
			this.redirectToRecordPage(savedRecordId);
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

			this.showErrorToast(message);
		}
		finally
		{
			this.isSaving = false;
		}
	}

	handleCancel()
	{
		window.history.back();
	}
}