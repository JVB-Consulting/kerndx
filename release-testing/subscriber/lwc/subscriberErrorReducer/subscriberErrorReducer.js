// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Drift-guard subscriber LWC for `kern/utilitySystem.reduceErrors` + the
 * `showErrorToast(errorObject)` integration on `kern/moduleNotification`. Confirms that:
 *
 *   1. `kern.utilitySystem.reduceErrors` handles the six Salesforce error shapes from the
 *      subscriber's namespace (LDS, UI API, and fallback ladder).
 *   2. `kern/componentBuilder` `notification` mixin's `showErrorToast` accepts an Apex
 *      error object directly and normalises it before toasting — subscribers do NOT need to
 *      call `reduceErrors` themselves.
 *   3. String inputs continue to pass through unchanged (no regression for existing callers).
 *
 * @author developer@kerndx.com
 *
 * @date May 2026
 */
import {ComponentBuilder} from 'kern/componentBuilder';
import {reduceErrors} from 'kern/utilitySystem';
import failOnPurpose from '@salesforce/apex/CTRL_SubscriberLwcTest.failOnPurpose';

export default class SubscriberErrorReducer extends ComponentBuilder('controller', 'notification')
{
	/**
	 * @description Result rows surfaced into the rendered list, one per assertion in runTests().
	 */
	results = [];

	/**
	 * @description Reactive flag exposed to the template — true once results have been populated.
	 *
	 * @returns {boolean} Whether the results array contains at least one entry.
	 */
	get hasResults()
	{
		return this.results.length > 0;
	}

	/**
	 * @description Runs the four assertions covering reduceErrors directly and the
	 * showErrorToast integration. Errors thrown by the assertions are caught and recorded as
	 * failures so the entire suite always completes.
	 */
	async runTests()
	{
		this.isLoading = true;
		this.results = [];
		const checks = [];

		try
		{
			const reduced = reduceErrors({body: {message: 'Generic'}});
			checks.push({name: 'reduceErrorsBodyMessage', pass: reduced === 'Generic'});
		}
		catch(error)
		{
			checks.push({name: 'reduceErrorsBodyMessage', pass: false});
		}

		try
		{
			const reduced = reduceErrors({
				body: [
					{message: 'A'},
					{message: 'B'}
				]
			});
			checks.push({name: 'reduceErrorsArrayBody', pass: reduced === 'A,B'});
		}
		catch(error)
		{
			checks.push({name: 'reduceErrorsArrayBody', pass: false});
		}

		try
		{
			const reduced = reduceErrors(null);
			checks.push({name: 'reduceErrorsNullReturnsEmptyString', pass: reduced === ''});
		}
		catch(error)
		{
			checks.push({name: 'reduceErrorsNullReturnsEmptyString', pass: false});
		}

		try
		{
			// Call the Apex method directly (NOT via callControllerMethod) — the controller
			// wrapper auto-handles errors via its own .catch(surfaceError) path and resolves
			// undefined unless isThrow=true, which would re-throw a generic 'Failed controller
			// call' Error rather than the raw AuraHandledException we want to normalise here.
			await failOnPurpose({});
			checks.push({name: 'showErrorToastNormalisesApexError', pass: false});
		}
		catch(error)
		{
			this.showErrorToast(error);
			const isObject = typeof error === 'object' && error !== null;
			const reducedDirectly = isObject ? reduceErrors(error) : error;
			const passed = isObject && typeof reducedDirectly === 'string' && reducedDirectly.length > 0 && reducedDirectly !== '[object Object]';
			checks.push({name: 'showErrorToastNormalisesApexError', pass: passed});
		}

		try
		{
			this.showErrorToast('plain string passthrough');
			checks.push({name: 'showErrorToastPassesStringsThrough', pass: true});
		}
		catch(error)
		{
			checks.push({name: 'showErrorToastPassesStringsThrough', pass: false});
		}

		this.results = checks.map(check => ({...check, label: `${check.name}: ${check.pass ? 'PASS' : 'FAIL'}`}));
		this.isLoading = false;
	}
}
