// SPDX-License-Identifier: BUSL-1.1
import {ComponentBuilder} from 'kern/componentBuilder';

export default class SubscriberNavigation extends ComponentBuilder('navigation')
{
	results = [];

	get hasResults()
	{
		return this.results.length > 0;
	}

	runTests()
	{
		this.results = [
			{name: 'redirectToRecordPage', pass: typeof this.redirectToRecordPage === 'function'},
			{name: 'generateRecordPageURL', pass: typeof this.generateRecordPageURL === 'function'}
		].map(check => ({...check, label: `${check.name}: ${check.pass ? 'PASS' : 'FAIL'}`}));
	}
}
