// SPDX-License-Identifier: BUSL-1.1
import {ComponentBuilder} from 'kern/componentBuilder';

export default class SubscriberBaseOnly extends ComponentBuilder()
{
	results = [];

	get hasResults()
	{
		return this.results.length > 0;
	}

	runTests()
	{
		this.results = [
			{name: 'dispatchCustomEvent', pass: typeof this.dispatchCustomEvent === 'function'},
			{name: 'consoleLog', pass: typeof this.consoleLog === 'function'},
			{name: 'consoleError', pass: typeof this.consoleError === 'function'},
			{name: 'isLoading', pass: typeof this.isLoading === 'boolean'}
		].map(check => ({...check, label: `${check.name}: ${check.pass ? 'PASS' : 'FAIL'}`}));
	}
}
