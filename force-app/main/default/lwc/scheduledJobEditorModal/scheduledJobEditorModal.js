// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Modal dialog for creating and editing ScheduledJob__c records. Extends LightningModal
 *              to provide a standard Salesforce modal experience with fixed header/footer and scrollable
 *              body. Contains the full edit form including cron expression editor and dynamic parameter
 *              inputs. Opened programmatically via static .open() from the scheduledJobDetail component.
 *
 * @author Jason van Beukering
 *
 * @date March 2026, May 2026
 */
import LightningModal from 'lightning/modal';
import {api, wire} from 'lwc';
import {getRecord, getFieldValue} from 'lightning/uiRecordApi';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';
import {reduceErrors} from 'c/utilitySystem';
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

	_lastLoadedClassName;

	get isCreateMode()
	{
		return !this.recordId;
	}

	get modalTitle()
	{
		return this.isCreateMode ? 'New Scheduled Job' : 'Edit Scheduled Job';
	}

	get scheduleHeading()
	{
		if(this.userTimezone)
		{
			return 'Schedule (' + getTimezoneDisplayName(this.userTimezone) + ')';
		}

		return 'Schedule';
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
			return this.parameterDefinitions.some((parameter) => parameter.isRequired && !this.parameterValues[parameter.name]);
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
		catch(error)
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
		catch(error)
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
			this.dispatchEvent(new ShowToastEvent({
				title: 'Error', message: reduceErrors(error) || 'Failed to load record', variant: 'error'
			}));
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
			this.dispatchEvent(new ShowToastEvent({
				title: 'Error', message: reduceErrors(error) || 'Failed to load parameter definitions', variant: 'error'
			}));
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

			let parameters = null;

			if(this.hasParameterDefinitions)
			{
				parameters = {};

				for(let [key, value] of Object.entries(this.parameterValues))
				{
					parameters[key] = String(value ?? '');
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
				title: 'Success', message: this.isCreateMode ? 'Scheduled job created' : 'Scheduled job saved', variant: 'success'
			}));

			// Release the close guard BEFORE invoking close() — LightningModal silently ignores close()
			// while disableClose is true, leaving the modal open and blocking the parent refresh.
			this.disableClose = false;
			this.close(resultId || this.recordId);
		}
		catch(error)
		{
			let message = 'Failed to save scheduled job';

			try
			{
				let reduced = reduceErrors(error);
				if(reduced)
				{
					message = reduced;
				}
			}
			catch(reduceError)
			{
				// use default message
			}

			this.dispatchEvent(new ShowToastEvent({
				title: 'Error', message, variant: 'error'
			}));
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

/**
 * @description Returns a human-readable timezone name from an IANA TimeZoneSidKey
 * using the browser's Intl.DateTimeFormat API.
 *
 * @param {string} timezoneSidKey The IANA timezone ID (e.g., Africa/Johannesburg).
 *
 * @returns {string} The display name, or the raw SidKey as fallback.
 */
function getTimezoneDisplayName(timezoneSidKey)
{
	try
	{
		return new Intl.DateTimeFormat('en', {timeZone: timezoneSidKey, timeZoneName: 'long'})
		.formatToParts(new Date())
		.find((part) => part.type === 'timeZoneName').value;
	}
	catch(error)
	{
		return timezoneSidKey;
	}
}

/**
 * @description Parses a DTO_NameValues JSON string into a plain object.
 *
 * @param {string} attributeString The serialized DTO_NameValues JSON.
 *
 * @returns {Object} Key-value map of parsed attributes.
 */
function parseAttributes(attributeString)
{
	if(!attributeString)
	{
		return {};
	}

	try
	{
		let parsed = JSON.parse(attributeString);
		return parsed.nameValueMap || {};
	}
	catch(error)
	{
		return {};
	}
}