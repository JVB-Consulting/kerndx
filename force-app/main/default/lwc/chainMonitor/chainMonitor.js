// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Full-page async chain execution monitor with split-panel list and detail views.
 * Subscribes to LogEntryEvent__e for real-time status updates and automatic refresh, and lands
 * correlation deep links (e.g. from the Log Console) on the linked chain.
 *
 * @author Jason van Beukering
 *
 * @date April 2026, September 2026
 */
import {wire} from 'lwc';
import {CurrentPageReference} from 'lightning/navigation';
import {ComponentBuilder} from 'c/componentBuilder';
import {subscribe, unsubscribe} from 'lightning/empApi';
import {formatTemplateString} from 'c/utilityString';
import ChainActionConfirmModal from 'c/chainActionConfirmModal';
import findChainExecutionIdByCorrelation from '@salesforce/apex/CTRL_ChainMonitor.findChainExecutionIdByCorrelation';
import getNamespacePrefix from '@salesforce/apex/CTRL_ChainMonitor.getNamespacePrefix';
import getChainOperationsState from '@salesforce/apex/CTRL_ChainMonitor.getChainOperationsState';
import clearStalledChains from '@salesforce/apex/CTRL_ChainMonitor.clearStalledChains';
import suspendChainProcessing from '@salesforce/apex/CTRL_ChainMonitor.suspendChainProcessing';
import resumeChainProcessing from '@salesforce/apex/CTRL_ChainMonitor.resumeChainProcessing';
import chainMonitorTitle from '@salesforce/label/c.ChainMonitor_Title';
import clearStalledAction from '@salesforce/label/c.ChainMonitor_ClearStalledAction';
import clearStalledModalTitle from '@salesforce/label/c.ChainMonitor_ClearStalledModalTitle';
import clearStalledModalBody from '@salesforce/label/c.ChainMonitor_ClearStalledModalBody';
import clearStalledConfirmButton from '@salesforce/label/c.ChainMonitor_ClearStalledConfirmButton';
import clearStalledResultToast from '@salesforce/label/c.ChainMonitor_ClearStalledResultToast';
import clearStalledFailed from '@salesforce/label/c.ChainMonitor_ClearStalledFailed';
import suspendAction from '@salesforce/label/c.ChainMonitor_SuspendAction';
import suspendModalTitle from '@salesforce/label/c.ChainMonitor_SuspendModalTitle';
import suspendModalBody from '@salesforce/label/c.ChainMonitor_SuspendModalBody';
import suspendConfirmButton from '@salesforce/label/c.ChainMonitor_SuspendConfirmButton';
import suspendedToast from '@salesforce/label/c.ChainMonitor_SuspendedToast';
import resumeAction from '@salesforce/label/c.ChainMonitor_ResumeAction';
import resumeModalTitle from '@salesforce/label/c.ChainMonitor_ResumeModalTitle';
import resumeModalBody from '@salesforce/label/c.ChainMonitor_ResumeModalBody';
import resumeConfirmButton from '@salesforce/label/c.ChainMonitor_ResumeConfirmButton';
import resumedToast from '@salesforce/label/c.ChainMonitor_ResumedToast';
import processingEnabledBadge from '@salesforce/label/c.ChainMonitor_ProcessingEnabledBadge';
import processingSuspendedBadge from '@salesforce/label/c.ChainMonitor_ProcessingSuspendedBadge';
import actionCancelButton from '@salesforce/label/c.ChainMonitor_ActionCancelButton';
import killSwitchUnavailableDisabled from '@salesforce/label/c.ChainMonitor_KillSwitchUnavailableDisabled';
import killSwitchUnavailableMissingPermission from '@salesforce/label/c.ChainMonitor_KillSwitchUnavailableMissingPermission';
import redriveUnavailableDisabled from '@salesforce/label/c.ChainMonitor_RedriveUnavailableDisabled';
import redriveUnavailableMissingPermission from '@salesforce/label/c.ChainMonitor_RedriveUnavailableMissingPermission';
import redriveUnavailableSuspended from '@salesforce/label/c.ChainMonitor_RedriveUnavailableSuspended';
import actionUnavailableNote from '@salesforce/label/c.ChainMonitor_ActionUnavailableNote';

const LOG_ENTRY_EVENT_OBJECT_NAME = 'LogEntryEvent__e';
const RECORD_ID_FIELD_NAME = 'RecordId__c';
const RECORD_KEY_PREFIX_LENGTH = 3;
const OPERATOR_AVAILABLE = 'Available';
const CLEAR_STALLED_UNAVAILABLE_MESSAGES = {
	ChainProcessingSuspended: redriveUnavailableSuspended, CapabilityDisabled: redriveUnavailableDisabled, PermissionMissing: redriveUnavailableMissingPermission
};
const KILL_SWITCH_UNAVAILABLE_MESSAGES = {
	CapabilityDisabled: killSwitchUnavailableDisabled, PermissionMissing: killSwitchUnavailableMissingPermission
};

