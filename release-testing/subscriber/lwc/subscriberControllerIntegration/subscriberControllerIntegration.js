// SPDX-License-Identifier: BUSL-1.1
import {ComponentBuilder} from 'kern/componentBuilder';
import echo from '@salesforce/apex/CTRL_SubscriberLwcTest.echo';
import failOnPurpose from '@salesforce/apex/CTRL_SubscriberLwcTest.failOnPurpose';
import getRecentAccounts from '@salesforce/apex/CTRL_SubscriberLwcTest.getRecentAccounts';

export default class SubscriberControllerIntegration extends ComponentBuilder('controller', 'notification')
{
	results = [];

	get hasResults()
	{
		return this.results.length > 0;
	}

	async runTests()
	{
		this.isLoading = true;
		this.results = [];
		const checks = [];

		try
		{
			const echoResult = await this.callControllerMethod(echo, {input: 'subscriber test'});
			checks.push({name: 'echo', pass: echoResult === 'Echo: subscriber test', label: ''});
		}
		catch(error)
		{
			checks.push({name: 'echo', pass: false, label: ''});
		}

		try
		{
			const accounts = await this.callControllerMethod(getRecentAccounts);
			checks.push({name: 'getRecentAccounts', pass: Array.isArray(accounts), label: ''});
		}
		catch(error)
		{
			checks.push({name: 'getRecentAccounts', pass: false, label: ''});
		}

		try
		{
			await this.callControllerMethod(failOnPurpose);
			checks.push({name: 'failOnPurpose', pass: false, label: ''});
		}
		catch(error)
		{
			checks.push({name: 'failOnPurpose', pass: true, label: ''});
		}

		this.results = checks.map(check => ({...check, label: `${check.name}: ${check.pass ? 'PASS' : 'FAIL'}`}));
		this.isLoading = false;
	}
}
