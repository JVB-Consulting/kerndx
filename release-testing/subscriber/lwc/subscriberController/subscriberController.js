// SPDX-License-Identifier: BUSL-1.1
import {ComponentBuilder} from 'kern/componentBuilder';

export default class SubscriberController extends ComponentBuilder('controller')
{
	results = [];

	get hasResults()
	{
		return this.results.length > 0;
	}

	runTests()
	{
		this.results = [
			{name: 'callControllerMethod', pass: typeof this.callControllerMethod === 'function'},
			{name: 'handleWireResponse', pass: typeof this.handleWireResponse === 'function'}
		].map(check => ({...check, label: `${check.name}: ${check.pass ? 'PASS' : 'FAIL'}`}));
	}
}
