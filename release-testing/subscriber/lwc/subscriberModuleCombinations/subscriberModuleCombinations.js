// SPDX-License-Identifier: BUSL-1.1
import {ComponentBuilder} from 'kern/componentBuilder';

export default class SubscriberModuleCombinations extends ComponentBuilder('notification', 'controller', 'navigation')
{
	results = [];

	get hasResults()
	{
		return this.results.length > 0;
	}

	runTests()
	{
		const checks = [];

		checks.push({name: 'consoleLog', pass: typeof this.consoleLog === 'function'});
		checks.push({name: 'consoleError', pass: typeof this.consoleError === 'function'});
		checks.push({name: 'dispatchCustomEvent', pass: typeof this.dispatchCustomEvent === 'function'});
		checks.push({name: 'isLoading', pass: typeof this.isLoading === 'boolean'});

		checks.push({name: 'showSuccessToast', pass: typeof this.showSuccessToast === 'function'});
		checks.push({name: 'showErrorToast', pass: typeof this.showErrorToast === 'function'});
		checks.push({name: 'showInfoToast', pass: typeof this.showInfoToast === 'function'});
		checks.push({name: 'showWarningToast', pass: typeof this.showWarningToast === 'function'});
		checks.push({name: 'callControllerMethod', pass: typeof this.callControllerMethod === 'function'});
		checks.push({name: 'handleWireResponse', pass: typeof this.handleWireResponse === 'function'});
		checks.push({name: 'redirectToRecordPage', pass: typeof this.redirectToRecordPage === 'function'});
		checks.push({name: 'generateRecordPageURL', pass: typeof this.generateRecordPageURL === 'function'});

		this.results = checks.map(check => ({...check, label: `${check.name}: ${check.pass ? 'PASS' : 'FAIL'}`}));
	}

	testBaseLogging()
	{
		this.consoleLog('Base logging test from subscriber');
		this.consoleError(new Error('Test error'), 'Base error logging test from subscriber');
		this.showSuccessToast('Base methods work alongside modules');
	}

	testDispatchEvent()
	{
		this.dispatchCustomEvent('subscribertest', {message: 'Custom event from subscriber'});
		this.showInfoToast('Custom event dispatched');
	}

	testLoadingToggle()
	{
		this.isLoading = !this.isLoading;
	}
}
