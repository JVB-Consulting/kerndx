// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Detail panel for a single async chain execution. Displays chain metadata,
 * step timeline, timing, context data, and error details.
 *
 * @author Jason van Beukering
 *
 * @date April 2026, June 2026
 */
import {api} from 'lwc';
import {ComponentBuilder} from 'c/componentBuilder';
import {copyToClipBoard} from 'c/utilitySystem';
import getChainDetail from '@salesforce/apex/CTRL_ChainMonitor.getChainDetail';
import viewLogsAction from '@salesforce/label/c.ChainMonitor_ViewLogsAction';

const STATUS_ICONS = {
	Running: 'standard:activations',
	Completed: 'standard:task2',
	Failed: 'standard:incident',
	Aborted: 'standard:record_delete',
	Stalled: 'standard:problem',
	Delayed: 'standard:shift_scheduling_operation'
};

export default class ChainMonitorDetail extends ComponentBuilder('controller', 'notification', 'navigation')
{
	detail = null;
	currentExecutionId = null;

	label = {
		viewLogs: viewLogsAction
	};

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

	get hasCorrelationId()
	{
		return !!this.detail?.correlationId;
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

	/**
	 * @description Cross-links to the Log Console, deep-linking the correlated forensic
	 * log entries for this chain execution. The template gates the action behind
	 * `hasCorrelationId`, so `this.detail.correlationId` is always present when invoked.
	 * The state param is `c__`-prefixed as the platform requires for custom URL state.
	 */
	handleViewLogs()
	{
		this.navigate({
			type: 'standard__navItemPage', attributes: {apiName: 'LogConsole'}, state: {c__correlationId: this.detail.correlationId}
		});
	}

	@api async refresh()
	{
		if(this.currentExecutionId)
		{
			await this.loadDetail();
		}
	}
}