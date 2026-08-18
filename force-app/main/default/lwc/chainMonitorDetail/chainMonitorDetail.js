// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Detail panel for a single async chain execution. Displays chain metadata,
 * step timeline, timing, context data, and error details.
 *
 * @author Jason van Beukering
 *
 * @date April 2026, August 2026
 */
import {api} from 'lwc';
import {ComponentBuilder} from 'c/componentBuilder';
import {copyToClipBoard} from 'c/utilitySystem';
import {formatTemplateString} from 'c/utilityString';
import ChainAbortModal from 'c/chainAbortModal';
import ChainActionConfirmModal from 'c/chainActionConfirmModal';
import getChainDetail from '@salesforce/apex/CTRL_ChainMonitor.getChainDetail';
import abortChain from '@salesforce/apex/CTRL_ChainMonitor.abortChain';
import retryChainFromFailedStep from '@salesforce/apex/CTRL_ChainMonitor.retryChainFromFailedStep';
import restartChainFromStart from '@salesforce/apex/CTRL_ChainMonitor.restartChainFromStart';
import viewLogsAction from '@salesforce/label/c.ChainMonitor_ViewLogsAction';
import actionsGroupLabel from '@salesforce/label/c.ChainMonitor_ActionsGroup';
import copyLabel from '@salesforce/label/c.ChainMonitor_Copy';
import copyFailed from '@salesforce/label/c.ChainMonitor_CopyFailed';
import progressStepsTemplate from '@salesforce/label/c.ChainMonitor_ProgressSteps';
import progressStepsStoppedTemplate from '@salesforce/label/c.ChainMonitor_ProgressStepsStopped';
import correlationCopied from '@salesforce/label/c.ChainMonitor_CorrelationCopied';
import stepsSection from '@salesforce/label/c.ChainMonitor_StepsSection';
import timingSection from '@salesforce/label/c.ChainMonitor_TimingSection';
import startedLabel from '@salesforce/label/c.ChainMonitor_Started';
import completedLabel from '@salesforce/label/c.ChainMonitor_CompletedLabel';
import durationLabel from '@salesforce/label/c.ChainMonitor_Duration';
import activeDuration from '@salesforce/label/c.ChainMonitor_ActiveDuration';
import correlationIdLabel from '@salesforce/label/c.ChainMonitor_CorrelationIdLabel';
import errorSection from '@salesforce/label/c.ChainMonitor_ErrorSection';
import emptyStateHeading from '@salesforce/label/c.ChainMonitor_EmptyStateHeading';
import emptyStateBody from '@salesforce/label/c.ChainMonitor_EmptyStateBody';
import abortAction from '@salesforce/label/c.ChainMonitor_AbortAction';
import abortModalTitle from '@salesforce/label/c.ChainMonitor_AbortModalTitle';
import abortModalBody from '@salesforce/label/c.ChainMonitor_AbortModalBody';
import abortModalProgress from '@salesforce/label/c.ChainMonitor_AbortModalProgress';
import abortConfirmButton from '@salesforce/label/c.ChainMonitor_AbortConfirmButton';
import abortCancelButton from '@salesforce/label/c.ChainMonitor_AbortCancelButton';
import abortSuccessToast from '@salesforce/label/c.ChainMonitor_AbortSuccessToast';
import abortUnavailableDisabled from '@salesforce/label/c.ChainMonitor_AbortUnavailableDisabled';
import abortUnavailableMissingPermission from '@salesforce/label/c.ChainMonitor_AbortUnavailableMissingPermission';
import retryAction from '@salesforce/label/c.ChainMonitor_RetryAction';
import retryModalTitle from '@salesforce/label/c.ChainMonitor_RetryModalTitle';
import retryModalBody from '@salesforce/label/c.ChainMonitor_RetryModalBody';
import retryConfirmButton from '@salesforce/label/c.ChainMonitor_RetryConfirmButton';
import retrySuccessToast from '@salesforce/label/c.ChainMonitor_RetrySuccessToast';
import restartAction from '@salesforce/label/c.ChainMonitor_RestartAction';
import restartModalTitle from '@salesforce/label/c.ChainMonitor_RestartModalTitle';
import restartModalBody from '@salesforce/label/c.ChainMonitor_RestartModalBody';
import restartConfirmButton from '@salesforce/label/c.ChainMonitor_RestartConfirmButton';
import restartSuccessToast from '@salesforce/label/c.ChainMonitor_RestartSuccessToast';
import restartedFromLabel from '@salesforce/label/c.ChainMonitor_RestartedFrom';
import actionCancelButton from '@salesforce/label/c.ChainMonitor_ActionCancelButton';
import retryUnavailableStepNotIdempotent from '@salesforce/label/c.ChainMonitor_RetryUnavailableStepNotIdempotent';
import retryUnavailablePermanent from '@salesforce/label/c.ChainMonitor_RetryUnavailablePermanent';
import retryUnavailableContext from '@salesforce/label/c.ChainMonitor_RetryUnavailableContext';
import restartUnavailableNotDeclared from '@salesforce/label/c.ChainMonitor_RestartUnavailableNotDeclared';
import redriveUnavailableDisabled from '@salesforce/label/c.ChainMonitor_RedriveUnavailableDisabled';
import redriveUnavailableMissingPermission from '@salesforce/label/c.ChainMonitor_RedriveUnavailableMissingPermission';
import redriveUnavailableSuspended from '@salesforce/label/c.ChainMonitor_RedriveUnavailableSuspended';
import statusRunning from '@salesforce/label/c.ChainMonitor_StatusRunning';
import statusCompleted from '@salesforce/label/c.ChainMonitor_StatusCompleted';
import statusFailed from '@salesforce/label/c.ChainMonitor_StatusFailed';
import statusAborted from '@salesforce/label/c.ChainMonitor_StatusAborted';
import statusStalled from '@salesforce/label/c.ChainMonitor_StatusStalled';
import endedLabel from '@salesforce/label/c.ChainMonitor_EndedLabel';
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

