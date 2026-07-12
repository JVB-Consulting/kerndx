// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Headless quick action to retry a failed API call from an ApiIssue__c record.
 *              Invokes the Apex retry controller and displays a toast with the result.
 *
 * @date March 2026, May 2026
 */
import {api} from 'lwc';
import {ComponentBuilder} from 'c/componentBuilder';
import {reduceErrors} from 'c/utilitySystem';
import {CloseActionScreenEvent} from 'lightning/actions';
import {notifyRecordUpdateAvailable} from 'lightning/uiRecordApi';
import retry from '@salesforce/apex/CTRL_RetryApiIssue.retry';

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
			let result = await retry({recordId: this.recordId});

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