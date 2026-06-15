// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Release-test post-trigger action ordered AFTER `TST_PostActionRecorder`
 * (higher `Order__c`). Records into the shared ledger so section scripts can assert the
 * framework runs post-actions in `Order__c` ascending.
 *
 * @author developer@kerndx.com
 *
 * @group Release Testing
 *
 * @date June 2026
 */
global with sharing class TST_PostActionSecond implements kern.IF_Trigger.PostAction
{
	/**
	 * @description Records this invocation under the name 'Second'.
	 *
	 * @param context The post-action context supplied by the framework.
	 */
	global void execute(kern.IF_Trigger.PostActionContext context)
	{
		TST_PostActionRecorder.record('Second', context);
	}
}