const STATUS_PILL_CLASSES = {
	Running: 'status-pill slds-badge_inverse',
	Completed: 'status-pill slds-theme_success',
	Failed: 'status-pill slds-theme_error',
	Aborted: 'status-pill',
	Stalled: 'status-pill slds-theme_warning'
};

// The headline renders one dot per step only while the count keeps them readable (M0 P28);
// beyond it the progress phrase and the bar carry the signal alone.
const STEP_DOT_MAXIMUM_STEPS = 10;
const STEP_DOT_CLASSES = {
	success: 'step-dot step-dot_done', failed: 'step-dot step-dot_failed', running: 'step-dot step-dot_running'
};
const STEP_DOT_DEFAULT_CLASS = 'step-dot step-dot_pending';

// The completion timestamp is stamped whatever ended the run, so the Timing card names the ending
// rather than claiming every terminal chain "Completed" (U39). `Stalled` is deliberately absent:
// a stalled row only carries a completion instant in the contradictory case, which the neutral
// conflict wording below owns.
const COMPLETION_LABELS = {Aborted: statusAborted, Failed: statusFailed};
const STATUS_COMPLETED = 'Completed';

// The bar's fill follows the run's outcome, so a part-way bar on a run that stopped reads
// differently from one still working through its steps. Colour alone carries nothing new: the
// status pill beside it already says the word, and the hue only keeps the bar from contradicting it.
const PROGRESS_BAR_BASE_CLASS = 'progress-bar';
const PROGRESS_BAR_CLASSES = {
	Completed: `${PROGRESS_BAR_BASE_CLASS} progress-bar_success`,
	Failed: `${PROGRESS_BAR_BASE_CLASS} progress-bar_error`,
	Aborted: `${PROGRESS_BAR_BASE_CLASS} progress-bar_error`,
	Stalled: `${PROGRESS_BAR_BASE_CLASS} progress-bar_warning`
};

