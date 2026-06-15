// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Release-test post-action entry criteria that always denies. Referenced from a
 * `PostTriggerAction__mdt` row's `EntryCriteriaContextClassName__c` to prove the framework
 * skips the gated action (`TST_PostActionEntryGated`) when `shouldRun` returns false.
 *
 * @author developer@kerndx.com
 *
 * @group Release Testing
 *
 * @date June 2026
 */
global with sharing class TST_PostActionEntryDenies implements kern.IF_Trigger.PostActionEntryCriteria
{
	/**
	 * @description Always returns false so the gated post-action is skipped.
	 *
	 * @param context The post-action context supplied by the framework.
	 *
	 * @return Always false.
	 */
	global Boolean shouldRun(kern.IF_Trigger.PostActionContext context)
	{
		return false;
	}
}
