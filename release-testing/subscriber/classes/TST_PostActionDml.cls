// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Release-test post-trigger action that performs SYNCHRONOUS DML inside
 * `execute()`, deliberately violating the framework no-DML contract. The framework's no-DML
 * guard detects the DML-statement increment and throws `PostActionDmlException` (always
 * rethrown regardless of `FailureAction__c` policy). Section scripts assert the exception
 * message names this class and that the originating DML rolled back.
 *
 * @author developer@kerndx.com
 *
 * @group Release Testing
 *
 * @date June 2026
 */
global with sharing class TST_PostActionDml implements kern.IF_Trigger.PostAction
{
	/**
	 * @description Records the invocation then performs synchronous DML to trip the no-DML
	 * guard. The inserted Task is a benign, trigger-free probe — the guard fires on the
	 * DML-statement increment before the inserted value matters.
	 *
	 * @param context The post-action context supplied by the framework.
	 */
	global void execute(kern.IF_Trigger.PostActionContext context)
	{
		TST_PostActionRecorder.record('Dml', context);
		insert new Task(Subject = 'TST_PostActionDml no-DML-guard probe');
	}
}
