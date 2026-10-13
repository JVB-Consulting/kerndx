// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Standalone form component for creating and editing ScheduledJob__c records.
 *              Used as the content of an Aura action override for the New and Edit standard buttons.
 *              Renders the shared scheduled job form in a lightning-card and adds the job runner fields:
 *              where the job runs, its priority, its overlap policy and a preview of its next run. On save,
 *              redirects to the record page.
 *
 * @author Jason van Beukering
 *
 * @date March 2026, October 2026
 */
import {api, wire} from 'lwc';
import {ComponentBuilder} from 'c/componentBuilder';
import {getRecord, getFieldValue, notifyRecordUpdateAvailable} from 'lightning/uiRecordApi';
import {reduceErrors} from 'c/utilitySystem';
import {formatInstant} from 'c/utilityScheduledJob';
import {ScheduledJobEditorForm, SCHEDULED_JOB_FORM_FIELDS, SCHEDULED_JOB_FORM_LABELS} from 'c/scheduledJobEditorForm';
import getJobRunnerState from '@salesforce/apex/CTRL_ScheduledJob.getJobRunnerState';
import previewNextRun from '@salesforce/apex/CTRL_ScheduledJob.previewNextRun';
import EXECUTION_MODE_FIELD from '@salesforce/schema/ScheduledJob__c.ExecutionMode__c';
import RUN_PRIORITY_FIELD from '@salesforce/schema/ScheduledJob__c.RunPriority__c';
import OVERLAP_POLICY_FIELD from '@salesforce/schema/ScheduledJob__c.OverlapPolicy__c';
import {formatTemplateString} from 'c/utilityString';
import LOAD_RECORD_FAILED from '@salesforce/label/c.ScheduledJob_LoadRecordFailed';
import CREATED from '@salesforce/label/c.ScheduledJob_Created';
import SAVED from '@salesforce/label/c.ScheduledJob_Saved';
import EXECUTION_MODE_LABEL from '@salesforce/label/c.ScheduledJob_ExecutionMode';
import EXECUTION_MODE_OWN from '@salesforce/label/c.ScheduledJob_ExecutionModeOwn';
import EXECUTION_MODE_JOB_RUNNER from '@salesforce/label/c.ScheduledJob_ExecutionModeJobRunner';
import JOB_RUNNER_INACTIVE_NOTE from '@salesforce/label/c.ScheduledJob_JobRunnerInactiveNote';
import JOB_RUNNER_ACTIVE_NOTE from '@salesforce/label/c.ScheduledJob_JobRunnerActiveNote';
import JOB_RUNNER_PERMISSION_NOTE from '@salesforce/label/c.ScheduledJob_JobRunnerPermissionNote';
import RUN_PRIORITY_LABEL from '@salesforce/label/c.ScheduledJob_RunPriority';
import RUN_PRIORITY_HELP from '@salesforce/label/c.ScheduledJob_RunPriorityHelp';
import OVERLAP_POLICY_LABEL from '@salesforce/label/c.ScheduledJob_OverlapPolicy';
import OVERLAP_POLICY_SKIP from '@salesforce/label/c.ScheduledJob_OverlapPolicySkip';
import OVERLAP_POLICY_ALLOW from '@salesforce/label/c.ScheduledJob_OverlapPolicyAllow';
import NEXT_RUN_PREVIEW from '@salesforce/label/c.ScheduledJob_NextRunPreview';
import NEXT_RUN_PREVIEW_UNAVAILABLE from '@salesforce/label/c.ScheduledJob_NextRunPreviewUnavailable';

const FIELDS = [
	...SCHEDULED_JOB_FORM_FIELDS,
	EXECUTION_MODE_FIELD,
	RUN_PRIORITY_FIELD,
	OVERLAP_POLICY_FIELD
];

/**
 * @description Picklist value for a job that keeps its own scheduled job.
 */
const EXECUTION_MODE_OWN_VALUE = 'OwnScheduledJob';

/**
 * @description Picklist value for a job the job runner starts.
 */
const EXECUTION_MODE_JOB_RUNNER_VALUE = 'JobRunner';

/**
 * @description Picklist value for skipping a run while the previous one is still running.
 */
const OVERLAP_POLICY_SKIP_VALUE = 'Skip';

/**
 * @description Picklist value for letting runs overlap.
 */
const OVERLAP_POLICY_ALLOW_VALUE = 'Allow';

export default class ScheduledJobEditor extends ScheduledJobEditorForm(ComponentBuilder('notification', 'navigation'))
{
	/**
	 * @description The ScheduledJob__c record to edit. The shared form declares and reads it since 1.8; it stays
	 *              declared here because a managed package keeps every public property it released.
	 *
	 * @type {string}
	 */
	@api recordId;

