// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Deliberate violation of KernTriggerMustDelegate.
 * Contains inline logic instead of delegating to TRG_Dispatcher.
 *
 * Expected violations:
 * - KernTriggerMustDelegate (x2: the rule checks the whole trigger body, so the loop and the
 *   assignment inside it are each reported)
 */
trigger ScannerTestTrigger on Account (before insert)
{
	for(Account record : Trigger.new)
	{
		record.Description = 'Should delegate to TRG_Dispatcher';
	}
}
