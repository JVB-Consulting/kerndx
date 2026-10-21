// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Runs an action on an API issue record for a headless quick action, such as the Retry and Dismiss
 *              actions. It calls the Apex method, shows a toast with the result, refreshes the record when the action
 *              worked, logs an error the call throws, and closes the action. The quick action passes in the parts
 *              that differ: the Apex call and the toast texts.
 *
 * @author Jason van Beukering
 *
 * @date October 2026
 */
import {reduceErrors} from 'c/utilitySystem';
import {CloseActionScreenEvent} from 'lightning/actions';
import {notifyRecordUpdateAvailable} from 'lightning/uiRecordApi';

/**
 * @typedef {Object} ApiIssueActionResult
 * @property {boolean} callSuccessful - True when the action worked
 * @property {string} [errorMessage] - Why the action did not work, when the Apex method says
 */

/**
 * @typedef {Object} ApiIssueAction
 * @property {() => Promise<ApiIssueActionResult>} callApex - Calls the Apex method of the action for the issue
 * @property {string} successMessage - The toast text when the action worked
 * @property {string} failureMessage - The toast text when the action did not work and the Apex method gave no reason
 * @property {string} unexpectedErrorMessage - The toast text when the call threw and the error has no readable detail
 * @property {string} errorSource - The name the logged error is filed under, for example 'RetryApiIssue.invoke'
 */

/**
 * @description Runs an action on the API issue record a quick action is open on. When the action works, the record
 *              is refreshed and the success toast is shown. When it does not work, the reason from the Apex method is
 *              shown, or the failure text when there is no reason. When the call throws, the error is logged and its
 *              detail is shown, or the unexpected error text when it has no detail. The action is always closed at
 *              the end.
 *
 * @param {Object} quickAction - The quick action component: it gives the record Id and shows the toasts
 * @param {ApiIssueAction} action - The parts of the action that differ from one quick action to another
 * @returns {Promise<void>}
 */
export async function runApiIssueAction(quickAction, action)
{
	try
	{
		const result = await action.callApex();

		if(result.callSuccessful)
		{
			await notifyRecordUpdateAvailable([{recordId: quickAction.recordId}]);
			quickAction.showSuccessToast(action.successMessage);
		}
		else
		{
			quickAction.showErrorToast(result.errorMessage || action.failureMessage);
		}
	}
	catch(error)
	{
		quickAction.consoleError(error, action.errorSource);
		quickAction.showErrorToast(reduceErrors(error) || action.unexpectedErrorMessage);
	}
	finally
	{
		quickAction.dispatchEvent(new CloseActionScreenEvent());
	}
}
