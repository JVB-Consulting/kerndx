// SPDX-License-Identifier: BUSL-1.1
import {ComponentBuilder} from 'kern/componentBuilder';

export default class SubscriberLightningMessage extends ComponentBuilder('lightning-message')
{
	results = [];

	get hasResults()
	{
		return this.results.length > 0;
	}

	runTests()
	{
		this.results = [
			{name: 'addMessageChannelSubscription', pass: typeof this.addMessageChannelSubscription === 'function'},
			{name: 'publishLightningMessage', pass: typeof this.publishLightningMessage === 'function'},
			{name: 'clearSubscriptions', pass: typeof this.clearSubscriptions === 'function'}
		].map(check => ({...check, label: `${check.name}: ${check.pass ? 'PASS' : 'FAIL'}`}));
	}
}
