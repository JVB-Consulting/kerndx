// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Step timeline visualisation for async chain executions. Displays each step
 * with status, duration, and error details in a vertical timeline layout.
 *
 * @author Jason van Beukering
 *
 * @date April 2026, July 2026
 */
import {api} from 'lwc';
import {ComponentBuilder} from 'c/componentBuilder';
import getChainDetail from '@salesforce/apex/CTRL_ChainMonitor.getChainDetail';
import CLASS_LABEL from '@salesforce/label/c.ChainMonitor_ClassLabel';
import CONTINUE_ON_ERROR_LABEL from '@salesforce/label/c.ChainMonitor_ContinueOnErrorLabel';
import DURATION_LABEL from '@salesforce/label/c.ChainMonitor_Duration';
import ERROR_LABEL from '@salesforce/label/c.ChainMonitor_ErrorSection';
import NO_STEPS_RECORDED from '@salesforce/label/c.ChainMonitor_NoStepsRecorded';
import STATUS_HEADING from '@salesforce/label/c.ChainMonitor_Status';
import STATUS_COMPLETED from '@salesforce/label/c.ChainMonitor_StatusCompleted';
import STATUS_CONTINUED from '@salesforce/label/c.ChainMonitor_StatusContinued';
import STATUS_FAILED from '@salesforce/label/c.ChainMonitor_StatusFailed';
import STATUS_PENDING from '@salesforce/label/c.ChainMonitor_StatusPending';
import STATUS_RUNNING_LABEL from '@salesforce/label/c.ChainMonitor_StatusRunning';
import STEP_TIMELINE_TITLE from '@salesforce/label/c.ChainMonitor_StepTimelineTitle';
import YES_LABEL from '@salesforce/label/c.ChainMonitor_Yes';

const STATUS_MAP = {
	success: {icon: 'utility:check', variant: 'success', label: STATUS_COMPLETED},
	warning: {icon: 'utility:warning', variant: 'warning', label: STATUS_CONTINUED},
	failed: {icon: 'utility:close', variant: 'error', label: STATUS_FAILED},
	pending: {icon: 'utility:clock', variant: 'neutral', label: STATUS_PENDING}
};

const STATUS_RUNNING = {icon: 'utility:spinner', variant: 'brand', label: STATUS_RUNNING_LABEL};

export default class ChainStepTimeline extends ComponentBuilder('controller', 'notification')
{
	@api recordId;
	@api steps;
	@api chainStatus;

	loadedSteps = [];
	loadedChainStatus = null;

	/** @description Template-bound Custom Labels for the card title, popover rows, and empty state. */
	labels = {
		classLabel: CLASS_LABEL,
		continueOnError: CONTINUE_ON_ERROR_LABEL,
		duration: DURATION_LABEL,
		error: ERROR_LABEL,
		noStepsRecorded: NO_STEPS_RECORDED,
		status: STATUS_HEADING,
		stepTimelineTitle: STEP_TIMELINE_TITLE,
		yes: YES_LABEL
	};

	get displaySteps()
	{
		const source = this.steps || this.loadedSteps;
		if(!source || source.length === 0)
		{
			return [];
		}

		let foundFirstPending = false;

		const lastIndex = source.length - 1;

		return source.map((step, index) =>
		{
			const isRunningStep = !foundFirstPending && step.stepStatus === 'pending' && this.isChainRunning;
			if(isRunningStep)
			{
				foundFirstPending = true;
			}

			const mapping = isRunningStep ? STATUS_RUNNING : (STATUS_MAP[step.stepStatus] || STATUS_MAP.pending);
			const isLast = index === lastIndex;

			return {
				...step, // The index keeps the key unique when the same step class and name repeat in a chain.
				key: step.className + '-' + step.name + '-' + index,
				iconName: mapping.icon,
				iconVariant: mapping.variant,
				iconClass: isRunningStep ? 'icon-spinning' : '',
				statusLabel: mapping.label,
				hasError: !!step.errorMessage,
				hasDuration: !!step.durationLabel,
				itemClass: 'slds-timeline__item_expandable' + (isLast ? ' slds-timeline__item_last' : '')
			};
		});
	}

	get isChainRunning()
	{
		const status = this.chainStatus || this.loadedChainStatus;
		return status === 'Running';
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
			this.loadedChainStatus = data.status;
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