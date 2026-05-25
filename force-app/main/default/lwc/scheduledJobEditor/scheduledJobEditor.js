// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Standalone form component for creating and editing ScheduledJob__c records.
 *              Used as the content of an Aura action override for the New and Edit standard buttons.
 *              Renders the form directly in a lightning-card with embedded cron expression editor
 *              and dynamic parameter inputs. On save, redirects to the record page.
 *
 * @author Jason van Beukering
 *
 * @date March 2026, May 2026
 */
import {api, wire} from 'lwc';
import {ComponentBuilder} from 'c/componentBuilder';
import {getRecord, getFieldValue, notifyRecordUpdateAvailable} from 'lightning/uiRecordApi';
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
			this.showErrorToast(reduceErrors(error) || 'Failed to load record');
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
			this.showErrorToast(reduceErrors(error) || 'Failed to load parameter definitions');
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

			let savedRecordId = resultId || this.recordId;
			notifyRecordUpdateAvailable([{recordId: savedRecordId}]);
			this.showSuccessToast(this.isCreateMode ? 'Scheduled job created' : 'Scheduled job saved');
			this.redirectToRecordPage(savedRecordId);
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