	/**
	 * @description Names of parameters that render read-only, used by the customize path to lock the target object
	 *              while the other parameters stay editable. The shared form declares and reads it since 1.8; it
	 *              stays declared here because a managed package keeps every public property it released.
	 *
	 * @type {string[]}
	 */
	@api lockedFields = [];

	label = {
		...SCHEDULED_JOB_FORM_LABELS,
		executionMode: EXECUTION_MODE_LABEL,
		runPriority: RUN_PRIORITY_LABEL,
		runPriorityHelp: RUN_PRIORITY_HELP,
		overlapPolicy: OVERLAP_POLICY_LABEL,
		jobRunnerPermissionNote: JOB_RUNNER_PERMISSION_NOTE
	};

	/**
	 * @description Where the job runs: its own scheduled job, or the job runner.
	 *
	 * @type {string}
	 */
	executionMode = EXECUTION_MODE_OWN_VALUE;

	/**
	 * @description The order this job takes among the jobs due at the same check of the runner, as typed.
	 *              Empty means the job goes last.
	 *
	 * @type {(string|number)}
	 */
	runPriority = '';

	/**
	 * @description What happens when a run is due while the previous one is still running.
	 *
	 * @type {string}
	 */
	overlapPolicy = OVERLAP_POLICY_SKIP_VALUE;

	/**
	 * @description Whether a job runner is active, how often it checks for due jobs, and whether the
	 *              running user may put a job on it.
	 *
	 * @type {{isActive: boolean, checkIntervalMinutes: (number|null), canManage: boolean}}
	 */
	jobRunnerState = {isActive: false, checkIntervalMinutes: null, canManage: false};

	/**
	 * @description The instant the current expression next fires, as the controller reported it.
	 *              Empty when there is nothing to show.
	 *
	 * @type {string}
	 */
	nextRunPreview = '';

	/**
	 * @description Whether the job being edited is set to run on the job runner.
	 *
	 * @return {boolean} True when the runner option is chosen.
	 */
	get isJobRunnerMode()
	{
		return this.executionMode === EXECUTION_MODE_JOB_RUNNER_VALUE;
	}

	/**
	 * @description The two places a job can run, for the execution-mode radio.
	 *
	 * @return {Object[]} The own-scheduled-job option and the job runner option.
	 */
	get executionModeOptions()
	{
		return [
			{label: EXECUTION_MODE_OWN, value: EXECUTION_MODE_OWN_VALUE},
			{label: EXECUTION_MODE_JOB_RUNNER, value: EXECUTION_MODE_JOB_RUNNER_VALUE}
		];
	}

	/**
	 * @description Whether the choice of where the job runs is closed to this user. It is closed only when the
	 *              user may not manage the runner and the job is not already on it, so a job already on the
	 *              runner stays editable.
	 *
	 * @return {boolean} True when the radio is disabled.
	 */
	get isExecutionModeDisabled()
	{
		return !this.jobRunnerState.canManage && !this.isJobRunnerMode;
	}

	/**
	 * @description Whether to say which permission puts a job on the runner.
	 *
	 * @return {boolean} True when the running user may not manage the runner.
	 */
	get showPermissionNote()
	{
		return !this.jobRunnerState.canManage;
	}

	/**
	 * @description How often an active runner checks for due jobs, for the cron editor's presets. Null while
	 *              no runner is active, which leaves every interval on offer.
	 *
	 * @return {(number|null)} The number of minutes between checks, or null.
	 */
	get activeCheckIntervalMinutes()
	{
		return this.jobRunnerState.isActive ? this.jobRunnerState.checkIntervalMinutes : null;
	}

	/**
	 * @description What the runner does with this job: when the runner starts it, or that the job waits until
	 *              a runner is activated.
	 *
	 * @return {string} The sentence shown under the execution-mode radio.
	 */
	get jobRunnerNote()
	{
		return this.jobRunnerState.isActive ? formatTemplateString(JOB_RUNNER_ACTIVE_NOTE, [this.jobRunnerState.checkIntervalMinutes]) : JOB_RUNNER_INACTIVE_NOTE;
	}

	/**
	 * @description The two answers to a run falling due while the previous one is still running.
	 *
	 * @return {Object[]} The skip option and the allow option.
	 */
	get overlapPolicyOptions()
	{
		return [
			{label: OVERLAP_POLICY_SKIP, value: OVERLAP_POLICY_SKIP_VALUE},
			{label: OVERLAP_POLICY_ALLOW, value: OVERLAP_POLICY_ALLOW_VALUE}
		];
	}

