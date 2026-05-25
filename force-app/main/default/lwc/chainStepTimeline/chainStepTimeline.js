// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Step timeline visualisation for async chain executions. Displays each step
 * with status, duration, and error details in a vertical timeline layout.
 *
 * @author Jason van Beukering
 *
 * @date April 2026, May 2026
 */
import {api} from 'lwc';
import {ComponentBuilder} from 'c/componentBuilder';
import getChainDetail from '@salesforce/apex/CTRL_ChainMonitor.getChainDetail';

const STATUS_MAP = {
	success: {icon: 'utility:check', variant: 'success', label: 'Completed'},
	warning: {icon: 'utility:warning', variant: 'warning', label: 'Continued'},
	failed: {icon: 'utility:close', variant: 'error', label: 'Failed'},
	pending: {icon: 'utility:clock', variant: 'neutral', label: 'Pending'}
};

const STATUS_RUNNING = {icon: 'utility:spinner', variant: 'brand', label: 'Running'};

export default class ChainStepTimeline extends ComponentBuilder('controller', 'notification')
{
	@api recordId;
	@api steps;
	@api chainStatus;

	loadedSteps = [];
	loadedChainStatus = null;

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
				...step,
				key: step.className + '-' + step.name,
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