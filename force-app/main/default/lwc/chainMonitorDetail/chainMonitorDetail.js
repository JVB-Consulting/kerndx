// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Detail panel for a single async chain execution. Displays chain metadata,
 * step timeline, timing, context data, and error details.
 *
 * @author Jason van Beukering
 *
 * @date April 2026, May 2026
 */
import {api} from 'lwc';
import {ComponentBuilder} from 'c/componentBuilder';
import {copyToClipBoard} from 'c/utilitySystem';
import getChainDetail from '@salesforce/apex/CTRL_ChainMonitor.getChainDetail';

const STATUS_ICONS = {
	Running: 'standard:activations',
	Completed: 'standard:task2',
	Failed: 'standard:incident',
	Aborted: 'standard:record_delete',
	Stalled: 'standard:problem',
	Delayed: 'standard:shift_scheduling_operation'
};

export default class ChainMonitorDetail extends ComponentBuilder('controller', 'notification')
{
	detail = null;
	currentExecutionId = null;

	@api get executionId()
	{
		return this.currentExecutionId;
	}

	set executionId(value)
	{
		this.currentExecutionId = value;
		if(value)
		{
			// noinspection JSIgnoredPromiseFromCall
			this.loadDetail();
		}
		else
		{
			this.detail = null;
		}
	}

	get hasDetail()
	{
		return this.detail != null;
	}

	get statusIconName()
	{
		return STATUS_ICONS[this.detail?.status] || 'utility:question';
	}

	/**
	 * @description Renders the "N/M steps" label shown beside the chain status badge.
	 * The template gates this getter behind `hasDetail`, so `this.detail` is always
	 * populated when the renderer reads it. Accessing `detail.completedSteps` and
	 * `detail.totalSteps` directly avoids adding branches for a fallback path that
	 * the template guard makes unreachable.
	 * @returns {string}
	 */
	get progressLabel()
	{
		return `${this.detail.completedSteps}/${this.detail.totalSteps} steps`;
	}

	get progressPercent()
	{
		const total = this.detail?.totalSteps || 0;
		return total > 0 ? Math.round((this.detail.completedSteps / total) * 100) : 0;
	}

	get hasError()
	{
		return !!this.detail?.errorMessage;
	}

	get activeSections()
	{
		const sections = [
			'steps',
			'timing'
		];
		if(this.hasError)
		{
			sections.push('error');
		}
		return sections;
	}

	get hasCompletedAt()
	{
		return !!this.detail?.completedAt;
	}

	async loadDetail()
	{
		this.isLoading = true;
		const data = await this.callControllerMethod(getChainDetail, {executionId: this.currentExecutionId});

		if(data)
		{
			this.detail = data;
		}
		this.isLoading = false;
	}

	async handleCopyCorrelation()
	{
		if(this.detail?.correlationId)
		{
			await copyToClipBoard(this.detail.correlationId);
			this.showSuccessToast('Correlation ID copied');
		}
	}

	@api async refresh()
	{
		if(this.currentExecutionId)
		{
			await this.loadDetail();
		}
	}
}