// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Headless quick action that marks an API issue resolved without running its request again. Use it when
 *              the request cannot be run again (it failed in a way a new run cannot fix, or its call is gone), or when
 *              you dealt with the issue another way. It shows a toast with the result, refreshes the record when the
 *              issue was resolved, and closes the action.
 *
 * @author Jason van Beukering
 *
 * @date October 2026
 */
import {api} from 'lwc';
import {ComponentBuilder} from 'c/componentBuilder';
import {runApiIssueAction} from 'c/utilityApiIssueAction';
import dismiss from '@salesforce/apex/CTRL_RetryApiIssue.dismiss';

import DISMISSED from '@salesforce/label/c.RetryApiIssue_Dismissed';
import UNEXPECTED_ERROR from '@salesforce/label/c.RetryApiIssue_UnexpectedError';

export default class DismissApiIssue extends ComponentBuilder('notification')
{
	@api recordId;

	@api async invoke()
	{
		await runApiIssueAction(this, {
			callApex: () => dismiss({issueId: this.recordId}),
			successMessage: DISMISSED,
			failureMessage: UNEXPECTED_ERROR,
			unexpectedErrorMessage: UNEXPECTED_ERROR,
			errorSource: 'DismissApiIssue.invoke'
		});
	}
}
