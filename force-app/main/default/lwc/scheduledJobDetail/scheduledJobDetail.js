// SPDX-License-Identifier: BUSL-1.1
/**
 * @description View-only record page component for ScheduledJob__c records. Displays job configuration
 *              with embedded cron expression descriptions and dynamic parameter tables.
 *
 * @author Jason van Beukering
 *
 * @date March 2026, September 2026
 */
import {api, wire} from 'lwc';
import {ComponentBuilder} from 'c/componentBuilder';
import {getRecord, getFieldValue, getFieldDisplayValue, notifyRecordUpdateAvailable} from 'lightning/uiRecordApi';
import {describeCronExpression} from 'c/cronExpressionEditor';
import {reduceErrors} from 'c/utilitySystem';
import {getTimezoneDisplayName, parseAttributes, formatInstant} from 'c/utilityScheduledJob';
import {formatTemplateString} from 'c/utilityString';
import getParameterDefinitions from '@salesforce/apex/CTRL_ScheduledJob.getParameterDefinitions';
import getJobRunnerState from '@salesforce/apex/CTRL_ScheduledJob.getJobRunnerState';
import runNow from '@salesforce/apex/CTRL_ScheduledJob.runNow';
import findLastRunLogEntryId from '@salesforce/apex/CTRL_ScheduledJob.findLastRunLogEntryId';
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
import EXECUTION_MODE_FIELD from '@salesforce/schema/ScheduledJob__c.ExecutionMode__c';
import NEXT_RUN_AT_FIELD from '@salesforce/schema/ScheduledJob__c.NextRunAt__c';
import LAST_RUN_AT_FIELD from '@salesforce/schema/ScheduledJob__c.LastRunAt__c';
import LAST_RUN_OUTCOME_FIELD from '@salesforce/schema/ScheduledJob__c.LastRunOutcome__c';
import LAST_RUN_REASON_FIELD from '@salesforce/schema/ScheduledJob__c.LastRunReason__c';
import EXECUTION_MODE from '@salesforce/label/c.ScheduledJobDetail_ExecutionMode';
import NEXT_RUN from '@salesforce/label/c.ScheduledJobDetail_NextRun';
import LAST_RUN from '@salesforce/label/c.ScheduledJobDetail_LastRun';
import LAST_RUN_OUTCOME from '@salesforce/label/c.ScheduledJobDetail_LastRunOutcome';
import LAST_RUN_REASON from '@salesforce/label/c.ScheduledJobDetail_LastRunReason';
import NO_RUN_YET from '@salesforce/label/c.ScheduledJobDetail_NoRunYet';
import VIEW_LOG from '@salesforce/label/c.ScheduledJobDetail_ViewLog';
import LOG_ENTRY_NOT_FOUND from '@salesforce/label/c.ScheduledJobDetail_LogEntryNotFound';
import RUN_NOW_LABEL from '@salesforce/label/c.ScheduledJob_RunNow';
import RUN_NOW_STARTED from '@salesforce/label/c.ScheduledJob_RunNowStarted';
import EXECUTION_MODE_OWN from '@salesforce/label/c.ScheduledJob_ExecutionModeOwn';
import EXECUTION_MODE_JOB_RUNNER from '@salesforce/label/c.ScheduledJob_ExecutionModeJobRunner';
import SKIPPED_PREVIOUS_RUN_STILL_RUNNING from '@salesforce/label/c.ScheduledJob_SkippedPreviousRunStillRunning';
import SKIPPED_RECORD_NO_LONGER_ON_RUNNER from '@salesforce/label/c.ScheduledJob_SkippedRecordNoLongerOnRunner';
import PARKED_CLASS_NOT_FOUND from '@salesforce/label/c.ScheduledJob_ParkedClassNotFound';
import PARKED_EXPRESSION_CANNOT_BE_PLACED from '@salesforce/label/c.ScheduledJob_ParkedExpressionCannotBePlaced';
import EXPRESSION_CANNOT_FIRE_WITHIN_HORIZON from '@salesforce/label/c.ScheduledJob_ExpressionCannotFireWithinHorizon';

const FIELDS = [
	SCHEDULER_NAME_FIELD,
	CLASS_NAME_FIELD,
	CRON_EXPRESSION_FIELD,
	IS_ACTIVE_FIELD,
	DESCRIPTION_FIELD,
	PARAMETERS_FIELD,
	TIMEZONE_FIELD,
	EXECUTION_MODE_FIELD,
	NEXT_RUN_AT_FIELD,
	LAST_RUN_AT_FIELD,
	LAST_RUN_OUTCOME_FIELD,
	LAST_RUN_REASON_FIELD
];

