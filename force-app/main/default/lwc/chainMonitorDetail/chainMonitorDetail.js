// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Detail panel for a single async chain execution. Displays chain metadata,
 * step timeline, timing, context data, and error details.
 *
 * @author Jason van Beukering
 *
 * @date April 2026, October 2026
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
import copyActionLabel from '@salesforce/label/c.ChainMonitor_CopyAction';
import copyCorrelationLabel from '@salesforce/label/c.ChainMonitor_CopyCorrelation';
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
import abortSelectionChanged from '@salesforce/label/c.ChainMonitor_AbortSelectionChanged';
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
import launchedUnderLabel from '@salesforce/label/c.ChainMonitor_LaunchedUnder';
import launchedByThisAction from '@salesforce/label/c.ChainMonitor_LaunchedByThisAction';
import startedThisAction from '@salesforce/label/c.ChainMonitor_StartedThisAction';
import restartOfTemplate from '@salesforce/label/c.ChainMonitor_RestartOf';
import launchedByStepNote from '@salesforce/label/c.ChainMonitor_LaunchedByStepNote';
import showActionLogsAction from '@salesforce/label/c.ChainMonitor_ShowActionLogsAction';
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
// A step that failed and let the chain carry on reads "warning", as the step timeline shows it, never pending.
const STEP_DOT_CLASSES = {
	success: 'step-dot step-dot_done', failed: 'step-dot step-dot_failed', running: 'step-dot step-dot_running', warning: 'step-dot step-dot_warning'
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

// How a run entered its action, the controller's vocabulary.
const LAUNCH_KIND_CHAIN = 'CHAIN';
const LAUNCH_KIND_ACTION = 'ACTION';
const LAUNCH_KIND_RESTART = 'RESTART';
const LAUNCH_KIND_ORIGIN = 'ORIGIN';

export default class ChainMonitorDetail extends ComponentBuilder('controller', 'notification', 'navigation')
{
	detail = null;
	currentExecutionId = null;
	isProcessing = false;

	label = {
		viewLogs: viewLogsAction,
		actionsGroup: actionsGroupLabel,
		copyAction: copyActionLabel,
		copyCorrelation: copyCorrelationLabel,
		abortAction,
		retryAction,
		restartAction,
		launchedUnder: launchedUnderLabel,
		showActionLogs: showActionLogsAction,
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

	// Counts the detail requests; an answer is taken only while its request is the newest (see loadDetail).
	loadSequence = 0;

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
		// The previous run's pane leaves with its selection: kept on screen through the round trip, or after a
		// failed load, its enabled actions would act on the run selected now.
		this.detail = null;
		if(value)
		{
			// noinspection JSIgnoredPromiseFromCall
			this.loadDetail();
		}
		else
		{
			// A load still on its way for the cleared run is ignored when it lands (see loadDetail), so the
			// loading state ends here or the pane would stay loading with nothing to show.
			this.loadSequence++;
			this.isLoading = false;
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

	get hasLaunchCorrelationId()
	{
		return !!this.detail?.launchCorrelationId;
	}

	/**
	 * @description How the run entered its action, as the controller classified it; a detail with no
	 * kind reads as the run that started the action.
	 *
	 * @returns {string}
	 */
	get launchedUnderKind()
	{
		return this.detail?.launchKind ?? LAUNCH_KIND_ORIGIN;
	}

	/**
	 * @description Whether the Launched under row names a run the reader can open: the launching
	 * chain, or the run a restart was made from.
	 *
	 * @returns {boolean}
	 */
	get launchedUnderIsLink()
	{
		return (this.launchedUnderKind === LAUNCH_KIND_CHAIN || this.launchedUnderKind === LAUNCH_KIND_RESTART) && !!this.detail?.launchedUnderExecutionId;
	}

	/**
	 * @description The words of the Launched under row by the four cases: the launching run's name
	 * and number, "this action", "restart of {source}", or "started this action".
	 *
	 * @returns {string}
	 */
	get launchedUnderText()
	{
		const kind = this.launchedUnderKind;
		if(kind === LAUNCH_KIND_CHAIN)
		{
			return this.detail.launchedUnderName ?? '';
		}
		if(kind === LAUNCH_KIND_RESTART)
		{
			return formatTemplateString(restartOfTemplate, [this.detail.launchedUnderName ?? '']);
		}
		return kind === LAUNCH_KIND_ORIGIN ? startedThisAction : launchedByThisAction;
	}

	/**
	 * @description The note under a launching chain, saying that one of its steps started this run.
	 * The other three readings need no note.
	 *
	 * @returns {string|null}
	 */
	get launchedUnderNote()
	{
		return this.launchedUnderKind === LAUNCH_KIND_CHAIN ? launchedByStepNote : null;
	}

	/**
	 * @description The raw launch id with copy is shown beside "this action": the action's own id,
	 * the one a reader may want to paste.
	 *
	 * @returns {boolean}
	 */
	get showLaunchIdCopy()
	{
		return this.launchedUnderKind === LAUNCH_KIND_ACTION && this.hasLaunchCorrelationId;
	}

	/**
	 * @description Whether this run belongs to an action whose logs can be opened as a whole.
	 *
	 * @returns {boolean}
	 */
	get hasRootCorrelationId()
	{
		return !!this.detail?.rootCorrelationId;
	}

	/**
	 * @description Whether the toolbar's navigation slot has anything to hold: the per-run logs, the
	 * whole action's logs, or both.
	 *
	 * @returns {boolean}
	 */
	get hasNavigationActions()
	{
		return this.hasCorrelationId || this.hasRootCorrelationId;
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
	 * @description Whether the toolbar row has anything to hold: the operator actions, the log
	 * hand-offs, or both. A chain with neither renders no row and costs no header height.
	 * @returns {boolean}
	 */
	get hasHeaderActions()
	{
		return this.hasActionGroup || this.hasNavigationActions;
	}

	/**
	 * @description The rule between the operator actions and the navigation actions, drawn only
	 * when there is something on each side of it.
	 * @returns {boolean}
	 */
	get showActionDivider()
	{
		return this.hasActionGroup && this.hasNavigationActions;
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

	async loadDetail()
	{
		const requestedExecutionId = this.currentExecutionId;
		this.loadSequence++;
		const requestSequence = this.loadSequence;
		this.isLoading = true;
		const data = await this.callControllerMethod(getChainDetail, {executionId: requestedExecutionId});

		// Whatever is selected NOW wins, and only its newest request. Two loads are in flight when the list
		// auto-selects its first row while a deep link resolves another run, or when two events about the selected
		// run refresh it in a burst, and the earlier request can answer last; written as it lands, it would
		// describe one run while the actions act on the selected one, or an older state of the right run.
		if(requestSequence !== this.loadSequence || requestedExecutionId !== this.currentExecutionId)
		{
			return;
		}
		if(data)
		{
			this.detail = data;
		}
		this.isLoading = false;
	}

	/**
	 * @description Takes an operator action's answer as the pane's detail: the newest word on the run, so a load
	 * still on its way is out of date and dropped when it lands, and any loading it started ends here.
	 * @param {Object} data The detail the action answered with.
	 */
	acceptActionDetail(data)
	{
		this.loadSequence++;
		this.detail = data;
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
	 * @description Copies the id the run was launched under to the clipboard, with the same confirmation and failure
	 * toasts as the correlation id copy.
	 */
	async handleCopyLaunchCorrelation()
	{
		if(this.detail?.launchCorrelationId)
		{
			try
			{
				await copyToClipBoard(this.detail.launchCorrelationId);
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
	 * toasted the labelled refusal), so the detail stays untouched and no event fires. If another
	 * run was selected while the dialog was open, nothing is aborted and a toast says so.
	 */
	async handleAbort()
	{
		// The abort body composes its own progress fragment ('2/5 steps') — the mockup deliberately
		// keeps it distinct from the headline's 'Step N of M' phrase, and the sentence is released
		// subscriber copy that must not drift with the headline.
		// The run is read before the dialog opens, so the dialog and the abort always name the same run.
		const actedExecutionId = this.currentExecutionId;
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

		if(actedExecutionId !== this.currentExecutionId)
		{
			this.showWarningToast(abortSelectionChanged);
			return;
		}

		this.isProcessing = true;
		try
		{
			const data = await this.callControllerMethod(abortChain, {executionId: actedExecutionId});

			if(data)
			{
				// A row clicked while the server was working keeps its own detail on screen; the event still names the run acted on.
				if(actedExecutionId === this.currentExecutionId)
				{
					this.acceptActionDetail(data);
				}
				this.showSuccessToast(abortSuccessToast);
				this.dispatchEvent(new CustomEvent('chainabort', {detail: {executionId: actedExecutionId}}));
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
	 * already toasted the labelled refusal), so onSuccess never runs. onSuccess receives the answer and the
	 * id of the run acted on, since a row clicked during the round trip may have moved the selection.
	 */
	async runConfirmedOperatorAction(modalConfiguration, controllerMethod, onSuccess)
	{
		const result = await ChainActionConfirmModal.open(modalConfiguration);

		if(result?.action !== 'confirm')
		{
			return;
		}

		const actedExecutionId = this.currentExecutionId;
		this.isProcessing = true;
		try
		{
			const data = await this.callControllerMethod(controllerMethod, {executionId: actedExecutionId});

			if(data)
			{
				onSuccess(data, actedExecutionId);
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
		}, retryChainFromFailedStep, (data, actedExecutionId) =>
		{
			if(actedExecutionId === this.currentExecutionId)
			{
				this.acceptActionDetail(data);
			}
			// The toast names the chain: several rows can share a truncated name in the list, so an
			// unnamed "Retry started" leaves the operator unable to tell which record moved.
			this.showSuccessToast(formatTemplateString(retrySuccessToast, [data.chainName]));
			this.dispatchEvent(new CustomEvent('chainretry', {detail: {executionId: actedExecutionId}}));
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
			// The clone is selected whatever was clicked meanwhile: the container follows this event to it.
			this.currentExecutionId = data.executionId;
			this.acceptActionDetail(data);
			this.showSuccessToast(formatTemplateString(restartSuccessToast, [data.chainName]));
			this.dispatchEvent(new CustomEvent('chainrestart', {detail: {executionId: data.executionId}}));
		});
	}

	/**
	 * @description The Launched under row's link: asks the container to select the launching run, or
	 * the restart's source.
	 */
	handleLaunchedUnderNavigate()
	{
		this.dispatchEvent(new CustomEvent('chainlineagenavigate', {detail: {executionId: this.detail.launchedUnderExecutionId}}));
	}

	/**
	 * @description Opens the Log Console on this run's whole action: the action and a click stamp, no
	 * window keys. View logs keeps its per-run meaning and its window.
	 */
	handleShowActionLogs()
	{
		this.navigate({
			type: 'standard__navItemPage', attributes: {apiName: 'LogConsole'}, state: {c__rootCorrelationId: this.detail.rootCorrelationId, c__viewLogsAt: String(Date.now())}
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