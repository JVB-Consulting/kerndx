// SPDX-License-Identifier: BUSL-1.1
/**
 * @description View-only record page component for ScheduledJob__c records. Displays job configuration
 *              with embedded cron expression descriptions and dynamic parameter tables.
 *
 * @author Jason van Beukering
 *
 * @date March 2026, July 2026
 */
import {api, wire} from 'lwc';
import {ComponentBuilder} from 'c/componentBuilder';
import {getRecord, getFieldValue} from 'lightning/uiRecordApi';
import {describeCronExpression} from 'c/cronExpressionEditor';
import {reduceErrors} from 'c/utilitySystem';
import {getTimezoneDisplayName, parseAttributes} from 'c/utilityScheduledJob';
import getParameterDefinitions from '@salesforce/apex/CTRL_ScheduledJob.getParameterDefinitions';
import LOADING_LABEL from '@salesforce/label/c.ScheduledJobDetail_Loading';
import LOAD_FAILED_LABEL from '@salesforce/label/c.ScheduledJobDetail_LoadFailed';
import LOAD_PARAMETERS_FAILED from '@salesforce/label/c.ScheduledJob_LoadParameterDefinitionsFailed';
import CARD_TITLE from '@salesforce/label/c.ScheduledJobDetail_CardTitle';
import SCHEDULER_NAME from '@salesforce/label/c.ScheduledJob_SchedulerName';
import CLASS_NAME from '@salesforce/label/c.ScheduledJob_ClassName';
import STATUS from '@salesforce/label/c.ScheduledJobDetail_Status';
import SCHEDULE from '@salesforce/label/c.ScheduledJob_Schedule';
import NO_SCHEDULE from '@salesforce/label/c.ScheduledJobDetail_NoSchedule';
import PARAMETERS from '@salesforce/label/c.ScheduledJob_Parameters';
import PARAMETER_COLUMN from '@salesforce/label/c.ScheduledJobDetail_ParameterColumn';
import VALUE_COLUMN from '@salesforce/label/c.ScheduledJobDetail_ValueColumn';
import DESCRIPTION from '@salesforce/label/c.ScheduledJob_Description';
import ACTIVE_STATUS from '@salesforce/label/c.ScheduledJob_Active';
import INACTIVE_STATUS from '@salesforce/label/c.ScheduledJob_Inactive';
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

	/**
	 * @description Message rendered in the card's inline error state when the record wire fails.
	 *              Empty when the record loaded (or is still loading) without error.
	 *
	 * @type {string}
	 */
	loadErrorMessage = '';

	/**
	 * @description Static label strings the template renders.
	 */
	labels = {
		loading: LOADING_LABEL,
		cardTitle: CARD_TITLE,
		schedulerName: SCHEDULER_NAME,
		className: CLASS_NAME,
		status: STATUS,
		schedule: SCHEDULE,
		noSchedule: NO_SCHEDULE,
		parameters: PARAMETERS,
		parameterColumn: PARAMETER_COLUMN,
		valueColumn: VALUE_COLUMN,
		description: DESCRIPTION
	};

	_lastLoadedClassName;

	get hasRecord()
	{
		return Boolean(this.record);
	}

	/**
	 * @description Whether the record wire has not yet emitted data or an error.
	 *
	 * @return {boolean} True while the initial record load is still in flight.
	 */
	get isLoadingRecord()
	{
		return !this.record && !this.loadErrorMessage;
	}

	/**
	 * @description Whether the record wire failed, so the inline error state should render.
	 *
	 * @return {boolean} True when a load error message is waiting to be shown.
	 */
	get hasLoadError()
	{
		return Boolean(this.loadErrorMessage);
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
		return this.viewIsActive ? ACTIVE_STATUS : INACTIVE_STATUS;
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
			this.loadErrorMessage = '';
			let currentClassName = getFieldValue(data, CLASS_NAME_FIELD);

			if(currentClassName && currentClassName !== this._lastLoadedClassName)
			{
				this._lastLoadedClassName = currentClassName;
				this.loadParameterDefinitions(currentClassName);
			}
		}

		if(error)
		{
			// Surface the failure instead of blanking silently; the template renders
			// this message in the card's inline error state.
			this.record = undefined;
			this.loadErrorMessage = reduceErrors(error) || LOAD_FAILED_LABEL;
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
			this.showErrorToast(reduceErrors(error) || LOAD_PARAMETERS_FAILED);
		}
	}

}