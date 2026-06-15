// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Release-test post-trigger action whose CMDT row is gated by the
 * `TST_PostActionEntryDenies` entry criteria (which always returns false). Because the
 * criteria denies, this action should NEVER fire — its absence from the shared ledger proves
 * the framework consulted the `EntryCriteriaContextClassName__c` evaluator before execution.
 *
 * @author developer@kerndx.com
 *
 * @group Release Testing
 *
 * @date June 2026
 */
global with sharing class TST_PostActionEntryGated implements kern.IF_Trigger.PostAction
{
	/**
	 * @description Records 'EntryGated' if (incorrectly) invoked. A passing entry-criteria
	 * test asserts this name is absent from the ledger.
	 *
	 * @param context The post-action context supplied by the framework.
	 */
	global void execute(kern.IF_Trigger.PostActionContext context)
	{
		TST_PostActionRecorder.record('EntryGated', context);
	}
}