// The acknowledgement the platform requires when a subscription is dropped: empApi hands its second
// argument on as the callback, and called with one argument it raises "Invalid or missing callback"
// while the page is being torn down. Nothing is left to do once the subscription is gone, so the
// platform's answer is taken and dropped.
const acknowledgeUnsubscribe = () => null;

export default class ChainMonitor extends ComponentBuilder('controller', 'notification')
{
	selectedExecutionId = null;
	subscription = null;
	consumedCorrelationId = null;
	// The action a deep link pinned (its root correlation id), handed to the list; null when unscoped. The consumed key
	// pairs the action with the click stamp, so a re-delivered page reference does not re-pin what the reader cleared.
	actionRootCorrelationId = null;
	consumedActionKey = null;
	userHasSelected = false;
	recordIdPayloadKey = null;
	connectionGeneration = 0;
	chainKeyPrefix = null;
	operationsState = null;
	isOperationsProcessing = false;

	label = {
		title: chainMonitorTitle, clearStalledAction, suspendAction, resumeAction
	};

	get listComponent()
	{
		return this.template.querySelector('c-chain-monitor-list');
	}

	get detailComponent()
	{
		return this.template.querySelector('c-chain-monitor-detail');
	}

	get showOperationsControl()
	{
		return this.operationsState != null;
	}

	get operationsBadgeLabel()
	{
		return this.operationsState?.chainProcessingEnabled ? processingEnabledBadge : processingSuspendedBadge;
	}

	get operationsBadgeClass()
	{
		return this.operationsState?.chainProcessingEnabled ? 'slds-theme_success' : 'slds-theme_warning';
	}

	get showSuspendButton()
	{
		return this.operationsState?.chainProcessingEnabled === true;
	}

	get isClearStalledDisabled()
	{
		return this.isOperationsProcessing || this.operationsState?.clearStalledAvailability !== OPERATOR_AVAILABLE;
	}

	get clearStalledUnavailableMessage()
	{
		return CLEAR_STALLED_UNAVAILABLE_MESSAGES[this.operationsState?.clearStalledAvailability] ?? '';
	}

	get isKillSwitchDisabled()
	{
		return this.isOperationsProcessing || this.operationsState?.killSwitchAvailability !== OPERATOR_AVAILABLE;
	}

	get killSwitchUnavailableMessage()
	{
		return KILL_SWITCH_UNAVAILABLE_MESSAGES[this.operationsState?.killSwitchAvailability] ?? '';
	}

	/**
	 * @description The refusal sentences to show on screen, one per greyed-out header action, each
	 * named by the action it belongs to because the buttons sit in the card header a row above.
	 * A disabled button suppresses pointer events, so its tooltip never fires, and it takes no
	 * focus, so neither the tooltip nor the assistive description can be reached by keyboard. This
	 * list needs neither, which is why it stays in the accessibility tree rather than being hidden
	 * as a duplicate: a reader who also lands on the button hears the sentence twice, and that
	 * repetition is the price of never hiding the reason from anyone.
	 *
	 * @returns {Array<{key: string, text: string}>}
	 */
	get unavailableReasons()
	{
		return [
			{key: 'clear-stalled', action: clearStalledAction, message: this.clearStalledUnavailableMessage},
			{key: 'kill-switch', action: this.showSuspendButton ? suspendAction : resumeAction, message: this.killSwitchUnavailableMessage}
		]
		.filter((reason) => reason.message)
		.map((reason) => ({
			key: reason.key, text: formatTemplateString(actionUnavailableNote, [
				reason.action,
				reason.message
			])
		}));
	}

	get hasUnavailableReasons()
	{
		return this.unavailableReasons.length > 0;
	}

	@wire(CurrentPageReference) async captureDeepLink(pageReference)
	{
		const state = pageReference?.state ?? {};
		// An action deep link (the Log Console's Open the chains) scopes the list to the action's
		// runs. Applied once per stamp: the wire re-delivers the page reference on every return to
		// the tab, and a cleared pill must stay cleared.
		const actionKey = state.c__rootCorrelationId ? `${state.c__rootCorrelationId}|${state.c__viewLogsAt ?? ''}` : null;
		if(actionKey && actionKey !== this.consumedActionKey)
		{
			this.consumedActionKey = actionKey;
			this.actionRootCorrelationId = state.c__rootCorrelationId;
		}
		const correlationId = state.c__correlationId;
		// A correlation deep link (the Log Console drawer's "Open in Chain Monitor") resolves to
		// the registered chain and selects it, instead of landing on the default first-row
		// selection. An unresolvable correlation (e.g. the chain was purged) falls through to the
		// normal landing. The consumed id is remembered so wire re-emissions don't re-resolve.
		if(!correlationId || correlationId === this.consumedCorrelationId)
		{
			return;
		}
		this.consumedCorrelationId = correlationId;

		const executionId = await this.callControllerMethod(findChainExecutionIdByCorrelation, {correlationId});
		this.rememberChainKeyPrefix(executionId);
		// A row the user clicked during the resolve round trip wins over the deep link; the
		// list's automatic first-row selection does not.
		if(executionId && !this.userHasSelected)
		{
			this.selectedExecutionId = executionId;
			this.listComponent?.selectById(executionId);
		}
	}

