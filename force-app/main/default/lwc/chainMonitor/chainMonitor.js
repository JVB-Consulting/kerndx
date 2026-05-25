// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Full-page async chain execution monitor with split-panel list and detail views.
 * Subscribes to LogEntryEvent__e for real-time status updates and automatic refresh.
 *
 * @author Jason van Beukering
 *
 * @date April 2026, May 2026
 */
import {ComponentBuilder} from 'c/componentBuilder';
import {subscribe, unsubscribe} from 'lightning/empApi';

const CHANNEL = '/event/kern__LogEntryEvent__e';

export default class ChainMonitor extends ComponentBuilder('notification')
{
	selectedExecutionId = null;
	subscription = null;

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
	}
}