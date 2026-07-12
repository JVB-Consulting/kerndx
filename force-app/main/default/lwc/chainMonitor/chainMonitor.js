// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Full-page async chain execution monitor with split-panel list and detail views.
 * Subscribes to LogEntryEvent__e for real-time status updates and automatic refresh, and lands
 * correlation deep links (e.g. from the Log Console) on the linked chain.
 *
 * @author Jason van Beukering
 *
 * @date April 2026, July 2026
 */
import {wire} from 'lwc';
import {CurrentPageReference} from 'lightning/navigation';
import {ComponentBuilder} from 'c/componentBuilder';
import {subscribe, unsubscribe} from 'lightning/empApi';
import findChainExecutionIdByCorrelation from '@salesforce/apex/CTRL_ChainMonitor.findChainExecutionIdByCorrelation';
import getNamespacePrefix from '@salesforce/apex/CTRL_ChainMonitor.getNamespacePrefix';
import chainMonitorTitle from '@salesforce/label/c.ChainMonitor_Title';

const LOG_ENTRY_EVENT_OBJECT_NAME = 'LogEntryEvent__e';
const RECORD_ID_FIELD_NAME = 'RecordId__c';
const RECORD_KEY_PREFIX_LENGTH = 3;

export default class ChainMonitor extends ComponentBuilder('controller', 'notification')
{
	selectedExecutionId = null;
	subscription = null;
	consumedCorrelationId = null;
	userHasSelected = false;
	recordIdPayloadKey = null;
	connectionGeneration = 0;
	chainKeyPrefix = null;

	label = {
		title: chainMonitorTitle
	};

	get listComponent()
	{
		return this.template.querySelector('c-chain-monitor-list');
	}

	get detailComponent()
	{
		return this.template.querySelector('c-chain-monitor-detail');
	}

	@wire(CurrentPageReference) async captureDeepLink(pageReference)
	{
		const correlationId = pageReference?.state?.c__correlationId;
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
				unsubscribe(subscription);
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
			unsubscribe(this.subscription);
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
}