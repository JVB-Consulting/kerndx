// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Step timeline visualisation for async chain executions. Displays each step
 * with status, duration, and error details in a vertical timeline layout.
 *
 * @author Jason van Beukering
 *
 * @date April 2026, October 2026
 */
import {api} from 'lwc';
import {ComponentBuilder} from 'c/componentBuilder';
import {formatTemplateString} from 'c/utilityString';
import getChainDetail from '@salesforce/apex/CTRL_ChainMonitor.getChainDetail';
import CLASS_LABEL from '@salesforce/label/c.ChainMonitor_ClassLabel';
import CONTINUE_ON_ERROR_LABEL from '@salesforce/label/c.ChainMonitor_ContinueOnErrorLabel';
import DURATION_LABEL from '@salesforce/label/c.ChainMonitor_Duration';
import ERROR_LABEL from '@salesforce/label/c.ChainMonitor_ErrorSection';
import LOADING_STEPS from '@salesforce/label/c.ChainMonitor_LoadingSteps';
import MANUAL_RETRY_MARKER from '@salesforce/label/c.ChainMonitor_ManualRetryMarker';
import MANUAL_RETRY_MARKER_AFTER from '@salesforce/label/c.ChainMonitor_ManualRetryMarkerAfter';
import NO_STEPS_RECORDED from '@salesforce/label/c.ChainMonitor_NoStepsRecorded';
import STATUS_HEADING from '@salesforce/label/c.ChainMonitor_Status';
import STATUS_COMPLETED from '@salesforce/label/c.ChainMonitor_StatusCompleted';
import STATUS_CONTINUED from '@salesforce/label/c.ChainMonitor_StatusContinued';
import STATUS_DID_NOT_RUN_LABEL from '@salesforce/label/c.ChainMonitor_StatusDidNotRun';
import STATUS_FAILED from '@salesforce/label/c.ChainMonitor_StatusFailed';
import STATUS_NO_RESULT_RECORDED_LABEL from '@salesforce/label/c.ChainMonitor_StatusNoResultRecorded';
import STATUS_PENDING from '@salesforce/label/c.ChainMonitor_StatusPending';
import STATUS_RUNNING_LABEL from '@salesforce/label/c.ChainMonitor_StatusRunning';
import STEP_TIMELINE_TITLE from '@salesforce/label/c.ChainMonitor_StepTimelineTitle';
import YES_LABEL from '@salesforce/label/c.ChainMonitor_Yes';

/**
 * @description What each step status word looks like on the timeline: an icon, an icon colour and a label. The
 * controller sends one of these seven words for every step, so the timeline only looks the word up here. A word that
 * is not in this list shows as pending.
 */
const STATUS_MAP = {
	success: {icon: 'utility:check', variant: 'success', label: STATUS_COMPLETED},
	warning: {icon: 'utility:warning', variant: 'warning', label: STATUS_CONTINUED},
	failed: {icon: 'utility:close', variant: 'error', label: STATUS_FAILED},
	pending: {icon: 'utility:clock', variant: 'neutral', label: STATUS_PENDING},
	running: {icon: 'utility:spinner', variant: 'brand', label: STATUS_RUNNING_LABEL},
	noResultRecorded: {icon: 'utility:question', variant: 'neutral', label: STATUS_NO_RESULT_RECORDED_LABEL},
	didNotRun: {icon: 'utility:dash', variant: 'neutral', label: STATUS_DID_NOT_RUN_LABEL}
};

export default class ChainStepTimeline extends ComponentBuilder('controller', 'notification')
{
	@api recordId;
	@api steps;
	/**
	 * @description The status of the chain run. Not read since 1.8: each step carries its own status.
	 *
	 * @deprecated since 1.8. Released in 1.7, and a managed package cannot remove a public property it released.
	 * @type {string}
	 */
	@api chainStatus;

	loadedSteps = [];

	/** @description Template-bound Custom Labels for the card title, popover rows, empty state and loading spinner. */
	labels = {
		classLabel: CLASS_LABEL,
		continueOnError: CONTINUE_ON_ERROR_LABEL,
		duration: DURATION_LABEL,
		error: ERROR_LABEL,
		loadingSteps: LOADING_STEPS,
		noStepsRecorded: NO_STEPS_RECORDED,
		status: STATUS_HEADING,
		stepTimelineTitle: STEP_TIMELINE_TITLE,
		yes: YES_LABEL
	};

	/**
	 * @description The steps as the timeline shows them. Each step gets the icon, colour and label of its status word,
	 * and the icon of a running step spins.
	 *
	 * @returns one display row per step, in the order the chain runs them
	 */
	get displaySteps()
	{
		const source = this.steps || this.loadedSteps || [];
		const lastIndex = source.length - 1;

		return source.map((step, index) =>
		{
			const mapping = STATUS_MAP[step.stepStatus] || STATUS_MAP.pending;

			return {
				...step, // The index keeps the key unique when the same step class and name repeat in a chain.
				key: step.className + '-' + step.name + '-' + index,
				iconName: mapping.icon,
				iconVariant: mapping.variant,
				iconClass: mapping === STATUS_MAP.running ? 'icon-spinning' : '',
				statusLabel: mapping.label,
				hasError: Boolean(step.errorMessage),
				hasDuration: Boolean(step.durationLabel),
				itemClass: 'slds-timeline__item_expandable' + (index === lastIndex ? ' slds-timeline__item_last' : ''),
				hasManualRetryMarker: step.manuallyRetried === true,
				manualRetryMarkerText: step.manualRetryAfterLabel ? formatTemplateString(MANUAL_RETRY_MARKER_AFTER, [step.manualRetryAfterLabel]) : MANUAL_RETRY_MARKER
			};
		});
	}

	get hasSteps()
	{
		return this.displaySteps.length > 0;
	}

	async connectedCallback()
	{
		if(!this.steps && this.recordId)
		{
			await this.loadSteps();
		}
	}

	async loadSteps()
	{
		this.isLoading = true;
		const data = await this.callControllerMethod(getChainDetail, {executionId: this.recordId});

		if(data)
		{
			this.loadedSteps = data.steps;
		}
		this.isLoading = false;
	}

	@api async refresh()
	{
		if(this.recordId)
		{
			await this.loadSteps();
		}
	}
}