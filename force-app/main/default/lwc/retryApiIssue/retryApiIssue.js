// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Headless quick action to retry a failed API call from an ApiIssue__c record.
 *              Invokes the Apex retry controller and displays a toast with the result.
 */
import {api} from 'lwc';
import {ComponentBuilder} from 'c/componentBuilder';
import {reduceErrors} from 'c/utilitySystem';
import {CloseActionScreenEvent} from 'lightning/actions';
import {notifyRecordUpdateAvailable} from 'lightning/uiRecordApi';
import retry from '@salesforce/apex/CTRL_RetryApiIssue.retry';

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
				this.showSuccessToast('Retry successful');
			}
			else
			{
				this.showErrorToast(result.errorMessage || 'Retry failed');
			}
		}
		catch(error)
		{
			this.consoleError(error, 'RetryApiIssue.invoke');
			this.showErrorToast(reduceErrors(error) || 'An unexpected error occurred');
		}
		finally
		{
			this.dispatchEvent(new CloseActionScreenEvent());
		}
	}
}