// Each match is a run of characters ending at the first separator, or the trailing run that has
// none — so a name breaks after `_ . - :` before overflow-wrap has to break it mid-token.
const CHAIN_NAME_SEGMENT_PATTERN = /[^_.:-]*[_.:-]|[^_.:-]+/g;
// Widens each end of the run's own bounds when deep-linking the Log Console, so a log written a
// moment either side of the recorded start/finish is still inside the window the console opens on.
const LOG_WINDOW_MARGIN_MILLISECONDS = 60000;

const OPERATOR_AVAILABLE = 'Available';
const ABORT_CHAIN_NOT_ABORTABLE = 'ChainNotAbortable';
const RETRY_CHAIN_NOT_RETRYABLE = 'ChainNotRetryable';
const RESTART_CHAIN_NOT_RESTARTABLE = 'ChainNotRestartable';
const ABORT_UNAVAILABLE_MESSAGES = {
	CapabilityDisabled: abortUnavailableDisabled, PermissionMissing: abortUnavailableMissingPermission
};
const RETRY_UNAVAILABLE_MESSAGES = {
	StepNotIdempotent: retryUnavailableStepNotIdempotent,
	FailurePermanent: retryUnavailablePermanent,
	ContextUnavailable: retryUnavailableContext,
	ChainProcessingSuspended: redriveUnavailableSuspended,
	CapabilityDisabled: redriveUnavailableDisabled,
	PermissionMissing: redriveUnavailableMissingPermission
};
const RESTART_UNAVAILABLE_MESSAGES = {
	RestartNotDeclared: restartUnavailableNotDeclared,
	ChainProcessingSuspended: redriveUnavailableSuspended,
	CapabilityDisabled: redriveUnavailableDisabled,
	PermissionMissing: redriveUnavailableMissingPermission
};

export default class ChainMonitorDetail extends ComponentBuilder('controller', 'notification', 'navigation')
{
	detail = null;
	currentExecutionId = null;
	isProcessing = false;

