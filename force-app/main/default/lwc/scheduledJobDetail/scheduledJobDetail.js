// SPDX-License-Identifier: BUSL-1.1
/**
 * @description View-only record page component for ScheduledJob__c records. Displays job configuration
 *              with embedded cron expression descriptions and dynamic parameter tables.
 *
 * @author Jason van Beukering
 *
 * @date March 2026, May 2026
 */
import {api, wire} from 'lwc';
import {ComponentBuilder} from 'c/componentBuilder';
import {getRecord, getFieldValue} from 'lightning/uiRecordApi';
import {describeCronExpression} from 'c/cronExpressionEditor';
import {reduceErrors} from 'c/utilitySystem';
import getParameterDefinitions from '@salesforce/apex/CTRL_ScheduledJob.getParameterDefinitions';
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

export default class ScheduledJobDetail extends ComponentBuilder('notification', 'controller')
{
	@api recordId;
	record;
	parameterDefinitions;

	_lastLoadedClassName;

	get hasRecord()
	{
		return Boolean(this.record);
	}

	get viewSchedulerName()
	{
		return this.record ? getFieldValue(this.record, SCHEDULER_NAME_FIELD) : '';
	}

	get viewClassName()
	{
		return this.record ? getFieldValue(this.record, CLASS_NAME_FIELD) : '';
	}

	get viewCronExpression()
	{
		return this.record ? getFieldValue(this.record, CRON_EXPRESSION_FIELD) : '';
	}

	get viewTimezone()
	{
		return this.record ? getFieldValue(this.record, TIMEZONE_FIELD) : '';
	}

	get viewTimezoneLabel()
	{
		let timezone = this.viewTimezone;

		if(!timezone)
		{
			return '';
		}

		return getTimezoneDisplayName(timezone);
	}

	get viewCronDescription()
	{
		let description = describeCronExpression(this.viewCronExpression);
		let timezone = this.viewTimezoneLabel;

		if(timezone)
		{
			return description + ' (' + timezone + ')';
		}

		return description;
	}

	get viewIsActive()
	{
		return this.record ? getFieldValue(this.record, IS_ACTIVE_FIELD) : false;
	}

	get viewDescription()
	{
		return this.record ? getFieldValue(this.record, DESCRIPTION_FIELD) : '';
	}

	get viewParameters()
	{
		return this.record ? getFieldValue(this.record, PARAMETERS_FIELD) : '';
	}

	get hasViewDescription()
	{
		return Boolean(this.viewDescription);
	}

	get hasParameterDefinitions()
	{
		return Boolean(this.parameterDefinitions && this.parameterDefinitions.length > 0);
	}

	get viewParameterPairs()
	{
		if(!this.hasParameterDefinitions || !this.viewParameters)
		{
			return [];
		}

		let attributeMap = parseAttributes(this.viewParameters);
		return this.parameterDefinitions.map((parameter) => ({
			name: parameter.name, label: parameter.label, value: attributeMap[parameter.name] || parameter.defaultValue || '', dataType: parameter.dataType
		}));
	}

	get hasViewParameterPairs()
	{
		return this.viewParameterPairs.length > 0;
	}

	get activeStatusLabel()
	{
		return this.viewIsActive ? 'Active' : 'Inactive';
	}

	get activeStatusVariant()
	{
		return this.viewIsActive ? 'slds-badge badge-success' : 'slds-badge';
	}

	@wire(getRecord, {recordId: '$recordId', fields: FIELDS}) wiredRecord({data, error})
	{
		if(data)
		{
			this.record = data;
			let currentClassName = getFieldValue(data, CLASS_NAME_FIELD);

			if(currentClassName && currentClassName !== this._lastLoadedClassName)
			{
				this._lastLoadedClassName = currentClassName;
				this.loadParameterDefinitions(currentClassName);
			}
		}

		if(error)
		{
			this.record = undefined;
		}
	}

	async loadParameterDefinitions(className)
	{
		try
		{
			this.parameterDefinitions = await this.callControllerMethod(getParameterDefinitions, {className});
		}
		catch(error)
		{
			this.parameterDefinitions = null;
			this.showErrorToast(reduceErrors(error) || 'Failed to load parameter definitions');
		}
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
 * @description Parses a DTO_NameValues JSON string into a plain object. Callers are
 * expected to have already verified the string is non-empty; invalid JSON is
 * caught and surfaced as an empty map so a malformed Parameters__c value never
 * breaks rendering.
 *
 * @param {string} attributeString The raw attributes JSON string.
 *
 * @returns {Object} Key-value map of parsed attributes.
 */
function parseAttributes(attributeString)
{
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