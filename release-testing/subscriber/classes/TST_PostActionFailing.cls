// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Release-test post-trigger action that throws an unhandled exception from
 * `execute()` to exercise the `FailureAction__c` policy. With `LogAndContinue` the framework
 * logs `postAction.failed` and lets the originating DML commit; with `BlockDml` it logs and
 * rethrows, rolling back the originating DML. Section scripts assert both policy branches.
 *
 * @author developer@kerndx.com
 *
 * @group Release Testing
 *
 * @date June 2026
 */
global with sharing class TST_PostActionFailing implements kern.IF_Trigger.PostAction
{
	/**
	 * @description Message of the exception thrown to drive the FailureAction policy paths.
	 */
	public static final String FAILURE_MESSAGE = 'Intentional TST_PostActionFailing release-test failure';

	/**
	 * @description Records the invocation then throws to trigger FailureAction handling.
	 *
	 * @param context The post-action context supplied by the framework.
	 */
	global void execute(kern.IF_Trigger.PostActionContext context)
	{
		TST_PostActionRecorder.record('Failing', context);
		throw new IllegalArgumentException(FAILURE_MESSAGE);
	}
}
