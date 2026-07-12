// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Modal dialog for creating and editing ScheduledJob__c records. Extends LightningModal
 *              to provide a standard Salesforce modal experience with fixed header/footer and scrollable
 *              body. Contains the full edit form including cron expression editor and dynamic parameter
 *              inputs. Opened programmatically via static .open() from the scheduledJobDetail component.
 *
 * @author Jason van Beukering
 *
 * @date March 2026, July 2026
 */
import LightningModal from 'lightning/modal';
import {api, wire} from 'lwc';
import {getRecord, getFieldValue} from 'lightning/uiRecordApi';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';
import {reduceErrors} from 'c/utilitySystem';
import {formatTemplateString} from 'c/utilityString';
import {getTimezoneDisplayName, parseAttributes} from 'c/utilityScheduledJob';
import getSchedulableClasses from '@salesforce/apex/CTRL_ScheduledJob.getSchedulableClasses';
import getParameterDefinitions from '@salesforce/apex/CTRL_ScheduledJob.getParameterDefinitions';
import getUserTimezone from '@salesforce/apex/CTRL_ScheduledJob.getUserTimezone';
import saveRecord from '@salesforce/apex/CTRL_ScheduledJob.saveRecord';
import LOAD_RECORD_FAILED_LABEL from '@salesforce/label/c.ScheduledJob_LoadRecordFailed';
import LOAD_PARAMETER_DEFINITIONS_FAILED_LABEL from '@salesforce/label/c.ScheduledJob_LoadParameterDefinitionsFailed';
import SAVE_FAILED_LABEL from '@salesforce/label/c.ScheduledJob_SaveFailed';
import CREATE_TITLE from '@salesforce/label/c.ScheduledJob_NewTitle';
import EDIT_TITLE from '@salesforce/label/c.ScheduledJob_EditTitle';
import SCHEDULE from '@salesforce/label/c.ScheduledJob_Schedule';
import SCHEDULE_WITH_TIMEZONE from '@salesforce/label/c.ScheduledJob_ScheduleWithTimezone';
import SUCCESS_TOAST_TITLE from '@salesforce/label/c.ScheduledJobEditorModal_SuccessToastTitle';
import CREATED from '@salesforce/label/c.ScheduledJob_Created';
import SAVED from '@salesforce/label/c.ScheduledJob_Saved';
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
import SCHEDULER_NAME_FIELD from '@salesforce/schema/ScheduledJob__c.SchedulerName__c';
import CLASS_NAME_FIELD from '@salesforce/schema/ScheduledJob__c.ClassName__c';
import CRON_EXPRESSION_FIELD from '@salesforce/schema/ScheduledJob__c.CronExpression__c';
import IS_ACTIVE_FIELD from '@salesforce/schema/ScheduledJob__c.IsActive__c';
import DESCRIPTION_FIELD from '@salesforce/schema/ScheduledJob__c.Description__c';
import PARAMETERS_FIELD from '@salesforce/schema/ScheduledJob__c.Parameters__c';
import TIMEZONE_FIELD from '@salesforce/schema/ScheduledJob__c.Timezone__c';

const FIELDS = [
	SCHEDULER_NAME_FIELD,
	CLASS_NAME_FIELD,
	CRON_EXPRESSION_FIELD,
	IS_ACTIVE_FIELD,
	DESCRIPTION_FIELD,
	PARAMETERS_FIELD,
	TIMEZONE_FIELD
];

export default class ScheduledJobEditorModal extends LightningModal
{
	/**
	 * @description The ScheduledJob__c record ID to edit. When omitted, the modal operates in create mode.
	 *
	 * @type {string}
	 */
	@api recordId;

	/**
	 * @description Optional create-mode payload used to pre-populate the form when no recordId is supplied.
	 *              Supported keys: schedulerName, className, cronExpression, isActive, description, parameterValues.
	 *
	 * @type {Object}
	 */
	@api prefill;

