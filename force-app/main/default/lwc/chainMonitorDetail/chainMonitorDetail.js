// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Detail panel for a single async chain execution. Displays chain metadata,
 * step timeline, timing, context data, and error details.
 *
 * @author Jason van Beukering
 *
 * @date April 2026, July 2026
 */
import {api} from 'lwc';
import {ComponentBuilder} from 'c/componentBuilder';
import {copyToClipBoard} from 'c/utilitySystem';
import {formatTemplateString} from 'c/utilityString';
import getChainDetail from '@salesforce/apex/CTRL_ChainMonitor.getChainDetail';
import viewLogsAction from '@salesforce/label/c.ChainMonitor_ViewLogsAction';
import copyFailed from '@salesforce/label/c.ChainMonitor_CopyFailed';
import progressStepsTemplate from '@salesforce/label/c.ChainMonitor_ProgressSteps';
import correlationCopied from '@salesforce/label/c.ChainMonitor_CorrelationCopied';
import stepsSection from '@salesforce/label/c.ChainMonitor_StepsSection';
import timingSection from '@salesforce/label/c.ChainMonitor_TimingSection';
import startedLabel from '@salesforce/label/c.ChainMonitor_Started';
import completedLabel from '@salesforce/label/c.ChainMonitor_CompletedLabel';
import durationLabel from '@salesforce/label/c.ChainMonitor_Duration';
import correlationIdLabel from '@salesforce/label/c.ChainMonitor_CorrelationIdLabel';
import errorSection from '@salesforce/label/c.ChainMonitor_ErrorSection';
import emptyStateHeading from '@salesforce/label/c.ChainMonitor_EmptyStateHeading';
import emptyStateBody from '@salesforce/label/c.ChainMonitor_EmptyStateBody';

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
		viewLogs: viewLogsAction,
		copyFailed,
		stepsSection,
		timingSection,
		started: startedLabel,
		completed: completedLabel,
		duration: durationLabel,
		correlationId: correlationIdLabel,
		errorSection,
		emptyStateHeading,
		emptyStateBody
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
		return formatTemplateString(progressStepsTemplate, [
			this.detail.completedSteps,
			this.detail.totalSteps
		]);
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

	/**
	 * @description Copies the chain's correlation ID to the clipboard, confirming with a success
	 * toast only once the copy actually happened. A failed copy (Clipboard API and its
	 * temporary-input fallback both failing) surfaces an error toast instead of rejecting.
	 */
	async handleCopyCorrelation()
	{
		if(this.detail?.correlationId)
		{
			try
			{
				await copyToClipBoard(this.detail.correlationId);
				this.showSuccessToast(correlationCopied);
			}
			catch
			{
				// copyToClipBoard already logged the failure; tell the user the copy did not happen.
				this.showErrorToast(this.label.copyFailed);
			}
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