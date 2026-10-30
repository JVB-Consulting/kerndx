// SPDX-License-Identifier: Apache-2.0
/**
 * @description Headless quick action that runs a failed API call again from its API issue record. For a call your org
 *              made, it sends the request again; for a call your org received, it replays the request and keeps its changes.
 *              It shows a toast with the result, refreshes the record when the call worked, and closes the action.
 *
 * @author Jason van Beukering
 *
 * @date May 2026, October 2026
 */
import {api} from 'lwc';
import {ComponentBuilder} from 'c/componentBuilder';
import {runApiIssueAction} from 'c/utilityApiIssueAction';
import resolveFailure from '@salesforce/apex/CTRL_RetryApiIssue.resolveFailure';

import RETRY_SUCCESSFUL from '@salesforce/label/c.RetryApiIssue_RetrySuccessful';
import RETRY_FAILED from '@salesforce/label/c.RetryApiIssue_RetryFailed';
import UNEXPECTED_ERROR from '@salesforce/label/c.RetryApiIssue_UnexpectedError';

export default class RetryApiIssue extends ComponentBuilder('notification')
{
	@api recordId;

	@api async invoke()
	{
		await runApiIssueAction(this, {
			callApex: () => resolveFailure({failureId: this.recordId}),
			successMessage: RETRY_SUCCESSFUL,
			failureMessage: RETRY_FAILED,
			unexpectedErrorMessage: UNEXPECTED_ERROR,
			errorSource: 'RetryApiIssue.invoke'
		});
	}
}