/**
 * @description Picklist value for a job the job runner starts.
 */
const EXECUTION_MODE_JOB_RUNNER_VALUE = 'JobRunner';

/**
 * @description Outcome of a run that finished with an error.
 */
const OUTCOME_FAILED = 'Failed';

/**
 * @description Outcome of a run the job runner could not place, which takes the job off the runner's list.
 */
const OUTCOME_PARKED = 'Parked';

/**
 * @description Outcome of a run that finished cleanly.
 */
const OUTCOME_SUCCEEDED = 'Succeeded';

/**
 * @description Reason value for a job parked because its class could not be loaded. Its sentence names the
 *              class, so it is formatted rather than read from the map below.
 */
const REASON_CLASS_NOT_FOUND = 'ClassNotFound';

/**
 * @description The sentence each reason value is shown as, so the view never shows a stored value as it is.
 */
const LAST_RUN_REASON_SENTENCES = Object.freeze({
	PreviousRunStillRunning: SKIPPED_PREVIOUS_RUN_STILL_RUNNING,
	RecordNoLongerOnRunner: SKIPPED_RECORD_NO_LONGER_ON_RUNNER,
	ExpressionCannotBePlaced: PARKED_EXPRESSION_CANNOT_BE_PLACED,
	ExpressionCannotFireWithinHorizon: EXPRESSION_CANNOT_FIRE_WITHIN_HORIZON
});

/**
 * @description Whether a record keeps its own scheduled job or runs on the job runner.
 *
 * @param {Object} record The wired record, which may be absent while it loads.
 *
 * @return {boolean} True when the record runs on the job runner.
 */
function isOnJobRunner(record)
{
	return Boolean(record) && getFieldValue(record, EXECUTION_MODE_FIELD) === EXECUTION_MODE_JOB_RUNNER_VALUE;
}

export default class ScheduledJobDetail extends ComponentBuilder('notification', 'controller', 'navigation')
{
	@api recordId;
	record;
	parameterDefinitions;

	/**
	 * @description Whether a job runner is active, how often it checks for due jobs, and whether the running
	 *              user may start a run from this page.
	 *
	 * @type {{isActive: boolean, checkIntervalMinutes: (number|null), canManage: boolean}}
	 */
	jobRunnerState = {isActive: false, checkIntervalMinutes: null, canManage: false};

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
		description: DESCRIPTION,
		executionMode: EXECUTION_MODE,
		nextRun: NEXT_RUN,
		lastRun: LAST_RUN,
		lastRunOutcome: LAST_RUN_OUTCOME,
		lastRunReason: LAST_RUN_REASON,
		viewLog: VIEW_LOG,
		runNow: RUN_NOW_LABEL
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
		let description = describeCronExpression(this.viewCronExpression, {
			jobRunnerMode: isOnJobRunner(this.record), activeCheckIntervalMinutes: this.jobRunnerState.isActive ? this.jobRunnerState.checkIntervalMinutes : null
		});
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

	/**
	 * @description Whether this job runs on the job runner, which is what brings the runner rows and the
	 *              Run now button onto the page.
	 *
	 * @return {boolean} True when the job runs on the job runner.
	 */
	get isJobRunnerRecord()
	{
		return isOnJobRunner(this.record);
	}

	/**
	 * @description Where the job runs, in the words the editor offers.
	 *
	 * @return {string} The name of the place the job runs.
	 */
	get viewExecutionMode()
	{
		return isOnJobRunner(this.record) ? EXECUTION_MODE_JOB_RUNNER : EXECUTION_MODE_OWN;
	}

	/**
	 * @description When the job runner next starts this job.
	 *
	 * @return {string} The instant, or an empty string when there is no next run.
	 */
	get viewNextRun()
	{
		return formatInstant(getFieldValue(this.record, NEXT_RUN_AT_FIELD));
	}

	/**
	 * @description When the job runner last started this job.
	 *
	 * @return {string} The instant, or the never-run words.
	 */
	get viewLastRun()
	{
		return formatInstant(getFieldValue(this.record, LAST_RUN_AT_FIELD)) || NO_RUN_YET;
	}

	/**
	 * @description How the last run ended, in the reader's own language: the platform's translated picklist
	 *              label, falling back to the stored value when the record carries no label for it.
	 *
	 * @return {string} The outcome, or the never-run words.
	 */
	get viewLastRunOutcome()
	{
		return getFieldDisplayValue(this.record, LAST_RUN_OUTCOME_FIELD) || getFieldValue(this.record, LAST_RUN_OUTCOME_FIELD) || NO_RUN_YET;
	}

