// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Headless quick action that runs a failed API call again from its API issue record. For a call your org
 *              made, it sends the request again; for a call your org received, it replays the request and keeps its changes.
 *              It shows a toast with the result, refreshes the record when the call worked, and closes the action.
 *
 * @date May 2026, October 2026
 */
import {api} from 'lwc';
import {ComponentBuilder} from 'c/componentBuilder';
import {reduceErrors} from 'c/utilitySystem';
import {CloseActionScreenEvent} from 'lightning/actions';
import {notifyRecordUpdateAvailable} from 'lightning/uiRecordApi';
import resolveFailure from '@salesforce/apex/CTRL_RetryApiIssue.resolveFailure';

import RETRY_SUCCESSFUL from '@salesforce/label/c.RetryApiIssue_RetrySuccessful';
import RETRY_FAILED from '@salesforce/label/c.RetryApiIssue_RetryFailed';
import UNEXPECTED_ERROR from '@salesforce/label/c.RetryApiIssue_UnexpectedError';

export default class RetryApiIssue extends ComponentBuilder('notification')
{
	@api recordId;

	@api async invoke()
	{
		try
		{
			let result = await resolveFailure({failureId: this.recordId});

			if(result.callSuccessful)
			{
				await notifyRecordUpdateAvailable([{recordId: this.recordId}]);
				this.showSuccessToast(RETRY_SUCCESSFUL);
			}
			else
			{
				this.showErrorToast(result.errorMessage || RETRY_FAILED);
			}
		}
		catch(error)
		{
			this.consoleError(error, 'RetryApiIssue.invoke');
			this.showErrorToast(reduceErrors(error) || UNEXPECTED_ERROR);
		}
		finally
		{
			this.dispatchEvent(new CloseActionScreenEvent());
		}
	}
}