	connectedCallback()
	{
		this.connectionGeneration++;
		this.subscribeToEvents(this.connectionGeneration);
		// noinspection JSIgnoredPromiseFromCall
		this.loadOperationsState();
	}

	disconnectedCallback()
	{
		// Advancing the generation invalidates any subscribe still in flight from the connection
		// being torn down; a plain disconnected flag cannot, because an immediate reconnect
		// resets it and lets the stale run register a second, orphaned subscription.
		this.connectionGeneration++;
		this.unsubscribeFromEvents();
	}

	async subscribeToEvents(generation)
	{
		try
		{
			// The channel and payload key carry the package namespace only in a managed install
			// ('kern__'), not in an unmanaged (no-namespace) deploy — resolved inside the try so
			// a failure degrades to the imperative-refresh path without surfacing a toast.
			const namespacePrefix = await getNamespacePrefix() ?? '';
			// A disconnect, or a disconnect/reconnect cycle, can happen while either await in
			// this method is in flight; a continuation from a superseded connection would
			// register a subscription nothing tears down for the page session.
			if(generation !== this.connectionGeneration)
			{
				return;
			}
			this.recordIdPayloadKey = `${namespacePrefix}${RECORD_ID_FIELD_NAME}`;
			const subscription = await subscribe(`/event/${namespacePrefix}${LOG_ENTRY_EVENT_OBJECT_NAME}`, -1, (event) =>
			{
				this.handleStreamingEvent(event);
			});
			if(generation !== this.connectionGeneration)
			{
				unsubscribe(subscription, acknowledgeUnsubscribe);
				return;
			}
			this.subscription = subscription;
		}
		catch(error)
		{
			// Subscription may fail on cold orgs or when the empApi session is stale. The monitor
			// still works via imperative Apex calls on user interactions, but the breakage is
			// logged so a broken real-time feed is diagnosable.
			this.consoleError(error, 'ChainMonitor.subscribeToEvents');
		}
	}

	unsubscribeFromEvents()
	{
		if(this.subscription)
		{
			unsubscribe(this.subscription, acknowledgeUnsubscribe);
			this.subscription = null;
		}
	}

	handleStreamingEvent(event)
	{
		const recordId = event?.data?.payload?.[this.recordIdPayloadKey];

		if(!recordId || !this.isChainExecutionRecordId(recordId))
		{
			return;
		}

		this.listComponent?.refresh();

		if(recordId === this.selectedExecutionId)
		{
			this.detailComponent?.refresh();
		}
	}

	rememberChainKeyPrefix(executionId)
	{
		// Every chain execution record in an org shares one key prefix (the first three
		// characters of its id). Learning it from any chain in view lets the streaming handler
		// ignore log events about unrelated records without an extra server round trip.
		if(executionId)
		{
			this.chainKeyPrefix = String(executionId).slice(0, RECORD_KEY_PREFIX_LENGTH);
		}
	}

	isChainExecutionRecordId(recordId)
	{
		// Until a chain has been in view the prefix is unknown; refresh conservatively so the
		// first chain still appears live on an empty monitor.
		return !this.chainKeyPrefix || String(recordId).startsWith(this.chainKeyPrefix);
	}

	handleSelect(event)
	{
		this.selectedExecutionId = event.detail.executionId;
		this.rememberChainKeyPrefix(event.detail.executionId);
		if(event.detail.isUserSelection)
		{
			this.userHasSelected = true;
		}
	}

	handleChainAbort()
	{
		// noinspection JSIgnoredPromiseFromCall
		this.listComponent?.refresh();
	}

	handleChainRetry()
	{
		// noinspection JSIgnoredPromiseFromCall
		this.listComponent?.refresh();
	}

	/**
	 * @description A successful restart selects the CLONE: the list refreshes so the new row
	 * exists, then selection moves to it. The clone id also re-points the detail pane, and the
	 * selection counts as a user selection so a pending deep-link resolve cannot override it.
	 */
	async handleChainRestart(event)
	{
		const cloneExecutionId = event.detail.executionId;
		this.selectedExecutionId = cloneExecutionId;
		this.userHasSelected = true;
		this.rememberChainKeyPrefix(cloneExecutionId);
		await this.listComponent?.refresh();
		this.listComponent?.selectById(cloneExecutionId);
	}

