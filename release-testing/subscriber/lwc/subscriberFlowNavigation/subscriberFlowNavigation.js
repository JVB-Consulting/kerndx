// SPDX-License-Identifier: BUSL-1.1
import {ComponentBuilder} from 'kern/componentBuilder';

export default class SubscriberFlowNavigation extends ComponentBuilder('flow-navigation')
{
	results = [];

	get hasResults()
	{
		return this.results.length > 0;
	}

	runTests()
	{
		this.results = [
			{name: 'dispatchFlowNextEvent', pass: typeof this.dispatchFlowNextEvent === 'function'},
			{name: 'dispatchFlowBackEvent', pass: typeof this.dispatchFlowBackEvent === 'function'},
			{name: 'dispatchFlowFinishEvent', pass: typeof this.dispatchFlowFinishEvent === 'function'}
		].map(check => ({...check, label: `${check.name}: ${check.pass ? 'PASS' : 'FAIL'}`}));
	}
}