	/**
	 * @description Field names that should render read-only. Forwarded to child form inputs for
	 *              lock-in-place behaviour when launched from the customize flow.
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

	schedulerName = '';
	className = '';
	cronExpression = '';
	isActive = false;
	description = '';

	classOptions = [];
	parameterDefinitions;
	parameterValues = {};
	cronIsValid = true;
	isSaving = false;
	userTimezone = '';

	/**
	 * @description Message rendered in the modal's inline error region. Toasts dispatched while a
	 *              LightningModal is open are swallowed by the overlay, so save/load failures surface
	 *              here instead. Empty when there is no error to show.
	 *
	 * @type {string}
	 */
	errorMessage = '';

	_lastLoadedClassName;

	get isCreateMode()
	{
		return !this.recordId;
	}

	get modalTitle()
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

	/**
	 * @description Whether the inline error region should render.
	 *
	 * @return {boolean} True when an error message is waiting to be shown.
	 */
	get hasErrorMessage()
	{
		return Boolean(this.errorMessage);
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

	/**
	 * @description Whether the class-name combobox should be disabled because `className` appears in lockedFields.
	 *              Used by the customize-path flow, which locks both the target object parameter and the scheduler
	 *              class to prevent the user from changing the retention scheduler selection.
	 *
	 * @return {boolean} True when the combobox should render disabled.
	 */
	get isClassNameLocked()
	{
		let lockedNames = Array.isArray(this.lockedFields) ? this.lockedFields : [];
		return lockedNames.indexOf('className') !== -1;
	}

	connectedCallback()
	{
		this.loadSchedulableClasses();
		this.loadUserTimezone();

		if(!this.recordId && this.prefill)
		{
			let prefill = this.prefill;

			this.schedulerName = prefill.schedulerName || this.schedulerName;
			this.className = prefill.className || this.className;
			this.cronExpression = prefill.cronExpression || this.cronExpression;

			if(prefill.isActive !== undefined && prefill.isActive !== null)
			{
				this.isActive = prefill.isActive === true;
			}

			if(prefill.description)
			{
				this.description = prefill.description;
			}

			if(prefill.parameterValues && typeof prefill.parameterValues === 'object')
			{
				this.parameterValues = {...prefill.parameterValues};
			}

			if(prefill.className)
			{
				this._lastLoadedClassName = prefill.className;
				this.loadParameterDefinitions(prefill.className);
			}
		}
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
			this.errorMessage = '';

			if(currentClassName && currentClassName !== this._lastLoadedClassName)
			{
				this._lastLoadedClassName = currentClassName;
				this.loadParameterDefinitions(currentClassName);
			}
		}

		if(error)
		{
			this.errorMessage = reduceErrors(error) || LOAD_RECORD_FAILED_LABEL;
		}
	}

	async loadParameterDefinitions(className)
	{
		try
		{
			this.parameterDefinitions = await getParameterDefinitions({className});
			this.errorMessage = '';
		}
		catch(error)
		{
			this.parameterDefinitions = null;
			this.errorMessage = reduceErrors(error) || LOAD_PARAMETER_DEFINITIONS_FAILED_LABEL;
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
			this.disableClose = true;
			this.errorMessage = '';

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

			this.dispatchEvent(new ShowToastEvent({
				title: SUCCESS_TOAST_TITLE, message: this.isCreateMode ? CREATED : SAVED, variant: 'success'
			}));

			// Release the close guard BEFORE invoking close() — LightningModal silently ignores close()
			// while disableClose is true, leaving the modal open and blocking the parent refresh.
			this.disableClose = false;
			this.close(resultId || this.recordId);
		}
		catch(error)
		{
			let message = SAVE_FAILED_LABEL;

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

			// Surface the failure inside the modal: a toast dispatched while the modal
			// stays open is swallowed by the overlay and the admin never sees it.
			this.errorMessage = message;
		}
		finally
		{
			this.isSaving = false;
			this.disableClose = false;
		}
	}

	handleCancel()
	{
		this.close(null);
	}
}