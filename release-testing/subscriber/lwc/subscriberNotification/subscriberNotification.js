// SPDX-License-Identifier: BUSL-1.1
import {ComponentBuilder} from 'kern/componentBuilder';

export default class SubscriberNotification extends ComponentBuilder('notification')
{
	results = [];

	get hasResults()
	{
		return this.results.length > 0;
	}

	runTests()
	{
		this.results = [
			{name: 'showSuccessToast', pass: typeof this.showSuccessToast === 'function'},
			{name: 'showErrorToast', pass: typeof this.showErrorToast === 'function'},
			{name: 'showInfoToast', pass: typeof this.showInfoToast === 'function'},
			{name: 'showWarningToast', pass: typeof this.showWarningToast === 'function'}
		].map(check => ({...check, label: `${check.name}: ${check.pass ? 'PASS' : 'FAIL'}`}));
	}
}
