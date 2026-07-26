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
import ChainAbortModal from 'c/chainAbortModal';
import getChainDetail from '@salesforce/apex/CTRL_ChainMonitor.getChainDetail';
import abortChain from '@salesforce/apex/CTRL_ChainMonitor.abortChain';
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
import abortAction from '@salesforce/label/c.ChainMonitor_AbortAction';
import abortModalTitle from '@salesforce/label/c.ChainMonitor_AbortModalTitle';
import abortModalBody from '@salesforce/label/c.ChainMonitor_AbortModalBody';
import abortConfirmButton from '@salesforce/label/c.ChainMonitor_AbortConfirmButton';
import abortCancelButton from '@salesforce/label/c.ChainMonitor_AbortCancelButton';
import abortSuccessToast from '@salesforce/label/c.ChainMonitor_AbortSuccessToast';
import abortUnavailableDisabled from '@salesforce/label/c.ChainMonitor_AbortUnavailableDisabled';
import abortUnavailableMissingPermission from '@salesforce/label/c.ChainMonitor_AbortUnavailableMissingPermission';
import statusRunning from '@salesforce/label/c.ChainMonitor_StatusRunning';
import statusCompleted from '@salesforce/label/c.ChainMonitor_StatusCompleted';
import statusFailed from '@salesforce/label/c.ChainMonitor_StatusFailed';
import statusAborted from '@salesforce/label/c.ChainMonitor_StatusAborted';
import statusStalled from '@salesforce/label/c.ChainMonitor_StatusStalled';
import statusConflict from '@salesforce/label/c.ChainMonitor_StatusConflict';
import statusConflictDetail from '@salesforce/label/c.ChainMonitor_StatusConflictDetail';

const STATUS_ICONS = {
	Running: 'standard:activations',
	Completed: 'standard:task2',
	Failed: 'standard:incident',
	Aborted: 'standard:record_delete',
	Stalled: 'standard:problem',
	Delayed: 'standard:shift_scheduling_operation'
};

const STATUS_LABELS = {
	Running: statusRunning, Completed: statusCompleted, Failed: statusFailed, Aborted: statusAborted, Stalled: statusStalled
};

const ABORT_AVAILABLE = 'Available';
const ABORT_CHAIN_NOT_ABORTABLE = 'ChainNotAbortable';
const ABORT_UNAVAILABLE_MESSAGES = {
	CapabilityDisabled: abortUnavailableDisabled, PermissionMissing: abortUnavailableMissingPermission
};

export default class ChainMonitorDetail extends ComponentBuilder('controller', 'notification', 'navigation')
{
	detail = null;
	currentExecutionId = null;

	label = {
		viewLogs: viewLogsAction,
		abortAction,
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
	 * @description True when the row is a contradictory terminal record: recovery marked it
	 * `Stalled` yet it already carries a completion timestamp, so it has truly ended and the
	 * watchdog will not re-drive it. The predecessor status (`markStalled` overwrites both
	 * `Status__c` and `FailureCategory__c`) is unrecoverable, so the badge stays deliberately
	 * neutral and never names a prior status.
	 * @returns {boolean}
	 */
	get hasStatusConflict()
	{
		return this.detail?.status === 'Stalled' && this.detail?.completedAt != null;
	}

	get statusLabel()
	{
		if(this.hasStatusConflict)
		{
			return statusConflict;
		}
		return STATUS_LABELS[this.detail?.status] ?? this.detail?.status;
	}

	get statusTitle()
	{
		return this.hasStatusConflict ? statusConflictDetail : '';
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

	get showAbortButton()
	{
		return this.detail?.abortAvailability != null && this.detail.abortAvailability !== ABORT_CHAIN_NOT_ABORTABLE;
	}

	get isAbortDisabled()
	{
		return this.detail?.abortAvailability !== ABORT_AVAILABLE;
	}

	get abortUnavailableMessage()
	{
		return ABORT_UNAVAILABLE_MESSAGES[this.detail?.abortAvailability] ?? '';
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

	/**
	 * @description Confirms the destructive abort through the modal, records it via the controller,
	 * and on success replaces the detail with the fresh state, toasts, and notifies the parent so
	 * the list refreshes. A refused abort resolves undefined (callControllerMethod has already
	 * toasted the labelled refusal), so the detail stays untouched and no event fires.
	 */
	async handleAbort()
	{
		const result = await ChainAbortModal.open({
			size: 'small', label: abortModalTitle, title: abortModalTitle, body: formatTemplateString(abortModalBody, [
				this.detail.chainName,
				this.progressLabel
			]), confirmLabel: abortConfirmButton, cancelLabel: abortCancelButton
		});

		if(result?.action !== 'confirm')
		{
			return;
		}

		const data = await this.callControllerMethod(abortChain, {executionId: this.currentExecutionId});

		if(data)
		{
			this.detail = data;
			this.showSuccessToast(abortSuccessToast);
			this.dispatchEvent(new CustomEvent('chainabort', {detail: {executionId: this.currentExecutionId}}));
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