	/**
	 * @description Why the last run was skipped or the job was parked, as a whole sentence. A reason this
	 *              release does not know is shown as it is stored, so the row is never blank.
	 *
	 * @return {string} The sentence, or an empty string when there is nothing to explain.
	 */
	get viewLastRunReason()
	{
		let reason = getFieldValue(this.record, LAST_RUN_REASON_FIELD);

		if(!reason)
		{
			return '';
		}

		if(reason === REASON_CLASS_NOT_FOUND)
		{
			return formatTemplateString(PARKED_CLASS_NOT_FOUND, [getFieldValue(this.record, CLASS_NAME_FIELD)]);
		}

		return LAST_RUN_REASON_SENTENCES[reason] || reason;
	}

	/**
	 * @description Whether the last run has something to explain.
	 *
	 * @return {boolean} True when the record holds a reason.
	 */
	get hasLastRunReason()
	{
		return Boolean(getFieldValue(this.record, LAST_RUN_REASON_FIELD));
	}

	/**
	 * @description The badge styling that matches the last outcome.
	 *
	 * @return {string} The badge classes for the outcome.
	 */
	get outcomeBadgeClass()
	{
		let outcome = getFieldValue(this.record, LAST_RUN_OUTCOME_FIELD);

		if(outcome === OUTCOME_SUCCEEDED)
		{
			return 'slds-badge badge-success';
		}

		if(outcome === OUTCOME_FAILED)
		{
			return 'slds-badge slds-theme_error';
		}

		if(outcome === OUTCOME_PARKED)
		{
			return 'slds-badge slds-theme_warning';
		}

		return 'slds-badge';
	}

	/**
	 * @description Whether to offer a way to the log entry of the last run. A failed run and a parked job both
	 *              write one; a clean run has nothing to read.
	 *
	 * @return {boolean} True when there is a log entry to offer.
	 */
	get showLastRunLog()
	{
		let outcome = getFieldValue(this.record, LAST_RUN_OUTCOME_FIELD);

		return outcome === OUTCOME_FAILED || outcome === OUTCOME_PARKED;
	}

	/**
	 * @description Whether to offer Run now: only for an active job on the runner, and only to a user who may
	 *              manage the runner.
	 *
	 * @return {boolean} True when the button belongs on the page.
	 */
	get showRunNow()
	{
		return isOnJobRunner(this.record) && getFieldValue(this.record, IS_ACTIVE_FIELD) === true && this.jobRunnerState.canManage;
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

	connectedCallback()
	{
		this.loadJobRunnerState();
	}

	/**
	 * @description Reads whether a runner is active, how often it checks and whether this user may start a run
	 *              from this page. A failure leaves the page without the Run now button.
	 *
	 * @return {Promise<void>} Resolves once the state has been read.
	 */
	async loadJobRunnerState()
	{
		try
		{
			this.jobRunnerState = await getJobRunnerState({}) || this.jobRunnerState;
		}
		catch
		{
			this.jobRunnerState = {isActive: false, checkIntervalMinutes: null, canManage: false};
		}
	}

	/**
	 * @description Starts the job now and says so. A refusal reaches the user as an error toast carrying the
	 *              controller's own words, and nothing starts.
	 *
	 * @return {Promise<void>} Resolves once the run has been asked for.
	 */
	async handleRunNow()
	{
		let runJobId = await this.callControllerMethod(runNow, {recordId: this.recordId});

		if(runJobId)
		{
			this.showSuccessToast(RUN_NOW_STARTED);
			await notifyRecordUpdateAvailable([{recordId: this.recordId}]);
		}
	}

	/**
	 * @description Opens the log entry the last run wrote. When no entry is left, or the user may not read log
	 *              entries, the page says so instead of opening nothing. A call that failed outright has already
	 *              been reported to the user, so it adds nothing.
	 *
	 * @return {Promise<void>} Resolves once the entry has been looked for.
	 */
	async handleViewLastRunLog()
	{
		let logEntryId = await this.callControllerMethod(findLastRunLogEntryId, {recordId: this.recordId});

		if(logEntryId)
		{
			this.redirectToRecordPage(logEntryId);
			return;
		}

		if(logEntryId === undefined)
		{
			return;
		}

		this.showErrorToast(LOG_ENTRY_NOT_FOUND);
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