	label = {
		viewLogs: viewLogsAction,
		actionsGroup: actionsGroupLabel,
		copy: copyLabel,
		abortAction,
		retryAction,
		restartAction,
		restartedFrom: restartedFromLabel,
		copyFailed,
		stepsSection,
		timingSection,
		started: startedLabel,
		duration: durationLabel,
		activeDuration,
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
		if(value === this.currentExecutionId)
		{
			return;
		}
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

	get statusPillClass()
	{
		return STATUS_PILL_CLASSES[this.detail?.status] ?? 'status-pill';
	}

	get showStepDots()
	{
		return this.detail?.totalSteps > 0 && this.detail.totalSteps <= STEP_DOT_MAXIMUM_STEPS;
	}

	/**
	 * @description One dot per step for the headline. The template gates this getter behind
	 * `showStepDots`, so `this.detail.steps` is always populated when the renderer reads it —
	 * the same unreachable-fallback reasoning `progressLabel` documents.
	 * @returns {Array<{key: string, dotClass: string}>}
	 */
	get stepDots()
	{
		return this.detail.steps.map((step, index) => ({
			key: `dot-${index}`, dotClass: STEP_DOT_CLASSES[step.stepStatus] ?? STEP_DOT_DEFAULT_CLASS
		}));
	}

	/**
	 * @description The chain name split at its separators, one segment per `_ . - :` run, so the
	 * heading can offer a break opportunity after each one and wrap at a readable boundary instead
	 * of truncating behind a hover-only tooltip. The template gates this getter behind `hasDetail`.
	 * @returns {Array<{key: string, text: string}>}
	 */
	get chainNameSegments()
	{
		return [...String(this.detail.chainName ?? '').matchAll(CHAIN_NAME_SEGMENT_PATTERN)]
		.map((match, index) => ({key: `segment-${index}`, text: match[0]}));
	}

	/**
	 * @description Renders the "N/M steps" label shown beside the chain status badge — the
	 * running phrase while the run is live or ran everything, and the stopped-short phrase once it
	 * has ended with steps left unrun, so an aborted chain no longer reads exactly as it did while
	 * it was running. The template gates this getter behind `hasDetail`, so `this.detail` is always
	 * populated when the renderer reads it. Accessing `detail.completedSteps` and
	 * `detail.totalSteps` directly avoids adding branches for a fallback path that
	 * the template guard makes unreachable.
	 * @returns {string}
	 */
	get progressLabel()
	{
		return formatTemplateString(this.hasStoppedShortOfCompletion ? progressStepsStoppedTemplate : progressStepsTemplate, [
			this.detail.completedSteps,
			this.detail.totalSteps
		]);
	}

	/**
	 * @description True when the run has ended, did not complete, and left steps unrun — the state
	 * whose frozen "Step 3 of 4" phrase, filled dots and part-way bar used to look identical to a
	 * chain still working through step 4.
	 * @returns {boolean}
	 */
	get hasStoppedShortOfCompletion()
	{
		return this.hasCompletedAt && this.detail.status !== STATUS_COMPLETED && this.detail.completedSteps < this.detail.totalSteps;
	}

	/**
	 * @description What the completion timestamp records: an abort, a failure, or a genuine
	 * completion. Every ending stamps the same field, so the Timing card names the ending rather
	 * than announcing "Completed" over an abort instant. The contradictory row gets the neutral
	 * word: recovery overwrote the status that actually ended the run, so the instant belongs to a
	 * predecessor nothing can now name — the badge says as much, and this term must not claim the
	 * run stalled at that moment.
	 * @returns {string}
	 */
	get completionLabel()
	{
		return this.hasStatusConflict ? endedLabel : (COMPLETION_LABELS[this.detail?.status] ?? completedLabel);
	}

	get progressPercent()
	{
		const total = this.detail?.totalSteps || 0;
		return total > 0 ? Math.round((this.detail.completedSteps / total) * 100) : 0;
	}

	/**
	 * @description The progress bar's fill class, chosen by how the run ended. A run still working
	 * keeps the default fill.
	 *
	 * @returns {string}
	 */
	get progressBarClass()
	{
		return PROGRESS_BAR_CLASSES[this.detail?.status] ?? PROGRESS_BAR_BASE_CLASS;
	}

	get hasError()
	{
		return !!this.detail?.errorMessage;
	}

	get hasCorrelationId()
	{
		return !!this.detail?.correlationId;
	}

	get structuralSections()
	{
		return [
			'steps',
			'timing'
		];
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
		return this.isProcessing || this.detail?.abortAvailability !== OPERATOR_AVAILABLE;
	}

	get abortUnavailableMessage()
	{
		return ABORT_UNAVAILABLE_MESSAGES[this.detail?.abortAvailability] ?? '';
	}

	get showRetryButton()
	{
		return this.detail?.retryAvailability != null && this.detail.retryAvailability !== RETRY_CHAIN_NOT_RETRYABLE;
	}

	get isRetryDisabled()
	{
		return this.isProcessing || this.detail?.retryAvailability !== OPERATOR_AVAILABLE;
	}

	get retryUnavailableMessage()
	{
		return RETRY_UNAVAILABLE_MESSAGES[this.detail?.retryAvailability] ?? '';
	}

	get showRestartButton()
	{
		return this.detail?.restartAvailability != null && this.detail.restartAvailability !== RESTART_CHAIN_NOT_RESTARTABLE;
	}

	get isRestartDisabled()
	{
		return this.isProcessing || this.detail?.restartAvailability !== OPERATOR_AVAILABLE;
	}

	get restartUnavailableMessage()
	{
		return RESTART_UNAVAILABLE_MESSAGES[this.detail?.restartAvailability] ?? '';
	}

	get hasActionGroup()
	{
		return this.showRetryButton || this.showRestartButton || this.showAbortButton;
	}

	/**
	 * @description Whether the toolbar row has anything to hold: the operator actions, the View
	 * logs hand-off, or both. A chain with neither renders no row and costs no header height.
	 * @returns {boolean}
	 */
	get hasHeaderActions()
	{
		return this.hasActionGroup || this.hasCorrelationId;
	}

	/**
	 * @description The rule between the operator actions and the navigation action, drawn only
	 * when there is something on each side of it.
	 * @returns {boolean}
	 */
	get showActionDivider()
	{
		return this.hasActionGroup && this.hasCorrelationId;
	}

	/**
	 * @description The refusal sentences to show on screen, one per distinct reason. A disabled
	 * button is not focusable, so a sighted keyboard-only reader can never reach the tooltip or
	 * the assistive description — the reasons have to be readable without pointing at anything.
	 * Reading the three messages is enough on its own: each is non-empty only for an availability
	 * code that both renders its button and disables it, so a message present here always belongs
	 * to a rendered, disabled action.
	 * @returns {Array<{key: string, text: string}>}
	 */
	get unavailableReasons()
	{
		return [
			...new Set([
				this.retryUnavailableMessage,
				this.restartUnavailableMessage,
				this.abortUnavailableMessage
			])
		].filter(Boolean).map((text, index) => ({key: `reason-${index}`, text}));
	}

	get hasUnavailableReasons()
	{
		return this.unavailableReasons.length > 0;
	}

	get hasActiveDuration()
	{
		return !!this.detail?.activeDurationLabel;
	}

	get showLineageLink()
	{
		return this.detail?.sourceExecutionId != null;
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
	 * log entries for this chain execution together with the window this run occupied. The
	 * template gates the action behind `hasCorrelationId`, so `this.detail.correlationId` is
	 * always present when invoked. Every state param is `c__`-prefixed as the platform requires
	 * for custom URL state. `c__viewLogsAt` stamps the click: the console applies each hand-off
	 * once and ignores the platform re-delivering the same page reference on every return to
	 * the tab it opened, so a second click for the same finished chain must read as a new
	 * hand-off, and only the stamp tells the two apart.
	 */
	handleViewLogs()
	{
		this.navigate({
			type: 'standard__navItemPage',
			attributes: {apiName: 'LogConsole'},
			state: {c__correlationId: this.detail.correlationId, c__viewLogsAt: String(Date.now()), ...this.logWindowState()}
		});
	}

	/**
	 * @description This run's bounds as URL state, each end widened by the margin. A chain that has
	 * not finished sends no upper bound, which the console reads as "up to now"; a run with no
	 * recorded start sends neither bound and leaves the console on its own fallback window.
	 * @returns {{c__windowStart?: string, c__windowEnd?: string}}
	 */
	logWindowState()
	{
		if(!this.detail.startedAt)
		{
			return {};
		}
		const windowState = {c__windowStart: this.shiftInstant(this.detail.startedAt, -LOG_WINDOW_MARGIN_MILLISECONDS)};
		if(this.detail.completedAt)
		{
			windowState.c__windowEnd = this.shiftInstant(this.detail.completedAt, LOG_WINDOW_MARGIN_MILLISECONDS);
		}
		return windowState;
	}

	// Moves an ISO-8601 instant by a signed millisecond offset, answering an ISO-8601 instant.
	shiftInstant(instant, offsetMilliseconds)
	{
		return new Date(new Date(instant).getTime() + offsetMilliseconds).toISOString();
	}

	/**
	 * @description Confirms the destructive abort through the modal, records it via the controller,
	 * and on success replaces the detail with the fresh state, toasts, and notifies the parent so
	 * the list refreshes. A refused abort resolves undefined (callControllerMethod has already
	 * toasted the labelled refusal), so the detail stays untouched and no event fires.
	 */
	async handleAbort()
	{
		// The abort body composes its own progress fragment ('2/5 steps') — the mockup deliberately
		// keeps it distinct from the headline's 'Step N of M' phrase, and the sentence is released
		// subscriber copy that must not drift with the headline.
		const result = await ChainAbortModal.open({
			size: 'small', label: abortModalTitle, title: abortModalTitle, body: formatTemplateString(abortModalBody, [
				this.detail.chainName,
				formatTemplateString(abortModalProgress, [
					this.detail.completedSteps,
					this.detail.totalSteps
				])
			]), confirmLabel: abortConfirmButton, cancelLabel: abortCancelButton
		});

		if(result?.action !== 'confirm')
		{
			return;
		}

		this.isProcessing = true;
		try
		{
			const data = await this.callControllerMethod(abortChain, {executionId: this.currentExecutionId});

			if(data)
			{
				this.detail = data;
				this.showSuccessToast(abortSuccessToast);
				this.dispatchEvent(new CustomEvent('chainabort', {detail: {executionId: this.currentExecutionId}}));
			}
		}
		finally
		{
			this.isProcessing = false;
		}
	}

	/**
	 * @description Confirms an operator action through the shared modal, then runs it with every
	 * action button held disabled until the controller promise settles — a rapid second click
	 * during server transit is impossible client-side, while the server's fresh re-read remains
	 * the enforcement point. A refused action resolves undefined (callControllerMethod has
	 * already toasted the labelled refusal), so onSuccess never runs.
	 */
	async runConfirmedOperatorAction(modalConfiguration, controllerMethod, onSuccess)
	{
		const result = await ChainActionConfirmModal.open(modalConfiguration);

		if(result?.action !== 'confirm')
		{
			return;
		}

		this.isProcessing = true;
		try
		{
			const data = await this.callControllerMethod(controllerMethod, {executionId: this.currentExecutionId});

			if(data)
			{
				onSuccess(data);
			}
		}
		finally
		{
			this.isProcessing = false;
		}
	}

	/**
	 * @description Confirms and runs the retry-from-failed-step action: on success the fresh
	 * detail (now Running) replaces the view, and the parent is told so the list row updates.
	 */
	async handleRetry()
	{
		await this.runConfirmedOperatorAction({
			size: 'small',
			label: retryModalTitle,
			title: retryModalTitle,
			body: formatTemplateString(retryModalBody, [this.detail.chainName]),
			confirmLabel: retryConfirmButton,
			cancelLabel: actionCancelButton,
			confirmVariant: 'brand'
		}, retryChainFromFailedStep, (data) =>
		{
			this.detail = data;
			// The toast names the chain: several rows can share a truncated name in the list, so an
			// unnamed "Retry started" leaves the operator unable to tell which record moved.
			this.showSuccessToast(formatTemplateString(retrySuccessToast, [data.chainName]));
			this.dispatchEvent(new CustomEvent('chainretry', {detail: {executionId: this.currentExecutionId}}));
		});
	}

	/**
	 * @description Confirms and runs the restart-from-start action. The controller answers with
	 * the CLONE's detail: the view re-points at the new run and the parent event carries the
	 * clone id so the container list refreshes and selects it.
	 */
	async handleRestart()
	{
		await this.runConfirmedOperatorAction({
			size: 'small',
			label: restartModalTitle,
			title: restartModalTitle,
			body: formatTemplateString(restartModalBody, [this.detail.chainName]),
			confirmLabel: restartConfirmButton,
			cancelLabel: actionCancelButton,
			confirmVariant: 'brand'
		}, restartChainFromStart, (data) =>
		{
			this.detail = data;
			this.currentExecutionId = data.executionId;
			this.showSuccessToast(formatTemplateString(restartSuccessToast, [data.chainName]));
			this.dispatchEvent(new CustomEvent('chainrestart', {detail: {executionId: data.executionId}}));
		});
	}

	/**
	 * @description The restart lineage link: asks the container to select the source run this
	 * clone was restarted from. The template gates the link behind `showLineageLink`, so the
	 * source id is always present when invoked.
	 */
	handleLineageNavigate()
	{
		this.dispatchEvent(new CustomEvent('chainlineagenavigate', {detail: {executionId: this.detail.sourceExecutionId}}));
	}

	@api async refresh()
	{
		if(this.currentExecutionId)
		{
			await this.loadDetail();
		}
	}
}