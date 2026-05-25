// SPDX-License-Identifier: BUSL-1.1
import {ComponentBuilder} from 'kern/componentBuilder';

export default class SubscriberAllModules extends ComponentBuilder('all')
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
			{name: 'showWarningToast', pass: typeof this.showWarningToast === 'function'},
			{name: 'callControllerMethod', pass: typeof this.callControllerMethod === 'function'},
			{name: 'handleWireResponse', pass: typeof this.handleWireResponse === 'function'},
			{name: 'redirectToRecordPage', pass: typeof this.redirectToRecordPage === 'function'},
			{name: 'generateRecordPageURL', pass: typeof this.generateRecordPageURL === 'function'},
			{name: 'addMessageChannelSubscription', pass: typeof this.addMessageChannelSubscription === 'function'},
			{name: 'publishLightningMessage', pass: typeof this.publishLightningMessage === 'function'},
			{name: 'clearSubscriptions', pass: typeof this.clearSubscriptions === 'function'},
			{name: 'dispatchFlowNextEvent', pass: typeof this.dispatchFlowNextEvent === 'function'},
			{name: 'dispatchFlowBackEvent', pass: typeof this.dispatchFlowBackEvent === 'function'},
			{name: 'dispatchFlowFinishEvent', pass: typeof this.dispatchFlowFinishEvent === 'function'}
		].map(check => ({...check, label: `${check.name}: ${check.pass ? 'PASS' : 'FAIL'}`}));
	}
}