	/**
	 * @description The next-run line under the schedule: the instant the expression next fires, or a line
	 *              saying the expression has to be valid first.
	 *
	 * @return {string} The line to show.
	 */
	get nextRunPreviewLabel()
	{
		return this.nextRunPreview ? formatTemplateString(NEXT_RUN_PREVIEW, [formatInstant(this.nextRunPreview)]) : NEXT_RUN_PREVIEW_UNAVAILABLE;
	}

	/**
	 * @description Reads what the shared form reads, and the job runner's state.
	 */
	connectedCallback()
	{
		super.connectedCallback();
		this.loadJobRunnerState();
	}

	/**
	 * @description Reads whether a runner is active, how often it checks and whether this user may manage it.
	 *              A failure leaves the editor offering the own-scheduled-job mode only.
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
	 * @description Asks the controller when the current expression next fires, so the editor shows what the
	 *              runner's check will do. Only a valid expression on the runner has a next run to show.
	 *
	 * @return {Promise<void>} Resolves once the preview has been refreshed.
	 */
	async refreshNextRunPreview()
	{
		if(!this.isJobRunnerMode || !this.cronIsValid || !this.cronExpression)
		{
			this.nextRunPreview = '';
			return;
		}

		try
		{
			this.nextRunPreview = await previewNextRun({cronExpression: this.cronExpression, timezone: this.userTimezone}) || '';
		}
		catch
		{
			this.nextRunPreview = '';
		}
	}

	/**
	 * @description Reads the user's time zone, then previews the next run again in that zone.
	 *
	 * @return {Promise<void>} Resolves once the zone has been read and the preview refreshed.
	 */
	async loadUserTimezone()
	{
		await super.loadUserTimezone();

		// The time zone and the record arrive independently, so a preview taken before the zone was known
		// was computed in UTC. Ask for it again now that the zone is here.
		await this.refreshNextRunPreview();
	}

	@wire(getRecord, {recordId: '$recordId', fields: FIELDS}) wiredRecord({data, error})
	{
		if(data)
		{
			this.applyRecord(data);
			this.executionMode = getFieldValue(data, EXECUTION_MODE_FIELD) || EXECUTION_MODE_OWN_VALUE;
			this.runPriority = getFieldValue(data, RUN_PRIORITY_FIELD) ?? '';
			this.overlapPolicy = getFieldValue(data, OVERLAP_POLICY_FIELD) || OVERLAP_POLICY_SKIP_VALUE;
			this.refreshNextRunPreview();
		}

		if(error)
		{
			this.showErrorToast(reduceErrors(error) || LOAD_RECORD_FAILED);
		}
	}

	/**
	 * @description Keeps the cron expression and refreshes the next-run line it changes.
	 *
	 * @param {CustomEvent} event The cron editor's cronchange event.
	 */
	handleCronChange(event)
	{
		super.handleCronChange(event);
		this.refreshNextRunPreview();
	}

	/**
	 * @description Keeps the chosen place for the job to run, and refreshes the next-run line, which only a
	 *              job on the runner has.
	 *
	 * @param {CustomEvent} event The radio's change event.
	 */
	handleExecutionModeChange(event)
	{
		this.executionMode = event.detail.value;
		this.refreshNextRunPreview();
	}

	/**
	 * @description Keeps the run priority as typed.
	 *
	 * @param {CustomEvent} event The input's change event.
	 */
	handleRunPriorityChange(event)
	{
		this.runPriority = event.detail.value;
	}

	/**
	 * @description Keeps the chosen answer to an overlapping run.
	 *
	 * @param {CustomEvent} event The radio's change event.
	 */
	handleOverlapPolicyChange(event)
	{
		this.overlapPolicy = event.detail.value;
	}

	/**
	 * @description Adds the job runner fields to the shared save request. A blank priority is sent as null.
	 *
	 * @return {Object} The save request.
	 */
	buildSaveRequest()
	{
		return {
			...super.buildSaveRequest(),
			executionMode: this.executionMode,
			runPriority: this.runPriority === '' ? null : Number(this.runPriority),
			overlapPolicy: this.overlapPolicy
		};
	}

	/**
	 * @description Refreshes the record in the client cache, says the record was created or saved, and opens it.
	 *
	 * @param {string} savedRecordId The id of the record that was saved.
	 *
	 * @return {Promise<void>} Resolves once the redirect has been requested.
	 */
	async completeSave(savedRecordId)
	{
		await notifyRecordUpdateAvailable([{recordId: savedRecordId}]);
		this.showSuccessToast(this.isCreateMode ? CREATED : SAVED);
		this.redirectToRecordPage(savedRecordId);
	}

	/**
	 * @description Shows a failed save as an error toast.
	 *
	 * @param {string} message What went wrong.
	 */
	reportSaveFailure(message)
	{
		this.showErrorToast(message);
	}

	handleCancel()
	{
		window.history.back();
	}
}