	/**
	 * @description The detail pane's Launched under link: selects the run named there, which is the
	 * launching run, or the source run a restart clone was made from, in both the list and the
	 * detail pane.
	 */
	handleLineageNavigate(event)
	{
		const sourceExecutionId = event.detail.executionId;
		this.selectedExecutionId = sourceExecutionId;
		this.userHasSelected = true;
		this.listComponent?.selectById(sourceExecutionId);
	}

	/**
	 * @description The list dropped its action pill: the container forgets the action so a later
	 * deep link with a new stamp can pin one again.
	 */
	handleActionClear()
	{
		this.actionRootCorrelationId = null;
	}

	async loadOperationsState()
	{
		const data = await this.callControllerMethod(getChainOperationsState);
		if(data)
		{
			this.operationsState = data;
		}
	}

	/**
	 * @description Confirms an operations-control action through the shared modal, then runs it
	 * with both header controls held disabled until the controller promise settles — a rapid
	 * second click during server transit is impossible client-side; the server re-resolves
	 * availability on every call and remains the enforcement point.
	 */
	async runConfirmedOperation(modalConfiguration, controllerMethod, onSuccess)
	{
		const result = await ChainActionConfirmModal.open(modalConfiguration);

		if(result?.action !== 'confirm')
		{
			return {confirmed: false, data: undefined};
		}

		this.isOperationsProcessing = true;
		try
		{
			const data = await this.callControllerMethod(controllerMethod);

			if(data)
			{
				onSuccess(data);
			}
			return {confirmed: true, data};
		}
		finally
		{
			this.isOperationsProcessing = false;
		}
	}

	/**
	 * @description Confirms and runs the clear-stalled sweep, then reports the per-bucket counts
	 * in the result toast and refreshes the list, the detail, and the operations state. A sweep
	 * that answers nothing at all gets the labelled failure toast — the engine swallows
	 * per-candidate failures, so a missing result means the sweep itself did not complete.
	 * The waiting count is re-read first: the dialog names it, and a page left open while chains
	 * stall would otherwise quote whatever was true when the header last loaded. Reading the count
	 * straight off the state needs no fallback — the button that reaches this handler renders only
	 * once a load has answered, and a refresh that fails leaves the previous answer in place.
	 */
	async handleClearStalled()
	{
		await this.loadOperationsState();

		const outcome = await this.runConfirmedOperation({
			size: 'small',
			label: clearStalledModalTitle,
			title: clearStalledModalTitle,
			body: formatTemplateString(clearStalledModalBody, [this.operationsState.stalledChainCount]),
			confirmLabel: clearStalledConfirmButton,
			cancelLabel: actionCancelButton,
			confirmVariant: 'brand'
		}, clearStalledChains, (data) =>
		{
			this.showSuccessToast(formatTemplateString(clearStalledResultToast, [
				data.candidates,
				data.redriven,
				data.markedFailed,
				data.remainingStalled
			]));
			// noinspection JSIgnoredPromiseFromCall
			this.listComponent?.refresh();
			// noinspection JSIgnoredPromiseFromCall
			this.detailComponent?.refresh();
			// noinspection JSIgnoredPromiseFromCall
			this.loadOperationsState();
		});

		if(outcome.confirmed && !outcome.data)
		{
			this.showErrorToast(clearStalledFailed);
		}
	}

	async handleSuspend()
	{
		await this.runConfirmedOperation({
			size: 'small',
			label: suspendModalTitle,
			title: suspendModalTitle,
			body: suspendModalBody,
			confirmLabel: suspendConfirmButton,
			cancelLabel: actionCancelButton,
			confirmVariant: 'destructive'
		}, suspendChainProcessing, (data) =>
		{
			this.operationsState = data;
			this.showSuccessToast(suspendedToast);
			// The suspension changes every re-drive availability answer on the open detail.
			// noinspection JSIgnoredPromiseFromCall
			this.detailComponent?.refresh();
		});
	}

	async handleResume()
	{
		await this.runConfirmedOperation({
			size: 'small',
			label: resumeModalTitle,
			title: resumeModalTitle,
			body: resumeModalBody,
			confirmLabel: resumeConfirmButton,
			cancelLabel: actionCancelButton,
			confirmVariant: 'brand'
		}, resumeChainProcessing, (data) =>
		{
			this.operationsState = data;
			this.showSuccessToast(resumedToast);
			// noinspection JSIgnoredPromiseFromCall
			this.detailComponent?.refresh();
		});
	}
}