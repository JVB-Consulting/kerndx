// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Full-page async chain execution monitor with split-panel list and detail views.
 * Subscribes to LogEntryEvent__e for real-time status updates and automatic refresh, and lands
 * correlation deep links (e.g. from the Log Console) on the linked chain.
 *
 * @author Jason van Beukering
 *
 * @date April 2026, May 2026, July 2026
 */
import {wire} from 'lwc';
import {CurrentPageReference} from 'lightning/navigation';
import {ComponentBuilder} from 'c/componentBuilder';
import {subscribe, unsubscribe} from 'lightning/empApi';
import findChainExecutionIdByCorrelation from '@salesforce/apex/CTRL_ChainMonitor.findChainExecutionIdByCorrelation';

const CHANNEL = '/event/kern__LogEntryEvent__e';

export default class ChainMonitor extends ComponentBuilder('controller', 'notification')
{
	selectedExecutionId = null;
	subscription = null;
	consumedCorrelationId = null;
	userHasSelected = false;

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
		// A row the user clicked during the resolve round trip wins over the deep link; the
		// list's automatic first-row selection does not.
		if(executionId && !this.userHasSelected)
		{
			this.selectedExecutionId = executionId;
			this.listComponent?.selectById(executionId);
		}
	}

	get listComponent()
	{
		return this.template.querySelector('c-chain-monitor-list');
	}

	get detailComponent()
	{
		return this.template.querySelector('c-chain-monitor-detail');
	}

	connectedCallback()
	{
		this.subscribeToEvents();
	}

	disconnectedCallback()
	{
		this.unsubscribeFromEvents();
	}

	async subscribeToEvents()
	{
		try
		{
			this.subscription = await subscribe(CHANNEL, -1, (event) =>
			{
				this.handleStreamingEvent(event);
			});
		}
		catch(error)
		{
			// Subscription may fail on cold orgs or when empApi session is stale.
			// Monitor still works via imperative Apex calls on user interactions.
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
		const recordId = event?.data?.payload?.kern__RecordId__c;

		if(recordId)
		{
			this.listComponent?.refresh();

			if(recordId === this.selectedExecutionId)
			{
				this.detailComponent?.refresh();
			}
		}
	}

	handleSelect(event)
	{
		this.selectedExecutionId = event.detail.executionId;
		if(event.detail.isUserSelection)
		{
			this.userHasSelected = true;
		}
	}
}